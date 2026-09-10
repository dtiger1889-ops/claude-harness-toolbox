# sort_open_threads.ps1 -- put a CHECKPOINT's "## Open threads" bullets into the four-run order
# mechanically: [owner] [low], [owner] [high], [agent] [low], [agent] [high]. Bullets with no
# tag pair keep their relative order and go last. Sub-bullets and
# continuation lines travel with their parent. The prose above the first bullet stays in place.
# The two optional bold sub-headers (**Owner-gated** / **Agent-side**) are regenerated only if
# the file already used them. Stable sort: within a run nothing moves.
#
#   & sort_open_threads.ps1 -Checkpoint <path>            # rewrites the file in place
#   & sort_open_threads.ps1 -Checkpoint <path> -DryRun    # prints the sorted section, writes nothing
#
# Exit 0 always (a sort must never break a close); prints what it did.
param(
    [Parameter(Mandatory = $true)][string]$Checkpoint,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Checkpoint)) { Write-Output "[sort-threads] not found: $Checkpoint"; exit 0 }

$raw = [IO.File]::ReadAllText($Checkpoint)
$nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $raw -split "`r?`n"

# --- locate the section ---------------------------------------------------------------
$start = -1; $end = $lines.Count
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($start -lt 0) { if ($lines[$i] -match '^##\s+Open threads') { $start = $i } ; continue }
    if ($lines[$i] -match '^##\s') { $end = $i; break }
}
if ($start -lt 0) { Write-Output "[sort-threads] no '## Open threads' section"; exit 0 }
$body = $lines[($start + 1)..($end - 1)]

# Guard (added after a real scramble): a project that groups its threads
# under its OWN sub-headers (**Backups**, ### Live, ...) is not sorted at all. Sorting would glue
# each header to a random bullet or float it to the top, silently. Refuse + warn instead;
# the file keeps its layout until the headers are removed or the convention grows a category rule.
$foreign = @($body | Where-Object { ($_ -match '^\*\*[^*]+\*\*\s*$' -or $_ -match '^#{2,}\s') -and $_ -notmatch '^\*\*(Owner-gated|Agent-side)\*\*\s*$' })
if ($foreign.Count -gt 0) {
    Write-Output "[sort-threads] NOT SORTED: Open threads carries $($foreign.Count) sub-header(s) the convention does not define ($($foreign -join ' | ')). Remove them or keep the file hand-ordered."
    exit 0
}

# --- split into preamble, headers, items ---------------------------------------------
$preamble = New-Object System.Collections.Generic.List[string]
$items = New-Object System.Collections.Generic.List[object]
$hadHeaders = $false
$cur = $null
foreach ($ln in $body) {
    if ($ln -match '^\*\*(Owner-gated|Agent-side)\*\*\s*$') { $hadHeaders = $true; $cur = $null; continue }
    if ($ln -match '^-\s') {
        $cur = [pscustomobject]@{ head = $ln; tail = (New-Object System.Collections.Generic.List[string]); rank = 99 }
        $items.Add($cur); continue
    }
    if ($null -eq $cur) {
        if ($items.Count -eq 0) { $preamble.Add($ln) }          # prose above the first bullet
        elseif ($ln.Trim().Length -gt 0) { $preamble.Add($ln) } # stray prose between runs: keep it, at the top
        continue
    }
    if ($ln.Trim().Length -eq 0) { $cur = $null; continue }      # blank line closes the item
    $cur.tail.Add($ln)                                          # sub-bullet / continuation
}
# trim trailing blank lines from the preamble
while ($preamble.Count -gt 0 -and $preamble[$preamble.Count - 1].Trim().Length -eq 0) { $preamble.RemoveAt($preamble.Count - 1) }

foreach ($it in $items) {
    # A bullet may wrap onto continuation lines; the pair sits at its TRUE end, so read the
    # whole item (sub-bullets carry no tags, so nothing there can mislead). Real bug this
    # fixes: a head-only read bucketed every wrapped bullet in one project as untagged.
    $h = (@($it.head) + @($it.tail)) -join ' '
    $gate = if ($h -match '\[owner\]') { 0 } elseif ($h -match '\[agent\]') { 1 } else { -1 }
    $cplx = if ($h -match '\[low\]') { 0 } elseif ($h -match '\[high\]') { 1 } else { -1 }
    $it.rank = if ($gate -lt 0 -or $cplx -lt 0) { 99 } else { $gate * 2 + $cplx }
}
$before = @($items | ForEach-Object { $_.head })
$sorted = @($items | Sort-Object -Property rank -Stable)
$after = @($sorted | ForEach-Object { $_.head })
$moved = 0
for ($i = 0; $i -lt $before.Count; $i++) { if ($before[$i] -ne $after[$i]) { $moved++ } }

# --- rebuild the section ---------------------------------------------------------------
$out = New-Object System.Collections.Generic.List[string]
$out.Add($lines[$start])
foreach ($p in $preamble) { $out.Add($p) }
$lastGate = -1
$needBlank = ($preamble.Count -gt 0)   # one blank line between the prose and the first bullet
foreach ($it in $sorted) {
    $g = if ($it.rank -eq 99) { 2 } else { [math]::Floor($it.rank / 2) }
    if ($hadHeaders -and $g -ne $lastGate -and $g -lt 2) {
        $out.Add('')
        $out.Add($(if ($g -eq 0) { '**Owner-gated**' } else { '**Agent-side**' }))
        $needBlank = $false
    } elseif ($needBlank) {
        $out.Add('')
        $needBlank = $false
    }
    $lastGate = $g
    $out.Add($it.head)
    foreach ($t in $it.tail) { $out.Add($t) }
}
$out.Add('')

$counts = @{}
foreach ($r in 0, 1, 2, 3, 99) { $counts[$r] = @($sorted | Where-Object { $_.rank -eq $r }).Count }
$summary = "[sort-threads] $($items.Count) bullets: owner-low $($counts[0]), owner-high $($counts[1]), agent-low $($counts[2]), agent-high $($counts[3]), untagged $($counts[99]); $moved bullet(s) changed position; headers=$hadHeaders"

if ($DryRun) {
    Write-Output $summary
    $out | ForEach-Object { Write-Output $_ }
    exit 0
}
if ($moved -eq 0 -and -not $hadHeaders) { Write-Output "$summary -- already in order, file untouched"; exit 0 }
$newLines = @()
if ($start -gt 0) { $newLines += $lines[0..($start - 1)] }
$newLines += $out
if ($end -lt $lines.Count) { $newLines += $lines[$end..($lines.Count - 1)] }
$text = ($newLines -join $nl)
if ($raw.EndsWith($nl) -and -not $text.EndsWith($nl)) { $text += $nl }
[IO.File]::WriteAllText($Checkpoint, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "$summary -- written"
exit 0
