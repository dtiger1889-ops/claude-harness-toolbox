# verify_checkpoint_claims.ps1 -- close step 4.5: make the verify step fail as loudly as the cap check.
# Built 2026-08-12 from the maintainer's private design record (verification-enforcement asymmetry).
# Exit contract mirrors finish-checkpoint.ps1: 0 = clean, 2 = defects found (each named).
# Coverage (honest): dead paths = HARD FAIL; git-state claims = REVIEW block to reconcile;
# stale-dated / owner-gated threads = PROMPTS unless undispositioned, then HARD FAIL (see below);
# tag/jargon/attribution prompts = advisory only; a new spec with no sourced Prior art = HARD FAIL
# (3.12); an undispositioned model recommendation in research/ = HARD FAIL (3.8); a broken
# changelog.jsonl in JSONL mode = HARD FAIL (3.10). Semantic staleness is NOT detected here.
# 3.6 attribution prompts added 2026-09-09 (unattributed verdicts / undated owner decisions).
# 3.6b notes-decision prompts, 3.6c attribution-source prompts and 3.7b defect-on-owner prompts
# are advisory only.
#
# 3.8 Recommendation failures. A file directly under <project>/research/ whose LastWriteTimeUtc is
# later than the CHECKPOINT's own previous `Last updated:` stamp, and whose content holds the dated
# attribution "model recommendation -- YYYY-MM-DD" (case-insensitive), must be named (basename) in
# an [owner]-tagged Open-threads bullet in this CHECKPOINT, or in a tracker note (a *.md in
# $env:HARNESS_TRACKER_DIR whose frontmatter `project:` matches this project's folder name) --
# otherwise the owner has no way to know the recommendation was ever filed. Undispositioned
# candidates print under "RECOMMENDATION FAILURES" and are a HARD FAIL (exit 2). Opt-out: a line
# `recommendations: advisory` in <project>/.checkpoint-verify-ignore downgrades them to REVIEW
# lines. An unparseable `Last updated:` stamp in the first 5 lines skips the check with a REVIEW line.
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
# Owner gate tag: [owner] always counts; HARNESS_OWNER_TAG adds your own name (e.g. Sam -> [Sam]).
$OwnerAlt = 'owner'
$OwnerNameEsc = $null
if ($env:HARNESS_OWNER_TAG) {
    $OwnerNameEsc = [regex]::Escape($env:HARNESS_OWNER_TAG.Trim('[', ']', ' '))
    $OwnerAlt = 'owner|' + $OwnerNameEsc
}
# Words that name the owner in prose (used by the 3.6b/3.6c/3.7b prompts): "the owner", "the user",
# plus your own name when HARNESS_OWNER_TAG is set.
$OwnerWho = if ($OwnerNameEsc) { "(?:the owner|the user|$OwnerNameEsc)" } else { '(?:the owner|the user)' }
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
    if ($ln -match "\[($OwnerAlt)\]") { $flag += 'owner-gated' }
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
    $gates = [regex]::Matches($text, "\[($OwnerAlt|agent)\]").Count
    $cplx  = [regex]::Matches($text, '\[(low|high)\]').Count
    if ($text -match '\[(quick|moderate|heavy)\]|\[owner decides[^\]]*\]') { $script:tagPrompts += "RETIRED TAG (convert to [owner]/[agent] + [low]/[high]): $h" }
    if ($gates -ne 1 -or $cplx -ne 1) { $script:tagPrompts += "TAG PAIR MISSING (need one of [owner]/[agent] and one of [low]/[high]): $h"; return }
    $rank = 0
    if ($text -match '\[agent\]') { $rank += 2 }
    if ($text -match '\[high\]')  { $rank += 1 }
    if ($rank -lt $script:prevRank -and -not $script:orderFlagged) { $script:tagPrompts += "ORDER (owner-low, owner-high, agent-low, agent-high) breaks at: $h"; $script:orderFlagged = $true }
    $script:prevRank = $rank
    # 3.7b DEFECT ON OWNER: an owner-tagged bullet that names a defect in the workspace's own tools
    # (a guard's false match, a failing script) and no step only the owner can take. The agent
    # diagnoses and fixes its own tools; only an approval, an interruption of the owner's running
    # work, or a physical or UI-only step is the owner's. An owner step must sit next to an owner
    # word (you/your/the owner/the user/he/his/she/her/they/their), so incidental words elsewhere do
    # not exempt it; pick/choose/decide never exempt (a session can phrase its own defect as a
    # choice). A refusal by the runtime's permission check exempts: that call waits for the owner.
    # Prompt only.
    if ($text -match "\[($OwnerAlt)\]" -and $text -match $script:defectRx -and $text -notmatch $script:ownerStepRx) {
        $script:tagPrompts += "DEFECT ON OWNER (the agent diagnoses and fixes its own tools; retag [agent], or name the one owner-only step left: approval, interruption, physical or UI-only): $h"
    }
}
$defectRx = '(?i)\b(false (positive|match|alarm|hit|flag)|(refuses|refused|blocked|fails|failed) (because|on)|bugs?|broken|regression|misfires?|(guard|scanner|hook|script|check|gate|verifier|test)s? (refused|refuses|blocked|blocks|fails?|failed|failing|errors?))\b'
$ownerWords = 'you|your|owner|owner''s|user|user''s|he|his|she|her|they|their'
if ($OwnerNameEsc) { $ownerWords += "|$OwnerNameEsc|$OwnerNameEsc's" }
$ownerStepRx = "(?i)\b($ownerWords)\b\W+(\w+\W+){0,3}?(approv\w*|sign(s|ed|ing)? in|log(s|ged|ging)? in|oauth|buy\w*|purchas\w*|pay\w*|install\w*|plug\w*|tap\w*|click\w*|restart\w*|reboot\w*|call\w*|phone|device|account|card|money|preferen\w*|prefer\w*|taste|priorit\w*|password|token)\b|\bauto-mode\b|\b(permission|safety) check\b|\bclassifier\b"
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

