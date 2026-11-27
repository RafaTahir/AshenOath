"""Select shared novel files and the field sets requested by their story gates."""

import fnmatch
import json


ACT_DIRECTORY = "data/novel/"
PROP_DIRECTORY = "assets/narrative_props/"
FIELD_DIRECTORY = PROP_DIRECTORY + "field/"
FIELD_RUNTIME = "scripts/novel/field_performances.gd"
PROP_CATALOG = PROP_DIRECTORY + "library.json"
ACT_FILES = {f"{ACT_DIRECTORY}act_{act}.json" for act in range(1, 5)}
# Exact closures of the five field scenes. Their textures are embedded in these
# resources; the three orchestration scripts under scripts/novel remain in base.
FIELD_PACK_FILES = {
    "novel_field_willow": {
        "willow.tscn", "willow_carry.tscn", "willow_stage.gd",
        "willow_surface.res", "willow_bank.res", "willow_loose.res",
        "willow_rigged.res", "willow_frame.res", "willow_oren.res",
        "willow_rest.res", "willow_porch.res", "willow_graves.res",
        "willow_lift_cloth.res",
    },
    "novel_field_gallery": {"gallery.tscn", "gallery.gd", "gallery_art.scn"},
    "novel_field_culvert": {
        "culvert.tscn", "culvert_carry.tscn", "culvert_stage.gd",
        "culvert_bank.res", "culvert_cart.res", "culvert_finish.res",
        "culvert_lever.res", "culvert_litter.res", "culvert_ward.res",
        "culvert_wreck.res",
    },
}
FIELD_PACK_PATHS = {pack: {FIELD_DIRECTORY + name for name in names}
                    for pack, names in FIELD_PACK_FILES.items()}
SOURCE_BOOK_FILTERS = {
    f"*AshenOath_The_Road_Between_Crowns.{extension}"
    for extension in ("docx", "epub", "md", "pdf")
}


def _is_novel_path(path):
    return path.removeprefix("res://").casefold().startswith((ACT_DIRECTORY, PROP_DIRECTORY))


def _matches(path, pattern):
    return fnmatch.fnmatchcase(path.casefold(), pattern.removeprefix("res://").casefold())


def _ensure_field_presets(config, sections, manifest):
    campaign = sections["Runtime Pack Campaign"]
    for pack_id in FIELD_PACK_PATHS:
        name = "Runtime Pack " + pack_id
        if name not in sections:
            index = max(int(section.split(".")[1]) for section in sections.values()) + 1
            section = "preset." + str(index)
            config[section] = dict(config[campaign])
            config[section]["name"] = json.dumps(name)
            config[section + ".options"] = dict(config[campaign + ".options"])
            sections[name] = section
        manifest["pack_presets"][pack_id] = name
        record = manifest["packs"].setdefault(pack_id, {
            "id": pack_id, "filename": pack_id + ".pck", "url": "packs/" + pack_id + ".pck",
            "version": "pending-build", "sha256": "", "bytes": 0, "entry_scene": "",
            "status": "awaiting_source_aligned_build", "preload_priority": 20,
        })
        record["dependencies"] = ["base"]
        record["required_at_startup"] = False
    # The runtime gate evaluates the selected save as well as live progression.
    # Geographic or startup dependencies would bypass that demand-only policy.
    field_ids = FIELD_PACK_PATHS.keys()
    for record in manifest["packs"].values():
        if "dependencies" in record:
            record["dependencies"] = [pack for pack in record["dependencies"] if pack not in field_ids]
    if "startup_dependencies" in manifest:
        manifest["startup_dependencies"] = [pack for pack in manifest["startup_dependencies"] if pack not in field_ids]
    for zone, dependencies in manifest.get("zone_dependencies", {}).items():
        manifest["zone_dependencies"][zone] = [pack for pack in dependencies if pack not in field_ids]


