#!/usr/bin/env python3
"""Bind one Web export, runtime-pack graph, shell, and source revision."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit


RELEASE_MANIFEST = "release_manifest.json"
MAX_TOTAL_BYTES = 104_857_600


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def compress_wasm(path: Path) -> None:
    payload = path.read_bytes()
    if payload.startswith(b"\x1f\x8b"):
        payload = gzip.decompress(payload)
    if not payload.startswith(b"\x00asm"):
        raise ValueError("Cannot package a non-WebAssembly engine")
    packed = gzip.compress(payload, compresslevel=9, mtime=0)
    if gzip.decompress(packed) != payload:
        raise ValueError("WebAssembly lossless transport round trip failed")
    path.write_bytes(packed)


def compress_pck_transport(export_dir: Path) -> None:
    pck_files = [export_dir / "index.pck"]
    packs_dir = export_dir / "packs"
    if packs_dir.is_dir():
        pck_files.extend(sorted(packs_dir.glob("*.pck")))
    for path in pck_files:
        if not path.is_file():
            raise ValueError(f"missing PCK transport artifact: {path.name}")
        payload = path.read_bytes()
        if payload.startswith(b"\x1f\x8b"):
            decoded = gzip.decompress(payload)
        else:
            decoded = payload
        if not decoded.startswith(b"GDPC"):
            raise ValueError(f"{path.name} is not a valid Godot PCK payload")
        if payload.startswith(b"\x1f\x8b"):
            continue
        packed = gzip.compress(decoded, compresslevel=9, mtime=0)
        if gzip.decompress(packed) != decoded:
            raise ValueError(f"{path.name} gzip transport failed its lossless round trip")
        temporary = path.with_name(path.name + ".tmp")
        try:
            temporary.write_bytes(packed)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def git_value(repo: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), *args], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def inspect_packaged_export(export_dir: Path) -> dict:
    """Check stored transport bytes and decoded pack identities before publishing."""
    manifest = json.loads((export_dir / RELEASE_MANIFEST).read_text(encoding="utf-8-sig"))
    records = manifest["artifacts"]
    by_path = {entry["path"]: entry for entry in records}
    if len(by_path) != len(records):
        raise ValueError("Duplicate artifact paths in release manifest")
    actual_paths = {p.relative_to(export_dir).as_posix() for p in export_dir.rglob("*") if p.is_file()}
    if actual_paths != set(by_path) | {RELEASE_MANIFEST}:
        raise ValueError("Web directory has missing or unlisted transport files")
    required = {"index.html", "index.js", "index.wasm", "index.pck", "runtime_pack_manifest.json"}
    if not required.issubset(by_path):
        raise ValueError("Required Web artifacts are missing")
    total = 0
    for relative, entry in by_path.items():
        path = (export_dir / relative).resolve()
        if not path.is_relative_to(export_dir) or path == export_dir:
            raise ValueError(f"Artifact escapes export directory: {relative}")
        total += path.stat().st_size
        if path.stat().st_size != entry["bytes"] or sha256(path) != entry["sha256"]:
            raise ValueError(f"Artifact size/hash mismatch: {relative}")
        if path.suffix == ".pck" or relative == "index.wasm":
            if entry.get("content_encoding") != "gzip":
                raise ValueError(f"Hosting requires gzip transport: {relative}")
            decoded = gzip.decompress(path.read_bytes())
            magic = b"GDPC" if path.suffix == ".pck" else b"\x00asm"
            if not decoded.startswith(magic):
                raise ValueError(f"Invalid decoded artifact: {relative}")
            if len(decoded) != entry.get("decoded_bytes") or hashlib.sha256(decoded).hexdigest() != entry.get("decoded_sha256"):
                raise ValueError(f"Decoded artifact size/hash mismatch: {relative}")
    if total != manifest["artifacts_total_bytes"]:
        raise ValueError("Manifest aggregate size does not match its artifacts")
    directory_bytes = total + (export_dir / RELEASE_MANIFEST).stat().st_size
    if directory_bytes >= MAX_TOTAL_BYTES:
        raise ValueError(f"Complete Web directory is {directory_bytes} bytes; must be below {MAX_TOTAL_BYTES}")
    if manifest["root_pck"] != by_path["index.pck"] or manifest["runtime_pack_manifest"] != by_path["runtime_pack_manifest.json"]:
        raise ValueError("Release identity references do not match artifact records")
    runtime = json.loads((export_dir / "runtime_pack_manifest.json").read_text(encoding="utf-8-sig"))
    if runtime["release_id"] != manifest["build_id"]:
        raise ValueError("Runtime and release build identities differ")
    runtime_packs = runtime["packs"]
    declared_packs = {p["id"]: p for p in manifest["packs"]}
    if len(declared_packs) != len(manifest["packs"]) or set(runtime_packs) != set(declared_packs):
        raise ValueError("Runtime and release pack sets differ")
    for pack_id, pack in runtime_packs.items():
        declared = declared_packs[pack_id]
        if pack["version"] != manifest["build_id"]:
            raise ValueError(f"Pack version drift: {pack_id}")
        for key in ("url", "bytes", "sha256", "dependencies"):
            if pack.get(key) != declared.get(key):
                raise ValueError(f"Pack metadata drift: {pack_id}/{key}")
        if any(dep not in runtime_packs for dep in pack.get("dependencies", [])):
            raise ValueError(f"Unknown pack dependency: {pack_id}")
        if str(pack.get("status", "")).startswith("embedded"):
            continue
        url = urlsplit(pack["url"])
        entry = by_path.get(url.path)
        if url.scheme or url.netloc or entry is None:
            raise ValueError(f"Missing local pack: {pack_id}")
        if entry.get("decoded_bytes") != pack["bytes"] or entry.get("decoded_sha256") != pack["sha256"]:
            raise ValueError(f"Runtime pack does not match decoded delivery bytes: {pack_id}")
        if pack["sha256"] not in url.query:
            raise ValueError(f"Pack URL lacks content identity: {pack_id}")
    return {"build_id": manifest["build_id"], "artifacts": len(records), "directory_bytes": directory_bytes}


def inject_shell_identity(html_path: Path, build_id: str) -> None:
    text = html_path.read_text(encoding="utf-8")
    replacement = json.dumps(build_id)
    text, shell_count = re.subn(
        r"const SHELL_BUILD_ID\s*=\s*['\"][^'\"]*['\"]\s*;",
        f"const SHELL_BUILD_ID = {replacement};",
        text,
        count=1,
    )
    text, pack_count = re.subn(
        r"const RUNTIME_PACK_CONTRACT\s*=\s*['\"][^'\"]*['\"]\s*;",
        f"const RUNTIME_PACK_CONTRACT = {replacement};",
        text,
        count=1,
    )
    if shell_count != 1 or pack_count != 1:
        raise ValueError("index.html does not contain injectable shell identity constants")
    html_path.write_text(text, encoding="utf-8")


def build_manifest(export_dir: Path, runtime_manifest_path: Path, source_commit: str = "") -> dict:
    runtime = json.loads(runtime_manifest_path.read_text(encoding="utf-8-sig"))
    build_id = str(runtime.get("release_id") or runtime.get("build_id") or "").strip()
    if not build_id:
        raise ValueError("runtime pack manifest has no release identity")
    declared_commit = str(runtime.get("generated_from_commit", "")).strip()
    if source_commit and declared_commit and source_commit != declared_commit:
        raise ValueError(f"source commit mismatch: runtime={declared_commit} requested={source_commit}")
    source_commit = source_commit or declared_commit
    if not source_commit:
        raise ValueError("runtime pack manifest has no source commit")

    sidecar = export_dir / "runtime_pack_manifest.json"
    if not sidecar.is_file():
        raise ValueError("export is missing runtime_pack_manifest.json")
    if sidecar.read_bytes() != runtime_manifest_path.read_bytes():
        raise ValueError("exported runtime pack manifest differs from the source manifest")
    html = export_dir / "index.html"
    if not html.is_file():
        raise ValueError("export is missing index.html")
    inject_shell_identity(html, build_id)

    files = sorted(
        path for path in export_dir.rglob("*")
        if path.is_file() and path.name != RELEASE_MANIFEST
    )
    records = []
    for path in files:
        record = {
            "path": path.relative_to(export_dir).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        if path.suffix.lower() == ".pck":
            payload = path.read_bytes()
            if not payload.startswith(b"\x1f\x8b"):
                raise ValueError(f"{path.name} is missing gzip transport encoding")
            decoded = gzip.decompress(payload)
            if not decoded.startswith(b"GDPC"):
                raise ValueError(f"{path.name} gzip payload is not a Godot PCK")
            record.update(
                content_encoding="gzip",
                decoded_bytes=len(decoded),
                decoded_sha256=hashlib.sha256(decoded).hexdigest(),
            )
        records.append(record)
    wasm = export_dir / "index.wasm"
    if wasm.is_file() and wasm.read_bytes().startswith(b"\x1f\x8b"):
        decoded = gzip.decompress(wasm.read_bytes())
        if not decoded.startswith(b"\x00asm"):
            raise ValueError("Compressed engine is not WebAssembly")
        wasm_record = next(item for item in records if item["path"] == "index.wasm")
        wasm_record.update(content_encoding="gzip", decoded_bytes=len(decoded),
                           decoded_sha256=hashlib.sha256(decoded).hexdigest())
    by_path = {item["path"]: item for item in records}
    required = {"index.html", "index.js", "index.wasm", "index.pck", "runtime_pack_manifest.json"}
    missing = sorted(required - by_path.keys())
    if missing:
        raise ValueError("missing required Web artifacts: " + ", ".join(missing))

    pack_records = []
    for pack_id, pack in runtime.get("packs", {}).items():
        url = str(pack.get("url", ""))
        digest = str(pack.get("sha256", "")).lower()
        embedded = str(pack.get("status", "")).startswith("embedded")
        if not embedded and (not digest or digest not in url):
            raise ValueError(f"{pack_id}: URL is not keyed by its content hash")
        pack_records.append({
            "id": str(pack_id),
            "url": url,
            "bytes": int(pack.get("bytes", 0)),
            "sha256": digest,
            "dependencies": list(pack.get("dependencies", [])),
            "embedded": embedded,
        })

    compatibility_payload = json.dumps({
        "build_id": build_id,
        "source_commit": source_commit,
        "root_pck": by_path["index.pck"]["sha256"],
        "packs": [{"id": item["id"], "sha256": item["sha256"]} for item in pack_records],
    }, sort_keys=True, separators=(",", ":")).encode("utf-8")
    total_bytes = sum(int(item["bytes"]) for item in records)
    if total_bytes >= MAX_TOTAL_BYTES:
        raise ValueError(
            f"Web payload {total_bytes} bytes reaches or exceeds the 100 MiB limit"
        )
    return {
        "schema_version": 2,
        "project": "Ashen Oath",
        "build_id": build_id,
        "source": {
            "git_commit": source_commit,
            "dirty": bool(runtime.get("source_dirty", False)),
        },
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "compatibility_key": hashlib.sha256(compatibility_payload).hexdigest(),
        "runtime_pack_manifest": by_path["runtime_pack_manifest.json"],
        "root_pck": by_path["index.pck"],
        "artifacts_total_bytes": total_bytes,
        "artifacts": records,
        "packs": pack_records,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--runtime-pack-manifest", type=Path)
    parser.add_argument("--source-commit", default="")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--compress-wasm", action="store_true")
    parser.add_argument("--check-existing", action="store_true", help="Read-only package identity/size inspection; no game execution")
    args = parser.parse_args()
    export_dir = args.export_dir.resolve()
    if not export_dir.is_dir():
        print(f"missing export directory: {export_dir}", file=sys.stderr)
        return 2
    if args.check_existing:
        try:
            print(json.dumps(inspect_packaged_export(export_dir)))
            return 0
        except (OSError, ValueError, TypeError, KeyError) as error:
            print(f"PACKAGE INTEGRITY: {error}", file=sys.stderr)
            return 1
    runtime_manifest = (args.runtime_pack_manifest or (export_dir / "runtime_pack_manifest.json")).resolve()
    if not runtime_manifest.is_file():
        print(f"missing runtime pack manifest: {runtime_manifest}", file=sys.stderr)
        return 2
    source_commit = args.source_commit
    if not source_commit:
        source_commit = git_value(Path(__file__).resolve().parents[3], "rev-parse", "HEAD")
    try:
        if args.compress_wasm:
            compress_wasm(export_dir / "index.wasm")
        compress_pck_transport(export_dir)
        manifest = build_manifest(export_dir, runtime_manifest, source_commit)
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
        print(f"WEB RELEASE MANIFEST: FAIL - {error}", file=sys.stderr)
        return 1
    output = (args.output or (export_dir / RELEASE_MANIFEST)).resolve()
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if output == export_dir / RELEASE_MANIFEST:
        try:
            inspect_packaged_export(export_dir)
        except (OSError, ValueError, TypeError, KeyError) as error:
            print(f"PACKAGE INTEGRITY: {error}", file=sys.stderr)
            return 1
    print(
        f"WEB RELEASE MANIFEST: PASS ({len(manifest['artifacts'])} artifacts, "
        f"{manifest['artifacts_total_bytes'] / 1048576:.1f} MB, "
        f"PCK {manifest['root_pck']['sha256']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
