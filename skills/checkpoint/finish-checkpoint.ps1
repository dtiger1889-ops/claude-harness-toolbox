#requires -Version 5.1
<#
.SYNOPSIS
  One-call session close for a CHECKPOINT.md: stamp `Last updated:` with real UTC
  and report line/byte counts against the 120-line / ~30KB caps.

.DESCRIPTION
  Collapses the /checkpoint skill's former steps 5-6 measurement (three separate
  PowerShell round-trips: UtcNow, Get-Content count, Get-Item length) into ONE
  invocation. The script rewrites the `Last updated:` line itself -- the model
  never transcribes a timestamp -- preserving an existing bare `(vN)` tag, the
  file's newline convention, and UTF-8-without-BOM encoding. Everything except
  that one line is written back byte-identical.

  Exit 0 = stamped + under both caps. Exit 2 = stamped but OVER a cap (the
  caller must run the archiver / compress per skill step 6). Exit 1 = refused
  (file missing, or no `Last updated:` line found in the first 5 lines -- in
  that case nothing is written).

.PARAMETER Checkpoint  Path to the CHECKPOINT.md to stamp + measure.
.PARAMETER KeepNewest  Changelog entries to keep inline when auto-archiving (default 2).
.PARAMETER NoAutoArchive  Report over-cap only; do not archive (old behavior).

.NOTES
  AUTO-ARCHIVE: when the file is over a cap and has a `## Harness changelog`
  section with more than -KeepNewest `### ` entries, this script computes the
  cut range itself (keep newest N, move the rest) and calls archive-changelog.ps1
  to do the byte-verbatim move -- the caller never picks line numbers. It then
  ensures the standard `Older entries:` pointer line and re-measures. If the file
  is still over cap after archiving (bloated live sections), that remainder is
  the caller's to compress -- exit 2.

.EXAMPLE
  & ~/.claude/skills/checkpoint/finish-checkpoint.ps1 -Checkpoint ./CHECKPOINT.md
#>
param(
  [Parameter(Mandatory)][string]$Checkpoint,
  [int]$KeepNewest = 2,
  [switch]$NoAutoArchive,
  [switch]$NoSort
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Checkpoint)) {
  # Write-Output, not Write-Error: under $ErrorActionPreference='Stop' a Write-Error
  # throws before `exit 1` runs, leaving the caller a stale $LASTEXITCODE.
  Write-Output "[finish-checkpoint] REFUSED: not found: $Checkpoint"
  exit 1
}

# Four-run sort of Open threads BEFORE the stamp (adopted after a hand-sort vs script-sort
# A/B): order is produced at every close, never maintained by hand. The sorter
# only reorders top-level bullets that carry the [owner]/[agent] + [low]/[high] pair,
# keeps untagged ones where they are, and never fails a close (-NoSort skips it).
if (-not $NoSort) {
  try {
    & (Join-Path $PSScriptRoot 'sort_open_threads.ps1') -Checkpoint $Checkpoint 2>&1 | ForEach-Object { Write-Output "$_" }
  } catch {
    Write-Output "[finish-checkpoint] sort skipped ($($_.Exception.Message))"
  }
}

function Invoke-IoRetry([scriptblock]$op, [string]$what) {
  # Mirror of archive-changelog.ps1's helper (added 2026-07-30 after a real FAIL logged as
  # "cannot be performed on a file with a user-mapped section open"). These files sit on a
  # Drive-synced / Defender-scanned / Search-indexed tree, so another process can hold the
  # target open or memory-mapped for a few seconds. Both directions break: a mapped section
  # blocks the truncating WRITE (ERROR_USER_MAPPED_FILE), an exclusive open blocks the READ
  # (sharing violation). Both are IOException and both clear on their own. ONLY IOException
  # retries -- UnauthorizedAccessException (ACL, read-only) is real and must fail fast.
  # NOTE: notices go to the WARNING stream on purpose. This helper's return value is
  # consumed (`$raw = Invoke-IoRetry {...}`), so a Write-Output here would be appended to
  # the caller's pipeline and silently corrupt that value into an array.
  $delaysMs = @(500, 1000, 2000, 4000, 8000)
  for ($a = 0; $a -le $delaysMs.Count; $a++) {
    try {
      $r = & $op
      if ($a -gt 0) { Write-Warning "[finish-checkpoint] transient lock cleared: $what succeeded on attempt $($a + 1)" }
      return $r
    } catch {
      # Unwrap PowerShell's MethodInvocationException so the type test sees the real cause.
      $ex = $_.Exception
      while ($ex.InnerException) { $ex = $ex.InnerException }
      if (($ex -isnot [System.IO.IOException]) -or ($a -eq $delaysMs.Count)) { throw }
      Write-Warning "[finish-checkpoint] locked by another process, retrying $what in $($delaysMs[$a]) ms"
      Start-Sleep -Milliseconds $delaysMs[$a]
    }
  }
}

