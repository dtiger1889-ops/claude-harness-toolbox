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

    # Flags are keyed by session AND by the resolved file, so reading one project's files does not
    # release actions in another project during the same session.
    function Get-PathKey {
        param([string]$Path)
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant()))
        return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 12)
    }

    $safeSessionId = $sessionId -replace '[^A-Za-z0-9_-]', '_'
    $tempRoot = [System.IO.Path]::GetTempPath()
    $claudeNorm = if ($claudePath) { Get-NormalPath $claudePath $cwd } else { $null }
    $checkpointNorm = if ($checkpointPath) { Get-NormalPath $checkpointPath $cwd } else { $null }
    $claudeFlag = if ($claudeNorm) { Join-Path $tempRoot ("codex_orient_{0}.{1}.claude.flag" -f $safeSessionId, (Get-PathKey $claudeNorm)) } else { $null }
    $checkpointFlag = if ($checkpointNorm) { Join-Path $tempRoot ("codex_orient_{0}.{1}.checkpoint.flag" -f $safeSessionId, (Get-PathKey $checkpointNorm)) } else { $null }

    # Allow the orientation reads themselves and record that they were requested. The command is
    # split into segments (; | & and newlines). A segment counts as a read only when its FIRST word
    # is a read verb, and only the paths inside that segment count, resolved against cwd. The whole
    # call is let through as an orientation read only when every segment is a read or a pipeline
    # helper (Select-Object, Out-String, Measure-Object, head, tail), so a read chained to another
    # command, or read words inside a string (Write-Output 'cat CLAUDE.md'), never passes.
    if ($tool -eq 'Bash') {
        $readVerb = '(?i)^(Get-Content|gc|cat|Select-String|sls|type|more|rg|head|tail)$'
        $helperVerb = '(?i)^(Select-Object|select|Out-String|Measure-Object|head|tail|more)$'
        $segments = @($command -split '\|\||&&|[;|&\r\n]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $allReadish = $segments.Count -gt 0
        $matchedAny = $false
        foreach ($seg in $segments) {
            $first = ($seg -split '\s+', 2)[0]
            if ($first -notmatch $readVerb) {
                if ($first -notmatch $helperVerb) { $allReadish = $false }
                continue
            }
            $named = @()
            $rest = $seg
            # Absolute paths first (they may contain spaces), then relative tokens in what is left.
            foreach ($m in [regex]::Matches($seg, '(?i)[A-Za-z]:[\\/][^''"`;|<>\r\n]*?(?:CLAUDE|CHECKPOINT)\.md\b')) {
                $named += $m.Value
                $rest = $rest.Replace($m.Value, ' ')
            }
            foreach ($m in [regex]::Matches($rest, '(?i)[^\s''"`;|&<>()=,]*(?:CLAUDE|CHECKPOINT)\.md\b')) {
                $named += $m.Value
            }
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
        }
        if ($matchedAny -and $allReadish) { exit 0 }
    }

    $claudeReady = (-not $claudeFlag) -or (Test-Path -LiteralPath $claudeFlag)
    $checkpointReady = (-not $checkpointFlag) -or (Test-Path -LiteralPath $checkpointFlag)
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
