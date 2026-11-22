"""Deterministically package the licensed Stag source, preserving mesh/rig/clips."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct

SOURCE_SHA256 = "170b964909d16d1ab4d428b1d714f25016913d32481acd9c3d62923192583be6"


def build(source: Path) -> bytes:
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unreviewed Stag source checksum")
    document = json.loads(raw)
    buffers = document["buffers"]
    if len(buffers) != 1 or document.get("images"):
        raise ValueError("Expected one embedded buffer and no external textures")
    uri = buffers[0]["uri"]
    prefix = "data:application/octet-stream;base64,"
    if not uri.startswith(prefix):
        raise ValueError("Unexpected buffer encoding")
    binary = base64.b64decode(uri[len(prefix):], validate=True)
    if len(binary) != buffers[0]["byteLength"]:
        raise ValueError("Source buffer byte count mismatch")
    del buffers[0]["uri"]
    palette = {
        "Material": ("HartCoat", [0.62, 0.70, 0.68, 1]),
        "Material.001": ("HartHoof", [0.06, 0.085, 0.08, 1]),
        "Material.003": ("HartThroat", [0.86, 0.89, 0.82, 1]),
        "Material.010": ("HartAntler", [0.30, 0.43, 0.38, 1]),
        "Material.011": ("HartEye", [0.009, 0.018, 0.014, 1]),
    }
    for material in document["materials"]:
        name, color = palette[material["name"]]
        material["name"] = name
        material["pbrMetallicRoughness"]["baseColorFactor"] = color
        material["pbrMetallicRoughness"]["roughnessFactor"] = 0.85
        if name == "HartAntler":
            material["emissiveFactor"] = [0.035, 0.075, 0.052]
    document["asset"]["extras"] = {
        "source": "https://quaternius.com/packs/ultimateanimatedanimals.html",
        "license": "CC0-1.0", "source_sha256": SOURCE_SHA256,
        "variant": "Ashen Oath White Hart; geometry and animations unchanged",
    }
    encoded = json.dumps(document, separators=(",", ":"), ensure_ascii=True).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary += b"\x00" * (-len(binary) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<I4s", len(encoded), b"JSON") + encoded
            + struct.pack("<I4s", len(binary), b"BIN\x00") + binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    artifact = build(args.source)
    if artifact != build(args.source):
        raise ValueError("Nondeterministic output")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(artifact)
    print(json.dumps({"bytes": len(artifact), "sha256": hashlib.sha256(artifact).hexdigest(), "output": str(args.output)}))


if __name__ == "__main__":
    main()
