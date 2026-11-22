"""Preserve maintained source formatting and compact the diagnostic archive."""
import gzip
import hashlib
import json
from pathlib import Path

REPO = Path("D:/Temp/af")
for name in ("build_story_release.ps1", "verify_living_cast_delivery.py"):
    path = REPO / "outputs/AshenOathTheRoadBetweenCrowns/tools" / name
    content = path.read_bytes().replace(b"\r\n", b"\n")
    path.write_bytes(content.replace(b"\n", b"\r\n"))

folder = REPO / "art_source/art_recovery_v2/evidence/lower_face_repair_20261111/diagnosis"
report = folder / "report.json"
content = report.read_bytes()
compressed = gzip.compress(content, compresslevel=9, mtime=0)
if gzip.decompress(compressed) != content:
    raise ValueError("Diagnostic archive differs")
(folder / "report.json.gz").write_bytes(compressed)
identity_path = folder / "diagnosis.json"
identity = json.loads(identity_path.read_bytes())
identity["report_uncompressed_sha256"] = hashlib.sha256(content).hexdigest()
identity_path.write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
report.unlink()
print("Preserved original source line endings and compressed the exact diagnostic report.")
