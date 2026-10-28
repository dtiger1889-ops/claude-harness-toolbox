# Codex PreToolUse orientation gate (a reminder gate, not proof of a full read).
# Blocks local actions (exit 2 with the reason on stderr, which is the blocking contract in the
# Codex hooks docs) until this session has run a read command that NAMES the resolved CLAUDE.md
# and the resolved CHECKPOINT.md. The read commands themselves stay allowed, so there is no
# circular block. It records read REQUESTS; it cannot see whether the read reached EOF.
#
# Codex reports shell commands (PowerShell ones too) as tool_name "Bash" with tool_input.command.
# Set HARNESS_WORKSPACE_ROOT to a folder holding a CLAUDE.md and CHECKPOINT.md if you want a
# fallback for sessions started outside any project; unset, there is no fallback.
# Per-session flags live in %TEMP%; orient_session.ps1 (SessionStart) clears them.
# Fails open: any script error exits 0 so a hook bug cannot wedge Codex.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $event = $raw | ConvertFrom-Json

    $tool = [string]$event.tool_name
    $command = [string]$event.tool_input.command
    $cwd = [string]$event.cwd
    $sessionId = [string]$event.session_id
    $workspaceRoot = [string]$env:HARNESS_WORKSPACE_ROOT

    function Find-Upward {
        param(
            [string]$StartPath,
            [string]$FileName
        )

        $dir = $StartPath
        while (-not [string]::IsNullOrWhiteSpace($dir)) {
            $candidate = Join-Path $dir $FileName
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }

            $parent = Split-Path -Path $dir -Parent
            if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
                break
            }
            $dir = $parent
        }
        return $null
    }

    function Get-NormalPath {
        param([string]$Path, [string]$BaseDir)
        try {
            $p = $Path.Trim().Trim("'", '"')
            if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $BaseDir $p }
            return [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/')
        }
        catch { return $null }
    }

    $claudePath = Find-Upward -StartPath $cwd -FileName 'CLAUDE.md'
    $checkpointPath = Find-Upward -StartPath $cwd -FileName 'CHECKPOINT.md'
    if (-not [string]::IsNullOrWhiteSpace($workspaceRoot)) {
        if ([string]::IsNullOrWhiteSpace($claudePath)) {
            $candidate = Join-Path $workspaceRoot 'CLAUDE.md'
            if (Test-Path -LiteralPath $candidate) { $claudePath = $candidate }
        }
        if ([string]::IsNullOrWhiteSpace($checkpointPath)) {
            $candidate = Join-Path $workspaceRoot 'CHECKPOINT.md'
            if (Test-Path -LiteralPath $candidate) { $checkpointPath = $candidate }
        }
    }
    if ([string]::IsNullOrWhiteSpace($claudePath) -and [string]::IsNullOrWhiteSpace($checkpointPath)) {
        exit 0
    }

    $safeSessionId = $sessionId -replace '[^A-Za-z0-9_-]', '_'
    $tempRoot = [System.IO.Path]::GetTempPath()
    $claudeFlag = Join-Path $tempRoot ("codex_orient_{0}.claude.flag" -f $safeSessionId)
    $checkpointFlag = Join-Path $tempRoot ("codex_orient_{0}.checkpoint.flag" -f $safeSessionId)

    # Allow the orientation reads themselves and record that they were requested. A read only
    # counts when a path in the command resolves to the required file (absolute, or relative to cwd).
    if ($tool -eq 'Bash') {
        $looksLikeRead = $command -match '(?i)\b(Get-Content|gc|cat|Select-String|sls|type|more|rg)\b'
        if ($looksLikeRead) {
            $named = @()
            $rest = $command
            # Absolute paths first (they may contain spaces), then relative tokens in what is left.
            foreach ($m in [regex]::Matches($command, '(?i)[A-Za-z]:[\\/][^''"`;|<>\r\n]*?(?:CLAUDE|CHECKPOINT)\.md\b')) {
                $named += $m.Value
                $rest = $rest.Replace($m.Value, ' ')
            }
            foreach ($m in [regex]::Matches($rest, '(?i)[^\s''"`;|&<>()=,]*(?:CLAUDE|CHECKPOINT)\.md\b')) {
                $named += $m.Value
            }
            $claudeNorm = if ($claudePath) { Get-NormalPath $claudePath $cwd } else { $null }
            $checkpointNorm = if ($checkpointPath) { Get-NormalPath $checkpointPath $cwd } else { $null }
            $matchedAny = $false
            foreach ($n in $named) {
                $norm = Get-NormalPath $n $cwd
                if (-not $norm) { continue }
                if ($claudeNorm -and ($norm -ieq $claudeNorm)) {
                    Set-Content -LiteralPath $claudeFlag -Value 'requested' -ErrorAction SilentlyContinue
                    $matchedAny = $true
                }
                if ($checkpointNorm -and ($norm -ieq $checkpointNorm)) {
                    Set-Content -LiteralPath $checkpointFlag -Value 'requested' -ErrorAction SilentlyContinue
                    $matchedAny = $true
                }
            }
            if ($matchedAny) { exit 0 }
        }
    }

    $claudeReady = [string]::IsNullOrWhiteSpace($claudePath) -or (Test-Path -LiteralPath $claudeFlag)
    $checkpointReady = [string]::IsNullOrWhiteSpace($checkpointPath) -or (Test-Path -LiteralPath $checkpointFlag)
    if ($claudeReady -and $checkpointReady) { exit 0 }

    $missing = @()
    if (-not $claudeReady) { $missing += $claudePath }
    if (-not $checkpointReady) { $missing += $checkpointPath }
    $reason = 'ORIENTATION GATE: before this action, read the following durable workspace files to EOF: ' + ($missing -join '; ')
    [Console]::Error.WriteLine($reason)
    exit 2
}
catch {
    # Fail open so a hook bug cannot wedge Codex.
    exit 0
}
