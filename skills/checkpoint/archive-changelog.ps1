#requires -Version 5.1
<#
.SYNOPSIS
  Verbatim move of a contiguous line range from a CHECKPOINT.md into a changelog
  archive file. Deterministic, byte-faithful, zero-context.

.DESCRIPTION
  The caller (the /checkpoint skill) decides WHICH lines to archive; this script
  only MOVES them. It cuts Checkpoint lines [FromLine..ToLine] (1-based, inclusive)
  and inserts them UNCHANGED into Archive after line InsertAfterLine (0 = very top).
  It touches nothing else: the caller separately patches the one-line pointer in the
  CHECKPOINT and the one-line summary in the archive (those are prose and vary per
  project). Preserves the file's existing newline convention; writes UTF-8 without a
  BOM. Fails CLOSED on any invalid range -- it never writes a partial/corrupt result.
  Write phase is fail-closed too: it creates the archive's parent dir if missing, then
  writes the ARCHIVE before the CHECKPOINT, so a failed archive write leaves the checkpoint
  untouched and the moved block is never lost (worst case: a harmless duplicate, never a loss).
  Before mutating anything it BACKS UP the originals (timestamped .bak copies under
  <script-dir>/backups/) and LOGS every run (OK or FAIL, with line range + counts) to
  <script-dir>/archive-changelog.log -- so a bad run is both recoverable and auditable.

  If Archive does not exist it is created with a minimal 4-line header and the block
  is inserted after that header (InsertAfterLine is ignored for a fresh archive).

.PARAMETER Checkpoint       Path to the CHECKPOINT.md to trim.
.PARAMETER Archive          Path to the archive file. Created if absent.
.PARAMETER FromLine         First CHECKPOINT line to move (1-based, inclusive).
.PARAMETER ToLine           Last CHECKPOINT line to move (1-based, inclusive).
.PARAMETER InsertAfterLine  Archive line to insert the block AFTER (0 = very top).
                            Ignored when -AtTop is set.
.PARAMETER AtTop            Auto-locate the newest-at-top insertion point: insert the block
                            immediately BEFORE the first existing entry (first line matching
                            `^###\s` or `^-\s`), i.e. right after the header prose. The script
                            finds this itself by reading the archive it already loads, so the
                            caller never has to Read the archive to discover where the header
                            ends. Falls back to end-of-file if the archive has no entries yet.
.PARAMETER PrependHeader    Optional header line written above the moved block (a date-led
                            section header, for bullet-format archives that group each moved
                            batch). Placed + a blank line in the SAME move, so nothing is
                            hand-written in the archive afterward. Omit it for date-led-entry
                            projects -- those entries carry their own headers.
.PARAMETER DryRun           Report the planned move + before/after counts; write nothing.

.EXAMPLE
  pwsh -NoProfile -File archive-changelog.ps1 -Checkpoint .\CHECKPOINT.md `
       -Archive .\harness_changelog_archive.md -FromLine 95 -ToLine 110 `
       -InsertAfterLine 4 -DryRun
#>
param(
  [Parameter(Mandatory)][string]$Checkpoint,
  [Parameter(Mandatory)][string]$Archive,
  [Parameter(Mandatory)][int]$FromLine,
  [Parameter(Mandatory)][int]$ToLine,
  [int]$InsertAfterLine = 0,
  [switch]$AtTop,
  [string]$PrependHeader = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Hoisted so the READ phase can log a FAIL too. The write phase already logged, but a
# permanent lock on the read side used to escape as a raw .NET exception with no audit
# line -- invisible in archive-changelog.log, which is the one place a bad run is meant
# to be reconstructible from. (2026-07-30)
$scriptDirTop = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $Checkpoint }
$logFileTop   = Join-Path $scriptDirTop 'archive-changelog.log'

function Fail([string]$msg) {
  Write-Error "[archive-changelog] REFUSED: $msg"
  exit 1
}

