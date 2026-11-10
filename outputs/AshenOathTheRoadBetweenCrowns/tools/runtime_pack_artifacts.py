"""Validate and copy the external packs declared by one runtime manifest."""

import argparse
import gzip
import hashlib
import json
import re
import shutil
from pathlib import Path
from urllib.parse import unquote, urlsplit

from runtime_pack_validation import require_valid_pack_graph


SHELL_ASSETS = {"menu-background.png": "assets_external/ui/greyfen_menu_stylized.png"}


def artifact_plan(manifest: dict, pack_dir: Path, *, delivered_paths: bool = False) -> list[tuple[Path, str]]:
    """Check every input before copying anything; accept decoded or gzip PCKs."""
    require_valid_pack_graph(manifest)
    root = pack_dir.resolve()
    plan, destinations = [], set()
    for pack_id, pack in manifest["packs"].items():
        if str(pack.get("status", "")).startswith("embedded"):
            if pack.get("url"):
                raise ValueError(f"{pack_id}: embedded ownership conflicts with external URL")
            if pack.get("bytes", 0) != 0:
                raise ValueError(f"{pack_id}: embedded pack must not claim a separate artifact")
            continue
        url = urlsplit(str(pack.get("url", "")))
        relative = unquote(url.path)
        # Keep delivery paths portable and unambiguous on Windows and POSIX.
        parts = relative.split("/")
        if (url.scheme or url.netloc or not relative.startswith("packs/")
                or any(part in {"", ".", ".."} or ":" in part or "\\" in part for part in parts)
                or not relative.endswith(".pck")):
            raise ValueError(f"{pack_id}: pack URL must resolve inside exported packs/")
        if relative.casefold() in destinations:
            raise ValueError(f"{pack_id}: duplicate pack destination {relative}")
        destinations.add(relative.casefold())
        artifact = "/".join(parts[1:]) if delivered_paths else str(pack.get("candidate_artifact") or parts[-1])
        source = (root / artifact).resolve()
        if not source.is_relative_to(root) or source == root:
            raise ValueError(f"{pack_id}: candidate artifact escapes pack directory")
        payload = source.read_bytes()
        decoded = gzip.decompress(payload) if payload.startswith(b"\x1f\x8b") else payload
        expected = str(pack.get("sha256", "")).lower()
        if not re.fullmatch(r"[a-f0-9]{64}", expected) or expected not in url.query:
            raise ValueError(f"{pack_id}: URL lacks its SHA-256 identity")
        if not decoded.startswith(b"GDPC"):
            raise ValueError(f"{pack_id}: candidate is not a Godot PCK")
        if len(decoded) != pack.get("bytes") or hashlib.sha256(decoded).hexdigest() != expected:
            raise ValueError(f"{pack_id}: candidate size/hash mismatch")
        plan.append((source, relative))
    return plan


def copy_runtime_pack_artifacts(export_dir: Path, manifest: dict, pack_dir: Path) -> None:
    plan = artifact_plan(manifest, pack_dir)
    root = export_dir.resolve()
    for source, relative in plan:
        target = (root / relative).resolve()
        if not target.is_relative_to(root / "packs"):
            raise ValueError(f"Pack destination escapes exported packs/: {relative}")
        target.parent.mkdir(parents=True, exist_ok=True)
        if source != target:
            shutil.copyfile(source, target)


def copy_shell_assets(export_dir: Path, project: Path) -> None:
    sources = [(project / source, export_dir / target) for target, source in SHELL_ASSETS.items()]
    for source, _target in sources:
        if not source.is_file():
            raise ValueError(f"Required shell asset is missing: {source}")
    for source, target in sources:
        if source.resolve() != target.resolve():
            shutil.copyfile(source, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("pack_dir", type=Path)
    args = parser.parse_args()
    try:
        plan = artifact_plan(json.loads(args.manifest.read_text(encoding="utf-8-sig")), args.pack_dir)
    except (OSError, ValueError, EOFError) as error:
        print(f"PACK ARTIFACTS: FAIL - {error}")
        return 1
    print(f"PACK ARTIFACTS: PASS ({len(plan)} external packs; no files copied)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
