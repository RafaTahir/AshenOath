"""Author exactly one fresh creature candidate under an explicit heavy-slot grant.

The maintained Blender recipe and source validator own the asset changes.
This runner only bounds them and preserves inputs, logs and results.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "outputs/AshenOathTheRoadBetweenCrowns"
ART = ROOT / "art_source/art_recovery_v2"
MODELS = ART / "models/living_assets_stage3_20261107/creatures"
BLENDER = Path("C:/Program Files/Blender Foundation/Blender 5.2/blender.exe")
RECIPE_NAMES = (
    "author_living_creature_motion.py", "living_creature_motion_profiles.py",
    "preserve_creature_action_bytes.py", "graft_creature_ambient.py",
    "verify_living_creature_motion.py", "living_creature_preview.py",
    "creature_morph_lineage.py",
)
PREVIEWS = ("Idle_00.png", "Idle_25.png", "Idle_50.png", "Idle_75.png",
            "Investigate_50.png", "Feed_38.png", "Feed_61.png", "Sleep_50.png")


def row(path):
    path = Path(path).resolve(strict=True)
    return {"path": str(path), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def unchanged(rows):
    return all(Path(item["path"]).is_file() and row(item["path"]) == item for item in rows)


def prepare(asset):
    if not re.fullmatch(r"M(?:0[1-9]|1[0-9]|20)", asset):
        raise ValueError("Explicit M01..M20 identity required")
    registry = GAME / "data/design_pack_assets.json"
    record = json.loads(registry.read_text(encoding="utf-8-sig"))["assets"][asset]
    resource = record["path"]
    prefix = "res://assets_external/design_pack_v1/creatures/" + asset + "_"
    if not resource.startswith(prefix):
        raise ValueError("Creature registry identity does not match requested source")
    source = (GAME / resource[6:]).resolve(strict=True)
    if not source.is_relative_to(GAME.resolve()) or row(source)["sha256"] != record["sha256"]:
        raise ValueError("Production source differs from registered retained input")
    folder = (MODELS / asset).resolve()
    if not folder.is_relative_to(MODELS.resolve()):
        raise ValueError("Candidate directory leaves its authoring root")
    if folder.exists() and any(folder.iterdir()):
        raise ValueError("Prior candidate directory is nonempty; preserve/review it instead of overwriting")
    raw = source.read_bytes()
    if raw[:4] != b"glTF":
        raise ValueError("Retained source is not GLB")
    length = struct.unpack_from("<I", raw, 12)[0]
    document = json.loads(raw[20:20 + length])
    paths = [Path(__file__), BLENDER, registry, source]
    paths += [ART / "tools" / name for name in RECIPE_NAMES]
    for entry in document.get("images", []) + document.get("buffers", []):
        uri = entry.get("uri", "")
        if not uri or uri.startswith("data:"):
            continue
        parsed = urlsplit(uri)
        if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
            raise ValueError("Retained dependency must be a local relative URI")
        target = (source.parent / unquote(parsed.path)).resolve(strict=True)
        if not target.is_relative_to(source.parent):
            raise ValueError("Retained dependency leaves source directory")
        paths.append(target)
    return source, folder, [row(path) for path in dict.fromkeys(paths)]


def verify_outputs(folder, asset, authored, contract):
    bindings = ((asset + "_living_v001.blend", "blend_sha256"),
                (asset + "_living_export.glb", "blender_export_sha256"),
                (asset + "_living_candidate.glb", "candidate_sha256"))
    for name, key in bindings:
        target = (folder / name).resolve(strict=True)
        if not target.is_relative_to(folder) or row(target)["sha256"] != authored.get(key):
            raise ValueError("Authored output differs from its receipt: " + name)
    candidate = row(folder / (asset + "_living_candidate.glb"))
    if candidate["sha256"] != contract.get("candidate_sha256") or candidate["bytes"] != contract.get("candidate_bytes"):
        raise ValueError("Candidate differs from verified source contract")
    frames = authored.get("source_review_frames", [])
    expected = {str((folder / "source_review" / name).resolve()) for name in PREVIEWS}
    resolved = [str(Path(frame).resolve(strict=True)) for frame in frames]
    if len(resolved) != len(PREVIEWS) or set(resolved) != expected:
        raise ValueError("Expected exactly eight distinct authored preview frames")
    for frame in resolved:
        target = Path(frame)
        if not target.is_relative_to(folder):
            raise ValueError("Preview path leaves candidate folder")
        raw = target.read_bytes()
        if len(raw) < 33 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR" or struct.unpack_from(">II", raw, 16) != (900, 700):
            raise ValueError("Invalid or unexpected preview image: " + frame)
    outputs = []
    for path in sorted(folder.rglob("*")):
        if not path.resolve().is_relative_to(folder):
            raise ValueError("Output path leaves candidate folder: " + str(path))
        if path.is_file():
            outputs.append(row(path))
    if any(item["bytes"] >= 100 * 1024 * 1024 for item in outputs):
        raise ValueError("Authored file exceeds committed-file limit")
    return outputs


def run_child(command, output, label, timeout):
    log = output / (label + ".log")
    started = time.monotonic()
    timed_out = False
    environment = os.environ.copy()
    environment.update(OMP_NUM_THREADS="2", MKL_NUM_THREADS="2", OPENBLAS_NUM_THREADS="2")
    with log.open("wb") as stream:
        child = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=stream,
                                 stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        print(json.dumps({"stage": label, "pid": child.pid, "timeout_seconds": timeout}), flush=True)
        try:
            child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            child.kill()
            child.wait(timeout=15)
    return {"stage": label, "command": command, "pid": child.pid, "exit_code": child.returncode,
            "timed_out": timed_out, "owned_process_exited": child.poll() is not None,
            "seconds": round(time.monotonic() - started, 3), "log": str(log),
            "passed": child.returncode == 0 and not timed_out}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--author-timeout", type=int, default=480)
    parser.add_argument("--source-timeout", type=int, default=90)
    parser.add_argument("--deadline-utc")
    args = parser.parse_args()
    if not 10 <= args.author_timeout <= 480 or not 10 <= args.source_timeout <= 90:
        parser.error("Timeouts must stay within the established per-stage bounds")
    deadline = datetime.datetime.fromisoformat(args.deadline_utc) if args.deadline_utc else None
    if deadline is not None and deadline.tzinfo is None:
        parser.error("The explicit deadline must include its UTC offset")
    if not re.fullmatch(r"[a-z0-9_-]+", args.label):
        parser.error("Use a fresh simple receipt label")
    source, folder, inputs = prepare(args.asset)
    receipt_root = Path(__file__).resolve().parent
    output = (receipt_root / args.asset / args.label).resolve()
    if not output.is_relative_to(receipt_root):
        raise ValueError("Receipt directory leaves its verification root")
    if output.exists():
        raise ValueError("Receipt directory already exists")
    print(json.dumps({"asset": args.asset, "ready": True, "execute": args.execute,
                      "source": str(source), "input_count": len(inputs), "output": str(output)}), flush=True)
    if not args.execute:
        return 0
    output.mkdir(parents=True)
    receipt = {"asset": args.asset, "inputs": inputs, "runs": [], "passed": False,
               "native_verified": False, "visual_accepted": False,
               "deadline_utc": deadline.isoformat() if deadline else None,
               "production_overwritten": False, "attack_profiles_recalibrated": False}
    try:
        commands = [
            ("blender_author", [str(BLENDER), "--background", "--threads", "2", "--python-exit-code", "1",
                                "--python", str(ART / "tools/author_living_creature_motion.py"),
                                "--", "--asset", args.asset, "--source-game", str(GAME), "--render"], args.author_timeout),
            ("source_contract", [sys.executable, str(ART / "tools/verify_living_creature_motion.py"),
                                 "--asset", args.asset], args.source_timeout),
        ]
        for label, command, timeout in commands:
            if not unchanged(inputs):
                raise ValueError("Frozen authoring input changed before " + label)
            if deadline is not None:
                remaining = (deadline - datetime.datetime.now(datetime.timezone.utc)).total_seconds()
                if remaining < 30:
                    raise ValueError("Explicit production-window boundary reached before " + label)
                timeout = min(timeout, remaining - 20)
            result = run_child(command, output, label, timeout)
            receipt["runs"].append(result)
            if not result["passed"]:
                raise ValueError("Candidate stage failed: " + label)
        authored = json.loads((folder / "authoring.json").read_text())
        contract = json.loads((folder / "source_contract.json").read_text())
        if contract.get("status") != "source_contract_pass" or contract.get("asset") != args.asset:
            raise ValueError("Missing successful exact source contract")
        if not unchanged(inputs):
            raise ValueError("Frozen input changed during authoring")
        receipt["outputs"] = verify_outputs(folder, args.asset, authored, contract)
        receipt["candidate_bytes"] = contract["candidate_bytes"]
        receipt["net_source_bytes"] = contract["net_source_bytes"]
        receipt["sources_unchanged"] = True
        receipt["passed"] = True
    except Exception as error:
        receipt["error"] = str(error)
        receipt["sources_unchanged"] = unchanged(inputs)
    finally:
        source_row = next(item for item in inputs if item["path"] == str(source))
        receipt["production_overwritten"] = not unchanged([source_row])
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in receipt.items() if key not in ("inputs", "outputs")}), flush=True)
    return 0 if receipt["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
