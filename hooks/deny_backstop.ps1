#requires -Version 5.1
# PreToolUse security backstop hook (Windows/PowerShell).
#
# Claude Code deny rules are not a hard boundary for shell-shaped commands: a command
# hidden in command substitution, backticks, or a loop body can evade a prefix matcher.
# This hook receives the complete raw command (Bash, PowerShell and Monitor tools) and
# blocks a deliberately narrow set of catastrophic operations wherever they appear. It
# fails open so a hook defect cannot wedge a session.
#
# Besides the raw text it also checks:
#   - the command after cheap de-obfuscation: PowerShell backtick escapes, literal string
#     concatenation ('Stop-' + 'Process'), bash quote-splitting (r''m), and variables
#     assigned from literals earlier in the same command (c=sudo; $c ...);
#   - the decoded text of -EncodedCommand arguments (any accepted abbreviation) and of
#     FromBase64String('...') literals;
#   - base64 decode piped into a shell or Invoke-Expression, which is blocked outright.
# It judges the command text only. Script files the command runs are not opened: scripts
# routinely delete their own computed temp paths, and scanning them over-blocks.
# Text matching can over-block a QUOTED dangerous literal (it never under-blocks because
# of quoting), so keep test cases in a data file rather than inline in a command.
#
# INSTALL: copy this file to ~/.claude/hooks/ and add the matching PreToolUse entry from
# settings-windows.example.json. Review and adapt the patterns to your own environment.

$KillMsg = 'BLOCKED by security backstop hook: broad-match process kill. This selects processes by name, pattern, or pipeline and can terminate work owned by other sessions. Re-issue targeting an explicit PID: Stop-Process -Id <pid> -Force, taskkill /PID <pid> /T /F, or kill <pid>. Get the PID from a read-only process listing or a port lookup. If a broad kill is genuinely intended, run it yourself.'
$CredMsg = 'BLOCKED by security backstop hook: this command touches ~/.claude/.credentials.json. Outside an interactive session that file is a stale token cache (a headless reader gets a days-old token and a 401). For usage or rate-limit numbers, read the JSON Claude Code passes to your statusline command (rate_limits.*) instead.'
$DeleteMsgTail = 'This blocks the FORM of the command, not the delete. A variable, loop, glob or $(...) target can resolve to a path you never saw. If the delete was asked for it is still your job: list and check the targets first, then re-issue it with every target written out as a literal path, e.g. Remove-Item -LiteralPath ''C:/x/a'',''C:/x/b'' -Recurse -Force or rm -rf ''/c/x/a'' ''/c/x/b''. Many literal paths in one command is fine; split a very long list across several commands. A drive root or home folder itself is never a delete target.'
$BlockMsgTail = 'This operation is catastrophic or irreversible in auto-approve mode. If you truly intend it, run it yourself.'

