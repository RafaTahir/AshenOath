#!/usr/bin/env python3
"""Validate the curated runtime library and its Web export contract."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "curated_runtime_assets.json"
PRESET = ROOT / "export_presets.cfg"
DATABASE = ROOT / "scripts" / "asset_database.gd"
REPORT = ROOT / ".release-gate" / "asset_001_report.json"

EXPECTED_ROLES = {
    "characters": {
        "player_kael", "sister_anwen", "mira_herbalist", "rook_smuggler",
        "widow_elna", "blacksmith_tor", "generic_villager_01",
        "generic_villager_02", "lord_edric", "castle_guard", "road_ranger",
    },
    "enemies": {
        "ghoulkin", "ghoulkin_skeleton", "bog_wretch", "gravebound_knight",
        "wychwood_stalker", "white_hart_avatar", "bandit",
    },
    "environment": {
        "greyfen_house", "greyfen_door_facade", "greyfen_window_facade",
        "greyfen_roof", "greyfen_chimney", "tavern", "shrine", "blacksmith_shop",
        "cemetery_gravestone", "forest_tree", "forest_rock", "forest_bush",
        "ruins_wall", "ruins_pillar", "barrel", "crate", "cart", "fence", "torch",
    },
    "audio": {"ui_click"},
    "ui": {"button", "panel"},
}


def local_path(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"not a res:// path: {resource_path}")
    return ROOT / resource_path.removeprefix("res://")


def main() -> int:
    failures: list[str] = []
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    preset = PRESET.read_text(encoding="utf-8")
    database = DATABASE.read_text(encoding="utf-8")
    roles = manifest.get("roles", {})

    if manifest.get("ticket") != "ASSET-001":
        failures.append("manifest ticket is not ASSET-001")
    if "CURATED_RUNTIME_PATH" not in database or "asset_role_mapping_suggested.json" in database:
        failures.append("AssetDatabase is not exclusively using the curated runtime manifest")

    unique_files: dict[str, dict[str, object]] = {}
    for group, required_roles in EXPECTED_ROLES.items():
        actual = set(roles.get(group, {}))
        missing = sorted(required_roles - actual)
        extra = sorted(actual - required_roles)
        if missing:
            failures.append(f"{group} is missing roles: {', '.join(missing)}")
        if extra:
            failures.append(f"{group} contains unreviewed roles: {', '.join(extra)}")
        for role, entry in roles.get(group, {}).items():
            status = str(entry.get("status", ""))
            path = str(entry.get("path", ""))
            license_name = str(entry.get("license", ""))
            license_file = str(entry.get("license_file", ""))
            if status in {"", "suggested", "placeholder"}:
                failures.append(f"{group}/{role} has prohibited status: {status!r}")
            if not path or not local_path(path).is_file():
                failures.append(f"{group}/{role} asset is missing: {path}")
                continue
            if license_name != "CC0 1.0":
                failures.append(f"{group}/{role} is not verified CC0: {license_name!r}")
            if not license_file or not local_path(license_file).is_file():
                failures.append(f"{group}/{role} license record is missing: {license_file}")
            payload = local_path(path).read_bytes()
            unique_files[path] = {
                "bytes": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
            export_token = path.removeprefix("res://")
            if export_token not in preset:
                failures.append(f"curated asset is absent from Web preset: {path}")

    quarantined = manifest.get("quarantine", [])
    if len(quarantined) < 3:
        failures.append("quarantine does not contain the remaining rejected ART-001 candidates")
    for entry in quarantined:
        path = str(entry.get("path", ""))
        if not entry.get("reason"):
            failures.append(f"quarantine reason is missing: {path}")
        if path.removeprefix("res://") in preset:
            failures.append(f"quarantined asset remains in Web preset: {path}")

    for forbidden in ("asset_manifest.json", "asset_role_mapping_suggested.json"):
        if forbidden in preset:
            failures.append(f"broad legacy manifest remains exported: {forbidden}")
    if "curated_runtime_assets.json" not in preset:
        failures.append("curated runtime manifest is absent from Web preset")

    report = {
        "ticket": "ASSET-001",
        "status": "fail" if failures else "pass",
        "role_count": sum(len(group) for group in roles.values()),
        "unique_asset_count": len(unique_files),
        "selected_source_bytes": sum(int(item["bytes"]) for item in unique_files.values()),
        "quarantined_count": len(quarantined),
        "files": unique_files,
        "failures": failures,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        for failure in failures:
            print(f"ASSET-001 ERROR: {failure}")
        print(f"ASSET-001 FILE VERIFIER: FAIL ({len(failures)})")
        return 1
    mib = report["selected_source_bytes"] / (1024 * 1024)
    print(
        "ASSET-001 FILE VERIFIER: PASS "
        f"({report['role_count']} roles, {len(unique_files)} unique files, {mib:.2f} MiB source payload)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
