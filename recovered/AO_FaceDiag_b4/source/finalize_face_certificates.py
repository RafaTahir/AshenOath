"""Bind the generated actor scene bytes to each face-only source successor."""
import hashlib
import json
from pathlib import Path

REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
REGISTRY = GAME / "data/design_pack_assets.json"
registry = json.loads(REGISTRY.read_bytes())
catalog = json.loads((GAME / "data/prepared_actors.json").read_bytes())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

compiler = digest(GAME / "tools/build_prepared_actors.gd")
count = 0
for asset, entry in registry["assets"].items():
    if "face_repair_certificate" not in entry:
        continue
    pointer = entry["face_repair_certificate"]
    path = REPO / pointer["path"]
    certificate = json.loads(path.read_bytes())
    rows = [row for row in catalog.values() if row.get("source") == entry["path"]]
    if not rows or len({row["path"] for row in rows}) != 1:
        raise ValueError("Prepared scene ownership differs: " + asset)
    scene_path = rows[0]["path"]
    scene = GAME / scene_path.removeprefix("res://")
    scene_sha = digest(scene)
    if scene_path != certificate["prepared"]["path"] or not all(
        row.get("source_sha256") == entry["sha256"] and row.get("compiled_sha256") == scene_sha for row in rows
    ):
        raise ValueError("Prepared scene does not bind its repaired source: " + asset)
    if digest(GAME / certificate["life_library"]["path"].removeprefix("res://")) != certificate["life_library"]["sha256"]:
        raise ValueError("Life library changed during actor compilation: " + asset)
    certificate["prepared"].update(sha256=scene_sha, bytes=scene.stat().st_size,
        source_sha256=entry["sha256"], compiler_sha256=compiler,
        compiler_path="res://tools/build_prepared_actors.gd")
    path.write_text(json.dumps(certificate, indent=2) + "\n", encoding="utf-8")
    pointer["sha256"] = digest(path)
    count += 1
REGISTRY.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"compiled_face_successors": count, "compiler_sha256": compiler}))
