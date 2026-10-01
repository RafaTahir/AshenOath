#!/usr/bin/env python3
"""Verify that the authoritative release runner fails closed.

This is a verifier-of-verifiers. It checks the runner's ownership boundary and
exercises the log classifier with deliberate active, shutdown, and incomplete
fixtures. A PASS marker must never hide a runtime or cleanup failure.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import tempfile
from pathlib import Path


def _load_classifier(path: Path):
    spec = importlib.util.spec_from_file_location("verify_qa_005", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load classifier: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.classify


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    runner_path = project / "tools" / "run_release_gate.ps1"
    ticket_runner_path = project / "tools" / "run_ticket_gate.ps1"
    classifier_path = project / "tools" / "verify_qa_005.py"
    try:
        runner = runner_path.read_text(encoding="utf-8-sig")
        ticket_runner = ticket_runner_path.read_text(encoding="utf-8-sig")
    except OSError as error:
        print(f"QA-001: FAIL - cannot read gate runner: {error}")
        return 1
    require(classifier_path.is_file(), "active diagnostic classifier is missing")
    release_report_path = project / "tools" / "verify_release_report.py"
    require(release_report_path.is_file(), "strict release-report validator is missing")

    required_runner_contract = {
        "Invoke-ManagedProcess": "owned process execution is missing",
        "if ($exitCode -ne 0)": "native exit-code failure is not enforced",
        "produced no verifier pass marker": "missing pass-marker failure is not enforced",
        "VERIFIER_PHASE:\\s*SHUTDOWN": "shutdown phase boundary is not recorded",
        "emitted a release-blocking error": "active diagnostic failure is not enforced",
        "Write-ReleaseReport \"fail\"": "runner does not write a failure report",
        "verify_qa_005": "active-render diagnostic classifier is not wired",
        "$blockingLine": "external gates do not inspect fatal log diagnostics",
    }
    for token, message in required_runner_contract.items():
        require(token in runner, message)
    require("$resourcePattern" in ticket_runner and "$fatalResource" in ticket_runner, "ticket gate does not classify resource errors")
    require("$runtimeFailure" in ticket_runner, "ticket gate does not classify generic runtime errors")
    require("$shutdownIndex" not in ticket_runner, "ticket gate still downgrades errors after shutdown")
    require("$shutdownResourcePattern" not in runner, "release gate still downgrades shutdown resource errors")

    if failures:
        for failure in failures:
            print(f"QA-001: FAIL - {failure}")
        return 1

    try:
        classify = _load_classifier(classifier_path)
        temp_root = Path(os.environ.get("ASHENOATH_QA_TEMP_ROOT", r"D:\Temp\AshenOath"))
        temp_root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="ashen-oath-qa001-", dir=str(temp_root)) as raw_dir:
            directory = Path(raw_dir)

            def fixture(name: str, contents: str) -> dict[str, object]:
                path = directory / name
                path.write_text(contents, encoding="utf-8")
                return classify(path)

            active_material = fixture(
                "active-material.log",
                'VERIFIER: PASS\nERROR: Parameter "material" is null\n',
            )
            shutdown_material = fixture(
                "shutdown-material.log",
                'VERIFIER: PASS\nVERIFIER_PHASE: SHUTDOWN\n'
                'ERROR: Parameter "material" is null\n',
            )
            active_after_shutdown = fixture(
                "active-after-shutdown.log",
                "VERIFIER: PASS\nVERIFIER_PHASE: SHUTDOWN\nERROR: gameplay failure\n",
            )
            leaked_rid = fixture(
                "leaked-rid.log",
                "VERIFIER: PASS\nVERIFIER_PHASE: SHUTDOWN\nRID allocations of type PhysicsServer3DShape are leaked at exit\n",
            )
            renderer_condition = fixture(
                "renderer-condition.log",
                "VERIFIER: PASS\nVERIFIER_PHASE: SHUTDOWN\nCondition render_list.size() > 0 is true\n",
            )
            parser_error = fixture("parser-error.log", "Parse Error: unexpected token\nVERIFIER: PASS\n")
            missing_resource = fixture("missing-resource.log", "VERIFIER: PASS\nFailed to load res://missing.tscn\n")
            assertion_error = fixture("assertion-error.log", "VERIFIER: PASS\nASSERTION FAILED: bridge blocked\n")
            timeout_error = fixture("timeout-error.log", "VERIFIER: PASS\nERROR: route timed out\n")
            missing_pass = fixture("missing-pass.log", "VERIFIER_PHASE: SHUTDOWN\n")

        require(active_material["status"] == "fail", "active material error was downgraded")
        require(shutdown_material["status"] == "fail", "shutdown material error was downgraded")
        require(active_after_shutdown["status"] == "fail", "active post-boundary error was downgraded")
        require(leaked_rid["status"] == "fail", "shutdown RID leak was downgraded")
        require(renderer_condition["status"] == "fail", "shutdown renderer condition was downgraded")
        require(parser_error["status"] == "fail", "parser error was downgraded")
        require(missing_resource["status"] == "fail", "missing resource was downgraded")
        require(assertion_error["status"] == "fail", "assertion error was downgraded")
        require(timeout_error["status"] == "fail", "timeout error was downgraded")
        require(missing_pass["status"] == "fail", "missing pass marker was accepted")
    except (OSError, RuntimeError, TypeError, KeyError) as error:
        failures.append(f"protocol fixture failed: {error}")

    if release_report_path.is_file():
        try:
            spec = importlib.util.spec_from_file_location("verify_release_report", release_report_path)
            if spec is None or spec.loader is None:
                raise RuntimeError("release-report validator cannot be loaded")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            valid = module.valid_owned_gate_result
            owned = {"process": {"owner": "release-runner", "exit_code": 0, "timed_out": False}}
            require(valid(owned), "owned successful gate was rejected")
            for process in (
                {"owner": "legacy-report", "exit_code": 0, "timed_out": False},
                {"owner": "release-runner", "exit_code": 7, "timed_out": False},
                {"owner": "release-runner", "exit_code": 0, "timed_out": True},
                {"owner": "release-runner", "exit_code": None, "timed_out": False},
            ):
                require(not valid({"process": process}), f"invalid process ownership was accepted: {process}")
        except (OSError, RuntimeError, AttributeError) as error:
            failures.append(f"strict report protocol fixture failed: {error}")

    process_test = project / "tools" / "test_qa_001_runner.ps1"
    require(process_test.is_file(), "release-runner process injection test is missing")
    if process_test.is_file():
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(process_test), "-Project", str(project)],
                capture_output=True,
                text=True,
                timeout=45,
                check=False,
            )
            require(result.returncode == 0 and "QA-001 PROCESS INJECTION: PASS" in result.stdout,
                    "release-runner process injection failed: " + (result.stdout + result.stderr)[-1200:])
        except (OSError, subprocess.TimeoutExpired) as error:
            failures.append(f"release-runner process injection could not finish: {error}")

    if failures:
        for failure in failures:
            print(f"QA-001: FAIL - {failure}")
        return 1
    print("QA-001: PASS - release and ticket diagnostic boundaries are fail-closed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
