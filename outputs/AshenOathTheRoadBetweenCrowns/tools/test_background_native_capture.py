"""Exercise desktop/process ownership with console-only children, never Godot."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from background_native_capture import spawn_background


@unittest.skipUnless(os.name == "nt", "verified Windows launcher")
class BackgroundDesktop(unittest.TestCase):
    def test_child_binds_only_owned_non_input_desktop(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "child.log"
            code = """import ctypes,json,os,time
from background_native_capture import _Windows
api=_Windows()
thread=ctypes.windll.kernel32.GetCurrentThreadId()
print(json.dumps({'desktop':api.name(api.thread_desktop(thread)),'input':api.input_name(),'expected':os.environ['ASHENOATH_CAPTURE_DESKTOP']}),flush=True)
time.sleep(.2)
"""
            env = dict(os.environ, PYTHONPATH=str(Path(__file__).resolve().parent))
            with path.open("wb") as output:
                process = spawn_background([sys.executable, "-c", code], cwd=folder, stdout=output, env=env)
                try:
                    self.assertEqual(process.wait(timeout=10), 0)
                    self.assertEqual(process.poll(), 0)
                    self.assertEqual(process.desktop_receipt["binding"], "STARTUPINFO.lpDesktop")
                    self.assertNotEqual(process.desktop_receipt["desktop"], process.desktop_receipt["input_desktop_before"])
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
                    process.close()
            result = json.loads(path.read_text())
            self.assertEqual(result["desktop"], result["expected"])
            self.assertNotEqual(result["desktop"], result["input"])
            process.close()  # idempotent, no handle or desktop reuse.

    def test_timeout_cleanup_owns_only_its_child(self):
        with tempfile.TemporaryDirectory() as folder:
            with (Path(folder) / "child.log").open("wb") as output:
                process = spawn_background([sys.executable, "-c", "import time; time.sleep(20)"], cwd=folder, stdout=output)
                try:
                    with self.assertRaises(subprocess.TimeoutExpired):
                        process.wait(timeout=.02)
                    with self.assertRaises(RuntimeError):
                        process.close()
                    process.terminate()
                    self.assertEqual(process.wait(timeout=5), 1)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
                    process.close()

    def test_missing_executable_fails_before_creating_desktop(self):
        with self.assertRaises(ValueError):
            spawn_background(["missing_capture_executable"], cwd=Path.cwd(), stdout=None)


if __name__ == "__main__":
    unittest.main()
