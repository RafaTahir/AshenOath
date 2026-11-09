"""Source-only restoration of the three builders' explicit resource inputs."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CANON = Path(r"D:\Projects\AshenOath")
REL = Path("outputs/AshenOathTheRoadBetweenCrowns")
GAME, SOURCE = ROOT / REL, CANON / REL
OUTPUT = ROOT / ".verification/scenery/extraction_preflight_r1.json"
INPUTS = [
    "assets_external/environment/props/Table_Large.obj",
    "assets_external/environment/props/Banner_1_Cloth.obj",
    *["assets_external/environment/village/" + name for name in [
        "Wall_UnevenBrick_Window_Thin_Round.obj", "Wall_Plaster_WoodGrid.obj",
        "Roof_RoundTiles_6x10.obj", "Door_1_Flat.obj", "Prop_WoodenFence_Extension1.obj",
        "Roof_Front_Brick6.obj"]],
    "assets_external/environment/forest/Fern_1.obj",
    "assets_external/textures/runtime/forest_ground_albedo.jpg",
]
SCRIPT_ROOTS = ["tools/build_campaign_wilds.gd", "tools/build_hart_woodland.gd", "tools/build_ash_mill.gd", "scripts/zone_build_context.gd"]
LOADS = re.compile(r'(?:preload\s*\(\s*|extends\s+)["\']res://([^"\']+)["\']')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe(base, relative):
    path = (base / relative).resolve()
    path.relative_to(base.resolve())
    return path


def main():
    if OUTPUT.exists():
        raise RuntimeError("Preserve the prior preflight receipt before another restoration")
    rows, blocked, pending, seen = [], [], [(p, "direct builder input") for p in INPUTS], set()
    while pending:
        relative, reason = pending.pop(0)
        if relative in seen:
            continue
        seen.add(relative)
        current, canonical = safe(GAME, relative), safe(SOURCE, relative)
        if not canonical.is_file():
            blocked.append({"path": relative, "reason": "canonical input missing", "referenced_by": reason})
            continue
        original_hash = sha(canonical)
        action = "existing_identical"
        if current.exists():
            if sha(current) != original_hash:
                action = "preserved_authored_difference"
                blocked.append({"path": relative, "reason": "authored input differs; canonical import closure cannot certify it"})
        else:
            current.parent.mkdir(parents=True, exist_ok=True)
            with current.open("xb") as target, canonical.open("rb") as source:
                shutil.copyfileobj(source, target)
            if sha(current) != original_hash or sha(canonical) != original_hash:
                raise RuntimeError("Input changed during restoration: " + relative)
            action = "restored_missing"
        rows.append({"path": relative, "source": str(canonical), "source_sha256": original_hash,
                     "destination_sha256": sha(current), "bytes": current.stat().st_size,
                     "action": action, "referenced_by": reason})
        if action == "preserved_authored_difference":
            continue
        suffix = current.suffix.lower()
        if suffix in (".obj", ".png", ".jpg", ".jpeg"):
            pending.append((relative + ".import", relative + " import metadata"))
        if suffix == ".obj":
            for line in current.read_text(errors="strict").splitlines():
                if line.startswith("mtllib "):
                    pending.append(((Path(relative).parent / line[7:].strip()).as_posix(), relative + " material library"))
        if suffix == ".mtl":
            for line in current.read_text(errors="strict").splitlines():
                if line.lstrip().startswith(("map_", "bump ")):
                    # The exact referenced inputs use single filenames, optionally
                    # preceded by Wavefront switches such as -bm 1.000000.
                    name = line.split()[-1]
                    pending.append(((Path(relative).parent / name).as_posix(), relative + " texture map"))
        if suffix == ".import":
            for resource in re.findall(r'"res://([^"\n]+)"', current.read_text()):
                if resource.startswith(".godot/imported/"):
                    pending.append((resource, relative + " imported resource"))
                    metadata = str(Path(resource).with_suffix(".md5")).replace("\\", "/")
                    if safe(SOURCE, metadata).is_file():
                        pending.append((metadata, relative + " import checksum"))
    scripts, script_pending, script_seen = [], list(SCRIPT_ROOTS), set()
    while script_pending:
        relative = script_pending.pop(0)
        if relative in script_seen:
            continue
        script_seen.add(relative)
        path = safe(GAME, relative)
        if not path.is_file():
            blocked.append({"path": relative, "reason": "required parser source missing; not restored over another owner's source"})
            continue
        scripts.append({"path": relative, "sha256": sha(path)})
        if path.suffix == ".gd":
            script_pending.extend(LOADS.findall(path.read_text(encoding="utf-8-sig")))
    cache = GAME / ".godot/global_script_class_cache.cfg"
    cache_receipt = {"exists": cache.is_file(), "sha256": sha(cache) if cache.is_file() else None}
    if not cache.is_file() or '"path": "res://scripts/zone_build_context.gd"' not in cache.read_text():
        blocked.append({"path": ".godot/global_script_class_cache.cfg", "reason": "ZoneBuildContext parser identity missing"})
    receipt = {"engine_started": False, "source_root": str(CANON), "destination_root": str(ROOT),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=CANON, text=True).strip(),
               "destination_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "resources": rows, "parser_scripts": scripts, "class_cache": cache_receipt, "blocked": blocked,
               "passed_static_preflight": not blocked,
               "native_parse_and_load": "unrun; no claim of actual resource load equivalence"}
    OUTPUT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    restored = [row for row in rows if row["action"] == "restored_missing"]
    print(json.dumps({"receipt": str(OUTPUT), "resources": len(rows), "restored": len(restored),
                      "restored_bytes": sum(row["bytes"] for row in restored), "parser_scripts": len(scripts),
                      "blocked": blocked}, indent=2))


if __name__ == "__main__":
    main()
