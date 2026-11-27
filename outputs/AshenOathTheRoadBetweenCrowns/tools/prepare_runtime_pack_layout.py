"""Compile non-overlapping export selections from the existing runtime presets.

This is packaging, not a runtime resource fallback. Original source assets stay
in the project; each selected path is transferred to its owning pack.
"""

import argparse
import configparser
import fnmatch
import hashlib
import json
import re
from pathlib import Path
from runtime_pack_validation import require_valid_pack_graph
from partition_actor_packs import partition_actor_packs
from prepared_forest_tree_layout import load_prepared_forest_trees
from partition_living_campaign_packs import partition_living_campaign_packs
from partition_novel_pack import partition_novel_pack
from story_voice_catalog import authored_dialogue_inventory, canonical_speaker
from natural_story_voices import pages


PROJECT = Path(__file__).resolve().parent.parent
ROOT_NAMES = {"Web Browser", "Web QA Browser", "Runtime Pack Base"}
SAGA_OPENING_RECORD = "assets_external/environment/props/CampaignRecord_register_mira_Authored.res"
CHAPTER_ART = "assets/ui/story_chapters_atlas.png"
FORGE_HAMMER = "assets/characters/forge_hammer.tscn"
HUNTING_ARROW = "assets/characters/kael_arrow.glb"
SILHOUETTE_DIRECTORY = "assets/characters/silhouette/"
ENVIRONMENT_RETIREMENTS = "data/environment_export_retirements.json"
CAMPAIGN_PREFIXES = (
    "assets_external/environment/forest/Campaign_",
    "assets_external/environment/forest/Hart",
    "assets_external/environment/forest/Bandit",
    "assets_external/environment/village/AshMill_",
    "assets_external/environment/village/AssemblyCourt_",
    "assets_external/environment/village/Farmstead",
    "assets_external/environment/village/RoadCheckpoint_",
    "assets_external/environment/village/Undercroft",
    "assets_external/environment/village/Vargan_",
    "assets_external/environment/props/RecordArchive_",
    "assets_external/environment/props/record_witness_",
    "assets_external/environment/props/CampaignRecord_",
    "scripts/zones/campaign_", "scripts/zones/castle_vargan_",
    "scripts/zones/bandit_road_", "scripts/undercroft_memorial.gd",
)


def selected_files(value):
    return json.loads("[" + value.removeprefix("PackedStringArray(").removesuffix(")") + "]")


# Greyfen uses the authored houses and cemetery. Only later road and castle
# builders request the modular masonry, while the shrine arch still uses wood trim.
MASONRY_PRESET = "Runtime Pack Masonry"
MASONRY_MODULES = {
    "assets_external/environment/village/" + name + ".obj"
    for name in ("Roof_2x4_RoundTile", "Roof_RoundTiles_8x10", "Wall_UnevenBrick_Straight")
}
MASONRY_ZONES = ("vargan_approach", "vargan_court")


def ensure_masonry_preset(config, sections):
    if MASONRY_PRESET in sections:
        return
    section = "preset." + str(max(int(s.split(".")[1]) for s in sections.values()) + 1)
    campaign = sections["Runtime Pack Campaign"]
    config[section] = dict(config[campaign])
    config[section].update({"name": json.dumps(MASONRY_PRESET), "export_files": "PackedStringArray()", "include_filter": '""'})
    config[section + ".options"] = dict(config[campaign + ".options"])
    sections[MASONRY_PRESET] = section


def partition_road_masonry(config, sections, manifest, environment):
    # The import dependency compiler decides which textures still have earlier consumers.
    owned = MASONRY_MODULES | {path.removeprefix("res://") for path, record in environment.items()
                               if record["owner"] == "masonry"}
    for name, section in sections.items():
        fields = config[section]
        files = set(selected_files(fields["export_files"]))
        includes = set(json.loads(fields["include_filter"]).split(",")) - {""}
        excludes = set(json.loads(fields["exclude_filter"]).split(",")) - {""}
        includes.difference_update(owned)
        sources = {"res://" + path for path in owned}
        if name == MASONRY_PRESET:
            # This dedicated preset has no other roots. Imported modules keep their material bindings.
            files = sources
            includes.clear()
            excludes.difference_update(owned)
            excludes.update(path.removeprefix("res://") for path, record in environment.items()
                            if record["owner"] != "masonry")
        else:
            files.difference_update(sources)
            excludes.update(owned)
        fields["export_files"] = "PackedStringArray(" + ", ".join(map(json.dumps, sorted(files))) + ")"
        fields["include_filter"] = json.dumps(",".join(sorted(includes)))
        fields["exclude_filter"] = json.dumps(",".join(sorted(excludes)))
    manifest["pack_presets"]["masonry"] = MASONRY_PRESET
    pack = manifest["packs"].setdefault("masonry", {})
    defaults = {
        "id": "masonry", "filename": "masonry.pck", "url": "packs/masonry.pck",
        "version": "pending-build", "sha256": "", "bytes": 0, "entry_scene": "",
        "required_at_startup": False, "preload_priority": 20, "status": "awaiting_source_aligned_build",
        "dependencies": ["base", "opening"]}
    for field, value in defaults.items():
        pack.setdefault(field, value)
    pack["contents"] = sorted("res://" + path for path in owned)
    for zone in MASONRY_ZONES:
        requirements = manifest["zone_dependencies"][zone]
        if "masonry" not in requirements:
            requirements.append("masonry")