# --- 3.6b Notes-decision prompts -----------------------------------------------
# A note in your notes system whose "Decision ..." heading was written by a model reads as the
# owner's decision to the next session. Runs only when HARNESS_NOTES_ROOT is set: for every note this
# CHECKPOINT points at (a backticked path or markdown link in a live section that resolves under the
# notes root), flag any "Decision" heading or bold lead line with no `<owner> decision -- <date>` tag
# (owner = "owner", "user" or your HARNESS_OWNER_TAG name) on it or the 3 lines below. A line openly
# tagged as a model or author-unknown verdict is not flagged. Wikilinks ([[...]]) are not followed.
# Prompt only: never a failure, never changes the exit code.
if ($NotesRoot) {
    try {
        $notesFull = [System.IO.Path]::GetFullPath($NotesRoot)
        $notePaths = New-Object System.Collections.Generic.HashSet[string]
        if (Test-Path -LiteralPath $notesFull) {
            foreach ($c in $cands) {
                $t = $c.Trim().Trim('"').Trim("'")
                if ($t -notmatch '\.md$' -or $t -match '[|<>*?{}]') { continue }
                $exp = ($t -replace '^~', $env:USERPROFILE) -replace '/', '\'
                $p = if ($exp -match '^[A-Za-z]:') { $exp } else { Join-Path $notesFull $exp }
                if ((Test-Path -LiteralPath $p -PathType Leaf) -and
                    ([System.IO.Path]::GetFullPath($p)).StartsWith($notesFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$notePaths.Add([System.IO.Path]::GetFullPath($p))
                }
            }
        }
        $ownerDecRx = '(?i)\b(owner|user'
        if ($OwnerNameEsc) { $ownerDecRx += "|$OwnerNameEsc" }
        # Em and en dash built from code points so the file stays ASCII (powershell.exe 5.1 reads a
        # BOM-less script as ANSI).
        $ownerDecRx += ')\s+decision\s*(--|-|' + [char]0x2014 + '|' + [char]0x2013 + '|:)\s*20\d{2}-\d{2}-\d{2}'
        $vdTotal = 0
        foreach ($vn in $notePaths) {
            $vl = [System.IO.File]::ReadAllLines($vn)
            for ($i = 0; $i -lt $vl.Count; $i++) {
                $hl = $vl[$i]
                if ($hl -notmatch '(?i)^\s*(#{1,6}\s|\*\*|-\s+\*\*).{0,40}\bdecision') { continue }
                $win = ($vl[$i..([Math]::Min($i + 3, $vl.Count - 1))]) -join ' '
                if ($win -match $ownerDecRx) { continue }
                if ($hl -match '(?i)\b(model|Codex|Claude|author unknown)\b') { continue }   # openly a model draft
                $vdTotal++
                if ($vdTotal -le $attrCap) {
                    $head = $hl.Trim()
                    if ($head.Length -gt 80) { $head = $head.Substring(0, 80) + '...' }
                    $rel = $vn.Substring($notesFull.Length).TrimStart('\')
                    $attrPrompts += "NOTE DECISION UNTAGGED ($rel line $($i + 1); treat as a model draft unless it carries an '<owner> decision -- <date>' tag): $head"
                }
            }
        }
        if ($vdTotal -gt $attrCap) { $attrPrompts += "... and $($vdTotal - $attrCap) more note decision line(s)" }
    } catch {
        $attrPrompts += "NOTE DECISION CHECK skipped (error reading a pointed-at note: $($_.Exception.Message))"
    }
}

# --- 3.6c Attribution source prompts -------------------------------------------
# A line recorded as the owner's decision gets built on as theirs, so a NEW line that credits the
# owner must quote their words, name its source, or say "evidence unavailable"; one that credits
# them with a hold, pause, skip or cancel needs their own action word inside a quote of theirs.
# "New" = not in the baseline: the file at git HEAD, or the file named by $env:HARNESS_VERIFY_BASELINE
# (tests); with neither, lines that carry today's or yesterday's UTC date. Owner words: "the owner",
# "the user", plus your HARNESS_OWNER_TAG name. Headings and [owner] tags are not credits.
# Prompt only: never a failure, exit code unchanged.
$srcPrompts = @()
$srcTotal = 0
try {
    $baseLines = $null
    if ($env:HARNESS_VERIFY_BASELINE -and (Test-Path -LiteralPath $env:HARNESS_VERIFY_BASELINE)) {
        $baseLines = [System.IO.File]::ReadAllLines($env:HARNESS_VERIFY_BASELINE)
    } else {
        try {
            $gpsi = New-Object System.Diagnostics.ProcessStartInfo
            $gpsi.FileName = 'git'
            $gpsi.Arguments = "-C `"$projRoot`" show `"HEAD:./$(Split-Path -Leaf $ckPath)`""
            $gpsi.RedirectStandardOutput = $true; $gpsi.RedirectStandardError = $true; $gpsi.UseShellExecute = $false
            $gpsi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
            $gp = [System.Diagnostics.Process]::Start($gpsi)
            $gout = $gp.StandardOutput.ReadToEnd(); [void]$gp.StandardError.ReadToEnd(); $gp.WaitForExit()
            if ($gp.ExitCode -eq 0) { $baseLines = $gout -split "`r?`n" }
        } catch { $baseLines = $null }
    }
    $baseSet = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($null -ne $baseLines) { foreach ($bl in $baseLines) { [void]$baseSet.Add($bl.Trim()) } }
    $today = [DateTime]::UtcNow.ToString('yyyy-MM-dd'); $yday = [DateTime]::UtcNow.AddDays(-1).ToString('yyyy-MM-dd')
    $creditRx = "(?i)\b$OwnerWho\s+(decision|rule|pick|correction|ask)\b|\b$OwnerWho's\s+(words|ask|pick|rule|decision|call|choice)\b|\b$OwnerWho\s*(,|:|--)|\(\s*$OwnerWho\b|\b$OwnerWho\s+(said|says|asked|wants|wanted|chose|picked|decided|approved|confirmed|told|ruled|insisted)\b"
    $holdRx = '(?i)\b(on hold|hold|held|paused?|skip(ped|s)?|cancel(l?ed|s)?|deferred|parked)\b'
    $actionRx = '(?i)\b(hold|wait|skip|stop|pause|cancel|drop|defer|later|not now|don''?t|do not|leave it)\b'
    # A quote is THEIRS only when it is introduced as theirs ("<owner> ...: / said / asked / -- / ,"
    # then the quote, within 40 characters and no sentence break) or tagged right after it
    # ("..." (<owner> ...). Any other quotation in the line is not their source. Curly quotes are
    # built from code points so the file stays ASCII (powershell.exe 5.1 reads a BOM-less script as ANSI).
    $lq = [string][char]0x201C; $rq = [string][char]0x201D
    $qRx = "[`"$lq]([^`"$rq]{2,})[`"$rq]"
    $hisQuoteRx = "(?i)\b$OwnerWho\b[^`"$lq;.]{0,40}?(:|\bsaid\b|\bsays\b|\basked\b|\bwrote\b|\btold\b|--|,)\s*$qRx|$qRx\s*\(\s*$OwnerWho\b"
    $otherSourceRx = '(?i)evidence unavailable|board pick|transcript:|tracker row|\breply\b|changelog|\.md\b|\.jsonl\b|grill q\d+'
    # Logical records: a line plus its indented continuation lines (a wrapped bullet is one record).
    $records = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($ln in $lines) {
        if ($ln.Trim().Length -eq 0 -or $ln.Trim() -match '^#') { if ($cur) { $records.Add($cur) }; $cur = $null; continue }
        $isCont = ($cur -and $ln -match '^\s{2,}\S' -and $ln -notmatch '^\s*([-*]|\d+[.)])\s')
        if ($isCont) { $cur.Parts.Add($ln.Trim()); continue }
        if ($cur) { $records.Add($cur) }
        $cur = @{ Parts = New-Object System.Collections.Generic.List[string] }
        $cur.Parts.Add($ln.Trim())
    }
    if ($cur) { $records.Add($cur) }
    foreach ($rec in $records) {
        $t = [string]::Join(' ', $rec.Parts.ToArray())
        if ($null -ne $baseLines) {
            if (-not ($rec.Parts | Where-Object { -not $baseSet.Contains($_) })) { continue }
        } elseif ($t -notmatch [regex]::Escape($today) -and $t -notmatch [regex]::Escape($yday)) { continue }
        if ($t -notmatch $creditRx) { continue }
        $why = $null
        if ($t -notmatch $hisQuoteRx -and $t -notmatch $otherSourceRx) {
            $why = "NAME THE SOURCE (quote the owner's words, name the source, or write 'evidence unavailable' / relabel it model)"
        } else {
            # A clause that credits the owner with a hold/skip/cancel needs their action word in a quote of theirs.
            foreach ($cl in ($t -split ';|(?<=[.!?])\s+')) {
                if ($cl -notmatch $creditRx -or $cl -notmatch $holdRx) { continue }
                $his = @([regex]::Matches($cl, $hisQuoteRx) | ForEach-Object { $_.Groups[2].Value + $_.Groups[3].Value })
                if (-not ($his | Where-Object { $_ -match $actionRx })) {
                    $why = "HOLD WITHOUT THE OWNER'S ACTION WORD (a hold, pause, skip or cancel credited to the owner quotes their own action word -- hold, wait, skip, stop, drop -- or is relabelled model)"
                    break
                }
            }
        }
        if (-not $why) { continue }
        $srcTotal++
        if ($srcPrompts.Count -lt $attrCap) {
            $head = $t -replace '^\-\s*', ''
            if ($head.Length -gt 90) { $head = $head.Substring(0, 90) + '...' }
            $srcPrompts += "${why}: $head"
        }
    }
    if ($srcTotal -gt $attrCap) { $srcPrompts += "... and $($srcTotal - $attrCap) more" }
} catch {
    $srcPrompts += "ATTRIBUTION SOURCE CHECK skipped (error: $($_.Exception.Message))"
}

# --- 3.9 Verified-claim prompts (added 2026-09-23) ----------------------------
# A stale "verified" claim is trusted more than an ordinary claim, so it costs a future session
# the most when it has quietly gone false. A Status or Key decisions line that uses a
# verification word must name WHAT was run and WHEN. The line passes when it carries a date
# (YYYY-MM-DD) AND a run name (a backticked name or a script/test file name), or a test count
# ("27 tests", "12 passed", "30/30"). Negated uses ("not verified", "never tested") and owner
# checks ("the user confirmed", "owner-verified") are not claims of a run; "green" counts only
# in its pass sense. A dry run over 53 real CHECKPOINTs tuned these exemptions (the colour
# green, "109 JVM tests green"). Advisory only, never a failure; exit code unchanged.
$verPrompts = @()
$verTotal = 0
$verCap = 6
# "green" counts only in a pass sense ("tests green", "is green", "all green"), never as a colour.
$verWord = '(?i)\b(live-verified|verified|tested|passes|passing|confirmed)\b|(?i)(?<=\b(is|are|all|tests?|suite|build|CI|stays|went|now|still)\s)green\b'
$inVerSec = $false
foreach ($ln in $lines) {
    if ($ln -match '^##\s') { $inVerSec = ($ln -match '^##\s+(Status|Key decisions)'); continue }
    if (-not $inVerSec) { continue }
    $t = $ln.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t -match '^\s*-\s+20\d{2}-\d{2}-\d{2}\s+--') { continue }   # changelog-shaped bullet: history
    # Drop negated and owner-confirmation phrases before looking for the claim word.
    $scan = $t -replace '(?i)\b(not|never|nothing|none)\s+(yet\s+|been\s+|was\s+|were\s+|is\s+)?(live-verified|verified|tested|confirmed)\b', ' '
    $scan = $scan -replace '(?i)\b(owner|the user|user|he|she|they)(\s+(has\s+|had\s+)?|-)(confirmed|verified|passes)\b', ' '
    $vm = [regex]::Match($scan, $verWord)
    if (-not $vm.Success) { continue }
    $hasDate  = ($t -match '\b20\d{2}-\d{2}-\d{2}\b')
    $hasName  = ($t -match '`[^`\r\n]+`' -or $t -match '(?i)\b[\w.-]+\.(ps1|py|sh|js|ts|mjs|cjs|bat|cmd|json|yml|yaml)\b')
    $hasCount = ($t -match '(?i)\b\d+\s+(\w+\s+)?(tests?|passed|passing|cases?|checks?|goldens?)\b' -or $t -match '\b\d+\s*/\s*\d+\b')   # "30/30", "tests 23/23", "(7/7)"
    if ($hasCount -or ($hasDate -and $hasName)) { continue }
    $verTotal++
    if ($verPrompts.Count -lt $verCap) {
        $start = [Math]::Max(0, $vm.Index - 40)
        $len = [Math]::Min($scan.Length - $start, 100)
        $ex = $scan.Substring($start, $len).Trim() -replace '^\-\s*', '' -replace '\s{2,}', ' '
        if ($start -gt 0) { $ex = '...' + $ex }
        if ($start + $len -lt $scan.Length) { $ex = $ex + '...' }
        $verPrompts += "VERIFIED-CLAIM PROMPT: $ex -- name what was run and when"
    }
}
if ($verTotal -gt $verCap) { $verPrompts += "... and $($verTotal - $verCap) more" }

# --- 3.8 Recommendation failures -------------------------------------------------
# See header for the rationale and the .checkpoint-verify-ignore opt-out.
$recoFailures = @()
$recoAdvisory = $false
foreach ($igl in @($igRaw)) {
    if ($igl -match '^recommendations\s*:\s*advisory\s*$') { $recoAdvisory = $true }
}
# Scan the first 5 lines for the stamp, exactly as finish-checkpoint.ps1 does (a project file puts
# its title on line 1 and the stamp on line 2).
$stampMatch = $null
for ($si = 0; $si -lt [Math]::Min(5, $lines.Count); $si++) {
    $m = [regex]::Match($lines[$si], '^Last updated:\s*(20\d{2}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+UTC')
    if ($m.Success) { $stampMatch = $m; break }
}
$researchDir = Join-Path $projRoot 'research'
if (-not (Test-Path -LiteralPath $researchDir)) {
    # nothing to check
} elseif (-not $stampMatch) {
    $reviews += "RECOMMENDATION CHECK SKIPPED -- no parseable 'Last updated' stamp in the first 5 lines (expected 'Last updated: YYYY-MM-DD HH:MM UTC'); cannot tell which research/ files are new."
} else {
    try {
        $prevStamp = [datetime]::ParseExact("$($stampMatch.Groups[1].Value) $($stampMatch.Groups[2].Value)", 'yyyy-MM-dd HH:mm', $null)
        $prevStamp = [datetime]::SpecifyKind($prevStamp, [System.DateTimeKind]::Utc)
        $slug = Split-Path -Leaf $projRoot
        $trackerFiles = @()
        if ($env:HARNESS_TRACKER_DIR -and (Test-Path -LiteralPath $env:HARNESS_TRACKER_DIR)) {
            $trackerFiles = @(Get-ChildItem -LiteralPath $env:HARNESS_TRACKER_DIR -Filter '*.md' -File -ErrorAction SilentlyContinue)
        }
        $recoRx = '(?i)model recommendation\s*(--|-|' + [char]0x2014 + ')\s*20\d{2}-\d{2}-\d{2}'
        $candFiles = @(Get-ChildItem -LiteralPath $researchDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '(?i)archive' -and $_.LastWriteTimeUtc -gt $prevStamp })
        foreach ($cf in $candFiles) {
            $body = [System.IO.File]::ReadAllText($cf.FullName)
            if ($body -notmatch $recoRx) { continue }   # dated attribution form only; a quoted mention in prose is not a recommendation
            $baseNoExt = $cf.BaseName
            $baseExt = $cf.Name
            $dispositioned = $false
            foreach ($sf in $trackerFiles) {
                $sfText = [System.IO.File]::ReadAllText($sf.FullName)
                if ($sfText.IndexOf($baseNoExt, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and
                    $sfText.IndexOf($baseExt, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $pm = [regex]::Match($sfText, '(?im)^project:\s*(\S+)\s*$')
                if ($pm.Success -and $pm.Groups[1].Value.Trim() -ieq $slug) { $dispositioned = $true; break }
            }
            if (-not $dispositioned) {
                # An [owner]-tagged Open-threads bullet in THIS CHECKPOINT naming the file also counts.
                $inOT = $false
                foreach ($ln in $lines) {
                    if ($ln -match '^##\s') { $inOT = ($ln -match '^##\s+Open threads'); continue }
                    if (-not $inOT) { continue }
                    if ($ln -match '^\s*-\s' -and $ln -match "\[($OwnerAlt)\]" -and
                        ($ln.IndexOf($baseNoExt, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                         $ln.IndexOf($baseExt, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) { $dispositioned = $true; break }
                }
            }
            if (-not $dispositioned) {
                $firstLine = ($body -split "`r?`n" | Where-Object { $_ -match $recoRx } | Select-Object -First 1)
                if ($null -eq $firstLine) { $firstLine = '' }
                $firstLine = $firstLine.Trim()
                if ($firstLine.Length -gt 90) { $firstLine = $firstLine.Substring(0, 90) }
                $recoFailures += "$($cf.Name): $firstLine"
            }
        }
    } catch {
        $reviews += "RECOMMENDATION CHECK SKIPPED -- error scanning research/ against the stamp: $($_.Exception.Message)"
    }
}
if ($recoAdvisory -and $recoFailures.Count -gt 0) {
    foreach ($f in $recoFailures) { $reviews += "RECOMMENDATION FAILURE (advisory per .checkpoint-verify-ignore: recommendations: advisory): $f" }
    $recoFailures = @()
}

# --- 3.12 Prior-art failures (added 2026-11-14) --------------------------------
# Pairs with the spec skill's step 1b (prior-art pass). A *.md directly under <project>/specs/ or
# <project>/outbound/ holding a line-start `Status:` and `Created: <YYYY-MM-DD>` (anywhere outside
# fenced code; a build plan may sit between them) dated on or after $priorArtRollout is a HARD FAIL
# (exit 2) unless it has a `Prior art` heading whose section holds `searched <YYYY-MM-DD>:` followed
# by a quoted query or a cited sweep file (*.md), and at least one source outside the quoted queries:
# an http link, a .md path, a file:line, or the literal "nothing found". Keyed on the spec's own
# Created: date, never file edit time, so older specs and non-spec files are never checked. Fenced
# code (``` or ~~~, closed only by the same character at the same or greater length) is skipped.
# Opt-out: `prior-art: advisory` in .checkpoint-verify-ignore (failures then print as REVIEW lines).
$priorArtRollout = [datetime]'2026-11-14'
$paFailures = @()
$paAdvisory = $false
foreach ($igl in @($igRaw)) {
    if ($igl -match '^prior-art\s*:\s*advisory\s*$') { $paAdvisory = $true }
}
function Get-UnfencedLines([string[]]$L) {
    $out = New-Object System.Collections.Generic.List[string]
    $fc = $null; $fl = 0
    foreach ($ln in $L) {
        if ($ln -match '^\s*(`{3,}|~{3,})(.*)$') {
            $run = $Matches[1]; $rest = $Matches[2]
            if ($null -eq $fc) { $fc = $run[0]; $fl = $run.Length; continue }
            if ($run[0] -eq $fc -and $run.Length -ge $fl -and $rest.Trim() -eq '') { $fc = $null; continue }
        }
        if ($null -eq $fc) { $out.Add($ln) }
    }
    return ,$out.ToArray()
}
function Get-PriorArtProblem([string[]]$L) {
    $inSec = $false; $secLevel = 0; $found = $false
    $sec = New-Object System.Collections.Generic.List[string]
    foreach ($ln in (Get-UnfencedLines $L)) {
        # A heading is indented at most 3 spaces; 4+ is an indented code example.
        if ($ln -match '^\s{0,3}(#{1,6})\s') {
            $lvl = $Matches[1].Length
            if ($inSec -and $lvl -gt $secLevel) { $sec.Add($ln); continue }
            if ($inSec) { break }
            if ($ln -match '^\s{0,3}#{1,6}\s+Prior art\b') { $inSec = $true; $found = $true; $secLevel = $lvl; $sec.Add($ln) }
            continue
        }
        if ($inSec) { $sec.Add($ln) }
    }
    if (-not $found) { return 'no Prior art section' }
    $t = [string]::Join("`n", [string[]]$sec.ToArray())
    $sm = [regex]::Match($t, '(?i)searched\s+\d{4}-\d{2}-\d{2}\s*:')
    if (-not $sm.Success) { return 'Prior art section has no "searched <YYYY-MM-DD>:" record' }
    $after = $t.Substring($sm.Index + $sm.Length)
    if ($after -notmatch '"[^"\r\n]+"' -and $after -notmatch '[\w./\\-]+\.md\b') {
        return 'Prior art "searched" record names no quoted query and no earlier sweep file'
    }
    # Sources are judged with the quoted queries removed, so a query naming a file is not a citation.
    # The record is its "searched" line plus the lines right after it that hold only quoted queries
    # (bulleted or not); the first line with anything else ends it and keeps its quotes.
    $inRec = $false
    $tq = [string]::Join("`n", @($t -split "`n" | ForEach-Object {
        if ($_ -match '(?i)searched\s+\d{4}-\d{2}-\d{2}\s*:') { $inRec = $true; $_ -replace '"[^"\r\n]*"', ' ' }
        elseif ($inRec -and $_ -match '^\s*([-*]\s+|\d+[.)]\s+)?("[^"\r\n]*"[\s,;]*)+$') { $_ -replace '"[^"\r\n]*"', ' ' }
        else { $inRec = $false; $_ } }))
    # file:line needs a path (a slash) or a file name with an extension, so a label like "Priority:1" is not one.
    $fileLine = '[\w.-]*[/\\][\w./\\-]*:\d+|\b[\w-]+\.\w+:\d+'
    if ($tq -notmatch 'https?://' -and $tq -notmatch '[\w./\\-]+\.md\b' -and $tq -notmatch $fileLine -and $tq -notmatch '(?i)nothing found') {
        return 'Prior art section cites no source (no link, no file path, no "nothing found")'
    }
    return $null
}
try {
    foreach ($sdn in @('specs', 'outbound')) {
        $sDir = Join-Path $projRoot $sdn
        if (-not (Test-Path -LiteralPath $sDir)) { continue }
        foreach ($sf in @(Get-ChildItem -LiteralPath $sDir -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
            $sl = [System.IO.File]::ReadAllLines($sf.FullName)
            $head = [string[]](Get-UnfencedLines $sl)
            if (-not ($head | Where-Object { $_ -match '^\s*Status\s*:' })) { continue }
            $cl = @($head | Where-Object { $_ -match '^\s*Created\s*:\s*(\d{4}-\d{2}-\d{2})' } | Select-Object -First 1)
            if ($cl.Count -eq 0) { continue }
            $null = $cl[0] -match '(\d{4}-\d{2}-\d{2})'
            try { $cd = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) } catch { continue }
            if ($cd -lt $priorArtRollout) { continue }
            $prob = Get-PriorArtProblem $sl
            if ($prob) { $paFailures += "$sdn/$($sf.Name): $prob" }
        }
    }
} catch {
    $reviews += "PRIOR-ART CHECK SKIPPED -- error scanning specs/: $($_.Exception.Message)"
}
if ($paAdvisory -and $paFailures.Count -gt 0) {
    foreach ($f in $paFailures) { $reviews += "PRIOR-ART FAILURE (advisory per .checkpoint-verify-ignore: prior-art: advisory): $f" }
    $paFailures = @()
}

# --- 3.10 JSONL-mode changelog check -------------------------------------------
# A project is in JSONL mode iff changelog.jsonl sits beside its CHECKPOINT.md (history lives there,
# append-only, oldest first; see changelog_jsonl.py). Then (a) every line of that file must parse as
# one JSON object, and (b) the CHECKPOINT's `## Harness changelog` section must hold exactly ONE
# entry, equal to the file's last record (heading byte-equal, body equal up to trailing whitespace)
# -- otherwise the next close's swap could drop an entry that exists only inline. Both are HARD
# FAILS (exit 2). A pointer line that does not name changelog.jsonl is a REVIEW line.
$jsonlFailures = @()
$jsonlPath = Join-Path $projRoot 'changelog.jsonl'
if (Test-Path -LiteralPath $jsonlPath) {
    $jl = [System.IO.File]::ReadAllLines($jsonlPath, (New-Object System.Text.UTF8Encoding($false)))
    $lastRec = $null; $badLines = @()
    for ($i = 0; $i -lt $jl.Count; $i++) {
        if ($jl[$i].Trim() -eq '') { $badLines += ($i + 1); continue }
        try {
            $rec = $jl[$i] | ConvertFrom-Json -ErrorAction Stop
            if ($rec.kind -ne 'preamble') {
                if ($null -eq $rec.heading -or $null -eq $rec.body) { $badLines += ($i + 1); continue }
                $lastRec = $rec
            }
        } catch { $badLines += ($i + 1) }
    }
    if ($badLines.Count -gt 0) {
        $jsonlFailures += "changelog.jsonl has $($badLines.Count) line(s) that are not one JSON entry object (line(s) $((@($badLines | Select-Object -First 10)) -join ', ')) -- the file is append-only; repair by hand from version control"
    }
    # Inline entries: from the first `### ` in the section to the `Older entries` pointer
    # (when it sits below them) or the section end.
    $s = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## Harness changelog') { $s = $i; break } }
    if ($s -lt 0) {
        $jsonlFailures += "JSONL mode but no '## Harness changelog' section -- it must hold the newest entry plus the pointer line"
    } else {
        $e = $lines.Count; for ($i = $s + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $e = $i; break } }
        $p = -1; for ($i = $s + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^Older entries') { $p = $i; break } }
        $f = -1; for ($i = $s + 1; $i -lt $e; $i++) { if ($lines[$i] -match '^### ') { $f = $i; break } }
        if ($p -lt 0 -or $lines[$p] -notmatch 'changelog\.jsonl') { $reviews += "JSONL mode: the changelog section has no 'Older entries:' pointer naming changelog.jsonl" }
        $inl = @()
        if ($f -ge 0) {
            $r = if ($p -gt $f) { $p } else { $e }
            $cur = $null
            for ($i = $f; $i -lt $r; $i++) {
                if ($lines[$i] -match '^### ') { if ($cur) { $inl += $cur }; $cur = @{ Heading = $lines[$i]; Body = New-Object System.Collections.Generic.List[string] } }
                else { $cur.Body.Add($lines[$i]) }
            }
            if ($cur) { $inl += $cur }
        }
        if ($inl.Count -ne 1) {
            $jsonlFailures += "JSONL mode keeps exactly ONE inline changelog entry (the newest); found $($inl.Count). Append new entries with changelog_jsonl.py append --checkpoint, which swaps the inline entry"
        } elseif ($null -eq $lastRec) {
            $jsonlFailures += "changelog.jsonl has no entry records, so the inline entry is in no durable record"
        } else {
            $inBody = ([string]::Join("`n", [string[]]$inl[0].Body.ToArray())).TrimEnd()
            $recBody = ([string]$lastRec.body).Replace("`r`n", "`n").TrimEnd()
            if ($inl[0].Heading -ne $lastRec.heading -or $inBody -ne $recBody) {
                $hd = $inl[0].Heading; if ($hd.Length -gt 90) { $hd = $hd.Substring(0, 90) + '...' }
                $jsonlFailures += "inline changelog entry is not the last line of changelog.jsonl ($hd) -- append it with changelog_jsonl.py append (never edit the JSONL by hand)"
            }
        }
    }
}

# --- Report ------------------------------------------------------------------
Write-Output "[verify-checkpoint] $ckPath"
Write-Output "[verify-checkpoint] paths checked: $checked"
if ($defects.Count -gt 0) { $defects | ForEach-Object { Write-Output $_ } }
if ($reviews.Count -gt 0) { Write-Output '-- REVIEW (reconcile before stamping):'; $reviews | ForEach-Object { Write-Output "  $_" } }
if ($prompts.Count -gt 0) { Write-Output '-- STALENESS PROMPTS (dispositioned -- informational):'; $prompts | ForEach-Object { Write-Output "  $_" } }
if ($staleFailures.Count -gt 0) { Write-Output '-- STALENESS FAILURES (exit 2 until each bullet is re-confirmed with [kept YYYY-MM-DD: reason] or pruned):'; $staleFailures | ForEach-Object { Write-Output "  $_" } }
if ($recoFailures.Count -gt 0) { Write-Output '-- RECOMMENDATION FAILURES (exit 2 until each filed recommendation has an [owner] thread or a tracker note naming it):'; $recoFailures | ForEach-Object { Write-Output "  $_" } }
if ($tagPrompts.Count -gt 0) { Write-Output '-- TAG PROMPTS (not failures -- gate + complexity pair on every Open-threads bullet, four-run order):'; $tagPrompts | ForEach-Object { Write-Output "  $_" } }
if ($attrPrompts.Count -gt 0) { Write-Output '-- ATTRIBUTION PROMPTS (not failures -- every verdict names its author + date; live sections only):'; $attrPrompts | ForEach-Object { Write-Output "  $_" } }
if ($srcPrompts.Count -gt 0) { Write-Output '-- ATTRIBUTION SOURCE PROMPTS (not failures -- a new line crediting the owner quotes their words, names its source, or says "evidence unavailable"):'; $srcPrompts | ForEach-Object { Write-Output "  $_" } }
if ($verPrompts.Count -gt 0) { Write-Output '-- VERIFIED-CLAIM PROMPTS (not failures -- a Status/Key decisions line saying verified/tested/green/passes/confirmed names what was run and when):'; $verPrompts | ForEach-Object { Write-Output "  $_" } }
if ($jargonHits.Count -gt 0) { Write-Output '-- JARGON PROMPTS (not failures -- fine if already glossed in the same breath):'; $jargonHits | ForEach-Object { Write-Output "  $_" } }
if ($paFailures.Count -gt 0) { Write-Output '-- PRIOR-ART FAILURES (exit 2 until each spec gets a sourced Prior art section -- spec skill step 1b):'; $paFailures | ForEach-Object { Write-Output "  $_" } }
if ($jsonlFailures.Count -gt 0) { Write-Output '-- CHANGELOG.JSONL FAILURES (exit 2 -- JSONL mode: the file must parse and its last line must equal the one inline entry):'; $jsonlFailures | ForEach-Object { Write-Output "  $_" } }
if ($defects.Count -gt 0 -or $staleFailures.Count -gt 0 -or $paFailures.Count -gt 0 -or $recoFailures.Count -gt 0 -or $jsonlFailures.Count -gt 0) {
    $why = @()
    if ($defects.Count -gt 0) { $why += "$($missing.Count) dead path(s)" }
    if ($staleFailures.Count -gt 0) { $why += "$($staleFailures.Count) undispositioned stale bullet(s)" }
    if ($paFailures.Count -gt 0) { $why += "$($paFailures.Count) spec(s) without a sourced Prior art section" }
    if ($recoFailures.Count -gt 0) { $why += "$($recoFailures.Count) undispositioned recommendation(s)" }
    if ($jsonlFailures.Count -gt 0) { $why += "$($jsonlFailures.Count) changelog.jsonl failure(s)" }
    Write-Output "[verify-checkpoint] EXIT 2: $($why -join '; '). Fix, then re-run; the finisher comes AFTER this passes."
    exit 2
}
Write-Output '[verify-checkpoint] clean (mechanical checks only -- REVIEW/PROMPT items above still need your judgment).'
exit 0
