#!/usr/bin/env python3
"""Classify Godot gate logs without hiding runtime or teardown errors."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TEARDOWN = re.compile(
    r'Parameter "material" is null|RID allocations .* leaked at exit|'
    r"Pages in use exist at exit|resources still in use at exit|"
    r"Buffer with GL ID .* leaked|shaders of type .* never freed|"
    r"ObjectDB instances leaked at exit|Leaked instance dependency|"
    r"did not call instance_notify_deleted|Orphan .* at exit|Condition .* is true",
    re.IGNORECASE,
)
FATAL = re.compile(
    r"SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|"
    r"ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed",
    re.IGNORECASE,
)
PASS = re.compile(r"\bPASS\b|Screenshot capture complete", re.IGNORECASE)
SHUTDOWN = re.compile(r"VERIFIER_PHASE:\s*SHUTDOWN", re.IGNORECASE)


def read_log_lines(path: Path) -> list[str]:
    """Read PowerShell-captured logs without losing their pass markers.

    PowerShell may write redirected native-process output as UTF-16LE with a
    BOM.  Decoding those bytes as UTF-8 leaves NUL characters between every
    visible character, which makes the regular-expression checks silently
    miss valid verifier results.  Prefer BOM-aware decoding and keep UTF-8 as
    the normal path for logs written directly by Python or Godot tooling.
    """
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16", errors="replace")
    elif raw.startswith(b"\xef\xbb\xbf"):
        text = raw.decode("utf-8-sig", errors="replace")
    else:
        text = raw.decode("utf-8", errors="replace")
    return text.splitlines()


def classify(path: Path) -> dict[str, object]:
    lines = read_log_lines(path)
    pass_index = max((index for index, line in enumerate(lines) if PASS.search(line)), default=-1)
    shutdown_index = next((index for index, line in enumerate(lines) if SHUTDOWN.search(line)), -1)
    warnings: list[str] = []
    failures: list[str] = []
    for index, line in enumerate(lines):
        if not FATAL.search(line) and not TEARDOWN.search(line):
            continue
        if re.search(r"CategoryInfo|FullyQualifiedErrorId", line):
            continue
        failures.append(line.strip())
    if pass_index < 0:
        failures.insert(0, "no verifier pass marker")
    return {
        "log": str(path),
        "status": "fail" if failures else "pass",
        "pass_marker_line": pass_index + 1 if pass_index >= 0 else None,
        "shutdown_phase_line": shutdown_index + 1 if shutdown_index >= 0 else None,
        "active_failures": failures,
        "shutdown_warnings": warnings,
    }


def load_run_logs(manifest_path: Path, project: Path, logs_dir: Path) -> list[Path]:
    """Resolve only the logs declared by the current authoritative run.

    A release directory is intentionally persistent, so globbing every ``*.log``
    can accidentally re-evaluate an older failed run.  The release runner writes
    a fresh manifest before invoking this verifier; direct callers must provide
    either that manifest or explicit ``--log`` arguments.
    """
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read run manifest: {error}") from error
    entries = payload.get("logs")
    if not isinstance(entries, list) or not entries:
        raise ValueError("run manifest has no declared logs")
    resolved: list[Path] = []
    for entry in entries:
        value = entry.get("path") if isinstance(entry, dict) else entry
        if not isinstance(value, str) or not value.strip():
            raise ValueError("run manifest contains an invalid log path")
        path = Path(value)
        if not path.is_absolute():
            path = logs_dir / path
        path = path.resolve()
        try:
            path.relative_to(logs_dir)
        except ValueError as error:
            raise ValueError(f"run manifest log escapes .release-gate: {value}") from error
        if path.is_file():
            resolved.append(path)
        else:
            raise ValueError(f"declared current-run log is missing: {path.name}")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--log", action="append", dest="logs", help="Specific log to classify.")
    parser.add_argument("--logs-dir", type=Path, help="Directory of logs to classify.")
    parser.add_argument(
        "--run-manifest",
        type=Path,
        help="Current-run JSON manifest containing the exact logs to classify.",
    )
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    directory = (args.logs_dir or project / ".release-gate").resolve()
    if args.logs and args.run_manifest:
        print("QA-005: FAIL - use --log or --run-manifest, not both")
        return 1
    if args.logs:
        logs = [Path(item).resolve() for item in args.logs]
    elif args.run_manifest:
        try:
            logs = load_run_logs(args.run_manifest.resolve(), project, directory)
        except ValueError as error:
            print(f"QA-005: FAIL - {error}")
            return 1
    else:
        default_manifest = directory / "qa_005_inputs.json"
        if not default_manifest.is_file():
            print(
                "QA-005: FAIL - no current-run manifest supplied; "
                "refusing to scan historical logs (use --run-manifest or --log)"
            )
            return 1
        try:
            logs = load_run_logs(default_manifest, project, directory)
        except ValueError as error:
            print(f"QA-005: FAIL - {error}")
            return 1
    logs = [path for path in logs if path.is_file()]
    if not logs:
        print("QA-005: FAIL - no gate logs supplied")
        return 1
    results = [classify(path) for path in logs]
    failures = [result for result in results if result["status"] == "fail"]
    report = {"schema_version": 1, "status": "fail" if failures else "pass", "results": results}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for result in results:
        warning_count = len(result["shutdown_warnings"])
        print(f"QA-005: {str(result['status']).upper()} - {Path(str(result['log'])).name} ({warning_count} shutdown warning(s))")
        for failure in result["active_failures"][:3]:
            print(f"QA-005: ACTIVE - {failure}")
    if failures:
        return 1
    print(f"QA-005: PASS - classified {len(results)} gate log(s); active errors are release-blocking")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
