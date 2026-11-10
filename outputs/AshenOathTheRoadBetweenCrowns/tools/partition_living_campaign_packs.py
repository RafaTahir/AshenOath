"""Explicit ownership for deferred community code, scenery and delivered voices.

Called by the authoritative layout compiler after actor closure is assigned.
Never attach expansion content or speech to the Greyfen startup dependency set.
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
from pathlib import PurePosixPath

COMMUNITY_FILES = {
    "scripts/community_campaign.gd", "scripts/community_activity.gd",
    "scripts/community_ending.gd",
    "scripts/community_presentation.gd", "scripts/zones/community_section.gd",
    "data/community_campaign.json", "data/community_cast_life.json",
    "data/community_story_overlay.json",
    "data/localization/community_en.json",
    "assets_external/environment/forest/HartAftermath_concord_Authored.res",
    "assets_external/environment/forest/HartAftermath_open_road_Authored.res",
}
BASE_STORY_FILES = {"data/runtime_story_campaign.json"}
AUTHORING_ONLY = {"data/story_campaign.json"}
VOICE_DIRECTORIES = {"living_cast_voice":"living_cast", "community_voice":"community"}
STATION_OWNERS = {"nessa":"actor_c11", "elna":"actor_c05", "toma":"actor_c06", "nera":"actor_c12", "vale":"actor_c09", "merrow":"actor_c10", "edric":"actor_c08"}
STATIONS = "assets_external/environment_prepared/living_cast/"
SCENERY_FILES = {"assets_external/environment_prepared/living_world/" + name + ".scn"
                 for name in ("checkpoint_cloth", "marsh_reeds", "hart_ferns", "ash_mill_wheel")}
COMPANION_FILES = {"assets_external/characters_prepared/companions/bracken.scn"}


def _selected(value):
    return set(json.loads("[" + value.removeprefix("PackedStringArray(").removesuffix(")") + "]"))


def _filter(value):
    return set(json.loads(value).split(",")) - {""}


def partition_living_campaign_packs(project, config, sections, manifest, *, require_prepared_companion=True):
    if not (project / "scripts/campaign_revision.gd").is_file(): return
    startup_before = list(manifest.get("startup_dependencies", []))
    owned = {path:"community" for path in COMMUNITY_FILES}
    owned.update({path:"base" for path in BASE_STORY_FILES})
    owned.update({path:"campaign" for path in SCENERY_FILES})
    owned.update({path:"actor_m13" for path in COMPANION_FILES})
    required = set(COMMUNITY_FILES) | SCENERY_FILES | BASE_STORY_FILES
    if require_prepared_companion:
        required.update(COMPANION_FILES)
    for person, owner in STATION_OWNERS.items():
        scene = STATIONS + "station_" + person + ".scn"
        required.add(scene)
        owned[scene] = owner
        for resource in (project / STATIONS).glob("station_" + person + "_*.res"):
            owned[resource.relative_to(project).as_posix()] = owner
    required.add(STATIONS + "merrow_cup.scn")
    owned[STATIONS + "merrow_cup.scn"] = "actor_c10"
    for resource in (project / STATIONS).glob("merrow_cup*.res"):
        owned[resource.relative_to(project).as_posix()] = "actor_c10"
    deliveries = json.loads((project / "voice_production_manifest.json").read_text(encoding="utf-8-sig"))
    for pack, directory in VOICE_DIRECTORIES.items():
        prefix = "res://assets_external/audio/voices/" + directory + "/"
        for entry in deliveries.get("lines", []):
            resource = str(entry.get("path", ""))
            if not resource.startswith(prefix): continue
            relative = PurePosixPath(resource[6:])
            if str(relative.parent) != prefix[6:-1] or relative.suffix != ".ogg" or ".." in relative.parts or "\\" in resource:
                raise ValueError("Invalid deferred voice path: " + resource)
            path = (project / relative).resolve()
            if not path.is_relative_to(project.resolve()) or not path.is_file():
                raise ValueError("Missing deferred voice: " + resource)
            if path.stat().st_size != entry.get("audio_bytes") or hashlib.sha256(path.read_bytes()).hexdigest() != entry.get("audio_sha256"):
                raise ValueError("Deferred voice bytes differ from delivery manifest: " + resource)
            owned[relative.as_posix()] = pack
    missing = sorted(path for path in required if not (project / path).is_file())
    if missing: raise ValueError("Missing authored community resource(s): " + ", ".join(missing))
    pack_ids = {"community", *VOICE_DIRECTORIES}
    by_pack = {pack:{path for path, owner in owned.items() if owner == pack} for pack in sorted(pack_ids)}
    for pack, paths in by_pack.items():
        if not paths: raise ValueError(f"Deferred pack {pack} has no delivered resources")
        name = "Runtime Pack " + pack
        if name not in sections:
            index = max(int(section.split(".")[1]) for section in config.sections() if "." in section) + 1
            section = "preset." + str(index)
            config[section] = dict(config[sections["Runtime Pack Campaign"]])
            config[section]["name"] = json.dumps(name)
            config[section + ".options"] = dict(config[sections["Runtime Pack Campaign"] + ".options"])
            sections[name] = section
        manifest.setdefault("pack_presets", {})[pack] = name
        record = manifest["packs"].setdefault(pack, {
            "id":pack, "filename":pack+".pck", "url":"packs/"+pack+".pck",
            "version":"pending-build", "sha256":"", "bytes":0, "entry_scene":"",
            "status":"awaiting_source_aligned_build", "preload_priority":30,
        })
        record["dependencies"] = ["base"]
        record["required_at_startup"] = False
        record["contents"] = sorted(paths)
    unknown = sorted(set(owned.values()) - set(manifest["pack_presets"]))
    if unknown: raise ValueError("Missing resource owner pack(s): " + ", ".join(unknown))
    # Keep the manifest's resource inventories aligned with the actual selectors,
    # including additions to packs created by the preceding actor partition.
    for pack, record in manifest["packs"].items():
        contents = {path for path in record.get("contents", [])
                    if path.removeprefix("res://") not in owned
                    and path.removeprefix("res://") not in AUTHORING_ONLY}
        contents.update("res://" + path for path, owner in owned.items() if owner == pack)
        record["contents"] = sorted(contents)
    actor_owners = manifest.setdefault("actor_resource_owners", {})
    for path, owner in owned.items():
        actor_owners.pop("res://" + path, None)
        if owner.startswith("actor_"): actor_owners["res://" + path] = owner
    presets_to_ids = {name:pack for pack, name in manifest["pack_presets"].items()}
    # Dynamic code imports still depend on base services. Exact exclusions
    # prevent duplicate code while leaving the community's own scripts intact.
    core_files = {path.relative_to(project).as_posix()
                  for directory in ("scripts", "data") for path in (project / directory).rglob("*")
                  if path.is_file() and path.suffix in {".gd", ".json", ".res"}}
    for name, section in sections.items():
        pack = presets_to_ids.get(name, "base")
        included = _filter(config[section].get("include_filter", '""'))
        excluded = _filter(config[section].get("exclude_filter", '""'))
        selected = _selected(config[section].get("export_files", "PackedStringArray()"))
        if pack in pack_ids:
            selected, included = set(), set()
            excluded = {"art_review/*", "art_review/**/*", "tools/*", "docs/*"}
            excluded.update(core_files - by_pack[pack])
        for path, owner in owned.items():
            selected.discard("res://" + path)
            included.discard(path)
            if pack == owner:
                excluded = {pattern for pattern in excluded if not fnmatch.fnmatchcase(path, pattern)}
                if path.endswith(".json"): included.add(path)
                else: selected.add("res://" + path)
            else:
                excluded.add(path)
        # A broad historical audio wildcard must not pull deferred recordings
        # back into the original audio pack, including future generated files.
        for owner, directory in VOICE_DIRECTORIES.items():
            pattern = "assets_external/audio/voices/" + directory + "/*"
            if pack != owner: excluded.add(pattern)
        for path in AUTHORING_ONLY:
            selected.discard("res://" + path)
            included.discard(path)
            excluded.add(path)
        config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(path) for path in sorted(selected)) + ")"
        config[section]["include_filter"] = json.dumps(",".join(sorted(included)))
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))
    # Existing regions acquire the overlay through revision/earned-state aware
    # preparation extras. Legacy Hart journeys must retain their old closure.
    for zone in ("lantern_reach", "hearthward"):
        if zone not in manifest.get("zone_dependencies", {}):
            raise ValueError("Missing explicit destination ownership: " + zone)
        if "community" not in manifest["zone_dependencies"][zone]:
            manifest["zone_dependencies"][zone].append("community")
    if manifest.get("startup_dependencies", []) != startup_before:
        raise ValueError("Community partition changed Greyfen startup dependencies")
    manifest["community_resource_owners"] = {"res://"+path:owner for path, owner in sorted(owned.items())}
