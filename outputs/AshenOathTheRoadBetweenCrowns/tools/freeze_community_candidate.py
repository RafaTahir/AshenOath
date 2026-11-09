"""Freeze exact final Web bytes as native test inputs without exporting again."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit

from community_acceptance_packs import _identity, verify_candidate
from compact_runtime_packs import parse_archive
from runtime_pack_validation import require_valid_pack_graph


def inside(root: Path, relative: str) -> Path:
    parts = relative.split("/")
    if any(part in ("", ".", "..") or ":" in part or "\\" in part for part in parts):
        raise ValueError("ambiguous or escaping artifact path: " + relative)
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()) or path == root.resolve():
        raise ValueError("artifact path escapes its root: " + relative)
    return path


def delivered(path: Path, record: dict) -> bytes:
    content = path.read_bytes()
    if len(content) != record.get("bytes") or hashlib.sha256(content).hexdigest() != record.get("sha256"):
        raise ValueError("transport bytes differ from the final release: " + str(path))
    encoded = content.startswith(b"\x1f\x8b")
    if encoded != (record.get("content_encoding") == "gzip"):
        raise ValueError("transport encoding differs from its release receipt: " + str(path))
    decoded = gzip.decompress(content) if encoded else content
    _identity(decoded, record, str(path))
    return decoded


def freeze(export: Path, output: Path, *, required_resources=None) -> dict:
    export = export.resolve(strict=True)
    output = output.resolve()
    if output.is_relative_to(export) or export.is_relative_to(output):
        raise ValueError("native freeze must be separate from the final Web export")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("native freeze output must be new or empty")
    manifest_path = export / "release_manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    release = json.loads(manifest_bytes.decode("utf-8-sig"))
    root_record = release.get("root_pck", {})
    if root_record.get("path") != "index.pck":
        raise ValueError("expected a maintained final Web release receipt")
    root_bytes = delivered(export / "index.pck", root_record)
    root_entries = {row.path:row.payload for row in parse_archive(root_bytes).entries}
    runtime_bytes = root_entries["runtime_pack_manifest.json"]
    _identity(runtime_bytes, release["runtime_pack_manifest"], "embedded runtime manifest")
    sidecar_bytes = delivered(export / "runtime_pack_manifest.json", release["runtime_pack_manifest"])
    if sidecar_bytes != runtime_bytes:
        raise ValueError("final runtime sidecar differs from the root manifest")
    runtime = json.loads(runtime_bytes.decode("utf-8-sig"))
    require_valid_pack_graph(runtime)
    artifacts = {row["path"]:row for row in release["artifacts"]}
    if len(artifacts) != len(release["artifacts"]):
        raise ValueError("duplicate release artifact records")
    cache_bytes = root_entries[".godot/global_script_class_cache.cfg"]
    plans, names = [], set()
    for key, pack in runtime["packs"].items():
        if str(pack.get("status", "")).startswith("embedded"):
            continue
        url = urlsplit(str(pack.get("url", "")))
        relative = unquote(url.path)
        if url.scheme or url.netloc or not relative.startswith("packs/") or not relative.endswith(".pck"):
            raise ValueError("invalid final external pack URL: " + key)
        source = inside(export, relative)
        name = str(pack.get("candidate_artifact") or relative.split("/")[-1])
        destination = inside(output / "packs", name)
        if name.casefold() in names or destination.name.casefold() == "base.pck":
            raise ValueError("duplicate or reserved native pack artifact: " + name)
        names.add(name.casefold())
        plans.append((source, destination, artifacts[relative]))
    output.mkdir(parents=True, exist_ok=True)
    (output / "packs").mkdir(exist_ok=True)
    (output / "index.pck").write_bytes(root_bytes)
    (output / "release_manifest.json").write_bytes(manifest_bytes)
    (output / "runtime_pack_manifest.json").write_bytes(runtime_bytes)
    (output / "global_script_class_cache.cfg").write_bytes(cache_bytes)
    for source, destination, record in plans:
        content = delivered(source, record)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
    closure = verify_candidate(output / "index.pck", output / "packs", output / "release_manifest.json",
                               required_resources=required_resources)
    result = {"schema_version":1, "kind":"frozen_final_web_candidate", "status":"pass",
              "source_export":str(export), "release_manifest_sha256":hashlib.sha256(manifest_bytes).hexdigest(),
              "candidate_closure":closure, "class_cache":str(output / "global_script_class_cache.cfg"),
              "engine_started":False, "source_export_modified":False, "gameplay_acceptance":False}
    (output / "freeze.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--scope", choices=["campaign", "cast-observation"], default="campaign",
                        help="campaign requires expansion resources; cast-observation also permits an exact historical release")
    args = parser.parse_args()
    try:
        result = freeze(args.export, args.output, required_resources=["scenes/main.tscn"] if args.scope == "cast-observation" else None)
    except (OSError, ValueError, KeyError, EOFError) as error:
        parser.exit(2, f"native candidate freeze failed: {error}\n")
    print(json.dumps({"status":result["status"], "receipt":str(args.output.resolve() / "freeze.json"), "engine_started":False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
