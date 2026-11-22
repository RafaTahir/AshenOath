"""Complete retained source/evidence checkout after the export has finished."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
relative = "outputs/AshenOathTheRoadBetweenCrowns/assets_external/environment/props/Bag.obj"
expected = "6aa7124265768200c3b59742a8b866fdc0fcbab002cac712e5e4f241b4b4b375"
for name in ("runtime_pack_manifest.json", "export_presets.cfg"):
    if "bag.obj" in (GAME / name).read_text(encoding="utf-8").lower():
        raise ValueError("Raw Bag source is an export input; do not change it after packaging")
original = subprocess.check_output(["git", "-C", str(REPO), "show", "HEAD:" + relative])
target = REPO / relative
current = target.read_bytes()
if hashlib.sha256(original).hexdigest() != expected or current.replace(b"\r\n", b"\n") != original:
    raise ValueError("Rook source differs beyond the diagnosed checkout conversion")
target.write_bytes(original)
with (REPO / ".gitattributes").open("a", encoding="utf-8", newline="\n") as stream:
    stream.write("\n# Preserve the retained opening satchel input; its compiled output is shipped.\n")
    stream.write(relative + " -text whitespace=cr-at-eol\n")
folder = REPO / "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/companion"
receipt = json.loads((folder / "prepared_companion.json").read_bytes())
archive = (REPO / receipt["proof_archive"] / "bracken.scn").resolve(strict=True)
if not archive.is_relative_to(folder.resolve()) or hashlib.sha256(archive.read_bytes()).hexdigest() != receipt["output_sha256"]:
    raise ValueError("Companion proof archive differs")
record = {"kind": "retained_input_completion", "runtime_test": False,
          "rook_source": {"path": relative, "sha256": expected, "geometry_changed": False,
                          "exported_raw_source": False},
          "companion_archive": {"path": archive.relative_to(REPO).as_posix(), "sha256": receipt["output_sha256"]}}
path = REPO / "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/retained_input_completion.json"
path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
print(json.dumps(record))
