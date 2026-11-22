"""Restore receipt-pinned prop input bytes without changing source geometry."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
PROPS = REPO / "art_source/art_recovery_v2/models/living_cast_stage2_20261107/props"
names = ["station_" + name + "_authoring.json" for name in ("nessa", "elna", "toma", "nera", "vale", "merrow", "edric")]
names.append("merrow_cup_calibration.json")
pins = {}
for name in names:
    for source in json.loads((PROPS / name).read_bytes())["sources"]:
        path, expected = source["resource"], source["sha256"]
        if path in pins and pins[path] != expected:
            raise ValueError("Conflicting retained prop input identity")
        pins[path] = expected
changes = []
for resource, expected in pins.items():
    relative = "outputs/AshenOathTheRoadBetweenCrowns/" + resource.removeprefix("res://")
    target = (REPO / relative).resolve(strict=True)
    if not target.is_relative_to((GAME / "assets_external").resolve()):
        raise ValueError("Prop input escapes retained assets")
    current = target.read_bytes()
    actual = hashlib.sha256(current).hexdigest()
    if actual == expected:
        continue
    original = subprocess.check_output(["git", "-C", str(REPO), "show", "HEAD:" + relative])
    if target.suffix not in (".obj", ".gltf") or hashlib.sha256(original).hexdigest() != expected or current.replace(b"\r\n", b"\n") != original:
        raise ValueError("Unexpected prop source change: " + relative)
    changes.append((target, original, {"path": relative, "before_sha256": actual, "sha256": expected,
        "before_bytes": len(current), "bytes": len(original), "change": "restore exact LF bytes; geometry unchanged"}))
if len(changes) != 4:
    raise ValueError("Expected four diagnosed prop checkout conversions")
for target, original, record in changes:
    target.write_bytes(original)
    if hashlib.sha256(target.read_bytes()).hexdigest() != record["sha256"]:
        raise ValueError("Prop input restore differs")
with (REPO / ".gitattributes").open("a", encoding="utf-8", newline="\n") as stream:
    stream.write("\n# Keep retained prop inputs identical to their measured source records.\n")
    for _, _, record in changes:
        stream.write(record["path"] + " -text whitespace=cr-at-eol\n")
receipt = REPO / "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/retained_prop_input_bytes.json"
receipt.write_text(json.dumps({"kind": "retained_prop_source_byte_restore", "checked_unique_inputs": len(pins),
    "geometry_changed": False, "runtime_test": False, "files": [row for _, _, row in changes]}, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checked_unique_inputs": len(pins), "restored": [row["path"] for _, _, row in changes]}))
