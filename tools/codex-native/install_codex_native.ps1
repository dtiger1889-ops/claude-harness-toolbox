# Installs the native Codex bridge for the current Windows user.
# Run in native PowerShell (Windows PowerShell 5.1 or pwsh 7) on the signed-in desktop,
# not over SSH. Rerun it after moving this folder or reinstalling Python.
#
# Settings: each parameter defaults to the environment variable named beside it, then
# to a built-in default. CODEX_NATIVE_STATE_DIR and CODEX_NATIVE_TASK are also read by
# codex_native.py at run time, so a non-default value must be saved as a USER
# environment variable (the installer refuses otherwise); the worker started by Task
# Scheduler sees only persistent user variables.
param(
    # Full path to a python.org-style python.exe (3.8 or newer) with pythonw.exe in the
    # same folder. Not the Microsoft Store alias under WindowsApps. Env: CODEX_NATIVE_PYTHON.
    # Default: the first python.exe on PATH that is not the Store alias.
    [string]$Python = $env:CODEX_NATIVE_PYTHON,

    # Folder that holds your `codex` and `codex.cmd` launchers and comes BEFORE any other
    # Codex on PATH for the shells that call Codex (SSH, tmux, desktop). Env: CODEX_NATIVE_BIN_DIR.
    [string]$BinDir = $(if ($env:CODEX_NATIVE_BIN_DIR) { $env:CODEX_NATIVE_BIN_DIR } else { Join-Path $env:USERPROFILE '.local\bin' }),

    # Local folder for per-call requests and receipts; locked to you and SYSTEM.
    # Env: CODEX_NATIVE_STATE_DIR (also read by codex_native.py).
    [string]$StateDir = $(if ($env:CODEX_NATIVE_STATE_DIR) { $env:CODEX_NATIVE_STATE_DIR } else { Join-Path $env:USERPROFILE '.local\state\codex-native' }),

    # Task Scheduler path of the on-demand worker: \Folder\Name. Env: CODEX_NATIVE_TASK
    # (also read by codex_native.py).
    [string]$Task = $(if ($env:CODEX_NATIVE_TASK) { $env:CODEX_NATIVE_TASK } else { '\Harness\CodexNative' })
)
$ErrorActionPreference = 'Stop'

$defaultStateDir = Join-Path $env:USERPROFILE '.local\state\codex-native'
$defaultTask = '\Harness\CodexNative'
foreach ($setting in @(@('CODEX_NATIVE_STATE_DIR', $StateDir, $defaultStateDir), @('CODEX_NATIVE_TASK', $Task, $defaultTask))) {
    $name, $value, $default = $setting
    $saved = [Environment]::GetEnvironmentVariable($name, 'User')
    if (($value -ne $default -or $saved) -and $saved -ne $value) {
        throw "$name is '$value' here but the user environment variable is '$saved'. Save it first: [Environment]::SetEnvironmentVariable('$name', '$value', 'User'), then open a new shell and rerun."
    }
}

if (!$Python) {
    $Python = Get-Command python.exe -CommandType Application -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1 -ExpandProperty Source
    if (!$Python) { throw 'No python.exe found on PATH. Pass -Python <full path to python.exe> or set CODEX_NATIVE_PYTHON.' }
}
$pythonw = Join-Path (Split-Path $Python) 'pythonw.exe'
if (!(Test-Path -LiteralPath $Python)) { throw "Python not found: $Python" }
if (!(Test-Path -LiteralPath $pythonw)) { throw "pythonw.exe missing beside $Python (the task needs the windowless interpreter)" }

$bridge = Join-Path $PSScriptRoot 'codex_native.py'
$split = $Task.LastIndexOf('\')
if (!$Task.StartsWith('\') -or $split -lt 0 -or $split -eq $Task.Length - 1) { throw "Task must look like \Folder\Name, got '$Task'" }
$taskPath = $Task.Substring(0, $split + 1)
$taskName = $Task.Substring($split + 1)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
& icacls.exe $StateDir /inheritance:r /grant:r "${identity}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect bridge state folder' }

# No trigger: the task runs only when codex_native.py asks for it.
$action = New-ScheduledTaskAction -Execute $pythonw -Argument ('"' + $bridge + '" --bridge-worker') -WorkingDirectory $PSScriptRoot
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances Parallel -ExecutionTimeLimit (New-TimeSpan -Hours 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Principal $principal -Settings $settings -Force | Select-Object TaskPath,TaskName,State

# Keep the first copy of any launcher this replaces, so it can be restored later.
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
$backup = Join-Path $StateDir 'original-shims'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($name in @('codex','codex.cmd')) {
    $original = Join-Path $BinDir $name
    $saved = Join-Path $backup $name
    if ((Test-Path -LiteralPath $original) -and !(Test-Path -LiteralPath $saved)) {
        Copy-Item -LiteralPath $original -Destination $saved
    }
}

# Fill the shim templates with this machine's interpreter and bridge paths.
$encoding = New-Object System.Text.UTF8Encoding($false)
$bash = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'codex-shim') -Raw) -replace "`r`n", "`n"
$bash = $bash.Replace('@PYTHON@', $Python.Replace('\', '/')).Replace('@BRIDGE@', $bridge.Replace('\', '/'))
[IO.File]::WriteAllText((Join-Path $BinDir 'codex'), $bash, $encoding)
$cmd = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'codex-shim.cmd') -Raw) -replace "`r?`n", "`r`n"
$cmd = $cmd.Replace('@PYTHON@', $Python).Replace('@BRIDGE@', $bridge)
[IO.File]::WriteAllText((Join-Path $BinDir 'codex.cmd'), $cmd, $encoding)

$first = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
if ($first -and (Split-Path $first) -ne $BinDir.TrimEnd('\')) {
    Write-Warning "codex on this shell's PATH resolves to $first, not $BinDir. Put $BinDir first on PATH for every shell that calls Codex."
}
Write-Output "Installed: task $Task, launchers in $BinDir, state in $StateDir"
