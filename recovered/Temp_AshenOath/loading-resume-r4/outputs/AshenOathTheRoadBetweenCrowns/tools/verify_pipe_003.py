#!/usr/bin/env python3
"""Verify the deterministic character/monster processing boundary."""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    failures: list[str] = []
    required = [
        ROOT / "tools" / "character_asset_pipeline.py",
        ROOT / "tools" / "register_soul_asset.py",
        ROOT / "tools" / "build_character_real_assets.py",
        ROOT / "soul_asset_pack_manifest.json",
        ROOT / "soul_character_role_manifest.json",
    ]
    for path in required:
        if not path.is_file():
            failures.append(f"missing pipeline contract: {path.name}")
    for path in required[:3]:
        if path.is_file():
            try:
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            except SyntaxError as exc:
                failures.append(f"parser error in {path.name}: {exc}")
    try:
        packs = json.loads((ROOT / "soul_asset_pack_manifest.json").read_text(encoding="utf-8"))
        roles = json.loads((ROOT / "soul_character_role_manifest.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        failures.append(f"manifest parse error: {exc}")
        packs = {}
        roles = {}
    if packs.get("schema_version", 0) < 2:
        failures.append("asset pack manifest is not version 2")
    if "excluded_source_patterns" not in packs.get("runtime_rules", {}):
        failures.append("asset pack manifest has no excluded source patterns")
    role_rows = roles.get("roles", {})
    if len(role_rows) < 9:
        failures.append("role manifest does not cover the nine soul-rebuild role contracts")
    approved = [role_id for role_id, role in role_rows.items() if isinstance(role, dict) and role.get("approved")]
    expected_approved = ["kael", "sister_anwen", "villager", "guard", "ranger"]
    if approved != expected_approved:
        failures.append(f"Milestone C approved runtime roles differ from the manifest contract: {approved}")
    for role_id, role in role_rows.items():
        if not isinstance(role, dict):
            continue
        if role.get("approved"):
            if role.get("export_eligible") is not True or not role.get("runtime_artifacts"):
                failures.append(f"approved role {role_id} lacks export/artifact contract")
        else:
            if role.get("export_eligible") is not False or not str(role.get("blocked_reason", "")).strip():
                failures.append(f"pending role {role_id} lacks explicit blocked state")
    builder = (ROOT / "tools" / "build_character_real_assets.py").read_text(encoding="utf-8") if (ROOT / "tools" / "build_character_real_assets.py").is_file() else ""
    for token in ("export_skins=True", "export_animations=True", "export_apply=False"):
        if token not in builder:
            failures.append(f"Blender fallback builder missing deterministic export setting: {token}")
    register = (ROOT / "tools" / "register_soul_asset.py").read_text(encoding="utf-8") if (ROOT / "tools" / "register_soul_asset.py").is_file() else ""
    for token in ("runtime_artifacts", "export_eligible", "source-url"):
        if token not in register:
            failures.append(f"registration tool missing {token}")
    report = {"ticket": "PIPE-003", "status": "fail" if failures else "pass", "approved_roles": approved, "failures": failures}
    report_path = ROOT / ".release-gate" / "pipe_003.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        print("PIPE-003 VERIFIER: FAIL")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("PIPE-003 VERIFIER: PASS - deterministic conversion and registration boundary")
    return 0


if __name__ == "__main__":
    sys.exit(main())