def partition_novel_pack(project, config, sections, manifest):
    # A resumed journey can be in any act while standing in Greyfen.
    # Opening is already required there and in every other playable zone.
    opening = manifest["pack_presets"]["opening"]
    if opening not in sections:
        raise ValueError(f"Novel owner export preset is missing: {opening}")
    present_acts = {path for path in ACT_FILES if (project / path).is_file()}
    if present_acts and present_acts != ACT_FILES:
        raise ValueError("Novel acts missing from the project: " + ", ".join(sorted(ACT_FILES - present_acts)))
    field_paths = set().union(*FIELD_PACK_PATHS.values())
    has_field = (
        (project / FIELD_RUNTIME).is_file()
        or any((project / path).is_file() for path in field_paths)
        or any(pack in manifest["pack_presets"] for pack in FIELD_PACK_PATHS)
    )
    if has_field:
        missing = sorted(path for path in field_paths if not (project / path).is_file())
        if missing:
            raise ValueError("Novel field resources missing from the project: " + ", ".join(missing))
        _ensure_field_presets(config, sections, manifest)
    props = {
        path.relative_to(project).as_posix()
        for path in (project / PROP_DIRECTORY).rglob("*.tscn")
        if path.is_file() and not path.relative_to(project).as_posix().startswith(FIELD_DIRECTORY)
    }
    catalog = {PROP_CATALOG} if (project / PROP_CATALOG).is_file() else set()
    other_novel_files = {
        path.relative_to(project).as_posix()
        for path in (project / ACT_DIRECTORY).rglob("*")
        if path.is_file()
    } - ACT_FILES

    field_presets = {manifest["pack_presets"][pack]: paths
                     for pack, paths in FIELD_PACK_PATHS.items() if has_field}
    for name, section in sections.items():
        preset = config[section]
        encoded = preset.get("export_files", "PackedStringArray()")
        files = json.loads("[" + encoded.removeprefix("PackedStringArray(").removesuffix(")") + "]")
        selected = {path for path in files if not _is_novel_path(path)}
        includes = {path for path in json.loads(preset.get("include_filter", '""')).split(",")
                    if path and not _is_novel_path(path)}
        excludes = set(json.loads(preset.get("exclude_filter", '""')).split(",")) - {""}
        if name in field_presets:
            owned = field_presets[name]
            # Dedicated presets have no inherited campaign roots or raw-file
            # filters. Selecting the complete closure also documents ownership.
            preset["export_filter"] = json.dumps("resources")
            selected = {"res://" + path for path in owned}
            includes.clear()
            excludes = {pattern for pattern in excludes
                        if not any(_matches(path, pattern) for path in owned)}
            excludes.update(field_paths - owned)
            excludes.update({ACT_DIRECTORY + "*", PROP_CATALOG} | props)
        elif name == opening:
            # JSON is read via FileAccess. Select scenes as resources so Godot
            # discovers their dependencies during export.
            includes.update(ACT_FILES | catalog)
            selected.update("res://" + path for path in props)
            excludes = {pattern for pattern in excludes if not (
                _is_novel_path(pattern) and any(
                    _matches(path, pattern)
                    for path in ACT_FILES | catalog | props
                )
            )}
            excludes.update(other_novel_files)
            excludes.add(FIELD_DIRECTORY + "*")
        else:
            excludes.update({ACT_DIRECTORY + "*", PROP_DIRECTORY + "*"})
        excludes.update(SOURCE_BOOK_FILTERS)
        preset["export_files"] = "PackedStringArray(" + ", ".join(map(json.dumps, sorted(selected))) + ")"
        preset["include_filter"] = json.dumps(",".join(sorted(includes)))
        preset["exclude_filter"] = json.dumps(",".join(sorted(excludes)))

    present = {"res://" + path for path in present_acts | catalog | props}
    for pack_id, pack in manifest["packs"].items():
        existing = pack.get("contents", [])
        if has_field and pack_id in FIELD_PACK_PATHS:
            pack["contents"] = sorted("res://" + path for path in FIELD_PACK_PATHS[pack_id])
        elif any(_is_novel_path(path) for path in existing) or (pack_id == "opening" and present):
            contents = {path for path in existing if not _is_novel_path(path)}
            if pack_id == "opening":
                contents.update(present)
            pack["contents"] = sorted(contents)
