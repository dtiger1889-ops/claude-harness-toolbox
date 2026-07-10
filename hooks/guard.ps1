# PreToolUse guard hook. Blocks (exit 2) on MECHANICAL breakage only -- cases where a
# character literally breaks parsing. Human-prose style (em-dashes as an AI-tell) is NOT
# handled here; that is a draft-then-review concern, not a real-time block. Two checks:
#   1. non-ASCII (em/en dash, curly quotes) in POWERSHELL ONLY -- the one language that
#      chokes on it (.ps1 misdecoded as Windows-1252 under PS 5.1). Other languages
#      (Python, JS, JSON, etc.) permit UTF-8, so em-dashes there are fine and NOT blocked.
#   2. backslash Windows drive-paths inside Bash double-quoted strings (MSYS eats them).
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

    # CHECK 2: Bash command with a backslash drive-path inside double quotes.
    if ($tool -eq 'Bash' -and ([string]$ti.command) -match '"[A-Za-z]:\\') {
        [Console]::Error.WriteLine("BLOCKED by guard hook: backslash Windows path in a Bash double-quoted string. MSYS bash eats the backslashes. Use forward slashes (C:/Users/...) or /c/Users/... form.")
        exit 2
    }

    exit 0
}
catch {
    # Fail open: never wedge the session on a guard bug.
    exit 0
}
