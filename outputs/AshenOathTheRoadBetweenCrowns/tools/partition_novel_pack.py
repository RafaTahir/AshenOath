"""Select the novel's runtime files for the pack shared by every playable zone."""

import fnmatch
import json


ACT_DIRECTORY = "data/novel/"
PROP_DIRECTORY = "assets/narrative_props/"
PROP_CATALOG = PROP_DIRECTORY + "library.json"
ACT_FILES = {f"{ACT_DIRECTORY}act_{act}.json" for act in range(1, 5)}
SOURCE_BOOK_FILTERS = {
    f"*AshenOath_The_Road_Between_Crowns.{extension}"
    for extension in ("docx", "epub", "md", "pdf")
}


def _is_novel_path(path):
    return path.removeprefix("res://").casefold().startswith((ACT_DIRECTORY, PROP_DIRECTORY))


def partition_novel_pack(project, config, sections, manifest):
    # A resumed journey can be in any act while standing in Greyfen.
    # Opening is already required there and in every other playable zone.
    opening = manifest["pack_presets"]["opening"]
    if opening not in sections:
        raise ValueError(f"Novel owner export preset is missing: {opening}")
    present_acts = {path for path in ACT_FILES if (project / path).is_file()}
    if present_acts and present_acts != ACT_FILES:
        raise ValueError("Novel acts missing from the project: " + ", ".join(sorted(ACT_FILES - present_acts)))
    props = {
        path.relative_to(project).as_posix()
        for path in (project / PROP_DIRECTORY).rglob("*.tscn")
        if path.is_file()
    }
    catalog = {PROP_CATALOG} if (project / PROP_CATALOG).is_file() else set()
    other_novel_files = {
        path.relative_to(project).as_posix()
        for path in (project / ACT_DIRECTORY).rglob("*")
        if path.is_file()
    } - ACT_FILES

    for name, section in sections.items():
        preset = config[section]
        encoded = preset.get("export_files", "PackedStringArray()")
        files = json.loads("[" + encoded.removeprefix("PackedStringArray(").removesuffix(")") + "]")
        selected = {path for path in files if not _is_novel_path(path)}
        includes = {path for path in json.loads(preset.get("include_filter", '""')).split(",")
                    if path and not _is_novel_path(path)}
        excludes = set(json.loads(preset.get("exclude_filter", '""')).split(",")) - {""}
        if name == opening:
            # JSON is read via FileAccess. Select scenes as resources so Godot
            # discovers their dependencies during export.
            includes.update(ACT_FILES | catalog)
            selected.update("res://" + path for path in props)
            excludes = {pattern for pattern in excludes if not (
                _is_novel_path(pattern) and any(
                    fnmatch.fnmatchcase(path.casefold(), pattern.removeprefix("res://").casefold())
                    for path in ACT_FILES | catalog | props
                )
            )}
            excludes.update(other_novel_files)
        else:
            excludes.update({ACT_DIRECTORY + "*", PROP_DIRECTORY + "*"})
        excludes.update(SOURCE_BOOK_FILTERS)
        preset["export_files"] = "PackedStringArray(" + ", ".join(map(json.dumps, sorted(selected))) + ")"
        preset["include_filter"] = json.dumps(",".join(sorted(includes)))
        preset["exclude_filter"] = json.dumps(",".join(sorted(excludes)))

    present = {"res://" + path for path in present_acts | catalog | props}
    for pack_id, pack in manifest["packs"].items():
        existing = pack.get("contents", [])
        if any(_is_novel_path(path) for path in existing) or (pack_id == "opening" and present):
            contents = {path for path in existing if not _is_novel_path(path)}
            if pack_id == "opening":
                contents.update(present)
            pack["contents"] = sorted(contents)
