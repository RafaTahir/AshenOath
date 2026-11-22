"""Generate the eleven private mesh successors, without rendering or gameplay."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BLENDER = Path("C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
RECIPE = ROOT / "source/repair_lower_faces.py"
ASSETS = ("P01", "C04", "C02", "C03", "C06", "C07", "C08", "C09", "C10", "C11", "C12")
for asset in ASSETS:
    destination = ROOT / "authored" / asset
    if (destination / "face_repair.json").exists():
        raise FileExistsError("Preserve completed authoring output: " + str(destination))
    log = ROOT / ("author_" + asset + ".log")
    command = [str(BLENDER), "--background", "--factory-startup", "--python-exit-code", "1",
               "--python", str(RECIPE), "--", "--repo", "D:/Temp/af", "--art-root",
               "D:/Projects/AshenOath/art_source/art_recovery_v2", "--asset", asset,
               "--output", str(destination)]
    print(json.dumps({"asset": asset, "state": "authoring", "rendering": False, "gameplay": False}), flush=True)
    with log.open("wb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode or not (destination / "face_repair.json").is_file():
        print(log.read_text(encoding="utf-8", errors="replace")[-12000:], flush=True)
        raise SystemExit(result.returncode or 1)
    receipt = json.loads((destination / "face_repair.json").read_bytes())
    print(json.dumps({"asset": asset, "state": "authored", "model_sha256": receipt["model"]["sha256"]}), flush=True)
