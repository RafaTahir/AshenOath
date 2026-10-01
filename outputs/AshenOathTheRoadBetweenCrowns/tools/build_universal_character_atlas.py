"""Build the deterministic runtime albedo atlas for Universal humanoids."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets_external" / "characters_universal"
OUTPUT = SOURCE / "runtime" / "Universal_Albedo_Atlas_512.png"
MANIFEST = SOURCE / "runtime" / "Universal_Albedo_Atlas_512.json"
TILE = 512
PADDING = 8
INNER = TILE - PADDING * 2
COLS = 4
ROWS = 2

SOURCES = [
    "T_Peasant_BaseColor_1K.png",
    "T_Regular_Male_Dark_BaseColor_1K.png",
    "T_Superhero_Male_Dark_1K.png",
    "T_Superhero_Female_Dark_BaseColor_1K.png",
    "T_Hair_1_BaseColor_1K.png",
    "T_Hair_2_BaseColor_1K.png",
    "T_Eye_Brown.png",
]


def paste_padded(atlas: Image.Image, image: Image.Image, x: int, y: int) -> None:
    image = image.convert("RGBA").resize((INNER, INNER), Image.Resampling.LANCZOS)
    atlas.paste(image, (x + PADDING, y + PADDING))
    atlas.paste(image.crop((0, 0, INNER, 1)).resize((INNER, PADDING)), (x + PADDING, y))
    atlas.paste(image.crop((0, INNER - 1, INNER, INNER)).resize((INNER, PADDING)), (x + PADDING, y + PADDING + INNER))
    atlas.paste(image.crop((0, 0, 1, INNER)).resize((PADDING, INNER)), (x, y + PADDING))
    atlas.paste(image.crop((INNER - 1, 0, INNER, INNER)).resize((PADDING, INNER)), (x + PADDING + INNER, y + PADDING))
    atlas.paste(image.getpixel((0, 0)), (x, y, x + PADDING, y + PADDING))
    atlas.paste(image.getpixel((INNER - 1, 0)), (x + PADDING + INNER, y, x + TILE, y + PADDING))
    atlas.paste(image.getpixel((0, INNER - 1)), (x, y + PADDING + INNER, x + PADDING, y + TILE))
    atlas.paste(image.getpixel((INNER - 1, INNER - 1)), (x + PADDING + INNER, y + PADDING + INNER, x + TILE, y + TILE))


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (255, 255, 255, 255))
    entries: dict[str, dict[str, object]] = {}
    for index, name in enumerate(SOURCES):
        path = SOURCE / name
        if not path.is_file():
            raise FileNotFoundError(path)
        col, row = index % COLS, index // COLS
        paste_padded(atlas, Image.open(path), col * TILE, row * TILE)
        entries[name] = {
            "offset": [(col * TILE + PADDING) / (COLS * TILE), (row * TILE + PADDING) / (ROWS * TILE)],
            "scale": [INNER / (COLS * TILE), INNER / (ROWS * TILE)],
            "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    atlas.save(OUTPUT, optimize=True)
    manifest = {
        "schema_version": 1,
        "atlas": OUTPUT.name,
        "size": list(atlas.size),
        "tile_size": TILE,
        "padding": PADDING,
        "entries": entries,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"UNIVERSAL CHARACTER ATLAS: {OUTPUT} ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
