#!/usr/bin/env python3
"""Encode timestamped native observations, preserving source and video hashes.

This is evidence packaging. It does not promote a fixture to gameplay acceptance
or turn source review into user visual acceptance. Raw frames are kept by default.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def owned_frame(output: Path, value: str) -> Path:
    path = Path(value).resolve(strict=True)
    path.relative_to(output)
    if path.suffix.lower() != ".png" or not path.is_file():
        raise ValueError(f"not a captured PNG: {path}")
    if any(c in str(path) for c in "\r\n'"):
        raise ValueError("capture filenames cannot contain newlines or apostrophes")
    return path


def encode(output: Path, ffmpeg: Path, prune: bool = False) -> dict:
    output = output.resolve(strict=True)
    report_path = output / "report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    runner = json.loads((output / "runner.json").read_text(encoding="utf-8"))
    if report.get("status") != "pass" or runner.get("status") != "pass":
        raise ValueError("only passing observations can be packaged as review sequences")
    if runner.get("kind") != "native_living_cast_runner" or Path(runner["output"]).resolve() != output:
        raise ValueError("output is not owned by the native capture runner")
    result = {"schema_version": 1, "kind": "native_observation_sequences",
              "report_sha256": digest(report_path), "runner_sha256": digest(output / "runner.json"),
              "codec_sha256": digest(ffmpeg), "user_acceptance": False,
              "real_input_acceptance": False, "sequences": []}
    videos = output / "sequences"
    videos.mkdir(exist_ok=True)
    videos = videos.resolve(strict=True)
    videos.relative_to(output)
    for sequence in report.get("scenarios", []):
        frames = sequence.get("frames", [])
        if len(frames) < 2:
            raise ValueError("sequence needs at least two timestamped frames")
        # Capture reports may index the top-level frame records rather than
        # duplicating them. Resolve only those exact records from this report.
        if isinstance(frames[0], int):
            frames = [report["frames"][index] for index in frames]
        elif isinstance(frames[0], str):
            by_path = {frame["path"]: frame for frame in report["frames"]}
            frames = [by_path[path] for path in frames]
        paths = [owned_frame(output, frame["path"]) for frame in frames]
        times = [float(frame["scenario_elapsed_ms"]) / 1000.0 for frame in frames]
        if len(set(paths)) != len(paths):
            raise ValueError("a sequence cannot own the same frame twice")
        if any(not math.isfinite(t) or t < 0 for t in times) or any(b <= a for a, b in zip(times, times[1:])):
            raise ValueError("frame timestamps must increase strictly")
        name = "_".join(str(sequence[key]) for key in ("actor", "environment", "scenario"))
        if not name.replace("_", "").isalnum():
            raise ValueError("unsafe sequence name")
        destination = videos / (name + ".mp4")
        if destination.exists():
            raise ValueError(f"refusing to overwrite existing evidence: {destination}")
        duration = float(sequence["elapsed_seconds"])
        if not math.isfinite(duration) or duration < times[-1]:
            raise ValueError("sequence duration must contain every frame")
        last_duration = max(0.001, duration - times[-1])
        with tempfile.TemporaryDirectory(prefix="encode_", dir=videos) as temporary:
            # Verify the exact generated directory before its scoped recursive
            # cleanup, including on Windows hosts with filesystem junctions.
            Path(temporary).resolve(strict=True).relative_to(output)
            concat = Path(temporary) / "frames.txt"
            lines = []
            for index, path in enumerate(paths):
                seconds = times[index + 1] - times[index] if index + 1 < len(times) else last_duration
                lines.extend([f"file '{path.as_posix()}'", f"duration {seconds:.6f}"])
            # concat requires a terminal frame to preserve the last duration.
            lines.append(f"file '{paths[-1].as_posix()}'")
            concat.write_text("\n".join(lines) + "\n", encoding="utf-8")
            command = [str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin",
                       "-f", "concat", "-safe", "0", "-i", str(concat),
                       "-fps_mode", "vfr", "-c:v", "libx264", "-preset", "medium",
                       "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(destination)]
            subprocess.run(command, check=True, timeout=180, capture_output=True)
            subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-nostdin",
                            "-i", str(destination), "-f", "null", "-"],
                           check=True, timeout=120, capture_output=True)
        record = {"name": name, "path": str(destination), "sha256": digest(destination),
                  "bytes": destination.stat().st_size, "source_frames": [], "retained_stills": []}
        for frame, path in zip(frames, paths):
            record["source_frames"].append({"path": str(path), "sha256": digest(path),
                                             "scenario_elapsed_ms": frame["scenario_elapsed_ms"]})
        # Preserve an opening frame, the frame nearest the first actual contact,
        # and the final frame. The full sequence remains in the checked video.
        contact_events = sequence.get("contacts", sequence.get("contact_events", []))
        contact_ms = float(contact_events[0].get("scenario_elapsed_ms", times[len(times)//2]*1000)) if contact_events else times[len(times)//2]*1000
        contact_index = min(range(len(times)), key=lambda index: abs(times[index]*1000-contact_ms))
        retained = {0, contact_index, len(paths)-1}
        record["retained_stills"] = [str(paths[index]) for index in sorted(retained)]
        result["sequences"].append(record)
        # Commit the evidence manifest before optional, scoped frame removal.
        (videos / "index.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        if prune:
            for index, path in enumerate(paths):
                if index not in retained:
                    path.relative_to(output)
                    path.unlink()
    if not result["sequences"]:
        raise ValueError("report has no scenarios")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--prune-frames", action="store_true")
    args = parser.parse_args()
    try:
        result = encode(args.output, args.ffmpeg.resolve(strict=True), args.prune_frames)
        print(f"ENCODED NATIVE SEQUENCES: {len(result['sequences'])}")
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"SEQUENCE PACKAGING FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
