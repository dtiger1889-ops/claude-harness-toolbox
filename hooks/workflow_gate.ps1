# PreToolUse WORKFLOW RUNAWAY GUARD (Windows/PowerShell).
#
# Blocks (exit 2) the FIRST Workflow tool call of a session, prints the runaway rules at
# the exact moment they matter, then allows (block-once; re-issuing the same call
# proceeds). Fails OPEN (exit 0) on any error so a gate bug can never wedge a session.
#
# WHY: Claude Code's Workflow tool does NOT stop itself when your session or rate limit
# is hit -- queued agents keep firing as limit windows reset. One observed run burned 267
# agents / ~5M tokens unattended. A prose rule in CLAUDE.md has to survive in the model's
# attention from session start until a rare Workflow call maybe hours later; this hook
# fires at the exact moment instead ("enforce structurally what prose can't"). This is
# also the pattern to copy for any rule of the shape "when you use tool X, remember Y":
# match tool X, block once with Y as the message, let the re-issue through.
#
# INSTALL: wire under PreToolUse with matcher "Workflow" (see settings-windows.example.json).
# Non-Windows: port is trivial -- read stdin JSON, check tool_name, flag-file in $TMPDIR,
# echo to stderr, exit 2 (orient_gate.sh in this folder shows the bash shape).

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    if ("$($j.tool_name)" -ne 'Workflow') { exit 0 }

    # --- Block-once: if we already nudged this session, allow. ---
    $sid = "$($j.session_id)"
    $safeSid = ($sid -replace '[^A-Za-z0-9_-]','_')
    $flag = Join-Path $env:TEMP ("workflow_gate_" + $safeSid + ".flag")
    if (Test-Path -LiteralPath $flag) { exit 0 }

    try { Set-Content -LiteralPath $flag -Value '1' -ErrorAction SilentlyContinue } catch {}
    [Console]::Error.WriteLine("WORKFLOW RUNAWAY GUARD (fires once per session): the Workflow tool does NOT stop itself on session/rate limits -- queued agents keep firing as limit windows reset (one observed run: 267 agents, ~5M tokens unattended). Before re-issuing, verify the script conforms: (1) any multi-round / loop-until / fan-out workflow ABORTS the whole run on the FIRST agent() session-limit or rate-limit error -- wrap rounds so the error breaks the loop and log()s why, never swallowed as null; (2) total agents and budget are capped explicitly -- never rely on the 1000-agent backstop. If the script already conforms, re-issue this exact call to proceed.")
    exit 2
}
catch {
    # Fail open: never wedge a session on a gate bug.
    exit 0
}
