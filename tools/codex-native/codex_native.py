"""Relay headless Codex calls from SSH / Windows session 0 to the signed-in desktop.

Windows Task Scheduler starts an on-demand task with the signed-in user's
interactive token; authenticated Windows named pipes carry stdin/stdout/stderr.
No TCP listener, timer, second Codex installation or second login.
"""
from __future__ import annotations

import ctypes
import glob
import json
import os
import subprocess
import sys
import threading
import time
import uuid
from multiprocessing.connection import Client, Listener
from pathlib import Path

# ---------------------------------------------------------------------------
# Settings. Each one reads an environment variable and falls back to a default.
# The worker is started by Task Scheduler, so it sees your persistent USER
# environment variables, not variables set only in the calling shell. Set any
# override as a user environment variable so the caller and the worker agree.
# ---------------------------------------------------------------------------

# Full Task Scheduler path of the on-demand worker task: folder plus task name,
# starting with a backslash. Must match what install_codex_native.ps1 registered.
TASK = os.environ.get("CODEX_NATIVE_TASK", r"\Harness\CodexNative")

# Folder holding per-call request/receipt subfolders. Must be a local folder
# that only you and SYSTEM can read; the installer creates and locks it.
ROOT = Path(os.environ.get("CODEX_NATIVE_STATE_DIR",
                           str(Path.home() / ".local" / "state" / "codex-native")))

# Full path to codex.exe. Empty = use the newest binary bundled with the Codex
# desktop app under %LOCALAPPDATA%\OpenAI\Codex\bin\<version>\codex.exe.
CODEX = os.environ.get("CODEX_NATIVE_CODEX", "")

# Full path to native PowerShell 7 (pwsh.exe), used for the sandbox preflight.
# Must be the native Windows build, not a shell running under MSYS2 or Cygwin.
PWSH = os.environ.get("CODEX_NATIVE_PWSH", r"C:\Program Files\PowerShell\7\pwsh.exe")

_SYSTEM32 = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32"
SCHTASKS = str(_SYSTEM32 / "schtasks.exe")
TASKKILL = str(_SYSTEM32 / "taskkill.exe")

START_TIMEOUT = 30           # seconds the caller waits for the desktop worker
JOB_TIMEOUT = 4 * 60 * 60    # seconds before a relayed process tree is stopped
NO_WINDOW = 0x08000000


class ProcessJob:
    """Windows closes every owned descendant when this job handle closes."""
    def __init__(self):
        from ctypes import wintypes as w

        class Basic(ctypes.Structure):
            _fields_ = [("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
                        ("flags", w.DWORD), ("min_ws", ctypes.c_size_t),
                        ("max_ws", ctypes.c_size_t), ("active", w.DWORD),
                        ("affinity", ctypes.c_size_t), ("priority", w.DWORD), ("scheduling", w.DWORD)]

        class Limits(ctypes.Structure):
            _fields_ = [("basic", Basic), ("io", ctypes.c_uint64 * 6),
                        ("process_mem", ctypes.c_size_t), ("job_mem", ctypes.c_size_t),
                        ("peak_process", ctypes.c_size_t), ("peak_job", ctypes.c_size_t)]

        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        self.kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, w.LPCWSTR]
        self.kernel.CreateJobObjectW.restype = w.HANDLE
        self.kernel.SetInformationJobObject.argtypes = [w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD]
        self.kernel.AssignProcessToJobObject.argtypes = [w.HANDLE, w.HANDLE]
        self.kernel.CloseHandle.argtypes = [w.HANDLE]
        self.handle = self.kernel.CreateJobObjectW(None, None)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = Limits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not self.kernel.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            self.close()
            raise ctypes.WinError(ctypes.get_last_error())

    def assign(self, proc):
        if not self.kernel.AssignProcessToJobObject(self.handle, int(proc._handle)):
            kill_tree(proc)
            raise ctypes.WinError(ctypes.get_last_error())

    def close(self):
        if self.handle:
            self.kernel.CloseHandle(self.handle)
            self.handle = None


def session_id():
    result = ctypes.c_ulong()
    if not ctypes.windll.kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(result)):
        raise ctypes.WinError()
    return result.value


def resolve_codex():
    if CODEX:
        if not os.path.isfile(CODEX):
            raise RuntimeError("CODEX_NATIVE_CODEX does not point at a file: " + CODEX)
        return CODEX
    candidates = glob.glob(str(Path(os.environ["LOCALAPPDATA"]) / "OpenAI/Codex/bin/*/codex.exe"))
    if not candidates:
        raise RuntimeError("No desktop Codex binary found; install the Codex app or set CODEX_NATIVE_CODEX")
    return max(candidates, key=os.path.getmtime)


