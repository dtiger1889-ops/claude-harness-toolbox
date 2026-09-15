# verify_checkpoint_claims.ps1 -- close step 4.5: make the verify step fail as loudly as the cap check.
# Built 2026-08-12 from the maintainer's private design record (verification-enforcement asymmetry).
# Exit contract mirrors finish-checkpoint.ps1: 0 = clean, 2 = defects found (each named).
# Coverage (honest): dead paths = HARD FAIL; git-state claims = REVIEW block to reconcile;
# stale-dated / owner-gated threads = PROMPTS unless undispositioned, then HARD FAIL (see below);
# tag/jargon/attribution prompts = advisory only. Semantic staleness is NOT detected here.
# 3.6 attribution prompts added 2026-09-09 (unattributed verdicts / undated owner decisions).
#
# Staleness disposition gate (built 2026-09-14; motivation: the maintainer's lapse ledger rows 1, 2, 9,
# 14 -- the verifier printed a staleness prompt labelled "not a failure" and the model stamped
# anyway). A STALE-DATED Open-threads bullet (a date older than 30 days on the bullet; an
# undated [owner]-tagged bullet stays an advisory prompt -- narrowed 2026-09-14 after a
# workspace-wide dry run blocked 22 closes on fresh, undated items) is DISPOSITIONED --
# and stays an informational STALENESS PROMPT -- only if it carries a marker
#   [kept YYYY-MM-DD: reason of at least 12 chars]
# with a date within the last 30 days, OR the bullet's own date is itself within 30 days
# (nothing to re-confirm). Pruning the bullet is the other disposition. Everything else --
# no marker, an expired marker (>30 days old), a reason under 12 chars, or a reason that
# duplicates another bullet's reason in the same file (rubber-stamp detection) -- prints under
# "STALENESS FAILURES" and is a HARD FAIL (exit 2), same contract as dead paths.
# Per-project opt-out: add a line `staleness: advisory` to <project>/.checkpoint-verify-ignore
# to restore the old advisory-only behavior for that file (failures still print, just don't
# gate exit 0). This does not affect dead-path or the other prompt classes.
param(
    [Parameter(Mandatory = $true)][string]$Checkpoint
)
$ErrorActionPreference = 'Stop'
try {
    $ckPath = (Resolve-Path -LiteralPath $Checkpoint).Path
} catch {
    Write-Output "[verify-checkpoint] ERROR: checkpoint not found: $Checkpoint"
    exit 2
}
$projRoot = Split-Path -Parent $ckPath
# Portable roots (public build): the workspace root defaults to the project's parent folder;
# override with HARNESS_WORKSPACE_ROOT. A notes system (Obsidian vault, wiki) is optional:
# set HARNESS_NOTES_ROOT to let notes-relative paths in the file resolve.
$WorkspaceRoot = if ($env:HARNESS_WORKSPACE_ROOT) { $env:HARNESS_WORKSPACE_ROOT } else { Split-Path -Parent $projRoot }
$NotesRoot = $env:HARNESS_NOTES_ROOT
$text = [System.IO.File]::ReadAllText($ckPath)
$lines = [System.IO.File]::ReadAllLines($ckPath)
$defects = @()
$reviews = @()
$prompts = @()

