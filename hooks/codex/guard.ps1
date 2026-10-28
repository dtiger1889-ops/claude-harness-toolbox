# PreToolUse guard hook. Blocks (exit 2) on MECHANICAL breakage only -- cases where a
# character literally breaks parsing. Human-prose style (em-dashes as an AI-tell) is NOT
# handled here; that is a draft-then-review concern, not a real-time block. Three checks:
#   1. non-ASCII (em/en dash, curly quotes) in POWERSHELL ONLY -- the one language that
#      chokes on it (.ps1 misdecoded as Windows-1252 under PS 5.1). Other languages
#      (Python, JS, JSON, etc.) permit UTF-8, so em-dashes there are fine and NOT blocked.
#   2. backslash Windows drive-paths inside Bash double-quoted strings (MSYS eats them).
#   3. `--no-ignore` passed to grep -- a ripgrep-only flag that makes GNU grep exit 2 and
#      print nothing, so a scan that never ran is indistinguishable from a clean one.
# Reads the PreToolUse JSON from stdin. Fails OPEN (exit 0) on any error so a hook bug
# can never wedge the session.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    $tool = "$($j.tool_name)"
    $ti = $j.tool_input

    # Gather PowerShell-bound text only: a PowerShell command, or a write to a .ps1/.psm1/.psd1.
    # This is the only language with a documented non-ASCII parse-break. Everything else
    # (prose, Python, JS, JSON, ...) is intentionally left alone.
    $isPwsh = $false
    $pwshText = ""
    if ($tool -eq 'PowerShell') {
        $isPwsh = $true
        $pwshText = [string]$ti.command
    }
    elseif ($tool -eq 'Write' -or $tool -eq 'Edit') {
        $fp = [string]$ti.file_path
        if ($fp -match '\.(ps1|psm1|psd1)$') {
            $isPwsh = $true
            if ($ti.content)    { $pwshText += [string]$ti.content + "`n" }
            if ($ti.new_string) { $pwshText += [string]$ti.new_string + "`n" }
        }
    }

    # CHECK 1: banned non-ASCII in PowerShell only.
    if ($isPwsh -and -not [string]::IsNullOrEmpty($pwshText)) {
        $banned = @{
            ([char]0x2014) = 'em dash'
            ([char]0x2013) = 'en dash'
            ([char]0x201C) = 'curly double quote'
            ([char]0x201D) = 'curly double quote'
            ([char]0x2018) = 'curly apostrophe'
            ([char]0x2019) = 'curly apostrophe'
        }
        foreach ($k in $banned.Keys) {
            if ($pwshText.Contains($k)) {
                [Console]::Error.WriteLine("BLOCKED by guard hook: non-ASCII (" + $banned[$k] + ") in PowerShell. PS 5.1 misdecodes it as Windows-1252 and the parse breaks. Use ASCII: -- for dashes, straight quotes.")
                exit 2
            }
        }
    }

    # CHECK 2: Bash command with a backslash drive-path outside single quotes.
    # Single-quoted 'C:\...' is safe in bash (backslashes stay literal); double-quoted
    # AND unquoted drive-paths both get mangled by MSYS. Strip single-quoted spans
    # first, then match anywhere in what remains. (The original quote-only pattern let
    # unquoted paths slip through -- confirmed in live transcripts before widening.)
    if ($tool -eq 'Bash') {
        $bashCmd = [string]$ti.command
        $outsideSq = $bashCmd -replace "'[^']*'", ' '
        # Path-start char required after the backslash: real drive paths look like
        # C:\Users\x, while grep alternation like "note:\|reply:" must NOT match
        # (false positive caught live the first session after widening).
        if ($outsideSq -match '[A-Za-z]:\\[A-Za-z0-9_.]') {
            [Console]::Error.WriteLine("BLOCKED by guard hook: backslash Windows path in a Bash command (outside single quotes). MSYS bash eats the backslashes. Use forward slashes (C:/Users/...), /c/Users/... form, or wrap the literal in single quotes.")
            exit 2
        }
    }

    # CHECK 3: GNU grep invoked with --no-ignore (a RIPGREP-only flag).
    # GNU grep exits 2 with a usage error and prints NOTHING on stdout, so when stderr is
    # suppressed (2>/dev/null) or simply not read, a scan that never ran is byte-identical
    # to a clean scan. That makes this failure mode uniquely dangerous: it silently DISARMS
    # whatever gate it was written into, and the wrong form spreads easily because the two
    # tools look interchangeable. Worth blocking mechanically if you run any grep-based
    # secret/personal-data scan before publishing.
    # Only an UNQUOTED occurrence is the flag; a quoted one is a search PATTERN, so
    # auditing your own tree for this mistake stays possible. rg/ripgrep is NOT blocked.
    if ($tool -eq 'Bash' -or $tool -eq 'PowerShell') {
        $cmdText = [string]$ti.command
        if ($cmdText -match '--no-ignore') {
            foreach ($seg in ($cmdText -split '[|;&\r\n]+')) {
                $bare = $seg -replace "'[^']*'", ' ' -replace '"[^"]*"', ' '
                if (($bare -match '--no-ignore') -and ($seg -match '\bgrep\b') -and ($seg -notmatch '\b(rg|ripgrep)\b')) {
                    [Console]::Error.WriteLine("BLOCKED by guard hook: '--no-ignore' is a ripgrep flag, NOT a GNU grep flag. grep exits 2 with a usage error and prints nothing, so a scan that never ran looks exactly like a clean scan. Drop the flag (plain grep does not read .gitignore anyway) or call rg --no-ignore. To scan a publish set: git ls-files -z | xargs -0 grep -inE 'pattern'  (exit 1 = clean, 0 = hits). And never trust an empty security scan without a control probe proving the pattern matches something.")
                    exit 2
                }
            }
        }
    }

    exit 0
}
catch {
    # Fail open: never wedge the session on a guard bug.
    exit 0
}
