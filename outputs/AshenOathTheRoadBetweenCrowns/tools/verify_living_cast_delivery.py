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
from pathlib import Path

ASSETS = ["C11", "C05", "C06", "C12", "C07", "C09", "C10", "C08", "P01"]
GAME = "outputs/AshenOathTheRoadBetweenCrowns"
ART = "art_source/art_recovery_v2"


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
        if digest(model) != row.get("model_sha256") or row.get("model_sha256") != authored.get("production_sha256"):
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


def verify(repository, assets=ASSETS):
    rows, errors = [], []
    for asset in assets:
        try: rows.append(verify_asset(repository, asset))
        except (OSError, ValueError, KeyError, TypeError) as error: errors.append(asset + ": " + str(error))
    return {"status":"fail" if errors else "pass", "assets":rows, "errors":errors,
            "visual_acceptance":False, "gameplay_acceptance":False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--asset", choices=ASSETS, action="append")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(args.repository.resolve(), args.asset or ASSETS)
    encoded = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__": raise SystemExit(main())
