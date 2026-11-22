"""Pin exact formatting-sensitive donor and design bytes in the art archive."""
import hashlib
import json
from pathlib import Path
import shutil

REPO = Path("D:/Temp/af")
ARCHIVE = Path("art_source/art_recovery_v2/models/lower_face_repair_20261111")
REGISTRY = REPO / "outputs/AshenOathTheRoadBetweenCrowns/data/design_pack_assets.json"
registry = json.loads(REGISTRY.read_bytes())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for asset, entry in registry["assets"].items():
    if "face_repair_certificate" not in entry:
        continue
    pointer = entry["face_repair_certificate"]
    path = REPO / pointer["path"]
    certificate = json.loads(path.read_bytes())
    donor = certificate["donor"]
    original = Path(donor["path"])
    base = ARCHIVE / "donors" / original.stem
    for dependency in donor["dependencies"]:
        source_relative = Path(dependency["path"])
        source = REPO / source_relative
        if digest(source) != dependency["sha256"]:
            raise ValueError("Donor input differs: " + str(source_relative))
        target_relative = base / source_relative.relative_to(original.parent)
        target = REPO / target_relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        dependency["path"] = target_relative.as_posix()
    donor["path"] = (base / original.name).as_posix()
    source = REPO / certificate["design_source"]["path"]
    if digest(source) != certificate["design_source"]["sha256"]:
        raise ValueError("Design source differs")
    design_relative = ARCHIVE / "recipes" / certificate["repair_tool"]["sha256"] / "human_designs.py"
    shutil.copyfile(source, REPO / design_relative)
    certificate["design_source"]["path"] = design_relative.as_posix()
    path.write_text(json.dumps(certificate, indent=2) + "\n", encoding="utf-8")
    pointer["sha256"] = digest(path)
REGISTRY.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
print("Archived exact donor and design inputs for portable source hashes.")