def receipt(folder, **data):
    data.update(updated_at=time.time())
    target = folder / "receipt.json"
    temp = folder / "receipt.tmp"
    temp.write_text(json.dumps(data), encoding="utf-8")
    os.replace(temp, target)


def kill_tree(proc):
    # The Popen handle remains open, keeping this PID owned by this invocation.
    if proc.poll() is None:
        subprocess.run([TASKKILL, "/PID", str(proc.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       creationflags=NO_WINDOW, timeout=10)
        proc.wait(timeout=10)


def preflight_args(cli, args, cwd):
    overrides = []
    permission_profile = ":workspace"
    index = 0
    while index < len(args):
        arg = args[index]
        if arg in ("-c", "--config", "-p", "--profile", "--enable", "--disable") and index + 1 < len(args):
            overrides += args[index:index + 2]
            index += 2
        elif arg in ("-C", "--cd") and index + 1 < len(args):
            cwd = os.path.abspath(os.path.join(cwd, args[index + 1]))
            index += 2
        elif arg in ("-s", "--sandbox") and index + 1 < len(args):
            permission_profile = ":read-only" if args[index + 1] == "read-only" else ":workspace"
            index += 2
        else:
            index += 1
    return [cli, *overrides, "sandbox", "--include-managed-config", "--permission-profile", permission_profile,
            "-C", cwd, "--", PWSH, "-NoProfile", "-Command",
            "Get-Item -LiteralPath . -ErrorAction Stop | Out-Null; Write-Output CODEX-NATIVE-PREFLIGHT-OK"]


def relay_process(connection, argv, cwd, folder, timeout=JOB_TIMEOUT):
    """One owned process, with bounded lifetime and independent completion receipt."""
    send_lock = threading.Lock()
    disconnected = threading.Event()

    def send(message):
        with send_lock:
            try:
                connection.send(message)
            except (OSError, EOFError):
                disconnected.set()

    job = ProcessJob()
    try:
        proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, creationflags=NO_WINDOW, bufsize=0)
        job.assign(proc)
    except BaseException:
        job.close()
        raise
    receipt(folder, status="running", pid=proc.pid, session_id=session_id())

    def output(stream, channel):
        while chunk := stream.read(65536):
            send((channel, chunk))

    def input_stream():
        try:
            while True:
                channel, chunk = connection.recv()
                if channel == "eof":
                    proc.stdin.close()
                    # Keep waiting for pipe EOF so a vanished caller cancels the job.
                    continue
                if channel == "stdin":
                    proc.stdin.write(chunk)
                    proc.stdin.flush()
        except (EOFError, OSError, ValueError):
            disconnected.set()

    threads = [threading.Thread(target=output, args=(proc.stdout, "stdout"), daemon=True),
               threading.Thread(target=output, args=(proc.stderr, "stderr"), daemon=True)]
    for thread in threads:
        thread.start()
    threading.Thread(target=input_stream, daemon=True).start()
    started = time.monotonic()
    code = None
    try:
        while proc.poll() is None:
            if disconnected.wait(0.1):
                code = 125
                break
            if time.monotonic() - started >= timeout:
                code = 124
                break
        if code is not None:
            kill_tree(proc)
        else:
            code = proc.wait()
        job.close()
        for thread in threads:
            thread.join(timeout=5)
        streams_closed = not any(thread.is_alive() for thread in threads)
        if not streams_closed:
            code = 125
        receipt(folder, status="completed" if code == 0 else "failed", exit_code=code,
                session_id=session_id(), pid=proc.pid)
        if streams_closed:
            send(("exit", code))
        return code
    finally:
        kill_tree(proc)
        job.close()
        for stream in (proc.stdin, proc.stdout, proc.stderr):
            if not stream.closed:
                stream.close()
        connection.close()


def worker():
    if session_id() == 0:
        raise RuntimeError("The CodexNative task must use Interactive logon, not a service token")
    for folder in sorted(ROOT.glob("*")):
        if not folder.is_dir() or len(folder.name) != 32:
            continue
        request_file = folder / "request.json"
        if not request_file.exists():
            continue
        try:
            (folder / "claim").mkdir()
        except FileExistsError:
            continue
        connection = None
        try:
            request = json.loads(request_file.read_text(encoding="utf-8"))
            if time.time() - request["created_at"] > START_TIMEOUT:
                receipt(folder, status="expired")
                continue
            connection = Client(request["pipe"], family="AF_PIPE", authkey=bytes.fromhex(request["key"]))
            # Remove the pipe authentication key once the peer has authenticated.
            request_file.unlink()
            connection.send(("ready", session_id()))
            cli = resolve_codex()
            args, cwd = request["args"], request["cwd"]
            if any(arg in ("exec", "review", "app-server") for arg in args):
                preflight_job = ProcessJob()
                try:
                    probe = subprocess.Popen(preflight_args(cli, args, cwd), stdin=subprocess.DEVNULL,
                                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=NO_WINDOW)
                    preflight_job.assign(probe)
                    stdout, stderr = probe.communicate(timeout=25)
                    checked = subprocess.CompletedProcess(probe.args, probe.returncode, stdout, stderr)
                finally:
                    preflight_job.close()
                    if 'probe' in locals():
                        probe.wait(timeout=5)
                if checked.returncode or b"CODEX-NATIVE-PREFLIGHT-OK" not in checked.stdout:
                    connection.send(("stderr", b"[codex native] sandbox preflight failed; no model started\n"
                                     + checked.stdout + checked.stderr))
                    connection.send(("exit", 126))
                    receipt(folder, status="preflight_failed", exit_code=126, session_id=session_id())
                    connection.close()
                    return 126
            # Detect a caller lost during preflight before starting a model.
            connection.send(("stderr", b""))
            return relay_process(connection, [cli, *args], cwd, folder)
        except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as exc:
            receipt(folder, status="failed", error=str(exc))
            if connection:
                try:
                    connection.send(("stderr", ("[codex native] " + str(exc) + "\n").encode()))
                    connection.send(("exit", 126))
                except (OSError, EOFError):
                    pass
                connection.close()
            return 126
        finally:
            request_file.unlink(missing_ok=True)
    return 0


def client(args):
    if not ROOT.is_dir():
        raise RuntimeError("Native bridge is not installed (no state folder at " + str(ROOT)
                           + "); run install_codex_native.ps1")
    job_id = uuid.uuid4().hex
    folder = ROOT / job_id
    folder.mkdir()
    address = r"\\.\pipe\codex-native-" + job_id
    key = os.urandom(32)
    listener = Listener(address, family="AF_PIPE", authkey=key)
    request = dict(args=args, cwd=os.getcwd(), pipe=address, key=key.hex(), created_at=time.time())
    temp = folder / "request.tmp"
    temp.write_text(json.dumps(request), encoding="utf-8")
    os.replace(temp, folder / "request.json")
    receipt(folder, status="queued", caller_session_id=session_id())
    accepted = threading.Event()
    peers = []

    def accept():
        try:
            peers.append(listener.accept())
        except OSError:
            pass
        finally:
            accepted.set()

    threading.Thread(target=accept, daemon=True).start()
    connection = None
    try:
        started = time.monotonic()
        while not accepted.is_set() and time.monotonic() - started < START_TIMEOUT:
            launch = subprocess.run([SCHTASKS, "/Run", "/TN", TASK], capture_output=True,
                                    creationflags=NO_WINDOW, timeout=5)
            if launch.returncode:
                raise RuntimeError("Cannot start task " + TASK + ": " + launch.stderr.decode(errors="replace"))
            accepted.wait(1)
        if not peers:
            raise RuntimeError("Desktop worker did not connect. Windows must remain signed in (a locked screen is expected to work)")
        connection = peers[0]
        if not connection.poll(5) or connection.recv()[0] != "ready":
            raise RuntimeError("Desktop worker did not complete its handshake")

        def forward_stdin():
            try:
                while chunk := os.read(sys.stdin.fileno(), 65536):
                    connection.send(("stdin", chunk))
                connection.send(("eof", b""))
            except (OSError, EOFError):
                pass

        threading.Thread(target=forward_stdin, daemon=True).start()
        while True:
            if not connection.poll(1):
                continue
            channel, data = connection.recv()
            if channel == "exit":
                return data
            stream = sys.stdout.buffer if channel == "stdout" else sys.stderr.buffer
            stream.write(data)
            stream.flush()
    finally:
        if connection:
            connection.close()
        listener.close()
        (folder / "request.json").unlink(missing_ok=True)


def main():
    try:
        import msvcrt
        for stream in (sys.stdin, sys.stdout, sys.stderr):
            if stream is not None:
                msvcrt.setmode(stream.fileno(), os.O_BINARY)
        if sys.argv[1:] == ["--bridge-worker"]:
            return worker()
        args = sys.argv[1:]
        if session_id() != 0 or args in (["--version"], ["-V"], ["--help"], ["-h"]):
            return subprocess.call([resolve_codex(), *args])
        if not args:
            raise RuntimeError("Interactive Codex needs a native Windows console; over SSH only headless calls are relayed")
        return client(args)
    except KeyboardInterrupt:
        return 130
    except (OSError, EOFError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("[codex native] " + str(exc), file=sys.stderr)
        return 126


if __name__ == "__main__":
    sys.exit(main())
