from __future__ import annotations

import hashlib
import sys
from pathlib import Path

from pipeline_common import (
    ASSETS_ROOT,
    AUDIO_EXTS,
    LICENSE_NAMES,
    MANIFEST_PATH,
    MODEL_EXTS,
    TEXTURE_EXTS,
    detect_source_pack,
    likely_use_from_name,
    load_pack_metadata,
    project_relative,
    read_json,
    res_path,
    utc_now,
    write_json,
)


def is_license(path: Path) -> bool:
    if "licenses" in path.parts:
        return True
    stem = path.stem.lower()
    return any(token in stem for token in LICENSE_NAMES)


def category_for(path: Path) -> str:
    rel = Path(project_relative(path))
    parts = rel.parts
    if len(parts) < 2:
        return ""
    if parts[0] != "assets_external":
        return ""
    if parts[1] in {"downloads", "raw"}:
        return parts[1]
    if len(parts) >= 3 and parts[1] in {"environment", "textures", "audio"}:
        return f"{parts[1]}/{parts[2]}"
    return parts[1]


def asset_id(path: Path) -> str:
    rel = project_relative(path)
    digest = hashlib.sha1(rel.encode("utf-8")).hexdigest()[:10]
    return f"{path.stem.lower().replace(' ', '_')}_{digest}"


def record(path: Path, license_lookup: dict) -> dict:
    category = category_for(path)
    source_pack = detect_source_pack(path)
    pack_meta = license_lookup.get(source_pack, {})
    return {
        "id": asset_id(path),
        "file_name": path.name,
        "relative_path": res_path(path),
        "extension": path.suffix.lower(),
        "category": category,
        "likely_use": likely_use_from_name(path.stem, category),
        "source_pack": source_pack,
        "license": pack_meta.get("license", ""),
        "notes": "",
    }


def is_animation(path: Path) -> bool:
    hay = f"{project_relative(path)} {path.stem}".lower()
    animation_words = ["anim", "animation", "idle", "walk", "run", "attack", "death", "roll", "dodge", "jump"]
    return path.suffix.lower() in {".fbx", ".glb", ".gltf"} and any(word in hay for word in animation_words)


def add_unique(bucket: list, item: dict) -> None:
    if not any(existing["relative_path"] == item["relative_path"] for existing in bucket):
        bucket.append(item)


def main() -> int:
    pack_meta = load_pack_metadata()
    manifest = {
        "generated_at": utc_now(),
        "models": [],
        "characters": [],
        "enemies": [],
        "environment": [],
        "animations": [],
        "textures": [],
        "audio": [],
        "ui": [],
        "licenses": [],
    }

    if not ASSETS_ROOT.exists():
        write_json(MANIFEST_PATH, manifest)
        print("No assets_external folder found; wrote empty manifest.")
        return 0

    for path in ASSETS_ROOT.rglob("*"):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        item = record(path, pack_meta)
        category = item["category"]

        if is_license(path):
            add_unique(manifest["licenses"], item)
            continue
        if ext in MODEL_EXTS:
            add_unique(manifest["models"], item)
            if category == "characters":
                add_unique(manifest["characters"], item)
            elif category == "enemies":
                add_unique(manifest["enemies"], item)
            elif category.startswith("environment"):
                add_unique(manifest["environment"], item)
            if is_animation(path):
                add_unique(manifest["animations"], item)
        elif ext in TEXTURE_EXTS:
            add_unique(manifest["textures"], item)
            if category == "ui" or category == "textures/ui":
                add_unique(manifest["ui"], item)
        elif ext in AUDIO_EXTS:
            add_unique(manifest["audio"], item)
        elif category == "ui":
            add_unique(manifest["ui"], item)

    write_json(MANIFEST_PATH, manifest)
    print(f"Wrote {MANIFEST_PATH.relative_to(MANIFEST_PATH.parent)}")
    print(
        "Counts: "
        + ", ".join(f"{key}={len(value)}" for key, value in manifest.items() if isinstance(value, list))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
