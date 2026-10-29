"""Publish authored Blender exports into the existing Godot asset registries.

No runtime launch or acceptance claims. Old sources remain recoverable until
their pack selections and consumers have been retired by the migration.
"""
import hashlib
import json
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
PROJECT = HERE.parents[1] / "outputs/AshenOathTheRoadBetweenCrowns"
PACK = "AshenOath_32_Asset_Design_Pack_v1"
LICENSE = "res://assets_external/design_pack_v1/PROVENANCE.md"
HUMANS = {
    "P01": ["kael", "player", "player_kael", "player_human"],
    "C01": ["anwen", "sister_anwen", "sister_anwen_human"],
    "C02": ["rook", "rook_smuggler", "rook_human", "traveler"],
    "C03": ["mira", "mira_herbalist", "mira_human"],
    "C04": ["tor", "blacksmith_tor", "villager_worker_human"],
    "C05": ["elna", "widow_elna", "generic_villager_02", "villager_female_human"],
    "C06": ["toma", "farmer_toma", "generic_villager_01", "villager", "villager_human"],
    "C07": ["senn", "captain_senn", "road_ranger", "road_ranger_human"],
    "C08": ["edric", "lord_edric", "edric_castle", "edric_campaign"],
    "C09": ["vale", "vargan_record_keeper"],
    "C10": ["merrow", "vargan_steward", "castle_guard", "castle_guard_human", "guard"],
    "C11": ["nessa", "saga_nessa", "vargan_servant"],
    "C12": ["nera", "saga_nera", "villager_hooded_human"],
}
CREATURES = {
    "M01": ["ghoulkin", "ghoulkin_creature", "ghoulkin_skeleton", "ghoul_gaunt_real"],
    "M02": ["wychwood_stalker", "wychwood_stalker_creature", "ghoul_stalker_real"],
    "M03": ["bog_wretch", "bog_wretch_creature"],
    "M04": ["gravebound_knight", "gravebound_knight_creature", "halvern", "halvern_boss", "returned_soldier", "bandit", "bandit_deserter", "bandit_tracker"],
    "M05": ["bell_eater", "bell_eater_boss"],
    "M06": ["rootbound_colossus", "rootbound_colossus_boss"],
    "M07": ["ashwing", "ashwing_creature", "ashwing_boss"],
    "M08": ["white_hart", "white_hart_avatar", "white_hart_boss"],
    "M09": ["silt_maw"], "M10": ["millback"], "M11": ["glassmoth"],
    "M12": ["knell_leech"], "M13": ["hearthscale", "bracken", "bracken_companion"],
    "M14": ["gallows_weaver"], "M15": ["reed_choir"], "M16": ["inkblind"],
    "M17": ["cairn_mother"], "M18": ["shroud_swimmer"],
    "M19": ["wychwood_raider", "wychwood_raider_creature"],
    "M20": ["wychwood_brute", "wychwood_brute_creature", "ghoul_brute_real", "orc_skull_real"],
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    curated = read(PROJECT / "curated_runtime_assets.json")
    visual = read(PROJECT / "visual_upgrade_manifest.json")
    runtime = read(PROJECT / "runtime_asset_manifest.json")
    old_roles = set()
    for manifest in (curated, visual):
        for category in ("characters", "enemies", "companions"):
            old_roles.update(manifest["roles"].get(category, {}))
    roster = read(PROJECT / "data/design_pack_cast.json")
    by_person = {key: value["design"] for key, value in roster["cast"].items()}
    for legacy, person in roster["legacy_cast"].items():
        if legacy not in HUMANS[by_person[person]]:
            HUMANS[by_person[person]].append(legacy)
    role_map = {role: asset for asset, roles in {**HUMANS, **CREATURES}.items() for role in roles}
    unknown = old_roles - role_map.keys()
    if unknown:
        raise ValueError("Unmapped existing cast roles: " + ", ".join(sorted(unknown)))
    ledger = {"source_pack": PACK, "runtime_acceptance": "unverified", "assets": {}, "roles": {}}
    destination = PROJECT / "assets_external/design_pack_v1"
    for asset_id, roles in {**HUMANS, **CREATURES}.items():
        folder = "humans" if asset_id in HUMANS else "creatures"
        if asset_id == "C01":
            source = HERE / "exports/C01_anwen_draft.glb"
            report = read(HERE / "exports/C01_anwen_draft.json")
            filename = "C01_Anwen.glb"
        else:
            report = read(HERE / "exports" / asset_id / "production.json")
            source = HERE / "exports" / asset_id / (asset_id + "_" + report["name"] + ".glb")
            filename = source.name
        target = destination / folder / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        path = "res://" + target.relative_to(PROJECT).as_posix()
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        expected = report.get("sha256", report.get("glb_sha256"))
        if digest != expected:
            raise ValueError("Blender production record does not match: " + asset_id)
        owner = "opening" if asset_id in ["P01", "C01", "C02", "C03", "C04", "C05", "C06", "C11", "C12", "M13", "M15"] else "characters" if folder == "humans" else "monsters"
        entry = {"status":"authored_inclusion_authorized_review_pending", "path":path,
                 "source_pack":PACK, "source":PACK, "license_file":LICENSE,
                 "license":"User-supplied design; project-authored mesh; retained CC0 human rig/anatomy where recorded",
                 "runtime_parts":[], "runtime_textures":[], "design_id":asset_id,
                 "notes":"One authored body and immutable material set; no legacy silhouette overlays."}
        ledger["assets"][asset_id] = {"path":path, "owner":owner, "sha256":digest,
                                           "bytes":target.stat().st_size, "blender_report":report}
        for role in roles:
            category = "characters" if folder == "humans" or role in ["halvern", "halvern_boss", "returned_soldier"] else "enemies"
            for manifest in (curated, visual):
                for group in ("characters", "enemies", "companions"):
                    manifest["roles"].setdefault(group, {}).pop(role, None)
                manifest["roles"][category][role] = dict(entry)
            runtime["roles"][role] = {
                "display_name":role, "model":path, "source_pack":PACK, "license_file":LICENSE,
                "approved":False, "inclusion_authorized":True,
                "authorization_kind":"user_requested_blender_cast_replacement",
                "visual_reviewed":False, "runtime_acceptance":"unverified", "export_eligible":True,
                "fallback_mode":"none", "status":"authored_pending_user_acceptance",
                "required_clips":["Idle", "Walking", "Running"] if folder == "creatures" else ["Idle", "Walk"],
                "runtime_files":[{"path":path, "bytes":target.stat().st_size, "sha256":digest}],
                "design_id":asset_id,
            }
            ledger["roles"][role] = asset_id
    staff = HERE / "exports/C01_ash_staff.glb"
    shutil.copy2(staff, destination / staff.name)
    ledger["staff"] = {"path":"res://assets_external/design_pack_v1/" + staff.name,
                       "bytes":staff.stat().st_size, "sha256":hashlib.sha256(staff.read_bytes()).hexdigest()}
    runtime["status"] = "design_pack_cast_authored_runtime_acceptance_pending"
    runtime["source_packs"] = [row for row in runtime["source_packs"] if row.get("id") != PACK]
    runtime["source_packs"].append({"id":PACK, "status":"user_authorized_blender_cast_replacement",
                                     "license_file":LICENSE, "runtime_roles":sorted(role_map)})
    for filename, data in [("curated_runtime_assets.json", curated), ("visual_upgrade_manifest.json", visual),
                           ("runtime_asset_manifest.json", runtime), ("data/design_pack_assets.json", ledger)]:
        write(PROJECT / filename, data)
    print(json.dumps({"authored_bodies":len(ledger["assets"]), "runtime_roles":len(ledger["roles"]),
                      "glb_bytes":sum(row["bytes"] for row in ledger["assets"].values())}))


if __name__ == "__main__":
    main()