def partition_opening_dialogue(project, config, sections, manifest):
    """Put the selected care and briefing recordings in Greyfen's pack."""
    bindings = authored_dialogue_inventory(project, ("dialogue.json", "interaction_scenes.json"), pages)
    selected = [row for row in bindings if row["selected_take_id"] and (
        row["source_id"] == "sister_anwen" or row["source_id"].startswith("opening_care_"))]
    if not selected:
        return set()
    delivery = json.loads((project / "voice_production_manifest.json").read_text(encoding="utf-8-sig"))
    lines = delivery["lines"]
    takes = lines if isinstance(lines, dict) else {take["id"]: take for take in lines}
    voice_paths = set()
    for binding in selected:
        take = takes.get(binding["selected_take_id"], {})
        if (take.get("scene") != binding["source_id"]
                or canonical_speaker(project, take.get("speaker_id", "")) != binding["speaker_id"]
                or take.get("text_sha256") != binding["text_sha256"]):
            raise ValueError("Missing matching opening performance: " + binding["line_id"])
        source = str(take.get("path", ""))
        relative = source.removeprefix("res://")
        if (not source.startswith("res://assets_external/audio/voices/story/")
                or Path(relative).suffix != ".ogg" or ".." in relative.split("/") or "\\" in relative):
            raise ValueError("Invalid opening performance path: " + source)
        recording = (project / relative).resolve()
        if not recording.is_relative_to(project.resolve()) or not recording.is_file():
            raise ValueError("Missing opening recording: " + source)
        payload = recording.read_bytes()
        if len(payload) != take.get("audio_bytes") or hashlib.sha256(payload).hexdigest() != take.get("audio_sha256"):
            raise ValueError("Opening recording differs from its authored take: " + source)
        voice_paths.add(source)

    relative_paths = {path.removeprefix("res://") for path in voice_paths}
    for name, section in sections.items():
        preset = config[section]
        prior_selection = set(selected_files(preset.get("export_files", "PackedStringArray()")))
        prior_include = set(json.loads(preset.get("include_filter", '\"\"')).split(",")) - {""}
        prior_exclude = set(json.loads(preset.get("exclude_filter", '\"\"')).split(",")) - {""}
        selected_paths = prior_selection - voice_paths
        included = prior_include - relative_paths
        excluded = prior_exclude.copy()
        if name == "Runtime Pack Opening":
            selected_paths.update(voice_paths)
            excluded = {pattern for pattern in excluded
                        if not any(fnmatch.fnmatchcase(path, pattern) for path in relative_paths)}
        else:
            all_resources = json.loads(preset.get("export_filter", '\"all_resources\"')) == "all_resources"
            for path in relative_paths:
                included_by_pattern = any(fnmatch.fnmatchcase(path, pattern) for pattern in included)
                if (all_resources or included_by_pattern) and not any(fnmatch.fnmatchcase(path, pattern) for pattern in excluded):
                    excluded.add(path)
        if selected_paths != prior_selection:
            preset["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(path) for path in sorted(selected_paths)) + ")"
        if included != prior_include:
            preset["include_filter"] = json.dumps(",".join(sorted(included)))
        if excluded != prior_exclude:
            preset["exclude_filter"] = json.dumps(",".join(sorted(excluded)))
    for pack, record in manifest["packs"].items():
        contents = set(record.get("contents", [])) - voice_paths - relative_paths
        if pack == "opening":
            contents.update(voice_paths)
        record["contents"] = sorted(contents)
    return voice_paths


def retire_environment_export_roots(project, config, sections):
    """Keep current baked visuals while retiring unused import roots.

    Texture ownership remains the environment dependency builder's decision.
    This policy excludes no texture or authoring file from the source library.
    """
    policy = json.loads((project / ENVIRONMENT_RETIREMENTS).read_text(encoding="utf-8-sig"))
    if not isinstance(policy, dict) or policy.get("schema_version") != 1:
        raise ValueError("Invalid environment export retirement policy")
    for field, suffix in (("retired_source_roots", ".obj"), ("required_authored_roots", ".res")):
        paths = policy.get(field)
        if (not isinstance(paths, list) or not paths or any(not isinstance(p, str) for p in paths)
                or len(set(paths)) != len(paths)
                or any(not p.startswith("res://assets_external/environment/") or not p.endswith(suffix)
                       or "\\" in p or ".." in p.split("/") for p in paths)):
            raise ValueError("Invalid environment export retirement policy: " + field)
    retired = set(policy["retired_source_roots"])
    for name, section in sections.items():
        selected = set(selected_files(config[section].get("export_files", "PackedStringArray()")))
        included = set(json.loads(config[section].get("include_filter", '""')).split(",")) - {""}
        excluded = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        selected.difference_update(retired)
        for source in retired:
            relative = source.removeprefix("res://")
            included.discard(relative)
            excluded.add(relative)
        if name == "Runtime Pack Opening":
            selected.update(policy["required_authored_roots"])
            for path in policy["required_authored_roots"]:
                excluded.discard(path.removeprefix("res://"))
        config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in sorted(selected)) + ")"
        config[section]["include_filter"] = json.dumps(",".join(sorted(included)))
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))


