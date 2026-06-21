from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ASSETS_ROOT = PROJECT_ROOT / "assets_external"
SOURCES_PATH = PROJECT_ROOT / "asset_sources.json"
MANIFEST_PATH = PROJECT_ROOT / "asset_manifest.json"
ROLE_MAPPING_PATH = PROJECT_ROOT / "asset_role_mapping_suggested.json"

MODEL_EXTS = {".glb", ".gltf", ".fbx", ".obj", ".dae"}
TEXTURE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".tga"}
AUDIO_EXTS = {".wav", ".ogg", ".mp3"}
LICENSE_NAMES = {"license", "licence", "readme", "credits", "copying", "attribution"}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def read_json(path: Path, default):
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=False)
        handle.write("\n")


def safe_name(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", value.strip())
    return cleaned.strip("._") or "asset_pack"


def project_relative(path: Path) -> str:
    return path.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()


def res_path(path: Path) -> str:
    return "res://" + project_relative(path)


def detect_source_pack(path: Path) -> str:
    parts = list(path.parts)
    if "raw" in parts:
        idx = parts.index("raw")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    name = path.name
    if "__" in name:
        return name.split("__", 1)[0]
    return ""


def load_pack_metadata() -> dict:
    data = read_json(SOURCES_PATH, {"packs": []})
    return {pack.get("name", ""): pack for pack in data.get("packs", [])}


def category_root(category: str) -> Path:
    safe_category = category.strip().strip("/\\")
    return ASSETS_ROOT / safe_category


def likely_use_from_name(name: str, category: str) -> str:
    hay = f"{name} {category}".lower()
    rules = [
        ("player", "player character"),
        ("hero", "player character"),
        ("villager", "generic villager"),
        ("blacksmith", "blacksmith NPC"),
        ("priest", "priestess NPC"),
        ("noble", "noble NPC"),
        ("bandit", "human enemy"),
        ("ghoul", "ghoulkin enemy"),
        ("zombie", "undead enemy"),
        ("skeleton", "gravebound enemy"),
        ("knight", "gravebound knight"),
        ("deer", "white hart avatar"),
        ("stag", "white hart avatar"),
        ("tree", "forest tree"),
        ("rock", "forest rock"),
        ("bush", "forest bush"),
        ("house", "village house"),
        ("hut", "village house"),
        ("tavern", "tavern"),
        ("wall", "ruins wall"),
        ("pillar", "ruins pillar"),
        ("grave", "cemetery prop"),
        ("sword", "combat prop"),
        ("ambience", "ambience"),
        ("footstep", "footstep audio"),
        ("ui", "UI asset"),
    ]
    for key, use in rules:
        if key in hay:
            return use
    return category or "general asset"
