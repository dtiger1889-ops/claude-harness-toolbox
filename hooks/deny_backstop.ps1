#requires -Version 5.1
# PreToolUse security backstop hook (Windows/PowerShell).
#
# Claude Code deny rules are not a hard boundary for shell-shaped commands: a command
# hidden in command substitution, backticks, or a loop body can evade a prefix matcher.
# This hook receives the complete raw command and blocks a deliberately narrow set of
# catastrophic operations wherever they appear. It fails open so a hook defect cannot
# wedge a session.
#
# INSTALL: copy this file to ~/.claude/hooks/ and add the matching PreToolUse entry from
# settings-windows.example.json. Review and adapt the patterns to your own environment.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    $tool = "$($j.tool_name)"
    if ($tool -ne 'Bash' -and $tool -ne 'PowerShell') { exit 0 }
    $cmd = [string]$j.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    $blockMsg = $null

    # 1. Network fetch piped into a shell interpreter (remote code execution).
    if ($cmd -match '(?i)\b(curl|wget)\b[^\r\n]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|ash)\b') {
        $blockMsg = 'network fetch piped into a shell (curl/wget | sh)'
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
            [Console]::Error.WriteLine('BLOCKED by security backstop hook: broad-match process kill. This selects processes by name, pattern, or pipeline and can terminate work owned by other sessions. Re-issue targeting an explicit PID: Stop-Process -Id <pid> -Force, taskkill /PID <pid> /T /F, or kill <pid>. Get the PID from a read-only process listing or a port lookup. If a broad kill is genuinely intended, run it yourself.')
            exit 2
        }
    }

    if ($blockMsg) {
        [Console]::Error.WriteLine("BLOCKED by security backstop hook: $blockMsg. This operation is catastrophic or irreversible in auto-approve mode. If you truly intend it, run it yourself.")
        exit 2
    }

    exit 0
}
catch {
    # Fail open: never wedge a session on a hook bug.
    exit 0
}
