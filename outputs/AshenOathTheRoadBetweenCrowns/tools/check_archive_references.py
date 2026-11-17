#!/usr/bin/env python3
"""Fail if an active script/workflow refers to a moved historical verifier."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
ARCHIVE = PROJECT / "docs/archive"


def main() -> int:
    manifest = ARCHIVE / "phase5-index.json"
    if not manifest.is_file():
        print("ARCHIVE FAIL: missing phase5-index.json", file=sys.stderr)
        return 1
    entries = json.loads(manifest.read_text(encoding="utf-8"))["moved"]
    stems = {Path(entry["original_path"]).stem for entry in entries}
    # Stems also catch invocations without an extension or with alternate separators.
    arguments = ["git", "grep", "-n", "-I", "-F", "-f", "-", "--",
                             "*.ps1", "*.py", "*.mjs", "*.js", "*.gd", "*.tscn", "*.yml", "*.yaml",
                             "CODEX_WORKFLOW.md", "DEPLOYMENT_POLICY.md", "DEPLOYMENT_WORKFLOW.md",
                             ":(exclude)" + ARCHIVE.relative_to(REPO).as_posix() + "/**"]
    errors = []
    found = False
    for cached in (False, True):
        invocation = arguments[:2] + (["--cached"] if cached else []) + arguments[2:]
        result = subprocess.run(invocation, cwd=REPO, input="\n".join(sorted(stems)), capture_output=True, text=True)
        if result.returncode not in (0, 1):
            errors.append(result.stderr)
        elif result.stdout:
            found = True
            errors.append("Active references to moved verifier paths:\n" + result.stdout)
    for entry in entries:
        original = (REPO / entry["original_path"]).resolve()
        destination = (REPO / entry["archived_path"]).resolve()
        try:
            original.relative_to(PROJECT)
            destination.relative_to(ARCHIVE)
        except ValueError:
            errors.append("Archive entry escapes the intended project/archive")
            continue
        if original.exists():
            errors.append("Original archive path still exists: " + entry["original_path"])
        if not destination.is_file() or hashlib.sha256(destination.read_bytes()).hexdigest() != entry["sha256"]:
            errors.append("Archive missing or changed: " + entry["archived_path"])
    for error in errors:
        print(error, file=sys.stderr)
    print(f"ARCHIVE {'FAIL' if errors else 'PASS'}: {len(entries)} byte-identical moves; "
          f"git grep active references (working tree + index): {'found' if found else '0'}")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
