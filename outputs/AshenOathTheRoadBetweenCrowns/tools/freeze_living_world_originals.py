"""Freeze exact combined scenery inputs before any of the three full bakes."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess

OUTPUTS = {
    **{name: f"assets_external/environment/forest/Campaign_{name}_Landscape.res" for name in
       ("deep_wood", "burned_farmstead", "marsh_crossing", "bandit_road")},
    **{f"farmstead_{side.lower()}": f"assets_external/environment/village/Farmstead{side}_Authored.res" for side in ("West", "East")},
    "checkpoint": "assets_external/environment/village/RoadCheckpoint_Authored.res",
    "hart": "assets_external/environment/forest/HartWoodland_Authored.res",
    "mill": "assets_external/environment/village/AshMill_Authored.res",
}
SCRIPTS = ["tools/build_campaign_wilds.gd", "tools/build_hart_woodland.gd", "tools/build_ash_mill.gd",
           "tools/build_record_archive.gd", "scripts/zones/campaign_wilds_presentation.gd",
           "scripts/zones/campaign_wilderness_section.gd", "scripts/hart_woodland.gd", "scripts/world_material_library.gd"]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def freeze(repository: Path) -> dict:
    game = repository / "outputs/AshenOathTheRoadBetweenCrowns"
    folder = repository / "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/scenery/combined_original"
    manifest_path = folder / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for row in [*manifest["meshes"], *manifest["source_snapshots"]]:
            if sha((folder / row["frozen"]).read_bytes()) != row["sha256"]:
                raise ValueError("Frozen original changed: " + row["frozen"])
        return manifest
    if folder.exists() and any(folder.iterdir()):
        raise ValueError("Preserve/review incomplete frozen originals before retrying")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
    records = []
    for identity, relative in OUTPUTS.items():
        current = game / relative
        tracked = "outputs/AshenOathTheRoadBetweenCrowns/" + relative
        # Existing worktree inputs take precedence. A sparse absent file comes
        # from this exact commit, never from a different live checkout.
        data = current.read_bytes() if current.is_file() else subprocess.check_output(["git", "show", f"{head}:{tracked}"], cwd=repository)
        if data[:4] not in (b"RSRC", b"RSCC"):
            raise ValueError("Expected a native Godot resource: " + relative)
        records.append((identity, relative, data, "worktree" if current.is_file() else "git:" + head))
    snapshots = [(relative, subprocess.check_output(["git", "show", f"{head}:outputs/AshenOathTheRoadBetweenCrowns/{relative}"], cwd=repository)) for relative in SCRIPTS]
    folder.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 1, "source_commit": head, "purpose": "combined-static-before-scenery-split",
                "native_validation": "pending", "meshes": [], "source_snapshots": []}
    for identity, relative, data, origin in records:
        filename = identity + "_" + sha(data)[:16] + ".res"
        with (folder / filename).open("xb") as stream: stream.write(data)
        manifest["meshes"].append({"id": identity, "runtime": "res://" + relative, "frozen": filename,
                                   "sha256": sha(data), "bytes": len(data), "origin": origin})
    for relative, data in snapshots:
        filename = Path(relative).stem + "_" + sha(data)[:16] + ".gd"
        with (folder / filename).open("xb") as stream: stream.write(data)
        manifest["source_snapshots"].append({"path": relative, "frozen": filename, "sha256": sha(data)})
    with manifest_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    return manifest


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[3]
    result = freeze(root)
    print(json.dumps({"frozen_originals": len(result["meshes"]), "source_commit": result["source_commit"], "engine_started": False}))
