import ctypes
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock
from multiprocessing import Pipe
from pathlib import Path

spec = importlib.util.spec_from_file_location('codex_native', Path(__file__).with_name('codex_native.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


@unittest.skipUnless(os.name == 'nt', 'Native Windows process lifetime checks')
class BridgeTests(unittest.TestCase):
    def call(self, code, payload=b'', timeout=5):
        # A just-killed descendant can still hold the folder as its cwd for a moment.
        with tempfile.TemporaryDirectory(prefix='codex bridge test ', ignore_cleanup_errors=True) as folder:
            client, worker = Pipe()
            result = []
            thread = threading.Thread(target=lambda: result.append(bridge.relay_process(
                worker, [sys.executable, '-u', '-c', code], folder, Path(folder), timeout)))
            thread.start()
            client.send(('stdin', payload))
            client.send(('eof', b''))
            output = {'stdout': b'', 'stderr': b''}
            until = time.monotonic() + 15
            while time.monotonic() < until:
                self.assertTrue(client.poll(10), 'relay did not finish')
                kind, data = client.recv()
                if kind == 'exit':
                    break
                output[kind] += data
            else:
                self.fail('relay deadline')
            thread.join(10)
            client.close()
            self.assertFalse(thread.is_alive())
            receipt = json.loads((Path(folder) / 'receipt.json').read_text())
            return result[0], output, receipt

    def test_binary_stdin_stdout_and_separate_stderr(self):
        payload = bytes(range(256)) * 4096
        code, output, receipt = self.call(
            "import sys; sys.stdout.buffer.write(sys.stdin.buffer.read()); sys.stderr.write('separate')", payload)
        self.assertEqual(code, 0)
        self.assertEqual(output['stdout'], payload)
        self.assertEqual(output['stderr'], b'separate')
        self.assertEqual(receipt['status'], 'completed')

    def test_nonzero_exit_propagates(self):
        code, _, receipt = self.call('import sys; sys.exit(7)')
        self.assertEqual(code, 7)
        self.assertEqual(receipt['exit_code'], 7)

    def test_timeout_stops_owned_process(self):
        code, _, receipt = self.call('import time; time.sleep(60)', timeout=0.3)
        self.assertEqual(code, 124)
        self.assertEqual(receipt['status'], 'failed')

    def assert_gone(self, pid):
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.OpenProcess(0x100000, 0, pid)
        if handle:
            try:
                self.assertEqual(kernel.WaitForSingleObject(handle, 3000), 0, 'owned child survived')
            finally:
                kernel.CloseHandle(handle)

    def test_normal_exit_also_stops_background_descendants(self):
        code, output, _ = self.call(
            "import subprocess,sys; p=subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)'],"
            "stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);print(p.pid)")
        self.assertEqual(code, 0)
        self.assert_gone(int(output['stdout'].strip()))

    def test_disconnected_caller_stops_worker(self):
        with tempfile.TemporaryDirectory() as folder:
            client, worker = Pipe()
            result = []
            thread = threading.Thread(target=lambda: result.append(bridge.relay_process(
                worker, [sys.executable, '-c', 'import time;time.sleep(60)'], folder, Path(folder), 10)))
            thread.start()
            client.send(('eof', b''))
            time.sleep(0.15)
            client.close()
            thread.join(10)
            self.assertFalse(thread.is_alive())
            self.assertEqual(result, [125])

    def test_preflight_preserves_config_and_target_with_spaces(self):
        args = bridge.preflight_args('codex', ['exec', '-C', r'C:\path with spaces',
                                             '-c', 'windows.sandbox=mxc', '-m', 'chosen'], r'C:\caller')
        self.assertIn('windows.sandbox=mxc', args)
        self.assertEqual(args[args.index('-C') + 1], r'C:\path with spaces')
        self.assertNotIn('chosen', args)
        readonly = bridge.preflight_args('codex', ['exec', '-s', 'read-only'], r'C:\caller')
        self.assertEqual(readonly[readonly.index('--permission-profile') + 1], ':read-only')

    def test_preflight_reads_equals_form_flags(self):
        args = bridge.preflight_args('codex', ['exec', r'--cd=C:\target dir', '--config=windows.sandbox=mxc',
                                             '--sandbox=read-only', '--profile=fast', 'do it'], r'C:\caller')
        self.assertEqual(args[args.index('-C') + 1], r'C:\target dir')
        self.assertIn('--config=windows.sandbox=mxc', args)
        self.assertIn('--profile=fast', args)
        self.assertEqual(args[args.index('--permission-profile') + 1], ':read-only')
        self.assertNotIn('do it', args)

    def run_client_without_worker(self, start_timeout, relaunch_every):
        launches = []
        fake = lambda *a, **k: launches.append(time.time()) or subprocess.CompletedProcess(a, 0, b'', b'')
        with tempfile.TemporaryDirectory() as root, \
                mock.patch.object(bridge, 'ROOT', Path(root)), \
                mock.patch.object(bridge, 'START_TIMEOUT', start_timeout), \
                mock.patch.object(bridge, 'RELAUNCH_EVERY', relaunch_every), \
                mock.patch.object(bridge.subprocess, 'run', fake):
            started = time.time()
            with self.assertRaisesRegex(RuntimeError, 'did not connect'):
                bridge.client(['exec', '-'])
            return time.time() - started, launches

    def test_client_gives_up_at_the_worker_expiry_deadline(self):
        elapsed, _ = self.run_client_without_worker(1.0, 0.8)
        self.assertLess(elapsed, 1.3)

    def test_slow_start_relaunches_with_doubling_gaps(self):
        # Gaps 0.2, 0.4, 0.8 inside 1.2s: launches at 0, 0.2, 0.6 (a fixed gap would launch 6 times).
        _, launches = self.run_client_without_worker(1.2, 0.2)
        self.assertEqual(len(launches), 3)

    def run_worker(self, root, created_at, probe_code='print(1)'):
        """Queue one exec request, run the worker as the desktop session would, return its messages."""
        folder = Path(root) / ('a' * 32)
        folder.mkdir()
        key = os.urandom(32)
        address = r'\\.\pipe\codex-native-test-' + os.urandom(8).hex()
        listener = bridge.Listener(address, family='AF_PIPE', authkey=key)
        (folder / 'request.json').write_text(json.dumps(dict(
            args=['exec', '-'], cwd=root, pipe=address, key=key.hex(), created_at=created_at)), encoding='utf-8')
        result, messages = [], []
        with mock.patch.object(bridge, 'ROOT', Path(root)), \
                mock.patch.object(bridge, 'session_id', lambda: 1), \
                mock.patch.object(bridge, 'resolve_codex', lambda: 'codex'), \
                mock.patch.object(bridge, 'PREFLIGHT_TIMEOUT', 0.5), \
                mock.patch.object(bridge, 'preflight_args', lambda *a: [sys.executable, '-c', probe_code]):
            thread = threading.Thread(target=lambda: result.append(bridge.worker()))
            thread.start()
            if created_at > time.time() - bridge.START_TIMEOUT:
                connection = listener.accept()
                while connection.poll(10):
                    messages.append(connection.recv())
                    if messages[-1][0] == 'exit':
                        break
                connection.close()
            thread.join(15)
        listener.close()
        self.assertFalse(thread.is_alive())
        return result, messages, json.loads((folder / 'receipt.json').read_text())

    def test_worker_expires_a_request_past_the_deadline(self):
        with tempfile.TemporaryDirectory() as root:
            result, _, receipt = self.run_worker(root, time.time() - bridge.START_TIMEOUT - 1)
            self.assertEqual(result, [0])
            self.assertEqual(receipt['status'], 'expired')
            self.assertFalse((Path(root) / ('a' * 32) / 'request.json').exists())

    def test_hung_preflight_times_out_without_starting_a_model(self):
        with tempfile.TemporaryDirectory() as root:
            result, messages, receipt = self.run_worker(root, time.time(), 'import time; time.sleep(30)')
            self.assertEqual(result, [126])
            self.assertEqual(messages[-1], ('exit', 126))
            self.assertIn(b'timed out', b''.join(m[1] for m in messages if m[0] == 'stderr'))
            self.assertEqual(receipt['status'], 'failed')


if __name__ == '__main__':
    unittest.main()
