#requires -Version 5.1
# ~/.claude/hooks/grill_gate.ps1 -- the enforcement half of the grill-me skill: interview before you build.
#
# Registered for TWO hook events; the event name in the JSON input picks the path:
#   UserPromptSubmit  -- if the prompt reads like a build kickoff ("build me a dashboard", "set up a new skill")
#                        and this session has not interviewed yet, drop a .pending flag and print a reminder
#                        (stdout on this event is added to the model's context). Never blocks.
#   PreToolUse (Write|Edit|MultiEdit|NotebookEdit) -- if a .pending flag exists and the transcript still shows
#                        no AskUserQuestion call and no grill-me Skill call, block ONCE (exit 2) with the reminder.
#                        Re-issuing the same call passes (block-once), so a real edit or fix is never stuck.
# Never gated: CHECKPOINT.md and scratchpad/temp writes; prompts that opt out ("just build it", "no questions",
# "already grilled", "skip the grill"); slash-command prompts; subagent calls (agent_id/agent_type present).
# Why two halves: the reminder alone is advice a model can skip; the write block is what makes it stick.
# State: %TEMP%\claude_grill_gate\<session>.{pending,advised,blocked,done}; files older than 7 days are swept.
# Fails OPEN (exit 0) on any error so a gate bug can never wedge a session.
# Shared re-issue with orient_gate.ps1: both gates block once and both say "re-issue this exact call". The
# .blocked file holds the blocked call's key (tool|path). When orient_gate's flag holds this exact call's key and
# was written 2-120 seconds ago, the call in hand is orient_gate's re-issue, so this gate passes it with its
# reminder as additionalContext and spends its once-flag instead of blocking the same call a second time.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    $event = "$($j.hook_event_name)"
    $tool  = "$($j.tool_name)"
    $tp    = "$($j.transcript_path)"
    $sid   = "$($j.session_id)"
    if ([string]::IsNullOrWhiteSpace($sid)) { $sid = 'nosession' }

    # Subagent calls carry an agent marker; the interview belongs to the parent session, so never gate them.
    if ($j.PSObject.Properties.Name -contains 'agent_id' -or $j.PSObject.Properties.Name -contains 'agent_type') { exit 0 }

    $dir = Join-Path $env:TEMP 'claude_grill_gate'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
    $safe    = ($sid -replace '[^A-Za-z0-9-]', '_')
    $pending = Join-Path $dir "$safe.pending"
    $advised = Join-Path $dir "$safe.advised"
    $blocked = Join-Path $dir "$safe.blocked"
    $done    = Join-Path $dir "$safe.done"

    # Has this session already interviewed? (an AskUserQuestion tool_use or a grill-me Skill call in the transcript)
    function Test-Grilled {
        param([string]$TranscriptPath)
        if ([string]::IsNullOrWhiteSpace($TranscriptPath) -or -not (Test-Path -LiteralPath $TranscriptPath)) { return $false }
        $hit = Select-String -LiteralPath $TranscriptPath -Pattern '"name":\s*"AskUserQuestion"|"skill":\s*"grill-me"|"name":\s*"Skill"[^}]{0,200}grill-me' -List -ErrorAction SilentlyContinue
        return [bool]$hit
    }

    if (Test-Path -LiteralPath $done) { exit 0 }
    if (Test-Grilled $tp) {
        New-Item -ItemType File -Path $done -Force | Out-Null
        Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue
        exit 0
    }

    # ---------------------------------------------------------------- UserPromptSubmit
    if ($event -eq 'UserPromptSubmit') {
        $p = "$($j.prompt)"
        if ([string]::IsNullOrWhiteSpace($p)) { exit 0 }
        $t = $p.Trim()
        if ($t.StartsWith('/')) { exit 0 }
        if ($t.Length -lt 25) { exit 0 }
        # Harness-generated turns also arrive through UserPromptSubmit (subagent completion notices, system
        # reminders, local-command blocks), and their text can read like a kickoff. They are not the user.
        if ($t -match '^(<system-reminder>|<task-notification>|\[SYSTEM NOTIFICATION|<local-command|<command-name>)') { exit 0 }
        if ($t -match '<task-notification>') { exit 0 }
        $optOut = '(?i)\b(just build it|just do it|no questions|don''t ask|do not ask|without asking|skip the grill|already grilled|already specced|spec already exists|continue where|pick up where)\b'
        if ($t -match $optOut) { exit 0 }

        $objects = '(app|apps|skill|skills|hook|hooks|dashboard|deck|tool|tools|script|scripts|automation|automations|pipeline|workflow|workflows|feature|features|system|site|website|page|bot|agent|agents|command|commands|integration|server|mcp|plugin|extension|tracker|planner|monitor|scraper|crawler|launcher|widget|widgets|report|template|framework|harness|gate|game|guide|spec|specs|plan|plans|roadmap|schema|database|table|form|calendar|notifier|convention|milestone|project|projects|implementation|prototype|mvp|v1|version)'
        $verbs = '(build|building|implement|implementing|create|creating|design|designing|develop|developing|scaffold|scaffolding|prototype|prototyping|set ?up|setting ?up|stand ?up|spin ?up|make|making|write|writing|draft|drafting|architect|wire ?up|automate|automating|ship|shipping|launch|launching)'
        $kick = $false
        if ($t -match "(?i)\b$verbs\b[^.!?\n]{0,60}\b$objects\b") { $kick = $true }
        if ($t -match "(?i)\b(new|fresh|greenfield)\s+(workspace\s+)?$objects\b") { $kick = $true }
        if ($t -match '(?i)\b(from scratch|kick(ing)? off|kick-off|first (implementation|pass|version|cut|draft)|deep implementation|workspace[- ]wide implementation|new session for|start(ing)? (a|the) new|i want (you to )?(build|make|create|design|implement)|we need (a|an|to build|to implement|to create))\b') { $kick = $true }
        if (-not $kick) { exit 0 }

        Set-Content -LiteralPath $pending -Value ($t.Substring(0, [Math]::Min(200, $t.Length))) -Encoding UTF8
        if (-not (Test-Path -LiteralPath $advised)) {
            New-Item -ItemType File -Path $advised -Force | Out-Null
            Write-Output '[grill-gate] This prompt reads like a build kickoff or first implementation. Run the grill-me interview BEFORE building: invoke the grill-me skill, ask 4-6 numbered questions per round (AskUserQuestion where the answers are a short list), never ask what CHECKPOINT.md / CLAUDE.md already answer, then write the Build spec to a file. If the user already answered everything in this prompt, say so in one line and write the Build spec anyway. If this is a continuation of already-specced work, an edit, a fix, or an unattended session, ignore this line. The first non-CHECKPOINT Write/Edit will be blocked once if no interview has happened.'
        }
        exit 0
    }

    # ---------------------------------------------------------------- PreToolUse (writes)
    if ($event -ne 'PreToolUse') { exit 0 }
    if ($tool -notin @('Write', 'Edit', 'MultiEdit', 'NotebookEdit')) { exit 0 }
    if (-not (Test-Path -LiteralPath $pending)) { exit 0 }
    if (Test-Path -LiteralPath $blocked) { exit 0 }

    $fp = [string]$j.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($fp)) { $fp = [string]$j.tool_input.notebook_path }
    if ($fp -match '(?i)CHECKPOINT\.md$') { exit 0 }
    if ($fp -match '(?i)[\\/](scratchpad|Temp|tmp)[\\/]') { exit 0 }

    $key = $tool + '|' + $fp
    if ($key.Length -gt 400) { $key = $key.Substring(0, 400) }
    $why = ''
    try { $why = (Get-Content -LiteralPath $pending -ErrorAction SilentlyContinue | Select-Object -First 1) } catch {}
    $msg = "[grill-gate] BLOCKED ONCE: this session opened with a build-kickoff prompt (" + $why + ") and no interview has happened -- no AskUserQuestion call and no grill-me Skill call in the transcript. " +
           'Grill BEFORE you build. Invoke the grill-me skill now: 2-3 rounds of 4-6 numbered questions (AskUserQuestion for short-list answers), skipping anything CHECKPOINT.md / CLAUDE.md already answer, then write the Build spec into a spec file or CHECKPOINT.md and build. ' +
           'If you have genuinely judged this an edit/fix/continuation, an unattended session, or the user said to skip it, re-issue this exact call -- the gate fires only once per session.'

    # Re-issue of a call orient_gate just blocked -> pass it with the reminder instead of a second block.
    $orientFlag = Join-Path $env:TEMP ('orient_gate_' + ($sid -replace '[^A-Za-z0-9_-]', '_') + '.flag')
    if (Test-Path -LiteralPath $orientFlag) {
        $age = ((Get-Date) - (Get-Item -LiteralPath $orientFlag).LastWriteTime).TotalSeconds
        $other = ''
        try { $other = ([IO.File]::ReadAllText($orientFlag)).Trim() } catch {}
        if ($age -ge 2 -and $age -le 120 -and $other -eq $key) {
            Set-Content -LiteralPath $blocked -Value $key -Encoding UTF8
            $ctx = $msg.Replace('[grill-gate] BLOCKED ONCE: ', '[grill-gate] NOT BLOCKED (orient_gate already stopped this call once): ')
            Write-Output (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $ctx } } | ConvertTo-Json -Compress -Depth 4)
            exit 0
        }
    }

    Set-Content -LiteralPath $blocked -Value $key -Encoding UTF8
    [Console]::Error.WriteLine($msg)
    exit 2
}
catch {
    exit 0
}