function Invoke-IoRetry([scriptblock]$op, [string]$what) {
  # TRANSIENT-LOCK RETRY (added 2026-07-30 after a real FAIL in archive-changelog.log:
  # "cannot be performed on a file with a user-mapped section open").
  # These files live on a Drive-synced, Defender-scanned, Search-indexed tree, so another
  # process can hold the target open or memory-mapped for a few seconds. Both directions
  # break: a mapped section blocks the truncating WRITE (ERROR_USER_MAPPED_FILE) and an
  # exclusive open blocks the READ (sharing violation). Both surface as IOException and
  # both clear on their own -- the live incident succeeded on a manual re-run 29 s later.
  # ONLY IOException retries: UnauthorizedAccessException (ACL, read-only file) is a real
  # error and must still fail fast. ~15.5 s of total wait before giving up.
  # NOTE: notices go to the WARNING stream on purpose. This helper's return value is
  # consumed (`$raw = Invoke-IoRetry {...}`), so a Write-Output here would be appended to
  # the caller's pipeline and silently corrupt that value into an array.
  $delaysMs = @(500, 1000, 2000, 4000, 8000)
  for ($a = 0; $a -le $delaysMs.Count; $a++) {
    try {
      $r = & $op
      if ($a -gt 0) { Write-Warning "[archive-changelog] transient lock cleared: $what succeeded on attempt $($a + 1)" }
      return $r
    } catch {
      # Unwrap PowerShell's MethodInvocationException so the type test sees the real cause.
      $ex = $_.Exception
      while ($ex.InnerException) { $ex = $ex.InnerException }
      if (($ex -isnot [System.IO.IOException]) -or ($a -eq $delaysMs.Count)) { throw }
      Write-Warning "[archive-changelog] locked by another process, retrying $what in $($delaysMs[$a]) ms"
      Start-Sleep -Milliseconds $delaysMs[$a]
    }
  }
}

function Get-Lines([string]$path) {
  # Returns @{ Lines = string[]; NL = newline } with EOL preserved, trailing NL normalized away.
  $raw = Invoke-IoRetry { [System.IO.File]::ReadAllText($path) } "read of $path"
  $nl  = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = Invoke-IoRetry { [System.IO.File]::ReadAllLines($path) } "read of $path"   # strips per-line EOL uniformly
  return @{ Lines = @($lines); NL = $nl }
}

function Save-Lines([string]$path, [string[]]$lines, [string]$nl) {
  $body = [string]::Join($nl, $lines) + $nl       # always end with one trailing newline
  $enc  = New-Object System.Text.UTF8Encoding($false)   # $false = no BOM
  Invoke-IoRetry { [System.IO.File]::WriteAllText($path, $body, $enc) } "write of $path" | Out-Null
}

function Write-Log([string]$logPath, [string]$msg) {
  # Best-effort audit line; never let a logging hiccup abort the archive op.
  $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
  try { Add-Content -LiteralPath $logPath -Value "$stamp  $msg" -Encoding utf8 } catch { }
}

function Slice([string[]]$arr, [int]$startIdx, [int]$endIdx) {
  # Inclusive 0-based slice that returns @() instead of wrapping when empty.
  if ($endIdx -lt $startIdx) { return @() }
  return @($arr[$startIdx..$endIdx])
}

function Byte-Count([string[]]$lines, [string]$nl) {
  $body = [string]::Join($nl, $lines) + $nl
  return [System.Text.Encoding]::UTF8.GetByteCount($body)
}

# --- Validate checkpoint + range -------------------------------------------------
if (-not (Test-Path -LiteralPath $Checkpoint)) { Fail "Checkpoint not found: $Checkpoint" }
try { $cp = Get-Lines $Checkpoint } catch {
  Write-Log $logFileTop ("FAIL  moved {0}..{1} | cp {2} | arc {3} | ERROR (checkpoint read): {4}" -f $FromLine, $ToLine, $Checkpoint, $Archive, $_.Exception.Message)
  Fail "could not read the checkpoint after retrying a locked file (nothing written): $($_.Exception.Message)"
}
$cpLines = $cp.Lines
$cpN = $cpLines.Count

