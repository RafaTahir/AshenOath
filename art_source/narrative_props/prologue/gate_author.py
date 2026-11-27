"""Rebuild the shrine threshold from measured stage geometry and woven surface textures.

From the repository root, run
    python art_source/narrative_props/prologue/gate_author.py --godot PATH_TO_GODOT
Requires NumPy, Pillow and Godot 4.6.3. All intermediate meshes and textures
are generated in a private temporary project. To compare two builds, pass
--output FILE and hash the result.
"""

from pathlib import Path
from collections import defaultdict
from math import sin, cos, pi
import argparse
import json
import random
import shutil
import subprocess
import tempfile
import numpy as np
from PIL import Image


def make_geometry(q):
    rng = random.Random(14824)

    groups = defaultdict(lambda: dict(v=[], n=[], uv=[], idx=[]))

    def unit(v):
        v = np.array(v, dtype=float)
        return v / max(np.linalg.norm(v), 1e-10)

    def poly(mat, points, uv=None, n=None):
        p = np.asarray(points)
        normal = unit(np.cross(p[1] - p[0], p[2] - p[0])) if n is None else n
        if np.linalg.norm(normal) < 0.1:
            return
        group = groups[mat]
        first = len(group["v"]) // 3
        if uv is None:
            uv = [(0, 0), (1, 0), (1, 1), (0, 1)][: len(p)]
        for i, point in enumerate(p):
            group["v"].extend(np.round(point, 5).tolist())
            group["n"].extend(np.round(normal, 5).tolist())
            group["uv"].extend(uv[i])
        # Godot uses clockwise outward-facing triangles.
        for i in range(1, len(p) - 1):
            group["idx"].extend([first, first + i + 1, first + i])

    def box(mat, c, size, bevel=0.0, angle=0, along="y"):
        c = np.array(c)
        s = np.array(size) / 2
        rot = np.array([[cos(angle), -sin(angle), 0], [sin(angle), cos(angle), 0], [0, 0, 1]])

        def xyz(p):
            return c + rot @ np.array(p)

        def uv(p, axis):
            a, b = ([2, 1], [0, 2], [0, 1])[axis]
            if along == "x" and b == 1:
                a, b = b, a
            return (float(p[a] / 0.43), float(p[b] / 1.05))

        def add(pts, n):
            pts = np.array(pts)
            n = np.array(n)
            if np.dot(np.cross(pts[1] - pts[0], pts[2] - pts[0]), n) < 0:
                pts = pts[::-1]
            poly(mat, [xyz(p) for p in pts], [uv(p, np.argmax(abs(n))) for p in pts])

        b = min(bevel, min(s) * 0.45)
        for axis in range(3):
            a1, a2 = [i for i in range(3) if i != axis]
            for sign in (-1, 1):
                pts = []
                for j, k in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
                    u = np.zeros(3)
                    u[axis] = sign * s[axis]
                    u[a1] = j * (s[a1] - b)
                    u[a2] = k * (s[a2] - b)
                    pts.append(u)
                n = np.zeros(3)
                n[axis] = sign
                add(pts, n)
        if b < 0.00001:
            return
        for axis in range(3):
            a1, a2 = [i for i in range(3) if i != axis]
            for j in (-1, 1):
                for k in (-1, 1):
                    pts = []
                    for t, edge in [(-1, 0), (1, 0), (1, 1), (-1, 1)]:
                        u = np.zeros(3)
                        u[axis] = t * (s[axis] - b)
                        u[a1] = j * (s[a1] - (b if edge else 0))
                        u[a2] = k * (s[a2] - (0 if edge else b))
                        pts.append(u)
                    n = np.zeros(3)
                    n[a1] = j
                    n[a2] = k
                    add(pts, n)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    signs = np.array((sx, sy, sz))
                    pts = [signs * (s - b + (np.eye(3)[d] * b)) for d in range(3)]
                    add(pts, signs)

    def tube(mat, points, rad, n=8):
        ps = np.asarray(points)
        rings = []
        if isinstance(rad, (int, float)):
            rad = [rad] * len(ps)
        for j, p in enumerate(ps):
            tangent = unit(ps[min(j + 1, len(ps) - 1)] - ps[max(j - 1, 0)])
            side = unit(np.cross(tangent, [1, 0, 0] if abs(tangent[0]) < 0.86 else [0, 0, 1]))
            up = unit(np.cross(tangent, side))
            rings.append(
                [p + rad[j] * (side * cos(2 * pi * i / n) + up * sin(2 * pi * i / n)) for i in range(n)]
            )
        for j, (a, b) in enumerate(zip(rings, rings[1:])):
            for i in range(n):
                k = (i + 1) % n
                quad = [a[i], a[k], b[k], b[i]]
                poly(
                    mat,
                    quad,
                    [(i / n, j / 4), (k / n, j / 4), (k / n, (j + 1) / 4), (i / n, (j + 1) / 4)],
                )
        for row, centre, d in [(rings[0], ps[0], -1), (rings[-1], ps[-1], 1)]:
            for i in range(n):
                k = (i + d) % n
                poly(mat, [centre, row[i], row[k]], [(0.5, 0.5), (0, 1), (1, 0)])

    def rivet(x, y, z, r=0.014):
        tube(
            "iron_bright", [(x, y, z), (x, y, z + 0.005), (x, y, z + 0.008)], [r, r * 0.85, r * 0.45], 9
        )

    def plate(mat, outline, z, depth):
        p = np.array(outline)
        area = sum(
            p[i, 0] * p[(i + 1) % len(p), 1] - p[(i + 1) % len(p), 0] * p[i, 1] for i in range(len(p))
        )
        if area < 0:
            p = p[::-1]
        # convex plates only
        for i in range(1, len(p) - 1):
            pts = [p[0], p[i], p[i + 1]]
            poly(mat, [[x, y, z + depth] for x, y in pts], [(x / 0.4, y / 0.6) for x, y in pts])
        for i in range(len(p)):
            a = p[i]
            b = p[(i + 1) % len(p)]
            poly(mat, [[*a, z], [*b, z], [*b, z + depth], [*a, z + depth]])

    def cloth_patch(mat, point, x0, x1, y0, y1, nx, ny, scale=(1, 1)):
        # Cloth is drawn on both faces. Ordered normals give the front its key light.
        for iy in range(ny):
            for ix in range(nx):
                coords = [
                    (x0 + (x1 - x0) * (ix + dx) / nx, y0 + (y1 - y0) * (iy + dy) / ny)
                    for dx, dy in [(0, 0), (1, 0), (1, 1), (0, 1)]
                ]
                poly(
                    mat,
                    [point(x, y) for x, y in coords],
                    [(x * scale[0], y * scale[1]) for x, y in coords],
                )

    def ring(mat, c, rad, wire):
        ps = [
            (c[0] + rad * cos(2 * pi * i / 24), c[1] + rad * sin(2 * pi * i / 24), c[2])
            for i in range(25)
        ]
        tube(mat, ps, wire, 6)

    # Planked half gate, hand-hewn stock and applied frame. The upright's keeper
    # spans the seam of the door leaf with two actual steel fastenings.
    box("earth", (0, -0.10, 0), (8, 0.14, 7))
    for i in range(11):
        x = -1.90 + 0.177 * i
        height = 2.1 + rng.uniform(-0.03, 0.09)
        box(
            ["oak", "oak_dark", "oak", "oak"][i % 4],
            (x, height / 2 - 0.035, -0.19 + rng.uniform(-0.006, 0.006)),
            (0.173, height, 0.13),
            0.008,
        )
    box("oak_dark", (-1.06, 0.32, -0.080), (1.84, 0.119, 0.09), 0.009, along="x")
    box("oak_dark", (-0.87, 1.65, -0.079), (1.49, 0.118, 0.09), 0.009, along="x")
    box("oak", (-0.84, 0.96, -0.076), (1.53, 0.112, 0.068), 0.009, angle=0.80, along="x")
    box("oak_dark", (0.04, 1.12, -0.16), (0.147, 2.29, 0.20), 0.013)
    box("oak_dark", (1.43, 1.1, -0.40), (0.16, 2.24, 0.21), 0.017)
    box("oak", (0.74, 1.94, -0.38), (1.62, 0.13, 0.20), 0.012, along="x")
    for x in (-1.56, -0.98, -0.49):
        for y in (0.32, 1.65):
            rivet(x, y, -0.023, 0.011)
    # Pivot plate, strap latch, arching grip, keeper/staple, and a loose lifting ring.
    plate(
        "iron",
        [
            (-0.70, 0.99),
            (-0.715, 1.06),
            (-0.70, 1.18),
            (-0.665, 1.217),
            (-0.620, 1.18),
            (-0.603, 1.06),
            (-0.622, 0.99),
            (-0.661, 0.956),
        ],
        -0.099,
        0.044,
    )
    rivet(-0.661, 1.165, -0.049)
    rivet(-0.661, 1.001, -0.049)
    plate(
        "iron_bright",
        [
            (-0.651, 1.059),
            (-0.610, 1.048),
            (0.070, 1.047),
            (0.099, 1.063),
            (0.099, 1.083),
            (0.075, 1.095),
            (-0.609, 1.106),
            (-0.652, 1.101),
        ],
        -0.048,
        0.030,
    )
    rivet(-0.641, 1.083, -0.012, 0.025)
    tube(
        "iron_bright",
        [
            (-0.54, 1.084, -0.017),
            (-0.51, 1.115, 0.049),
            (-0.462, 1.124, 0.092),
            (-0.356, 1.123, 0.096),
            (-0.316, 1.108, 0.064),
            (-0.30, 1.082, -0.014),
        ],
        [0.015, 0.018, 0.02, 0.02, 0.017, 0.014],
    )
    box("iron", (0.044, 1.043, -0.045), (0.087, 0.125, 0.028), 0.009)
    tube(
        "iron_bright",
        [
            (0.04, 1.017, -0.02),
            (0.04, 1.017, 0.025),
            (0.04, 1.024, 0.037),
            (0.04, 1.116, 0.037),
            (0.04, 1.13, 0.024),
            (0.04, 1.133, -0.022),
        ],
        0.012,
    )
    ring("iron_bright", (-0.20, 1.009, 0.003), 0.047, 0.008)
    tube("iron", [(-0.20, 1.079, -0.012), (-0.20, 1.055, 0.002)], 0.015)
    # Inner room. A small garment hangs from an actual peg on a cut stone wall.
    box("mortar", (0.78, 1.0, -1.04), (2.55, 2.22, 0.15))
    for j in range(8):
        for i in range(8):
            w = 0.345
            h = 0.255
            x = -0.48 + i * w + (j % 2) * 0.16
            y = -0.04 + (j + 0.5) * h
            box(
                ["stone", "stone", "stone_b", "stone_b", "stone"][rng.randrange(5)],
                (x, y, -0.948 + rng.uniform(-0.010, 0.009)),
                (w - rng.uniform(0.009, 0.018), h - rng.uniform(0.009, 0.018), 0.09),
                0.016,
            )
    box("oak_dark", (0.74, 1.51, -0.868), (0.89, 0.075, 0.062), 0.006, along="x")
    for x in (0.36, 0.74, 1.12):
        tube("oak", [(x, 1.508, -0.843), (x, 1.52, -0.76), (x, 1.548, -0.722)], [0.017, 0.015, 0.021], 8)
    # A front-opening coat sagging off a single peg. Open neck, hollow sleeve
    # mouths and darker lining give the empty silhouette its scale and weight.
    cx, cy, cz = 0.74, 1.51, -0.77

    def coat_width(t):
        return float(
            np.interp(t, [0, 0.08, 0.20, 0.44, 0.65, 1], [0.046, 0.130, 0.151, 0.137, 0.127, 0.156])
        )

    def coat(u, t):
        width = coat_width(t)
        x = cx + u * width + 0.017 * t
        y = cy - 0.61 * t - 0.042 * abs(u) * (1 - t) - 0.014 * sin(4 * u + 1) * t**6
        fold = 0.016 * cos(u * 9 + t * 1.8) + 0.004 * cos(18 * u - t)
        z = cz + 0.060 * sin(pi * max(0.0, min(1.0, t))) + 0.018 * (1 - u * u) + fold * (0.3 + 0.7 * t)
        return (x, y, z)

    for half in (-1, 1):

        def panel(u, v):
            t = 1 - v
            gap = 0.025 * (1 - t) + 0.009 + 0.016 * t**4
            x, y, z = coat(half * (gap + u * (1 - gap)), t)
            return (x, y, z)

        cloth_patch("coat", panel, 0, 1, 0, 1, 11, 20, scale=(0.75, 2.6))
        for offset in (0.0, 0.022):
            pts = [list(panel(offset, i / 16)) for i in range(17)]
            for pt in pts:
                pt[2] += 0.0025
            tube("coat_edge", pts, 0.0022)
        # Folded pocket openings and the turned hem follow the same cloth surface.
        pocket = [list(coat(half * u, t)) for u, t in [(0.44, 0.57), (0.58, 0.55), (0.75, 0.54)]]
        for pt in pocket:
            pt[2] += 0.004
        tube("coat_edge", pocket, 0.0055)
        hem = [list(coat(half * u, 0.978)) for u in np.linspace(0.08, 0.94, 15)]
        for pt in hem:
            pt[2] += 0.003
        tube("coat_edge", hem, 0.0028)

    # dark visible interior
    def liner(u, v):
        x, y, z = coat(u * 0.52, 1 - v)
        return x, y, z - 0.020

    cloth_patch("lining", liner, -1, 1, 0.0, 1, 7, 15)

    def sleeve(side):
        def ringpos(t, j):
            angle = 2 * pi * j / 12
            # hanging under its own weight, sleeves point down
            x = cx + side * (0.084 + 0.154 * t + (0.038 if side > 0 else 0.026) * sin(t * pi))
            y = cy - 0.043 - (0.349 if side > 0 else 0.315) * t
            r = 0.059 - 0.021 * t
            return (
                x + r * cos(angle),
                y + r * 0.23 * sin(angle),
                cz + 0.017 + r * 0.54 * sin(angle) + 0.014 * sin(t * pi),
            )

        for j in range(12):
            for k in range(10):
                a, b = k / 10, (k + 1) / 10
                mat = "coat_edge" if k == 9 else "coat"
                poly(
                    mat,
                    [ringpos(a, j), ringpos(a, j + 1), ringpos(b, j + 1), ringpos(b, j)],
                    [(j / 12, a), (j / 12 + 1 / 12, a), ((j + 1) / 12, b), (j / 12, b)],
                )
        # Inset dark cuff mouth
        ringp = [ringpos(1, j) for j in range(13)]
        centre = np.mean(ringp[:-1], axis=0) + [0, 0.009, -0.002]
        for a, b in zip(ringp, ringp[1:]):
            poly("lining", [centre, a, b], [(0, 0), (1, 0), (0, 1)])

    sleeve(-1)
    sleeve(1)
    for side in (-1, 1):
        x = cx
        poly(
            "coat_edge",
            [
                (x + side * 0.009, cy - 0.04, cz + 0.029),
                (x + side * 0.018, cy - 0.143, cz + 0.069),
                (x + side * 0.107, cy - 0.058, cz + 0.039),
                (x + side * 0.063, cy + 0.009, cz + 0.006),
            ],
        )
    for t in (0.29, 0.43, 0.57, 0.72):
        x, y, z = coat(-0.08, t)
        tube("button", [(x, y, z + 0.002), (x, y, z + 0.011)], [0.010, 0.008], 8)
    # Small warm hearth beneath the coat, nested inside dark masonry.
    hearth_offsets = {material: len(group["v"]) for material, group in groups.items()}
    box("hearth", (0.86, 0.09, -0.55), (1.06, 0.18, 0.60), 0.025)
    box("hearth", (0.88, 0.246, -0.69), (0.82, 0.18, 0.28), 0.016)
    for j in range(11):
        x = 0.45 + 0.078 * j
        z = -0.54 + 0.03 * sin(j * 2)
        tube("coal", [(x - 0.09, 0.188, z + 0.08), (x + 0.08, 0.22, z - 0.06)], [0.032, 0.027], 8)
        for k in range(3):
            t = (j * 1.65 + k) * 1.9
            x2 = x + 0.02 * sin(t)
            z2 = z + 0.035 * cos(t)
            box("embers", (x2, 0.215 + 0.010 * k, z2), (0.039, 0.014, 0.022), 0.003)
    for material, group in groups.items():
        for i in range(hearth_offsets.get(material, 0), len(group["v"]), 3):
            group["v"][i] += 0.34
            group["v"][i + 1] += 0.28
    box("hearth", (1.20, 0.14, -0.55), (1.01, 0.28, 0.57), 0.014)
    # Texture-backed tailboard and hanging woven shawl outside, with a flat crown
    # measured at y=.825. Its low rail keeps the gate mechanism in clear view.
    rail_offsets = {material: len(group["v"]) for material, group in groups.items()}
    box("oak_dark", (0.27, 0.546, 0.525), (1.33, 0.177, 0.217), 0.010, along="x")
    for x in (-0.33, 0.86):
        box("iron", (x, 0.516, 0.632), (0.039, 0.251, 0.020), 0.004)
        rivet(x, 0.58, 0.646, 0.008)
        rivet(x, 0.452, 0.646, 0.008)
        box("oak_dark", (x, 0.20, 0.50), (0.072, 0.64, 0.11), 0.007)

    def shawl(u, v):
        x = 0.22 + u * 0.412 + sin(v * pi * 1.7) * 0.012
        if v < 0.20:
            a = v / 0.20
            y = 0.57 + 0.075 * sin(a * pi / 2)
            z = 0.405 + 0.042 * a
        elif v < 0.51:
            a = (v - 0.20) / 0.31
            y = 0.645
            z = 0.447 + 0.197 * a
        else:
            a = (v - 0.51) / 0.49
            height = 0.190 + 0.055 * cos(u * 2.1 - 1.0) + 0.02 * sin(u * 4.0)
            y = 0.645 - height * a - 0.004 * sin(3 * pi * a)
            z = (
                0.650
                + 0.049 * sin(a * pi * 0.63)
                + (0.003 + 0.020 * a) * sin(12 * u + 0.7 * a)
                + (0.002 + 0.006 * a) * cos(19 * u - 0.8 * a)
            )
        # area directly supporting the parcel stays flat
        if v < 0.51:
            local = max(0, min(1, (abs(u - 0.04) - 0.25) / 0.30))
            y += local * (0.004 + 0.003 * sin(10 * u + v * 3)) * sin(v * pi)
        return (x, y, z)

    for k in range(32):
        v0 = k / 32
        v1 = (k + 1) / 32
        v = (v0 + v1) * 0.5
        material = "ochre" if k in [1, 2, 27, 28, 30] else "shawl"
        cloth_patch(material, shawl, -1, 1, v0, v1, 28, 1, scale=(2.0, 3.5))
    for side in (-1, 1):
        pts = [shawl(side, i / 48) for i in range(49)]
        tube("ochre_dim", pts, 0.0025, 5)
    for i in range(58):
        u = -1 + 2 * i / 57
        end = np.array(shawl(u, 1.0))
        d = 0.018 + 0.013 * (sin(i * 27) ** 2)
        tube(
            "ochre_dim" if i % 5 else "shawl",
            [end, end + (0.002, -d * 0.65, 0.001), end + (0.004 * cos(i * 4), -d, 0.001)],
            [0.0016, 0.0012, 0.00065],
            4,
        )
    for material, group in groups.items():
        for i in range(rail_offsets.get(material, 0) + 1, len(group["v"]), 3):
            group["v"][i] += 0.18

    (q / "gate_geo.json").write_text(json.dumps(groups, separators=(",", ":")))


