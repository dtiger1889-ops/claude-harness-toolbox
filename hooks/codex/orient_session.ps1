# Codex SessionStart orientation receipt.
# Resolves the nearest project CLAUDE.md and CHECKPOINT.md from cwd (optionally falling back to
# the folder named by HARNESS_WORKSPACE_ROOT for sessions started outside any project), clears
# this session's orient_gate.ps1 flags, and adds a developer-context receipt naming the files.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $event = $raw | ConvertFrom-Json

    $cwd = [string]$event.cwd
    $source = [string]$event.source
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

    $claudePath = Find-Upward -StartPath $cwd -FileName 'CLAUDE.md'
    $checkpointPath = Find-Upward -StartPath $cwd -FileName 'CHECKPOINT.md'

    if (-not [string]::IsNullOrWhiteSpace($workspaceRoot)) {
        if ([string]::IsNullOrWhiteSpace($claudePath)) {
            $fallbackClaude = Join-Path $workspaceRoot 'CLAUDE.md'
            if (Test-Path -LiteralPath $fallbackClaude) {
                $claudePath = $fallbackClaude
            }
        }
        if ([string]::IsNullOrWhiteSpace($checkpointPath)) {
            $fallbackCheckpoint = Join-Path $workspaceRoot 'CHECKPOINT.md'
            if (Test-Path -LiteralPath $fallbackCheckpoint) {
                $checkpointPath = $fallbackCheckpoint
            }
        }
    }

    $safeSessionId = $sessionId -replace '[^A-Za-z0-9_-]', '_'
    foreach ($kind in @('claude', 'checkpoint')) {
        $flagPath = Join-Path ([System.IO.Path]::GetTempPath()) ("codex_orient_{0}.{1}.flag" -f $safeSessionId, $kind)
        Remove-Item -LiteralPath $flagPath -Force -ErrorAction SilentlyContinue
    }

    $required = @()
    if (-not [string]::IsNullOrWhiteSpace($claudePath)) {
        $required += "CLAUDE guidance: $claudePath"
    }
    if (-not [string]::IsNullOrWhiteSpace($checkpointPath)) {
        $required += "CHECKPOINT state: $checkpointPath"
    }
    if ($required.Count -eq 0) { exit 0 }

    $context = @(
        "CODEX ORIENTATION RECEIPT (source: $source)."
        'Before any non-orientation action, read every required file below to EOF and follow its routing, current-state, and next-step instructions:'
        ($required -join "`n")
        'Use the exact absolute paths above. A truncated or partial read does not count; continue with targeted reads until EOF.'
        'This requirement applies again after resume, clear, and compaction so durable project state wins over a stale conversation summary.'
    ) -join "`n"

    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $context
        }
    } | ConvertTo-Json -Depth 4 -Compress
}
catch {
    @{
        systemMessage = ('Codex orientation receipt failed: ' + $_.Exception.Message + ' Manually read the project CLAUDE.md and CHECKPOINT.md before acting.')
    } | ConvertTo-Json -Compress
}
