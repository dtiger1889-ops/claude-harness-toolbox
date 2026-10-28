# Tests for the Codex hook set in this folder (orient_gate.ps1, orient_session.ps1, guard.ps1, hooks.json).
# Events use the real Codex PreToolUse / SessionStart shape (fields from the schemas in the
# openai/codex repo, codex-rs/hooks/schema/generated): session_id, transcript_path, cwd,
# hook_event_name, model, permission_mode, turn_id, tool_name, tool_use_id, tool_input.command.
# A shell command is tool_name "Bash" on Codex, including PowerShell commands.
#
# Run (Windows PowerShell 5.1 or PowerShell 7):
#   powershell.exe -NoProfile -File hooks/codex/orient_gate_tests.ps1
# Optional: -HooksDir <folder holding the scripts and hooks.json> -SharedGuard <path to hooks/guard.ps1>
param(
    [string]$HooksDir = $PSScriptRoot,
    [string]$SharedGuard = (Join-Path $PSScriptRoot '..\guard.ps1')
)

$ErrorActionPreference = 'Continue'
$gate = Join-Path $HooksDir 'orient_gate.ps1'
$session = Join-Path $HooksDir 'orient_session.ps1'
$guardCopy = Join-Path $HooksDir 'guard.ps1'
$hooksJson = Join-Path $HooksDir 'hooks.json'
$tempRoot = [System.IO.Path]::GetTempPath()
$base = Join-Path $tempRoot ('codex_gate_tests_' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $base 'proj'
$otherRoot = Join-Path $base 'other_root'
$bare = Join-Path $base 'bare'
New-Item -ItemType Directory -Force -Path $fixture, $otherRoot, $bare | Out-Null
foreach ($d in @($fixture, $otherRoot)) {
    Set-Content -LiteralPath (Join-Path $d 'CLAUDE.md') -Value '# test claude'
    Set-Content -LiteralPath (Join-Path $d 'CHECKPOINT.md') -Value '# test checkpoint'
}

$script:pass = 0
$script:fail = 0
$script:sessions = @()

function New-Sid { $s = 'tst' + [guid]::NewGuid().ToString('N'); $script:sessions += $s; return $s }

function New-Event {
    param([string]$Sid, [string]$Cwd, [string]$Command, [string]$Hook = 'PreToolUse', [string]$Source = 'startup')
    $e = [ordered]@{
        session_id      = $Sid
        transcript_path = $null
        cwd             = $Cwd
        hook_event_name = $Hook
        model           = 'gpt-test'
        permission_mode = 'default'
        turn_id         = 'turn-1'
    }
    if ($Hook -eq 'SessionStart') { $e['source'] = $Source }
    else {
        $e['tool_name'] = 'Bash'
        $e['tool_use_id'] = 'call-1'
        $e['tool_input'] = [ordered]@{ command = $Command }
    }
    return ($e | ConvertTo-Json -Depth 5 -Compress)
}

# Runs a script the way Codex does (windows PowerShell, -File), JSON on stdin. Returns exit code and merged text.
function Invoke-Script {
    param([string]$Script, [string]$Stdin)
    $out = $Stdin | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script 2>&1 | Out-String
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = $out }
}

function Flag-Path { param([string]$Sid, [string]$Kind) Join-Path $tempRoot ("codex_orient_{0}.{1}.flag" -f $Sid, $Kind) }

function Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { $script:pass++; Write-Output "PASS $Name" }
    else { $script:fail++; Write-Output "FAIL $Name $Detail" }
}

$env:HARNESS_WORKSPACE_ROOT = $otherRoot
$npm = 'npm test'
$readClaude = "Get-Content -LiteralPath '" + (Join-Path $fixture 'CLAUDE.md') + "' -Raw"
$readCheckpoint = "Get-Content '" + (Join-Path $fixture 'CHECKPOINT.md') + "'"

# a: no reads yet, a normal command is blocked.
$sid = New-Sid
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'a: npm test with no reads exits 2' ($r.Exit -eq 2) ("exit=" + $r.Exit)

# b: reading CHECKPOINT.md is allowed and recorded.
$sid = New-Sid
$r = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
Check 'b: Get-Content CHECKPOINT.md exits 0 and writes the checkpoint flag' (($r.Exit -eq 0) -and (Test-Path (Flag-Path $sid 'checkpoint'))) ("exit=" + $r.Exit)

# c: both reads, then a normal command passes.
$sid = New-Sid
$null = Invoke-Script $gate (New-Event $sid $fixture $readClaude)
$null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'c: both reads then npm test exits 0' ($r.Exit -eq 0) ("exit=" + $r.Exit)

