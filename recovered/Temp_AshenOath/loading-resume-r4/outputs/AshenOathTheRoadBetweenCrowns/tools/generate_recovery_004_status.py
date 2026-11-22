#!/usr/bin/env python3
"""Generate the compact current Recovery-004 status from its registry."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ORDER = (
    "PERF-001", "WORLD-001", "WORLD-002", "PRES-001", "QA-002",
    "STORY-001", "AUDIO-001", "ACCESS-001", "CERT-001", "RELEASE-001",
)


def render(project: Path) -> str:
    registry = json.loads((project / "RECOVERY_004_ISSUE_REGISTRY.json").read_text(encoding="utf-8-sig"))
    program = registry["current_program"]
    acceptance = program["acceptance"]
    closure = program["closure"]
    accepted = sum(status == "accepted" for status in acceptance.values())
    lines = [
        "# Recovery-004 Current Closure Status",
        "",
        "> Generated from `RECOVERY_004_ISSUE_REGISTRY.json`. Historical result notes are evidence, not current direction.",
        "",
        f"- Accepted: **{accepted}/{len(acceptance)}**",
        f"- Remaining: **{len(acceptance) - accepted}**",
        "- Production: **frozen until RELEASE-001 live proof**",
        "- Critical path: **PERF-001 -> final world/presentation freeze -> QA-002 -> shared browser closure -> CERT-001 -> RELEASE-001**",
        "",
        "| Order | Ticket | Status | Blocker | Exact next action |",
        "|---:|---|---|---|---|",
    ]
    for index, ticket in enumerate(ORDER, 1):
        record = closure[ticket]
        blocker = str(record["current_blocker"]).replace("|", "\\|")
        next_action = str(record["next_action"]).replace("|", "\\|")
        lines.append(f"| {index} | `{ticket}` | `{acceptance[ticket]}` | {blocker} | {next_action} |")
    lines.extend((
        "",
        "## Closure Rule",
        "",
        "A ticket closes only when every acceptance cell is satisfied at its required evidence level. Partial, native-only, historical, or bypassed evidence remains preserved but cannot be promoted.",
        "",
    ))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    output = project / "RECOVERY_004_CURRENT_STATUS.md"
    expected = render(project)
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8-sig") != expected:
            print("RECOVERY STATUS: FAIL - compact status is stale")
            return 1
        print("RECOVERY STATUS: PASS")
        return 0
    if args.write:
        output.write_text(expected, encoding="utf-8")
        print(output)
        return 0
    print(expected, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
