"""Reject stale cast libraries using the authored and native compiler receipts.

This checks source/output identity, never visual or gameplay acceptance. Paths
in historical receipts may name a different checkout; resolve their identities
inside the supplied repository instead of opening those historical locations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import runpy
from pathlib import Path

ASSETS = ["C11", "C05", "C06", "C12", "C07", "C09", "C10", "C08", "P01"]
GAME = "outputs/AshenOathTheRoadBetweenCrowns"
ART = "art_source/art_recovery_v2"
STAGE2_PROPS = ["station_" + name for name in ("nessa", "elna", "toma", "nera", "vale", "merrow", "edric")] + ["merrow_cup"]
PROP_RESOURCES = "res://assets_external/environment_prepared/living_cast/"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def resource(game, value):
    if not isinstance(value, str) or not value.startswith("res://") or "\\" in value:
        raise ValueError("invalid resource identity")
    relative = Path(value[6:])
    result = (game / relative).resolve()
    if relative.is_absolute() or ".." in relative.parts or not result.is_relative_to(game.resolve()):
        raise ValueError("resource path escapes project")
    return result


def expected_clips(asset):
    clips = {"Life_Idle_A":6.0, "Life_Idle_B":8.0}
    if asset != "P01": clips.update(Life_Work=4.0, Life_Listen=4.0, Life_Speak=4.0)
    if asset == "C09": clips["Life_Settle_Ledger"] = 4.0
    if asset == "C10": clips.update(Life_Cup_Hold=4.0, Life_Drink=4.0)
    return clips


def model_matches_motion_source(repository, asset, model, original_sha):
    if digest(model) == original_sha:
        return True
    helper = repository / ART / "tools/face_repair_provenance.py"
    if not helper.is_file():
        return False
    resolver = runpy.run_path(str(helper))["resolve_model_successor"]
    game = repository / GAME
    source = "res://" + model.relative_to(game).as_posix()
    prepared = {row.get("path") for row in read(game / "data/prepared_actors.json").values()
                if row.get("source") == source}
    if len(prepared) != 1:
        return False
    successor = resolver(repository, asset, original_sha, prepared_path=prepared.pop())
    return successor is not None


def verify_asset(repository: Path, asset: str) -> dict:
    if asset not in ASSETS: raise ValueError("unknown living cast asset: " + asset)
    game, art = repository / GAME, repository / ART
    folder = art / "models" / ("living_assets_stage3_20261107/player" if asset == "P01" else "living_cast_stage2_20261107")
    source = folder / asset / (asset + "_life_review.glb")
    authored = read(folder / asset / "authoring.json")
    source_hash = digest(source)
    if authored.get("asset") != asset or authored.get("review_glb_sha256") != source_hash:
        raise ValueError("authored carrier hash differs from its receipt")
    blend_name = str(authored.get("blend", "")).replace("\\", "/").rsplit("/", 1)[-1]
    if not blend_name.endswith(".blend") or digest(folder / asset / blend_name) != authored.get("blend_sha256"):
        raise ValueError("editable Blender source differs from its receipt")
    recipes = authored.get("recipe_snapshot", {}).get("files", [])
    if not recipes: raise ValueError("immutable authoring recipe is missing")
    for recipe in recipes:
        relative = Path(str(recipe.get("path", "")).replace("\\", "/"))
        path = (art / relative).resolve()
        if relative.is_absolute() or ".." in relative.parts or not path.is_relative_to(art.resolve()):
            raise ValueError("recipe path escapes retained art sources")
        if digest(path) != recipe.get("sha256"):
            raise ValueError("archived recipe bytes differ: " + str(relative))
    output_resource = "res://assets_external/characters_prepared/animations/life_" + asset + ".res"
    output = resource(game, output_resource)
    output_hash = digest(output)
    candidates = []
    for receipt in sorted(folder.glob("library_compile_*.json")):
        document = read(receipt)
        if document.get("status") == "compiled":
            candidates.extend((receipt, row) for row in document.get("libraries", []) if row.get("asset") == asset)
    for receipt, row in candidates:
        if row.get("source_sha256") != source_hash or row.get("sha256") != output_hash or row.get("path") != output_resource:
            continue
        model = resource(game, row.get("model"))
        if row.get("model_sha256") != authored.get("production_sha256") \
                or not model_matches_motion_source(repository, asset, model, row.get("model_sha256")):
            raise ValueError("retained production actor differs from compiled source")
        if row.get("bytes") != output.stat().st_size: raise ValueError("compiled library size differs")
        error = row.get("maximum_rest_error")
        if not isinstance(error, (int, float)) or not math.isfinite(error) or not 0 <= error <= 0.0001:
            raise ValueError("retained rest-pose proof is missing or failed")
        expected, actual = expected_clips(asset), row.get("clips", {})
        if set(actual) != set(expected): raise ValueError("native clip inventory differs")
        for clip, duration in expected.items():
            value = actual[clip].get("duration")
            if not isinstance(value, (int, float)) or not math.isfinite(value) or abs(value-duration) > 0.001:
                raise ValueError("native clip duration differs: " + clip)
        return {"asset":asset, "source_sha256":source_hash, "output":output_resource,
                "output_sha256":output_hash, "receipt":receipt.relative_to(repository).as_posix(), "bytes":output.stat().st_size}
    raise ValueError("no native compiler receipt matches the current authored carrier and delivered library; rebuild required")


def _require_hash(path: Path, expected, label: str) -> None:
    if digest(path) != expected:
        raise ValueError(f"{label} hash differs: {path.name}")


def _verify_cup_inputs(game: Path, folder: Path, authored: dict, compiled: dict) -> None:
    calibration_hash = compiled.get("calibration_sha256")
    _require_hash(folder / "merrow_cup_calibration.json", calibration_hash, "Cup calibration")
    archive_name = f"merrow_cup_calibration_{calibration_hash}.json"
    archived = str(compiled.get("calibration_archive", "")).replace("\\", "/").rsplit("/", 1)[-1]
    if archived != archive_name:
        raise ValueError("Cup calibration archive identity differs from its compiler receipt")
    _require_hash(folder / "receipts" / archive_name, calibration_hash, "Archived cup calibration")
    _require_hash(game / "tools/build_merrow_cup.gd", compiled.get("compiler_sha256"), "Cup compiler")
    actor_folder = folder.parent / "C10"
    actor_source = compiled.get("actor_source_sha256")
    _require_hash(actor_folder / "C10_life_review.glb", actor_source, "Merrow motion carrier")
    actor = read(actor_folder / "authoring.json")
    if (not isinstance(actor, dict) or actor.get("review_glb_sha256") != actor_source
            or actor.get("baseline_sha256") != authored["baseline_sha256"]):
        raise ValueError("Cup and Merrow carriers do not share the recorded baseline")
    clearance_path = actor_folder / "source_cup_clearance.json"
    _require_hash(clearance_path, compiled.get("source_clearance_sha256"), "Cup source clearance")
    clearance = read(clearance_path)
    if (not isinstance(clearance, dict) or authored.get("grip_verified") is not True or authored.get("rim_calibrated") is not True
            or compiled.get("source_full_motion_clearance_verified") is not True
            or clearance.get("source_trajectory_clear") is not True or clearance.get("full_trajectory_sampled") is not True
            or clearance.get("actor_carrier_sha256") != actor_source or clearance.get("cup_carrier_sha256") != authored["carrier_sha256"]):
        raise ValueError("Cup compilation lacks current source calibration and clearance")


def verify_stage2_prop(repository: Path, asset: str) -> dict:
    if asset not in STAGE2_PROPS:
        raise ValueError("unknown Stage 2 prop: " + asset)
    game = repository / GAME
    folder = repository / ART / "models/living_cast_stage2_20261107/props"
    cup = asset == "merrow_cup"
    identity = "merrow" if cup else asset.removeprefix("station_")
    authored = read(folder / ("merrow_cup_calibration.json" if cup else asset + "_authoring.json"))
    receipt = folder / (asset + "_compile.json")
    compiled = read(receipt)
    if not isinstance(authored, dict) or not isinstance(compiled, dict):
        raise ValueError("Malformed prop authoring or compiler receipt")
    scene_resource = PROP_RESOURCES + asset + ".scn"
    if authored.get("identity") != identity or authored.get("runtime_resource") != scene_resource or compiled.get("path") != scene_resource:
        raise ValueError("Prop receipt identifies a different asset or scene")
    carrier = folder / ("merrow_cup_world.glb" if cup else asset + ".glb")
    source_hash = digest(carrier)
    if authored.get("carrier_sha256") != source_hash or compiled.get("source_sha256") != source_hash:
        raise ValueError("Authored carrier differs from the prop compiler receipt")
    sources = authored.get("sources")
    if not isinstance(sources, list):
        raise ValueError("Malformed retained prop source inventory")
    for source in sources:
        _require_hash(resource(game, source["resource"]), source["sha256"], "Retained prop source")
    scene = resource(game, scene_resource)
    _require_hash(scene, compiled.get("sha256"), "Compiled prop scene")

    if cup:
        _verify_cup_inputs(game, folder, authored, compiled)
        inline_count = compiled.get("inline_mesh_count")
        if type(inline_count) is not int or inline_count < 1:
            raise ValueError("Cup compiler receipt lacks inline meshes")
        components = []
    else:
        if (compiled.get("identity") != identity or compiled.get("geometry_contact_verified") is not True
                or compiled.get("support_bounds_verified") is not True):
            raise ValueError("Station compiler receipt lacks exact identity or geometry proof")
        components = compiled.get("resources")
        if not isinstance(components, list) or not components:
            raise ValueError("Station compiler receipt lacks component hashes")
        for index, component in enumerate(components):
            expected = PROP_RESOURCES + f"{asset}_{index:02d}.res"
            if component["path"] != expected:
                raise ValueError("Station compiler component inventory differs")
            _require_hash(resource(game, expected), component["sha256"], "Compiled station component")
    pattern = "merrow_cup*.res" if cup else asset + "_*.res"
    actual = {PROP_RESOURCES + path.name for path in scene.parent.glob(pattern)}
    if actual != {component["path"] for component in components}:
        raise ValueError("Actual prop component inventory differs from compiler receipt")
    return {"asset":asset, "source_sha256":source_hash, "output":scene_resource, "output_sha256":compiled["sha256"],
            "receipt":receipt.relative_to(repository).as_posix(), "components":components}


def verify(repository, assets=ASSETS, *, verify_stage2_props=False):
    rows, errors = [], []
    for asset in assets:
        try: rows.append(verify_asset(repository, asset))
        except (OSError, ValueError, KeyError, TypeError) as error: errors.append(asset + ": " + str(error))
    props = []
    if verify_stage2_props:
        for asset in STAGE2_PROPS:
            try: props.append(verify_stage2_prop(repository, asset))
            except (OSError, ValueError, KeyError, TypeError) as error: errors.append(asset + ": " + str(error))
    return {"status":"fail" if errors else "pass", "assets":rows, "errors":errors,
            "visual_acceptance":False, "gameplay_acceptance":False,
            **({"stage2_props":props} if verify_stage2_props else {})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--asset", choices=ASSETS, action="append")
    parser.add_argument("--verify-stage2-props", action="store_true", help="Check exact precompiled station and Merrow cup receipts")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(args.repository.resolve(), args.asset or ASSETS, verify_stage2_props=args.verify_stage2_props)
    encoded = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__": raise SystemExit(main())
