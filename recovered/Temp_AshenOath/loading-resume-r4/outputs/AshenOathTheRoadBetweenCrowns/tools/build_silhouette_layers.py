"""Compile small socket layers from retained CC0 mesh groups; no runtime/QA.

Original geometry stays in the library. Outputs are untextured shape layers,
fitted in metres with +Y up/+Z forward. No external models are downloaded.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "assets_external/characters"
OUTPUT = PROJECT / "assets/characters/silhouette"


def read_group(filename: str, prefix: str, min_y=None, max_y=None):
    vertices, groups, current = [], [], ""
    for line in (SOURCE / filename).read_text(encoding="utf-8-sig").splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            vertices.append(tuple(float(v) for v in parts[1:4]))
        elif parts[0] == "o":
            current = " ".join(parts[1:])
        elif parts[0] == "f" and current.startswith(prefix):
            ids = []
            for item in parts[1:]:
                index = int(item.split("/")[0])
                ids.append(index - 1 if index > 0 else len(vertices) + index)
            if min_y is not None and any(vertices[i][1] < min_y for i in ids):
                continue
            if max_y is not None and any(vertices[i][1] > max_y for i in ids):
                continue
            # Triangulate the retained polygon winding, then mirror Z below.
            groups.extend((ids[0], ids[j + 1], ids[j]) for j in range(1, len(ids) - 1))
    if not groups:
        raise ValueError(f"No source faces: {filename}:{prefix}:{min_y}:{max_y}")
    used = sorted({i for face in groups for i in face})
    remap = {old: new for new, old in enumerate(used)}
    return [vertices[i] for i in used], [tuple(remap[i] for i in f) for f in groups]


def compile_layer(name, filename, group, size, center, min_y=None, max_y=None):
    vertices, faces = read_group(filename, group, min_y, max_y)
    # Monk's robe group is closed over the separate face. Keep its crown,
    # side rims and back, but open the front below the brow before fitting.
    # Coordinates here are the retained source frame (-Z faces forward).
    if name == "hood":
        faces = [face for face in faces if not (
            sum(vertices[i][2] for i in face) / 3 < 0.06
            and sum(vertices[i][1] for i in face) / 3 < 2.87
        )]
    low = [min(v[a] for v in vertices) for a in range(3)]
    high = [max(v[a] for v in vertices) for a in range(3)]
    dimensions = [high[a] - low[a] for a in range(3)]
    if min(dimensions) < 0.00001:
        raise ValueError(f"Degenerate source layer: {name}")
    fitted = []
    for vertex in vertices:
        point = [(vertex[a] - (low[a] + high[a]) / 2) / dimensions[a] * size[a] for a in range(3)]
        point[2] = -point[2]  # The old stylized OBJ family faces -Z.
        fitted.append(tuple(point[a] + center[a] for a in range(3)))
    lines = [f"# CC0 derivative of {filename}: {group}; see provenance.json", f"o {name}"]
    lines.extend("v " + " ".join(f"{c:.7f}" for c in v) for v in fitted)
    lines.append("s 1")
    lines.extend("f " + " ".join(str(i + 1) for i in f) for f in faces)
    destination = OUTPUT / f"{name}.obj"
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
    record = {
        "source": f"res://assets_external/characters/{filename}",
        "source_sha256": hashlib.sha256((SOURCE / filename).read_bytes()).hexdigest(),
        "group": group,
        "selection_y": [min_y, max_y],
        "fitted_size_m": size,
        "vertices": len(fitted),
        "triangles": len(faces),
        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
    }
    if name == "hood":
        record["face_opening"] = {"source_centroid_z_below": 0.06, "source_brow_y": 2.87}
    return record


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    recipes = [
        ("cloak", "Ranger.obj", "Cloak_", (.70, .88, .24), (0, -.36, -.07)),
        ("mantle", "Ranger.obj", "Cloak_", (.60, .46, .25), (0, -.14, 0)),
        # Adapt the retained cloak's cloth skirt, excluding its hood, into the
        # two-part working apron. Separate chest/hip sockets permit bending.
        ("apron_bib", "Ranger.obj", "Cloak_", (.32, .31, .045), (0, -.13, 0), None, 2.42),
        ("apron_skirt", "Ranger.obj", "Cloak_", (.54, .49, .075), (0, -.245, 0), None, 2.42),
        ("satchel", "Ranger.obj", "Pouch_", (.24, .29, .17), (0, -.145, 0)),
        # Fit around the retained human crown, not a second head-sized shell.
        ("hood", "Monk.obj", "Monk__", (.34, .30, .35), (0, .085, -.020), 2.42, None),
        ("helmet", "Helmet1.obj", "Helmet_", (.40, .36, .42), (0, .15, 0)),
        ("pauldron_left", "Warrior.obj", "ShoulderPad.L", (.28, .29, .34), (.045, -.045, 0)),
        ("pauldron_right", "Warrior.obj", "ShoulderPad.R", (.28, .29, .34), (-.045, -.045, 0)),
        ("walking_stick", "Cleric.obj", "Cleric_Staff_", (.12, 1.30, .10), (0, -.40, 0)),
    ]
    layers = {row[0]: compile_layer(*row) for row in recipes}
    manifest = {
        "version": 1,
        "source_pack": "Retained Quaternius stylized characters",
        "license": "CC0-1.0",
        "license_file": "res://assets_external/licenses/Quaternius_RPG_Characters_CC0.txt",
        "authoring": "Selected original groups, optional cloth/hood cuts, metre fitting, mirrored forward axis; source files preserved.",
        "runtime": "Shared immutable meshes and regional materials; BoneAttachment3D per moving socket.",
        "layers": layers,
    }
    (OUTPUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"SILHOUETTE ASSET BUILD: {len(layers)} retained-library layers, {sum(v['triangles'] for v in layers.values())} triangles total")


if __name__ == "__main__":
    main()