def make_textures(q):
    rng = np.random.default_rng(812)
    s = 384
    y, x = np.mgrid[:s, :s] / s

    def noise(h, w):
        a = rng.random((h, w), dtype=np.float32)
        t = np.pad(a, ((1, 1), (1, 1)), mode="wrap")
        b = Image.fromarray(t).resize(
            (int((w + 2) * s / w), int((h + 2) * s / h)), Image.Resampling.BICUBIC
        )
        return np.asarray(b.crop((s // w, s // h, s // w + s, s // h + s)), dtype=float) - 0.5

    def make(name, base, field):
        a = np.clip(np.array(base)[None, None, :] + field[:, :, None], 1, 253).astype("uint8")
        Image.fromarray(a).save(q / (name + ".png"))

    grain = rng.normal(0, 1, (s, s))
    flow = 0.009 * np.sin(2 * np.pi * y) + noise(4, 12) * 0.020 + noise(11, 16) * 0.012
    uv = x + flow
    lines = (
        3 * np.sin(uv * 2 * np.pi * 48)
        + 2 * np.sin(uv * 2 * np.pi * 79)
        + 4 * np.sin(uv * 2 * np.pi * 20)
    )
    wood = (
        noise(6, 60) * 31
        + noise(5, 28) * 18
        + noise(5, 80) * 8
        + noise(48, 96) * 7
        + noise(38, 240) * 15
        + lines
        + grain * 3.2
    )
    for px, py, rad in ((0.22, 0.75, 0.12), (0.81, 0.29, 0.06)):
        dist = np.sqrt(((x - px + flow * 1.2) / 0.6) ** 2 + (y - py) ** 2)
        mask = np.maximum(0, 1 - dist / rad) ** 2
        wood += mask * np.sin(dist * 650) * 13 - mask * 17
    make("oak", (102, 76, 52), wood)
    make("oak_dark", (75, 56, 42), wood * 0.83)
    iron = noise(12, 19) * 11 + noise(48, 48) * 11 + noise(110, 100) * 8 + grain * 3
    make("iron", (51, 51, 47), iron)
    make("iron_bright", (107, 108, 98), iron * 1.05)
    wool = (
        3 * np.sin(x * 2 * np.pi * 83)
        + 2.5 * np.sin(y * 2 * np.pi * 89)
        + noise(72, 70) * 12
        + noise(7, 9) * 6
        + grain * 2
    )
    make("shawl", (104, 65, 43), wool)
    make("ochre", (177, 135, 62), wool * 0.85)
    make("ochre_dim", (138, 101, 54), wool)
    make("coat", (64, 80, 85), wool * 0.84)
    make("coat_edge", (81, 94, 96), wool)
    make("lining", (60, 46, 40), wool)
    make("button", (133, 112, 77), iron)
    stone = noise(5, 6) * 27 + noise(13, 17) * 19 + noise(40, 37) * 16 + noise(100, 90) * 10 + grain * 3
    make("earth", (77, 69, 57), stone)
    make("mortar", (76, 74, 61), stone * 0.65)
    make("stone", (122, 114, 94), stone)
    make("stone_b", (112, 105, 90), stone)
    make("hearth", (81, 76, 66), stone)
    make("coal", (45, 37, 31), stone)
    make("embers", (178, 79, 26), stone)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot 4 console executable")
    default_output = (
        Path(__file__).resolve().parents[3]
        / "outputs"
        / "AshenOathTheRoadBetweenCrowns/assets/narrative_props/prologue/gate_furnishings.res"
    )
    parser.add_argument("--output", type=Path, default=default_output)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="ao-gate-") as private:
        work = Path(private)
        (work / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Threshold authoring"\n', encoding="utf-8"
        )
        make_textures(work)
        make_geometry(work)
        shutil.copyfile(Path(__file__).with_name("gate_bake.gd"), work / "gate_bake.gd")
        output = work / "gate_furnishings.res"
        cmd = [
            args.godot,
            "--headless",
            "--audio-driver",
            "Dummy",
            "--rendering-method",
            "gl_compatibility",
            "--path",
            str(work),
            "--script",
            "res://gate_bake.gd",
            "--",
            str(work),
            str(output),
        ]
        run = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=True, timeout=180
        )
        if "ERROR:" in run.stdout or not output.is_file():
            raise RuntimeError(run.stdout)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(output, args.output)
        print(f"Wrote {args.output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
