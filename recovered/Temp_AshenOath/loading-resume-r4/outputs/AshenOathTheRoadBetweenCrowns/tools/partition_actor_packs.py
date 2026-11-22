"""Partition existing compiled actors without changing their bytes or catalog IDs.

Called only by the pack layout compiler. The catalog supplies transitive resource
closure; the authored destination declaration supplies potential actor presence.
"""

import fnmatch
import json
import re


ACTOR_TEXTURE_DIRECTORIES = (
    "assets_external/design_pack_v1/humans/textures/",
    "assets_external/design_pack_v1/creatures/textures/",
)
ACTOR_IMAGE_DIRECTORIES = tuple(path.removesuffix("textures/") for path in ACTOR_TEXTURE_DIRECTORIES)
TEXTURE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def retired_actor_textures(project, resources, selections):
    """Retire stale selectors, preserving compiled, declared and direct users.

    Actor atlases belong to the current dependency ledger. Earlier exports left
    old exact selectors behind when an actor switched to a new atlas. Keep the
    editable files, but stop exporting atlases with no remaining consumer.
    """
    def managed(path):
        return path.removeprefix("res://").startswith(ACTOR_IMAGE_DIRECTORIES)

    candidates = {path for path in selections if managed(path)
                  and any(path.lower().endswith(suffix) for suffix in TEXTURE_SUFFIXES)
                  and not any(c in path for c in "*?[")}
    for directory in ACTOR_IMAGE_DIRECTORIES:
        candidates.update("res://" + path.relative_to(project).as_posix()
                          for path in (project / directory).rglob("*")
                          if path.is_file() and path.suffix.lower() in TEXTURE_SUFFIXES)
    protected = set(resources)
    environment_path = project / "data/environment_material_dependencies.json"
    if environment_path.is_file():
        protected.update(json.loads(environment_path.read_text(encoding="utf-8-sig"))["textures"])
    # Direct runtime loads are outside the compiled actor dependency graph.
    # A directory literal with computed filenames makes the namespace ambiguous;
    # conservatively keep that directory until its users have a resource ledger.
    literal = re.compile(r'''["']([^"'\r\n]+)["']''')
    values = set()
    computed_prefixes = set()
    for script in (project / "scripts").rglob("*.gd"):
        text = script.read_text(encoding="utf-8-sig")
        for match in literal.finditer(text):
            value = match.group(1)
            values.add(value)
            relative = value.removeprefix("res://")
            if not relative.startswith(ACTOR_IMAGE_DIRECTORIES):
                continue
            if not (relative.endswith("/") or "%" in relative or "{" in relative):
                continue
            # Family classification is not a computed filename. Other uses of
            # a directory/template are conservatively treated as live loaders.
            context = text[max(0, match.start() - 40):match.start()]
            if re.search(r"\.(?:begins_with|ends_with|contains|trim_prefix|trim_suffix)\(\s*$", context):
                continue
            computed_prefixes.add(re.split(r"[%{]", relative, maxsplit=1)[0])
    ambiguous = tuple(computed_prefixes)
    for path in candidates:
        relative = path.removeprefix("res://")
        if path in values or relative.rsplit("/", 1)[-1] in values or (ambiguous and relative.startswith(ambiguous)):
            protected.add(path)
    return candidates - protected