def prepared_source_exclusions(catalog):
    """Omit only proven standalone compiled actors, retaining direct consumers.

    Dependency evidence is generated by Godot alongside animation ownership and
    bound to the exact compiled scene bytes. Original authoring files stay local.
    """
    direct_sources = set()
    pattern = re.compile(r'''["'](res://assets_external/design_pack_v1/[^"']+\.(?:glb|gltf|fbx|dae))["']''')
    for directory in ("scripts", "scenes", "assets"):
        for path in (PROJECT / directory).rglob("*"):
            if path.suffix in {".gd", ".tscn", ".tres"}:
                direct_sources.update(pattern.findall(path.read_text(encoding="utf-8-sig")))
    grouped = {}
    for actor in catalog.values():
        grouped.setdefault(actor["source"], []).append(actor)
    required_roles = {}
    for name in ("curated_runtime_assets.json", "visual_upgrade_manifest.json"):
        manifest = json.loads((PROJECT / name).read_text(encoding="utf-8-sig"))
        for roles in manifest.get("roles", {}).values():
            for role, record in roles.items():
                source = str(record.get("path", ""))
                required_roles.setdefault(source, set()).add(role + "|" + source)
    exclusions = set()
    for source, actors in grouped.items():
        if not source.startswith("res://assets_external/design_pack_v1/") or source in direct_sources:
            continue
        # A newly added alias must retain its source until the compiler has
        # produced its prepared entry; an older catalog cannot hide that role.
        if not required_roles.get(source, set()).issubset(catalog):
            continue
        for actor in actors:
            path = PROJECT / actor["path"].removeprefix("res://")
            if (not actor.get("variant_safe", False)
                    or actor.get("source_scene_dependencies") != []
                    or not path.is_file()
                    or actor.get("compiled_sha256") != hashlib.sha256(path.read_bytes()).hexdigest()):
                break
        else:
            exclusions.add(source.removeprefix("res://"))
    return exclusions


