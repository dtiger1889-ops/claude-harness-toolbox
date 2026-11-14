# vet_dedupe.ps1 -- has this thing already been picked apart?
# Sweeps the places a past breakdown can live, in the order you want to read them: the ledger,
# the topic guides, the rest of your notes, the workspace's .md files, and the local skills folder.
#
# Usage:  pwsh -NoProfile -File vet_dedupe.ps1 -Term "some-tool"
#         pwsh -NoProfile -File vet_dedupe.ps1 -Term "tool-a,tool-b,tool-c"   (comma-separated)
#
# Roots (a parameter wins over its environment variable; an unset root is skipped):
#   -Ledger         the ledger file              (VET_LEDGER)
#   -GuidesDir      the topic-guides folder      (VET_GUIDES_DIR)
#   -NotesRoot      your notes folder            (HARNESS_NOTES_ROOT)
#   -WorkspaceRoot  the projects folder          (HARNESS_WORKSPACE_ROOT; default: current folder)
#   -SkillsRoot     installed skills             (default: ~/.claude/skills)
#
# Literal, case-insensitive matching. Plain file walking, so .gitignore never hides a folder.
# Always exits 0; no hits is a valid answer.

param(
    [Parameter(Mandatory = $true)][string] $Term,
    [string] $Ledger,
    [string] $GuidesDir,
    [string] $NotesRoot,
    [string] $WorkspaceRoot,
    [string] $SkillsRoot,
    [int] $MaxPerZone = 6
)

# pwsh -File hands every argument over as one string, so split here rather than at the call.
$terms = @($Term -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })

function Resolve-Root([string]$Value, [string]$EnvName, [string]$Default) {
    if ([string]::IsNullOrWhiteSpace($Value) -and $EnvName) { $Value = [Environment]::GetEnvironmentVariable($EnvName) }
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = $Default }
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if (-not (Test-Path -LiteralPath $Value)) { return $null }
    return (Resolve-Path -LiteralPath $Value).Path
}

$ledgerPath = Resolve-Root $Ledger 'VET_LEDGER' $null
$guideRoot  = Resolve-Root $GuidesDir 'VET_GUIDES_DIR' $null
$notesPath  = Resolve-Root $NotesRoot 'HARNESS_NOTES_ROOT' $null
$wsPath     = Resolve-Root $WorkspaceRoot 'HARNESS_WORKSPACE_ROOT' (Get-Location).Path
$skillsPath = Resolve-Root $SkillsRoot $null (Join-Path (Join-Path $HOME '.claude') 'skills')

# Paths that are evidence, noise, or duplicates -- never a verdict.
$excludePattern = '[\\/](archive[\\/]research_raw|\.tmp\.drive[^\\/]*|node_modules|\.git|backups|\.trash)([\\/]|$)|[\\/]skills[\\/]vet[\\/]'

$guideSet = @()
if ($guideRoot) {
    $guideSet = @(Get-ChildItem -LiteralPath $guideRoot -Filter *.md -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}
$skip = @($guideSet)
if ($ledgerPath) { $skip += $ledgerPath }

function Get-MdFiles([string]$Root, [string[]]$Include = @('*.md')) {
    if (-not $Root) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -Recurse -Include $Include -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $excludePattern -and $script:skip -notcontains $_.FullName } |
        Select-Object -ExpandProperty FullName)
}

$notesFiles = Get-MdFiles $notesPath
# A notes folder inside the workspace is swept once, as notes.
$wsFiles = @(Get-MdFiles $wsPath | Where-Object { $notesFiles -notcontains $_ })
$skillFiles = Get-MdFiles $skillsPath @('*.md', '*.ps1', '*.py', '*.sh')
$skillDirs = @()
if ($skillsPath) { $skillDirs = @(Get-ChildItem -LiteralPath $skillsPath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) }