# --- 1. Path existence -------------------------------------------------------
# Candidates: backticked tokens and markdown-link targets that look like paths.
# Changelog sections are HISTORY -- paths there describe past states; skip them.
$liveText = New-Object System.Text.StringBuilder
$inChangelog = $false
foreach ($ln in $lines) {
    if ($ln -match '^##\s') { $inChangelog = ($ln -match '^##\s+Harness changelog') }
    if ($inChangelog) { continue }
    # Dated changelog-shaped bullets ("- 2026-07-29 -- ...") are history regardless of which
    # section holds them (one project keeps its changelog under Next step) -- skip as history too.
    if ($ln -match '^\s*-\s+20\d{2}-\d{2}-\d{2}\s+--') { continue }
    [void]$liveText.AppendLine($ln)
}
$liveText = $liveText.ToString()
$cands = New-Object System.Collections.Generic.HashSet[string]
foreach ($m in [regex]::Matches($liveText, '`([^`\r\n]{2,240})`'))   { [void]$cands.Add($m.Groups[1].Value) }
foreach ($m in [regex]::Matches($liveText, '\]\(([^)\r\n]{2,240})\)')) { [void]$cands.Add($m.Groups[1].Value) }
$missing = @(); $planned = @(); $checked = 0
# Optional per-project ignore list: <proj>/.checkpoint-verify-ignore, one wildcard per line,
# '#' comments allowed -- for external/deliberately-dead paths a heuristic can't classify
# (the false-exit-2 record, fix 3 alternative).
$ignoreGlobs = @()
$stalenessAdvisory = $false
$igPath = Join-Path $projRoot '.checkpoint-verify-ignore'
if (Test-Path -LiteralPath $igPath) {
    $igRaw = @([System.IO.File]::ReadAllLines($igPath) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -notmatch '^#' })
    foreach ($igl in $igRaw) {
        if ($igl -match '^staleness\s*:\s*advisory\s*$') { $stalenessAdvisory = $true; continue }
        $ignoreGlobs += $igl
    }
}
foreach ($c in $cands) {
    $t = $c.Trim().Trim('"').Trim("'")
    $skip = $false
    foreach ($g in $ignoreGlobs) { if ($t -like $g) { $skip = $true; break } }
    if ($skip) { continue }
    if ($t -match '^(https?|mailto|file):') { continue }
    if ($t -notmatch '[\\/]') { continue }                          # not path-shaped
    if ($t -match '[|<>*?{}]' ) { continue }                        # globs/braces/placeholders/pipes
    if ($t -match '\s-\w|\||;|&&') { continue }                     # command-looking
    if ($t -match '^\\\\') { continue }                             # UNC: out of scope
    if ($t -match "[^ -~]") { continue }                      # non-ASCII (ellipsis placeholders)
    if ($t -match '^/') { continue }                                # POSIX/remote/slash-cmd: not checkable here
    if ($t -match '^[^\\/]+[\\/]$') { continue }                    # bare "name/" concept mentions
    if ($t -match ':' -and $t -notmatch '^[A-Za-z]:[\\/]') { continue }  # code/field pairs, not drive paths
    if ($t -match '#') { $t = ($t -split '#')[0] }                  # strip anchors
    if ($t -eq '') { continue }
    $expanded = $t -replace '^~', $env:USERPROFILE
    $tries = @()
    if ($expanded -match '^[A-Za-z]:') { $tries += $expanded }
    else {
        $tries += (Join-Path $projRoot $expanded)
        $tries += (Join-Path (Split-Path -Parent $projRoot) $expanded)  # ../-style siblings written bare
        $tries += (Join-Path $env:USERPROFILE $expanded)                # home-relative shorthand
        if ($NotesRoot) { $tries += (Join-Path $NotesRoot $expanded) }          # notes-system-relative refs
        $tries += (Join-Path $WorkspaceRoot $expanded)                            # workspace-root cross-project refs
        # One-level working subdirs (scripts often write paths relative to e.g. <proj>/pipeline/).
        # One level only, full-suffix match -- -Recurse would risk false negatives on same-named
        # files deep in unrelated subtrees (the false-exit-2 record, fix 1).
        foreach ($sub in (Get-ChildItem -LiteralPath $projRoot -Directory -ErrorAction SilentlyContinue)) {
            if ($sub.Name -notmatch '^(\.|archive$|node_modules$)') { $tries += (Join-Path $sub.FullName $expanded) }
        }
        # ...and one level into sibling projects (paths written relative to a sibling's subdir,
        # e.g. one project referencing a data file under a sibling project's subdir).
        foreach ($sib in (Get-ChildItem -LiteralPath (Split-Path -Parent $projRoot) -Directory -ErrorAction SilentlyContinue)) {
            if ($sib.FullName -ne $projRoot -and $sib.Name -notmatch '^(\.|archive$|node_modules$)') { $tries += (Join-Path $sib.FullName $expanded) }
        }
    }
    $found = $false
    foreach ($p in $tries) { if (Test-Path -LiteralPath $p) { $found = $true; break } }
    $checked++
    if (-not $found) {
        # Downgrades before DEAD PATH (the false-exit-2 record, fix 3):
        # (a) absolute path OUTSIDE the workspace root -- external Drive-account folders etc.
        #     the verifier can't reach; not provably dead from here.
        $expNorm = $expanded -replace '/', '\'
        $wsRoot  = $WorkspaceRoot
        $isExternal = ($expNorm -match '^[A-Za-z]:') -and -not $expNorm.StartsWith($wsRoot, [System.StringComparison]::OrdinalIgnoreCase)
        # (b) the source line describes the path as intentionally gone -- a deletion RECORD,
        #     not a broken pointer. Brittle by design; the ignore file is the robust lane.
        $srcRemoved = $false
        foreach ($ln in $lines) {
            if ($ln.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                $ln -match '(?i)\b(deleted|removed|reverted|shelved|retired)\b') { $srcRemoved = $true; break }
        }
        if ($t -match '(^|[\\/])specs?[\\/]') { $planned += $t }    # spec-planned future paths: report, don't block
        elseif ($isExternal) { $reviews += "EXTERNAL PATH (outside workspace, not checkable here -- confirm it still exists where it lives): $t" }
        elseif ($srcRemoved) { $reviews += "PATH DESCRIBED AS REMOVED (deliberate-deletion record, confirm intentional): $t" }
        else { $missing += $t }
    }
}
if ($missing.Count -gt 0) {
    $defects += "DEAD PATHS ($($missing.Count) of $checked checked) -- fix the pointer or the claim:"
    foreach ($p in ($missing | Sort-Object -Unique)) { $defects += "  MISSING: $p" }
}
if ($planned.Count -gt 0) {
    $reviews += "specs/-referenced paths not on disk (may be planned, verify intent): $((($planned | Sort-Object -Unique) -join ', '))"
}