# d: only the CHECKPOINT read, then a normal command is still blocked.
$sid = New-Sid
$null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'd: only CHECKPOINT read then npm test exits 2' ($r.Exit -eq 2) ("exit=" + $r.Exit)

# e: a read of a file with the same name elsewhere sets no flag.
$sid = New-Sid
$null = Invoke-Script $gate (New-Event $sid $fixture 'Select-String -Path missing/CLAUDE.md -Pattern x')
$null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'e: Select-String on missing/CLAUDE.md sets no flag, npm test stays exit 2' (($r.Exit -eq 2) -and -not (Test-Path (Flag-Path $sid 'claude'))) ("exit=" + $r.Exit)

# f: input that is not JSON fails open.
$r = Invoke-Script $gate 'this is not json'
Check 'f: non-JSON input exits 0 (fail open)' ($r.Exit -eq 0) ("exit=" + $r.Exit)

# g: no CLAUDE.md or CHECKPOINT.md above cwd and the root variable unset: nothing to enforce.
$saved = $env:HARNESS_WORKSPACE_ROOT
Remove-Item Env:\HARNESS_WORKSPACE_ROOT -ErrorAction SilentlyContinue
$sid = New-Sid
$r = Invoke-Script $gate (New-Event $sid $bare $npm)
$env:HARNESS_WORKSPACE_ROOT = $saved
Check 'g: no files above cwd and variable unset exits 0' ($r.Exit -eq 0) ("exit=" + $r.Exit)

# h: a clear SessionStart wipes the flags.
$sid = New-Sid
$null = Invoke-Script $gate (New-Event $sid $fixture $readClaude)
$null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
$null = Invoke-Script $session (New-Event $sid $fixture '' 'SessionStart' 'clear')
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'h: reads, then SessionStart clear, then npm test exits 2' ($r.Exit -eq 2) ("exit=" + $r.Exit)

# i: guard copy is byte-identical to the shared guard, and every script path in hooks.json resolves.
$same = $false
if ((Test-Path $guardCopy) -and (Test-Path $SharedGuard)) {
    $same = ((Get-FileHash $guardCopy -Algorithm SHA256).Hash -eq (Get-FileHash $SharedGuard -Algorithm SHA256).Hash)
}
$allResolve = $false
$leftover = $true
if (Test-Path $hooksJson) {
    $dirFwd = (Resolve-Path -LiteralPath $HooksDir).Path -replace '\\', '/'
    $text = (Get-Content -LiteralPath $hooksJson -Raw).Replace('<HOOKS_DIR>', $dirFwd)
    $leftover = $text -match '<HOOKS_DIR>'
    $paths = [regex]::Matches($text, '-File\s+\\"([^"\\]+)\\"') | ForEach-Object { $_.Groups[1].Value }
    $allResolve = (@($paths).Count -ge 3) -and (@($paths | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -eq 0)
}
Check 'i: guard copy identical to hooks/guard.ps1, hooks.json script paths resolve, no leftover placeholder' ($same -and $allResolve -and -not $leftover) ("same=$same resolve=$allResolve leftover=$leftover")

# j: the guard command that hooks.json registers for Write|Edit|Bash|PowerShell blocks a backslash drive path.
$j = $false
$jText = ''
if (Test-Path $hooksJson) {
    $dirFwd = (Resolve-Path -LiteralPath $HooksDir).Path -replace '\\', '/'
    $cfg = (Get-Content -LiteralPath $hooksJson -Raw).Replace('<HOOKS_DIR>', $dirFwd) | ConvertFrom-Json
    $entry = $cfg.hooks.PreToolUse | Where-Object { $_.matcher -eq 'Write|Edit|Bash|PowerShell' } | Select-Object -First 1
    if ($entry) {
        $cmd = [string]$entry.hooks[0].command
        $sb = [scriptblock]::Create('$input | ' + $cmd)
        $out = (New-Event (New-Sid) $fixture 'ls D:\Projects') | & $sb 2>&1 | Out-String
        $jText = $out
        $j = ($LASTEXITCODE -eq 2) -and ($out -match 'BLOCKED by guard hook')
    }
}
Check 'j: registered guard command blocks an unquoted backslash drive path with exit 2' $j ($jText.Trim())

# cleanup
foreach ($s in $script:sessions) {
    foreach ($k in 'claude', 'checkpoint') { Remove-Item -LiteralPath (Flag-Path $s $k) -Force -ErrorAction SilentlyContinue }
}
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item Env:\HARNESS_WORKSPACE_ROOT -ErrorAction SilentlyContinue

$total = $script:pass + $script:fail
Write-Output ("{0}/{1} passed" -f $script:pass, $total)
if ($script:fail -gt 0) { exit 1 }
exit 0
