"""Restore two receipt-pinned OBJ inputs altered only by checkout newlines."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
MODELS = REPO / "art_source/art_recovery_v2/models/living_assets_stage3_20261107/scenery"
known = {"Banner_1_Cloth.obj", "Fern_1.obj"}
pins = {}
for asset in ("checkpoint_cloth", "marsh_reeds", "hart_ferns", "ash_mill_wheel"):
    for resource, expected in json.loads((MODELS / asset / "authoring.json").read_bytes())["source_hashes"].items():
        if resource in pins and pins[resource] != expected:
            raise ValueError("Conflicting retained input hash")
        pins[resource] = expected
changes = []
for resource, expected in pins.items():
    relative = "outputs/AshenOathTheRoadBetweenCrowns/" + resource.removeprefix("res://")
    target = (REPO / relative).resolve(strict=True)
    if not target.is_relative_to(GAME.resolve()):
        raise ValueError("Retained input escapes game")
    current = target.read_bytes()
    actual = hashlib.sha256(current).hexdigest()
    if actual == expected:
        continue
    original = subprocess.check_output(["git", "-C", str(REPO), "show", "aa81191:" + relative])
    if target.name not in known or hashlib.sha256(original).hexdigest() != expected or current.replace(b"\r\n", b"\n") != original:
        raise ValueError("Unexpected retained source change: " + relative)
    changes.append((target, original, {"path": relative, "before_sha256": actual, "sha256": expected,
        "before_bytes": len(current), "bytes": len(original), "change": "restore exact LF bytes; geometry unchanged"}))
if len(changes) != 2:
    raise ValueError("Expected exactly two diagnosed checkout conversions")
for target, original, record in changes:
    target.write_bytes(original)
    if hashlib.sha256(target.read_bytes()).hexdigest() != record["sha256"]:
        raise ValueError("Retained input restore differs")
attributes = REPO / ".gitattributes"
with attributes.open("a", encoding="utf-8", newline="\n") as stream:
    stream.write("\n# Preserve the exact frozen scenery source bytes on Windows checkouts.\n")
    for _, _, record in changes:
        stream.write(record["path"] + " -text whitespace=cr-at-eol\n")
receipt = REPO / "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/retained_input_bytes.json"
receipt.write_text(json.dumps({"kind": "retained_source_byte_restore", "checked_unique_inputs": len(pins),
    "geometry_changed": False, "runtime_test": False, "files": [row for _, _, row in changes]}, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checked_unique_inputs": len(pins), "restored": [row["path"] for _, _, row in changes]}))
