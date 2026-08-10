# necromancy.ps1 -- session recovery digest for dead (un-checkpointed) Claude Code sessions.
# Pattern stolen from ryanthedev/herderp (src/necromancy): deterministic regex anchor
# extraction over ~/.claude/projects JSONL, no model calls, everything capped and clipped.
# List mode:   necromancy.ps1 [-Project <path>] [-Max 10]
# Digest mode: necromancy.ps1 [-Project <path>] -Session <uuid-or-prefix|latest>
param(
    [string]$Project = (Get-Location).Path,
    [string]$Session = "",
    [int]$Max = 10
)

$ErrorActionPreference = "Stop"
$store = Join-Path $env:USERPROFILE ".claude\projects"
$slug = ($Project -replace '[^A-Za-z0-9]', '-')
$dir = Join-Path $store $slug
if (-not (Test-Path $dir)) {
    # case-insensitive fallback (a lowercase slug variant exists for some projects)
    $hit = Get-ChildItem $store -Directory | Where-Object { $_.Name -ieq $slug } | Select-Object -First 1
    if ($hit) { $dir = $hit.FullName } else { Write-Output "NO SESSION STORE for slug '$slug' under $store"; exit 1 }
}

$files = Get-ChildItem $dir -Filter *.jsonl -File | Where-Object { $_.Length -gt 0 } | Sort-Object LastWriteTime -Descending
if (-not $files) { Write-Output "NO SESSIONS in $dir"; exit 1 }

function Clip([string]$s, [int]$n) {
    $s = ($s -replace '\s+', ' ').Trim()
    if ($s.Length -gt $n) { return $s.Substring(0, $n) + "..." } else { return $s }
}

# Bounded dedup collector: additions beyond the cap are dropped silently (precision over recall).
function Add-Anchor($list, [hashtable]$seen, [string]$val, [int]$cap, [int]$clip) {
    if (-not $val) { return }
    $c = Clip $val $clip
    $k = $c.ToLower()
    if ($seen.ContainsKey($k) -or $list.Count -ge $cap) { return }
    $seen[$k] = $true
    [void]$list.Add($c)
}

if (-not $Session) {
    # ---------- LIST MODE: raw-text regex scan only, no JSON parsing ----------
    Write-Output "SESSIONS for $Project (newest first, top $Max of $($files.Count)):"
    Write-Output "note: the newest file is usually the CURRENT live session, not a dead one."
    $files | Select-Object -First $Max | ForEach-Object {
        $raw = [System.IO.File]::ReadAllText($_.FullName)
        $title = ""
        $tm = [regex]::Matches($raw, '"type":"custom-title","customTitle":"((?:[^"\\]|\\.)*)"')
        if ($tm.Count -gt 0) { $title = $tm[$tm.Count - 1].Groups[1].Value }
        $ask = ""
        $am = [regex]::Match($raw, '"type":"user","message":\{"role":"user","content":"((?:[^"\\]|\\.)*)"')
        if ($am.Success) { $ask = $am.Groups[1].Value -replace '\\n', ' ' -replace '\\"', '"' -replace '\\\\', '\' }
        $ckpt = "NO CHECKPOINT WRITE"
        $cm = [regex]::Matches($raw, '"name":"(?:Edit|Write)"[^\r\n]{0,4000}?CHECKPOINT\.md')
        if ($cm.Count -eq 0) { $cm = [regex]::Matches($raw, 'CHECKPOINT\.md[^\r\n]{0,400}?"name":"(?:Edit|Write)"') }
        if ($cm.Count -gt 0) {
            $lastPos = $cm[$cm.Count - 1].Index
            $tailAsst = [regex]::Matches($raw.Substring($lastPos), '"type":"assistant"').Count
            $ckpt = "checkpoint written; $tailAsst assistant msgs after last write"
        }
        $kb = [math]::Round($_.Length / 1KB)
        Write-Output ("-" * 72)
        Write-Output ("{0}  {1}  {2}KB" -f $_.BaseName, $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), $kb)
        if ($title) { Write-Output ("  title: " + (Clip $title 100)) }
        if ($ask)   { Write-Output ("  ask:   " + (Clip $ask 160)) }
        Write-Output ("  state: " + $ckpt)
    }
    exit 0
}