def compile_layout(defer_environment=False, require_prepared_forest=False):
    forest = load_prepared_forest_trees(PROJECT, required=not defer_environment or require_prepared_forest)
    presets_path = PROJECT / "export_presets.cfg"
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read(presets_path, encoding="utf-8-sig")
    sections = {json.loads(config[s]["name"]): s for s in config.sections()
                if "name" in config[s]}
    ensure_masonry_preset(config, sections)
    leisure = "Runtime Pack Leisure"
    if leisure not in sections:
        index = max(int(s.split(".")[1]) for s in config.sections() if "." in s) + 1
        section = f"preset.{index}"
        config[section] = dict(config[sections["Runtime Pack Campaign"]])
        config[section]["name"] = json.dumps(leisure)
        config[section]["export_files"] = "PackedStringArray()"
        config[section]["include_filter"] = '"assets/everyday/*.glb"'
        config[section + ".options"] = {"variant/extensions_support": "false"}
        sections[leisure] = section
    adjacent = "Runtime Pack Adjacent"
    if adjacent not in sections:
        index = max(int(s.split(".")[1]) for s in config.sections() if "." in s) + 1
        section = f"preset.{index}"
        config[section] = dict(config[sections["Runtime Pack Campaign"]])
        config[section]["name"] = json.dumps(adjacent)
        config[section]["export_files"] = "PackedStringArray()"
        config[section]["include_filter"] = '""'
        config[section + ".options"] = {"variant/extensions_support": "false"}
        sections[adjacent] = section
    adjacent_options = sections[adjacent] + ".options"
    if not config.has_section(adjacent_options):
        config[adjacent_options] = {"variant/extensions_support": "false"}
    materials = "Runtime Pack Opening Materials"
    if materials not in sections:
        index = max(int(s.split(".")[1]) for s in config.sections() if "." in s) + 1
        section = f"preset.{index}"
        config[section] = dict(config[sections["Runtime Pack Opening"]])
        config[section]["name"] = json.dumps(materials)
        config[section]["export_files"] = "PackedStringArray()"
        config[section]["include_filter"] = '""'
        config[section + ".options"] = {"variant/extensions_support": "false"}
        sections[materials] = section
    includes = {n: set(json.loads(config[s].get("include_filter", '""')).split(",")) - {""}
                for n, s in sections.items()}
    files = {n: set(selected_files(config[s].get("export_files", "PackedStringArray()")))
             for n, s in sections.items()}
    # The standalone base includes HUD scripts through a filter. Its view
    # dependencies need explicit resource selection for Godot to emit bytecode.
    files["Runtime Pack Base"].add("res://scripts/views/dialogue_button_dispatch.gd")
    # The compiler proves identical arrays, bounds and effective flat materials.
    # Keep raw authoring files locally, but never load their obsolete imported
    # materials through a later pack after their prepared replacement is owned.
    for name in sections:
        for source, record in forest.items():
            files[name].discard(source)
            includes[name].discard(source.removeprefix("res://"))
            files[name].discard(record["path"])
            includes[name].discard(record["path"].removeprefix("res://"))
    files["Runtime Pack Opening"].update(record["path"] for record in forest.values())
    for name in ROOT_NAMES:
        includes[name].add("data/native_attack_profiles.json")
        includes[name].update({"scripts/systems/*.gd", "scripts/hud/*.gd", "scripts/systems/method_ownership.json"})
        files[name].update({
            "res://scripts/systems/character_silhouette.gd",
            "res://scripts/systems/character_palette.gd",
            "res://shaders/character_region_palette.gdshader",
            "res://scripts/spectral_monster_presentation.gd",
            "res://shaders/spectral_veil.gdshader",
            "res://shaders/everyday_wear.gdshader",
            "res://data/spectral_monster_profiles.json",
            "res://scripts/views/monster_material_view.gd",
            "res://scripts/views/monster_pigment_material.gd",
            "res://scripts/views/character_material_budget_view.gd",
            "res://scripts/models/ecology_response.gd",
            "res://scripts/views/enemy_strike_contact.gd",
            "res://scripts/views/wychwood_counterplay.gd",
            "res://scripts/views/wychwood_hunter_wardrobe.gd",
            "res://scripts/views/wychwood_burden_view.gd",
            "res://shaders/monster_pigment.gdshader",
            "res://shaders/monster_pigment_clearcoat.gdshader",
            "res://shaders/monster_pigment_common.gdshaderinc",
            "res://shaders/monster_pigment_surface.gdshaderinc",
            "res://data/monster_material_profiles.json",
        })
        includes[name].update({"data/runtime_dialogue_index.json", "data/runtime_dialogue/*.json"})
        includes[name].update({"assets/ui/fonts/*.ttf", "assets/ui/fonts/OFL.txt"})
    spectral_profiles = PROJECT / "data/spectral_monster_profiles.json"
    if spectral_profiles.exists():
        files["Runtime Pack Monsters"].update(json.loads(spectral_profiles.read_text())["assets"])
    # Loading artwork belongs to the boot PCK, not a later campaign download.
    # Select the imported texture explicitly; keep just one mounted owner.
    for name in sections:
        includes[name].discard(CHAPTER_ART)
        files[name].discard("res://" + CHAPTER_ART)
        if name in {"Web Browser", "Web QA Browser"}:
            files[name].add("res://" + CHAPTER_ART)
    includes["Runtime Pack Opening"].add("assets_external/environment/prepared/greyfen_*.res")
    living_station_directory = "assets_external/environment_prepared/living_cast/"
    drying_leaves = "assets_external/environment/forest/Fern_1.obj"
    # Greyfen owns the authored work props and their retained leaf detail.
    # Select the scene so Godot includes its three mesh dependencies as well.
    includes["Runtime Pack Opening"].update({living_station_directory + "*.res", living_station_directory + "*.scn", drying_leaves})
    files["Runtime Pack Opening"].add("res://" + living_station_directory + "rook_station_satchel.scn")
    for name in sections:
        if name != "Runtime Pack Opening":
            includes[name].discard(drying_leaves)
            files[name].discard("res://" + drying_leaves)
            files[name] = {path for path in files[name] if not path.startswith("res://" + living_station_directory)}
    # Touchable village details share retained source meshes, owned by opening.
    for prop in ("Dummy.obj", "Pot_1.obj", "Pot_1_Lid.obj"):
        relative = "assets_external/environment/props/" + prop
        includes["Runtime Pack Opening"].add(relative)
        for name in sections:
            if name != "Runtime Pack Opening":
                includes[name].discard(relative)
                files[name].discard("res://" + relative)
    includes["Runtime Pack Opening"].add("data/prepared_greyfen_social_collision.res")
    files["Runtime Pack Opening"].add("res://" + FORGE_HAMMER)
    files["Runtime Pack Opening"].add("res://" + HUNTING_ARROW)
    for layer in (PROJECT / SILHOUETTE_DIRECTORY).glob("*.obj"):
        files["Runtime Pack Opening"].add("res://" + layer.relative_to(PROJECT).as_posix())
    includes["Runtime Pack Opening"].add(SILHOUETTE_DIRECTORY + "provenance.json")
    # Regional written requests begin in Greyfen, before campaign packs mount.
    # Transfer the retained mesh instead of duplicating it or loading a late
    # resource opportunistically during opening preparation.
    includes["Runtime Pack Opening"].add(SAGA_OPENING_RECORD)
    for name in sections:
        if name != "Runtime Pack Opening":
            includes[name].discard(SAGA_OPENING_RECORD)
            files[name].discard("res://" + SAGA_OPENING_RECORD)
    # Kael can bring the carved token back to Greyfen. The axle and tally
    # are encountered only after the forest's adjacent pack has mounted.
    trail_props = {
        "assets_external/environment/village/CarvedCrowToken.res": "Runtime Pack Opening",
        "assets_external/environment/forest/Wychwood_CartersAxle.res": adjacent,
        "assets_external/environment/forest/Wychwood_RaiderTally.res": adjacent,
    }
    for relative, owner_name in trail_props.items():
        files[owner_name].add("res://" + relative)
    includes[adjacent].add("assets_external/environment/prepared/wychwood_*.res")
    includes["Runtime Pack Campaign"].add("assets_external/environment/prepared/*.res")
    for owner, name in (("opening", "Runtime Pack Opening"), ("characters", "Runtime Pack Characters"), ("monsters", "Runtime Pack Monsters")):
        includes[name].add(f"assets_external/characters_prepared/{owner}/*.scn")
    # Include filters copy generated scenes without reliably expanding every
    # imported dependency. Include inactive/alternate serialized materials too.
    actor_catalog = PROJECT / "data/prepared_actors.json"
    prepared_catalog = json.loads(actor_catalog.read_text(encoding="utf-8-sig")) if actor_catalog.is_file() else {}
    standalone_sources = prepared_source_exclusions(prepared_catalog)
    if actor_catalog.is_file():
        for actor in json.loads(actor_catalog.read_text(encoding="utf-8-sig")).values():
            pack = "Runtime Pack " + str(actor["owner"]).capitalize()
            if "resource_dependencies" not in actor:
                raise ValueError(f"Prepared resource dependencies absent: {actor['role']}; refresh the asset catalog")
            for dependency in actor["resource_dependencies"]:
                if not dependency.startswith("res://") or not (PROJECT / dependency.removeprefix("res://")).is_file():
                    raise ValueError(f"Required prepared dependency missing: {actor['role']}: {dependency}")
                files[pack].add(dependency)
            for binding in actor.get("material_bindings", []):
                texture = str(binding.get("texture", ""))
                if not texture.startswith("res://") or "::" in texture:
                    continue
                if not (PROJECT / texture.removeprefix("res://")).is_file():
                    raise ValueError(f"Required actor atlas missing: {actor['role']}: {texture}")
                files[pack].add(texture)
    animation_owners = {}
    if actor_catalog.is_file():
        for actor in json.loads(actor_catalog.read_text(encoding="utf-8-sig")).values():
            if "animation_resources" not in actor:
                raise ValueError(f"Prepared animation dependency record is absent: {actor['role']}; refresh the asset catalog")
            for path in actor.get("animation_resources", []):
                if not (PROJECT / path.removeprefix("res://")).is_file():
                    raise ValueError(f"Required actor animation missing: {actor['role']}: {path}")
                animation_owners.setdefault(path, set()).add(str(actor["owner"]))
    for name in sections:
        includes[name].discard("assets_external/characters_prepared/animations/*.res")
    for path, owners in animation_owners.items():
        owner = "opening" if "opening" in owners else ("characters" if "characters" in owners else "monsters")
        name = "Runtime Pack " + owner.capitalize()
        files[name].add(path)
        for other in sections:
            if other != name:
                files[other].discard(path)
    for name in ROOT_NAMES:
        files[name].add("res://scripts/zone_construction_host.gd")
        includes[name].add("data/prepared_actors.json")
        includes[name].add("data/prepared_forest_trees.json")
        includes[name].add("data/prepared_static_batches.res")
        includes[name].update({"data/prepared_audio.json", "assets/audio/prepared/menu/*.res"})
    includes["Runtime Pack Opening"].add("assets/audio/prepared/opening/*.res")
    includes[adjacent].add("assets/audio/prepared/adjacent/*.res")
    includes["Runtime Pack Campaign"].add("assets/audio/prepared/campaign/*.res")
    for name in sections:
        includes[name].discard("assets/audio/prepared_bank.res")
        files[name].discard("res://assets/audio/prepared_bank.res")

    # Expand only the broad zone-script/scene selectors; their ownership differs.
    for name in sections:
        for pattern in ("scripts/zones/*.gd", "scenes/zones/*.tscn"):
            if pattern in includes[name]:
                includes[name].remove(pattern)
                includes[name].update(p.relative_to(PROJECT).as_posix() for p in PROJECT.glob(pattern))

    def owner(relative):
        if relative in (FORGE_HAMMER, HUNTING_ARROW):
            return "Runtime Pack Opening"
        if relative == SAGA_OPENING_RECORD:
            return "Runtime Pack Opening"
        if relative.startswith(CAMPAIGN_PREFIXES):
            return "Runtime Pack Campaign"
        if relative.startswith(("scripts/zones/wychwood_", "scripts/zones/ruins_",
                                "scenes/zones/wychwood_", "scenes/zones/cemetery_",
                                "scenes/zones/ruins_", "assets_external/environment/forest/Wychwood_")):
            return adjacent
        if relative.startswith(("scripts/zones/greyfen_", "scripts/zones/cemetery_",
                                "scripts/zones/river_", "scenes/zones/greyfen_")):
            return "Runtime Pack Opening"
        if relative.startswith("assets_external/") and not relative.startswith("assets_external/ui/"):
            # Only move root selections here. Other asset-pack selections already
            # have explicit family ownership and are handled separately below.
            return "Runtime Pack Opening"
        return None

    transfers = {}
    for name in ROOT_NAMES | {"Runtime Pack Opening"}:
        for kind, collection in (("include", includes[name]), ("file", files[name])):
            for item in list(collection):
                relative = item.removeprefix("res://")
                previous_exclusions = json.loads(config[sections[name]].get("exclude_filter", '""')).split(",")
                if any(pattern and fnmatch.fnmatchcase(relative, pattern) for pattern in previous_exclusions):
                    # Do not resurrect obsolete include entries which were
                    # already explicitly excluded by the previous preset.
                    collection.remove(item)
                    continue
                destination = owner(relative)
                if destination and destination != name:
                    collection.remove(item)
                    includes[destination].add(relative)
                    transfers[relative] = destination
    # Scripts/manifests have one base owner. Asset packs never replace core code.
    core_manifests = {"runtime_asset_manifest.json", "runtime_pack_manifest.json"}
    for name in sections:
        if name not in ROOT_NAMES:
            files[name] = {p for p in files[name] if p.removeprefix("res://") not in core_manifests}
        if name in {"Runtime Pack Characters", "Runtime Pack Monsters", "Runtime Pack Audio", "Runtime Pack Quality Materials"}:
            files[name] = {p for p in files[name] if not p.startswith("res://scripts/")}
    # The opening owns the native male head/hair layers also used by the Ranger.
    character_layers = ("assets_external/characters_universal/Male_Head.",
                        "assets_external/characters_universal/Hair_SimpleParted.",
                        "assets_external/characters_universal/T_")
    for item in list(includes["Runtime Pack Characters"]):
        if item.startswith(character_layers):
            includes["Runtime Pack Characters"].remove(item)
            includes["Runtime Pack Opening"].add(item)
            transfers[item] = "Runtime Pack Opening"
    shared_opening_textures = set()
    for item in list(files["Runtime Pack Characters"]):
        relative = item.removeprefix("res://")
        if relative.startswith(character_layers):
            files["Runtime Pack Characters"].remove(item)
            files["Runtime Pack Opening"].add(item)
            shared_opening_textures.add(relative)
    # Hostile human assemblies use the same approved Bandit atlases as their
    # character sources. Keep those bytes in characters, not in both packs.
    shared_character_textures = set()
    for item in list(files["Runtime Pack Monsters"]):
        relative = item.removeprefix("res://")
        if relative.endswith(".png") and item in files["Runtime Pack Characters"]:
            files["Runtime Pack Monsters"].remove(item)
            shared_character_textures.add(relative)
    environment_path = PROJECT / "data/environment_material_dependencies.json"
    # The first build pass precedes import/catalog generation. Validate and
    # apply environment closure only on the mandatory post-import pass.
    environment = {} if defer_environment else json.loads(environment_path.read_text(encoding="utf-8-sig"))["textures"]
    for texture, record in environment.items():
        if not texture.startswith("res://assets_external/") or not (PROJECT / texture.removeprefix("res://")).is_file():
            raise ValueError(f"Required environment texture missing: {texture} (owner {record['owner']})")
        destination = "Runtime Pack " + record["owner"].capitalize()
        if destination not in sections:
            raise ValueError(f"Unknown environment texture owner: {texture}: {destination}")
        for name in sections:
            includes[name].discard(texture.removeprefix("res://"))
            files[name].discard(texture)
        # Selecting a texture as a resource exports its remap and decoded
        # import. An include-filter path alone is not a loadable Texture2D.
        files[destination].add(texture)
    design_path = PROJECT / "data/design_pack_assets.json"
    designs = json.loads(design_path.read_text(encoding="utf-8")) if design_path.is_file() else {}
    design_owners = {row["path"].removeprefix("res://"): "Runtime Pack " + row["owner"].capitalize()
                     for row in designs.get("assets", {}).values()}
    if designs:
        design_owners[designs["staff"]["path"].removeprefix("res://")] = "Runtime Pack Opening"
        for relative, destination in design_owners.items():
            for name in sections:
                files[name].discard("res://" + relative)
                includes[name].discard(relative)
            if relative not in standalone_sources:
                files[destination].add("res://" + relative)
        for name in ROOT_NAMES:
            includes[name].update({"data/design_pack_cast.json", "data/design_pack_assets.json", "data/design_pack_ecology.json"})
    # Root scripts use dynamic zone loading. Exclude transferred resources from
    # dependency expansion as well as from explicit selections.
    for name, section in sections.items():
        exclusions = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        exclusions.update(source.removeprefix("res://") for source in forest)
        forest_pattern = "assets_external/environment/prepared/forest_tree_*.res"
        if name == "Runtime Pack Opening":
            exclusions.discard(forest_pattern)
            for record in forest.values():
                exclusions.discard(record["path"].removeprefix("res://"))
        else:
            exclusions.add(forest_pattern)
        # Art review derivatives are deliberately unapproved, high-density
        # inspection assets. They never belong to any production pack.
        exclusions.update({"art_review/*", "art_review/**/*"})
        if designs:
            # Retire previous bodies from delivery, not from recoverable source
            # history. Shared animation libraries remain explicitly owned above.
            for retired in ("characters_universal", "characters_ranger", "enemies", "monsters", "creatures", "animals"):
                prefix = f"assets_external/{retired}/"
                retained = {texture.removeprefix("res://") for texture, record in environment.items()
                            if texture.startswith("res://" + prefix)
                            and name == "Runtime Pack " + record["owner"].capitalize()}
                if retained:
                    # An environment mesh can still use one retired-family
                    # atlas. Keep that exact dependency, not the obsolete bodies.
                    exclusions.discard(prefix + "*")
                    exclusions.update(path.relative_to(PROJECT).as_posix()
                                      for path in (PROJECT / prefix).rglob("*")
                                      if path.is_file() and path.relative_to(PROJECT).as_posix() not in retained)
                else:
                    exclusions.add(prefix + "*")
            # Weapons share the old character directory; they are retained
            # equipment, not bodies, and still have live player/VFX consumers.
            exclusions.discard("assets_external/characters/*")
            for body in (PROJECT / "assets_external/characters").rglob("*"):
                if body.suffix.lower() in {".fbx", ".gltf", ".glb", ".obj"} and body.stem not in {"Sword", "Ranger_Bow", "Ranger_Arrow"}:
                    exclusions.add(body.relative_to(PROJECT).as_posix())
            exclusions.add("assets/companions/*")
            for relative, destination in design_owners.items():
                if name == destination and relative not in standalone_sources:
                    exclusions.discard(relative)
                else:
                    exclusions.add(relative)
        for texture, record in environment.items():
            relative = texture.removeprefix("res://")
            if name == "Runtime Pack " + record["owner"].capitalize():
                exclusions.discard(relative)
            else:
                exclusions.add(relative)
        if name != "Runtime Pack Opening":
            exclusions.add(SILHOUETTE_DIRECTORY + "*")
        else:
            exclusions.discard(SILHOUETTE_DIRECTORY + "*")
        if name not in ROOT_NAMES:
            exclusions.update({"scripts/systems/*", "scripts/hud/*"})
            exclusions.add("data/native_attack_profiles.json")
            exclusions.add("data/prepared_forest_trees.json")
        else:
            exclusions.discard("data/native_attack_profiles.json")
        if name in {"Web Browser", "Web QA Browser"}:
            exclusions.discard(CHAPTER_ART)
        else:
            exclusions.add(CHAPTER_ART)
        if name == "Runtime Pack Opening":
            exclusions.discard(SAGA_OPENING_RECORD)
            exclusions.discard(FORGE_HAMMER)
            exclusions.discard(HUNTING_ARROW)
            exclusions.discard(living_station_directory + "*")
            exclusions.discard(drying_leaves)
        else:
            exclusions.add(SAGA_OPENING_RECORD)
            exclusions.add(FORGE_HAMMER)
            exclusions.add(HUNTING_ARROW)
            exclusions.add(living_station_directory + "*")
            exclusions.add(drying_leaves)
        # Imported GLTF scenes already contain these vertex/skin buffers. Godot
        # loads the imported scene at runtime, never the source GLTF .bin files.
        # Keep originals in the repository, not duplicated in delivery packs.
        for directory in ("characters_universal", "characters_ranger"):
            exclusions.add(f"assets_external/{directory}/*.bin")
            exclusions.add(f"assets_external/{directory}/runtime/*.bin")
        exclusions.add("assets/audio/prepared_bank.res")
        exclusions.update({"assets/audio/prepared/opening/music_wychwood_tension.res", "assets/audio/prepared/opening/music_ghoulkin_combat.res"})
        for audio_owner in ("menu", "opening", "adjacent", "campaign"):
            expected = ROOT_NAMES if audio_owner == "menu" else {"Runtime Pack " + audio_owner.capitalize()}
            if name not in expected:
                exclusions.add(f"assets/audio/prepared/{audio_owner}/*")
        if name in ROOT_NAMES:
            exclusions.update(transfers)
            exclusions.update({"data/dialogue.json", "data/campaign_dialogue.json", "data/interaction_scenes.json"})
            exclusions.add("assets_external/environment/prepared/*")
            exclusions.add("assets_external/characters_prepared/*")
        if name == "Runtime Pack Campaign":
            exclusions.add("assets_external/environment/prepared/greyfen_*")
            exclusions.add("assets_external/environment/prepared/wychwood_*")
        exclusions.discard("assets_external/characters_prepared/animations/*")
        for animation_path, owners in animation_owners.items():
            owner = "opening" if "opening" in owners else ("characters" if "characters" in owners else "monsters")
            relative = animation_path.removeprefix("res://")
            if name == "Runtime Pack " + owner.capitalize():
                exclusions.discard(relative)
            else:
                exclusions.add(relative)
        if name == "Runtime Pack Characters":
            exclusions.update(shared_opening_textures)
        if name == "Runtime Pack Monsters":
            exclusions.update(shared_character_textures)
        config[section]["include_filter"] = json.dumps(",".join(sorted(includes[name])))
        config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in sorted(files[name])) + ")"
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(exclusions)))
    # Move complete imported texture resources, never resample or recompress
    # their pixels. The opening mounts only after this dependency is ready.
    material_files = set()
    runtime_assets = json.loads((PROJECT / "runtime_asset_manifest.json").read_text(encoding="utf-8-sig"))
    for role, record in runtime_assets.get("roles", {}).items():
        asset_id = record.get("design_id")
        if designs.get("assets", {}).get(asset_id, {}).get("owner") != "opening":
            continue
        for resource in record.get("runtime_files", []):
            resource_path = resource["path"]
            if resource_path.startswith("res://assets_external/design_pack_v1/") and Path(resource_path).suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
                if not (PROJECT / resource_path.removeprefix("res://")).is_file():
                    raise ValueError(f"Opening material is missing: {role}: {resource_path}")
                material_files.add(resource_path)
    if not material_files:
        raise ValueError("Opening material partition has no declared texture resources")
    for name, section in sections.items():
        selected = set(selected_files(config[section]["export_files"]))
        included = set(json.loads(config[section]["include_filter"]).split(",")) - {""}
        excluded = set(json.loads(config[section]["exclude_filter"]).split(",")) - {""}
        if name == materials:
            selected = material_files.copy()
            included.clear()
        else:
            selected.difference_update(material_files)
        for resource_path in material_files:
            relative = resource_path.removeprefix("res://")
            included.discard(relative)
            if name == materials:
                excluded.discard(relative)
            else:
                excluded.add(relative)
        config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in sorted(selected)) + ")"
        config[section]["include_filter"] = json.dumps(",".join(sorted(included)))
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))
    manifest_path = PROJECT / "runtime_pack_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    published_actor_paths = list(manifest.get("actor_resource_owners", {}))
    manifest["packs"].setdefault("leisure", {
        "id":"leisure", "filename":"leisure.pck", "url":"packs/leisure.pck",
        "version":"pending-build", "sha256":"", "bytes":0, "entry_scene":"",
        "preload_priority":30, "status":"awaiting_source_aligned_build",
        "required_at_startup":False, "dependencies":["base"],
        "contents":["optional_inspection_fishing_cooking"],
    })
    manifest.setdefault("pack_presets", {})["leisure"] = leisure
    for name, section in sections.items():
        excluded = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        included = set(json.loads(config[section].get("include_filter", '""')).split(",")) - {""}
        if name == leisure:
            included = set()
            excluded.discard("assets/everyday/*")
            resources = sorted("res://" + p.relative_to(PROJECT).as_posix()
                               for p in (PROJECT / "assets/everyday").glob("*.glb"))
            config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in resources) + ")"
        else:
            excluded.add("assets/everyday/*")
            included.discard("assets/everyday/*.glb")
        config[section]["include_filter"] = json.dumps(",".join(sorted(included)))
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))
    manifest["packs"].setdefault("adjacent", {
        "version": "pending-build", "url": "", "sha256": "", "bytes": 0,
        "entry_scene": "", "dependencies": ["base", "opening"],
        "preload_priority": 15, "status": "awaiting_source_aligned_build",
        "contents": ["wychwood", "cemetery_layers", "ruins"],
    })
    manifest["packs"]["opening"]["contents"] = ["greyfen", "opening_actors", "shared_opening_scenery"]
    manifest["packs"].setdefault("opening_materials", {
        "version": "pending-build", "url": "", "sha256": "", "bytes": 0,
        "entry_scene": "", "dependencies": ["base"], "preload_priority": 5,
        "status": "awaiting_source_aligned_build", "contents": ["opening_character_textures"],
    })
    dependencies = manifest["packs"]["opening"].setdefault("dependencies", [])
    if "opening_materials" not in dependencies:
        dependencies.append("opening_materials")
    # Register the new consumer before assigning shared texture dependencies.
    manifest["packs"].setdefault("masonry", {"id": "masonry", "dependencies": ["base", "opening"]})
    for record in environment.values():
        for consumer in record["consumers"]:
            if consumer != record["owner"]:
                dependencies = manifest["packs"][consumer].setdefault("dependencies", [])
                if record["owner"] not in dependencies:
                    dependencies.append(record["owner"])
    if shared_character_textures:
        dependencies = manifest["packs"]["monsters"].setdefault("dependencies", [])
        if "characters" not in dependencies:
            dependencies.append("characters")
    for owners in animation_owners.values():
        owner = "opening" if "opening" in owners else ("characters" if "characters" in owners else "monsters")
        for consumer in owners:
            if consumer != owner:
                dependencies = manifest["packs"][consumer].setdefault("dependencies", [])
                if owner not in dependencies:
                    dependencies.append(owner)
    manifest.setdefault("pack_presets", {})["adjacent"] = adjacent
    manifest["pack_presets"]["opening_materials"] = materials
    manifest["pack_presets"]["quality_materials"] = "Runtime Pack Quality Materials"
    partition_actor_packs(PROJECT, config, sections, manifest, prepared_catalog, standalone_sources)
    partition_living_campaign_packs(PROJECT, config, sections, manifest,
                                    require_prepared_companion=not defer_environment)
    # Actor partitioning can create presets and replace inherited exclusion
    # sets. Reapply the forest ownership boundary to the final preset set too.
    for name, section in sections.items():
        excluded = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        for relative, owner_name in trail_props.items():
            if name == owner_name:
                excluded.discard(relative)
            else:
                excluded.add(relative)
        excluded.update(source.removeprefix("res://") for source in forest)
        forest_pattern = "assets_external/environment/prepared/forest_tree_*.res"
        if name == "Runtime Pack Opening":
            excluded.discard(forest_pattern)
        else:
            excluded.add(forest_pattern)
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))
    # Apply after actor partitioning too: it creates presets and replaces some
    # inherited filters. No subsequent pass may resurrect these stale imports.
    retire_environment_export_roots(PROJECT, config, sections)
    partition_road_masonry(config, sections, manifest, environment)
    partition_opening_dialogue(PROJECT, config, sections, manifest)
    partition_novel_pack(PROJECT, config, sections, manifest)
    # Set traversal in the partitioners must not reorder the published manifest.
    owners = manifest["actor_resource_owners"]
    retained = [path for path in published_actor_paths if path in owners]
    manifest["actor_resource_owners"] = {
        path: owners[path] for path in retained + sorted(owners.keys() - set(retained))
    }
    # Validate the complete generated graph before either tracked output changes.
    require_valid_pack_graph(manifest)
    with presets_path.open("w", encoding="utf-8", newline="\n") as output:
        config.write(output, space_around_delimiters=False)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(sections)} export presets with an adjacent-world pack")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--defer-environment", action="store_true")
    parser.add_argument("--require-prepared-forest", action="store_true")
    args = parser.parse_args()
    compile_layout(args.defer_environment, args.require_prepared_forest)
