"""Review staged publication bytes and pinned artifact identities; no engines."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"

def git(*args, data=None):
    return subprocess.run(["git", "-C", str(REPO), *args], input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=True).stdout

def index_hash(path):
    process = subprocess.Popen(["git", "-C", str(REPO), "cat-file", "blob", ":" + path],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    value = hashlib.sha256()
    while chunk := process.stdout.read(1024 * 1024):
        value.update(chunk)
    error = process.stderr.read()
    if process.wait():
        raise ValueError(error.decode(errors="replace"))
    return value.hexdigest()

def relative(raw):
    return "outputs/AshenOathTheRoadBetweenCrowns/" + raw[6:] if raw.startswith("res://") else raw

identities = {}
def pin(row):
    path = relative(row["path"])
    if path in identities and identities[path] != row["sha256"]:
        raise ValueError("Conflicting pinned identity: " + path)
    identities[path] = row["sha256"]

registry = json.loads((GAME / "data/design_pack_assets.json").read_bytes())
for entry in registry["assets"].values():
    if "face_repair_certificate" not in entry:
        continue
    pointer = entry["face_repair_certificate"]
    pin(pointer)
    cert = json.loads((REPO / pointer["path"]).read_bytes())
    for field in ("model", "baseline_model", "new_glb", "editable_source", "editable_baseline",
                  "design_source", "repair_tool", "donor", "prepared", "life_library"):
        pin(cert[field])
    for row in cert["donor"]["dependencies"]:
        pin(row)
    if "raw_bind_anchor_canonicalization" in cert:
        pin(cert["raw_bind_anchor_canonicalization"]["producer_certificate"])
    identities["outputs/AshenOathTheRoadBetweenCrowns/tools/build_prepared_actors.gd"] = cert["prepared"]["compiler_sha256"]

admission = json.loads((REPO / "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/admission.json").read_bytes())
identities["art_source/art_recovery_v2/tools/face_repair_provenance.py"] = admission["helper_sha256"]
for path, expected in identities.items():
    if index_hash(path) != expected:
        raise ValueError("Staged artifact differs from its identity: " + path)

changed = [value.decode("utf-8") for value in git("diff", "--cached", "--name-only", "--diff-filter=ACM", "-z").split(b"\0") if value]
for path in changed:
    physical = hashlib.sha256((REPO / path).read_bytes()).hexdigest()
    if index_hash(path) != physical:
        raise ValueError("Git changed staged bytes: " + path)

entries = [value for value in git("ls-files", "--stage", "-z").split(b"\0") if value]
objects = {}
for value in entries:
    metadata, path = value.split(b"\t", 1)
    mode, oid, stage = metadata.split()
    if stage != b"0":
        raise ValueError("Unmerged source entry")
    if mode != b"160000":
        objects.setdefault(oid, path.decode("utf-8"))
stats = git("cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)", data=b"\n".join(objects) + b"\n")
largest = (0, "")
for line in stats.splitlines():
    oid, kind, raw_size = line.split()
    size = int(raw_size)
    if kind == b"blob":
        if size >= 100 * 1024 * 1024:
            raise ValueError("Committed file reaches Git limit: " + objects[oid])
        if size > largest[0]:
            largest = (size, objects[oid])
print(json.dumps({"pinned_artifacts_match_index": len(identities), "changed_files_byte_identical": len(changed),
                  "largest_committed_file": {"bytes": largest[0], "path": largest[1]}}))
