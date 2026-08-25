#!/usr/bin/env python3
"""Truthful static gate for the single immediate Web boot surface."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []

    shell_path = project / "web_boot_shell.html"
    preset_path = project / "export_presets.cfg"
    game_path = project / "scripts" / "game.gd"
    shell = shell_path.read_text(encoding="utf-8") if shell_path.is_file() else ""
    preset = preset_path.read_text(encoding="utf-8") if preset_path.is_file() else ""
    game = game_path.read_text(encoding="utf-8") if game_path.is_file() else ""

    if not shell:
        errors.append("web boot shell is missing")
    for label, token in {
        "canvas": 'id="canvas"',
        "immediate first-paint marker": "ashen-oath-first-paint",
        "boot telemetry": "window.__ashenOathBoot",
        "automatic engine start": "window.setTimeout(begin, 0)",
        "engine start timestamp": "ashen-oath-engine-start",
        "engine ready timestamp": "ashen-oath-engine-ready",
        "engine start": "engine.startGame",
        "progress callback": "onProgress",
    }.items():
        if token not in shell:
            errors.append(f"boot shell missing {label}")

    if 'html/custom_html_shell="res://web_boot_shell.html"' not in preset:
        errors.append("Web preset does not use the custom boot shell")
    web_preset = re.search(r"\[preset\.0\](.*?)(?=\n\[preset\.\d+\]|\Z)", preset, re.S)
    web_text = web_preset.group(1) if web_preset else ""
    web_sources = "\n".join(
        line for line in web_text.splitlines()
        if line.startswith("include_filter=") or line.startswith("export_files=")
    )
    if "scripts/qa_browser_telemetry.gd" in web_sources:
        errors.append("production Web preset still includes QA telemetry")

    if 'if OS.has_feature("web"):' not in game:
        errors.append("game does not have a Web-specific launch path")
    else:
        web_branch = game.split('if OS.has_feature("web"):')[1].split("\n\telse:", 1)[0]
        if "hud.show_main_menu()" not in web_branch or "_on_launch_accepted()" not in web_branch:
            errors.append("Web boot still lacks direct menu launch and hidden prewarm")
        if "hud.show_launch_screen()" in web_branch:
            errors.append("Web boot still shows the duplicate in-engine launch gate")

    if errors:
        print("BOOT-003: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("BOOT-003: PASS (single Web launch path, immediate shell, timing telemetry, production QA exclusion)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
