"""Compile non-overlapping export selections from the existing runtime presets.

This is packaging, not a runtime resource fallback. Original source assets stay
in the project; each selected path is transferred to its owning pack.
"""

import argparse
import configparser
import fnmatch
import json
from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
ROOT_NAMES = {"Web Browser", "Web QA Browser", "Runtime Pack Base"}
SAGA_OPENING_RECORD = "assets_external/environment/props/CampaignRecord_register_mira_Authored.res"
CHAPTER_ART = "assets/ui/story_chapters_atlas.png"
FORGE_HAMMER = "assets/characters/forge_hammer.tscn"
SILHOUETTE_DIRECTORY = "assets/characters/silhouette/"
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


def compile_layout(defer_environment=False):
    path = PROJECT / "export_presets.cfg"
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read(path, encoding="utf-8-sig")
    sections = {json.loads(config[s]["name"]): s for s in config.sections()
                if "name" in config[s]}
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
    includes = {n: set(json.loads(config[s].get("include_filter", '""')).split(",")) - {""}
                for n, s in sections.items()}
    files = {n: set(selected_files(config[s].get("export_files", "PackedStringArray()")))
             for n, s in sections.items()}
    for name in ROOT_NAMES:
        includes[name].update({"scripts/systems/*.gd", "scripts/hud/*.gd", "scripts/systems/method_ownership.json"})
        files[name].update({
            "res://scripts/systems/character_silhouette.gd",
            "res://scripts/systems/character_palette.gd",
            "res://shaders/character_region_palette.gdshader",
            "res://scripts/spectral_monster_presentation.gd",
            "res://shaders/spectral_veil.gdshader",
            "res://data/spectral_monster_profiles.json",
        })
        includes[name].update({"data/runtime_dialogue_index.json", "data/runtime_dialogue/*.json"})
        includes[name].update({"assets/ui/fonts/*.ttf", "assets/ui/fonts/OFL.txt"})
    spectral_profiles = PROJECT / "data/spectral_monster_profiles.json"
    if spectral_profiles.exists():
        files["Runtime Pack Monsters"].update(json.loads(spectral_profiles.read_text())["assets"])
    # Optional chapter illustrations never gate the usable menu or first control.
    # Keep one owner; the unchanged Greyfen menu artwork is still root-resident.
    for name in sections:
        includes[name].discard(CHAPTER_ART)
        files[name].discard("res://" + CHAPTER_ART)
    includes["Runtime Pack Campaign"].add(CHAPTER_ART)
    includes["Runtime Pack Opening"].add("assets_external/environment/prepared/greyfen_*.res")
    # Touchable village details share retained source meshes, owned by opening.
    for prop in ("Dummy.obj", "Pot_1.obj", "Pot_1_Lid.obj"):
        relative = "assets_external/environment/props/" + prop
        includes["Runtime Pack Opening"].add(relative)
        for name in sections:
            if name != "Runtime Pack Opening":
                includes[name].discard(relative)
                files[name].discard("res://" + relative)
    files["Runtime Pack Opening"].add("res://" + FORGE_HAMMER)
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
    includes[adjacent].add("assets_external/environment/prepared/wychwood_*.res")
    includes["Runtime Pack Campaign"].add("assets_external/environment/prepared/*.res")
    for owner, name in (("opening", "Runtime Pack Opening"), ("characters", "Runtime Pack Characters"), ("monsters", "Runtime Pack Monsters")):
        includes[name].add(f"assets_external/characters_prepared/{owner}/*.scn")
    # Include filters copy generated scenes, but do not reliably expand their
    # imported texture dependencies. Select the recorded atlases as resources.
    actor_catalog = PROJECT / "data/prepared_actors.json"
    if actor_catalog.is_file():
        for actor in json.loads(actor_catalog.read_text(encoding="utf-8-sig")).values():
            pack = "Runtime Pack " + str(actor["owner"]).capitalize()
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
        if relative == FORGE_HAMMER:
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
        if not texture.startswith("res://assets_external/environment/") or not (PROJECT / texture.removeprefix("res://")).is_file():
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
            files[destination].add("res://" + relative)
        for name in ROOT_NAMES:
            includes[name].update({"data/design_pack_cast.json", "data/design_pack_assets.json", "data/design_pack_ecology.json"})
    # Root scripts use dynamic zone loading. Exclude transferred resources from
    # dependency expansion as well as from explicit selections.
    for name, section in sections.items():
        exclusions = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        if designs:
            # Retire previous bodies from delivery, not from recoverable source
            # history. Shared animation libraries remain explicitly owned above.
            for retired in ("characters_universal", "characters_ranger", "enemies", "monsters", "creatures", "animals"):
                exclusions.add(f"assets_external/{retired}/*")
            # Weapons share the old character directory; they are retained
            # equipment, not bodies, and still have live player/VFX consumers.
            exclusions.discard("assets_external/characters/*")
            for body in (PROJECT / "assets_external/characters").rglob("*"):
                if body.suffix.lower() in {".fbx", ".gltf", ".glb", ".obj"} and body.stem not in {"Sword", "Ranger_Bow", "Ranger_Arrow"}:
                    exclusions.add(body.relative_to(PROJECT).as_posix())
            exclusions.add("assets/companions/*")
            for relative, destination in design_owners.items():
                if name == destination:
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
        if name == "Runtime Pack Campaign":
            exclusions.discard(CHAPTER_ART)
        else:
            exclusions.add(CHAPTER_ART)
        if name == "Runtime Pack Opening":
            exclusions.discard(SAGA_OPENING_RECORD)
            exclusions.discard(FORGE_HAMMER)
        else:
            exclusions.add(SAGA_OPENING_RECORD)
            exclusions.add(FORGE_HAMMER)
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
    with path.open("w", encoding="utf-8", newline="\n") as output:
        config.write(output, space_around_delimiters=False)

    manifest_path = PROJECT / "runtime_pack_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    manifest["packs"].setdefault("adjacent", {
        "version": "pending-build", "url": "", "sha256": "", "bytes": 0,
        "entry_scene": "", "dependencies": ["base", "opening"],
        "preload_priority": 15, "status": "awaiting_source_aligned_build",
        "contents": ["wychwood", "cemetery_layers", "ruins"],
    })
    manifest["packs"]["opening"]["contents"] = ["greyfen", "opening_actors", "shared_opening_scenery"]
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
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(sections)} export presets with an adjacent-world pack")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--defer-environment", action="store_true")
    compile_layout(parser.parse_args().defer_environment)
