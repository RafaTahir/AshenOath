#!/usr/bin/env python3
"""Bind newly rendered gallery files to an unchanged capture-time worktree."""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path

from visual_evidence import file_sha256, rendering_inputs_sha256


def begin_capture(project: Path, gate: str) -> dict:
    gallery = project / "Development_Gallery" / "screenshots"
    inputs = rendering_inputs_sha256(project)
    before = {
        image.name: [image.stat().st_mtime_ns, image.stat().st_size]
        for image in gallery.glob("*.png") if image.is_file()
    }
    return {"schema_version": 1, "status": "started", "project": str(project.resolve()),
            "capture_gate": gate, "rendering_inputs_sha256": inputs,
            "started_ns": time.time_ns(), "before": before}


def finish_capture(project: Path, session: dict) -> list[str]:
    if session.get("schema_version") != 1 or session.get("status") != "started" or not session.get("capture_gate"):
        raise ValueError("invalid or previously completed capture session")
    if session.get("project") != str(project.resolve()):
        raise ValueError("capture session belongs to another project")
    current = rendering_inputs_sha256(project)
    if current != session.get("rendering_inputs_sha256"):
        raise ValueError("source/assets changed while the capture gate ran; recapture required")
    images: list[Path] = []
    for image in (project / "Development_Gallery" / "screenshots").glob("*.png"):
        if not image.is_file():
            continue
        stat = image.stat()
        if session["before"].get(image.name) == [stat.st_mtime_ns, stat.st_size]:
            continue
        if stat.st_mtime_ns < session["started_ns"]:
            continue
        images.append(image)
    if not images:
        raise ValueError("successful capture gate produced no fresh PNG files")
    captured_at = datetime.now(timezone.utc).isoformat()
    for image in images:
        record = {"schema_version": 1, "status": "captured", "capture_gate": session["capture_gate"],
                  "captured_at_utc": captured_at, "rendering_inputs_sha256": current,
                  "image_sha256": file_sha256(image)}
        image.with_suffix(image.suffix + ".capture.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return sorted(image.name for image in images)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("begin", "finish"))
    parser.add_argument("project", type=Path)
    parser.add_argument("--session", required=True, type=Path)
    parser.add_argument("--gate", default="")
    args = parser.parse_args()
    project = args.project.resolve()
    try:
        if args.phase == "begin":
            if not args.gate:
                raise ValueError("capture gate name is required")
            session = begin_capture(project, args.gate)
        else:
            session = json.loads(args.session.read_text(encoding="utf-8"))
            images = finish_capture(project, session)
            session["status"] = "captured"
            session["images"] = images
        args.session.parent.mkdir(parents=True, exist_ok=True)
        args.session.write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError, KeyError) as error:
        print(f"VISUAL CAPTURE IDENTITY: FAIL - {error}")
        return 1
    print(f"VISUAL CAPTURE IDENTITY: PASS - {args.phase} {session['capture_gate']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
