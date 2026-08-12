#!/usr/bin/env python3
"""Classify Godot gate logs without hiding active runtime errors.

The release runner already records shutdown diagnostics as warnings when they
occur after a verifier's pass marker. This standalone check makes that rule
auditable and fails logs that contain an active parser, resource, renderer, or
verifier failure before a pass marker.
"""

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
    r"did not call instance_notify_deleted",
    re.IGNORECASE,
)
FATAL = re.compile(
    r"SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|"
    r"ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed",
    re.IGNORECASE,
)
PASS = re.compile(r"\bPASS\b|Screenshot capture complete", re.IGNORECASE)


def classify(path: Path) -> dict[str, object]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    pass_index = max((index for index, line in enumerate(lines) if PASS.search(line)), default=-1)
    warnings: list[str] = []
    failures: list[str] = []
    for index, line in enumerate(lines):
        if not FATAL.search(line):
            continue
        if re.search(r"CategoryInfo|FullyQualifiedErrorId", line):
            continue
        if TEARDOWN.search(line) and pass_index >= 0 and index > pass_index:
            warnings.append(line.strip())
        else:
            failures.append(line.strip())
    if pass_index < 0:
        failures.insert(0, "no verifier pass marker")
    return {
        "log": str(path),
        "status": "fail" if failures else "pass",
        "pass_marker_line": pass_index + 1 if pass_index >= 0 else None,
        "active_failures": failures,
        "shutdown_warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--log", action="append", dest="logs", help="Specific log to classify.")
    parser.add_argument("--logs-dir", type=Path, help="Directory of logs to classify.")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    if args.logs:
        logs = [Path(item).resolve() for item in args.logs]
    else:
        directory = (args.logs_dir or project / ".release-gate").resolve()
        logs = sorted(directory.glob("*.log"))
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