function Show-Hits([string]$Zone, [object[]]$Hits, [int]$Cap) {
    if (-not $Hits -or $Hits.Count -eq 0) { return }
    Write-Output ""
    Write-Output ("--- {0} ({1} hit(s)) ---" -f $Zone, $Hits.Count)
    foreach ($h in ($Hits | Select-Object -First $Cap)) {
        $snippet = $h.Line.Trim()
        if ($snippet.Length -gt 220) { $snippet = $snippet.Substring(0, 220) + ' ...' }
        Write-Output ("  {0}:{1}: {2}" -f $h.Path, $h.LineNumber, $snippet)
    }
    if ($Hits.Count -gt $Cap) { Write-Output ("  ... {0} more in this zone" -f ($Hits.Count - $Cap)) }
}

function Find-In([string[]]$Files, [string]$Pattern) {
    if (-not $Files -or $Files.Count -eq 0) { return @() }
    return @(Select-String -LiteralPath $Files -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue)
}

$missing = @()
if (-not $ledgerPath) { $missing += 'ledger (set -Ledger or VET_LEDGER)' }
if (-not $guideRoot) { $missing += 'topic guides (set -GuidesDir or VET_GUIDES_DIR)' }
if (-not $notesPath) { $missing += 'notes (set -NotesRoot or HARNESS_NOTES_ROOT)' }
if ($missing.Count -gt 0) { Write-Output ("NOTE: not swept, no folder or file given: " + ($missing -join '; ')) }

foreach ($t in $terms) {
    Write-Output ""
    Write-Output ("=============== TERM: {0} ===============" -f $t)
    $total = 0

    $h1 = @(); if ($ledgerPath) { $h1 = Find-In @($ledgerPath) $t }
    Show-Hits 'LEDGER' $h1 $MaxPerZone; $total += $h1.Count

    $h1b = Find-In $guideSet $t
    Show-Hits 'TOPIC GUIDES' $h1b $MaxPerZone; $total += $h1b.Count

    $h2 = Find-In $notesFiles $t
    Show-Hits 'NOTES (other)' $h2 $MaxPerZone; $total += $h2.Count

    $h3 = Find-In $wsFiles $t
    Show-Hits 'WORKSPACE (.md)' $h3 $MaxPerZone; $total += $h3.Count

    # Already built locally? Skill folder names, then skill file contents.
    $nameHits = @($skillDirs | Where-Object { $_ -like ("*" + $t + "*") })
    if ($nameHits.Count -gt 0) {
        Write-Output ""
        Write-Output ("--- LOCAL SKILL FOLDER NAME MATCH ({0}) ---" -f $nameHits.Count)
        foreach ($n in $nameHits) { Write-Output ("  {0}" -f (Join-Path $skillsPath $n)) }
        $total += $nameHits.Count
    }
    $h5 = Find-In $skillFiles $t
    Show-Hits 'LOCAL SKILLS (content)' $h5 4; $total += $h5.Count

    Write-Output ""
    if ($total -eq 0) {
        Write-Output ("RESULT: no hits for '{0}' -- treat as NEW." -f $t)
        continue
    }
    Write-Output ("RESULT: {0} hit(s) for '{1}' -- read them before researching. A dated breakdown that names the thing's parts (or a dated ruled-out reason) is JUDGED; an install-only verdict, or one older than 90 days, is STALE; an entry under Evaluation queued or Part waiting on your go is PENDING, never a stop." -f $total, $t)
    # A ledger hit under a pending group is called out, so the early stop cannot swallow it.
    if ($h1.Count -gt 0) {
        $group = ''
        foreach ($line in (Get-Content -LiteralPath $ledgerPath -ErrorAction SilentlyContinue)) {
            if ($line -match '^### (.+?) \(\d+\)') { $group = $Matches[1]; continue }
            if (-not $line.StartsWith('- **')) { continue }
            if ($line.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            if ($group -notmatch '^(Watching|Evaluation queued|Part waiting on your go)') { continue }
            if ($group -like 'Watching*' -and $h1b.Count -eq 0) {
                Write-Output ("PENDING (breakdown missing): '{0}' sits under '{1}' with no topic-guide block -- pick apart this one entry only, then move it. No sweep of the others." -f $t, $group)
            } else {
                Write-Output ("PENDING (action outstanding): '{0}' sits under '{1}' -- the breakdown exists; do not re-research. Check the linked task or trigger and move the entry if it closed." -f $t, $group)
            }
            break
        }
    }
}

exit 0
