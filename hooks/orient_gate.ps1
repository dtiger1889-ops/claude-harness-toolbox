#requires -Version 5.1
# ~/.claude/hooks/orient_gate.ps1 -- PreToolUse orientation gate.
# Blocks (exit 2) every world-changing action of a session until the project's CHECKPOINT.md
# has been read this session. Read/Grep/Glob and read-ish MCP methods are never gated: the
# model must stay free to orient. Fails OPEN (exit 0) on any error so a gate bug can never
# wedge a session.
#
# What counts as "read": Read calls of the NEAREST CHECKPOINT.md (at or above cwd), each with
# a successful tool_result, whose line ranges together cover the whole file, anywhere after the
# session's last /clear (a Read before a compaction still counts). So an errored Read, a
# one-chunk partial Read, a Read of another project's CHECKPOINT.md or of CHECKPOINT.md.bak
# does not orient.
#
# Re-issuing a blocked call does NOT pass by default: a self-judged "this is a one-shot, I can
# skip orientation" escape is the exact shortcut the gate exists to stop. To restore the older
# block-once behaviour (first unoriented call blocked, its re-issue allowed), set the user
# environment variable ORIENT_GATE_BLOCK_ONCE=1.
#
# Each block writes the call's key (tool|path-or-command) to %TEMP%\orient_gate_<sid>.flag.
# grill_gate.ps1 reads it: when it sees orient_gate's re-issue of the same call it passes it
# with its reminder instead of blocking a second time. In block-once mode this gate does the
# same for a call grill_gate just blocked (2-120 seconds ago; under 2 seconds = both gates saw
# the same call in parallel, so both block normally).

# ---------------------------------------------------------------- transcript helpers
function Get-TranscriptLines([string]$Path) {
    # The transcript's lines; empty when the path is empty, missing or unreadable. ReadWrite
    # sharing so a file Claude Code is still writing opens; line by line to stay cheap on a
    # large transcript.
    $empty = [string[]]@()
    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return ,$empty }
        $fs = New-Object System.IO.FileStream($Path, 'Open', 'Read', 'ReadWrite', 65536)
        $sr = New-Object System.IO.StreamReader($fs)
        $list = New-Object 'System.Collections.Generic.List[string]'
        try { while ($null -ne ($l = $sr.ReadLine())) { $list.Add($l) } } finally { $sr.Close() }
        return ,$list.ToArray()
    } catch { return ,$empty }
}