# ---------- DIGEST MODE ----------
if ($Session -eq "latest") { $target = $files[0] }
else {
    $target = $files | Where-Object { $_.BaseName -like "$Session*" } | Select-Object -First 1
    if (-not $target) { Write-Output "NO SESSION matching '$Session' in $dir"; exit 1 }
}

$caps = @{ user = 25; files = 30; cmds = 20; git = 12; err = 12; test = 8; pr = 8; ver = 8 }
$firstAsk = ""; $firstTs = ""; $lastTs = ""; $lastCkptTs = ""; $asstAfterCkpt = 0
$lastAsst = New-Object System.Collections.ArrayList
$userMsgs = New-Object System.Collections.ArrayList; $userSeen = @{}
$filesW = New-Object System.Collections.ArrayList;  $filesWSeen = @{}
$filesR = New-Object System.Collections.ArrayList;  $filesRSeen = @{}
$cmds  = New-Object System.Collections.ArrayList;   $cmdSeen = @{}
$git   = New-Object System.Collections.ArrayList;   $gitSeen = @{}
$errs  = New-Object System.Collections.ArrayList;   $errSeen = @{}
$tests = New-Object System.Collections.ArrayList;   $testSeen = @{}
$prs   = New-Object System.Collections.ArrayList;   $prSeen = @{}
$vers  = New-Object System.Collections.ArrayList;   $verSeen = @{}

$reGit  = [regex]'(?i)(\[[\w./-]+ [0-9a-f]{7,10}\]|commit(?:ted)? [0-9a-f]{7,40}|\b(?:feat|fix|chore|docs|refactor|perf|test)(?:\([^)\r\n]{1,40}\))?: [^\r\n"]{5,120})'
$reTest = [regex]'(?i)(\b\d+ (?:passed|failed|passing|failing|pass|fail)\b|Ran \d+ tests?|\d+/\d+ (?:cases|tests) )'
$rePr   = [regex]'(?i)(pull request #?\d+|\bPR #\d+|github\.com/[\w.-]+/[\w.-]+/pull/\d+)'
$reVer  = [regex]'(?i)\bv\d+(?:\.\d+){0,2}\b'
$reErr  = [regex]'(?i)^.{0,40}\b(error|exception|traceback|denied|ENOENT|fatal|failed with|exit code [1-9])\b'

function Scan-Text([string]$t) {
    foreach ($m in $reGit.Matches($t))  { Add-Anchor $git  $gitSeen  $m.Value $caps.git 160 }
    foreach ($m in $reTest.Matches($t)) { Add-Anchor $tests $testSeen $m.Value $caps.test 80 }
    foreach ($m in $rePr.Matches($t))   { Add-Anchor $prs  $prSeen   $m.Value $caps.pr 100 }
    foreach ($m in $reVer.Matches($t))  { Add-Anchor $vers $verSeen  $m.Value $caps.ver 20 }
}

