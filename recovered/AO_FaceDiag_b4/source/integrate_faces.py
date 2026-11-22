"""Install completed private art successors in the isolated release checkout."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

QA = Path(__file__).resolve().parent.parent
REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
ARCHIVE = Path("art_source/art_recovery_v2/models/lower_face_repair_20261111")
ADMISSION = "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/admission.json"
ASSETS = ("P01", "C04", "C02", "C03", "C06", "C07", "C08", "C09", "C10", "C11", "C12")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

def portable_existing(row):
    original = str(row["path"]).replace("\\", "/")
    if original.startswith("D:/Projects/AshenOath/"):
        relative = original[len("D:/Projects/AshenOath/"):]
    elif original.startswith("D:/Temp/af/"):
        relative = original[len("D:/Temp/af/"):]
    else:
        raise ValueError("Unrecognized retained input: " + original)
    result = copy.deepcopy(row)
    result["path"] = relative
    if digest(REPO / relative) != row["sha256"]:
        raise ValueError("Retained source copy differs: " + relative)
    return result

registry_path = GAME / "data/design_pack_assets.json"
registry = json.loads(registry_path.read_bytes())
spec = importlib.util.spec_from_file_location("face_recipe_read", QA / "source/repair_lower_faces.py")
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
prepared = []
for asset in ASSETS:
    folder = QA / "authored" / asset
    certificate = json.loads((folder / "face_repair.json").read_bytes())
    entry = registry["assets"][asset]
    runtime = GAME / entry["path"].removeprefix("res://")
    if certificate["asset"] != asset or digest(runtime) != certificate["model"]["baseline_sha256"]:
        raise ValueError("Actor is no longer the exact baseline: " + asset)
    if "face_repair_certificate" in entry:
        raise ValueError("Preserve an already installed successor: " + asset)
    tool_sha = certificate["repair_tool"]["sha256"]
    frozen_tool = QA / "source/recipes" / tool_sha / "repair_lower_faces.py"
    if digest(frozen_tool) != tool_sha:
        raise ValueError("Missing exact source recipe: " + asset)
    donor = certificate["donor"]
    if digest(REPO / donor["path"]) != donor["sha256"]:
        raise ValueError("Retained donor differs: " + asset)
    successor = folder / (asset + "_face_repaired.glb")
    model = recipe.read_model(successor)
    bounds = entry["authored_bind_bounds"]
    low = bounds["position"]
    high = [low[axis] + bounds["size"][axis] for axis in range(3)]
    for edit in certificate["allowed_edits"]:
        if "POSITION" not in edit["attributes"]:
            continue
        primitive = model["document"]["meshes"][edit["mesh"]]["primitives"][edit["primitive"]]
        positions = recipe.accessor(model, primitive["attributes"]["POSITION"])
        for index in edit["vertices"]:
            if any(not low[axis] - 0.0001 <= positions[index][axis] <= high[axis] + 0.0001 for axis in range(3)):
                raise ValueError("Face change escapes retained whole-actor bounds: " + asset)
    life = GAME / certificate["life_library"]["path"].removeprefix("res://")
    if digest(life) != certificate["life_library"]["sha256"]:
        raise ValueError("Retained animation library differs: " + asset)
    certificate["editable_baseline"] = portable_existing(certificate["editable_baseline"])
    certificate["design_source"] = portable_existing(certificate["design_source"])
    prepared.append((asset, folder, certificate, frozen_tool, runtime))

# All inputs have passed identity checks before installing any successor.
for asset, folder, certificate, frozen_tool, runtime in prepared:
    relative = ARCHIVE / asset
    destination = REPO / relative
    destination.mkdir(parents=True, exist_ok=False)
    for field in ("baseline_snapshot", "new_glb", "editable_source"):
        row = certificate[field]
        source = Path(row["path"])
        if digest(source) != row["sha256"] or source.stat().st_size >= 100 * 1024 * 1024:
            raise ValueError("Authored artifact differs or exceeds Git limit: " + asset)
        target = destination / source.name
        shutil.copyfile(source, target)
        row["path"] = (relative / source.name).as_posix()
    tool_relative = ARCHIVE / "recipes" / certificate["repair_tool"]["sha256"] / "repair_lower_faces.py"
    tool_target = REPO / tool_relative
    tool_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(frozen_tool, tool_target)
    certificate["repair_tool"]["path"] = tool_relative.as_posix()
    certificate["baseline_model"]["path"] = certificate["baseline_snapshot"]["path"]
    certificate_path = destination / "face_repair.json"
    write(certificate_path, certificate)
    shutil.copyfile(REPO / certificate["new_glb"]["path"], runtime)
    entry = registry["assets"][asset]
    entry["sha256"] = certificate["model"]["sha256"]
    entry["bytes"] = runtime.stat().st_size
    entry["authored_bind_bounds"]["asset_sha256"] = entry["sha256"]
    entry["candidate_source_path"] = certificate["editable_source"]["path"]
    entry["candidate_runtime_path"] = certificate["new_glb"]["path"]
    entry["face_repair_certificate"] = {
        "path": (relative / "face_repair.json").as_posix(),
        "sha256": digest(certificate_path), "admission_path": ADMISSION,
    }
    print(json.dumps({"asset": asset, "state": "installed_isolated", "runtime_acceptance": False}), flush=True)
write(registry_path, registry)
shutil.copyfile(QA / "source/repair_lower_faces.py", REPO / "art_source/art_recovery_v2/tools/repair_lower_faces.py")
shutil.copyfile(QA / "source/provenance_patch/art_source/art_recovery_v2/tools/face_repair_provenance.py",
                REPO / "art_source/art_recovery_v2/tools/face_repair_provenance.py")
