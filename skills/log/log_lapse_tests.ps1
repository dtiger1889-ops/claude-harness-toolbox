# Tests for log_lapse.ps1 (append, repeat detection, PROMOTE message, nearest-CHECKPOINT lookup).
# Run: powershell.exe -NoProfile -File <this folder>/log_lapse_tests.ps1 (uses throwaway ledgers under TEMP).

$script = Join-Path $PSScriptRoot 'log_lapse.ps1'
$tmpDir = Join-Path $env:TEMP ('claude_log_lapse_tests_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir | Out-Null }

function ConvertTo-ArgString([string]$a) {
    if ($a -ne '' -and $a -notmatch '[\s"]') { return $a }
    return '"' + ([regex]::Replace($a, '(\\*)("|$)', { param($m) $m.Groups[1].Value + $m.Groups[1].Value + $(if ($m.Groups[2].Value) { '\"' } else { '' }) })) + '"'
}

function Invoke-LogLapse {
    param([hashtable]$Params)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'pwsh'
    $argv = New-Object System.Collections.Generic.List[string]
    foreach ($a in '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) { $argv.Add($a) }
    foreach ($k in $Params.Keys) {
        $v = $Params[$k]
        if ($v -is [array]) {
            $argv.Add("-$k")
            foreach ($item in $v) { $argv.Add([string]$item) }
        } elseif ($v -is [bool]) {
            if ($v) { $argv.Add("-$k") }
        } else {
            $argv.Add("-$k")
            $argv.Add([string]$v)
        }
    }
    $psi.Arguments = (@($argv | ForEach-Object { ConvertTo-ArgString $_ })) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ code = $p.ExitCode; out = $out; err = $err }
}

$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
    if ($ok) { $script:pass++; Write-Output "PASS  $name" } else { $script:fail++; Write-Output "FAIL  $name  $detail" }
}

function New-TempLedger([string]$label, [string]$dir = $tmpDir) {
    $path = Join-Path $dir "lltest-$label-$([guid]::NewGuid().ToString('N').Substring(0,8)).jsonl"
    $seed1 = @{ n = 1; date = '2026-08-01'; utc = '2026-08-01 00:00 UTC'; model = 'seed'; effort = 'seed'; provenance = 'seed'; session = 'seed session'; rule = 'Never restart the agent or close its windows without the user explicit approval for interruption'; consequence = 'seed'; how_caught = 'seed'; fix_status = 'seed' } | ConvertTo-Json -Compress
    $seed2 = @{ n = 2; date = '2026-08-05'; utc = '2026-08-05 00:00 UTC'; model = 'seed'; effort = 'seed'; provenance = 'seed'; session = 'seed session'; rule = 'Interview before you build a session that kicks off new work runs the interview skill first'; consequence = 'seed'; how_caught = 'seed'; fix_status = 'seed' } | ConvertTo-Json -Compress
    Set-Content -Path $path -Value @($seed1, $seed2) -Encoding utf8
    return $path
}

