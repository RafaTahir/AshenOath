#!/usr/bin/env python3
"""Contract gate for the small, input-responsive Crow Flight wait activity."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    shell_path = args.project.resolve() / "web_boot_shell.html"
    errors: list[str] = []
    if not shell_path.is_file():
        errors.append("Crow Flight shell is missing")
        source = ""
    else:
        source = shell_path.read_text(encoding="utf-8")

    required = {
        "canvas game": 'id="road-canvas"',
        "crow physics": "crowVelocity +=",
        "branch obstacles": "const branches = []",
        "embers and score": "bootMetrics.crow_score",
        "keyboard flap": "flap('keyboard')",
        "pointer/touch flap": "flap('pointer')",
        "button flap": "flap('button')",
        "gamepad flap": "flap('gamepad')",
        "gamepad edge detection": "!gamepadPressed",
        "reduced-motion fallback": "prefers-reduced-motion",
        "accessible status": 'aria-live="polite"',
        "boot handoff": "setBootState('ready'",
    }
    for label, token in required.items():
        if token not in source:
            errors.append(f"Crow Flight missing {label}")
    if 'start.textContent = \'Enter the Road\'' in source:
        errors.append("Crow Flight still presents an explicit launch gate")
    if "window.setTimeout(begin, 0)" not in source:
        errors.append("Crow Flight does not hand off to the engine automatically")

    if errors:
        print("LOADGAME-002: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("LOADGAME-002: PASS (keyboard, pointer, touch, gamepad, reduced motion, immediate handoff)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
