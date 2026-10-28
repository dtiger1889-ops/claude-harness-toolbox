# Tests for the Codex hook set in this folder (orient_gate.ps1, orient_session.ps1, hooks.json).
# Events use the real Codex PreToolUse / SessionStart shape (fields from the schemas in the
# openai/codex repo, codex-rs/hooks/schema/generated): session_id, transcript_path, cwd,
# hook_event_name, model, permission_mode, turn_id, tool_name, tool_use_id, tool_input.command.
# A shell command is tool_name "Bash" on Codex, including PowerShell commands.
#
# Run (Windows PowerShell 5.1 or PowerShell 7):
#   powershell.exe -NoProfile -File <this folder>/orient_gate_tests.ps1
# Works from a clone or from the installed copy; it needs nothing outside this folder.
# Optional: -HooksDir <folder holding the scripts and hooks.json>
param(
    [string]$HooksDir = $PSScriptRoot
)

$ErrorActionPreference = 'Continue'
$gate = Join-Path $HooksDir 'orient_gate.ps1'
$session = Join-Path $HooksDir 'orient_session.ps1'
$hooksJson = Join-Path $HooksDir 'hooks.json'
$tempRoot = [System.IO.Path]::GetTempPath()
$base = Join-Path $tempRoot ('codex_gate_tests_' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $base 'proj'
$otherRoot = Join-Path $base 'other_root'
$bare = Join-Path $base 'bare'
$projB = Join-Path $base 'projB'
New-Item -ItemType Directory -Force -Path $fixture, $otherRoot, $bare, $projB | Out-Null
foreach ($d in @($fixture, $otherRoot, $projB)) {
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
    $code = $LASTEXITCODE
    # The gate blocks with a JSON permissionDecision "deny" on stdout and exit 0 (the form Codex
    # enforces). In these checks "exits 2" means blocked: a valid deny counts as 2; a bare exit 2
    # with no deny JSON counts as 99, because Codex does not enforce that form.
    $isDeny = $false
    try { $isDeny = (($out | ConvertFrom-Json).hookSpecificOutput.permissionDecision -eq 'deny') } catch {}
    if ($code -eq 0 -and $isDeny) { $code = 2 }
    elseif ($code -eq 2) { $code = 99 }
    return [pscustomobject]@{ Exit = $code; Text = $out }
}

# Flags are named codex_orient_<session>.<file key>.<kind>.flag; this matches any file key.
function Flag-Path { param([string]$Sid, [string]$Kind) Join-Path $tempRoot ("codex_orient_{0}.*.{1}.flag" -f $Sid, $Kind) }

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

# i: every script path in hooks.json resolves after placeholder substitution, none left over.
$allResolve = $false
$leftover = $true
if (Test-Path $hooksJson) {
    $dirFwd = (Resolve-Path -LiteralPath $HooksDir).Path -replace '\\', '/'
    $text = (Get-Content -LiteralPath $hooksJson -Raw).Replace('<HOOKS_DIR>', $dirFwd)
    $leftover = $text -match '<HOOKS_DIR>'
    $paths = [regex]::Matches($text, '-File\s+\\"([^"\\]+)\\"') | ForEach-Object { $_.Groups[1].Value }
    $allResolve = (@($paths).Count -ge 2) -and (@($paths | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -eq 0)
}
Check 'i: hooks.json script paths resolve, no leftover placeholder' ($allResolve -and -not $leftover) ("resolve=$allResolve leftover=$leftover")

# j: after both reads, every registered PreToolUse command lets a PowerShell command with a
# backslash path through (Codex runs shell commands in PowerShell on Windows; no MSYS false block).
$j = $false
$jText = ''
if (Test-Path $hooksJson) {
    $dirFwd = (Resolve-Path -LiteralPath $HooksDir).Path -replace '\\', '/'
    $cfg = (Get-Content -LiteralPath $hooksJson -Raw).Replace('<HOOKS_DIR>', $dirFwd) | ConvertFrom-Json
    $sid = New-Sid
    $null = Invoke-Script $gate (New-Event $sid $fixture $readClaude)
    $null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
    $codes = @()
    foreach ($entry in @($cfg.hooks.PreToolUse)) {
        foreach ($h in @($entry.hooks)) {
            $sb = [scriptblock]::Create('$input | ' + [string]$h.command)
            $out = (New-Event $sid $fixture 'Get-Content D:\Work\notes.txt') | & $sb 2>&1 | Out-String
            $codes += $LASTEXITCODE
            $jText += $out
        }
    }
    $j = ($codes.Count -ge 1) -and (@($codes | Where-Object { $_ -ne 0 }).Count -eq 0)
}
Check 'j: registered PreToolUse commands allow a backslash-path PowerShell command after both reads' $j ($jText.Trim())

# k: read words inside a string are not a read: no flag is set and npm test stays blocked.
$sid = New-Sid
$r1 = Invoke-Script $gate (New-Event $sid $fixture "Write-Output 'cat CLAUDE.md CHECKPOINT.md'")
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'k: Write-Output naming both files sets no flag (exit 2), then npm test exits 2' (($r1.Exit -eq 2) -and ($r.Exit -eq 2) -and -not (Test-Path (Flag-Path $sid 'claude'))) ("first=" + $r1.Exit + " exit=" + $r.Exit)

# l: a read chained to another command is not let through as a read while CLAUDE.md is still unread.
$sid = New-Sid
$r = Invoke-Script $gate (New-Event $sid $fixture ($readCheckpoint + '; npm test'))
Check 'l: CHECKPOINT read chained to npm test, CLAUDE.md unread, exits 2' ($r.Exit -eq 2) ("exit=" + $r.Exit)

# n: a blocked chained call records nothing: both reads chained to npm test exit 2, and the next npm test still exits 2.
$sid = New-Sid
$r1 = Invoke-Script $gate (New-Event $sid $fixture ($readClaude + '; ' + $readCheckpoint + '; npm test'))
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'n: reads chained to npm test exit 2 and set no flag' (($r1.Exit -eq 2) -and ($r.Exit -eq 2)) ("first=" + $r1.Exit + " exit=" + $r.Exit)

# o: search patterns and redirections are not reads.
$sid = New-Sid
$r1 = Invoke-Script $gate (New-Event $sid $fixture "Select-String -InputObject 'hello' -Pattern 'CLAUDE.md CHECKPOINT.md'")
$r2 = Invoke-Script $gate (New-Event $sid $fixture ($readClaude + ' > copied.txt'))
$r = Invoke-Script $gate (New-Event $sid $fixture $npm)
Check 'o: Select-String pattern and a redirected read are refused, npm test exits 2' (($r1.Exit -eq 2) -and ($r2.Exit -eq 2) -and ($r.Exit -eq 2)) ("sls=" + $r1.Exit + " redirect=" + $r2.Exit + " exit=" + $r.Exit)

# p: a quoted path containing & is one path: both reads in a folder named A&B pass, then npm test passes.
$amp = Join-Path $base 'A&B'
New-Item -ItemType Directory -Force -Path $amp | Out-Null
Set-Content -LiteralPath (Join-Path $amp 'CLAUDE.md') -Value '# a'
Set-Content -LiteralPath (Join-Path $amp 'CHECKPOINT.md') -Value '# b'
$sid = New-Sid
$r1 = Invoke-Script $gate (New-Event $sid $amp ("Get-Content -LiteralPath '" + (Join-Path $amp 'CLAUDE.md') + "' -Raw"))
$r2 = Invoke-Script $gate (New-Event $sid $amp ("Get-Content '" + (Join-Path $amp 'CHECKPOINT.md') + "' | Select-Object -First 50"))
$r = Invoke-Script $gate (New-Event $sid $amp $npm)
Check 'p: quoted A&B paths read (exit 0, 0), then npm test exits 0' (($r1.Exit -eq 0) -and ($r2.Exit -eq 0) -and ($r.Exit -eq 0)) ("r1=" + $r1.Exit + " r2=" + $r2.Exit + " exit=" + $r.Exit)

# m: reads in project A do not release actions in project B in the same session.
$sid = New-Sid
$null = Invoke-Script $gate (New-Event $sid $fixture $readClaude)
$null = Invoke-Script $gate (New-Event $sid $fixture $readCheckpoint)
$r = Invoke-Script $gate (New-Event $sid $projB $npm)
Check 'm: project A reads, then npm test in project B exits 2' ($r.Exit -eq 2) ("exit=" + $r.Exit)

# cleanup
foreach ($s in $script:sessions) {
    Get-ChildItem -LiteralPath $tempRoot -Filter ("codex_orient_{0}.*.flag" -f $s) -File -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item Env:\HARNESS_WORKSPACE_ROOT -ErrorAction SilentlyContinue

$total = $script:pass + $script:fail
Write-Output ("{0}/{1} passed" -f $script:pass, $total)
if ($script:fail -gt 0) { exit 1 }
exit 0