# Returns $null, or @{ Kind = 'kill'|'cred'|'delete'|'block'; Msg = <reason> }.
function Get-Verdict([string]$cmd) {
    if ([string]::IsNullOrWhiteSpace($cmd)) { return $null }
    $blockMsg = $null
    $isDelete = $false

    # 1. Network fetch piped into a shell interpreter (remote code execution).
    if ($cmd -match '(?i)\b(curl|wget)\b[^\r\n]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|ash)\b') {
        $blockMsg = 'network fetch piped into a shell (curl/wget | sh)'
    }

    # 1b. Base64 decode piped into a shell or Invoke-Expression (obfuscated command).
    elseif ($cmd -match '(?i)\bbase64\b[^\r\n|]*\s(-d|--decode|-D)\b[^\r\n]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|ash|iex|Invoke-Expression)\b') {
        $blockMsg = 'base64-decoded text piped into a shell'
    }

    # 2. sudo (privilege escalation).
    elseif ($cmd -match '(?i)(^|[\s;&|(`])sudo\b') {
        $blockMsg = 'sudo privilege escalation'
    }

    # 3. Recursive + force rm of a catastrophic target (root / home / drive root / bare var).
    elseif (($cmd -match '(?i)\brm\b') -and
            ($cmd -match '(?i)(--recursive\b|[\s(]-\S*[rR]\S*)') -and
            ($cmd -match '(?i)(--force\b|[\s(]-\S*[fF]\S*)')) {
        $targets = @(
            '/(?![\w./])',
            '~(?![\w./])', '~/(?![\w.])',
            '\$\{?HOME\}?(?![\w./])', '\$\{?HOME\}?/(?![\w.])',
            '\$USERPROFILE(?![\w./])', '\$USERPROFILE/(?![\w.])',
            '%USERPROFILE%(?![\w./])', '%USERPROFILE%/(?![\w.])',
            'C:[\\/](?![\w.])', 'C:(?![\w.\\/])',
            '/c(?![\w./])',
            '\$[A-Za-z_]\w*(?![\w./])'
        )
        foreach ($t in $targets) {
            if ($cmd -match ('(?i)\brm\b[^;|&\r\n]*?[\s(]["'']?' + $t)) {
                $blockMsg = 'recursive force-delete of root / home / drive root / a variable target'
                # Only a computed (variable) target gets the re-issue-with-literal-paths
                # message; a literal root/home target stays a plain block.
                if ($t.StartsWith('\$[A-Za-z_]')) { $isDelete = $true }
                break
            }
        }
    }

    # 4. PowerShell recursive Remove-Item of home / drive root / a variable target.
    if (-not $blockMsg -and
        ($cmd -match '(?i)\b(Remove-Item|ri|rd|rmdir|del|erase)\b') -and
        ($cmd -match '(?i)-Recurse\b') -and
        ($cmd -match '(?i)(\$HOME|\$env:USERPROFILE|\$env:HOME|C:[\\/](?![\w.])|C:(?![\w.\\/])|\$[A-Za-z_]\w*)')) {
        $blockMsg = 'PowerShell recursive Remove-Item of home / drive root / a variable target'
        $isDelete = $true
    }

    # 5. Set-ExecutionPolicy (security-setting change).
    if (-not $blockMsg -and $cmd -match '(?i)\bSet-ExecutionPolicy\b') {
        $blockMsg = 'Set-ExecutionPolicy change'
    }

    # 6. Broad-match process kill. Name/pattern/pipeline selection can terminate every
    # matching process on the machine, including work owned by another session. Require
    # an explicit PID for process termination; read-only listings remain untouched.
    if (-not $blockMsg) {
        $killByName = ($cmd -match '(?i)(^|[\s;|&({])(Stop-Process|spps)\b[^;|\r\n]*\s-Name\b') -or
                      ($cmd -match '(?i)(^|[\s;|&({])kill\b[^;|\r\n]*\s-Name\b')
        $killByPipe = ($cmd -match '(?i)\|\s*(Stop-Process|spps|kill)\b') -and
                      ($cmd -notmatch '(?i)-Id\b')
        $killByImage = ($cmd -match '(?i)\btaskkill\b[^;\r\n]*\s[/-]IM\b') -and
                       ($cmd -notmatch '(?i)\btaskkill\b[^;\r\n]*\s[/-]PID\b')
        $killByPattern = $cmd -match '(?i)(^|[\s;|&({])(pkill|killall)\b'
        $killByPgrep = ($cmd -match '(?i)\bpgrep\b') -and
                       ($cmd -match '(?i)(^|[\s;|&({])kill\b')
        if ($killByName -or $killByPipe -or $killByImage -or $killByPattern -or $killByPgrep) {
            return @{ Kind = 'kill'; Msg = 'broad-match process kill' }
        }
    }

    # 7. Reading ~/.claude/.credentials.json from a script or command. The file is a token
    #    cache that only a terminal-attached Claude Code session refreshes; a headless reader
    #    (a usage poller, a scheduled script) gets a token that can be days stale and a 401.
    #    Usage and rate-limit numbers belong to the statusline JSON Claude Code hands its
    #    statusline command (rate_limits.*), not to this file.
    if (-not $blockMsg -and $cmd -match '(?i)\.credentials\.json') {
        return @{ Kind = 'cred'; Msg = 'credentials file' }
    }

    if ($blockMsg -and $isDelete) { return @{ Kind = 'delete'; Msg = $blockMsg } }
    if ($blockMsg) { return @{ Kind = 'block'; Msg = $blockMsg } }
    return $null
}

