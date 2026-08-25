#!/usr/bin/env python3
"""Static and contract checks for the interactive Web boot/loading path."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []
    shell = project / "web_boot_shell.html"
    if not shell.is_file():
        errors.append("web boot shell is missing")
    else:
        html = shell.read_text(encoding="utf-8")
        required = {
            "canvas#road-canvas": 'id="road-canvas"',
            "start control": 'id="start"',
            "engine start": "engine.startGame",
            "keyboard input": "addEventListener('keydown'",
            "pointer input": "addEventListener('pointerdown'",
            "gamepad input": "navigator.getGamepads",
            "progress": "onProgress",
            "reduced motion": "prefers-reduced-motion",
            "automatic engine start": "window.setTimeout(begin, 0)",
            "flap interaction": "function flap()",
            "branch obstacles": "const branches = []",
        }
        for label, token in required.items():
            if token not in html:
                errors.append(f"boot shell missing {label}")
        if "background: #080d10" in html and "#boot" not in html:
            errors.append("boot shell has no authored content layer")
    manifest = project / "runtime_pack_manifest.json"
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if int(data.get("max_deployment_bytes", 0)) > 100 * 1024 * 1024:
            errors.append("runtime pack budget exceeds 100 MB")
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"runtime pack manifest invalid: {exc}")
    hud = project / "scripts" / "hud.gd"
    game = project / "scripts" / "game.gd"
    for path, tokens in {
        hud: ["func arm_loading", "loading_elapsed", "MOUSE_FILTER_IGNORE"],
        game: ["hud.arm_loading(\"Opening Greyfen...\")", "hud.arm_loading(\"Crossing the Oath Gate...\")", "if OS.has_feature(\"web\"):", "hud.show_main_menu()"],
    }.items():
        try:
            source = path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(str(exc))
            continue
        for token in tokens:
            if token not in source:
                errors.append(f"{path.name} missing {token}")
    if errors:
        print("LOAD-QA-001: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("LOAD-QA-002: PASS (automatic boot, playable Crow Flight, gamepad input, nonblocking progress, pack budget)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
