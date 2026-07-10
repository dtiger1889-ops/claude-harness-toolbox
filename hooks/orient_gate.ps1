# ~/.claude/hooks/orient_gate.ps1
# Blocks (exit 2) the FIRST world-changing action of a session until CHECKPOINT.md has
# been read this session, then allows (block-once). Read/Grep/Glob are never gated.
# Fails OPEN (exit 0) on any error so a gate bug can never wedge a session.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    $tool = "$($j.tool_name)"; $cwd = "$($j.cwd)"
    $tp = "$($j.transcript_path)"; $sid = "$($j.session_id)"

    $coreGated = @('Write','Edit','MultiEdit','NotebookEdit','Bash','PowerShell','WebSearch','WebFetch')
    $isGated = $false
    if ($coreGated -contains $tool) { $isGated = $true }
    elseif ($tool -like 'mcp__*') {
        $method = ($tool -split '__')[-1]
        if ($method -match '^(create|update|delete|add|send|set|fill|apply|save|submit|publish|archive|log|rebuild|respond|upload|insert|remove|patch|write|draft|move|copy)([_]|$)') { $isGated = $true }
    }
    if (-not $isGated) { exit 0 }

    # If no CHECKPOINT.md at or above cwd, nothing to orient against -> never block.
    $hasCp = $false; $dir = $cwd
    while (-not [string]::IsNullOrEmpty($dir)) {
        if (Test-Path -LiteralPath (Join-Path $dir 'CHECKPOINT.md')) { $hasCp = $true; break }
        $parent = Split-Path -LiteralPath $dir -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    if (-not $hasCp) { exit 0 }

    # Already read a CHECKPOINT.md this session?
    if (-not [string]::IsNullOrEmpty($tp) -and (Test-Path -LiteralPath $tp)) {
        if (Select-String -LiteralPath $tp -Pattern '"name":\s*"Read".*CHECKPOINT\.md' -List -ErrorAction SilentlyContinue) { exit 0 }
    }

    # Block-once: if we already nudged this session, allow (preserves the one-shot escape).
    $safeSid = ($sid -replace '[^A-Za-z0-9_-]','_')
    $flag = Join-Path $env:TEMP ("orient_gate_" + $safeSid + ".flag")
    if (Test-Path -LiteralPath $flag) { exit 0 }
    try { Set-Content -LiteralPath $flag -Value '1' -ErrorAction SilentlyContinue } catch {}
    [Console]::Error.WriteLine("ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action (" + $tool + "). FIRST Read the project's CHECKPOINT.md to EOF and follow its Open threads / Next step. If you have genuinely judged this a pre-oriented one-shot, just re-issue this exact call -- the gate fires only once per session.")
    exit 2
}
catch { exit 0 }
