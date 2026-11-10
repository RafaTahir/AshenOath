"""Reject QA-only content and missing current prepared-actor ownership."""
import configparser
import fnmatch
import json
from pathlib import Path

from runtime_pack_validation import require_valid_pack_graph


def selected_files(section):
    return set(json.loads("[" + section["export_files"].removeprefix("PackedStringArray(")[:-1] + "]"))


def filters(section, key):
    return set(json.loads(section.get(key, '""')).split(",")) - {""}


def selected(section, resource):
    relative = resource.removeprefix("res://")
    if any(fnmatch.fnmatchcase(relative, pattern) for pattern in filters(section, "exclude_filter")):
        return False
    return resource in selected_files(section) or any(
        fnmatch.fnmatchcase(relative, pattern) for pattern in filters(section, "include_filter"))


def validate_living_ownership(runtime, owners, production, qa):
    registry = runtime.get("community_resource_owners")
    if registry is None: return []
    if not isinstance(registry, dict) or not registry:
        return ["Living resource ownership registry must be a nonempty object"]
    errors = []
    for resource, owner in registry.items():
        if not isinstance(resource, str) or not resource.startswith("res://") or ".." in resource[6:].split("/"):
            errors.append("Invalid living resource path: " + str(resource))
            continue
        if not isinstance(owner, str) or owner not in owners:
            errors.append(f"Unknown living resource owner {owner}: {resource}")
            continue
        actual = {pack for pack, section in owners.items() if selected(section, resource)}
        if actual != {owner}: errors.append(f"Living resource {resource}: declared {owner}, selected by {sorted(actual)}")
        if owner != "base" and (selected(production, resource) or selected(qa, resource)):
            errors.append("Root PCK duplicates deferred living resource " + resource)
        if resource not in runtime["packs"][owner].get("contents", []):
            errors.append(f"{owner}: resource inventory omits {resource}")
        if str(owner).startswith("actor_") and runtime.get("actor_resource_owners", {}).get(resource) != owner:
            errors.append("Actor and living resource ownership disagree: " + resource)
    return errors


def validate(path):
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read(path, encoding="utf-8-sig")
    presets = {s.get("name", "").strip('"'): s for s in config.values()}
    production, qa = presets["Web Browser"], presets["Web QA Browser"]
    telemetry = "res://scripts/qa_browser_telemetry.gd"
    errors = []

    def check(valid, message):
        if not valid:
            errors.append(message)

    check(selected_files(qa) == selected_files(production) | {telemetry}, "QA explicit resources differ from production")
    check(filters(qa, "include_filter") == filters(production, "include_filter"), "QA includes extra runtime content")
    check(filters(qa, "exclude_filter") == filters(production, "exclude_filter") - {telemetry.removeprefix("res://")}, "QA exclusions differ beyond telemetry")
    check(not selected(production, telemetry) and selected(qa, telemetry), "QA telemetry ownership differs from the production exclusion contract")

    project = path.parent
    runtime = json.loads((project / "runtime_pack_manifest.json").read_text(encoding="utf-8-sig"))
    require_valid_pack_graph(runtime)
    owners = {pack_id: presets[runtime.get("pack_presets", {}).get(pack_id, "Runtime Pack " + pack_id.replace("_", " ").title())]
              for pack_id in runtime["packs"]}
    errors.extend(validate_living_ownership(runtime, owners, production, qa))
    actors = json.loads((project / "data/prepared_actors.json").read_text(encoding="utf-8-sig"))
    check(bool(actors), "Current prepared actor catalog is empty")
    declared_owners = runtime.get("actor_resource_owners")
    check(declared_owners is None or isinstance(declared_owners, dict), "Prepared actor ownership registry must be an object")
    for actor in actors.values():
        resource = actor["path"]
        # The catalog retains its compilation batch; partitioning declares the
        # current delivery owner. An explicit registry must cover every scene.
        owner = (declared_owners.get(resource) if isinstance(declared_owners, dict)
                 else actor["owner"] if declared_owners is None else None)
        if declared_owners is not None:
            check(owner is not None, f"Missing explicit prepared actor ownership: {resource}")
        check(isinstance(owner, str) and owner in owners and selected(owners[owner], resource), f"{owner}: missing current prepared actor {resource}")
        check(not selected(production, resource) and not selected(qa, resource), f"Root PCK duplicates deferred prepared actor {resource}")
        for other, section in owners.items():
            if other != owner and other != "base":
                check(not selected(section, resource), f"{other}: duplicates {owner} prepared actor {resource}")

    opening = owners["opening"]
    for prop in ["Bucket_Wooden_1.fbx", "Book_Simplified_Single.fbx", "Axe_Bronze.fbx"]:
        resource = "res://assets_external/environment/props/" + prop
        check(selected(opening, resource), f"Opening pack lacks staged equipment: {resource}")
    for resource in ["res://assets/characters/kael_arrow.glb", "res://assets/characters/forge_hammer.tscn"]:
        check(selected(opening, resource), f"Opening pack lacks current held equipment: {resource}")
    check(any(p.startswith("assets_external/environment/") for p in filters(opening, "include_filter")), "Opening pack owns no environment content")
    check("assets_external/textures/runtime/*_albedo.jpg" in filters(opening, "include_filter"), "Opening pack lacks lightweight albedo materials")
    check("assets_external/textures/runtime/grass_tuft.png" in filters(opening, "include_filter"), "Opening pack lacks foliage texture")
    for pattern in ["assets_external/textures/runtime/*_normal.jpg", "assets_external/textures/runtime/*_orm.jpg"]:
        check(pattern not in filters(opening, "include_filter"), f"Opening pack owns optional quality maps: {pattern}")
        check(pattern in filters(owners["quality_materials"], "include_filter"), f"Quality pack lacks {pattern}")
    if errors:
        raise ValueError("; ".join(dict.fromkeys(errors)))


if __name__ == "__main__":
    try:
        validate(Path(__file__).resolve().parents[1] / "export_presets.cfg")
    except (OSError, ValueError, KeyError) as error:
        print(f"WEB PRESET PARITY: FAIL - {error}")
        raise SystemExit(1)
    print("WEB PRESET PARITY: PASS (current catalog and static resource selection only)")