function Write-Text([string]$path, [string]$body, $enc) {
  Invoke-IoRetry { [System.IO.File]::WriteAllText($path, $body, $enc) } "write of $path" | Out-Null
}

# Same EOL/encoding handling as archive-changelog.ps1: detect the file's newline
# convention, work line-wise, write back UTF-8 no-BOM with one trailing newline.
$raw   = Invoke-IoRetry { [System.IO.File]::ReadAllText($Checkpoint) } "read of $Checkpoint"
$nl    = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = Invoke-IoRetry { [System.IO.File]::ReadAllLines($Checkpoint) } "read of $Checkpoint"

$idx = -1
for ($i = 0; $i -lt [Math]::Min(5, $lines.Count); $i++) {
  if ($lines[$i] -match '^Last updated:') { $idx = $i; break }
}
if ($idx -lt 0) {
  Write-Output "[finish-checkpoint] REFUSED: no 'Last updated:' line in the first 5 lines of $Checkpoint -- nothing written"
  exit 1
}

$stamp = [System.DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm UTC')
$tag   = if ($lines[$idx] -match '\((v\d+)\)') { " ($($Matches[1]))" } else { '' }
$lines[$idx] = "Last updated: $stamp$tag"

$body = [string]::Join($nl, $lines) + $nl
$enc  = New-Object System.Text.UTF8Encoding($false)
Write-Text $Checkpoint $body $enc

function Measure-Cp([string]$path) {
  $l = Invoke-IoRetry { [System.IO.File]::ReadAllLines($path) } "read of $path"
  return @{ N = $l.Count; Bytes = (Get-Item -LiteralPath $path).Length; Lines = $l }
}

function Get-Section([string[]]$L, [string]$name) {
  # Content lines of `## <name>` up to the next `## ` heading (or EOF). Empty array if absent.
  $out = @(); $in = $false
  foreach ($ln in $L) {
    if ($ln -match "^## $([regex]::Escape($name))") { $in = $true; continue }
    if ($in -and $ln -match '^## ') { break }
    if ($in) { $out += $ln }
  }
  return $out
}

function Test-SectionBloat([string[]]$L) {
  # Live-section budgets (standing directive: "the changelog is the status" --
  # live sections are terse pointers, narrative belongs in the changelog. The numeric
  # thresholds are defaults executing that directive; tune them). The total-size
  # caps alone let live sections balloon while auto-archiving kept the FILE under cap;
  # a section with no enforcement signal drifts (same asymmetry as the verify step).
  $v = @()
  $s = @(Get-Section $L 'Status' | Where-Object { $_.Trim() -ne '' })
  if ($s.Count -gt 0) {
    $chars = (($s -join ' ')).Length
    if ($s.Count -gt 1 -or $chars -gt 300) {
      $v += "Status is $chars chars / $($s.Count) line(s) (budget: 1 line, ~300 chars) -- present state in ONE short sentence; past -> changelog, future -> Next step / Open threads"
    }
  }
  $g = @(Get-Section $L 'Goal' | Where-Object { $_.Trim() -ne '' })
  if ($g.Count -gt 3) { $v += "Goal is $($g.Count) lines (budget: 1-3 lines)" }
  $n = @(Get-Section $L 'Next step' | Where-Object { $_.Trim() -ne '' })
  if ($n.Count -gt 0) {
    $chars = (($n -join ' ')).Length
    if ($n.Count -gt 2 -or $chars -gt 350) {
      $v += "Next step is $chars chars / $($n.Count) line(s) (budget: <= 2 lines, ~350 chars) -- one declared shape (Action / HOLD / Pick), not a narrative"
    }
  }
  return ,$v
}

$m    = Measure-Cp $Checkpoint
$over = ($m.N -gt 120) -or ($m.Bytes -gt 30KB)
Write-Output "[finish-checkpoint] stamped: Last updated: $stamp$tag"
# EVERY run rewrites the file (the stamp), and the over-cap path rewrites it twice more.
# The caller is an agent holding a read snapshot from its own earlier Edits, so that
# snapshot is now stale and its next Edit is rejected ("File has been modified since
# read") -- which is exactly what step 6(b) compression asks it to do. Say so here.
Write-Output "[finish-checkpoint] NOTE: this script rewrote the file on disk. Re-Read it before your next Edit -- your read snapshot is stale and the Edit will otherwise be rejected."

if ($over -and -not $NoAutoArchive) {
  # --- Auto-archive: keep newest $KeepNewest changelog entries, move the rest ---
  $L = $m.Lines
  $clStart = -1
  for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i] -match '^## Harness changelog') { $clStart = $i; break } }
  if ($clStart -ge 0) {
    $secEnd = $L.Count                     # exclusive: next `## ` heading or EOF
    for ($i = $clStart + 1; $i -lt $L.Count; $i++) { if ($L[$i] -match '^## ') { $secEnd = $i; break } }
    $entries = @()                         # 0-based indices of `### ` headers, newest first
    $pointer = -1                          # 0-based index of the `Older entries:` line
    for ($i = $clStart + 1; $i -lt $secEnd; $i++) {
      if ($L[$i] -match '^### ')           { $entries += $i }
      if ($L[$i] -match '^Older entries:') { $pointer  = $i }
    }
    if ($entries.Count -gt $KeepNewest) {
      $cutFrom = $entries[$KeepNewest] + 1                                  # 1-based
      # The pointer line only bounds the cut when it sits BELOW the entries
      # (end-of-section layout). In the pointer-at-top layout (the workspace
      # standard: pointer directly under the heading, entries after), using it
      # produced an INVERTED range the mover refused (bug observed 2026-07-30).
      $cutToIdx = if ($pointer -gt $entries[$KeepNewest]) { $pointer - 1 } else { $secEnd - 1 } # 0-based
      $cutTo = $cutToIdx + 1                                                # 1-based
      $arc = Join-Path (Join-Path (Split-Path -Parent $Checkpoint) 'archive') 'harness_changelog.md'
      Write-Output "[finish-checkpoint] over cap -- auto-archiving changelog entries (keeping newest $KeepNewest): lines $cutFrom..$cutTo"
      $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
      & (Join-Path $PSScriptRoot 'archive-changelog.ps1') -Checkpoint $Checkpoint -Archive $arc -FromLine $cutFrom -ToLine $cutTo -AtTop 2>&1 | ForEach-Object { Write-Output "  $_" }
      $moverExit = $LASTEXITCODE
      $ErrorActionPreference = $prevEAP
      if ($moverExit -eq 0) {
        # Ensure the standard pointer line ends the section (mover doesn't manage it).
        $m = Measure-Cp $Checkpoint
        if (-not ($m.Lines -match '^Older entries:')) {
          $L2 = $m.Lines; $secEnd2 = $L2.Count
          for ($i = 0; $i -lt $L2.Count; $i++) { if ($L2[$i] -match '^## Harness changelog') { $cl2 = $i; break } }
          for ($i = $cl2 + 1; $i -lt $L2.Count; $i++) { if ($L2[$i] -match '^## ') { $secEnd2 = $i; break } }
          $ins = @(); if ($secEnd2 -gt 0 -and $L2[$secEnd2 - 1].Trim() -ne '') { $ins += '' }
          $ins += 'Older entries: see [archive/harness_changelog.md](archive/harness_changelog.md).'
          if ($secEnd2 -lt $L2.Count) { $ins += '' }   # keep a blank before the next `## ` section
          $L2 = @($L2[0..($secEnd2 - 1)]) + $ins + $(if ($secEnd2 -lt $L2.Count) { @($L2[$secEnd2..($L2.Count - 1)]) } else { @() })
          Write-Text $Checkpoint ([string]::Join($nl, $L2) + $nl) $enc
          Write-Output "[finish-checkpoint] added the standard 'Older entries:' pointer line"
        }
        $m = Measure-Cp $Checkpoint
        $over = ($m.N -gt 120) -or ($m.Bytes -gt 30KB)
      } else {
        Write-Output "[finish-checkpoint] auto-archive FAILED (mover exit $moverExit) -- file left over cap, archive manually"
      }
    } else {
      Write-Output "[finish-checkpoint] over cap but only $($entries.Count) changelog entries -- nothing to auto-archive; compress live sections instead"
    }
  } else {
    Write-Output "[finish-checkpoint] over cap, no '## Harness changelog' section -- compress live sections or archive manually"
  }
}

