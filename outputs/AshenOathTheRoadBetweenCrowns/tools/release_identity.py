#!/usr/bin/env python3
"""Compute independent Recovery-004 release identities.

Runtime content, test harness, registry, and exported artifacts deliberately have
separate hashes.  Documentation/status edits therefore do not invalidate game
bytes, while same-HEAD dirty runtime edits cannot be hidden by Git history.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Iterable
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


RUNTIME_SUFFIXES = {
    ".bin", ".cfg", ".csv", ".fbx", ".gd", ".glb", ".gltf", ".import",
    ".jpg", ".json", ".material", ".mesh", ".ogg", ".png", ".res",
    ".shader", ".tres", ".tscn", ".wav", ".webp",
}
HARNESS_SUFFIXES = {".gd", ".js", ".json", ".mjs", ".ps1", ".py"}
RUNTIME_EXTRA = (
    "project.godot",
    "export_presets.cfg",
    "runtime_asset_manifest.json",
    "asset_manifest.json",
    "asset_acceptance_manifest.json",
    "curated_runtime_assets.json",
    "character_role_manifest.json",
    "soul_character_role_manifest.json",
    "soul_asset_pack_manifest.json",
    "monster_family_manifest.json",
    "zone_scene_manifest.json",
    "world_sector_manifest.json",
    "voice_production_manifest.json",
    "visual_upgrade_manifest.json",
    "runtime_pack_manifest.json",
    "runtime_pack_candidates.json",
    "web_boot_shell.html",
)


class HashCache:
    def __init__(self, cache_path: Path | None = None) -> None:
        self.cache_path = cache_path
        self._digests: dict[Path, str] = {}
        self._records: dict[str, dict[str, object]] = {}
        if cache_path and cache_path.is_file():
            try:
                payload = json.loads(cache_path.read_text(encoding="utf-8-sig"))
                if payload.get("schema_version") == 1 and isinstance(payload.get("files"), dict):
                    self._records = payload["files"]
            except (OSError, json.JSONDecodeError, AttributeError):
                self._records = {}

    def file(self, path: Path) -> str:
        resolved = path.resolve()
        digest = self._digests.get(resolved)
        if digest is None:
            stat = resolved.stat()
            key = str(resolved)
            record = self._records.get(key, {})
            if record.get("bytes") == stat.st_size and record.get("mtime_ns") == stat.st_mtime_ns and isinstance(record.get("sha256"), str):
                digest = str(record["sha256"])
            else:
                digest = hashlib.sha256(resolved.read_bytes()).hexdigest()
                self._records[key] = {"bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns, "sha256": digest}
            self._digests[resolved] = digest
        return digest

    def save(self) -> None:
        if self.cache_path is None:
            return
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.cache_path.with_suffix(self.cache_path.suffix + ".tmp")
        temporary.write_text(json.dumps({"schema_version": 1, "files": self._records}, sort_keys=True), encoding="utf-8")
        temporary.replace(self.cache_path)


def _runtime_file_allowed(project: Path, path: Path) -> bool:
    relative = path.relative_to(project).as_posix()
    if relative.startswith(("assets_external/raw/", "assets_external/downloads/")):
        return False
    if relative.startswith("assets_external/animations/") and path.suffix.lower() in {".fbx", ".glb"}:
        return False
    return path.suffix.lower() in RUNTIME_SUFFIXES


def runtime_files(project: Path) -> list[Path]:
    files: set[Path] = set()
    for root_name in ("scripts", "scenes", "data", "assets", "assets_external"):
        root = project / root_name
        if root.is_dir():
            files.update(path for path in root.rglob("*") if path.is_file() and _runtime_file_allowed(project, path))
    for relative in RUNTIME_EXTRA:
        candidate = project / relative
        if candidate.is_file():
            files.add(candidate)
    return sorted(files, key=lambda path: path.relative_to(project).as_posix())


def harness_files(project: Path) -> list[Path]:
    root = project / "tools"
    if not root.is_dir():
        return []
    return sorted(
        (path for path in root.rglob("*") if path.is_file() and path.suffix.lower() in HARNESS_SUFFIXES),
        key=lambda path: path.relative_to(project).as_posix(),
    )


def fingerprint(project: Path, files: Iterable[Path], cache: HashCache) -> str:
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(project).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(cache.file(path).encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def runtime_fingerprint(project: Path, cache: HashCache | None = None) -> str:
    cache = cache or HashCache()
    digest = hashlib.sha256()
    for path in runtime_files(project):
        content_hash = cache.file(path)
        if path.name in {"runtime_pack_manifest.json", "runtime_pack_candidates.json"} and path.parent == project:
            # Exported byte identities belong to artifact validation. Retain the
            # loading graph and every non-generated field in source identity.
            content = json.loads(path.read_text(encoding="utf-8-sig"))
            for key in ("release_id", "build_id", "generated_from_commit", "generated_at_utc", "source_dirty", "total_bytes"):
                content.pop(key, None)
            packs = content.get("packs", {})
            for pack in packs.values() if isinstance(packs, dict) else packs:
                for key in ("version", "bytes", "sha256", "candidate_bytes", "candidate_sha256", "cache_key", "embedded_source_bytes", "embedded_source_sha256", "log"):
                    pack.pop(key, None)
                if "url" in pack:
                    url = urlsplit(pack["url"])
                    query = urlencode([(key, value) for key, value in parse_qsl(url.query) if key != "sha256"])
                    pack["url"] = urlunsplit((url.scheme, url.netloc, url.path, query, url.fragment))
            content_hash = hashlib.sha256(json.dumps(content, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
        digest.update(path.relative_to(project).as_posix().encode("utf-8") + b"\0")
        digest.update(content_hash.encode("ascii") + b"\0")
    return digest.hexdigest()


def harness_fingerprint(project: Path, cache: HashCache | None = None) -> str:
    return fingerprint(project, harness_files(project), cache or HashCache())


def registry_fingerprint(project: Path, cache: HashCache | None = None) -> str:
    path = project / "RECOVERY_004_ISSUE_REGISTRY.json"
    return (cache or HashCache()).file(path) if path.is_file() else ""


def artifact_snapshot(directory: Path, cache: HashCache | None = None) -> dict[str, object]:
    cache = cache or HashCache()
    files: list[dict[str, object]] = []
    total = 0
    if directory.is_dir():
        for path in sorted((item for item in directory.rglob("*") if item.is_file()), key=lambda item: item.relative_to(directory).as_posix()):
            size = path.stat().st_size
            total += size
            files.append({
                "path": path.relative_to(directory).as_posix(),
                "bytes": size,
                "sha256": cache.file(path),
            })
    digest = hashlib.sha256()
    for item in files:
        digest.update(str(item["path"]).encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(item["bytes"]).encode("ascii"))
        digest.update(b"\0")
        digest.update(str(item["sha256"]).encode("ascii"))
        digest.update(b"\0")
    return {"fingerprint": digest.hexdigest(), "total_bytes": total, "files": files}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--harness", action="store_true")
    parser.add_argument("--registry", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    cache = HashCache(project / ".release-gate" / "release_identity_cache.json")
    values: dict[str, object] = {}
    selected = args.runtime or args.harness or args.registry or args.artifact is not None
    if args.runtime or not selected:
        values["runtime_content"] = runtime_fingerprint(project, cache)
    if args.harness or not selected:
        values["test_harness"] = harness_fingerprint(project, cache)
    if args.registry or not selected:
        values["registry"] = registry_fingerprint(project, cache)
    if args.artifact is not None:
        values["artifact"] = artifact_snapshot(args.artifact.resolve(), cache)
    if args.json or len(values) != 1:
        print(json.dumps(values, sort_keys=True))
    else:
        print(next(iter(values.values())))
    cache.save()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
