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
from multiprocessing import Pipe
from pathlib import Path

spec = importlib.util.spec_from_file_location('codex_native', Path(__file__).with_name('codex_native.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


@unittest.skipUnless(os.name == 'nt', 'Native Windows process lifetime checks')
class BridgeTests(unittest.TestCase):
    def call(self, code, payload=b'', timeout=5):
        with tempfile.TemporaryDirectory(prefix='codex bridge test ') as folder:
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


if __name__ == '__main__':
    unittest.main()
