#!/usr/bin/env python3
"""Build the compact runtime Ranger from the locally selected CC0 source.

The source outfit remains outside the release mapping. This helper keeps the
skinned GLTF and binary intact, rewrites image URIs, and reduces only the
Ranger-specific maps to the project's 1K character budget.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image


ROLE_IMAGES = {
    "T_Ranger_BaseColor.png": "T_Ranger_BaseColor_1K.png",
    "T_Ranger_Normal.png": "T_Ranger_Normal_1K.png",
    "T_Ranger_ORM.png": "T_Ranger_ORM_1K.png",
}


def resize_png(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        image = image.convert("RGBA") if image.mode not in {"RGB", "RGBA"} else image
        image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        image.save(destination, format="PNG", optimize=True)


def build(project_root: Path) -> None:
    source_dir = project_root / "assets_external" / "characters_universal"
    output_dir = project_root / "assets_external" / "characters_ranger"
    output_dir.mkdir(parents=True, exist_ok=True)

    source_gltf = source_dir / "Male_Ranger.gltf"
    source_bin = source_dir / "Male_Ranger.bin"
    if not source_gltf.is_file() or not source_bin.is_file():
        raise FileNotFoundError("Male_Ranger.gltf and Male_Ranger.bin are required")

    document = json.loads(source_gltf.read_text(encoding="utf-8"))
    for image in document.get("images", []):
        uri = str(image.get("uri", ""))
        if uri in ROLE_IMAGES:
            image["uri"] = ROLE_IMAGES[uri]
        elif uri.startswith("T_Regular_Male_"):
            image["uri"] = f"../characters_universal/{uri}"
    for buffer_entry in document.get("buffers", []):
        if str(buffer_entry.get("uri", "")) == source_bin.name:
            buffer_entry["uri"] = "Male_Ranger_Runtime.bin"

    (output_dir / "Male_Ranger_Runtime.gltf").write_text(
        json.dumps(document, indent=2) + "\n", encoding="utf-8"
    )
    shutil.copyfile(source_bin, output_dir / "Male_Ranger_Runtime.bin")
    for source_name, output_name in ROLE_IMAGES.items():
        resize_png(source_dir / source_name, output_dir / output_name)

    print("RANGER RUNTIME: PASS")
    for path in sorted(output_dir.iterdir()):
        print(f"  {path.name}: {path.stat().st_size} bytes")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", type=Path)
    args = parser.parse_args()
    build(args.project_root.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
