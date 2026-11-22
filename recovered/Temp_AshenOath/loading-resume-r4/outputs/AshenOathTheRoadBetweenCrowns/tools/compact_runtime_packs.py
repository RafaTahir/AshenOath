#!/usr/bin/env python3
"""Keep shared Godot metadata in the authoritative root instead of every pack.

Only three engine metadata paths are eligible. Every content resource retains
its path, payload, flags and digest. UID caches need an exact mapping subset;
global classes and the icon need identical authority bytes. project.binary is
deliberately retained because Web and standalone exports use different settings.

Godot 4.6 reloads class/UID metadata through the merged virtual filesystem when
mounting a pack. An omitted path keeps the root's authoritative resource:
https://github.com/godotengine/godot/blob/4.6/core/config/project_settings.cpp
https://github.com/godotengine/godot/blob/4.6/core/io/file_access_pack.cpp
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
import gzip
import hashlib
import json
from pathlib import Path
import struct


UID_CACHE = ".godot/uid_cache.bin"
METADATA_PATHS = frozenset({UID_CACHE, ".godot/global_script_class_cache.cfg", "assets/icons/icon.svg"})
HEADER_BYTES = 112


@dataclass(frozen=True)
class PckEntry:
    path: str
    encoded_path: bytes
    payload: bytes
    md5: bytes
    flags: int = 0

    def with_payload(self, payload: bytes) -> PckEntry:
        return replace(self, payload=payload, md5=hashlib.md5(payload).digest())


@dataclass(frozen=True)
class PckArchive:
    header: bytes
    entries: tuple[PckEntry, ...]
    was_gzip: bool = False


def _read(format_: str, payload: bytes, position: int):
    size = struct.calcsize(format_)
    if position < 0 or position + size > len(payload):
        raise ValueError("Truncated PCK or UID table")
    values = struct.unpack_from(format_, payload, position)
    return values, position + size


def parse_archive(payload: bytes) -> PckArchive:
    """Read a standalone unencrypted Godot 4.6 PCK v3, optionally gzip encoded."""
    was_gzip = payload.startswith(b"\x1f\x8b")
    decoded = gzip.decompress(payload) if was_gzip else payload
    if len(decoded) < HEADER_BYTES or decoded[:4] != b"GDPC":
        raise ValueError("Not a standalone Godot PCK")
    version, _, _, _, flags = struct.unpack_from("<5I", decoded, 4)
    file_base, directory = struct.unpack_from("<QQ", decoded, 24)
    if version != 3 or flags != 2 or file_base != HEADER_BYTES:
        raise ValueError("Only standalone, relative-base, unencrypted PCK v3 is supported")
    if directory < file_base or directory > len(decoded) - 4:
        raise ValueError("Invalid PCK directory offset")
    (count,), position = _read("<I", decoded, directory)
    if count > (len(decoded) - position) // 40:
        raise ValueError("Invalid PCK entry count")
    entries = []
    names = set()
    for _ in range(count):
        (length,), position = _read("<I", decoded, position)
        if length == 0 or position + length > len(decoded):
            raise ValueError("Invalid PCK path length")
        encoded = decoded[position:position + length]
        position += length
        path = encoded.rstrip(b"\0").decode("utf-8")
        if not path or "\0" in path or "\\" in path or path.startswith("/") or ":" in path or ".." in path.split("/"):
            raise ValueError("Unsafe PCK resource path")
        if path in names:
            raise ValueError("Duplicate PCK resource path: " + path)
        names.add(path)
        (offset, size), position = _read("<QQ", decoded, position)
        (digest, entry_flags), position = _read("<16sI", decoded, position)
        if entry_flags != 0 or offset > directory - file_base or size > directory - file_base - offset:
            raise ValueError("Unsupported flags or invalid resource range: " + path)
        data = decoded[file_base + offset:file_base + offset + size]
        if hashlib.md5(data).digest() != digest:
            raise ValueError("PCK resource digest mismatch: " + path)
        entries.append(PckEntry(path, encoded, data, digest, entry_flags))
    if position != len(decoded):
        raise ValueError("Unexpected data after standalone PCK directory")
    return PckArchive(decoded[:HEADER_BYTES], tuple(entries), was_gzip)


def encode_archive(archive: PckArchive) -> bytes:
    """Serialize preserved resources; retain the input raw/gzip transport format."""
    output = bytearray(archive.header)
    records = []
    for entry in archive.entries:
        output.extend(b"\0" * (-len(output) % 16))
        records.append((entry, len(output) - HEADER_BYTES))
        output.extend(entry.payload)
    output.extend(b"\0" * (-len(output) % 16))
    struct.pack_into("<Q", output, 32, len(output))
    output.extend(struct.pack("<I", len(records)))
    for entry, offset in records:
        output.extend(struct.pack("<I", len(entry.encoded_path)))
        output.extend(entry.encoded_path)
        output.extend(struct.pack("<QQ16sI", offset, len(entry.payload), entry.md5, entry.flags))
    raw = bytes(output)
    return gzip.compress(raw, compresslevel=9, mtime=0) if archive.was_gzip else raw


def replace_resources(payload: bytes, replacements: dict[str, bytes]) -> bytes:
    """Explicitly replace named resource bytes, e.g. an embedded pack manifest."""
    archive = parse_archive(payload)
    missing = set(replacements) - {entry.path for entry in archive.entries}
    if missing:
        raise ValueError("Cannot replace missing PCK resources: " + ", ".join(sorted(missing)))
    entries = tuple(entry.with_payload(replacements[entry.path]) if entry.path in replacements else entry
                    for entry in archive.entries)
    result = encode_archive(replace(archive, entries=entries))
    # Validate the actual encoded result, including every updated resource MD5.
    parsed = parse_archive(result)
    for original, updated in zip(archive.entries, parsed.entries, strict=True):
        if updated.path != original.path or updated.payload != replacements.get(original.path, original.payload):
            raise ValueError("Resource replacement changed an unrelated payload")
    return result


def read_uid_cache(payload: bytes) -> dict[int, str]:
    (count,), position = _read("<I", payload, 0)
    if count > (len(payload) - position) // 12:
        raise ValueError("Invalid UID cache entry count")
    mappings = {}
    for _ in range(count):
        (uid, length), position = _read("<QI", payload, position)
        if length == 0 or position + length > len(payload):
            raise ValueError("Truncated UID mapping")
        path = payload[position:position + length].decode("utf-8")
        position += length
        if uid in mappings:
            raise ValueError("Duplicate UID cache ID")
        mappings[uid] = path
    if position != len(payload):
        raise ValueError("Unexpected UID cache trailing bytes")
    return mappings


def retained_resource_fingerprint(entries: tuple[PckEntry, ...]) -> str:
    """Hash the retained path/flags/length/payload graph for an audit receipt."""
    digest = hashlib.sha256()
    for entry in entries:
        path = entry.path.encode("utf-8")
        digest.update(struct.pack("<I", len(path)))
        digest.update(path)
        digest.update(struct.pack("<IQ", entry.flags, len(entry.payload)))
        digest.update(hashlib.sha256(entry.payload).digest())
    return digest.hexdigest()


def compact_payload(payload: bytes, authority: PckArchive) -> tuple[bytes, dict, dict[int, str]]:
    archive = parse_archive(payload)
    authoritative = {entry.path: entry for entry in authority.entries}
    removed = []
    required_uids = {}
    kept = []
    for entry in archive.entries:
        root = authoritative.get(entry.path)
        eligible = entry.path in METADATA_PATHS and root is not None
        source_uids = {}
        if eligible and entry.path == UID_CACHE:
            source_uids = read_uid_cache(entry.payload)
            root_uids = read_uid_cache(root.payload)
            eligible = all(root_uids.get(uid) == path for uid, path in source_uids.items())
        elif eligible:
            eligible = entry.payload == root.payload
        if eligible:
            removed.append({"path": entry.path, "bytes": len(entry.payload),
                            "sha256": hashlib.sha256(entry.payload).hexdigest(),
                            "authority_sha256": hashlib.sha256(root.payload).hexdigest(),
                            "proof": "uid_mapping_subset" if entry.path == UID_CACHE else "identical_bytes"})
            required_uids.update(source_uids)
        else:
            kept.append(entry)
    if not removed:
        return payload, {"before_bytes": len(payload), "after_bytes": len(payload), "removed": []}, {}
    candidate = encode_archive(replace(archive, entries=tuple(kept)))
    parsed = parse_archive(candidate)
    if parsed.entries != tuple(kept):
        raise ValueError("Compaction changed a retained resource path, payload, digest or flags")
    if len(candidate) >= len(payload):
        return payload, {"before_bytes": len(payload), "after_bytes": len(payload), "removed": [],
                         "kept_reason": "Compacted transport was not smaller"}, {}
    return candidate, {"before_bytes": len(payload), "after_bytes": len(candidate),
                       "removed": removed, "retained_resources": len(kept),
                       "content_payloads_preserved": True,
                       "retained_resources_sha256": retained_resource_fingerprint(tuple(kept)),
                       "before_sha256": hashlib.sha256(payload).hexdigest(),
                       "after_sha256": hashlib.sha256(candidate).hexdigest()}, required_uids


def compact_directory(pack_dir: Path, root_pack: Path, *, dry_run: bool = False) -> dict:
    if not pack_dir.is_dir():
        raise ValueError("Pack directory does not exist")
    authority = parse_archive(root_pack.read_bytes())
    report = {"schema_version": 1, "authority_pack": str(root_pack.resolve()), "dry_run": dry_run,
              "required_uid_mappings": {}, "required_exact_resources": {}, "packs": []}
    paths = [path for path in sorted(pack_dir.glob("*.pck")) if path.resolve() != root_pack.resolve()]
    if not paths:
        raise ValueError("Pack directory contains no supplemental PCKs")
    for path in paths:
        if path.resolve() == root_pack.resolve():
            continue
        original = path.read_bytes()
        compacted, record, uids = compact_payload(original, authority)
        record["file"] = path.name
        report["packs"].append(record)
        report["required_uid_mappings"].update({str(uid): resource for uid, resource in uids.items()})
        for removed in record["removed"]:
            if removed["path"] != UID_CACHE:
                report["required_exact_resources"][removed["path"]] = removed["sha256"]
        if not dry_run and compacted != original:
            temporary = path.with_name(path.name + ".compact-tmp")
            try:
                temporary.write_bytes(compacted)
                # Check stored bytes before replacing the build-only artifact.
                if temporary.read_bytes() != compacted:
                    raise ValueError("Compacted artifact write mismatch: " + path.name)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
    report["saved_bytes"] = sum(row["before_bytes"] - row["after_bytes"] for row in report["packs"])
    verify_authority(root_pack.read_bytes(), report)
    return report


def verify_authority(payload: bytes, report: dict) -> None:
    """Verify an actual exported root still owns everything removed earlier."""
    if report.get("schema_version") != 1 or not isinstance(report.get("packs"), list):
        raise ValueError("Not a pack compaction authority receipt")
    authority = {entry.path: entry.payload for entry in parse_archive(payload).entries}
    required = report.get("required_uid_mappings", {})
    if required:
        if UID_CACHE not in authority:
            raise ValueError("Actual root has no authoritative UID cache")
        root_uids = read_uid_cache(authority[UID_CACHE])
        for uid, path in required.items():
            if root_uids.get(int(uid)) != path:
                raise ValueError("Actual root does not cover removed UID mapping: " + str(uid))
    for path, digest in report.get("required_exact_resources", {}).items():
        if path not in METADATA_PATHS or path == UID_CACHE:
            raise ValueError("Receipt contains a non-whitelisted exact resource")
        if path not in authority or hashlib.sha256(authority[path]).hexdigest() != digest:
            raise ValueError("Actual root does not own removed metadata: " + path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root-pack", type=Path, required=True)
    parser.add_argument("--pack-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--verify-authority", type=Path, metavar="RECEIPT")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.verify_authority:
        receipt = json.loads(args.verify_authority.read_text(encoding="utf-8"))
        verify_authority(args.root_pack.read_bytes(), receipt)
        print("PACK METADATA AUTHORITY: PASS")
        return 0
    if args.pack_dir is None or args.report is None:
        parser.error("compaction requires --pack-dir and --report")
    report = compact_directory(args.pack_dir, args.root_pack, dry_run=args.dry_run)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PACK METADATA COMPACTION: PASS ({len(report['packs'])} packs; {report['saved_bytes']:,} bytes saved" +
          ("; dry run)" if args.dry_run else ")"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
