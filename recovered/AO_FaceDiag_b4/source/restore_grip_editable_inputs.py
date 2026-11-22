"""Fill missing retained grip masters from exact committed binary objects."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
ART = REPO / "art_source/art_recovery_v2"
roots = [ART / "models/living_cast_20261107", ART / "models/living_cast_stage2_20261107",
         ART / "models/living_assets_stage3_20261107/player"]
required = {}
for root in roots:
    for manifest in root.glob("*/activity_grips.json"):
        for style, source in json.loads(manifest.read_bytes()).get("fits", {}).items():
            evidence = (REPO / source["evidence"]).resolve(strict=True)
            if not evidence.is_relative_to(ART) or hashlib.sha256(evidence.read_bytes()).hexdigest() != source["evidence_sha256"]:
                raise ValueError("Grip evidence identity differs")
            fit = json.loads(evidence.read_bytes())["fits"][style]
            editable = fit["editable_scene"]
            name = editable["path"]
            if Path(name).name != name or not name.endswith(".blend"):
                raise ValueError("Editable grip master path escapes its evidence folder")
            path = evidence.parent / name
            if path in required and required[path] != editable["sha256"]:
                raise ValueError("Conflicting editable grip identity")
            required[path] = editable["sha256"]
restored = []
for path, expected in required.items():
    if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected:
        continue
    relative = path.relative_to(REPO).as_posix()
    content = subprocess.check_output(["git", "-C", str(REPO), "show", "HEAD:" + relative])
    if hashlib.sha256(content).hexdigest() != expected:
        raise ValueError("Committed grip master differs from its record: " + relative)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    restored.append(relative)
print(json.dumps({"pinned_editable_grip_masters": len(required), "restored_from_exact_git_objects": restored}))