# --- 2. Git claim probe ------------------------------------------------------
if ($text -match '(?i)unpushed|uncommitted|unstaged|commit\+push|push OWED|needs? push') {
    $inRepo = $false
    Push-Location $projRoot
    try {
        git rev-parse --is-inside-work-tree 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $inRepo = $true }
        if ($inRepo) {
            $dirty = @(git status --porcelain 2>$null).Count
            $ahead = @(git log --oneline '@{u}..HEAD' 2>$null).Count
            $reviews += "GIT CLAIMS PRESENT -- live truth: $dirty dirty path(s), $ahead unpushed commit(s). Reconcile every unpushed/uncommitted claim in the file against these numbers."
        } else {
            $reviews += "GIT CLAIMS PRESENT but $projRoot is not a git repo -- verify which repo the claims describe."
        }
    } catch {} finally { Pop-Location }
}

# --- 3. Staleness prompts / failures (disposition gate, added 2026-09-14) ----
# See header for the marker syntax and the .checkpoint-verify-ignore opt-out.
$cutoff = (Get-Date).AddDays(-30)
$inThreads = $false
$staleFailures = @()
$staleItems = @()
foreach ($ln in $lines) {
    if ($ln -match '^##\s') { $inThreads = ($ln -match '^##\s+Open threads') ; continue }
    if (-not $inThreads) { continue }
    if ($ln -notmatch '^\s*-\s') { continue }

    # The [kept YYYY-MM-DD: reason] marker carries its OWN date, which must not be counted as
    # "the bullet's own date is within 30 days" (that free pass is for a genuine non-marker
    # date on the bullet, e.g. its opened-date) -- strip the marker before the general date scan
    # so a marker's date can't launder a bare/expired/rubber-stamp marker past disposition.
    $mm = [regex]::Match($ln, '\[kept\s+(20\d{2}-\d{2}-\d{2})\s*:\s*([^\]]+)\]')
    $lnForDates = if ($mm.Success) { $ln.Remove($mm.Index, $mm.Length) } else { $ln }

    $flag = @()
    $recentDate = $false
    foreach ($dm in [regex]::Matches($lnForDates, '\b(20\d{2}-\d{2}-\d{2})\b')) {
        try {
            $d = [datetime]::ParseExact($dm.Groups[1].Value, 'yyyy-MM-dd', $null)
            if ($d -lt $cutoff) { if ($flag -notcontains "date $($dm.Groups[1].Value)") { $flag += "date $($dm.Groups[1].Value)" } }
            else { $recentDate = $true }
        } catch {}
    }
    if ($ln -match '\[owner\]') { $flag += 'owner-gated' }
    if ($flag.Count -eq 0) { continue }

    $head = ($ln.Trim() -replace '^\-\s*', '')
    if ($head.Length -gt 90) { $head = $head.Substring(0, 90) + '...' }

    $disposition = $null   # $null = no marker; 'ok' | 'expired' | 'short' | 'dup'
    $markerReason = $null
    if ($mm.Success) {
        $markerReason = $mm.Groups[2].Value.Trim()
        try {
            $mDate = [datetime]::ParseExact($mm.Groups[1].Value, 'yyyy-MM-dd', $null)
            if ($mDate -lt $cutoff) { $disposition = 'expired' }
            elseif ($markerReason.Length -lt 12) { $disposition = 'short' }
            else { $disposition = 'ok' }
        } catch { $disposition = 'short' }   # malformed marker date -- treat as undispositioned defect, not a free pass
    }
    $staleItems += [PSCustomObject]@{ Head = $head; Flag = ($flag -join ', '); RecentDate = $recentDate; Disposition = $disposition; Reason = $markerReason }
}
# Rubber-stamp detection: a valid-looking marker whose reason text is reused verbatim (case-
# insensitive) on another bullet in the same file is not a real disposition -- fail both.
$reasonCounts = @{}
foreach ($it in $staleItems) {
    if ($it.Disposition -eq 'ok') {
        $k = $it.Reason.ToLowerInvariant()
        if ($reasonCounts.ContainsKey($k)) { $reasonCounts[$k]++ } else { $reasonCounts[$k] = 1 }
    }
}
foreach ($it in $staleItems) {
    if ($it.Disposition -eq 'ok' -and $reasonCounts[$it.Reason.ToLowerInvariant()] -gt 1) { $it.Disposition = 'dup' }
}
foreach ($it in $staleItems) {
    if ($it.Disposition -eq 'ok') {
        $prompts += "RE-CONFIRM OR PRUNE ($($it.Flag)) [dispositioned -- kept: $($it.Reason)]: $($it.Head)"
    } elseif ($it.RecentDate) {
        $prompts += "RE-CONFIRM OR PRUNE ($($it.Flag)) [dispositioned -- bullet carries a date within 30 days]: $($it.Head)"
    } elseif ($it.Flag -notmatch 'date ') {
        # Narrowed 2026-09-14 (model review of the dry run): an owner-gated bullet with NO date at
        # all is a prompt, never a failure. Only a bullet that carries a date older than 30 days
        # (or an expired/short/duplicate marker on such a bullet) blocks the close. Without this
        # narrowing 22 projects failed their next close on fresh, undated [owner] items, which is
        # the false-exit-2 pattern the maintainer's record warns about.
        $prompts += "RE-CONFIRM OR PRUNE ($($it.Flag), undated -- advisory): $($it.Head)"
    } elseif ($it.Disposition -eq 'expired') {
        $staleFailures += "EXPIRED MARKER (kept-marker is >30 days old -- re-confirm with a fresh [kept YYYY-MM-DD: reason] or prune): $($it.Head)"
    } elseif ($it.Disposition -in @('short', 'dup')) {
        $staleFailures += "UNDISPOSITIONED ($($it.Flag)) -- reason too short / duplicated: $($it.Head)"
    } else {
        $staleFailures += "UNDISPOSITIONED ($($it.Flag)) -- needs [kept YYYY-MM-DD: reason] or prune: $($it.Head)"
    }
}
if ($stalenessAdvisory -and $staleFailures.Count -gt 0) {
    foreach ($f in $staleFailures) { $prompts += "$f (advisory per .checkpoint-verify-ignore: staleness: advisory)" }
    $staleFailures = @()
}

