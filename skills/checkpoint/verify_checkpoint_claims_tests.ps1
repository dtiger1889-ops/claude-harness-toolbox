# Tests for verify_checkpoint_claims.ps1. Runs the verifier exactly as the checkpoint skill does
# (powershell.exe -NoProfile -File, one CHECKPOINT path) against throwaway fixture files and checks
# exit code + stdout. Covers 3.6b, 3.6c, 3.7b, 3.8, 3.9, 3.10 and 3.12.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File verify_checkpoint_claims_tests.ps1
# Fixtures are written under %TEMP%\vcc_tests_<id> and left there for inspection.
$verifier = Join-Path $PSScriptRoot 'verify_checkpoint_claims.ps1'
$root = Join-Path $env:TEMP ('vcc_tests_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
[void](New-Item -ItemType Directory -Path $root -Force)
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
$n = 0
# Keep the caller's environment out of the fixtures.
foreach ($v in 'HARNESS_OWNER_TAG', 'HARNESS_NOTES_ROOT', 'HARNESS_TRACKER_DIR', 'HARNESS_VERIFY_BASELINE', 'HARNESS_WORKSPACE_ROOT') {
    Remove-Item "Env:$v" -ErrorAction SilentlyContinue
}

function Invoke-Verifier([string]$status, [string]$keyDecisions = '', [string]$extra = '', [string]$stampLine = '') {
    $script:n++
    $proj = Join-Path $script:root ("proj$script:n")
    [void](New-Item -ItemType Directory -Path $proj -Force)
    if ($stampLine -eq '') { $stampLine = "Last updated: $script:stamp UTC (v1)" }
    $body = "# fixture`r`n$stampLine`r`n`r`n## Status`r`n$status`r`n`r`n"
    if ($keyDecisions -ne '') { $body += "## Key decisions`r`n$keyDecisions`r`n`r`n" }
    $body += "## Open threads`r`n**Agent-side**`r`n- Nothing here yet. [agent] [low]`r`n`r`n$extra"
    $ck = Join-Path $proj 'CHECKPOINT.md'
    [System.IO.File]::WriteAllText($ck, $body)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:verifier`" -Checkpoint `"$ck`""
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
    return @{ code = $p.ExitCode; out = $out; err = $err }
}
function Next-Proj { $np = Join-Path $script:root ("proj$($script:n + 1)"); [void](New-Item -ItemType Directory -Path $np -Force); return $np }

$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { $script:pass++; Write-Output "PASS  $name" } else { $script:fail++; Write-Output "FAIL  $name  $detail" }
}