# Undo the cheap obfuscations: PowerShell backtick escapes, literal string concatenation,
# bash quote-splitting (r''m, "r"m), and variables assigned from literals in the same text.
function Expand-Command([string]$t) {
    $x = $t -replace '`(?=[A-Za-z-])', ''
    for ($i = 0; $i -lt 20; $i++) {
        $y = [regex]::Replace($x, '([''"])([^''"\r\n]*)\1\s*\+\s*([''"])([^''"\r\n]*)\3', { param($m) "'" + $m.Groups[2].Value + $m.Groups[4].Value + "'" })
        if ($y -eq $x) { break }
        $x = $y
    }
    $x = $x -replace '(?<=[\w-])(?:''''|"")(?=[\w-])', ''
    $x = [regex]::Replace($x, '(?<=[\w-])([''"])([\w-]+)\1', { param($m) $m.Groups[2].Value })
    $x = [regex]::Replace($x, '([''"])([\w-]+)\1(?=[\w-])', { param($m) $m.Groups[2].Value })
    $vars = @{}
    foreach ($m in [regex]::Matches($x, '(?i)\$(?:env:)?(\w+)\s*=\s*([''"])([^''"\r\n]*)\2')) { $vars[$m.Groups[1].Value] = $m.Groups[3].Value }
    foreach ($m in [regex]::Matches($x, '(?m)(?:^|[\s;&|(])(?:export\s+)?([A-Za-z_]\w*)=(?:([''"])([^''"\r\n]*)\2|([^\s;&|''"()]+))')) {
        $v = if ($m.Groups[2].Success) { $m.Groups[3].Value } else { $m.Groups[4].Value }
        $vars[$m.Groups[1].Value] = $v
    }
    foreach ($k in $vars.Keys) {
        $v = $vars[$k]
        $x = [regex]::Replace($x, '(?i)\$(?:env:)?\{?' + [regex]::Escape($k) + '\}?(?!\w)(?!\s*=)', { param($m) $v })
    }
    return $x
}

# Decoded text of -EncodedCommand arguments (every abbreviation PowerShell accepts) and
# FromBase64String('...') literals, as both UTF-16 and UTF-8.
function Get-DecodedTexts([string]$t) {
    $out = @()
    $b64 = @()
    foreach ($m in [regex]::Matches($t, '(?i)(?:^|\s)[-/](?:e|ec|en|enc|enco|encod|encode|encoded|encodedc|encodedco|encodedcom|encodedcomm|encodedcomma|encodedcomman|encodedcommand)\s+[''"]?([A-Za-z0-9+/=]{8,})')) { $b64 += $m.Groups[1].Value }
    foreach ($m in [regex]::Matches($t, '(?i)FromBase64String\(\s*[''"]([A-Za-z0-9+/=]{8,})[''"]')) { $b64 += $m.Groups[1].Value }
    foreach ($s in $b64) {
        try {
            $bytes = [Convert]::FromBase64String($s)
            $out += [Text.Encoding]::Unicode.GetString($bytes)
            $out += [Text.Encoding]::UTF8.GetString($bytes)
        } catch { }
    }
    return $out
}

function Write-Verdict($v, [string]$where) {
    $suffix = if ($where) { " (found in $where)" } else { '' }
    switch ($v.Kind) {
        'kill'   { [Console]::Error.WriteLine($KillMsg + $suffix) }
        'cred'   { [Console]::Error.WriteLine($CredMsg + $suffix) }
        'delete' { [Console]::Error.WriteLine("BLOCKED by security backstop hook: $($v.Msg)$suffix. $DeleteMsgTail") }
        default  { [Console]::Error.WriteLine("BLOCKED by security backstop hook: $($v.Msg)$suffix. $BlockMsgTail") }
    }
    exit 2
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    $tool = "$($j.tool_name)"
    # Monitor runs a shell command too (a watch loop), so it is checked like Bash.
    if ($tool -ne 'Bash' -and $tool -ne 'PowerShell' -and $tool -ne 'Monitor') { exit 0 }
    $cmd = [string]$j.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    # The raw text first, then the de-obfuscated and decoded forms.
    $v = Get-Verdict $cmd
    if ($v) { Write-Verdict $v '' }
    $expanded = Expand-Command $cmd
    if ($expanded -ne $cmd) {
        $v = Get-Verdict $expanded
        if ($v) { Write-Verdict $v 'the command after expanding variables / joined strings' }
    }
    foreach ($d in (Get-DecodedTexts $cmd)) {
        $v = Get-Verdict $d
        if (-not $v) { $v = Get-Verdict (Expand-Command $d) }
        if ($v) { Write-Verdict $v 'an encoded (base64) command' }
    }

    exit 0
}
catch {
    # Fail open: never wedge a session on a hook bug.
    exit 0
}