# Section-bloat is a STYLE norm, not a transport limit -- advisory (exit 0) by default so
# exit-2 keeps meaning "a real, fixable defect". A file opts into the hard gate with a
# marker in its first 5 lines: <!-- checkpoint-budgets: strict -->
# (advisory-by-default is a deliberate choice after false exit-2 noise -- flip the
# $strictBudgets logic if you want the inverse).
$strictBudgets = $false
for ($i = 0; $i -lt [Math]::Min(5, $m.Lines.Count); $i++) {
  if ($m.Lines[$i] -match 'checkpoint-budgets:\s*strict') { $strictBudgets = $true; break }
}
$bloat = Test-SectionBloat $m.Lines
$bloatTag = if ($strictBudgets) { 'SECTION BLOAT' } else { 'SECTION BLOAT (advisory)' }
foreach ($msg in $bloat) { Write-Output "[finish-checkpoint] ${bloatTag}: $msg" }
if ($bloat.Count -gt 0) {
  Write-Output "[finish-checkpoint] the changelog is the record -- live sections are terse pointers into it. Compress the flagged section(s) when the content allows it (never hastily compress state a project's CLAUDE.md protects). Anything cut must already exist in (or be moved to) the changelog / a pointer target first."
}

# Open-threads per-bullet warning (advisory only -- no stated cap in the harness rules).
$otLong = @(Get-Section $m.Lines 'Open threads' | Where-Object { $_ -match '^- ' -and $_.Length -gt 700 })
if ($otLong.Count -gt 0) {
  Write-Output "[finish-checkpoint] WARN: $($otLong.Count) Open-threads bullet(s) exceed 700 chars -- a thread is a to-do line + pointer, not the diagnosis itself."
}