# --- 3.7 Tag-convention prompts (added 2026-09-03) ---------------------------
# Every top-level Open-threads bullet ends with one gate tag ([owner] / [agent]) and one
# complexity tag ([low] / [high]); the list runs [owner][low], [owner][high],
# [agent][low], [agent][high].
# Prompts only, never failures; tags are checked, sub-headers are not.
$tagPrompts = @()
$inThreads = $false
$prevRank = -1
$orderFlagged = $false
# A bullet may wrap onto continuation lines and its pair sits at the TRUE end, so gather each
# top-level item (head + every following non-blank, non-bullet, non-header line, plus its
# sub-bullets) and judge the whole thing. (2026-09-03 fix: head-only reads flagged every
# wrapped bullet as TAG PAIR MISSING.)
$itemText = $null; $itemHead = $null
function Judge-Item {
    param([string]$text, [string]$head)
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $h = ($head.Trim() -replace '^\-\s*', ''); if ($h.Length -gt 70) { $h = $h.Substring(0, 70) + '...' }
    $gates = [regex]::Matches($text, '\[(owner|agent)\]').Count
    $cplx  = [regex]::Matches($text, '\[(low|high)\]').Count
    if ($text -match '\[(quick|moderate|heavy)\]|\[owner decides[^\]]*\]') { $script:tagPrompts += "RETIRED TAG (convert to [owner]/[agent] + [low]/[high]): $h" }
    if ($gates -ne 1 -or $cplx -ne 1) { $script:tagPrompts += "TAG PAIR MISSING (need one of [owner]/[agent] and one of [low]/[high]): $h"; return }
    $rank = 0
    if ($text -match '\[agent\]') { $rank += 2 }
    if ($text -match '\[high\]')  { $rank += 1 }
    if ($rank -lt $script:prevRank -and -not $script:orderFlagged) { $script:tagPrompts += "ORDER (owner-low, owner-high, agent-low, agent-high) breaks at: $h"; $script:orderFlagged = $true }
    $script:prevRank = $rank
}
foreach ($ln in $lines) {
    if ($ln -match '^##\s') { Judge-Item $itemText $itemHead; $itemText = $null; $inThreads = ($ln -match '^##\s+Open threads') ; continue }
    if (-not $inThreads) { continue }
    # 2026-09-09: a sub-header the convention does not define (one project's ### headers,
    # another's **Backups**) is silently mangled by the sorter; name it here so the
    # close sees it. The two sanctioned bold headers pass.
    if (($ln -match '^\*\*[^*]+\*\*\s*$' -or $ln -match '^#{3,}\s') -and $ln -notmatch '^\*\*(Owner-gated|Agent-side)\*\*\s*$') {
        $script:tagPrompts += "STRAY HEADER inside Open threads (the sorter refuses to sort this file while it is here; convention allows only **Owner-gated** / **Agent-side**): $($ln.Trim())"
    }
    if ($ln -match '^-\s') { Judge-Item $itemText $itemHead; $itemText = $ln; $itemHead = $ln; continue }
    if ($null -eq $itemText) { continue }
    if ($ln.Trim().Length -eq 0) { Judge-Item $itemText $itemHead; $itemText = $null; continue }
    $itemText += ' ' + $ln
}
Judge-Item $itemText $itemHead

