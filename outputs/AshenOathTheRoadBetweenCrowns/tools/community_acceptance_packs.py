"""Read-only native acceptance preflight against the maintained release receipt.

The final Web root must be losslessly decoded before this tool sees it. Standalone
base.pck is an export intermediate, never a supplemental pack or a substitute root.
All external packs come from the final root's manifest, not a directory glob.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from compact_runtime_packs import parse_archive
from runtime_pack_artifacts import artifact_plan

REQUIRED_RESOURCES = [
    "scenes/main.tscn", "scripts/campaign_revision.gd", "scripts/ending_catalog.gd",
    "scripts/community_campaign.gd", "scripts/community_activity.gd",
    "scripts/community_ending.gd", "scripts/community_presentation.gd",
    "scripts/zones/community_section.gd", "data/runtime_story_campaign.json",
    "data/community_campaign.json", "data/community_cast_life.json",
    "data/community_story_overlay.json", "world_sector_manifest.json",
    *["assets_external/environment/village/Cemetery_" + name + "_Authored.res"
      for name in ["chapel", "bell_frame", "bell", "grave_rows", "boundary", "grave_earth", "memory_window"]],
    *["assets_external/environment/forest/HartAftermath_" + name + "_Authored.res"
      for name in ["concord", "open_road"]],
]


def _raw(path: Path) -> bytes:
    payload = path.read_bytes()
    if payload.startswith(b"\x1f\x8b"):
        raise ValueError(f"Native acceptance requires an uncompressed PCK; losslessly decode a separate frozen copy: {path}")
    if not payload.startswith(b"GDPC"):
        raise ValueError("Native acceptance requires a standalone Godot PCK: " + str(path))
    return payload


def _identity(payload: bytes, record: dict, label: str) -> None:
    size = record.get("decoded_bytes", record.get("bytes"))
    digest = record.get("decoded_sha256", record.get("sha256"))
    if len(payload) != size or hashlib.sha256(payload).hexdigest() != digest:
        raise ValueError(label + " differs from the maintained release receipt")


def _resource_exists(path: str, resources: dict[str, bytes], visiting=None) -> bool:
    if path in resources:
        return True
    visiting = set() if visiting is None else visiting
    if path in visiting:
        return False
    visiting.add(path)
    remap = resources.get(path + ".remap", b"").decode("utf-8-sig", errors="strict")
    match = re.search(r'^path="res://([^"\n]+)"$', remap, flags=re.MULTILINE)
    return bool(match and _resource_exists(match.group(1), resources, visiting))


def verify_candidate(root_pack: Path, pack_dir: Path, release_manifest: Path,
                     *, required_resources=None) -> dict:
    """Verify exact decoded release bytes, ownership and known fixture resources.

    This is a static container/resource inventory, not Godot resource instantiation
    or gameplay validation. Those remain separate acceptance gates.
    """
    root_pack, pack_dir = root_pack.resolve(strict=True), pack_dir.resolve(strict=True)
    release_manifest = release_manifest.resolve(strict=True)
    release = json.loads(release_manifest.read_text(encoding="utf-8-sig"))
    root_bytes = _raw(root_pack)
    root_record = release.get("root_pck", {})
    if root_record.get("path") != "index.pck":
        raise ValueError("A maintained final Web release manifest is required")
    _identity(root_bytes, root_record, "Final root PCK")
    root_resources = {entry.path: entry.payload for entry in parse_archive(root_bytes).entries}
    classes = ".godot/global_script_class_cache.cfg"
    if classes not in root_resources:
        raise ValueError("Final root is missing generated global class metadata")
    manifest_bytes = root_resources.get("runtime_pack_manifest.json")
    if manifest_bytes is None:
        raise ValueError("Final root is missing its embedded runtime pack manifest")
    _identity(manifest_bytes, release.get("runtime_pack_manifest", {}), "Embedded runtime manifest")
    manifest = json.loads(manifest_bytes.decode("utf-8-sig"))
    if manifest.get("release_id") != release.get("build_id") or manifest.get("generated_from_commit") != release.get("source", {}).get("git_commit"):
        raise ValueError("Root runtime manifest and release receipt have different build identities")
    if not str(manifest.get("packs", {}).get("base", {}).get("status", "")).startswith("embedded"):
        raise ValueError("Final root must own the embedded base")
    plan = artifact_plan(manifest, pack_dir)
    release_packs = {row["id"]: row for row in release.get("packs", [])}
    if len(release_packs)!=len(release.get("packs", [])) or set(release_packs) != set(manifest["packs"]):
        raise ValueError("Release receipt and embedded runtime manifest declare different packs")
    for key, pack in manifest["packs"].items():
        row = release_packs[key]
        if any(row.get(field) != pack.get(field) for field in ["url", "bytes", "sha256", "dependencies"]):
            raise ValueError("Release pack identity differs from the final root: " + key)
        if row.get("embedded") != str(pack.get("status", "")).startswith("embedded"):
            raise ValueError("Release pack ownership differs from the final root: " + key)
    artifacts = {row["path"]: row for row in release.get("artifacts", [])}
    if len(artifacts)!=len(release.get("artifacts", [])) or artifacts.get("index.pck")!=root_record or artifacts.get("runtime_pack_manifest.json")!=release.get("runtime_pack_manifest"):
        raise ValueError("Release artifact table has duplicate or inconsistent authority records")
    paths = {relative: path for path, relative in plan}
    order, visited = [], set()
    def visit(key):
        if key in visited:
            return
        for dependency in manifest["packs"][key].get("dependencies", []):
            visit(dependency)
        visited.add(key)
        if not release_packs[key]["embedded"]:
            order.append(key)
    for key in manifest["packs"]:
        visit(key)
    # Keep only remap text in the accumulated inventory; actor mesh payloads do
    # not need to remain resident while the next pack is being inspected.
    resources = {key:value if key.endswith(".remap") else b"" for key,value in root_resources.items()}
    mounted = []
    for key in order:
        pack = manifest["packs"][key]
        # artifact_plan already validates URLs and paths. Keep the decoded URL
        # mapping it returned rather than guessing artifact names or globbing.
        relative = unquote(urlsplit(pack["url"]).path)
        path = paths[relative]
        if path == root_pack or path.name.casefold() == "base.pck":
            raise ValueError("Standalone base cannot replace the final root")
        payload = _raw(path)
        _identity(payload, artifacts.get(relative, {}), "External pack " + key)
        entries = {entry.path: entry.payload for entry in parse_archive(payload).entries}
        if "runtime_pack_manifest.json" in entries:
            raise ValueError("External pack cannot override the root runtime manifest: " + key)
        if classes in entries and entries[classes] != root_resources.get(classes):
            raise ValueError("External pack changes root class metadata: " + key)
        resources.update({name:value if name.endswith(".remap") else b"" for name,value in entries.items()})
        mounted.append({"id":key,"path":str(path),"bytes":len(payload),"sha256":hashlib.sha256(payload).hexdigest()})
    required = REQUIRED_RESOURCES if required_resources is None else required_resources
    missing = [name for name in required if not _resource_exists(name, resources)]
    if missing:
        raise ValueError("Frozen acceptance closure is missing: " + ", ".join(missing))
    return {"schema_version":1,"kind":"verified_native_candidate_closure","build_id":release["build_id"],
            "source_commit":release["source"]["git_commit"],"release_manifest":str(release_manifest),
            "root":{"path":str(root_pack),"bytes":len(root_bytes),"sha256":hashlib.sha256(root_bytes).hexdigest()},
            "runtime_manifest_sha256":hashlib.sha256(manifest_bytes).hexdigest(),"packs":mounted,
            "class_cache_sha256":hashlib.sha256(root_resources[classes]).hexdigest(),
            "known_required_resources":required,"resource_count":len(resources),"resource_instantiation_validated":False,
            "unlisted_pack_policy":"ignored; never mounted","deferred_loading_tested":False}