# --- 3.9 Verified-claim prompts ----------------------------------------------------
function Prompted($r) { return ($r.out -match 'VERIFIED-CLAIM PROMPT:') }
$r = Invoke-Verifier 'Hook installed and verified working on the desktop.'
Check 'P1 bare verified prompts' ((Prompted $r) -and $r.out -match 'name what was run and when') "out=$($r.out)"
$r = Invoke-Verifier 'Build is green on main after the refactor.'
Check 'P2 bare green prompts' (Prompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'Nothing to report.' '- Schema confirmed with `validate_board.py`.'
Check 'P3 Key decisions: run name without date prompts' (Prompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'Restore path tested 2026-09-20 on the spare disk.'
Check 'P4 date without run name prompts' (Prompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'Sync passes everywhere now.'
Check 'P5 prompt is advisory, exit 0' ((Prompted $r) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$many = (1..8 | ForEach-Object { "Piece $_ verified." }) -join "`r`n"
$r = Invoke-Verifier $many
$cnt = ([regex]::Matches($r.out, 'VERIFIED-CLAIM PROMPT:')).Count
Check 'P6 cap at 6 with overflow line' ($cnt -eq 6 -and $r.out -match '\.\.\. and 2 more') "count=$cnt out=$($r.out)"
$r = Invoke-Verifier 'CI is green again.'
Check 'P7 pass-sense green prompts' (Prompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'Gate verified 2026-09-20 by `gate_tests.ps1`.'
Check 'C1 date + backticked name is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'question_guard tested against chooser answers (17 tests).'
Check 'C2 N tests count is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Collector passes 23/23 on the renamed field.'
Check 'C3 N/N pass count is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Not yet verified; waiting on the next reboot.'
Check 'C4 negated verified is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'The user confirmed the three-column layout.'
Check 'C5 user confirmed is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Quiet week.' '' "## Harness changelog`r`n### 2026-09-01 -- thing`r`n- Hook verified working.`r`n"
Check 'C6 changelog verified is ignored' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Greenhouse scraper still unverified against the new layout.'
Check 'C7 unverified / greenhouse do not trigger' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Theme is dark blue with green done-sets.'
Check 'C8 colour green is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier '109 JVM tests green after the port.'
Check 'C9 N qualifier tests count is clean' (-not (Prompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'Import done and owner-verified on the phone.'
Check 'C10 owner-verified is clean' (-not (Prompted $r)) "out=$($r.out)"

# --- 3.10 JSONL mode ---------------------------------------------------------------
function Invoke-JsonlVerifier([string]$section, [string]$jsonl) {
    $np = Next-Proj
    [System.IO.File]::WriteAllText((Join-Path $np 'changelog.jsonl'), $jsonl, (New-Object System.Text.UTF8Encoding($false)))
    return Invoke-Verifier 'Quiet.' '' $section
}
$ptr = 'Older entries: changelog.jsonl (append-only, oldest first; search with grep, render with changelog_jsonl.py render).'
$recOld = '{"date":"2026-10-01","title":"older","author":"","body":"- old body\n\n","heading":"### 2026-10-01 -- older","origin":"archive"}'
# Non-ASCII stays out of this file's literals (powershell.exe 5.1 reads a BOM-less script as ANSI).
$dash = [string][char]0x2014
$jdash = [string][char]92 + 'u2014'   # the six-character JSON escape for an em dash
$recNew = '{"date":"2026-10-02","title":"newest ' + $jdash + ' dash","author":"model -- 2026-10-02","body":"- new body (model -- 2026-10-02)\n\n","heading":"### 2026-10-02 -- newest ' + $jdash + ' dash","origin":"checkpoint"}'
$secOk = "## Harness changelog`r`n### 2026-10-02 -- newest $dash dash`r`n- new body (model -- 2026-10-02)`r`n`r`n$ptr`r`n"
function JsonlFailed($r) { return ($r.out -match 'CHANGELOG\.JSONL FAILURES') }
$r = Invoke-JsonlVerifier $secOk "$recOld`n$recNew`n"
Check 'J1 matching inline entry is clean' ((-not (JsonlFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-JsonlVerifier ($secOk -replace 'new body', 'edited body') "$recOld`n$recNew`n"
Check 'J2 inline entry not equal to last line fails' ((JsonlFailed $r) -and $r.code -eq 2 -and $r.out -match 'not the last line') "code=$($r.code) out=$($r.out)"
$r = Invoke-JsonlVerifier $secOk "$recOld`n{broken`n$recNew`n"
Check 'J3 unparsable line fails' ((JsonlFailed $r) -and $r.code -eq 2 -and $r.out -match 'line\(s\) 2') "code=$($r.code) out=$($r.out)"
$two = "## Harness changelog`r`n### 2026-10-02 -- newest $dash dash`r`n- new body (model -- 2026-10-02)`r`n`r`n### 2026-10-01 -- older`r`n- old body`r`n`r`n$ptr`r`n"
$r = Invoke-JsonlVerifier $two "$recOld`n$recNew`n"
Check 'J4 more than one inline entry fails' ((JsonlFailed $r) -and $r.code -eq 2 -and $r.out -match 'exactly ONE') "code=$($r.code) out=$($r.out)"
$r = Invoke-Verifier 'Quiet.' '' $two
Check 'J5 non-JSONL project is unaffected' ((-not (JsonlFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"

# --- 3.12 Prior-art failures -------------------------------------------------------
function Invoke-SpecVerifier([string]$specText, [string]$ignore = '', [string]$specDir = 'specs') {
    $np = Next-Proj
    [void](New-Item -ItemType Directory -Path (Join-Path $np $specDir) -Force)
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $np $specDir) 'widget-plan.md'), $specText)
    if ($ignore -ne '') { [System.IO.File]::WriteAllText((Join-Path $np '.checkpoint-verify-ignore'), $ignore) }
    return Invoke-Verifier 'Quiet.'
}
function PriorArtFailed($r) { return ($r.out -match 'PRIOR-ART FAILURES') }
$paHead = "# Widget plan`r`nStatus: proposed`r`nCreated: 2026-11-14`r`n`r`n## Problem`r`nNo widget.`r`n"
$paTail = "`r`n## Closeout`r`n- [ ] ARCHIVE`r`n"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget cache library`")`r`n1. widgetlib -- https://example.com/widgetlib -- adopt: maintained, fits`r`nVerdict: adopt`r`n" + $paTail)
Check 'PA-a sourced Prior art passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + $paTail)
Check 'PA-b missing Prior art fails' ((PriorArtFailed $r) -and $r.code -eq 2 -and $r.out -match 'no Prior art section') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget cache library`")`r`nI looked around and this seems new.`r`n" + $paTail)
Check 'PA-c prose-only Prior art fails' ((PriorArtFailed $r) -and $r.code -eq 2 -and $r.out -match 'cites no source') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art`r`nnothing found`r`n" + $paTail)
Check 'PA-d nothing found without searched date fails' ((PriorArtFailed $r) -and $r.code -eq 2 -and $r.out -match 'searched <YYYY-MM-DD>') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: the web)`r`nnothing found`r`n" + $paTail)
Check 'PA-d2 no recorded query fails' ((PriorArtFailed $r) -and $r.code -eq 2 -and $r.out -match 'no quoted query') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art`r`n(searched 2026-11-14: see research/widget-prior-art-2026-11-14.md)`r`nVerdict: adapt`r`n" + $paTail)
Check 'PA-d3 cited sweep file passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ("# Widget plan`r`nStatus: proposed`r`nCreated: 2026-11-12`r`n" + $paTail)
Check 'PA-e1 pre-rollout spec is not checked' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ("# Widget notes`r`nStatus: draft`r`n" + $paTail)
Check 'PA-e2 file with no Created line is not checked' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + $paTail) 'prior-art: advisory'
Check 'PA-f prior-art: advisory opt-out exits 0' ((-not (PriorArtFailed $r)) -and $r.code -eq 0 -and $r.out -match 'PRIOR-ART FAILURE \(advisory') "code=$($r.code) out=$($r.out)"
$paGood = "## Prior art (searched 2026-11-14: `"widget cache library`")`r`n1. widgetlib -- https://example.com/widgetlib -- adopt`r`n"
$f3 = '```' + "`r`n"; $f4 = '````' + "`r`n"
$r = Invoke-SpecVerifier ($paHead + $f3 + $paGood + $f3 + $paTail)
Check 'PA-g fenced Prior art section does not count' ((PriorArtFailed $r) -and $r.code -eq 2 -and $r.out -match 'no Prior art section') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + $f4 + $f3 + $f3 + $paGood + $f4 + $paTail)
Check 'PA-h nested fence keeps the example section out' ((PriorArtFailed $r) -and $r.out -match 'no Prior art section') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + $f4 + $f3 + "example`r`n" + $f3 + $f4 + $paGood + $paTail)
Check 'PA-h2 real section after a nested fence counts' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget.md`")`r`nNo research performed.`r`n" + $paTail)
Check 'PA-i filename inside a query is not a source' ((PriorArtFailed $r) -and $r.out -match 'cites no source') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"R`")`r`n1. R -- https://www.r-project.org/ -- adopt`r`n" + $paTail)
Check 'PA-j one-character query passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ("# Widget notes`r`n" + $f3 + "Status: proposed`r`nCreated: 2026-11-14`r`n" + $f3 + "Just notes.`r`n")
Check 'PA-k fenced metadata is not a spec' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$plan = (1..12 | ForEach-Object { "$_. step $_`r`n" }) -join ''
$r = Invoke-SpecVerifier ("# Widget plan`r`nStatus: proposed`r`n## Build plan`r`n" + $plan + "Created: 2026-11-14`r`n" + $paTail)
Check 'PA-l late Created line is still checked' ((PriorArtFailed $r) -and $r.code -eq 2) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget build`")`r`n1. sibling build -- sibling/Dockerfile:42 -- adapt`r`n" + $paTail)
Check 'PA-m extensionless file:line passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget`")`r`nPriority:1`r`nNo research performed.`r`n" + $paTail)
Check 'PA-o label like Priority:1 is not a source' ((PriorArtFailed $r) -and $r.out -match 'cites no source') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art (searched 2026-11-14: `"widget`")`r`n1. Library -- `"https://example.com/library`" -- adopt`r`n" + $paTail)
Check 'PA-p quoted URL in a finding passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$ind = '    '
$r = Invoke-SpecVerifier ($paHead + $ind + $f3 + $ind + "## Prior art (searched 2026-11-14: `"widget`")`r`n" + $ind + "1. a -- https://example.com -- adopt`r`n" + $ind + $f3 + $paTail)
Check 'PA-q indented fenced example does not count' ((PriorArtFailed $r) -and $r.out -match 'no Prior art section') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art`r`nsearched 2026-11-14:`r`n`"widget.md`"`r`nNo research performed.`r`n" + $paTail)
Check 'PA-r wrapped query naming a file is not a source' ((PriorArtFailed $r) -and $r.out -match 'cites no source') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art`r`nsearched 2026-11-14:`r`n- `"widget.md`"`r`nNo research performed.`r`n" + $paTail)
Check 'PA-s bulleted wrapped query is not a source' ((PriorArtFailed $r) -and $r.out -match 'cites no source') "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + "## Prior art`r`nsearched 2026-11-14: `"widget`"`r`nResult: `"https://example.com`"`r`n" + $paTail)
Check 'PA-t quoted source after the record passes' ((-not (PriorArtFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-SpecVerifier ($paHead + $paTail) '' 'outbound'
Check 'PA-u outbound spec is checked too' ((PriorArtFailed $r) -and $r.code -eq 2) "code=$($r.code) out=$($r.out)"

# --- 3.8 Recommendation failures ---------------------------------------------------
# A research/ file newer than the stamp carrying "model recommendation -- <date>" needs an
# [owner] thread or a tracker note (HARNESS_TRACKER_DIR, project: <folder name>) naming it.
$oldStamp = 'Last updated: 2020-01-01 00:00 UTC (v1)'
function Invoke-RecoVerifier([string]$threadLine = '', [string]$trackerProject = '', [string]$ignore = '', [string]$researchText = "# Cache study`r`nUse a disk cache (model recommendation -- 2026-11-14).`r`n") {
    $np = Next-Proj
    [void](New-Item -ItemType Directory -Path (Join-Path $np 'research') -Force)
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $np 'research') 'cache-study.md'), $researchText)
    if ($ignore -ne '') { [System.IO.File]::WriteAllText((Join-Path $np '.checkpoint-verify-ignore'), $ignore) }
    if ($trackerProject -ne '') {
        $td = Join-Path $script:root ("tracker$($script:n + 1)")
        [void](New-Item -ItemType Directory -Path $td -Force)
        $pv = if ($trackerProject -eq 'SLUG') { Split-Path -Leaf $np } else { $trackerProject }
        [System.IO.File]::WriteAllText((Join-Path $td 'row1.md'), "---`r`nproject: $pv`r`n---`r`nDecide on cache-study.md`r`n")
        $env:HARNESS_TRACKER_DIR = $td
    }
    $extra = if ($threadLine -ne '') { "$threadLine`r`n" } else { '' }
    try { return Invoke-Verifier 'Quiet.' '' $extra $oldStamp } finally { Remove-Item Env:HARNESS_TRACKER_DIR -ErrorAction SilentlyContinue }
}
function RecoFailed($r) { return ($r.out -match 'RECOMMENDATION FAILURES') }
$r = Invoke-RecoVerifier
Check 'R1 filed recommendation with no disposition fails' ((RecoFailed $r) -and $r.code -eq 2 -and $r.out -match 'cache-study\.md') "code=$($r.code) out=$($r.out)"
$r = Invoke-RecoVerifier '- Decide on the cache: research/cache-study.md [owner] [low]'
Check 'R2 owner thread naming the file is clean' ((-not (RecoFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-RecoVerifier '' 'SLUG'
Check 'R3 tracker note of this project is clean' ((-not (RecoFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-RecoVerifier '' 'some-other-project'
Check 'R4 tracker note of another project does not count' ((RecoFailed $r) -and $r.code -eq 2) "code=$($r.code) out=$($r.out)"
$r = Invoke-RecoVerifier '' '' 'recommendations: advisory'
Check 'R5 recommendations: advisory opt-out exits 0' ((-not (RecoFailed $r)) -and $r.code -eq 0 -and $r.out -match 'RECOMMENDATION FAILURE \(advisory') "code=$($r.code) out=$($r.out)"
$r = Invoke-RecoVerifier '' '' '' "# Cache study`r`nWe discussed what a model recommendation looks like.`r`n"
Check 'R6 undated mention is not a recommendation' ((-not (RecoFailed $r)) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"

# --- 3.6c Attribution source prompts -----------------------------------------------
function Invoke-AttrVerifier([string]$status, [string]$baselineStatus, [string]$ownerTag = '') {
    $bf = Join-Path $script:root ("baseline$($script:n + 1).md")
    [System.IO.File]::WriteAllText($bf, "# fixture`r`nLast updated: $script:stamp UTC (v1)`r`n`r`n## Status`r`n$baselineStatus`r`n")
    $env:HARNESS_VERIFY_BASELINE = $bf
    if ($ownerTag -ne '') { $env:HARNESS_OWNER_TAG = $ownerTag }
    try { return Invoke-Verifier $status } finally {
        Remove-Item Env:HARNESS_VERIFY_BASELINE -ErrorAction SilentlyContinue
        Remove-Item Env:HARNESS_OWNER_TAG -ErrorAction SilentlyContinue
    }
}
function SourcePrompted($r) { return ($r.out -match 'ATTRIBUTION SOURCE PROMPTS') }
$r = Invoke-AttrVerifier "Old line.`r`nThe owner decision -- 2026-11-05: drop the cache." 'Old line.'
Check 'A1 new unsourced owner credit prompts' ((SourcePrompted $r) -and $r.code -eq 0 -and $r.out -match 'drop the cache') "code=$($r.code) out=$($r.out)"
$r = Invoke-AttrVerifier 'The owner decision -- 2026-11-05: "drop the cache" (board pick).' 'Old line.'
Check 'A2 quoted credit is clean' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier 'The user asked for a daily run (evidence unavailable).' 'Old line.'
Check 'A3 evidence unavailable is clean' (-not (SourcePrompted $r)) "out=$($r.out)"
$old = 'The owner decision -- 2026-10-01: keep the old layout.'
$r = Invoke-AttrVerifier $old $old
Check 'A4 unchanged credit is not prompted' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier "Pick the card design. [owner] [low]`r`nCache moved to TEMP (model analysis -- 2026-11-05)." 'Old line.'
Check 'A5 owner tag / model line not prompted' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier 'The audit, which the owner chose to skip (the owner, 2026-10-16).' 'Old line.'
Check 'A6 paraphrased owner credit prompts' (SourcePrompted $r) "out=$($r.out)"
$r = Invoke-AttrVerifier 'Row 85 ON HOLD until 2026-12-29 (the owner: "You''re right, I technically can''t apply for that").' 'Old line.'
Check 'A7 hold without the owner action word prompts' ((SourcePrompted $r) -and $r.out -match 'action word') "out=$($r.out)"
$r = Invoke-AttrVerifier 'Row 85 ON HOLD (the owner: "hold it until December").' 'Old line.'
Check 'A8 hold with the owner action word is clean' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier "- The owner decision -- 2026-11-05:`r`n  `"hold it until December`" (grill Q3)." 'Old line.'
Check 'A9 wrapped quote is read with its bullet' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier "- The cache stays in TEMP per the owner`r`n  decision -- 2026-11-05." 'Old line.'
Check 'A10 credit split across lines prompts' (SourcePrompted $r) "out=$($r.out)"
$r = Invoke-AttrVerifier 'The owner approved the "compact" layout.' 'Old line.'
Check 'A11 unrelated quote is not the owner source' (SourcePrompted $r) "out=$($r.out)"
$r = Invoke-AttrVerifier 'The owner: "ship it"; the old worker remains paused.' 'Old line.'
Check 'A12 unattributed pause clause is not a hold credit' (-not (SourcePrompted $r)) "out=$($r.out)"
$r = Invoke-AttrVerifier 'Sam decision -- 2026-11-05: drop the cache.' 'Old line.' 'Sam'
Check 'A13 HARNESS_OWNER_TAG name counts as the owner' (SourcePrompted $r) "out=$($r.out)"
$r = Invoke-AttrVerifier 'Sam decision -- 2026-11-05: drop the cache.' 'Old line.'
Check 'A14 the name is not the owner without HARNESS_OWNER_TAG' (-not (SourcePrompted $r)) "out=$($r.out)"

# --- 3.7b DEFECT ON OWNER (prompt only) --------------------------------------------
function DefectPrompted($r) { return ($r.out -match 'DEFECT ON OWNER') }
$scan = '- **toolbox pushed but not certified.** Certify refuses because its commit ID contains "a1b2c", on the privacy scanner''s blocked list (a false match on a random ID). Pick one: (A, recommended) have the scanner skip commit lines in its history grep; or (B) re-make that commit and force-push the public repo.'
$r = Invoke-Verifier 'ok' '' "$scan [owner] [low]`r`n"
Check 'D1 defect on owner prompts' (DefectPrompted $r) "out=$($r.out)"
Check 'D1b prompt only, exit 0' ($r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "$scan [agent] [low]`r`n"
Check 'D2 same bullet on agent is clean' (-not (DefectPrompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- The hook fails on PowerShell 5.1; record the call in the browser log and check the private account list. [owner] [low]`r`n"
Check 'D3 incidental words do not suppress' (DefectPrompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- Backup fix built; the task scheduler refused because the install needs your approval at the admin prompt. [owner] [low]`r`n"
Check 'D4 owner approval step exempts' (-not (DefectPrompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- Decide which broken project to prioritise first (your preference). [owner] [low]`r`n"
Check 'D5 owner preference exempts' (-not (DefectPrompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- Sign in to the search API dashboard and copy the API key. [owner] [low]`r`n"
Check 'D6 no defect is clean' (-not (DefectPrompted $r)) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- Bug in the sorter hook. Your pick: (a) patch it or (b) rewrite it. [owner] [low]`r`n"
Check 'D7 your pick does not exempt' (DefectPrompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- The scanner refused on a false match; you said earlier this week that the account page looked fine. [owner] [low]`r`n"
Check 'D8 distant owner word does not exempt' (DefectPrompted $r) "out=$($r.out)"
$r = Invoke-Verifier 'ok' '' "- Blocked: the auto-mode check refused the funnel command, so the tunnel step waits. [owner] [low]`r`n"
Check 'D9 permission-check refusal exempts' (-not (DefectPrompted $r)) "out=$($r.out)"

# --- 3.6b Notes-decision prompts (HARNESS_NOTES_ROOT) ------------------------------
function Invoke-NotesVerifier([string]$noteText, [bool]$setRoot = $true) {
    $nr = Join-Path $script:root ("notes$($script:n + 1)")
    [void](New-Item -ItemType Directory -Path (Join-Path $nr 'Projects') -Force)
    [System.IO.File]::WriteAllText((Join-Path $nr 'Projects\cache.md'), $noteText)
    if ($setRoot) { $env:HARNESS_NOTES_ROOT = $nr }
    try { return Invoke-Verifier 'See `Projects/cache.md` for the cache plan.' } finally { Remove-Item Env:HARNESS_NOTES_ROOT -ErrorAction SilentlyContinue }
}
function NotePrompted($r) { return ($r.out -match 'NOTE DECISION UNTAGGED') }
$r = Invoke-NotesVerifier "# Cache`r`n## Decision update`r`nUse the disk cache.`r`n"
Check 'N1 untagged decision heading in a pointed-at note prompts' ((NotePrompted $r) -and $r.code -eq 0) "code=$($r.code) out=$($r.out)"
$r = Invoke-NotesVerifier "# Cache`r`n## Decision update`r`nOwner decision -- 2026-11-05: use the disk cache.`r`n"
Check 'N2 owner-tagged decision is clean' (-not (NotePrompted $r)) "out=$($r.out)"
$r = Invoke-NotesVerifier "# Cache`r`n## Decision (model draft)`r`nUse the disk cache.`r`n"
Check 'N3 openly model decision is clean' (-not (NotePrompted $r)) "out=$($r.out)"
$r = Invoke-NotesVerifier "# Cache`r`n## Decision update`r`nUse the disk cache.`r`n" $false
Check 'N4 no notes root, no check' (-not (NotePrompted $r)) "out=$($r.out)"

Write-Output "---- $pass passed, $fail failed ----"
if ($fail -gt 0) { exit 1 } else { exit 0 }
