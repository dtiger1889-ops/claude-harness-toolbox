# Native Codex bridge for SSH and session 0 (Windows)

On Windows, the Codex CLI's sandbox does not work when Codex is started from an SSH
login. OpenSSH runs your shell in Windows session 0, the non-interactive service
session, and that includes a tmux server you started over SSH. This bridge keeps your
ordinary `codex exec`, `codex review` and `codex app-server` calls working from there:
it hands each headless call to an on-demand task that runs the same Codex binary in
your signed-in desktop session and relays its input, output and exit code back.

Calls made from the desktop are not touched; they run Codex directly. First installed
2026-10-15.

## What you need

- Windows, with you signed in on the desktop. A locked screen should be enough
  (the task uses Interactive logon), but that case has not been tested. Fully signed
  out is not supported: the bridge reports the worker as unavailable instead of
  queueing a model run for later.
- The Codex desktop app, whose bundled `codex.exe` the bridge finds by itself, or any
  `codex.exe` you name with `CODEX_NATIVE_CODEX`.
- A python.org-style Python 3.8 or newer with `pythonw.exe` beside `python.exe`. The
  Microsoft Store alias does not work.
- PowerShell 7 (`pwsh.exe`), the native Windows build. The sandbox preflight runs it.
- A folder of Codex launchers (`codex` for bash, `codex.cmd` for Windows) that comes
  before any other Codex on PATH in every shell that calls Codex.

## How it works

The two launchers call `codex_native.py`. On the desktop it runs Codex directly. In
session 0 it writes a request into the state folder, opens an authenticated Windows
named pipe, and starts the scheduled task. The task has no trigger, runs at Limited
privilege with Interactive logon, and runs only when asked. Its worker connects to the
pipe, deletes the request (which holds the pipe key), and runs Codex in the caller's
directory with the caller's arguments. Standard input, output, error and the exit code
are relayed byte for byte, so tools that speak Codex's protocol over stdio still work.
Separate calls can run at the same time.

There is no network listener, no second Codex installation, no new login and no change
to the sandbox policy. The worker uses your saved `~/.codex` sign-in and configuration
and inherits the desktop environment, not the SSH shell's. Environment variables you set
only in the calling shell are not forwarded.

Before any `exec`, `review` or `app-server` call starts a model, the worker runs a
zero-token sandbox probe: native PowerShell, inside the Codex sandbox, in the target
directory. If the probe fails, the call returns 126 and no model starts. There is no
retry with full access and no fallback outside the sandbox.

Each call runs inside a Windows Job Object, so its whole process tree stops together.
The worker stops it when the caller disconnects (exit 125) or at the four-hour deadline
(exit 124), and closing the job also ends background processes the call left behind.
Each call leaves a small `receipt.json` in its own folder under the state folder
(status, exit code, session); prompts and output are never stored there. The caller
waits 120 seconds for the worker to connect, measured from when the request was created
(the same deadline the worker uses to expire it), then gives up. While it waits it
re-launches the task after gaps of 10, 20 and 40 seconds, so a slow start stacks a few
workers rather than one per second; on a fully loaded machine a 30-second window with
one-second relaunches stacked 18 workers and none connected in time. The sandbox probe
may run for 120 seconds; it was measured at 28-49 seconds with the screen locked.

Interactive Codex (no arguments) is not relayed; it needs a native Windows console.

## Settings

Set any value you change as a **user** environment variable
(`[Environment]::SetEnvironmentVariable('NAME', 'value', 'User')`, then open a new
shell). The worker is started by Task Scheduler and sees only persistent user
variables, so a value set in one shell would leave the caller and worker disagreeing.

