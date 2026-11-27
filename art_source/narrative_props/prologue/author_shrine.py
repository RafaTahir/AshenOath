"""Bake Anwen's linen, bobbin, feathers and pastry from the painted crow prologue.

Requires Python 3, NumPy, Pillow and Godot 4.6. From any directory run
    python author_shrine.py --godot /path/to/godot
Use --output to write a candidate mesh outside the worktree.
"""

import argparse
import json
from math import cos, pi, sin, sqrt
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile

import numpy as np
from PIL import Image


def sculpt(workdir: Path):
    rng = random.Random(6348)

    def normalized(v):
        v = np.array(v, float)
        return v / max(np.linalg.norm(v), 0.0000001)

    def rgb(h):
        return np.array(tuple(int(h[i : i + 2], 16) / 255 for i in [0, 2, 4]))

    def tint(c, t):
        return np.clip(c * t, 0, 1)

    class Surface:
        def __init__(self, key):
            self.key = key
            self.v = []
            self.poly = []
            self.c = []
            self.uv = []
            self.norm = []

        def add_vertex(self, p, c, uv=None):
            self.v.append(np.asarray(p, float))
            self.c.append(np.clip(c, 0, 1))
            self.norm.append(np.zeros(3))
            self.uv.append(list(uv if uv is not None else (p[0] * 8, p[2] * 8)))
            return len(self.v) - 1

        def add_triangle(self, a, b, c, n=None):
            v = self.v
            norm = np.cross(v[b] - v[a], v[c] - v[a])
            if np.linalg.norm(norm) < 1.0e-12:
                return
            if n is not None and np.dot(norm, n) < 0:
                b, c = c, b
                norm = -norm
            self.poly.append((a, c, b))
            for j in (a, b, c):
                self.norm[j] += norm

        def add_quad(self, a, b, c, d, n=None):
            self.add_triangle(a, b, c, n)
            self.add_triangle(a, c, d, n)

        def pack(self):
            def values(arr):
                return np.round(np.asarray(arr, dtype=float), 6).flatten().tolist()

            return dict(
                pos=values(self.v),
                norm=values([normalized(n) for n in self.norm]),
                uv=values(self.uv),
                color=values(self.c),
                idx=np.array(self.poly).flatten().tolist(),
            )

    surfaces = {
        k: Surface(k) for k in ("stone", "linen", "thread", "wood", "crust", "onion", "feather")
    }

    def add_tube(m, pts, r, col, n=6):
        pts = np.array(pts, float)
        rings = []
        for i, p in enumerate(pts):
            v = normalized(pts[min(i + 1, len(pts) - 1)] - pts[max(0, i - 1)])
            cross = np.cross(v, [0, 1, 0] if abs(v[1]) < 0.93 else [0, 0, 1])
            e = normalized(cross)
            f = normalized(np.cross(v, e))
            rr = r if np.isscalar(r) else r[i]
            ring = []
            for j in range(n):
                t = j * 2 * pi / n
                ring.append(
                    m.add_vertex(p + (cos(t) * e + sin(t) * f) * rr, col, (i / len(pts), j / n))
                )
            if i:
                for j in range(n):
                    k = (j + 1) % n
                    o = pts[i - 1] * 0.5 + p * 0.5
                    point = m.v[ring[j]] - p
                    m.add_quad(rings[-1][j], rings[-1][k], ring[k], ring[j], point)
            rings.append(ring)

    def bake_grain(kind):
        g = np.random.default_rng(163 + len(kind))
        n = 96
        t = np.zeros((n, n), float)
        for count, am in [(3, 7), (8, 9), (27, 6), (64, 3)]:
            grid = g.normal(0, am, (count, count))
            extended = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
            img = Image.fromarray(np.float32(extended)).resize(
                (n + n // count, n + n // count), Image.Resampling.BICUBIC
            )
            t += np.array(img)[:n, :n]
        X, Y = np.meshgrid(np.arange(n) / n, np.arange(n) / n)
        if kind == "linen":
            t += 4 * np.sin(2 * pi * X * 24) * (0.5 + 0.5 * np.cos(2 * pi * Y * 24)) + 5 * np.sin(
                2 * pi * Y * 24
            )
        if kind == "wood":
            t += 5 * np.sin(2 * pi * (Y * 23 + np.sin(X * 2 * pi) * 0.28))
        if kind == "crust":
            t += g.normal(0, 5, (n, n))
        t += g.normal(0, 2.5, (n, n))
        shade = np.uint8(np.clip(235 + t, 194, 255))
        Image.fromarray(shade).save(workdir / (kind + ".png"), optimize=True)

    for k in surfaces:
        bake_grain(k)
    # A single continuous old flagstone with a chipped bullnose, not a floating board.
    m = surfaces["stone"]
    stone_columns = 22
    stone_rows = 18

    def slab(a, b):
        return (
            -0.0053
            + 0.0007 * sin(a * 43 + b * 31)
            + 0.00045 * sin(b * 83 - a * 52)
            + 0.00065 * sin(a * 12 + b * 56)
        )

    grid = []
    for j in range(stone_rows + 1):
        z = -0.39 + j * 0.75 / stone_rows
        row = []
        for i in range(stone_columns + 1):
            x = -0.48 + i * 0.96 / stone_columns
            col = rgb("53564e") * (1 + 0.025 * cos(x * 82 + z * 48) + 0.02 * sin(z * 69 - x * 130))
            row.append(m.add_vertex((x, slab(x, z), z), col, (x * 5.0, z * 5.0)))
        grid.append(row)
    for j in range(stone_rows):
        for i in range(stone_columns):
            m.add_quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], (0, 1, 0))
    # Worn sage linen under the token: exactly planar through the complete coin
    # and cord; softly curling edges, folded selvedges and hand-ironed creases.
    m = surfaces["linen"]
    linen_columns = 36
    linen_rows = 27

    def cloth(u, v):
        x = -0.165 + 0.275 * u
        z = -0.182 + 0.287 * v + 0.012 * u
        x += 0.002 * sin(v * 17 + 1) * (1 - u) ** 5 + 0.0012 * sin(v * 21) * u**5
        z += 0.002 * cos(u * 21) * v**5
        flat = max(0, abs(x) - 0.057, -z - 0.107, z - 0.059)
        ripple = min(1, max(0, flat / 0.027))
        y = -0.001 + ripple * (
            0.0016 * sin(54 * x - 34 * z)
            + 0.0013 * cos(57 * z + 23 * x)
            + 0.0012 * sin(135 * x + 73 * z)
        )
        y += 0.006 * (1 - u) ** 12 * (0.4 + 0.6 * sin(11 * v + 0.7) ** 2) + 0.0035 * v**15 * (
            0.2 + 0.8 * cos(8 * u + 0.5) ** 2
        )
        return np.array([x, y, z])

    grid = []
    u_steps = [
        u for u in np.linspace(0, 1, linen_columns + 1) if not -0.041 < cloth(u, 0.50)[0] < 0.041
    ]
    v_steps = [v for v in np.linspace(0, 1, linen_rows + 1) if not -0.040 < cloth(0.60, v)[2] < 0.040]
    for v in v_steps:
        row = []
        for u in u_steps:
            p = cloth(u, v)
            col = rgb("777d76") * (1 + 0.012 * cos(v * 18 + u * 13))
            row.append(m.add_vertex(p, col, (p[0] * 11, p[2] * 11)))
        grid.append(row)
    for j in range(len(v_steps) - 1):
        for i in range(len(u_steps) - 1):
            m.add_quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], (0, 1, 0))
    # Stitched finished edge is reserved for the near and left sides.
    for iu in (0.014, 0.026):
        pts = [cloth(iu, j / 50) + [0, 0.00024, 0] for j in range(51)]
        add_tube(m, pts, 0.0006, rgb("68716b"), 4)
    for iv in (0.962, 0.975):
        add_tube(
            m, [cloth(i / 64, iv) + [0, 0.00024, 0] for i in range(65)], 0.00050, rgb("667368"), 4
        )
    for i in range(34):
        u = 0.04 + i * 0.027
        v = 0.985
        add_tube(
            m,
            [cloth(u, v) + [0, 0.00036, 0], cloth(u + 0.01, v - 0.002) + [0, 0.0004, 0]],
            0.00036,
            rgb("cac7ad"),
            4,
        )
    # Rosewood bobbin with an open turning hole, carved flanges and real thread.
    bobbin_centre = np.array([-0.088, 0.0, -0.045])

    def turn_spool(m, profile, col):
        rings = []
        n = 36
        for row, (y, r, c) in enumerate(profile):
            ring = []
            for j in range(n):
                a = 2 * pi * j / n
                rad = r * (1 + 0.008 * sin(a * 5 + 0.54) + 0.006 * sin(a * 7))
                C = tint(rgb(col), c * (1 + 0.017 * sin(a * 9)))
                ring.append(
                    m.add_vertex(
                        bobbin_centre + [rad * cos(a), y, rad * sin(a)], C, (j / 12.0, y * 21)
                    )
                )
            if row:
                dy = y - profile[row - 1][0]
                dr = r - profile[row - 1][1]
                for j in range(n):
                    a = 2 * pi * (j + 0.5) / n
                    k = (j + 1) % n
                    normal = (dy * cos(a), -dr, dy * sin(a))
                    m.add_quad(rings[-1][j], rings[-1][k], ring[k], ring[j], normal)
            rings.append(ring)

    turn_spool(
        surfaces["wood"],
        [
            (0, 0.004, 0.53),
            (0, 0.024, 0.72),
            (0.0014, 0.0252, 0.80),
            (0.0038, 0.0259, 1.1),
            (0.0052, 0.0251, 1.02),
            (0.0062, 0.020, 0.88),
            (0.0064, 0.011, 0.80),
            (0.051, 0.011, 0.86),
            (0.0512, 0.019, 0.94),
            (0.053, 0.0223, 1.18),
            (0.0557, 0.0223, 0.95),
            (0.057, 0.0208, 1.14),
            (0.0574, 0.007, 1.11),
            (0.0572, 0.0037, 0.8),
            (0.055, 0.003, 0.45),
            (0, 0.003, 0.3),
        ],
        "715542",
    )
    turn_spool(
        surfaces["thread"],
        [
            (0.0069, 0.011, 0.72),
            (0.0076, 0.018, 0.84),
            (0.012, 0.0201, 0.97),
            (0.023, 0.0208, 1.02),
            (0.035, 0.0204, 1.0),
            (0.045, 0.0196, 0.92),
            (0.0503, 0.0176, 1),
            (0.051, 0.011, 0.82),
        ],
        "84827d",
    )
    for row in range(18):
        h = 0.0082 + row * 0.00227
        rr = 0.0184 + 0.0027 * sin((h - 0.006) / 0.051 * pi)
        pts = []
        for j in range(37):
            a = (j / 36) * 2 * pi + 0.6
            rad = rr + 0.00030 * sin(3 * a + row * 0.13)
            pts.append(
                bobbin_centre + [cos(a) * rad, h + 0.00048 * sin(a * 1.02 + row * 0.11), sin(a) * rad]
            )
        add_tube(
            surfaces["thread"],
            pts,
            0.00068,
            rgb(["787874", "83827c", "97958c", "83827b"][row % 4]),
            4,
        )

    # Loose thread unwinds from the spool, sags to the cloth, and ends on the token.
    def bez(points, n):
        A, B, C, D = np.array(points)
        return [
            (1 - t) ** 3 * A + 3 * (1 - t) ** 2 * t * B + 3 * (1 - t) * t * t * C + t**3 * D
            for t in np.linspace(0, 1, n)
        ]

    thread = bez(
        [
            [-0.070, 0.019, -0.045],
            [-0.044, 0.006, -0.026],
            [-0.116, 0.004, 0.011],
            [-0.091, 0.001, 0.029],
        ],
        25,
    )
    thread += bez(
        [thread[-1], [-0.076, 0.0003, 0.044], [-0.053, 0.0013, 0.015], [-0.052, 0.0011, 0.007]], 20
    )[1:]
    thread += bez(
        [thread[-1], [-0.053, 0.002, -0.010], [-0.032, 0.002, -0.011], [-0.024, 0.003, -0.004]], 16
    )[1:]
    add_tube(surfaces["thread"], thread, 0.00085, rgb("878782"), 7)

    # A worn oval wooden trencher keeps the pastry clear of the burial thread.
    # The shallow hollow ends in a rolled edge. The planar patch carries both pieces.
    def make_trencher():
        mesh = surfaces["wood"]
        n = 52
        centre = np.array([0.116, 0.0062, -0.001])
        previous = []
        for radius, height, value in [
            (0.003, -0.006, 0.53),
            (0.89, -0.006, 0.66),
            (0.98, -0.003, 0.82),
            (1, 0.001, 0.87),
            (0.99, 0.0046, 1.12),
            (0.955, 0.0047, 1.09),
            (0.938, 0.003, 1.00),
            (0.88, 0, 1.0),
            (0.70, 0, 1.02),
            (0.40, 0, 1.06),
            (0.006, 0, 1.08),
        ]:
            ring = []
            for j in range(n):
                angle = 2 * pi * j / n
                shape = 1 + 0.008 * sin(3 * angle + 0.34) + 0.014 * cos(5 * angle)
                x = np.sign(cos(angle)) * abs(cos(angle)) ** 0.86 * 0.074 * radius * shape
                z = np.sign(sin(angle)) * abs(sin(angle)) ** 0.86 * 0.081 * radius * shape
                color = tint(rgb("564637"), value * (1 + 0.030 * sin(angle * 7)))
                ring.append(mesh.add_vertex(centre + [x, height, z], color, (x * 5, z * 12)))
            if previous:
                for j in range(n):
                    k = (j + 1) % n
                    expected = [
                        (height - prior_height) * cos(2 * pi * j / n),
                        prior_radius - radius,
                        (height - prior_height) * sin(2 * pi * j / n),
                    ]
                    mesh.add_quad(previous[j], previous[k], ring[k], ring[j], expected)
            previous = ring
            prior_height, prior_radius = height, radius

    make_trencher()

    # Baked hand pie torn into two uneven pieces. Its cut face is a real rough
    # cross-section with distinct dark filling and pale, curled pieces of onion.
    def make_pie(small):
        x0, x1 = (0.18, 1) if small else (-1, 0.18)
        ang = np.deg2rad(43 if small else -43)
        cx, cz = (0.127, -0.031) if small else (0.105, 0.022)
        off = np.array([cx, 0.0067, cz])
        mid = (x0 + x1) / 2

        def place(a, b, c):
            x = (a - mid) * 0.069
            return off + np.array([x * cos(ang) + c * sin(ang), b, -x * sin(ang) + c * cos(ang)])

        def pie_section(a, t):
            width = max(0.03, sqrt(max(0, 1 - a * a)))
            b = -width * 0.009 - 0.003 * a
            half = 0.029 * width
            z = b + half * t
            arch = max(0.0, 1 - t * t) ** 0.76
            h = (
                0.003
                + 0.025 * width**0.83 * arch * (1 + 0.045 * sin(9 * a + 6 * t))
                + 0.0045 * (1 - abs(t)) * (1 - abs(a))
            )
            return z, h

        m = surfaces["crust"]
        nx = 23 if not small else 17
        nt = 14
        rows = []
        for i in range(nx + 1):
            a = x0 + (x1 - x0) * i / nx
            row = []
            for j in range(nt + 1):
                t = -1 + j * 2 / nt
                z, h = pie_section(a, t)
                # Toast on the crown, paler flaky rim.
                toast = (0.5 + 0.5 * cos(13 * a - 3 * t) * sin(7 * t + 2 * a)) * (1 - t * t)
                col = rgb("ba7a41") * (1 - 0.27 * toast) + rgb("cba671") * (0.13 * abs(t) ** 4)
                row.append(m.add_vertex(place(a, h, z), col, (a * 0.72, t * 0.35)))
            rows.append(row)
        for i in range(nx):
            for j in range(nt):
                m.add_quad(rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1], (0, 1, 0))
        for k in [0, nt]:
            ring = []
            for i in range(nx + 1):
                a = x0 + (x1 - x0) * i / nx
                t = -1 if k == 0 else 1
                z, h = pie_section(a, t)
                u = place(a, 0.0004, z)
                ring.append(m.add_vertex(u, rgb("956139")))
                if i:
                    m.add_quad(rows[i - 1][k], rows[i][k], ring[i], ring[i - 1])
        a = 0.18
        face = np.array([cos(ang), 0, -sin(ang)]) * (-1 if small else 1)

        def front(j, lev, extra=0):
            t = j * 2 - 1
            z, h = pie_section(a, t)
            rag = 0.0012 * sin(63 * j + 5 * lev) + 0.0008 * sin(29 * j - 8 * lev)
            return place(a, 0.0004 + lev * (h - 0.0004), z) + (rag + extra) * face

        prev = []
        for k, lev in enumerate([0, 0.10, 0.19, 0.36, 0.57, 0.72, 0.84, 0.91, 1]):
            pts = []
            for j in range(22):
                v = j / 21
                c = rgb("c4a363") if k in (0, 1, 7, 8) else rgb("9f7748")
                if k == 6:
                    c = rgb("d6b47c")
                pts.append(
                    m.add_vertex(
                        front(v, lev), tint(c, 0.84 + 0.16 * rng.random()), (j / 13, lev / 3)
                    )
                )
            if k:
                for j in range(21):
                    m.add_quad(prev[j], prev[j + 1], pts[j + 1], pts[j], face)
            prev = pts
        # Onion slices exposed by the break. They curve and vary in thickness.
        for j in range(15 if not small else 11):
            at = rng.uniform(0.11, 0.89)
            hh = rng.uniform(0.26, 0.67)
            w = rng.uniform(0.05, 0.14)
            bend = rng.uniform(0.025, 0.12)
            pts = [
                front(at + w * (t - 0.5), hh + bend * (1 - (t * 2 - 1) ** 2), 0.0013)
                for t in np.linspace(0, 1, 9)
            ]
            add_tube(
                surfaces["onion"],
                pts,
                [0.0004 + 0.0011 * sin(pi * t) ** 0.5 for t in np.linspace(0, 1, 9)],
                rgb(["dfc58a", "e2c897", "b79856", "cabe8a"][j % 4]),
                6,
            )
        # Folded pastry seam pinched together; tight and finer near the corners.
        for jj in range(13 if not small else 9):
            a = x0 + (x1 - x0) * (jj + 0.42) / (13 if not small else 9)
            z, h = pie_section(a, -1)
            z2, hh = pie_section(min(a + 0.07, x1), -0.73)
            pts = bez(
                [
                    place(a, h, z),
                    place(a - 0.015, h + 0.0028, z + 0.001),
                    place(a + 0.032, hh + 0.0004, z2),
                    place(min(a + 0.07, x1), hh, z2),
                ],
                9,
            )
            add_tube(
                m,
                pts,
                [0.0005 + 0.0016 * sin(pi * t) for t in np.linspace(0, 1, 9)],
                rgb("dcb074"),
                6,
            )
        # Fine blister cracks and a few open steam cuts with raised lamination.
        for aa in np.linspace(x0 + 0.20, x1 - 0.16, 3 if not small else 2):
            pts = []
            for t, v in zip(np.linspace(0.07, -0.32, 11), np.linspace(0, 1, 11)):
                a = aa + 0.15 * v
                z, h = pie_section(a, t)
                pts.append(place(a, h + 0.00025, z))
            add_tube(
                m,
                pts,
                [0.0002 + 0.0012 * sin(pi * t) for t in np.linspace(0, 1, 11)],
                rgb("8c5735"),
                5,
            )
            add_tube(
                m,
                [p + np.array([-0.001, 0.0004, 0.0007]) for p in pts],
                [0.0002 + 0.0008 * sin(pi * t) for t in np.linspace(0, 1, 11)],
                rgb("d8ad73"),
                5,
            )
        # Unevenly blistered patches of baked dough; each follows the local dome.
        for mark in range(11 if not small else 6):
            aa = rng.uniform(x0 + 0.10, x1 - 0.10)
            tt = rng.uniform(-0.70, 0.72)
            da = rng.uniform(0.021, 0.068)
            dt = rng.uniform(0.035, 0.105)
            last = []
            for radius, shade, rise in [
                (1.0, "b87943", 0.00020),
                (0.64, "ad6a39", 0.00031),
                (0.25, "965a32", 0.00038),
                (0.025, "b47945", 0.00046),
            ]:
                row = []
                for j in range(8):
                    ang2 = j * pi / 4
                    a = aa + da * radius * cos(ang2)
                    u = tt + dt * radius * sin(ang2)
                    z, h = pie_section(a, u)
                    row.append(m.add_vertex(place(a, h + rise, z), rgb(shade), (a * 0.72, u * 0.35)))
                if last:
                    for j in range(8):
                        m.add_quad(last[j], last[(j + 1) % 8], row[(j + 1) % 8], row[j], (0, 1, 0))
                last = row

    make_pie(False)
    make_pie(True)
    # Flakes near the torn edges catch the light, with unequal silhouettes.
    for i in range(29):
        x = rng.uniform(0.063, 0.151)
        z = rng.uniform(-0.016, 0.029)
        scale = rng.uniform(0.00065, 0.0023)
        y = 0.0065
        verts = []
        for j in range(3):
            angle = 2 * pi * j / 3 + i
            verts.append(
                surfaces["crust"].add_vertex(
                    (x + scale * cos(angle), y, z + scale * 0.68 * sin(angle)), rgb("c99557")
                )
            )
        v = surfaces["crust"].add_vertex((x - 0.0003, y + scale * 0.51, z), rgb("dfb77c"))
        for j in range(3):
            surfaces["crust"].add_triangle(verts[j], v, verts[(j + 1) % 3], (0, 1, 0))
    bundle_centres = []
    bundle_axes = []
    # Sella's bundled shrine feathers, subdued against the cool far edge of the sill.
    for j in range(5):
        b = np.array([0.047 + 0.006 * j, -0.0005, -0.105 - 0.003 * j])
        v = np.array([0.075 + 0.018 * rng.random(), 0.008 * rng.random(), -0.047 - 0.009 * (j - 2)])
        side = normalized(np.array([-v[2], 0, v[0]]))
        bundle_centres.append(b + 0.19 * v + [0, 0.003 * sin(0.19 * pi), -0.005 * sin(0.19 * pi)])
        bundle_axes.append(normalized(v))
        cen = []
        left = []
        right = []
        m = surfaces["feather"]
        vc = rgb(["555849", "474b45", "787665", "505957", "5a5952"][j])
        for i in range(29):
            t = i / 28
            mid = b + t * v + np.array([0, 0.003 * sin(pi * t), -0.005 * sin(pi * t)])
            cen.append(mid)
            w = 0.0085 * sin(pi * t) ** 0.82 * (0.62 + 0.38 * t) if t > 0 and t < 1 else 0.00015
            l = mid - side * w * (0.72 + 0.14 * cos(i * 2.3)) - 0.003 * sin(t * pi) * normalized(v)
            r = mid + side * w * (0.94 + 0.08 * sin(i * 3.84)) - 0.0015 * sin(t * pi) * normalized(v)
            left.append(
                [
                    m.add_vertex(l + [0, -0.0008, 0], tint(vc, 1.16 if i % 4 == 0 else 0.95)),
                    m.add_vertex(mid, tint(vc, 1.18)),
                ]
            )
            right.append(m.add_vertex(r + [0, -0.0008, 0], tint(vc, 0.91)))
            if i:
                m.add_quad(left[-2][0], left[-1][0], left[-1][1], left[-2][1], (0, 1, 0))
                m.add_quad(left[-2][1], left[-1][1], right[-1], right[-2], (0, 1, 0))
        for k in range(5, 24, 3):
            t = k / 28
            w = 0.0070 * sin(pi * t) ** 0.82 * (0.62 + 0.38 * t)
            for sign in [-1, 1]:
                end = cen[k] + side * sign * w - 0.0035 * normalized(v)
                add_tube(
                    m, [cen[k] + [0, 0.00021, 0], end + [0, 0.0001, 0]], 0.00020, tint(vc, 1.30), 3
                )
        add_tube(
            m, cen, [0.0002 + 0.00058 * (1 - t) for t in np.linspace(0, 1, 29)], tint(vc, 1.27), 4
        )
    # The five quills share a narrow loop of Sella's dressing cord.
    axis = normalized(np.mean(bundle_axes, axis=0))
    transverse = normalized(np.cross(axis, [0, 1, 0]))
    bundle = np.array(bundle_centres)
    centre = np.mean(bundle, axis=0)
    radius = max(abs((bundle - centre) @ transverse)) + 0.0056
    for turn in range(3):
        pts = [
            centre
            + axis * ((turn - 1) * 0.0013)
            + transverse * (radius * cos(alpha))
            + np.array([0, 0.0033 * sin(alpha), 0])
            for alpha in np.linspace(0, 2 * pi, 24)
        ]
        add_tube(surfaces["thread"], pts, 0.00052, rgb("9f927a"), 4)
    mesh = {k: v.pack() for k, v in surfaces.items()}
    (workdir / "mesh.json").write_text(json.dumps(mesh, separators=(",", ":")))
    print("Triangles", sum(len(v.poly) for v in surfaces.values()))


def main():
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument(
        "--output",
        type=Path,
        default=repo
        / "outputs/AshenOathTheRoadBetweenCrowns/assets/narrative_props/prologue/shrine_still_life.res",
    )
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="ashen-oath-shrine-") as temp:
        workdir = Path(temp)
        (workdir / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        sculpt(workdir)
        shutil.copy2(Path(__file__).with_name("cook_shrine.gd"), workdir / "cook_shrine.gd")
        subprocess.run(
            [
                args.godot,
                "--headless",
                "--path",
                str(workdir),
                "--script",
                "res://cook_shrine.gd",
                "--",
                "res://shrine_still_life.res",
            ],
            check=True,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(workdir / "shrine_still_life.res", args.output)


if __name__ == "__main__":
    main()
