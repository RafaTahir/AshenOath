"""Execute the production batch against disposable child processes, never Godot.

The copied batch is unmodified except in the explicit mutation control. Python
children are real processes running tiny replacement tool scripts. Native EXE
stubs avoid CMD's non-CALL batch-file handoff, which can mask missing guards.
"""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
CSC = Path(os.environ.get("WINDIR", "C:/Windows")) / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
PINNED_PYTHON = Path("C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe")
EXIT_CODES = {"packs": 41, "sync": 42, "artifacts": 43, "godot": 44,
              "package": 45, "verify": 46, "native_profiles": 47}
CRASH_STATUS = -1073741819  # Windows NTSTATUS 0xC0000005, as reported by CMD.
TOOLS = {"sync_runtime_pack_manifest.py": "sync", "runtime_pack_artifacts.py": "artifacts",
         "build_web_runtime_manifest.py": "package", "verify_web_export.py": "verify",
         "verify_native_attack_profiles.py": "native_profiles"}

# H3 alone predates Stage 2. Supply its future validator stub now; activate the
# boundary test automatically when the merged production batch invokes it.
BATCH_LINES = (PROJECT / "Export_Web_Build.bat").read_text(encoding="utf-8-sig").splitlines()
STAGE_POSITIONS = {}
for line_number, line in enumerate(BATCH_LINES):
    command = line.strip()
    if command.startswith('"%GODOT%"'):
        STAGE_POSITIONS["godot"] = line_number
    if command.startswith('"%PYTHON%"'):
        for filename, stage in TOOLS.items():
            if filename in command:
                STAGE_POSITIONS[stage] = line_number
PACK_BUILD_POSITION = next(index for index, line in enumerate(BATCH_LINES)
                           if line.strip().lower().startswith("powershell ") and "build_runtime_packs.ps1" in line)
STAGES = sorted(STAGE_POSITIONS, key=STAGE_POSITIONS.get)

EXE_SOURCE = r'''
using System;
using System.IO;
using System.Reflection;
class DisposableChild {
    static int Main(string[] args) {
        string stage = Path.GetFileNameWithoutExtension(Assembly.GetExecutingAssembly().Location) == "powershell" ? "packs" : "godot";
        File.AppendAllText(Environment.GetEnvironmentVariable("BATCH_FIXTURE_LOG"), stage + "\n");
        File.WriteAllLines(Path.Combine(Environment.GetEnvironmentVariable("BATCH_FIXTURE_ROOT"), stage + ".args"), args);
        Console.WriteLine("DISPOSABLE CHILD: " + stage);
        if (Environment.GetEnvironmentVariable("BATCH_FIXTURE_FAIL") == stage) {
            string exitOverride = Environment.GetEnvironmentVariable("BATCH_FIXTURE_EXIT");
            return exitOverride == null ? (stage == "packs" ? 41 : 44) : int.Parse(exitOverride);
        }
        if (stage == "godot") {
            string html = args[args.Length - 1];
            Directory.CreateDirectory(Path.GetDirectoryName(html));
            File.WriteAllText(html, "disposable exported shell");
            File.WriteAllText(Path.ChangeExtension(html, ".pck"), "GDPCdisposable");
        }
        return 0;
    }
}
'''

PYTHON_SOURCE = '''import json, os, sys
from pathlib import Path
stage = {stage!r}
root = Path(os.environ["BATCH_FIXTURE_ROOT"])
with Path(os.environ["BATCH_FIXTURE_LOG"]).open("a", encoding="utf-8") as log:
    log.write(stage + "\\n")
(root / (stage + ".args.json")).write_text(json.dumps(sys.argv[1:]), encoding="utf-8")
print("DISPOSABLE CHILD:", stage)
if os.environ.get("BATCH_FIXTURE_FAIL") == stage:
    raise SystemExit(int(os.environ.get("BATCH_FIXTURE_EXIT", {code})))
out = Path(os.environ["ASHEN_OATH_WEB_DIRECTORY"])
if stage in ["package", "verify"]:
    (out / (stage + ".marker")).write_text("completed", encoding="ascii")
'''


