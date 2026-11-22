from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageStat


EXPECTED = (
    "01_Main_Menu",
    "02_Kael",
    "03_Anwen",
    "04_Greyfen",
    "05_River",
    "06_Wychwood",
    "07_Combat",
    "08_Castle",
    "09_Hart",
)


def fail(message: str) -> None:
    raise AssertionError(message)


def main() -> int:
    project = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    report_path = project / ".release-gate" / "qa_soul_001_runtime.json"
    if not report_path.is_file():
        fail("QA-SOUL-001 runtime report is missing")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("status") != "pass":
        fail("QA-SOUL-001 graphical capture did not pass")
    if report.get("viewport") != [1280, 720]:
        fail("QA-SOUL-001 viewport is not native 1280x720")
    views = {str(view.get("id")): view for view in report.get("views", [])}
    gallery = project / "Development_Gallery" / "screenshots"
    for suffix in EXPECTED:
        matches = [view for key, view in views.items() if key.endswith(suffix)]
        if len(matches) != 1:
            fail(f"expected exactly one current {suffix} baseline view")
        image_path = project / str(matches[0]["path"])
        if not image_path.is_file() or image_path.parent != gallery:
            fail(f"baseline image missing from gallery: {image_path}")
        with Image.open(image_path) as image:
            expected_size = (1920, 1080) if suffix == "01_Main_Menu" else (1280, 720)
            if image.size != expected_size:
                fail(f"{image_path.name} is not {expected_size[0]}x{expected_size[1]}")
            stat = ImageStat.Stat(image.convert("RGB").resize((64, 36)))
            if max(stat.var) < 12.0:
                fail(f"{image_path.name} appears blank or visually flat")
    timings = report.get("timings_ms", {})
    for key in ("scene_ready", "new_game", "transition_wychwood", "transition_vargan_approach", "transition_hart_glade"):
        if not isinstance(timings.get(key), (int, float)) or timings[key] < 0:
            fail(f"missing current timing measurement: {key}")
    for zone in ("greyfen", "wychwood"):
        sample = report.get("zones", {}).get(zone, {})
        if not sample.get("frames") or not sample.get("average_fps") or not sample.get("one_percent_low_fps"):
            fail(f"missing current {zone} performance sample")
    baseline_doc = project / "QA_SOUL_001_TRUTHFUL_BASELINE.md"
    result_doc = project / "QA-SOUL-001_RESULT.md"
    for document in (baseline_doc, result_doc):
        if not document.is_file():
            fail(f"missing {document.name}")
    text = baseline_doc.read_text(encoding="utf-8")
    if "Historical evidence" not in text or "Current visual debt" not in text:
        fail("truthful baseline does not distinguish historical evidence and current debt")
    if "not an original-state recapture" not in text:
        fail("truthful baseline does not disclose the historical-image limitation")
    print("QA-SOUL-001 VERIFIER: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QA-SOUL-001 VERIFIER: FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