# --- Test 1: -RepeatOf prints PROMOTE and stores repeat_of, appends exactly one row
$ledger1 = New-TempLedger '1'
$r = Invoke-LogLapse @{
    LogFile = $ledger1; RepeatOf = @(1); Session = 'test session'
    Rule = 'Third instance: closed another active agent window without asking the user first.'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
$lines1 = Get-Content $ledger1
Check '1a exit 0' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
Check '1b stdout has appended-n line' ($r.out -match 'appended lapse n=3') "out=$($r.out)"
Check '1c stdout has PROMOTE with n=1,3' ($r.out -match 'PROMOTE: this rule now has 2 rows \(n=1,3\)') "out=$($r.out)"
Check '1d PROMOTE names Fix candidates, the open-item line and the edit-one-line step' ($r.out -match 'Fix candidates' -and $r.out -match 'open-item line' -and $r.out -match 'Do not read that file whole') "out=$($r.out)"
Check '1e exactly 3 lines in ledger' ($lines1.Count -eq 3) "count=$($lines1.Count)"
$rec3 = $lines1[2] | ConvertFrom-Json
Check '1f new record has repeat_of = [1]' (($rec3.repeat_of -join ',') -eq '1') "repeat_of=$($rec3.repeat_of -join ',')"

# --- Test 2: near-duplicate rule, no flags -> exits 3, appends nothing
$ledger2 = New-TempLedger '2'
$beforeLines2 = (Get-Content $ledger2).Count
$r = Invoke-LogLapse @{
    LogFile = $ledger2; Session = 'test session'
    Rule = 'Never restart the agent or close its windows without the user explicit approval for interruption again everyone'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
$afterLines2 = (Get-Content $ledger2).Count
Check '2a exit 3' ($r.code -eq 3) "code=$($r.code) out=$($r.out) err=$($r.err)"
Check '2b stdout has POSSIBLE REPEAT of n=1' ($r.out -match 'POSSIBLE REPEAT of n=1') "out=$($r.out)"
Check '2c stdout names -RepeatOf and -NotRepeat as next moves' ($r.out -match '-RepeatOf 1' -and $r.out -match '-NotRepeat') "out=$($r.out)"
Check '2d no row appended' ($afterLines2 -eq $beforeLines2) "before=$beforeLines2 after=$afterLines2"

# --- Test 3: same near-duplicate rule with -NotRepeat -> appends normally, no repeat_of, no PROMOTE
$ledger3 = New-TempLedger '3'
$r = Invoke-LogLapse @{
    LogFile = $ledger3; NotRepeat = $true; Session = 'test session'
    Rule = 'Never restart the agent or close its windows without the user explicit approval for interruption again everyone'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
$lines3 = Get-Content $ledger3
Check '3a exit 0' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
Check '3b appended (3 lines total)' ($lines3.Count -eq 3) "count=$($lines3.Count)"
Check '3c no PROMOTE in stdout' ($r.out -notmatch 'PROMOTE') "out=$($r.out)"
$rec3c = $lines3[2] | ConvertFrom-Json
Check '3d new record has no repeat_of field' (-not ($rec3c.PSObject.Properties.Name -contains 'repeat_of')) "props=$($rec3c.PSObject.Properties.Name -join ',')"

# --- Test 4: unrelated rule, no flags -> appends normally, no hint
$ledger4 = New-TempLedger '4'
$r = Invoke-LogLapse @{
    LogFile = $ledger4; Session = 'test session'
    Rule = 'Backup the monthly cold archive copy to the off site drive before the retention window closes.'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
$lines4 = Get-Content $ledger4
Check '4a exit 0' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
Check '4b appended (3 lines total)' ($lines4.Count -eq 3) "count=$($lines4.Count)"
Check '4c no hint in stdout' ($r.out -notmatch 'POSSIBLE REPEAT' -and $r.out -notmatch 'PROMOTE') "out=$($r.out)"

# --- Test 5: -RepeatOf with a nonexistent n throws (nonzero exit, no append)
$ledger5 = New-TempLedger '5'
$beforeLines5 = (Get-Content $ledger5).Count
$r = Invoke-LogLapse @{
    LogFile = $ledger5; RepeatOf = @(999); Session = 'test session'
    Rule = 'Some rule that repeats a row that does not exist.'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
$afterLines5 = (Get-Content $ledger5).Count
Check '5a nonzero exit' ($r.code -ne 0) "code=$($r.code)"
Check '5b error names the bad RepeatOf value' ($r.err -match '999' -and $r.err -match 'RepeatOf') "err=$($r.err)"
Check '5c no row appended' ($afterLines5 -eq $beforeLines5) "before=$beforeLines5 after=$afterLines5"

# --- Test 6: PROMOTE names the nearest CHECKPOINT.md at or above the ledger folder
$proj = Join-Path $tmpDir 'proj'
$ledgerDir = Join-Path $proj 'ledgers'
New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
Set-Content -Path (Join-Path $proj 'CHECKPOINT.md') -Value '# state' -Encoding utf8
$ledger6 = New-TempLedger '6' $ledgerDir
$r = Invoke-LogLapse @{
    LogFile = $ledger6; RepeatOf = @(2); Session = 'test session'
    Rule = 'Skipped the interview again.'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
Check '6a exit 0' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
Check '6b PROMOTE names the project CHECKPOINT one level up' ($r.out -match [regex]::Escape((Join-Path $proj 'CHECKPOINT.md'))) "out=$($r.out)"
# same-folder ledger also resolves
$ledger6b = New-TempLedger '6b' $proj
$r = Invoke-LogLapse @{
    LogFile = $ledger6b; RepeatOf = @(2); Session = 'test session'
    Rule = 'Skipped the interview a third time.'
    Consequence = 'test'; HowCaught = 'test'; FixStatus = 'test'; Model = 'test-model'
}
Check '6c PROMOTE names the CHECKPOINT beside a project-root ledger' ($r.out -match [regex]::Escape((Join-Path $proj 'CHECKPOINT.md'))) "out=$($r.out)"

Write-Output "---- $pass passed, $fail failed ----"
Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { exit 1 } else { exit 0 }
