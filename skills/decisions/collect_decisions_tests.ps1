# Tests for collect_decisions.ps1's offered[] (choices this session already put to the user).
# Runs the collector as a child process with -File, the way SKILL.md step 1 does, against fixture
# files in the temp folder and checks the JSON it prints.
# Usage: pwsh -NoProfile -File collect_decisions_tests.ps1   (or powershell -NoProfile -ExecutionPolicy Bypass -File ...)
$collector = Join-Path $PSScriptRoot 'collect_decisions.ps1'
$shell = (Get-Process -Id $PID).Path
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('cdt_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$proj = Join-Path $root 'fixture'
[void](New-Item -ItemType Directory -Path $proj -Force)
[System.IO.File]::WriteAllText((Join-Path $proj 'CHECKPOINT.md'), "# fixture`r`n## Open threads`r`n- Nothing. [agent]`r`n")
# The collector reads the live session id from the environment; the fixture runs start without it.
$liveSid = $env:CLAUDE_CODE_SESSION_ID
Remove-Item Env:CLAUDE_CODE_SESSION_ID -ErrorAction SilentlyContinue

function Invoke-Collector([string[]]$extra) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:shell
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:collector`" -ProjectDir `"$script:proj`" " + ($extra -join ' ')
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd(); [void]$p.StandardError.ReadToEnd(); $p.WaitForExit()
    try { $j = $out | ConvertFrom-Json } catch { $j = $null }
    return @{ code = $p.ExitCode; out = $out; json = $j }
}

$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { $script:pass++; Write-Output "PASS  $name" } else { $script:fail++; Write-Output "FAIL  $name  $detail" }
}

# Fixture transcript: one row per line, the shapes Claude Code writes.
$rows = @(
    '{"type":"user","message":{"role":"user","content":"how should we log the server crash?"},"timestamp":"2026-10-26T06:00:00Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Three ways to record it:\n**Option A -- system event logging.** Needs an admin step.\n**Option B -- a watchdog script.** May lag during freezes.\n**Option C -- do nothing.**\nWhich do you want?"}]},"timestamp":"2026-10-26T06:01:00Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"AskUserQuestion","input":{"questions":[{"question":"How snappy should the jump feel?","options":[{"label":"Floaty","description":"slow arc"},{"label":"Snappy","description":"fast arc"}]}]}}]},"timestamp":"2026-10-26T06:02:00Z"}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Done. The file is saved."}]},"timestamp":"2026-10-26T06:03:00Z"}',
    '{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"text","text":"Option A -- x\nOption B -- y"}]},"timestamp":"2026-10-26T06:04:00Z"}',
    'not json at all'
)
$tr = Join-Path $root 'session.jsonl'
[System.IO.File]::WriteAllText($tr, ($rows -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))

# T1. -Transcript yields exactly the two offers (option list in text + AskUserQuestion), not plain text or sidechain rows
$r = Invoke-Collector @('-Transcript', "`"$tr`"")
$off = @($r.json.offered)
Check 'T1 two offers found' ($r.code -eq 0 -and $off.Count -eq 2) "code=$($r.code) count=$($off.Count) out=$($r.out)"
Check 'T1b text offer carries its options' (@($off | Where-Object { $_.kind -eq 'text' -and $_.text -match 'Option B' }).Count -eq 1) "out=$($r.out)"
Check 'T1c question offer carries question and labels' (@($off | Where-Object { $_.kind -eq 'question' -and $_.text -match 'jump feel' -and $_.text -match 'Snappy' }).Count -eq 1) "out=$($r.out)"
# (checked on the raw text: pwsh 7's ConvertFrom-Json would turn the string back into a DateTime)
Check 'T1d offers carry the transcript timestamp verbatim' ([regex]::Matches($r.out, '"at":\s*"2026-10-26T06:0[12]:00Z"').Count -eq 2) "out=$($r.out)"

# T2. without a transcript or session id, offered is an empty list and nothing else changes
$r = Invoke-Collector @()
Check 'T2 no transcript -> offered empty' ($r.code -eq 0 -and $null -ne $r.json -and @($r.json.offered).Count -eq 0 -and $r.out -match '"offered"') "out=$($r.out)"

# T3. a missing transcript path is a warning, never a crash
$r = Invoke-Collector @('-Transcript', "`"$(Join-Path $root 'nope.jsonl')`"")
Check 'T3 missing transcript warns' ($r.code -eq 0 -and (@($r.json.warnings) -join ' ') -match 'transcript not found') "out=$($r.out)"

# T4-T6: the transcript is found by THIS session's id, never by newest file.
$pd = Join-Path $root 'projects'
$sid = '11111111-2222-3333-4444-555555555555'
$pf = Join-Path $pd 'fixture-folder'
[void](New-Item -ItemType Directory -Path $pf -Force)
Copy-Item -LiteralPath $tr -Destination (Join-Path $pf "$sid.jsonl")
# a NEWER transcript from another session in the same folder, with its own offer
$other = '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Option A -- other\nOption B -- session"}]},"timestamp":"2026-10-27T00:00:00Z"}'
[System.IO.File]::WriteAllText((Join-Path $pf 'zzzz-other.jsonl'), $other + "`n")

# T4. -SessionId picks that session's transcript, not the newest one
$r = Invoke-Collector @('-SessionId', $sid, '-ProjectsDir', "`"$pd`"")
Check 'T4 -SessionId reads its own transcript' (@($r.json.offered).Count -eq 2 -and ($r.out -notmatch 'other')) "out=$($r.out)"

# T5. with no -Transcript or -SessionId, the session id comes from CLAUDE_CODE_SESSION_ID
$env:CLAUDE_CODE_SESSION_ID = $sid
try { $r = Invoke-Collector @('-ProjectsDir', "`"$pd`"") } finally { Remove-Item Env:CLAUDE_CODE_SESSION_ID -ErrorAction SilentlyContinue }
Check 'T5 session id from the environment' (@($r.json.offered).Count -eq 2) "out=$($r.out)"

# T6. -Out writes the same JSON to a file (the validator reads it as <board name>.collected.json)
$of = Join-Path $root 'board.collected.json'
$r = Invoke-Collector @('-Transcript', "`"$tr`"", '-Out', "`"$of`"")
$fileJson = $null; try { $fileJson = [System.IO.File]::ReadAllText($of) | ConvertFrom-Json } catch {}
Check 'T6 -Out writes the collector JSON' ($null -ne $fileJson -and @($fileJson.offered).Count -eq 2) "exists=$(Test-Path $of) out=$($r.out)"

if ($liveSid) { $env:CLAUDE_CODE_SESSION_ID = $liveSid }
Write-Output "---- $pass passed, $fail failed ----"
# Fixtures are left in the temp folder (cdt_*) on purpose: no delete on a computed path.
if ($fail -gt 0) { exit 1 } else { exit 0 }