@unittest.skipUnless(os.name == "nt", "Production Windows batch execution")
class ExportBatch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CSC.is_file() or not PINNED_PYTHON.is_file():
            raise unittest.SkipTest("Requires the batch's pinned Python and Windows C# compiler")
        temp_root = Path("D:/Temp/AshenOath")
        temp_root.mkdir(parents=True, exist_ok=True)
        cls.compiled = tempfile.TemporaryDirectory(prefix="batch-child-exe-", dir=temp_root)
        cls.addClassCleanup(cls.compiled.cleanup)
        source = Path(cls.compiled.name) / "child.cs"
        source.write_text(EXE_SOURCE, encoding="utf-8")
        cls.child_exe = source.with_suffix(".exe")
        result = subprocess.run([str(CSC), "/nologo", "/target:exe", "/out:" + str(cls.child_exe), str(source)],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise AssertionError("Could not compile disposable child: " + result.stdout + result.stderr)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="export batch fixture ", dir="D:/Temp/AshenOath")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project with spaces"
        (self.project / "tools").mkdir(parents=True)
        self.batch = self.project / "Export_Web_Build.bat"
        shutil.copyfile(PROJECT / "Export_Web_Build.bat", self.batch)
        self.bin = self.root / "child executables"
        self.bin.mkdir()
        for name in ["powershell.exe", "godot.exe"]:
            shutil.copyfile(self.child_exe, self.bin / name)
        for name, stage in TOOLS.items():
            (self.project / "tools" / name).write_text(PYTHON_SOURCE.format(stage=stage, code=EXIT_CODES[stage]), encoding="utf-8")
        self.runtime = self.project / "runtime_pack_manifest.json"
        self.runtime.write_text('{"fixture":"runtime source preserved"}\n', encoding="ascii")
        self.raw_packs = self.root / "builder raw packs"
        self.raw_packs.mkdir()
        (self.raw_packs / "runtime_pack_candidates.json").write_text('{"packs":[]}\n', encoding="ascii")
        (self.raw_packs / "opening.pck").write_bytes(b"GDPCraw pack must remain unchanged")
        self.output = self.root / "fresh web candidate"
        self.log = self.root / "children.log"
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        GODOT_BIN=str(self.bin / "godot.exe"), ASHEN_OATH_REUSE_PACKS="1",
                        ASHEN_OATH_PACK_DIRECTORY=str(self.raw_packs), ASHEN_OATH_WEB_DIRECTORY=str(self.output),
                        BATCH_FIXTURE_ROOT=str(self.root), BATCH_FIXTURE_LOG=str(self.log))
        self.env.pop("BATCH_FIXTURE_FAIL", None)
        self.env.pop("BATCH_FIXTURE_EXIT", None)
        self.production_before = {path: path.read_bytes() for path in [PROJECT / "Export_Web_Build.bat", PROJECT / "runtime_pack_manifest.json"]}
        self.raw_before = {path: path.read_bytes() for path in self.raw_packs.iterdir()}
        self.addCleanup(self._assert_sources_unchanged)

    def _assert_sources_unchanged(self):
        for path, before in {**self.production_before, **self.raw_before}.items():
            self.assertEqual(before, path.read_bytes(), str(path))

    def run_batch(self, fail=""):
        self.env["BATCH_FIXTURE_FAIL"] = fail
        # CMD's outer quote pair preserves a batch pathname containing spaces.
        command = '"' + os.environ.get("COMSPEC", "C:/Windows/System32/cmd.exe") + '" /d /s /c ""' + str(self.batch) + '""'
        return subprocess.run(command,
                              env=self.env, cwd=self.root, capture_output=True, text=True, timeout=30)

    def calls(self):
        return self.log.read_text(encoding="utf-8-sig").splitlines() if self.log.exists() else []

    def test_success_control_preserves_raw_pack_and_output_environment(self):
        result = self.run_batch()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(STAGES, self.calls())
        self.assertTrue((self.output / "index.pck").is_file())
        self.assertTrue((self.output / "verify.marker").is_file())
        sync = json.loads((self.root / "sync.args.json").read_text())
        self.assertEqual(self.runtime.resolve(), Path(sync[0]).resolve())
        self.assertEqual((self.raw_packs / "runtime_pack_candidates.json").resolve(), Path(sync[1]).resolve())
        godot = (self.root / "godot.args").read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(["--headless", "--path"], godot[:2])
        self.assertEqual(self.project.resolve(), Path(godot[2]).resolve())
        self.assertEqual(["--export-release", "Web Browser", str(self.output / "index.html")], godot[3:])
        package = json.loads((self.root / "package.args.json").read_text())
        self.assertEqual(self.output.resolve(), Path(package[0]).resolve())
        self.assertEqual(self.raw_packs.resolve(), Path(package[package.index("--pack-dir") + 1]).resolve())
        self.assertIn("--compress-wasm", package)

    def _assert_child_failure(self, stage, expected_exit=None):
        # unittest gives each case a fresh project, pack set and output path.
        result = self.run_batch(stage)
        expected_exit = EXIT_CODES[stage] if expected_exit is None else expected_exit
        self.assertEqual(expected_exit & 0xffffffff, result.returncode & 0xffffffff, result.stdout + result.stderr)
        self.assertEqual(STAGES[:STAGES.index(stage) + 1], self.calls())
        self.assertNotIn("Web build ready:", result.stdout)
        if STAGES.index(stage) < STAGES.index("godot"):
            self.assertFalse(self.output.exists())
        elif stage == "godot":
            self.assertFalse((self.output / "index.pck").exists())
        else:
            self.assertFalse((self.output / "verify.marker").exists())

    def test_sync_failure_stops_before_artifact_validation(self):
        self._assert_child_failure("sync")

    def test_artifact_failure_stops_before_export(self):
        self._assert_child_failure("artifacts")

    def test_godot_failure_stops_before_packaging(self):
        self._assert_child_failure("godot")

    def test_packager_failure_stops_before_verification(self):
        self._assert_child_failure("package")

    def test_verifier_failure_cannot_report_ready(self):
        self._assert_child_failure("verify")

    @unittest.skipUnless("native_profiles" in STAGES, "Native-profile hook activates after the Stage 2 merge")
    def test_native_profile_validator_failure_stops_the_batch(self):
        self._assert_child_failure("native_profiles")

    def test_negative_native_status_stops_every_child_boundary(self):
        # CMD's `if errorlevel 1` excludes signed negative NTSTATUS values.
        # Fresh fixtures preserve source/raw packs and detect every later child.
        for stage in [*STAGES, "packs"]:
            with self.subTest(stage=stage):
                fixture = ExportBatch("test_success_control_preserves_raw_pack_and_output_environment")
                fixture.setUp()
                try:
                    fixture.env["BATCH_FIXTURE_EXIT"] = str(CRASH_STATUS)
                    if stage == "packs":
                        fixture.test_pack_builder_exe_failure_stops_before_python_and_export()
                    else:
                        fixture._assert_child_failure(stage, CRASH_STATUS)
                finally:
                    try:
                        fixture._assert_sources_unchanged()
                    finally:
                        fixture.doCleanups()

    def test_pack_builder_exe_failure_stops_before_python_and_export(self):
        self.env.pop("ASHEN_OATH_REUSE_PACKS")
        self.assertEqual((self.bin / "powershell.exe").resolve(), Path(shutil.which("powershell", path=self.env["PATH"])).resolve())
        result = self.run_batch("packs")
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        expected = [stage for stage in STAGES if STAGE_POSITIONS[stage] < PACK_BUILD_POSITION] + ["packs"]
        self.assertEqual(expected, self.calls())
        self.assertFalse(self.output.exists())

    def test_existing_candidate_is_preserved_and_godot_is_not_called(self):
        self.output.mkdir()
        candidate = self.output / "index.pck"
        candidate.write_bytes(b"prior candidate must remain")
        result = self.run_batch()
        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        self.assertEqual(STAGES[:STAGES.index("godot")], self.calls())
        self.assertEqual(b"prior candidate must remain", candidate.read_bytes())

    def test_mutation_control_missing_guards_would_be_detected(self):
        # Prove a failing native child returns control to the batch. A .cmd
        # handoff could wrongly pass the negative tests even without guards.
        lines = self.batch.read_text(encoding="utf-8").splitlines()
        self.batch.write_text("\n".join(line for line in lines if not line.strip().lower().startswith("if errorlevel 1 exit /b")) + "\n", encoding="utf-8")
        result = self.run_batch("sync")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(STAGES, self.calls())
        self.assertIn("Web build ready:", result.stdout)


if __name__ == "__main__":
    unittest.main()