| Variable | Read by | Default | What the value must be |
|---|---|---|---|
| `CODEX_NATIVE_STATE_DIR` | bridge, installer | `%USERPROFILE%\.local\state\codex-native` | A local folder only you and SYSTEM can read. The installer creates and locks it. |
| `CODEX_NATIVE_TASK` | bridge, installer | `\Harness\CodexNative` | The Task Scheduler path of the worker, `\Folder\Name`. |
| `CODEX_NATIVE_CODEX` | bridge | newest `%LOCALAPPDATA%\OpenAI\Codex\bin\<version>\codex.exe` | Full path to the `codex.exe` both sides should run. |
| `CODEX_NATIVE_PWSH` | bridge | `C:\Program Files\PowerShell\7\pwsh.exe` | Full path to native PowerShell 7, used for the preflight. |
| `CODEX_NATIVE_PYTHON` | installer | first `python.exe` on PATH that is not the Store alias | Full path to `python.exe`, with `pythonw.exe` in the same folder. |
| `CODEX_NATIVE_BIN_DIR` | installer | `%USERPROFILE%\.local\bin` | The launcher folder that is first on PATH for Codex. |

The installer takes the same values as parameters (`-Python`, `-BinDir`, `-StateDir`,
`-Task`) and refuses a non-default state folder or task path that is not also saved as
a user variable.

## Install, check, undo

Install from native PowerShell on the desktop, not over SSH:

```powershell
powershell -ExecutionPolicy Bypass -File .\install_codex_native.ps1
```

It registers the task, creates and locks the state folder, saves your existing `codex`
and `codex.cmd` launchers once under `<state folder>\original-shims`, and writes new
launchers into the launcher folder from the `codex-shim` and `codex-shim.cmd` templates
with your Python and bridge paths filled in. Rerun it after moving this folder or
reinstalling Python. It warns if `codex` on the current PATH resolves somewhere else.

If a call from SSH fails to start, look at the task
(`Get-ScheduledTask -TaskPath '\Harness\' -TaskName CodexNative`, or your own path) and
the newest `receipt.json`. Anything that runs `codex.exe` directly, rather than through
the launchers, bypasses the bridge.

To undo it, copy the files in `original-shims` back over the launchers and unregister
only the bridge task once no call is running. Restoring the old launchers brings the
session 0 failures back too.

## Tests

`test_codex_native.py` runs six native Windows checks without the scheduled task or
Codex: binary stdin and stdout with stderr kept separate, exit-code propagation,
deadline cleanup, cleanup when the caller disconnects, background descendants stopped
after a normal exit, and preflight argument handling.

```powershell
python .\test_codex_native.py -v
```

The full path through SSH, the task and a real Codex binary was checked by hand on the
first install (2026-10-15): from an SSH-started tmux, native PowerShell reads and
writes worked with writes outside the workspace denied, concurrent Git jobs ran,
preflight passed and a deliberately broken preflight failed, and an `app-server`
initialize request got its response. OpenAI's Codex plugin for Claude Code
(codex-plugin-cc 1.0.6) ran its `setup --json` check from session 0 through the bridge
and reported ready and signed in. No model request ran during those checks.

## What broke, and why the bridge looks like this

These are the failures from the first install. Your machine may fail differently;
they explain the design choices above.

- **Session 0 broke the sandbox in two ways.** With the elevated sandbox runner, Codex
  timed out. Under the MXC sandbox, PowerShell, Git and MSYS2 processes started in
  session 0 died at startup with `0xC0000142` (a DLL initialization failure). The same
  native PowerShell and Git, and the same file boundaries, worked from the desktop
  session. The probes showed the failure depends on the session; they did not establish
  which Windows DLL fails or why. That is why the bridge moves the call to the desktop
  instead of trying to repair session 0.
- **MSYS bash failed under MXC even on the desktop.** So the preflight and the
  supported audit shell are native PowerShell, and the bridge does not make interactive
  Codex work inside MSYS2 tmux.
- **`cmd /c echo` passing proved nothing.** A sandboxed `cmd /c echo` succeeded on a
  host where real commands still failed. The preflight therefore runs native PowerShell
  in the actual target directory and checks for its own marker line.
- **No full-access fallback, on purpose.** When the sandbox cannot start, retrying
  without it would quietly run an agent with more access than you asked for. The
  bridge fails with 126 instead.

OpenAI's guidance on the Windows sandbox and its compatibility probe (checked
2026-10-15): https://learn.chatgpt.com/docs/windows/windows-sandbox
