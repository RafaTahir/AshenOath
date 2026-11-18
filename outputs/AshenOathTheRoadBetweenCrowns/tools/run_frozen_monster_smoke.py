#!/usr/bin/env python3
"""Observe exact exported Web PCK bytes in an isolated native Godot process.

Preparation and --check-only never launch Godot. --run explicitly launches two
serial renderers. This is native frozen-export QA, not Web/network acceptance.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from urllib.parse import urlsplit
import zlib

from background_native_capture import spawn_background
from runtime_pack_validation import require_valid_pack_graph

HERE = Path(__file__).resolve().parent
GODOT = Path.home() / ".cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
QA = HERE / "verify_frozen_monster_smoke.gd"
COORDINATES = HERE / "qa_viewport_coordinates.gd"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def relative_path(value: object) -> str:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value or "\x00" in value:
        raise ValueError(f"invalid artifact path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in value.split("/")):
        raise ValueError(f"artifact path escape: {value!r}")
    return value


def read_bound(root: Path, relative: str, record: dict) -> bytes:
    path = root / relative_path(relative)
    if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
        raise ValueError(f"artifact resolves outside export: {relative}")
    data = path.read_bytes()
    if len(data) != record.get("bytes") or digest(data) != record.get("sha256"):
        raise ValueError(f"transport identity mismatch: {relative}")
    return data


def decode_pack(data: bytes, record: dict, name: str) -> bytes:
    if record.get("content_encoding") != "gzip":
        raise ValueError(f"PCK must use declared gzip transport: {name}")
    try:
        decoded = gzip.decompress(data)
    except (OSError, EOFError, zlib.error) as error:
        raise ValueError(f"invalid gzip PCK transport: {name}") from error
    if len(decoded) != record.get("decoded_bytes") or digest(decoded) != record.get("decoded_sha256"):
        raise ValueError(f"decoded identity mismatch: {name}")
    if not decoded.startswith(b"GDPC"):
        raise ValueError(f"decoded artifact is not a Godot PCK: {name}")
    return decoded


def exported_packs(export: Path) -> tuple[dict, dict, list[dict]]:
    """Fail closed before creating any output; bind both manifests and all PCKs."""
    release = json.loads((export / "release_manifest.json").read_text(encoding="utf-8-sig"))
    records = {}
    for entry in release["artifacts"]:
        name = relative_path(entry["path"])
        if name.casefold() in {key.casefold() for key in records}:
            raise ValueError(f"duplicate artifact: {name}")
        records[name] = entry
    bound = release["runtime_pack_manifest"]
    if bound != records.get("runtime_pack_manifest.json"):
        raise ValueError("runtime manifest binding disagrees with artifacts")
    runtime_bytes = read_bound(export, "runtime_pack_manifest.json", bound)
    runtime = json.loads(runtime_bytes)
    require_valid_pack_graph(runtime)
    if not release.get("build_id") or runtime.get("release_id") != release["build_id"]:
        raise ValueError("release identity mismatch")
    if release.get("root_pck") != records.get("index.pck"):
        raise ValueError("root PCK binding disagrees with artifacts")
    packs = runtime["packs"]
    mounted, ordered, referenced = set(), [], {"index.pck"}

    def visit(identity: str) -> None:
        if identity in mounted:
            return
        row = packs[identity]
        for dependency in row.get("dependencies", []):
            visit(dependency)
        mounted.add(identity)
        if row.get("embedded", False):
            return
        url = urlsplit(row.get("url", ""))
        if url.scheme or url.netloc or url.fragment:
            raise ValueError(f"nonlocal pack URL: {identity}")
        path = relative_path(url.path)
        if not path.startswith("packs/") or not path.endswith(".pck") or path in referenced:
            raise ValueError(f"invalid or repeated external pack path: {path}")
        entry = records.get(path, {})
        if entry.get("decoded_bytes") != row.get("bytes") or entry.get("decoded_sha256") != row.get("sha256"):
            raise ValueError(f"runtime PCK binding mismatch: {identity}")
        referenced.add(path)
        ordered.append({"id": identity, "path": path, "bytes": row["bytes"], "sha256": row["sha256"]})

    for identity in packs:
        visit(identity)
    if referenced != {name for name in records if name.endswith(".pck")}:
        raise ValueError("undeclared or missing PCK artifact")
    payloads = []
    for row in [{"id": "root", "path": "index.pck"}] + ordered:
        entry = records[row["path"]]
        payload = decode_pack(read_bound(export, row["path"], entry), entry, row["path"])
        payloads.append({**row, "bytes": len(payload), "sha256": digest(payload), "payload": payload})
    return release, runtime, payloads


def prepare(export: Path, output: Path, expected_profile: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{64}", expected_profile):
        raise ValueError("an exact expected candidate profile SHA256 is required")
    release, runtime, payloads = exported_packs(export)
    if output.exists():
        raise ValueError("preserve prior evidence; use a fresh output directory")
    output.mkdir(parents=True)
    (output / "resource-root").mkdir()
    (output / "qa").mkdir()
    qa_payload = QA.read_bytes()
    (output / "qa" / QA.name).write_bytes(qa_payload)
    coordinate_payload = COORDINATES.read_bytes()
    (output / "qa" / COORDINATES.name).write_bytes(coordinate_payload)
    for row in payloads:
        target = output / "decoded" / row["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(row.pop("payload"))
    receipt = {"kind": "frozen_monster_smoke_preparation", "schema_version": 1,
               "build_id": release["build_id"], "source": release.get("source", {}),
               "release_manifest_sha256": digest((export / "release_manifest.json").read_bytes()),
               "runtime_manifest_sha256": digest((export / "runtime_pack_manifest.json").read_bytes()),
               "expected_profile_sha256": expected_profile, "packs": payloads,
               "qa_script_sha256": digest(qa_payload),
               "coordinate_helper_sha256": digest(coordinate_payload),
               "launcher_sha256": digest(Path(__file__).read_bytes()),
               "background_launcher_sha256": digest((HERE / "background_native_capture.py").read_bytes()),
               "source_fallback": False, "engine_launched": False,
               "visual_acceptance": False, "browser_acceptance": False, "physical_phone": False}
    write_json(output / "preparation.json", receipt)
    return receipt


def check_prepared(output: Path) -> dict:
    receipt = json.loads((output / "preparation.json").read_text(encoding="utf-8"))
    if receipt.get("source_fallback") is not False:
        raise ValueError("source fallback is forbidden")
    resource_root = output / "resource-root"
    junction = getattr(resource_root, "is_junction", lambda: False)()
    if not resource_root.is_dir() or resource_root.is_symlink() or junction or any(resource_root.iterdir()):
        raise ValueError("resource root must be an empty real directory before launch")
    qa = output / "qa" / QA.name
    if digest(qa.read_bytes()) != receipt["qa_script_sha256"]:
        raise ValueError("prepared QA script changed")
    if digest((output / "qa" / COORDINATES.name).read_bytes()) != receipt["coordinate_helper_sha256"]:
        raise ValueError("prepared coordinate helper changed")
    if {path.name for path in (output / "qa").iterdir()} != {QA.name, COORDINATES.name}:
        raise ValueError("only the two reviewed QA scripts may accompany the frozen packs")
    if digest(Path(__file__).read_bytes()) != receipt["launcher_sha256"]:
        raise ValueError("QA launcher changed since preparation")
    if digest((HERE / "background_native_capture.py").read_bytes()) != receipt["background_launcher_sha256"]:
        raise ValueError("background launcher changed since preparation")
    expected = set()
    for row in receipt["packs"]:
        name = relative_path(row["path"])
        expected.add(name)
        data = read_bound(output / "decoded", name, row)
        if not data.startswith(b"GDPC"):
            raise ValueError("prepared PCK header changed")
    actual = {path.relative_to(output / "decoded").as_posix() for path in (output / "decoded").rglob("*") if path.is_file()}
    if actual != expected:
        raise ValueError("undeclared decoded resource")
    return receipt


def observation_geometry_errors(report: dict, window_size: tuple[int, int]) -> list[str]:
    """Keep client input coverage distinct from the native render texture size."""
    errors = []
    if report.get("requested_window_size") != list(window_size) or report.get("window_client_size") != list(window_size):
        errors.append("actual/requested client window mismatch")
    if report.get("internal_render_size") != [1280, 720]:
        errors.append("production internal render size mismatch")
    frames = report.get("frames", [])
    if not frames or any((row.get("width"), row.get("height")) != (1280, 720) or row.get("window_client_size") != list(window_size) for row in frames):
        errors.append("raw PNG/window dimension contract mismatch")
    inputs = report.get("inputs", [])
    if not inputs:
        errors.append("no recorded native input events")
    for index, row in enumerate(inputs):
        contract = row.get("coordinates", {})
        logical = contract.get("logical_size", [])
        physical = contract.get("window_client_size", [])
        if contract.get("valid") is not True or logical != [1280, 720] or physical != list(window_size):
            errors.append(f"input {index}: actual logical/client coordinate contract mismatch")
            continue
        for logical_key, physical_key in (("logical_position", "window_position"), ("logical_delta", "window_delta")):
            if logical_key not in row:
                continue  # Keyboard events have no pointer position.
            point, raw = row[logical_key], row.get(physical_key, [])
            finite_pair = lambda pair: isinstance(pair, list) and len(pair) == 2 and all(isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) for value in pair)
            if not finite_pair(point) or not finite_pair(raw):
                errors.append(f"input {index}: missing/nonfinite raw coordinate pair")
            elif any(not math.isclose(raw[axis], point[axis] * physical[axis] / logical[axis], rel_tol=1e-6, abs_tol=1e-4) for axis in (0, 1)):
                errors.append(f"input {index}: logical coordinate was not mapped to native client pixels")
    return errors


def run(output: Path, godot: Path, timeout: int) -> dict:
    receipt = check_prepared(output)
    if not godot.is_file():
        raise ValueError("verified native Godot executable is missing")
    summaries = []
    for mode, size in (("desktop", (1280, 720)), ("touch", (960, 540))):
        target = output / mode
        target.mkdir()
        # --main-pack replaces project settings. Redirect OS roots BEFORE the
        # process exists; never depend on script-time custom_user_dir_name.
        roaming, local = target / "profile" / "Roaming", target / "profile" / "Local"
        roaming.mkdir(parents=True)
        local.mkdir(parents=True)
        environment = dict(os.environ, APPDATA=str(roaming.resolve()), LOCALAPPDATA=str(local.resolve()))
        command = [str(godot.resolve()), "--path", str((output / "resource-root").resolve()),
                   "--main-pack", str((output / "decoded/index.pck").resolve()),
                   "--script", str((output / "qa" / QA.name).resolve()), "--rendering-method", "gl_compatibility",
                   "--resolution", f"{size[0]}x{size[1]}", "--disable-vsync", "--no-focus", "--",
                   f"--output={target.resolve()}", f"--preparation={(output / 'preparation.json').resolve()}",
                   f"--coordinates={(output / 'qa' / COORDINATES.name).resolve()}",
                   f"--pack-root={(output / 'decoded').resolve()}", f"--profile-root={roaming.resolve()}", f"--viewport={mode}"]
        with (target / "engine.log").open("xb") as log:
            process = spawn_background(command, cwd=output / "resource-root", stdout=log, env=environment)
            timed_out = False
            try:
                try:
                    exit_code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    process.kill()
                    exit_code = process.wait(timeout=30)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=30)
                process.close()
            desktop = process.desktop_receipt
        path = target / "smoke.json"
        result = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}
        geometry_errors = observation_geometry_errors(result, size)
        text = (target / "engine.log").read_text(encoding="utf-8", errors="replace")
        bad_log = any(token in text for token in ("SCRIPT ERROR:", "ERROR:", "USER ERROR:"))
        frames = []
        for frame in result.get("frames", []):
            name = relative_path(frame["file"])
            payload = (target / name).read_bytes()
            frames.append({"file": name, "bytes": len(payload), "sha256": digest(payload)})
        summaries.append({"viewport": mode, "exit_code": exit_code, "timed_out": timed_out,
                          "requested_window_size":list(size), "production_internal_render_size":[1280,720],
                          "actual_window_size":result.get("window_client_size"),
                          "coordinate_errors":geometry_errors,
                          "desktop": desktop, "engine_errors_in_log": bad_log,
                          "report_sha256": digest(path.read_bytes()) if path.is_file() else "",
                          "frames": frames, "passed": exit_code == 0 and not timed_out and not bad_log and not geometry_errors and result.get("passed") is True})
        if not summaries[-1]["passed"]:
            break
    # PCKs and supplied QA are still exact after both executions.
    for row in receipt["packs"]:
        read_bound(output / "decoded", row["path"], row)
    if digest((output / "qa" / QA.name).read_bytes()) != receipt["qa_script_sha256"]:
        raise ValueError("supplied QA changed during smoke")
    if digest((output / "qa" / COORDINATES.name).read_bytes()) != receipt["coordinate_helper_sha256"]:
        raise ValueError("supplied coordinate helper changed during smoke")
    result = {"kind": "native_frozen_export_monster_smoke", "build_id": receipt["build_id"],
              "passed": len(summaries) == 2 and all(row["passed"] for row in summaries),
              "godot_executable": str(godot.resolve()), "godot_sha256": digest(godot.read_bytes()),
              "runs": summaries, "source_fallback": False, "browser_acceptance": False,
              "visual_acceptance": False, "physical_phone": False, "user_acceptance": False}
    write_json(output / "runner.json", result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-profile-sha256", default="")
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--timeout", type=int, default=600)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--prepare-only", action="store_true")
    mode.add_argument("--check-only", action="store_true")
    mode.add_argument("--run", action="store_true")
    args = parser.parse_args()
    try:
        if args.prepare_only:
            if args.export is None:
                parser.error("--prepare-only requires --export")
            result = prepare(args.export.resolve(), args.output.resolve(), args.expected_profile_sha256)
        elif args.check_only:
            result = check_prepared(args.output.resolve())
        else:
            if args.timeout <= 0:
                raise ValueError("timeout must be positive")
            result = run(args.output.resolve(), args.godot, args.timeout)
        print(json.dumps({"build_id": result["build_id"], "mode": "prepare" if args.prepare_only else "check" if args.check_only else "run", "passed": result.get("passed", True)}))
        return 0 if result.get("passed", True) else 1
    except (OSError, ValueError, KeyError, TypeError, EOFError) as error:
        print(f"FROZEN MONSTER SMOKE: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