$reader = New-Object System.IO.StreamReader($target.FullName)
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line.Length -gt 2000000) { Scan-Text $line.Substring(0, 200000); continue }
        try { $o = $line | ConvertFrom-Json -AsHashtable } catch { continue }
        if ($null -eq $o -or $o['isSidechain'] -eq $true) { continue }
        $ts = $o['timestamp']
        if ($ts) { if (-not $firstTs) { $firstTs = $ts }; $lastTs = $ts }
        $type = $o['type']
        if ($type -ne 'user' -and $type -ne 'assistant') { continue }
        $msg = $o['message']; if ($null -eq $msg) { continue }
        $content = $msg['content']

        if ($type -eq 'user') {
            if ($content -is [string]) {
                if (-not $firstAsk) { $firstAsk = $content }
                Add-Anchor $userMsgs $userSeen $content $caps.user 220
                Scan-Text $content
            } elseif ($content -is [array]) {
                foreach ($b in $content) {
                    if ($b['type'] -eq 'text') {
                        if (-not $firstAsk) { $firstAsk = $b['text'] }
                        Add-Anchor $userMsgs $userSeen $b['text'] $caps.user 220
                        Scan-Text $b['text']
                    } elseif ($b['type'] -eq 'tool_result') {
                        $rtxt = ""
                        if ($b['content'] -is [string]) { $rtxt = $b['content'] }
                        elseif ($b['content'] -is [array]) {
                            $rtxt = (($b['content'] | Where-Object { $_['type'] -eq 'text' } | ForEach-Object { $_['text'] }) -join " ")
                        }
                        if ($rtxt) {
                            Scan-Text $rtxt
                            foreach ($ln in ($rtxt -split "`n" | Select-Object -First 40)) {
                                if ($reErr.IsMatch($ln)) { Add-Anchor $errs $errSeen $ln $caps.err 200; break }
                            }
                        }
                    }
                }
            }
        } else {
            $isAfterCkptCandidate = $true
            if ($content -is [array]) {
                foreach ($b in $content) {
                    switch ($b['type']) {
                        'text' {
                            [void]$lastAsst.Add($b['text'])
                            if ($lastAsst.Count -gt 3) { $lastAsst.RemoveAt(0) }
                            Scan-Text $b['text']
                        }
                        'tool_use' {
                            $inp = $b['input']
                            if ($inp -is [hashtable]) {
                                $fp = $inp['file_path']; if (-not $fp) { $fp = $inp['notebook_path'] }; if (-not $fp) { $fp = $inp['path'] }
                                if ($fp) {
                                    if ($b['name'] -in @('Edit','Write','NotebookEdit')) {
                                        Add-Anchor $filesW $filesWSeen $fp $caps.files 200
                                        if ($fp -match 'CHECKPOINT\.md$') { $lastCkptTs = $ts; $asstAfterCkpt = 0; $isAfterCkptCandidate = $false }
                                    } else { Add-Anchor $filesR $filesRSeen $fp $caps.files 200 }
                                }
                                if ($inp['command']) { Add-Anchor $cmds $cmdSeen $inp['command'] $caps.cmds 160 }
                            }
                        }
                    }
                }
            }
            if ($lastCkptTs -and $isAfterCkptCandidate) { $asstAfterCkpt++ }
        }
    }
} finally { $reader.Close() }

Write-Output "SESSION DIGEST: $($target.BaseName)"
Write-Output "file: $($target.FullName) ($([math]::Round($target.Length/1KB))KB)"
Write-Output "span: $firstTs -> $lastTs"
if ($lastCkptTs) { Write-Output "checkpoint: last CHECKPOINT.md write at $lastCkptTs; $asstAfterCkpt assistant msgs after it" }
else { Write-Output "checkpoint: NEVER written this session" }
Write-Output ""
Write-Output "== FIRST ASK =="
Write-Output (Clip $firstAsk 400)
Write-Output ""
Write-Output "== USER MESSAGES (the decisions; capped $($caps.user)) =="
$userMsgs | ForEach-Object { Write-Output ("- " + $_) }
Write-Output ""
Write-Output "== FINAL ASSISTANT STATE (last text blocks) =="
$lastAsst | ForEach-Object { Write-Output (Clip $_ 700); Write-Output "" }
if ($filesW.Count) { Write-Output "== FILES WRITTEN =="; $filesW | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($filesR.Count) { Write-Output "== FILES READ (capped) =="; $filesR | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($cmds.Count)  { Write-Output "== COMMANDS RUN (capped) =="; $cmds | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($git.Count)   { Write-Output "== GIT / COMMITS =="; $git | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($prs.Count)   { Write-Output "== PRS =="; $prs | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($vers.Count)  { Write-Output "== VERSIONS SEEN =="; Write-Output ("  " + ($vers -join ", ")); Write-Output "" }
if ($tests.Count) { Write-Output "== TEST RESULTS =="; $tests | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
if ($errs.Count)  { Write-Output "== ERRORS (first line each, capped) =="; $errs | ForEach-Object { Write-Output ("- " + $_) }; Write-Output "" }
