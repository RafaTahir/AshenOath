"""Review exported and copied transport bytes before Git publication."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
BUILD = "lower-face-repair-20261112-1653ba2-r4"
RELEASE = REPO / ".release-gate" / BUILD
EXPORT = RELEASE / "export"
WEB = REPO / "web"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = json.loads((EXPORT / "release_manifest.json").read_bytes())
source_commit = manifest["source"]["git_commit"]
if manifest["build_id"] != BUILD or source_commit != "1653ba24f6b86e7943b35a2824fe925b32611f13":
    raise ValueError("Wrong release identity")
files = [path for path in EXPORT.rglob("*") if path.is_file()]
for source in files:
    target = (WEB / source.relative_to(EXPORT)).resolve(strict=True)
    if not target.is_relative_to(WEB.resolve()) or digest(source) != digest(target):
        raise ValueError("Copied transport bytes differ: " + str(source))
web_files = [path for path in WEB.rglob("*") if path.is_file()]
total = sum(path.stat().st_size for path in web_files)
if total >= 256 * 1024 * 1024 or any(path.stat().st_size >= 100 * 1024 * 1024 for path in web_files):
    raise ValueError("Web deployment limit exceeded")
old_tree = subprocess.check_output(["git", "-C", str(REPO), "ls-tree", "-rl", "b4b52e4", "web"])
previous = sum(int(line.split(b"\t", 1)[0].split()[3]) for line in old_tree.splitlines())
if total - previous > 12 * 1024 * 1024:
    raise ValueError("Face repair exceeds existing-asset growth allocation")
record = {"kind": "reviewed_face_web_candidate", "build_id": BUILD,
          "source_commit": source_commit, "previous_release_commit": "b4b52e4b6a87a0a346618484fdabd405b2980fdf",
          "release_manifest_sha256": digest(EXPORT / "release_manifest.json"),
          "copied_export_files_match": len(files), "web_total_bytes": total,
          "web_total_mib": total / (1024 * 1024), "net_growth_from_previous_bytes": total - previous,
          "publication": "pending", "served_identity": "not_yet_observed",
          "runtime_diagnostic_processes": 1, "post_repair_playtest": False,
          "user_visual_acceptance": "pending", "anwen_full_face_appearance": "unconfirmed"}
(RELEASE / "publication_receipt.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
print(json.dumps(record))
