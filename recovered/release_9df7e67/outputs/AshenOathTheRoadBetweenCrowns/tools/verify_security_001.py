#!/usr/bin/env python3
"""Verify that QA browser controls are isolated from the production Web build."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    project_settings = (project / "project.godot").read_text(encoding="utf-8")
    presets = (project / "export_presets.cfg").read_text(encoding="utf-8")
    game = (project / "scripts" / "game.gd").read_text(encoding="utf-8")
    telemetry = (project / "scripts" / "qa_browser_telemetry.gd").read_text(encoding="utf-8")

    require("[autoload]" not in project_settings, "production project still declares an autoload section")
    def preset_section(preset_id: int) -> str:
        match = re.search(
            rf"(?ms)^\[preset\.{preset_id}\]\r?\n(.*?)(?=^\[preset\.\d+(?:\.options)?\]\s*$|\Z)",
            presets,
        )
        return match.group(0) if match else ""

    production_section = preset_section(0)
    production_export = re.search(r"(?m)^export_files=(.*)$", production_section)
    production_include = re.search(r"(?m)^include_filter=(.*)$", production_section)
    production_sources = " ".join(
        [production_export.group(1) if production_export else "", production_include.group(1) if production_include else ""]
    )
    require("qa_browser_telemetry.gd" not in production_sources, "QA telemetry is present in the production export sources")
    require('name="Web Browser"' in production_section, "production Web Browser preset is missing")
    qa_section = preset_section(1)
    require(bool(qa_section), "disposable Web QA Browser preset is missing")
    require('custom_features="ashenoath_qa"' in qa_section, "QA preset lacks the ash enoath feature gate")
    qa_export = re.search(r"(?m)^export_files=(.*)$", qa_section)
    qa_export_sources = qa_export.group(1) if qa_export else ""
    require(
        '"res://scenes/main.tscn"' in qa_export_sources
        and '"res://scripts/qa_browser_telemetry.gd"' in qa_export_sources,
        "QA preset does not explicitly contain the telemetry entrypoint",
    )
    require('OS.has_feature("ashenoath_qa")' in game, "runtime QA attachment is not feature-gated")
    require('JavaScriptBridge.eval' in telemetry, "QA telemetry has no browser bridge")
    require("has_feature(\"web\")" in telemetry and "has_feature(\"ashenoath_qa\")" in telemetry,
            "QA telemetry does not require both Web and ash enoath QA features")
    require("window.location.search).get('qa')" in telemetry, "QA telemetry is not query-gated")
    require(not re.search(r"autoload/.+qa_browser_telemetry", project_settings, re.IGNORECASE),
            "QA telemetry appears in project autoload settings")

    if failures:
        for failure in failures:
            print(f"SECURITY-001: FAIL - {failure}")
        return 1
    print("SECURITY-001: PASS - production Web has no QA autoload or telemetry surface")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
