"""Validate the engine's exact-geometry receipt before retiring tree imports.

Authoring sources remain in the library. A missing or stale receipt cannot make
their imports disappear from delivery; the mandatory post-compile pass fails.
"""

import hashlib
import json
import shlex
from pathlib import Path, PurePosixPath


FOREST_ROOT = "res://assets_external/environment/forest/"
PREPARED_ROOT = "res://assets_external/environment/prepared/"
SOURCES = {
    FOREST_ROOT + stem + ".obj": PREPARED_ROOT + "forest_tree_" + stem + ".res"
    for stem in ("CommonTree_5", "TwistedTree_2", "TwistedTree_4")
}
COMPILERS = {
    "res://scripts/prepared_forest_trees.gd",
    "res://tools/build_prepared_zone_geometry.gd",
    "res://tools/prepared_zone_geometry_factory.gd",
}
CATALOG = "data/prepared_forest_trees.json"


def resource_file(project, path):
    if not isinstance(path, str) or not path.startswith("res://"):
        raise ValueError("Invalid forest resource path: " + str(path))
    relative = path.removeprefix("res://")
    if (not relative or "\\" in relative or ":" in relative
            or relative.startswith("/") or ".." in PurePosixPath(relative).parts):
        raise ValueError("Unsafe forest resource path: " + path)
    return Path(project) / relative


def fingerprint(path):
    payload = path.read_bytes()
    return {"bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}


def source_inputs(project, source):
    inputs = {source, source + ".import"}
    text = resource_file(project, source).read_text(encoding="utf-8-sig")
    for line in text.splitlines():
        if line.strip().startswith("mtllib "):
            for name in shlex.split(line.strip().removeprefix("mtllib ").strip()):
                material = source.rsplit("/", 1)[0] + "/" + name
                resource_file(project, material)
                inputs.add(material)
    if len(inputs) < 3:
        raise ValueError("Forest source material library is missing: " + source)
    return inputs


def load_prepared_forest_trees(project, required=True):
    """Return only complete, source-aligned, standalone engine receipts."""
    try:
        path = Path(project) / CATALOG
        catalog = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(catalog, dict) or set(catalog) != set(SOURCES):
            raise ValueError("Forest preparation must cover exactly the three approved trees")
        for source, prepared in SOURCES.items():
            row = catalog[source]
            if (row.get("contract_version") != 1 or row.get("source_path") != source
                    or row.get("path") != prepared):
                raise ValueError("Forest preparation identity mismatch: " + source)
            if row.get("source_scene_dependencies") != [] or row.get("resource_dependencies") != []:
                raise ValueError("Prepared forest mesh retains external dependencies: " + source)
            for field, expected in (("source_fingerprints", source_inputs(project, source)),
                                    ("compiler_fingerprints", COMPILERS)):
                recorded = row.get(field, {})
                if set(recorded) != expected:
                    raise ValueError("Incomplete forest preparation inputs: " + source + ": " + field)
                for dependency in expected:
                    if recorded[dependency] != fingerprint(resource_file(project, dependency)):
                        raise ValueError("Stale forest preparation input: " + dependency)
            compiled = fingerprint(resource_file(project, prepared))
            if (compiled["sha256"] != row.get("compiled_sha256")
                    or compiled["bytes"] != row.get("compiled_bytes")):
                raise ValueError("Stale prepared forest mesh: " + prepared)
            for field in ("source_geometry_sha256", "geometry_sha256", "material_sha256"):
                value = row.get(field, "")
                if len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
                    raise ValueError("Missing forest geometry/material proof: " + source)
            if row["source_geometry_sha256"] != row["geometry_sha256"]:
                raise ValueError("Prepared forest geometry differs from its source: " + source)
            if (not isinstance(row.get("surface_names"), list) or len(row["surface_names"]) < 2
                    or not isinstance(row.get("aabb"), list) or len(row["aabb"]) != 6):
                raise ValueError("Missing forest shape proof: " + source)
        return catalog
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        if required:
            raise ValueError("Required prepared forest geometry is missing or stale; run "
                             "build_prepared_zone_geometry.gd: " + str(error)) from error
        # The preliminary layout runs before imports/compilation. Keep source
        # selections intact until the mandatory proof-bearing pass succeeds.
        return {}