if ($FromLine -lt 1)        { Fail "FromLine ($FromLine) must be >= 1" }
if ($ToLine -lt $FromLine)  { Fail "ToLine ($ToLine) must be >= FromLine ($FromLine)" }
if ($ToLine -gt $cpN)       { Fail "ToLine ($ToLine) exceeds checkpoint length ($cpN lines)" }

# Block to move (verbatim), and the checkpoint remainder.
$block = Slice $cpLines ($FromLine - 1) ($ToLine - 1)
$cpHead = Slice $cpLines 0 ($FromLine - 2)
$cpTail = Slice $cpLines $ToLine ($cpN - 1)
$cpNew  = @($cpHead + $cpTail)

# --- Load or seed archive --------------------------------------------------------
$freshArchive = -not (Test-Path -LiteralPath $Archive)
if ($freshArchive) {
  $arcLines = @(
    "# harness changelog archive",
    "Read-only archaeology: entries moved verbatim from CHECKPOINT.md to stay under the 120-line / ~30KB cap. Newest at top. See ../CHECKPOINT.md for current entries.",
    ""
  )
  $arcNL = $cp.NL
  $effInsert = $arcLines.Count        # insert after the seeded header
} else {
  try { $arc = Get-Lines $Archive } catch {
    Write-Log $logFileTop ("FAIL  moved {0}..{1} | cp {2} | arc {3} | ERROR (archive read): {4}" -f $FromLine, $ToLine, $Checkpoint, $Archive, $_.Exception.Message)
    Fail "could not read the archive after retrying a locked file (checkpoint untouched, nothing lost): $($_.Exception.Message)"
  }
  $arcLines = $arc.Lines
  $arcNL = $arc.NL
  if ($AtTop) {
    # Newest-at-top: insert right before the first existing entry (date-led `### ` or
    # bullet `- `), i.e. just after the header prose. Caller never reads the archive.
    $firstEntry = 0
    for ($i = 0; $i -lt $arcLines.Count; $i++) {
      if ($arcLines[$i] -match '^(###\s|-\s)') { $firstEntry = $i + 1; break }
    }
    # No entries yet -> append after all header lines (end of file).
    $effInsert = if ($firstEntry -gt 0) { $firstEntry - 1 } else { $arcLines.Count }
  } else {
    if ($InsertAfterLine -lt 0 -or $InsertAfterLine -gt $arcLines.Count) {
      Fail "InsertAfterLine ($InsertAfterLine) out of range 0..$($arcLines.Count) for $Archive"
    }
    $effInsert = $InsertAfterLine
  }
}

$arcN = $arcLines.Count
$arcBefore = Slice $arcLines 0 ($effInsert - 1)
$arcAfter  = Slice $arcLines $effInsert ($arcN - 1)
$insertBlock = if ($PrependHeader) { @($PrependHeader, '') + $block } else { $block }
$arcNew    = @($arcBefore + $insertBlock + $arcAfter)

# --- Report ----------------------------------------------------------------------
$cpBytesBefore  = Byte-Count $cpLines $cp.NL
$cpBytesAfter   = Byte-Count $cpNew $cp.NL
$arcBytesBefore = Byte-Count $arcLines $arcNL
$arcBytesAfter  = Byte-Count $arcNew $arcNL

$mode = if ($DryRun) { "DRY RUN (no files written)" } else { "WRITE" }
Write-Output "[archive-changelog] $mode"
Write-Output "  Checkpoint: $Checkpoint"
Write-Output "    moving lines $FromLine..$ToLine ($($block.Count) lines)"
Write-Output "    first moved: $($block[0])"
Write-Output "    last  moved: $($block[$block.Count - 1])"
Write-Output "    before: $cpN lines / $cpBytesBefore bytes  ->  after: $($cpNew.Count) lines / $cpBytesAfter bytes"
Write-Output "  Archive: $Archive$(if ($freshArchive) { '  (created)' })"
Write-Output "    inserting after line $effInsert$(if ($PrependHeader) { " (with header: $PrependHeader)" })"
Write-Output "    before: $arcN lines / $arcBytesBefore bytes  ->  after: $($arcNew.Count) lines / $arcBytesAfter bytes"

