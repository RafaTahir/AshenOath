"""Archive observations from the one authorized runtime diagnostic."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil

QA = Path(__file__).resolve().parent.parent
CAPTURE = QA / "single_runtime_check"
OUTPUT = Path("D:/Temp/af/art_source/art_recovery_v2/evidence/lower_face_repair_20261111/diagnosis")
OUTPUT.mkdir(parents=True, exist_ok=False)
for name in ("00_kael_normal.png", "01_kael_modifier_disabled_restored.png", "04_tor_normal.png",
             "05_tor_modifier_disabled_restored.png", "report.json", "runner.json"):
    shutil.copyfile(CAPTURE / name, OUTPUT / name)
samples = (CAPTURE / "lower_face_samples.json").read_bytes()
(OUTPUT / "lower_face_samples.json.gz").write_bytes(gzip.compress(samples, compresslevel=9, mtime=0))
record = {
    "kind": "lower_face_source_diagnosis", "baseline_commit": "b4b52e4",
    "build_id": "combined-loading-cast-20261111-ba93115-r6", "authorized_runtime_processes": 1,
    "observed": {"kael": "recessed chin persists with facial modifier disabled and all face bones at rest",
                 "tor": "recessed chin persists with facial modifier disabled and all face bones at rest",
                 "anwen": "bone poses collected; framing was overridden during the care scene, so images do not establish full-face appearance"},
    "source_cause": {"tool": "art_source/design_pack_v1/tools/build_humans.py",
                     "operation": "neck ellipse fitting ceiling extended through the chin",
                     "old_ceiling": "Head origin + 0.025m", "corrected_ceiling": "Head origin - 0.035m"},
    "independent_source_witness": {"uv": [0.548905611, 0.145922542],
        "space": "glTF Y up, source bind coordinates in metres",
        "donor_chin": [0.0, 1.609416962, 0.084593989],
        "kael_before": [-0.000172323, 1.608171344, 0.024000078],
        "tor_before": [-0.000342801, 1.606716275, 0.025529567],
        "head_origin_y": 1.599800337},
    "runtime_face_motion": {"largest_sampled_lower_face_delta_m": 0.000434,
                            "static_bind_translation_error_max_m": 1.50e-7},
    "samples_uncompressed_sha256": hashlib.sha256(samples).hexdigest(),
    "post_repair_runtime_test": "not performed: one runtime diagnostic allowance was used for diagnosis",
    "post_repair_visual_acceptance": "not established", "publication": "not yet performed"
}
(OUTPUT / "diagnosis.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
print(OUTPUT)