if ($over) {
  Write-Output "[finish-checkpoint] $($m.N) lines / $($m.Bytes) bytes -- OVER CAP (120 ln / ~30KB): compress live sections (skill step 6b), then re-run this script"
  exit 2
} elseif ($bloat.Count -gt 0 -and $strictBudgets) {
  Write-Output "[finish-checkpoint] $($m.N) lines / $($m.Bytes) bytes -- under caps but SECTION BLOAT above must be fixed (this file declares checkpoint-budgets: strict)"
  exit 2
} elseif ($bloat.Count -gt 0) {
  Write-Output "[finish-checkpoint] $($m.N) lines / $($m.Bytes) bytes -- under caps. SECTION BLOAT above is ADVISORY (exit 0): address it when the content allows, or add '<!-- checkpoint-budgets: strict -->' to the file header to make it blocking."
  exit 0
} else {
  if (($m.N -ge 113) -or ($m.Bytes -ge 28672)) {
    # FOR-THE-MODEL prefix: this is housekeeping addressed to the model, not to the user.
    # They take no action on cap headroom. It kept getting quoted verbatim into the close
    # against the skill's one-line confirm cap, so the line now says so itself.
    Write-Output "[finish-checkpoint] $($m.N) lines / $($m.Bytes) bytes -- under caps but HOVERING (>=113 ln or >=28KB)."
    Write-Output "[finish-checkpoint] FOR THE MODEL, DO NOT REPORT TO THE USER: the changelog is likely already thin, so next session will tip over again. Prune done items from Open threads / thin Files that matter (skill step 6b) now, not more archiving."
  } else {
    Write-Output "[finish-checkpoint] $($m.N) lines / $($m.Bytes) bytes -- under caps (120 ln / ~30KB). Done."
  }
  exit 0
}
