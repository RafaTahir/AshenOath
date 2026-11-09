"""Copy only measured Stage2 inputs and their selected import byte closure.

The canonical game is read-only. Existing differing destination files stop the
copy, so this tool cannot overwrite another agent's isolated authored work.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from living_cast_stage2_profiles import PROFILES

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1] / "outputs/AshenOathTheRoadBetweenCrowns"


def main(source, copy, source_only, asset=None):
    catalog = json.loads((GAME / "data/prepared_actors.json").read_text())
    designs = json.loads((GAME / "data/design_pack_assets.json").read_text())["assets"]
    required = set()
    expected = {}
    selected = {}
    for identity in ([asset] if asset else PROFILES):
        production = designs[identity]["path"]
        required.add(production)
        expected[production] = designs[identity]["sha256"]
        candidates = [row for row in catalog.values() if row.get("source") == production]
        if not candidates:
            raise ValueError("Missing prepared retained actor: " + identity)
        # Exporter takes the first retained alias; same canonical body metadata
        # and variant-safe prepared scene are preserved without rebuilding.
        row = candidates[0]
        selected[identity] = row["path"]
        if not source_only:
            required.add(row["path"])
            expected[row["path"]] = row["compiled_sha256"]
        required.update(row.get("resource_dependencies", []))
        required.update(row.get("animation_resources", []))
        required.update(row.get("source_scene_dependencies", []))
    required.add("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
    if asset == "P01":
        # The player-only native gate exercises the actual bow hand/back
        # transfer and arrow visual. Keep their exact selected import closure.
        for resource in ("res://assets_external/characters/Ranger_Bow.fbx",
                         "res://assets/characters/kael_arrow.glb"):
            required.add(resource)
            required.add(resource + ".import")
    for name in (() if asset == "P01" else ("Banner_1_Cloth.obj", "Crate_Wooden.obj", "Book_7.obj", "Scroll_1.obj", "Mug.gltf", "Mug.bin")):
        required.add("res://assets_external/environment/props/" + name)
    visited = {}
    pending = list(sorted(required))
    while pending:
        resource = pending.pop(0)
        if resource in visited:
            continue
        if not resource.startswith("res://"):
            raise ValueError("Only retained project resources are allowed: " + resource)
        relative = Path(resource[6:])
        path = (source/relative).resolve()
        target = (GAME/relative).resolve()
        if not path.is_relative_to(source.resolve()) or not target.is_relative_to(GAME.resolve()):
            raise ValueError("Input closure escapes its explicit project roots")
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if resource in expected and digest != expected[resource]:
            raise ValueError("Canonical bytes differ from isolated source catalog: " + resource)
        visited[resource] = {"resource": resource, "bytes": len(data), "sha256": digest}
        if target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError("Refusing to overwrite different isolated bytes: " + resource)
        suffix = path.suffix.lower()
        if suffix in (".tres", ".tscn", ".import"):
            pending.extend(re.findall(r'path="(res://[^\"]+)"', data.decode("utf-8-sig")))
        if suffix in (".png", ".jpg", ".jpeg", ".webp"):
            importer = path.with_name(path.name + ".import")
            if not importer.is_file():
                raise ValueError("Retained texture import recipe is missing: " + resource)
            pending.append(resource + ".import")
        if suffix == ".gltf":
            document = json.loads(data)
            # The authored cup retains exact mesh buffers, replacing its old
            # trim-atlas material. It does not import unused 4K source images.
            for item in document.get("buffers", []):
                uri = item.get("uri", "")
                if uri and not uri.startswith("data:"):
                    pending.append("res://" + (relative.parent / uri).as_posix())
        if suffix == ".obj":
            for line in data.decode("utf-8-sig").splitlines():
                if line.startswith("mtllib "):
                    pending.append("res://" + (relative.parent / line[7:].strip()).as_posix())
        # Imported OBJ materials are replaced by the authored palette. Their
        # MTL remains provenance but unused MTL texture libraries are excluded.
    if copy:
        for row in visited.values():
            relative = Path(row['resource'][6:])
            target = GAME/relative
            if not target.exists():
                data = (source/relative).read_bytes()
                if hashlib.sha256(data).hexdigest() != row['sha256']:
                    raise ValueError('Retained input changed during bounded copy: '+row['resource'])
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
    result = {"schema_version": 1, "source_read_only": str(source), "isolated_game": str(GAME),
              "copied": copy, "prepared_actor_inputs": selected, "files": list(visited.values()),
              "total_bytes": sum(row["bytes"] for row in visited.values()),
              "full_cache_copied": False, "prepared_actors_deferred": source_only,
              "unused_material_textures_omitted": "Mug and OBJ source trim materials are replaced by the authored palette; exact geometry buffers/MTL provenance are retained."}
    output = ROOT / "evidence/living_cast_stage2_20261107/input_closure.json"
    if asset:
        output = ROOT / ("evidence/living_assets_stage3_20261107/player/input_closure.json" if asset == "P01" else "evidence/living_cast_stage2_20261107/input_closure_"+asset+".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"files": len(visited), "bytes": result["total_bytes"], "copied": copy,
                      "selected_import_cache_files": sum("/.godot/" in row["resource"] for row in visited.values())}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-game", required=True, type=Path)
    parser.add_argument("--copy", action="store_true")
    parser.add_argument("--source-only", action="store_true")
    parser.add_argument("--asset", choices=[*PROFILES, "P01"])
    args = parser.parse_args()
    main(args.source_game, args.copy, args.source_only, args.asset)