def partition_actor_packs(project, config, sections, manifest, catalog, standalone):
    designs = json.loads((project / "data/design_pack_assets.json").read_text(encoding="utf-8-sig"))["assets"]
    requirements = json.loads((project / "data/zone_actor_requirements.json").read_text(encoding="utf-8-sig"))
    sources = {record["path"]: key for key, record in designs.items()}
    resources = {}
    roles = {}
    for actor in catalog.values():
        asset = sources.get(actor["source"])
        if asset is None:
            raise ValueError("Prepared actor has no destination identity: " + actor["source"])
        pack = "actor_" + asset.lower()
        roles[actor["role"]] = pack
        paths = {actor["path"], *actor["resource_dependencies"], *actor["animation_resources"]}
        if actor["source"].removeprefix("res://") not in standalone:
            paths.add(actor["source"])
        for path in paths:
            resources.setdefault(path, set()).add(pack)
    runtime = json.loads((project / "runtime_asset_manifest.json").read_text(encoding="utf-8-sig"))
    for record in runtime["roles"].values():
        asset = record.get("design_id")
        if asset not in designs:
            continue
        for resource in record.get("runtime_files", []):
            path = resource["path"]
            if path.removeprefix("res://") not in standalone:
                resources.setdefault(path, set()).add("actor_" + asset.lower())
    owners = {path: next(iter(users)) if len(users) == 1 else "actor_shared"
              for path, users in resources.items()}
    pack_ids = sorted(set(owners.values()))
    template = dict(config[sections["Runtime Pack Monsters"]])
    for pack_id in pack_ids:
        name = "Runtime Pack " + pack_id
        if name not in sections:
            index = max(int(s.split(".")[1]) for s in config.sections() if "." in s) + 1
            section = "preset." + str(index)
            sections[name] = section
            config[section] = dict(template)
            config[section]["name"] = json.dumps(name)
            config[section + ".options"] = {"variant/extensions_support": "false"}
        dependencies = ["base"]
        if pack_id != "actor_shared" and any(pack_id in users and owners[path] == "actor_shared" for path, users in resources.items()):
            dependencies.append("actor_shared")
        record = manifest["packs"].setdefault(pack_id, {
            "version": "pending-build", "url": "", "bytes": 0, "sha256": "",
            "entry_scene": "", "status": "awaiting_source_aligned_build", "preload_priority": 20,
        })
        record["dependencies"] = dependencies
        record["contents"] = sorted(p for p, owner in owners.items() if owner == pack_id)
        manifest["pack_presets"][pack_id] = name

    excluded_sources = {"res://" + path for path in standalone}
    actor_paths = set(resources) | excluded_sources
    prior_selections = set()
    for section in sections.values():
        encoded = config[section].get("export_files", "PackedStringArray()")
        prior_selections.update(json.loads("[" + encoded.removeprefix("PackedStringArray(").removesuffix(")") + "]"))
        prior_selections.update("res://" + path.removeprefix("res://")
                                for path in json.loads(config[section].get("include_filter", '""')).split(",") if path)
    retired_textures = retired_actor_textures(project, resources, prior_selections)
    for name, section in sections.items():
        encoded = config[section].get("export_files", "PackedStringArray()")
        selected = set(json.loads("[" + encoded.removeprefix("PackedStringArray(").removesuffix(")") + "]"))
        included = set(json.loads(config[section].get("include_filter", '""')).split(",")) - {""}
        excluded = set(json.loads(config[section].get("exclude_filter", '""')).split(",")) - {""}
        pack_id = name.removeprefix("Runtime Pack ")
        selected.difference_update(actor_paths)
        selected.difference_update(retired_textures)
        for path in retired_textures:
            relative = path.removeprefix("res://")
            included.discard(relative)
            excluded.add(relative)
        # Broad compiled-actor selectors would resurrect already partitioned
        # scenes; selecting each catalog path also omits stale compiler outputs.
        included = {p for p in included if not p.startswith("assets_external/characters_prepared/")}
        if pack_id in pack_ids:
            selected = {p for p, owner in owners.items() if owner == pack_id}
            included.clear()
            excluded = {"art_review/*", "art_review/**/*", "scripts/*", "data/*"}
            excluded.update(path.removeprefix("res://") for path in retired_textures)
        for path in actor_paths:
            relative = path.removeprefix("res://")
            included.discard(relative)
            if owners.get(path) == pack_id:
                # Remove inherited blanket filters only for the dedicated pack.
                excluded = {p for p in excluded if not fnmatch.fnmatchcase(relative, p)}
                selected.add(path)
            else:
                excluded.add(relative)
        config[section]["export_files"] = "PackedStringArray(" + ", ".join(json.dumps(p) for p in sorted(selected)) + ")"
        config[section]["include_filter"] = json.dumps(",".join(sorted(included)))
        config[section]["exclude_filter"] = json.dumps(",".join(sorted(excluded)))

    # These were the same character textures now assigned to their actor owner.
    # Retire the empty transport rather than ship a dummy PCK or duplicate pixels.
    old_materials = "Runtime Pack Opening Materials"
    if old_materials in sections:
        section = sections[old_materials]
        if config[section]["export_files"] != "PackedStringArray()" or config[section]["include_filter"] != '""':
            raise ValueError("Opening Materials still has resources; cannot retire its ownership")
        config.remove_section(section)
        config.remove_section(section + ".options")
        sections.pop(old_materials)
        manifest["packs"].pop("opening_materials", None)
        manifest["pack_presets"].pop("opening_materials", None)
        for record in manifest["packs"].values():
            record["dependencies"] = [p for p in record.get("dependencies", []) if p != "opening_materials"]
    manifest["packs"]["opening"]["contents"] = ["greyfen", "shared_opening_scenery", "opening_audio"]

    ecology = json.loads((project / "data/design_pack_ecology.json").read_text(encoding="utf-8-sig"))
    zones = {}
    for zone, actors in requirements["zones"].items():
        actors = set(actors) | set(requirements["shared"])
        actors.update(row["design"] for row in ecology["sightings"] if row["zone"] == zone)
        unknown = actors - set(designs)
        if unknown:
            raise ValueError(f"Unknown actors in {zone}: {sorted(unknown)}")
        environment = ["base", "opening"]
        if zone in {"wychwood", "cemetery", "ruins"}:
            environment.append("adjacent")
        elif zone != "greyfen":
            environment.append("campaign")
        zones[zone] = environment + ["actor_" + asset.lower() for asset in sorted(actors)]
    zones["long_road"] = zones["bandit_road"]
    manifest["zone_dependencies"] = zones
    manifest["actor_packs"] = roles
    manifest["actor_resource_owners"] = owners
    manifest["startup_dependencies"] = zones["greyfen"]

    # Godot stops reading presets at the first missing numeric index.
    # Removing the retired transport must not hide later actor presets.
    presets = [(name, dict(config[section]), dict(config[section + ".options"]))
               for name, section in sorted(sections.items(), key=lambda row: int(row[1].split(".")[1]))]
    for section in list(config.sections()):
        if section.startswith("preset."):
            config.remove_section(section)
    sections.clear()
    for index, (name, settings, options) in enumerate(presets):
        section = "preset." + str(index)
        config[section] = settings
        config[section + ".options"] = options
        sections[name] = section
