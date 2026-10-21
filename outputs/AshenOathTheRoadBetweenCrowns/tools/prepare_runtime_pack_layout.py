"""Compile non-overlapping export selections from the existing runtime presets.

This is packaging, not a runtime resource fallback. Original source assets stay
in the project; each selected path is transferred to its owning pack.
"""

import configparser
import fnmatch
import json
from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
ROOT_NAMES = {"Web Browser", "Web QA Browser", "Runtime Pack Base"}
SAGA_OPENING_RECORD = "assets_external/environment/props/CampaignRecord_register_mira_Authored.res"
CHAPTER_ART = "assets/ui/story_chapters_atlas.png"
FORGE_HAMMER = "assets/characters/forge_hammer.tscn"
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


def compile_layout():
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
        includes[name].update({"data/runtime_dialogue_index.json", "data/runtime_dialogue/*.json"})
        includes[name].update({"assets/ui/fonts/*.ttf", "assets/ui/fonts/OFL.txt"})
    # Optional chapter illustrations never gate the usable menu or first control.
    # Keep one owner; the unchanged Greyfen menu artwork is still root-resident.
    for name in sections:
        includes[name].discard(CHAPTER_ART)
        files[name].discard("res://" + CHAPTER_ART)
    includes["Runtime Pack Campaign"].add(CHAPTER_ART)
    includes["Runtime Pack Opening"].add("assets_external/environment/prepared/greyfen_*.res")
    files["Runtime Pack Opening"].add("res://" + FORGE_HAMMER)
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
    includes["Runtime Pack Opening"].add("assets_external/characters_prepared/animations/*.res")
    for name in ROOT_NAMES:
        includes[name].add("data/prepared_actors.json")
        includes[name].add("data/prepared_static_batches.res")
        includes[name].update({"data/prepared_audio.json", "assets/audio/prepared/menu/*.res"})
    includes["Runtime Pack Opening"].add("assets/audio/prepared/opening/*.res")
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
    # Root scripts use dynamic zone loading. Exclude transferred resources from
    # dependency expansion as well as from explicit selections.
    for name, section in sections.items():
        exclusions = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
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
        for audio_owner in ("menu", "opening", "campaign"):
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
        if name in {"Runtime Pack Characters", "Runtime Pack Monsters"}:
            exclusions.add("assets_external/characters_prepared/animations/*")
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
    if shared_character_textures:
        dependencies = manifest["packs"]["monsters"].setdefault("dependencies", [])
        if "characters" not in dependencies:
            dependencies.append("characters")
    manifest.setdefault("pack_presets", {})["adjacent"] = adjacent
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(sections)} export presets with an adjacent-world pack")


if __name__ == "__main__":
    compile_layout()