function Get-SessionStart([string[]]$Lines) {
    # Index of the first line after the last /clear user row; 0 when there is none.
    $clearTag = '<command-name>/clear</command-name>'
    for ($i = $Lines.Count - 1; $i -ge 0; $i--) {
        $l = $Lines[$i]
        if ($l.IndexOf($clearTag, [StringComparison]::Ordinal) -lt 0) { continue }
        if ($l.IndexOf('"type":"user"', [StringComparison]::Ordinal) -lt 0) { continue }
        if ($l.IndexOf('"isMeta":true', [StringComparison]::Ordinal) -ge 0) { continue }
        $r = $null
        try { $r = $l | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        if ("$($r.type)" -eq 'user' -and $r.message.content -is [string] -and $r.message.content.Contains($clearTag)) { return ($i + 1) }
    }
    return 0
}

function Get-ReadUses([string[]]$Lines, [int]$Start) {
    # Every Read tool_use at or after $Start whose line mentions CHECKPOINT.md (any case), as
    # @{ Index; Id; Input }. Matched on parsed JSON, so input key order does not matter.
    $out = New-Object System.Collections.ArrayList
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        $l = $Lines[$i]
        if ($l.IndexOf('"tool_use"', [StringComparison]::Ordinal) -lt 0) { continue }
        if ($l.IndexOf('"Read"', [StringComparison]::Ordinal) -lt 0) { continue }
        if ($l.IndexOf('CHECKPOINT.md', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $r = $null
        try { $r = $l | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $blocks = @()
        if ("$($r.type)" -eq 'tool_use') { $blocks = @($r) }
        elseif ($r.message -and $r.message.content -and $r.message.content -isnot [string]) { $blocks = @($r.message.content) }
        foreach ($b in $blocks) {
            if ($null -eq $b -or $b -is [string]) { continue }
            if ("$($b.type)" -eq 'tool_use' -and "$($b.name)" -ceq 'Read') { [void]$out.Add(@{ Index = $i; Id = "$($b.id)"; Input = $b.input }) }
        }
    }
    return ,$out.ToArray()
}

function Test-ToolResultOk([string[]]$Lines, [int]$From, [string]$ToolUseId) {
    # True when a tool_result for $ToolUseId sits after line $From and is not an error.
    if ([string]::IsNullOrWhiteSpace($ToolUseId)) { return $false }
    for ($i = [Math]::Max(0, $From + 1); $i -lt $Lines.Count; $i++) {
        $l = $Lines[$i]
        if ($l.IndexOf($ToolUseId, [StringComparison]::Ordinal) -lt 0) { continue }
        if ($l.IndexOf('"tool_result"', [StringComparison]::Ordinal) -lt 0) { continue }
        $r = $null
        try { $r = $l | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $blocks = @()
        if ("$($r.type)" -eq 'tool_result') { $blocks = @($r) }
        elseif ($r.message -and $r.message.content -and $r.message.content -isnot [string]) { $blocks = @($r.message.content) }
        foreach ($b in $blocks) {
            if ($null -eq $b -or $b -is [string]) { continue }
            if ("$($b.type)" -eq 'tool_result' -and "$($b.tool_use_id)" -ceq $ToolUseId) { return (-not ($b.is_error -eq $true)) }
        }
    }
    return $false
}

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
        # Gate MCP tools whose METHOD name (after the last __) starts with a write verb.
        $method = ($tool -split '__')[-1]
        if ($method -match '^(create|update|delete|add|send|set|fill|apply|save|submit|publish|archive|log|rebuild|respond|upload|insert|remove|patch|write|draft|move|copy)([_]|$)') { $isGated = $true }
    }
    if (-not $isGated) { exit 0 }

    # Nearest CHECKPOINT.md at or above cwd; none -> nothing to orient against -> never block.
    # Case-exact (a lower-case checkpoint.md is a note, not project state); -Force finds hidden files.
    $cpPath = ''; $dir = $cwd
    while (-not [string]::IsNullOrEmpty($dir)) {
        $hit = @(Get-ChildItem -LiteralPath $dir -Filter 'CHECKPOINT.md' -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ceq 'CHECKPOINT.md' })
        if ($hit.Count -gt 0) { $cpPath = $hit[0].FullName; break }
        # -Path, not -LiteralPath: Windows PowerShell 5.1 has no -LiteralPath + -Parent parameter
        # set, so that form throws and the gate would fail open in every project subfolder.
        $parent = Split-Path -Path $dir -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    if (-not $cpPath) { exit 0 }

    # Has this session read that CHECKPOINT.md, successfully and completely?
    # A missing or unreadable transcript gives no lines, so the call is blocked below.
    $oriented = $false
    $lines = Get-TranscriptLines $tp
    if ($lines.Count -gt 0) {
        $want = [IO.Path]::GetFullPath($cpPath)
        $ranges = New-Object System.Collections.ArrayList
        foreach ($u in (Get-ReadUses $lines (Get-SessionStart $lines))) {
            $fp = "$($u.Input.file_path)"
            if ([string]::IsNullOrWhiteSpace($fp)) { continue }
            $full = ''
            try { $full = [IO.Path]::GetFullPath($fp) } catch { continue }
            if (-not [string]::Equals($full, $want, [StringComparison]::OrdinalIgnoreCase)) { continue }
            if (-not (Test-ToolResultOk $lines $u.Index $u.Id)) { continue }
            # Range [offset, offset+limit-1]; offset defaults to 1, a missing limit means the
            # Read tool's default of 2000 lines.
            [long]$off = 1; [long]$end = 0
            try {
                if ($null -ne $u.Input.offset) { $off = [Math]::Max([long]1, [long]$u.Input.offset) }
                $end = $off + 2000 - 1
                if ($null -ne $u.Input.limit) { $end = $off + [long]$u.Input.limit - 1 }
            } catch { continue }
            [void]$ranges.Add([pscustomobject]@{ S = $off; E = $end })
        }
        if ($ranges.Count -gt 0) {
            [long]$total = ([IO.File]::ReadAllLines($cpPath)).Count
            [long]$next = 1   # first line not yet covered
            foreach ($rg in @($ranges | Sort-Object S)) {
                if ($rg.S -gt $next) { break }
                if ($rg.E -ge $total) { $next = $total + 1; break }
                if ($rg.E -ge $next) { $next = $rg.E + 1 }
            }
            if ($next -gt $total) { $oriented = $true }
        }
    }
    if ($oriented) { exit 0 }

    $blockOnce = ("$env:ORIENT_GATE_BLOCK_ONCE" -eq '1')
    $safeSid = ($sid -replace '[^A-Za-z0-9_-]','_')
    $flag = Join-Path $env:TEMP ("orient_gate_" + $safeSid + ".flag")
    if ($blockOnce -and (Test-Path -LiteralPath $flag)) { exit 0 }

    # Key of the call in hand (same formula as grill_gate.ps1).
    $ti = $j.tool_input; $target = ''
    foreach ($k in 'file_path', 'notebook_path', 'command', 'url', 'query') {
        if ($ti -and -not [string]::IsNullOrWhiteSpace([string]$ti.$k)) { $target = [string]$ti.$k; break }
    }
    $key = $tool + '|' + $target
    if ($key.Length -gt 400) { $key = $key.Substring(0, 400) }

    if ($blockOnce) {
        $msg = "ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action (" + $tool + "). FIRST Read the project's CHECKPOINT.md to EOF and follow its Open threads / Next step. If you have genuinely judged this a pre-oriented one-shot, just re-issue this exact call -- the gate fires only once per session."
        # Re-issue of a call grill_gate just blocked -> pass it with this note instead of a second block.
        $grillSafe = if ([string]::IsNullOrWhiteSpace($sid)) { 'nosession' } else { ($sid -replace '[^A-Za-z0-9-]', '_') }
        $grillBlocked = Join-Path (Join-Path $env:TEMP 'claude_grill_gate') ($grillSafe + '.blocked')
        if (Test-Path -LiteralPath $grillBlocked) {
            $age = ((Get-Date) - (Get-Item -LiteralPath $grillBlocked).LastWriteTime).TotalSeconds
            $other = ''
            try { $other = ([IO.File]::ReadAllText($grillBlocked)).Trim() } catch {}
            if ($age -ge 2 -and $age -le 120 -and $other -eq $key) {
                try { Set-Content -LiteralPath $flag -Value $key -ErrorAction SilentlyContinue } catch {}
                $ctx = $msg.Replace('just re-issue this exact call -- the gate fires only once per session.', 'carry on: this call was let through because grill_gate already stopped it once, and this gate will not fire again this session.')
                Write-Output (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $ctx } } | ConvertTo-Json -Compress -Depth 4)
                exit 0
            }
        }
    }
    else {
        $msg = "ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action (" + $tool + "). FIRST Read the project's CHECKPOINT.md to EOF (every line, with as many offset/limit Reads as it takes) and follow its pointers (Open threads, Files that matter, Next step). There is no exemption and re-issuing does not pass: this gate blocks every such call until that Read."
    }

    try { Set-Content -LiteralPath $flag -Value $key -ErrorAction SilentlyContinue } catch {}
    [Console]::Error.WriteLine($msg)
    exit 2
}
catch {
    # Fail open: never wedge a session on a gate bug.
    exit 0
}