# --- Write -----------------------------------------------------------------------
# Order is load-bearing for fail-closed behavior: ensure the archive's parent dir exists,
# then write the ARCHIVE first and the CHECKPOINT second. If creating the dir or writing the
# archive fails, the checkpoint is left UNTOUCHED, so the moved block is never lost -- the
# caller just re-runs after fixing the cause. (If the checkpoint write somehow fails after the
# archive succeeds, the block lands in BOTH files -- a harmless, obvious duplicate, never a
# silent loss.) The previous order wrote the checkpoint first and lost the block when the
# archive folder did not exist.
if (-not $DryRun) {
  # Log + backups live next to the script (via $PSScriptRoot) so they follow the install,
  # not the project. Falls back to the checkpoint's folder if $PSScriptRoot is empty.
  $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $Checkpoint }
  $logFile   = Join-Path $scriptDir 'archive-changelog.log'
  $backupDir = Join-Path $scriptDir 'backups'
  $stamp     = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
  try {
    # 1. Pre-write BACKUP -- the ultimate safety net. Copy the originals BEFORE any mutation,
    #    so even a logic bug or a crash mid-write leaves a recoverable copy on disk.
    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    $cpLeaf = Split-Path -Leaf $Checkpoint
    Copy-Item -LiteralPath $Checkpoint -Destination (Join-Path $backupDir "${stamp}_${cpLeaf}.bak") -Force
    if (-not $freshArchive) {
      $arcLeaf = Split-Path -Leaf $Archive
      Copy-Item -LiteralPath $Archive -Destination (Join-Path $backupDir "${stamp}_${arcLeaf}.bak") -Force
    }
    # 2. Ensure the archive's parent dir exists, then write ARCHIVE before CHECKPOINT
    #    (fail-closed order: a failed archive write leaves the checkpoint untouched).
    $arcDir = Split-Path -Parent $Archive
    if ($arcDir -and -not (Test-Path -LiteralPath $arcDir)) { New-Item -ItemType Directory -Path $arcDir -Force | Out-Null }
    Save-Lines $Archive    $arcNew $arcNL
    Save-Lines $Checkpoint $cpNew  $cp.NL
    Write-Log $logFile ("OK    moved {0}..{1} ({2} ln) | cp {3} {4}->{5} ln | arc {6} (+{2} ln){7}" -f `
      $FromLine, $ToLine, $block.Count, $Checkpoint, $cpN, $cpNew.Count, $Archive, $(if ($freshArchive) { ' [created]' } else { '' }))
    Write-Output "  backed up originals -> $backupDir\${stamp}_*.bak"
    Write-Output "  logged -> $logFile"
    Write-Output "  done."
    # The caller is an agent holding a read snapshot of the checkpoint it just edited.
    # This script rewrote that file out-of-band, so the snapshot is now stale and the very
    # next Edit is rejected ("File has been modified since read"). Say so here, in the
    # tool result the caller is already reading, rather than relying on it to remember.
    Write-Output "  NOTE: this script rewrote BOTH files on disk. Re-Read the CHECKPOINT before your next Edit to it -- your read snapshot is stale and the Edit will otherwise be rejected."
  } catch {
    Write-Log $logFile ("FAIL  moved {0}..{1} | cp {2} | arc {3} | ERROR: {4}" -f $FromLine, $ToLine, $Checkpoint, $Archive, $_.Exception.Message)
    Fail "write failed (originals preserved in $backupDir): $($_.Exception.Message)"
  }
}
exit 0
