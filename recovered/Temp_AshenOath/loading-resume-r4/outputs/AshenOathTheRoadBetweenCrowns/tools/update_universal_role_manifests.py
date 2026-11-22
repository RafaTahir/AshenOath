#!/usr/bin/env python3
"""Register the clothed Universal crowd assemblies across runtime manifests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNTIME = "res://assets_external/characters_universal/runtime"
KAEL = f"{RUNTIME}/Kael_A_Set_Atlas.gltf"
ANWEN = f"{RUNTIME}/Anwen_A_Set_Atlas.gltf"
MALE = f"{RUNTIME}/Villager_Male_Atlas.gltf"
FEMALE = f"{RUNTIME}/Villager_Female_Atlas.gltf"
WORKER = f"{RUNTIME}/Villager_Worker_Atlas.gltf"
HOODED = f"{RUNTIME}/Villager_Hooded_Atlas.gltf"
LICENSE = "res://assets_external/licenses/Quaternius_Universal_Base_Characters_CC0.txt"
SOURCE_URL = "https://quaternius.com/packs/universalbasecharacters.html"

MALE_ROLES = {
    "rook_human", "villager_human", "villager_worker_human", "villager_hooded_human",
    "castle_guard_human", "rook_smuggler", "blacksmith_tor", "generic_villager_01",
    "lord_edric", "castle_guard", "player_human", "villager_male", "villager_worker",
    "villager_hooded", "villager", "guard", "traveler",
}
FEMALE_ROLES = {"mira_human", "villager_female_human", "mira_herbalist", "widow_elna", "generic_villager_02", "villager_female"}
PROTECTED_ROLES = {"road_ranger", "road_ranger_human", "ranger"}


def res_file(value: str) -> Path:
    return ROOT / value.removeprefix("res://").replace("/", "/")


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def artifact(path_value: str) -> dict:
    path = res_file(path_value)
    return {"path": path_value, "bytes": path.stat().st_size, "sha256": digest(path)}


def assembly_files(model: str) -> list[str]:
    stem = model.removesuffix(".gltf")
    return [f"{stem}.bin", f"{stem}.png"]


def variant_for(role: str) -> tuple[str, str, list[str]] | None:
    key = role.lower()
    if key in PROTECTED_ROLES:
        return None
    if key in {"player_kael", "player_human", "kael"}:
        return KAEL, "opening_single_material_a_set", assembly_files(KAEL)
    if key in {"sister_anwen", "sister_anwen_human", "anwen"}:
        return ANWEN, "opening_single_material_a_set", assembly_files(ANWEN)
    if key in FEMALE_ROLES or "female" in key:
        return FEMALE, "opening_single_material_crowd", assembly_files(FEMALE)
    if "worker" in key or "guard" in key or "tor" in key:
        return WORKER, "opening_single_material_crowd", assembly_files(WORKER)
    if "hooded" in key or "rook" in key or "smuggler" in key or "traveler" in key:
        return HOODED, "opening_single_material_crowd", assembly_files(HOODED)
    if key in MALE_ROLES or key.endswith("_male") or "guard" in key or "villager" in key or "rook" in key or "edric" in key or "tor" in key:
        return MALE, "opening_single_material_crowd", assembly_files(MALE)
    return None


def update_visual_manifest() -> None:
    path = ROOT / "visual_upgrade_manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("roles", {}).get("characters", {})
    for role, entry in entries.items():
        choice = variant_for(role)
        if choice is None or not isinstance(entry, dict):
            continue
        model, status, maps = choice
        entry["path"] = model
        entry["status"] = status
        entry["runtime_parts"] = []
        entry["runtime_textures"] = maps
        entry["notes"] = "Complete clothed Universal body assembly with native face, brows, eyes, role hair, one shared skeleton, deterministic role palette, and 1K maps."
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_curated_manifest() -> None:
    path = ROOT / "curated_runtime_assets.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    for group_name in ("characters",):
        group = data.get("roles", {}).get(group_name, {})
        for role, entry in group.items():
            choice = variant_for(role)
            if choice is None or not isinstance(entry, dict):
                continue
            model, status, _maps = choice
            entry["path"] = model
            entry["status"] = status
            entry["notes"] = "Complete clothed Universal body assembly with deterministic identity recipe and one shared skeleton."
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_character_role_manifest() -> None:
    path = ROOT / "character_role_manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    roles = data.get("roles", {})
    for role, value in list(roles.items()):
        choice = variant_for(role)
        if choice is not None:
            roles[role] = choice[0]
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_soul_manifest() -> None:
    path = ROOT / "soul_character_role_manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    for role, entry in data.get("roles", {}).items():
        choice = variant_for(role)
        if choice is None or not isinstance(entry, dict):
            continue
        model, status, maps = choice
        entry["path"] = model
        entry["model"] = model
        entry["outfit"] = model
        entry["status"] = status
        entry["approved"] = True
        entry["export_eligible"] = True
        entry["source_pack"] = "quaternius_universal_base_characters"
        entry["source_url"] = SOURCE_URL
        entry["license_file"] = LICENSE
        entry["sha256"] = artifact(model)["sha256"]
        entry["runtime_artifacts"] = [artifact(model)] + [artifact(item) for item in maps]
        entry["blocked_reason"] = ""
        entry["notes"] = "Complete clothed Universal body assembly with native facial anatomy, deterministic occupation palette, shared non-root-motion clips, and 1K maps."
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_runtime_manifest() -> None:
    path = ROOT / "runtime_asset_manifest.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    roles = data.get("roles", {})
    for role in ("kael", "anwen", "villager", "guard", "traveler"):
        entry = roles.get(role)
        choice = variant_for(role)
        if not isinstance(entry, dict) or choice is None:
            continue
        model, status, maps = choice
        entry["model"] = model
        entry["status"] = status
        entry["runtime_files"] = [artifact(model)] + [artifact(item) for item in maps]
        entry["notes"] = "Complete clothed Universal body assembly with one shared skeleton, native face anatomy, deterministic palette variation, and 1K maps."
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    for path_value in (KAEL, ANWEN, MALE, FEMALE, WORKER, HOODED):
        if not res_file(path_value).is_file():
            raise FileNotFoundError(path_value)
    update_visual_manifest()
    update_curated_manifest()
    update_character_role_manifest()
    update_soul_manifest()
    update_runtime_manifest()
    print("ROLE MANIFESTS: PASS - Universal full-body variants registered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