# --- 3.5 Jargon prompts (added 2026-08-19, /prevent) -------------------------
# A CHECKPOINT is read cold weeks later by someone who cannot ask what a phrase means.
# The people-words rule (project policy): the test is not "is it a code", it is "can a
# stranger resolve this without opening another file". These terms are defined only inside
# this workspace, so each one owes a plain-words gloss in the same breath. Advisory only --
# a term is fine WITH its gloss; this just makes you look. Live sections only; the
# changelog is history and is exempt.
# Ships EMPTY: fill it with your own workspace's shorthand (regex, one per entry), e.g. internal
# codes like 'F0\d\d\b' or pet names for rules that only mean something to you.
$jargonTerms = @()
$jargonHits = @()
$inLive = $true
foreach ($ln in $lines) {
    if ($ln -match '^##\s') { $inLive = ($ln -notmatch '^##\s+(Harness changelog|Changelog)') ; continue }
    if (-not $inLive) { continue }
    if ($ln.Trim().Length -eq 0) { continue }
    foreach ($t in $jargonTerms) {
        if ($ln -match $t) {
            $head = $ln.Trim(); if ($head.Length -gt 80) { $head = $head.Substring(0, 80) + '...' }
            $jargonHits += "GLOSS IT OR CUT IT ('$t'): $head"
            break
        }
    }
}

