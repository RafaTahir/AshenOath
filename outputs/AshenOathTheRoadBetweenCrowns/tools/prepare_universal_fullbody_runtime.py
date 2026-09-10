#!/usr/bin/env python3
"""Create compact, deterministic Universal full-body runtime variants.

The source GLTFs are retained as authoring inputs. Runtime variants point at
the existing 1K maps, preserve the source skeleton/bin, and live below the
runtime asset directory so export filters can include them explicitly.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


VARIANTS = {
    "male": {
        "source": "Superhero_Male_FullBody.gltf",
        "output": "Universal_Male_FullBody_1K.gltf",
        "maps": {
            "T_Hair_1_Normal_png.png": "../T_Hair_1_Normal_1K.png",
            "T_Hair_1_BaseColor.png": "../T_Hair_1_BaseColor_1K.png",
            "T_Eye_Normal_png.png": "../T_Eye_Normal.png",
            "T_Eye_Brown.png": "../T_Eye_Brown.png",
            "T_Superhero_Male_Normal.png": "../T_Superhero_Male_Normal_1K.png",
            "T_Superhero_Male_Dark.png": "../T_Superhero_Male_Dark_1K.png",
            "T_Superhero_Male_Roughness.png": "../T_Superhero_Male_Roughness_1K.png",
        },
    },
    "female": {
        "source": "Superhero_Female_FullBody.gltf",
        "output": "Universal_Female_FullBody_1K.gltf",
        "maps": {
            "T_Hair_2_Normal.png": "../T_Hair_2_Normal_1K.png",
            "T_Hair_2_BaseColor.png": "../T_Hair_2_BaseColor_1K.png",
            "T_Eye_Normal_png.png": "../T_Eye_Normal.png",
            "T_Eye_Brown.png": "../T_Eye_Brown.png",
            "T_Superhero_Female_Normal.png": "../T_Superhero_Female_Normal_1K.png",
            "T_Superhero_Female_Dark_BaseColor.png": "../T_Superhero_Female_Dark_BaseColor_1K.png",
            "T_Superhero_Female_Roughness.png": "../T_Superhero_Female_Roughness_1K.png",
        },
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def build(project: Path) -> dict:
    source_dir = project / "assets_external" / "characters_universal"
    output_dir = source_dir / "runtime"
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "pipeline": "Universal full-body 1K runtime conversion",
        "license": "CC0 1.0",
        "source_pack": "Quaternius Universal Base Characters",
        "source_url": "https://quaternius.com/packs/universalbasecharacters.html",
        "variants": {},
    }
    for role, spec in VARIANTS.items():
        source_gltf = source_dir / spec["source"]
        source_bin_name = source_gltf.with_suffix(".bin").name
        source_bin = source_dir / source_bin_name
        output_gltf = output_dir / spec["output"]
        output_bin = output_dir / output_gltf.with_suffix(".bin").name
        if not source_gltf.is_file() or not source_bin.is_file():
            raise FileNotFoundError(f"missing source pair for {role}: {source_gltf.name}")

        document = json.loads(source_gltf.read_text(encoding="utf-8"))
        for image in document.get("images", []):
            uri = str(image.get("uri", ""))
            if uri not in spec["maps"]:
                raise ValueError(f"unmapped image {uri} in {source_gltf.name}")
            image["uri"] = spec["maps"][uri]
        for buffer_entry in document.get("buffers", []):
            if str(buffer_entry.get("uri", "")) == source_bin_name:
                buffer_entry["uri"] = output_bin.name
        output_gltf.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        shutil.copyfile(source_bin, output_bin)
        manifest["variants"][role] = {
            "source": f"res://assets_external/characters_universal/{source_gltf.name}",
            "source_sha256": sha256(source_gltf),
            "source_bin_sha256": sha256(source_bin),
            "runtime": f"res://assets_external/characters_universal/runtime/{output_gltf.name}",
            "runtime_bin": f"res://assets_external/characters_universal/runtime/{output_bin.name}",
            "runtime_sha256": sha256(output_gltf),
            "runtime_bin_sha256": sha256(output_bin),
            "maps": list(spec["maps"].values()),
            "root_motion": False,
        }
    manifest_path = output_dir / "UNIVERSAL_FULLBODY_RUNTIME_MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    manifest = build(args.project.resolve())
    for role, item in manifest["variants"].items():
        print(f"UNIVERSAL {role}: PASS {item['runtime']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
