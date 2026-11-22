#!/usr/bin/env python3
"""Register the complete, user-authorized Spectral Bestiary without art approval.

Default mode only describes the pending changes. --write requires all ten built
models and their current hashes, then updates the live role aliases and explicit
normalization/provenance records. Original source artifacts remain untouched.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from verify_spectral_source_contract import Document, read_contract_json

PROJECT = Path(__file__).resolve().parents[1]
PACK_ID = "ashenoath_spectral_bestiary"
RECEIPT = "assets_external/enemies/spectral/SPECTRAL_BESTIARY_BUILD.json"
BASELINE = ".release-gate/spectral-monsters/baseline.json"
SOURCE_BASELINE = ".release-gate/spectral-monsters/source_baseline.json"
PACK_URL = "https://github.com/RafaTahir/AshenOath"
AUTHORIZATION_KIND = "user_requested_creation_and_in_game_application"
AUTHORIZATION_REQUEST = "Build for me asset packs for monsters that are more the witcher-esque so we can use it instead of the monster assets we have now. Then apply them straight into the game"
EXPECTED = {
    "ghoulkin": "ghoulkin_creature", "wychwood_stalker": "wychwood_stalker_creature",
    "wychwood_raider": "wychwood_raider_creature", "wychwood_brute": "wychwood_brute_creature",
    "bog_wretch": "bog_wretch_creature", "gravebound_knight": "gravebound_knight_creature",
    "bell_eater": "bell_eater_boss", "rootbound_colossus": "rootbound_colossus_boss",
    "ashwing": "ashwing_boss", "white_hart_avatar": "white_hart_boss",
}
UNIVERSAL = ("quaternius_universal_base_characters", "https://quaternius.com/packs/universalbasecharacters.html", "res://assets_external/licenses/Quaternius_Universal_Base_Characters_CC0.txt")
ULTIMATE = ("quaternius_ultimate_monsters", "https://quaternius.com/packs/ultimatemonsters.html", "res://assets_external/licenses/Quaternius_Ultimate_Monsters_Mirror_CC0.txt")
ANIMATED = ("quaternius_lowpoly_animated_monsters", "https://opengameart.org/content/animated-monsters-pack", "res://assets_external/licenses/quaternius_lowpoly_animated_monsters/License.txt")
ANIMALS = ("quaternius_ultimate_animated_animals", "https://quaternius.com/packs/ultimateanimatedanimals.html", "res://assets_external/licenses/Quaternius_Ultimate_Animals_CC0.txt")
SOURCE_INFO = {enemy: UNIVERSAL if enemy in {"ghoulkin", "bog_wretch", "bell_eater"} else ANIMATED if enemy in {"gravebound_knight", "ashwing"} else ANIMALS if enemy == "white_hart_avatar" else ULTIMATE for enemy in EXPECTED}


def load(name: str) -> dict:
    return json.loads((PROJECT / name).read_text(encoding="utf-8"))


def path(value: str) -> Path:
    if not value.startswith("res://"):
        raise ValueError("Expected project resource path: " + value)
    result = (PROJECT / value.removeprefix("res://")).resolve()
    if not result.is_relative_to(PROJECT.resolve()):
        raise ValueError("Resource escapes the project: " + value)
    return result


def artifact(file: Path) -> dict:
    raw = file.read_bytes()
    return {"path": "res://" + file.relative_to(PROJECT).as_posix(), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def artifacts(record: dict) -> list[dict]:
    model = path(record["path"])
    document = json.loads(model.read_text())
    files = {model}
    for section in ("buffers", "images"):
        for entry in document.get(section, []):
            uri = entry.get("uri", "")
            if uri and not uri.startswith("data:"):
                file = (model.parent / uri).resolve()
                if not file.is_relative_to(PROJECT.resolve()):
                    raise ValueError("Model dependency escapes project: " + uri)
                files.add(file)
    # The authoring receipt must match every named output before registration.
    for name, expected in record.get("files", {}).items():
        file = model.parent / name
        actual = artifact(file)
        if actual["bytes"] != expected["bytes"] or actual["sha256"] != expected["sha256"]:
            raise ValueError("Stale authoring receipt: " + str(file.relative_to(PROJECT)))
        files.add(file)
    return [artifact(file) for file in sorted(files)]


def actual_root_height(model: Path) -> float:
    """Measure exported positions through node frames, independent of metadata."""
    document = Document(model)
    minimum, maximum = math.inf, -math.inf
    for index, node in enumerate(document.data.get("nodes", [])):
        if "mesh" not in node:
            continue
        frame = document.world(index)
        for primitive in document.data["meshes"][node["mesh"]]["primitives"]:
            for x, y, z in document.accessor(primitive["attributes"]["POSITION"])[0]:
                height = frame[1] * x + frame[5] * y + frame[9] * z + frame[13]
                minimum, maximum = min(minimum, height), max(maximum, height)
    if not math.isfinite(minimum) or not math.isfinite(maximum) or maximum <= minimum:
        raise ValueError("Model has no finite measured root-space height: " + str(model))
    return maximum - minimum


def aliases(enemy: str, role: str) -> list[str]:
    values = [role, enemy]
    if enemy == "ashwing": values.append("ashwing_creature")
    return list(dict.fromkeys(values))


def runtime_key(enemy: str) -> str:
    return "ghoulkin" if enemy.startswith("wychwood_") else "white_hart" if enemy == "white_hart_avatar" else enemy


def pending_fields() -> dict:
    return {"status": "spectral_inclusion_authorized_visual_review_pending", "approved": False,
        "visual_reviewed": False, "visual_review": "pending_user_review", "inclusion_authorized": True,
        "authorization_kind": AUTHORIZATION_KIND, "authorization_request": AUTHORIZATION_REQUEST,
        "runtime_acceptance": "requires_current_checks"}


def plan() -> tuple[dict[str, dict], dict]:
    receipt = load(RECEIPT)
    baseline = read_contract_json(PROJECT / BASELINE, 'runtime')
    source_baseline = read_contract_json(PROJECT / SOURCE_BASELINE, 'source')
    records = {entry["enemy_id"]: entry for entry in receipt["assets"]}
    if set(records) != set(EXPECTED):
        raise ValueError("Complete ten-monster build required; missing=" + str(sorted(set(EXPECTED) - set(records))) + "; unexpected=" + str(sorted(set(records) - set(EXPECTED))))
    for enemy, record in records.items():
        if record["role"] != EXPECTED[enemy] or "/spectral/" not in record["path"]:
            raise ValueError("Unexpected role/output for " + enemy)
        # Immutable sources and all dependencies are still the captured originals.
        for relative, expected in source_baseline["roles"][enemy]["snapshot"]["files"].items():
            actual = artifact(PROJECT / relative)
            if actual["bytes"] != expected["bytes"] or actual["sha256"] != expected["sha256"]:
                raise ValueError("Retained source changed: " + relative)
    model_artifacts = {enemy: artifacts(record) for enemy, record in records.items()}
    output = {name: load(name) for name in ["visual_upgrade_manifest.json", "curated_runtime_assets.json", "runtime_asset_manifest.json", "soul_asset_pack_manifest.json", "soul_character_role_manifest.json", "monster_family_manifest.json"]}
    profiles = {"version": 1, "pack": PACK_ID, "normalization_policy": "immutable_source_frame_keeps_rig_scale_and_contact_positions; actual_geometry_is_measured_separately", "assets": {}}
    runtime, soul = output["runtime_asset_manifest.json"], output["soul_character_role_manifest.json"]
    for enemy, role in EXPECTED.items():
        record, original = records[enemy], baseline["actors"][enemy]
        source_pack, source_url, license_file = SOURCE_INFO[enemy]
        license_record = artifact(path(license_file))
        source = original["source"]
        provenance = {"source": source, "source_sha256": artifact(path(source))["sha256"],
            "source_pack": source_pack, "source_url": source_url, "license_file": license_file,
            "license_sha256": license_record["sha256"], "build_ledger": "res://" + RECEIPT,
            "authored_changes": record.get("authored_changes", []), "rig_and_animation_contract": record.get("rig_and_animation_payloads", "checked_by_source_and_runtime_verifiers")}
        palette = record.get("spectral_color")
        if not isinstance(palette, list) or len(palette) != 3:
            raise ValueError("Build receipt missing spectral_color for " + enemy)
        raw_height = actual_root_height(path(record["path"]))
        profiles["assets"][record["path"]] = {"enemy_id": enemy, "source": source,
            "normalization_bounds": original["source_bounds"], "palette": palette,
            "raw_height": raw_height, "max_visual_displacement": 0.03}
        for filename in ["visual_upgrade_manifest.json", "curated_runtime_assets.json"]:
            enemies = output[filename]["roles"].setdefault("enemies", {})
            seed = copy.deepcopy(enemies.get(role, enemies.get(enemy, {})))
            for alias in aliases(enemy, role):
                value = copy.deepcopy(enemies.get(alias, seed))
                value.update(pending_fields())
                value.update({"path": record["path"], "source": "AshenOath Spectral Bestiary; retained licensed rig", "source_pack": PACK_ID,
                    "source_url": source_url, "license": "CC0 1.0 retained source; project-owned authored additions", "license_file": license_file,
                    "runtime_textures": [a["path"] for a in model_artifacts[enemy] if a["path"] != record["path"]],
                    "provenance": provenance, "notes": "User authorized creation and application in the game. Visual, listening and performance approval are not implied."})
                value.pop("visual_evidence", None)
                enemies[alias] = value
        key = runtime_key(enemy)
        if enemy.startswith("wychwood_"):
            continue  # Existing alias table intentionally uses the Ghoulkin group.
        entry = runtime["roles"].setdefault(key, {})
        entry.update(pending_fields())
        entry.update({"display_name": original["definition"]["name"], "family": entry.get("family", "monster"), "source_pack": PACK_ID,
            "export_eligible": True, "fallback_mode": "none", "model": record["path"], "source_url": source_url,
            "license_file": license_file, "runtime_files": model_artifacts[enemy], "provenance": provenance,
            "blocked_reason": "", "notes": "Inclusion authorized explicitly by the user; pending visual review is recorded separately from runtime eligibility."})
        entry.pop("visual_evidence", None)
        if enemy == "ghoulkin":
            entry["runtime_files"] = [item for member in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"] for item in model_artifacts[member]]
            entry["additional_license_files"] = [ULTIMATE[2]]
            entry["model_family"] = "Spectral Pallbearer, Thorn Veil, Oathless Shade and Hollow Crown; retained independent rigs"
        soul_entry = soul["roles"].setdefault(key, {"family": "animal" if enemy == "white_hart_avatar" else "monster", "triangle_budget": 24000 if enemy in {"bell_eater", "rootbound_colossus", "ashwing", "white_hart_avatar"} else 20000 if enemy == "gravebound_knight" else 18000,
            "texture_budget": 1024, "required_clips": ["idle", "walk", "run", "attack", "hit", "death"], "equipment_sockets": []})
        soul_entry.update(pending_fields())
        soul_entry.update({"source_pack": PACK_ID, "path": record["path"], "model": record["path"], "source_url": source_url,
            "license_file": license_file, "sha256": artifact(path(record["path"]))["sha256"], "runtime_artifacts": model_artifacts[enemy],
            "export_eligible": False, "current_fallback": source, "provenance": provenance,
            "blocked_reason": "Visual review remains pending; explicit user authorization separately permits this candidate in the current game."})
    # Group aliases need provenance for each independent source, not only base Ghoulkin.
    runtime["roles"]["ghoulkin"]["family_members"] = [{"enemy_id": enemy, "role": EXPECTED[enemy], "model": records[enemy]["path"], "source": baseline["actors"][enemy]["source"]} for enemy in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]]
    family = output["monster_family_manifest.json"]
    family["version"] = max(4, int(family.get("version", 0)))
    family["ticket"] = "SPECTRAL-BESTIARY"
    for enemy, role in EXPECTED.items():
        original = baseline["actors"][enemy]
        entry = family["families"].setdefault(enemy, {})
        entry.update({"visual_role": role, "runtime_source_role": role, "source_path": records[enemy]["path"], "skin": "authored_spectral_body_and_skinned_veils",
            "profile": entry.get("profile", original["definition"].get("behavior_profile", "retained")),
            "height": entry.get("height", original["role_spec"]["height"]), "source_rig_bones": records[enemy]["skins"], "visual_review": "pending_user_review"})
    family["shared_contract"]["source_policy"] = "original_spectral_derivatives_preserve_each_retained_rig_animation_and_contact_contract"
    all_artifacts = list({item["path"]: item for items in model_artifacts.values() for item in items}.values())
    pack = {"id": PACK_ID, "version": "1", "url": PACK_URL, "dependencies": sorted({SOURCE_INFO[enemy][0] for enemy in EXPECTED}),
        "preload_priority": 40, "license": "CC0 1.0 retained sources; project-owned authored additions", "authored_additions_license": "Project-owned; this registration does not make a public-domain dedication.",
        "status": "inclusion_authorized_visual_review_pending", "inclusion_authorized": True, "visual_reviewed": False,
        "runtime_artifacts": sorted(all_artifacts, key=lambda a: a["path"]), "entry_scene": records["ghoulkin"]["path"],
        "export_policy": "explicit_user_inclusion_authorization_with_separate_pending_visual_review", "build_ledger": "res://" + RECEIPT}
    packs = output["soul_asset_pack_manifest.json"]["packs"]
    packs[:] = [row for row in packs if row.get("id") != PACK_ID] + [pack]
    source_rows = runtime["source_packs"]
    source_rows[:] = [row for row in source_rows if row.get("id") != PACK_ID] + [{"id": PACK_ID, "url": PACK_URL, "license": pack["license"], "status": pack["status"], "runtime_roles": [key for key in runtime["roles"] if runtime["roles"][key].get("source_pack") == PACK_ID]}]
    output["data/spectral_monster_profiles.json"] = profiles
    summary = {"models": len(records), "artifacts": len(all_artifacts), "artifact_bytes": sum(a["bytes"] for a in all_artifacts), "visual_review": "pending_user_review", "files": list(output)}
    return output, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    try:
        output, summary = plan()
        changed = []
        for name, value in output.items():
            encoded = json.dumps(value, indent=2, ensure_ascii=False) + "\n"
            file = PROJECT / name
            if not file.exists() or file.read_text(encoding="utf-8") != encoded:
                changed.append(name)
                if args.write:
                    file.parent.mkdir(parents=True, exist_ok=True)
                    file.write_text(encoded, encoding="utf-8")
        print(json.dumps({"mode": "written" if args.write else "plan", "changed": changed, **summary}, indent=2))
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, "SPECTRAL REGISTRATION: " + str(error) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