# --- 3.6 Attribution prompts (added 2026-09-09) ------------------------------
# Project policy "Attribute every judgment and decision -- author + date": every verdict,
# recommendation, threshold or decision in a live section names WHO reached it and WHEN, and a
# claim of the owner's own decision carries an explicit date. Built from the maintainer's lapse
# ledger, lapses #13 (model recommendation mislabeled as the owner's decision) and #19
# (author + date omitted). Live sections only -- the changelog is history and is exempt.
# Advisory only; deliberately under-flags (verdict word must lead a clause, not just appear).
$attrPrompts = @()
$attrTotal = 0
$attrCap = 6
$inLive = $true
$inLiveSec = $false
foreach ($ln in $lines) {
    if ($ln -match '^##\s') {
        $inLiveSec = ($ln -match '^##\s+(Status|Key decisions|Open threads|Next step)')
        continue
    }
    if (-not $inLiveSec) { continue }
    $t = $ln.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t -match '^\s*-\s+20\d{2}-\d{2}-\d{2}\s+--') { continue }   # changelog-shaped bullet: history
    $hasDate   = ($t -match '\b20\d{2}-\d{2}-\d{2}\b')
    $hasAuthor = ($t -match '(?i)\b(owner|the user|model|Codex|Claude|author unknown)\b')
    $why = $null
    # (b) an explicit claim that the owner decided, with no date on the line.
    if ($t -match '(?i)\b(owner|the user)\b[^.]{0,40}\b(decided|decision|approved|confirmed)\b' -or
        $t -match '(?i)\b(decided|decision|approved|confirmed)\b[^.]{0,20}\bby (the owner|the user)\b') {
        if (-not $hasDate) { $why = 'owner-attributed but undated' }
    }
    # (a) a verdict/recommendation/decision word with neither author marker nor date.
    if (-not $why -and $t -match '(?i)\b(decided|recommend(s|ed|ation)?|verdict|adopted|rejected|threshold|should)\b') {
        if (-not $hasAuthor -and -not $hasDate) { $why = 'verdict language, no author + no date' }
    }
    if ($why) {
        $attrTotal++
        if ($attrPrompts.Count -lt $attrCap) {
            $head = $t -replace '^\-\s*', ''
            if ($head.Length -gt 80) { $head = $head.Substring(0, 80) + '...' }
            $attrPrompts += "ATTRIBUTE IT ($why): $head"
        }
    }
}
if ($attrTotal -gt $attrCap) { $attrPrompts += "... and $($attrTotal - $attrCap) more" }

# --- Report ------------------------------------------------------------------
Write-Output "[verify-checkpoint] $ckPath"
Write-Output "[verify-checkpoint] paths checked: $checked"
if ($defects.Count -gt 0) { $defects | ForEach-Object { Write-Output $_ } }
if ($reviews.Count -gt 0) { Write-Output '-- REVIEW (reconcile before stamping):'; $reviews | ForEach-Object { Write-Output "  $_" } }
if ($prompts.Count -gt 0) { Write-Output '-- STALENESS PROMPTS (dispositioned -- informational):'; $prompts | ForEach-Object { Write-Output "  $_" } }
if ($staleFailures.Count -gt 0) { Write-Output '-- STALENESS FAILURES (exit 2 until each bullet is re-confirmed with [kept YYYY-MM-DD: reason] or pruned):'; $staleFailures | ForEach-Object { Write-Output "  $_" } }
if ($tagPrompts.Count -gt 0) { Write-Output '-- TAG PROMPTS (not failures -- gate + complexity pair on every Open-threads bullet, four-run order):'; $tagPrompts | ForEach-Object { Write-Output "  $_" } }
if ($attrPrompts.Count -gt 0) { Write-Output '-- ATTRIBUTION PROMPTS (not failures -- every verdict names its author + date; live sections only):'; $attrPrompts | ForEach-Object { Write-Output "  $_" } }
if ($jargonHits.Count -gt 0) { Write-Output '-- JARGON PROMPTS (not failures -- fine if already glossed in the same breath):'; $jargonHits | ForEach-Object { Write-Output "  $_" } }
if ($defects.Count -gt 0 -or $staleFailures.Count -gt 0) {
    $why = @()
    if ($defects.Count -gt 0) { $why += "$($missing.Count) dead path(s)" }
    if ($staleFailures.Count -gt 0) { $why += "$($staleFailures.Count) undispositioned stale bullet(s)" }
    Write-Output "[verify-checkpoint] EXIT 2: $($why -join '; '). Fix, then re-run; the finisher comes AFTER this passes."
    exit 2
}
Write-Output '[verify-checkpoint] clean (mechanical checks only -- REVIEW/PROMPT items above still need your judgment).'
exit 0
