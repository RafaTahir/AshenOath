"""Index the exported catalog by byte range while preserving its full JSON contents."""
import hashlib
import json
from pathlib import Path

from compact_runtime_packs import parse_archive, replace_resources


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def indexed_catalog(payload):
    manifest = json.loads(payload)
    lines = manifest["lines"]
    if manifest.get("runtime_voice_format") == 1 or not isinstance(lines, (list, dict)):
        return payload
    mapping = isinstance(lines, dict)
    entries = lines.items() if mapping else ((row["id"], row) for row in lines)
    rows = bytearray()
    lookup = []
    for voice_id, entry in entries:
        if rows:
            rows.extend(b",\n")
        if mapping:
            rows.extend(compact(voice_id) + b":")
        encoded = compact(entry)
        text_hash = hashlib.sha256(entry["text"].strip().encode("utf-8")).hexdigest()
        lookup.append([voice_id, entry["speaker_id"], text_hash, len(rows), len(encoded), entry.get("scene", "")])
        rows.extend(encoded)
    index = {"allow_generated": manifest.get("allow_generated_current_recordings", False), "takes": lookup}
    header = b'{"runtime_voice_format":1,\n"runtime_lookup":' + compact(index) + b",\n"
    prefix, suffix = (b"{", b"}") if mapping else (b"[", b"]")
    metadata = {k: v for k, v in manifest.items() if k != "lines"}
    tail = (b"," + compact(metadata)[1:]) if metadata else b"}"
    return header + b'"lines":' + prefix + b"\n" + rows + suffix + tail


def index_exported_voices(root: Path) -> None:
    original = root.read_bytes()
    archive = parse_archive(original)
    catalog_path = "voice_production_manifest.json"
    files = {entry.path: entry for entry in archive.entries}
    if catalog_path not in files or not any(f"scripts/core/indexed_voice_takes.{ext}" in files for ext in ("gd", "gdc")):
        raise ValueError("The Web root is missing the dialogue catalog or its runtime reader")
    previous = files[catalog_path].payload
    indexed = indexed_catalog(previous)
    if previous != indexed:
        root.write_bytes(replace_resources(original, {catalog_path: indexed}))
