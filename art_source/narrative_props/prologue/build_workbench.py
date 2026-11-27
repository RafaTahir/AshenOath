"""Bake Sella's wagon paint board and washbasin.

From the repository root run:
    python art_source/narrative_props/prologue/build_workbench.py --godot GODOT_BINARY

Requires NumPy, Pillow and Godot 4.6.3. Coordinates are metres in Godot axes.
"""

from pathlib import Path
import argparse
import subprocess
import tempfile
import json, math, random
import numpy as np
from PIL import Image
from collections import defaultdict

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default="godot", help="Godot 4 executable")
parser.add_argument("--output", type=Path, help="Alternate path for the baked scenes and meshes")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[3]
ART = args.output or repo / "outputs/AshenOathTheRoadBetweenCrowns/assets/narrative_props/prologue"
ART = ART.resolve()
temporary = tempfile.TemporaryDirectory(prefix="ashen-crow-scenery-")
OUT = Path(temporary.name)
ART.mkdir(parents=True, exist_ok=True)
rng = random.Random(42)
V = lambda a: np.asarray(a, dtype=float)


def unit(a):
    a = V(a)
    return a / max(np.linalg.norm(a), 1e-9)


def periodic_noise(size, cells, seed):
    rr = np.random.default_rng(seed)
    n = rr.uniform(-1, 1, (cells[1] + 1, cells[0] + 1))
    n[-1, :] = n[0, :]
    n[:, -1] = n[:, 0]
    yy, xx = np.mgrid[:size, :size]
    xf = xx * cells[0] / size
    yf = yy * cells[1] / size
    ix, iy = xf.astype(int), yf.astype(int)
    u = xf - ix
    v = yf - iy
    u = u * u * (3 - 2 * u)
    v = v * v * (3 - 2 * v)
    return ((1 - u) * n[iy, ix] + u * n[iy, ix + 1]) * (1 - v) + (
        (1 - u) * n[iy + 1, ix] + u * n[iy + 1, ix + 1]
    ) * v


def tex(name, base, delta):
    a = np.clip(
        np.array(base) + np.asarray(delta)[:, :, None] * np.array([1, 0.85, 0.64]), 0, 255
    ).astype("uint8")
    image = Image.fromarray(a)
    size = 192 if name == "wood" else 96
    image.resize((size, size), Image.Resampling.LANCZOS).save(OUT / (name + ".png"))


sz = 256
yy, xx = np.mgrid[:sz, :sz]
x = xx / sz
y = yy / sz
warp = periodic_noise(sz, (3, 8), 93) * 0.8 + np.sin(x * 2 * math.pi) * 0.5
grain = np.sin(y * 2 * math.pi * 48 + warp * 4.8 + 1.2 * np.sin(y * 2 * math.pi * 9))
n = (
    periodic_noise(sz, (5, 32), 4) * 15
    + periodic_noise(sz, (52, 107), 5) * 5
    + periodic_noise(sz, (5, 18), 80) * 14
)
tex(
    "wood",
    (139, 98, 66),
    n * 0.72
    + 12 * grain
    - 12 * np.maximum(grain - 0.54, 0) ** 0.25
    + 3 * np.sin(2 * math.pi * (y * 6 + np.sin(x * 2 * math.pi) * 0.13)),
)


def rough_tex(name, base, coarse=14, fine=6):
    tex(
        name,
        base,
        periodic_noise(sz, (9, 9), 24) * coarse
        + periodic_noise(sz, (71, 59), 53) * fine
        + periodic_noise(sz, (119, 130), 66) * fine * 0.6,
    )


rough_tex("earth", (105, 93, 71), 19, 8)
rough_tex("oxide", (139, 139, 131), 20, 9)
rough_tex("clay", (151, 115, 76), 10, 5)
rough_tex("quill", (179, 166, 134), 7, 4)
rough_tex("potblack", (38, 40, 40), 5, 3)
rough_tex("washwater", (66, 80, 75), 13, 3)
rough_tex("iron", (90, 83, 72), 13, 6)
rough_tex("brass", (159, 108, 60), 12, 6)
tex(
    "linen",
    (156, 148, 124),
    periodic_noise(sz, (9, 14), 721) * 12
    + (np.cos(x * 2 * math.pi * 64) * np.cos(y * 2 * math.pi * 64)) * 8
    + 4 * np.sin(y * 2 * math.pi * 16),
)
# Each material shares its texture across the whole composition. Colors modulate baked surface wear.
mats = {
    k: {"tex": k, "rough": v[0], "metal": v[1]}
    for k, v in {
        "wood": (0.84, 0),
        "earth": (0.99, 0),
        "oxide": (0.53, 0.62),
        "clay": (0.52, 0),
        "quill": (0.85, 0),
        "iron": (0.67, 0.52),
        "brass": (0.46, 0.62),
        "linen": (0.95, 0),
        "potblack": (0.21, 0),
    }.items()
}
mats.update(
    {
        "water": {"tex": "washwater", "rough": 0.28, "metal": 0.15},
        "wet": {"color": [0.28, 0.33, 0.31], "rough": 0.18, "metal": 0.25},
        "cord": {"color": [0.63, 0.18, 0.103], "rough": 0.92},
        "ember": {"color": [1, 0.62, 0.16], "emit": [1, 0.50, 0.09], "rough": 1},
        "heart": {"color": [1, 0.88, 0.48], "emit": [1, 0.83, 0.32], "rough": 1},
        "mark": {"color": [0.124, 0.114, 0.093], "rough": 0.86},
    }
)


def reset():
    global scene
    scene = defaultdict(lambda: {"v": [], "n": [], "uv": [], "c": [], "ix": []})


def vec(a):
    return [round(float(v), 7) for v in a]


def mesh(mat, vs, faces, uv=None, cols=None, smooth=False):
    vs = np.asarray(vs)
    n = len(vs)
    faces = np.asarray(faces)
    fn = np.cross(vs[faces[:, 1]] - vs[faces[:, 0]], vs[faces[:, 2]] - vs[faces[:, 0]])
    norms = np.linalg.norm(fn, axis=1)
    valid = norms > 1e-12
    faces = faces[valid]
    fn = fn[valid] / norms[valid, None]
    if uv is None:
        uv = vs[:, [0, 2]] * 6.4
    if cols is None:
        cols = [(1, 1, 1)] * n
    if smooth:
        norm = np.zeros_like(vs, dtype=float)
        for t, f in zip(faces, fn):
            norm[t] += f
        norm /= np.maximum(np.linalg.norm(norm, axis=1)[:, None], 1e-9)
    s = scene[mat]
    if smooth:
        k = len(s["v"])
        s["v"].extend(map(vec, vs))
        s["n"].extend(map(vec, norm))
        s["uv"].extend(map(vec, uv))
        s["c"].extend(map(vec, cols))
        s["ix"].extend((faces[:, [0, 2, 1]] + k).flatten().tolist())
    else:
        for tri, normal in zip(faces, fn):
            k = len(s["v"])
            for j in tri:
                s["v"].append(vec(vs[j]))
                s["n"].append(vec(normal))
                s["uv"].append(vec(uv[j]))
                s["c"].append(vec(cols[j]))
            s["ix"].extend([k, k + 2, k + 1])


def quads(rows, cols, wrap=False):
    a = []
    for r in range(rows - 1):
        for c in range(cols if wrap else cols - 1):
            a0 = r * cols + c
            b0 = r * cols + (c + 1) % cols
            a.extend([(a0, a0 + cols, b0), (b0, a0 + cols, b0 + cols)])
    return a


def lathe(mat, ctr, profile, col=(1, 1, 1), N=48, variation=0.0, oval=1, smooth=True, swirl=0.0):
    # Profile traces the outside upward, then back through the hollow to the base.
    vs = []
    cs = []
    uv = []
    ctr = V(ctr)
    for j, (rr, h) in enumerate(profile):
        for i in range(N):
            a = 2 * math.pi * i / N
            r = rr * (1 + variation * (math.sin(a * 3 + 0.2) + math.cos(a * 7 + 1) * 0.6))
            dx = swirl * (j / max(1, len(profile) - 1)) ** 1.7
            vs.append(ctr + V((r * math.cos(a) + dx, h, r * math.sin(a) * oval)))
            k = 0.965 + 0.035 * math.cos(i * 1.38 + j * 0.17)
            cs.append(V(col) * k)
            uv.append((a / (2 * math.pi) * 2, h * 10 + 0.4))
    f = quads(len(profile), N, True)
    # Winding of increasing theta in XZ + rising Y makes outward xz normal.
    mesh(mat, vs, f, uv, cs, smooth)


def tube(mat, path, radii, col=(1, 1, 1), N=7):
    path = [V(p) for p in path]
    rr = radii if isinstance(radii, (list, tuple, np.ndarray)) else [radii] * len(path)
    vs = []
    uv = []
    cols = []
    u0 = None
    through = 0
    for j, p in enumerate(path):
        axis = unit(path[min(j + 1, len(path) - 1)] - path[max(j - 1, 0)])
        if u0 is None:
            u0 = unit(np.cross(axis, (0, 1, 0) if abs(axis[1]) < 0.9 else (1, 0, 0)))
        u0 = unit(u0 - axis * np.dot(u0, axis))
        v = np.cross(u0, axis)
        if j:
            through += np.linalg.norm(path[j] - path[j - 1])
        for i in range(N):
            a = 2 * math.pi * i / N
            vs.append(p + rr[j] * (u0 * math.cos(a) + v * math.sin(a)))
            uv.append((through * 5, i / N))
            cols.append(col)
    mesh(mat, vs, quads(len(path), N, True), uv, cols, True)


def curved(mat, coords, rad, col=(1, 1, 1), loops=7):
    tube(mat, coords, rad, col, loops)


def pin(mat, a, b, rad, col=(1, 1, 1), N=9):
    p = V(a)
    d = V(b) - p
    tube(mat, [p, p + d * 0.08, p + d * 0.91, p + d], [rad * 0.77, rad, rad, rad * 0.68], col, N)


def bevel_board(mat, ctr, size, angle=0, col=(1, 1, 1), chip=0.0015, longx=True):
    # Hand-hewn plank with chamfered edges and corners; horizontal surfaces retain uninterrupted grain.
    sx, sy, sz = V(size) * 0.5
    ring = [
        [-sx + chip, -sz],
        [-sx, -sz + chip],
        [-sx, sz - chip],
        [-sx + chip, sz],
        [sx - chip, sz],
        [sx, sz - chip],
        [sx, -sz + chip],
        [sx - chip, -sz],
    ]
    vs = []
    uv = []
    cs = []
    rings = [(-sy, 0.96, 0.91), (-sy + chip, 1, 1), (sy - chip, 1, 1), (sy, 0.976, 0.971)]
    O = rng.uniform(0.1, 4)
    for j, (h, fx, fz) in enumerate(rings):
        for i, (a, b) in enumerate(ring):
            px = a * fx
            pz = b * fz
            rot = (
                px * math.cos(angle) + pz * math.sin(angle),
                h,
                -px * math.sin(angle) + pz * math.cos(angle),
            )
            vs.append(V(ctr) + rot)
            u, v = (px, pz) if longx else (pz, px)
            uv.append((u * 3 + O, v * 9 + h * 2 + 0.3))
            cs.append(V(col) * ([0.66, 0.77, 0.87, 1][j]))
    faces = []
    n = 8
    for j in range(3):
        for i in range(n):
            a = j * n + i
            b = j * n + (i + 1) % n
            faces.extend([(a, b, a + n), (b, b + n, a + n)])
    for i in range(1, 7):
        faces.extend([(24, 24 + i, 25 + i), (0, i + 1, i)])
    mesh(mat, vs, faces, uv, cs)


def patch(mat, c, rx, rz, col=(1, 1, 1), N=10, rot=0):
    a0 = rng.random() * 2
    vs = [V(c)]
    cols = [col]
    for i in range(N):
        a = 2 * math.pi * i / N
        k = 1 + 0.092 * math.sin(a * 3 + a0) + 0.08 * math.sin(a * 5 + 0.5)
        x = rx * math.cos(a) * k
        z = rz * math.sin(a) * k
        vs.append(
            V(c) + (x * math.cos(rot) + z * math.sin(rot), 0, -x * math.sin(rot) + z * math.cos(rot))
        )
        cols.append(col)
    mesh(mat, vs, [(0, 1 + (i + 1) % N, 1 + i) for i in range(N)], cols=cols)


def save(name):
    (OUT / (name + ".json")).write_text(
        json.dumps({"mats": mats, "surfaces": scene}, separators=(",", ":"))
    )


def wheel():
    center = V((-0.160, 0.151, -0.114))
    a = np.arange(73) * 2 * np.pi / 72
    path = lambda radius, depth: [
        center + V((math.cos(t) * radius, math.sin(t) * radius, depth)) for t in a
    ]
    tube("wood", path(0.164, -0.008), 0.010, (0.71, 0.66, 0.56), 9)
    tube("iron", path(0.174, -0.007), 0.0039, (0.82, 0.79, 0.68), 8)
    for i in range(12):
        n = V((math.cos(i * math.pi / 6 + 0.12), math.sin(i * math.pi / 6 + 0.12), 0))
        pin("wood", center + n * 0.020, center + n * 0.162, 0.0055, (0.81, 0.76, 0.65), 7)
    pin("wood", center + (0, 0, -0.039), center + (0, 0, 0.020), 0.027, (0.74, 0.67, 0.59), 18)
    pin("iron", center + (0, 0, 0.021), center + (0, 0, 0.027), 0.015, (0.79, 0.75, 0.67), 16)
    bevel_board("wood", (-0.04, 0.183, -0.191), (0.62, 0.030, 0.044), 0.03, (0.59, 0.55, 0.53))
    bevel_board("wood", (0.08, 0.144, -0.224), (0.64, 0.044, 0.033), -0.02, (0.68, 0.61, 0.54))


def open_ink_pot():
    c = V((0.080, 0.0001, -0.045))
    n = 46
    lathe(
        "clay",
        c,
        [
            (0.009, 0),
            (0.022, 0),
            (0.025, 0.002),
            (0.028, 0.011),
            (0.030, 0.026),
            (0.028, 0.042),
            (0.023, 0.047),
            (0.023, 0.052),
            (0.026, 0.0525),
            (0.026, 0.055),
            (0.024, 0.057),
            (0.0208, 0.056),
            (0.020, 0.052),
            (0.019, 0.044),
        ],
        (0.88, 0.88, 0.79),
        N=n,
        variation=0.012,
    )
    lathe(
        "potblack",
        c,
        [
            (0.025, 0.054),
            (0.026, 0.055),
            (0.025, 0.0566),
            (0.0237, 0.0575),
            (0.022, 0.0566),
            (0.0208, 0.054),
        ],
        (0.8, 0.83, 0.79),
        N=n,
        variation=0.012,
    )
    lathe(
        "potblack",
        c,
        [(0.021, 0.050), (0.0193, 0.0485), (0.014, 0.048), (0.00008, 0.048)],
        (0.48, 0.50, 0.5),
        N=n,
    )
    for aa, length, width in [
        (0.84, 0.018, 0.0032),
        (1.66, 0.0082, 0.002),
        (2.23, 0.013, 0.0022),
        (-0.6, 0.008, 0.0014),
        (-0.19, 0.025, 0.0026),
    ]:
        cs = []
        rs = []
        for i in range(13):
            t = i / 12
            hh = 0.055 - length * t
            rad = np.interp(
                hh,
                [0.023, 0.030, 0.042, 0.047, 0.050, 0.052, 0.054, 0.055],
                [0.0302, 0.030, 0.028, 0.0235, 0.0235, 0.025, 0.026, 0.026],
            )
            aa0 = aa + 0.033 * math.sin(i * 0.32)
            cs.append(c + (math.cos(aa0) * rad, hh, math.sin(aa0) * rad))
            rs.append(width * (1 - 0.64 * t))
        tube("potblack", cs, rs, (0.72, 0.75, 0.75), 7)
    for j in range(4):
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0.007, 0.016)
        patch(
            "potblack",
            c + (math.sin(a) * rr, 0.0486, math.cos(a) * rr),
            0.0015,
            0.0011,
            (1.15, 1.17, 1.14),
        )


def feather():
    # Split vanes gather toward the tip around a visible curved rachis.
    origin = V((-0.055, 0.0015, -0.048))
    direction = unit((-0.85, 0, 0.51))
    lateral = unit(np.cross((0, 1, 0), direction))
    fn = lambda t: (
        origin
        + direction * 0.090 * t
        + lateral * 0.006 * math.sin(math.pi * t)
        + (0, 0.003 + 0.006 * math.sin(t * math.pi * 0.85), 0)
    )
    shaft = [fn(t) for t in np.linspace(0, 1, 21)]
    tube("quill", shaft, np.linspace(0.0013, 0.00020, 21), (0.96, 0.88, 0.65), 7)
    # Each vane is a continuous, cambered sheet. Short notches break the edge
    # where groups of barbs have worked loose from the child's feather.
    for side in (-1, 1):
        verts = []
        texuv = []
        cols = []
        faces = []
        intervals = 60
        for i in range(intervals + 1):
            t = 0.15 + i / intervals * 0.835
            width = 0.0135 * math.sin((t - 0.13) / 0.87 * math.pi) ** 0.74 * (1 if side > 0 else 0.75)
            for notch in [0.39, 0.43, 0.66, 0.87] if side < 0 else [0.48, 0.58, 0.81]:
                width *= 1 - 0.48 * math.exp(-(((t - notch) / 0.013) ** 2))
            edge = fn(min(1, t + 0.035 * (1 - t))) + lateral * width * side + V((0, -width * 0.20, 0))
            ridge = fn(t) + lateral * 0.0006 * side
            midpoint = 0.55 * ridge + 0.45 * edge + V((0, 0.0011, 0))
            value = 0.89 - 0.17 * (0.5 + 0.5 * math.cos(t * math.pi * 12)) ** 5
            for j, v in enumerate([ridge, midpoint, edge]):
                verts.append(v)
                texuv.append((t, j * 0.29))
                c = value * (0.80 if j == 0 else 1.0)
                cols.append((c, c * 0.93, c * 0.85))
            if i:
                for j in range(2):
                    a = (i - 1) * 3 + j
                    b = a + 1
                    for tri in [(a, b, a + 3), (b, b + 3, a + 3)]:
                        aa, bb, cc = [V(verts[k]) for k in tri]
                        faces.append(
                            tri if np.cross(bb - aa, cc - aa)[1] > 0 else (tri[0], tri[2], tri[1])
                        )
        mesh("quill", verts, faces, texuv, cols, True)
    tube(
        "quill",
        [fn(t) + V((0, 0.00055, 0)) for t in np.linspace(0.14, 1, 20)],
        np.linspace(0.00064, 0.00012, 20),
        (0.99, 1.02, 0.84),
        6,
    )


def yard():
    reset()
    wheel()
    bevel_board("earth", (0, -0.041, 0), (0.80, 0.035, 0.62), 0, (1, 1, 1))
    for x, z, diam in [
        (-0.100, 0.07, 0.012),
        (0.187, 0.048, 0.015),
        (-0.103, -0.097, 0.008),
        (0.181, -0.105, 0.009),
    ]:
        lathe(
            "earth",
            (x, -0.0237, z),
            [(diam, 0), (diam * 0.64, diam * 0.3), (diam * 0.15, diam * 0.46)],
            (0.73, 0.71, 0.66),
            10,
            variation=0.07,
        )
    for i in range(43):
        x = rng.uniform(-0.26, 0.24)
        z = rng.uniform(-0.21, 0.15)
        if abs(x) < 0.150 and abs(z) < 0.083:
            continue
        rad = rng.uniform(0.0012, 0.0052)
        patch("earth", (x, -0.0234, z), rad, rad * 0.55, (0.82, 0.77, 0.68))
    bevel_board("wood", (0, -0.011, 0), (0.300, 0.022, 0.157), -0.035, (1.02, 0.98, 0.85), 0.004)
    # A weather-worn scrap beneath the wagon with a split at its outer edge.
    for x, z in [(-0.135, -0.061), (-0.135, 0.052), (0.133, -0.055)]:
        patch("iron", (x, 0.00015, z), 0.0028, 0.0022, (0.84, 0.79, 0.70))
    for start, zz in [(-0.145, 0.019), (0.147, 0.042)]:
        d = -1 if start > 0 else 1
        curved(
            "mark",
            [
                (start, 0.0001, zz),
                (start + d * 0.025, 0.0001, zz - 0.0021),
                (start + d * 0.041, 0.0002, zz - 0.0019),
            ],
            [0.00045, 0.00030, 0.00008],
            (0.56, 0.50, 0.44),
            4,
        )
    open_ink_pot()
    for x, z, s in [
        (0.052, -0.017, 0.0071),
        (0.056, -0.010, 0.0032),
        (0.048, -0.009, 0.0016),
        (0.104, 0.002, 0.0028),
        (0.106, -0.008, 0.0012),
        (0.039, -0.014, 0.0011),
    ]:
        patch("potblack", (x, 0.00021, z), s, s * rng.uniform(0.44, 0.84), (0.55, 0.57, 0.56), 13, 0.31)
    # Slender improvised brush, bent ferrule of wound thread, three individual hair tips.
    start = V((0.037, 0.0037, 0.002))
    end = V((0.123, 0.006, 0.052))
    axis = unit(end - start)
    p = [
        start + (end - start) * t + (0, 0.0014 * math.sin(t * math.pi), 0) for t in np.linspace(0, 1, 7)
    ]
    tube("wood", p, [0.0012, 0.0020, 0.00235, 0.0026, 0.0027, 0.0024, 0.0014], (0.76, 0.60, 0.44), 8)
    for t in [0.065, 0.085, 0.11, 0.135, 0.16]:
        pin(
            "linen",
            start + (end - start) * t,
            start + (end - start) * (t + 0.017),
            0.0022,
            (0.62, 0.62, 0.53),
            9,
        )
    for i in [-1, 0, 1]:
        curved(
            "potblack",
            [
                start - axis * 0.001 + (0.0005 * i, 0, 0),
                start - axis * 0.007 + (0.0006 * i, -0.0006, 0.0002 * i),
                start - axis * 0.016 + (0.0013 * i, -0.0028, 0.0003 * i),
            ],
            [0.00072, 0.00054, 0.00020],
            (0.46, 0.45, 0.41),
            6,
        )
    feather()
    save("yard")


def basin():
    reset()
    # Trestle, threaded-through cross-board and a cool pewter bowl.
    for j in range(6):
        bevel_board(
            "wood",
            (0.015, -0.099, (j - 2.5) * 0.094),
            (0.75, 0.033, 0.093),
            0,
            (0.66 + (0.05 if j % 2 else 0), 0.68, 0.70),
            0.0025,
        )
    c = V((0.028, -0.081, -0.012))
    lathe(
        "oxide",
        c,
        [
            (0.045, 0),
            (0.066, 0.001),
            (0.073, 0.006),
            (0.080, 0.017),
            (0.098, 0.032),
            (0.116, 0.054),
            (0.128, 0.065),
            (0.132, 0.067),
            (0.134, 0.069),
            (0.134, 0.0715),
            (0.132, 0.073),
            (0.128, 0.073),
            (0.126, 0.071),
            (0.124, 0.067),
            (0.111, 0.050),
            (0.096, 0.033),
            (0.076, 0.018),
            (0.059, 0.012),
        ],
        (0.89, 0.99, 0.96),
        N=72,
        oval=0.85,
        variation=0.005,
    )
    lathe(
        "brass",
        c,
        [(0.130, 0.066), (0.1322, 0.0678), (0.1328, 0.069), (0.1326, 0.0701)],
        (0.90, 0.88, 0.65),
        N=72,
        oval=0.85,
        variation=0.005,
    )
    # Ink gathers in the cool washwater in faint, off-centre marbled streams.
    # Radial tessellation supplies an irregular meniscus and continuous UVs.
    vs = []
    uv = []
    cs = []
    N = 72
    for ring in range(13):
        rr = 0.110 * (1 - ring / 12) * 0.999 + 0.000002
        for j in range(N):
            t = j * math.pi * 2 / N
            x = rr * math.cos(t)
            z = rr * math.sin(t) * 0.85
            vs.append(c + (x, 0.0525 + 0.00035 * (rr / 0.11) ** 5, z))
            uv.append((x * 5 + 0.5, z * 6 + 0.5))
            u = x + 0.039
            v = z + 0.004
            theta = math.atan2(v, u)
            rad = math.hypot(u, v)
            streak = math.sin(180 * rad + 1.35 * math.sin(theta * 2) + theta)
            shade = 0.90 - 0.24 * max(streak, 0) ** 2 + 0.08 * math.cos(85 * z)
            cs.append((shade * 0.94, shade, shade * 0.99))
    mesh("water", vs, quads(13, N, True), uv, cs, True)
    # Light broken arcs of the basin wall and diluted ink, in the water surface.
    for cx, cz, r, lo, hi in [
        (0.069, -0.014, 0.029, -0.3, 1.83),
        (0.069, -0.014, 0.038, 0.08, 1.39),
        (-0.020, -0.026, 0.079, 2.95, 4.23),
        (0.051, 0.025, 0.019, 2.25, 4.56),
    ]:
        coords = [
            (cx + r * math.cos(a), -0.02785, cz + r * 0.7 * math.sin(a)) for a in np.linspace(lo, hi, 24)
        ]
        tube(
            "wet",
            coords,
            [0.00019 + 0.00009 * math.sin(i / 23 * math.pi) for i in range(24)],
            (0.87, 0.89, 0.88),
            5,
        )
    # Two riveted loop handles come from the rim itself.
    for side in [-1, 1]:
        ears = [
            c + (side * 0.128, 0.066, -0.018),
            c + (side * 0.143, 0.072, -0.021),
            c + (side * 0.150, 0.074, -0.012),
            c + (side * 0.1505, 0.074, 0.010),
            c + (side * 0.144, 0.072, 0.019),
            c + (side * 0.128, 0.066, 0.018),
        ]
        tube("oxide", ears, 0.0031, (0.80, 0.89, 0.84), 8)
    bevel_board(
        "wood", (0, -0.0045, -0.012), (0.086, 0.009, 0.255), -0.058, (0.77, 0.82, 0.80), 0.0019, False
    )
    # Damp board and the loose cord before Sella ties it.
    for xx, zz, rad in [(-0.032, 0.079, 0.009), (0.030, 0.059, 0.0077), (0.035, 0.050, 0.0038)]:
        patch("wood", (xx, 0.00019, zz), rad, rad * 0.73, (0.62, 0.53, 0.44))
    points = [
        (0.032, 0.0016, -0.056),
        (0.031, 0.0017, -0.046),
        (0.025, 0.0017, -0.039),
        (0.023, 0.0017, -0.028),
        (0.030, 0.0017, -0.021),
        (0.036, 0.0018, -0.024),
        (0.039, 0.0018, -0.032),
        (0.038, 0.0018, -0.039),
        (0.035, 0.0024, -0.041),
        (0.032, 0.0032, -0.037),
        (0.033, 0.0033, -0.028),
        (0.038, 0.0017, -0.010),
        (0.042, 0.0017, 0.005),
        (0.044, -0.0002, 0.008),
        (0.047, -0.006, 0.010),
        (0.052, -0.014, 0.017),
        (0.059, -0.020, 0.023),
        (0.065, -0.0225, 0.027),
    ]
    tube("cord", points, 0.00143, (1, 1, 1), 9)
    for end, forward in [(V(points[0]), V((0, 0, -1))), (V(points[-1]), unit((1, -0.15, 0.75)))]:
        for j in range(3):
            pn = end + np.array((j - 1, 0, j % 2)) * 0.00039
            tube(
                "cord",
                [
                    pn,
                    pn + forward * 0.003 + ((j - 1) * 0.00055, 0, 0),
                    pn + forward * 0.0048 + ((j - 1) * 0.001, 0, (j % 2 - 0.5) * 0.0006),
                ],
                [0.00045, 0.00036, 0.00016],
                (1, 0.85, 0.68),
                5,
            )
    # Oil reservoir, shoulder lugs, charred wick and leaning flame.
    lamp = V((-0.115, -0.0824, -0.071))
    lathe(
        "brass",
        lamp,
        [
            (0.012, 0),
            (0.030, 0.001),
            (0.034, 0.004),
            (0.033, 0.009),
            (0.025, 0.012),
            (0.021, 0.018),
            (0.024, 0.031),
            (0.033, 0.041),
            (0.035, 0.046),
            (0.034, 0.049),
            (0.029, 0.050),
            (0.025, 0.052),
            (0.019, 0.057),
            (0.012, 0.058),
            (0.012, 0.061),
            (0.010, 0.063),
            (0.006, 0.063),
        ],
        (0.87, 0.77, 0.63),
        N=44,
    )
    lathe(
        "brass",
        lamp,
        [(0.0095, 0.061), (0.012, 0.062), (0.012, 0.065), (0.010, 0.067), (0.006, 0.067)],
        (1.08, 1.02, 0.84),
        N=36,
    )
    h = []
    for a in np.linspace(-math.pi * 0.53, math.pi * 0.70, 32):
        h.append(lamp + (-0.029 - 0.016 * math.cos(a), 0.036 + 0.015 * math.sin(a), -0.0015))
    tube("brass", h, 0.00215, (0.81, 0.76, 0.60), 8)
    pin("potblack", lamp + (0, 0.064, 0), lamp + (0.001, 0.071, 0), 0.0020, (0.58, 0.46, 0.32))
    base = lamp + (0.0008, 0.0695, 0)
    lathe(
        "ember",
        base,
        [(0.001, 0), (0.004, 0.003), (0.0053, 0.008), (0.0037, 0.012), (0.0021, 0.017), (0.0002, 0.025)],
        (0.99, 0.79, 0.45),
        N=14,
        oval=0.80,
        swirl=0.007,
    )
    lathe(
        "heart",
        base + (0, 0.0003, 0.0018),
        [(0.0004, 0), (0.0029, 0.0022), (0.0026, 0.007), (0.0001, 0.013)],
        (1, 1, 1),
        N=12,
        oval=0.77,
        swirl=0.002,
    )
    # Boiled linen lies off the wet board; its turned edges reveal the hem.
    ctr = V((0.121, -0.080, 0.100))
    rows = 13
    cols = 19
    vs = []
    uv = []
    colour = []
    for j in range(rows):
        for i in range(cols):
            x = i / (cols - 1)
            z = j / (rows - 1)
            fold = (
                0.0045 * math.sin(math.pi * x * 4 + 0.45 * z) + 0.0024 * math.sin(z * 4.8 + x * 5.4)
            ) * (1 - 0.24 * z)
            vs.append(
                ctr
                + (
                    (x - 0.5) * 0.13 + 0.013 * (z - 0.5),
                    0.0061 + fold + (1 - z) * 0.0055,
                    (z - 0.5) * 0.072 + math.sin(x * 10) * 0.0017,
                )
            )
            uv.append((x * 2.3, z * 1.3))
            colour.append((0.88, 0.82, 0.69) if j in [1, 2] else (0.99, 0.97, 0.92))
    mesh("linen", vs, quads(rows, cols), uv, colour, True)
    for i in range(1, cols - 1):
        a = V(vs[(rows - 1) * cols + i])
        pin("linen", a, a + (0.0004, -0.002, 0.0024 + (i % 3) * 0.0007), 0.00024, (0.93, 0.88, 0.69), 4)
    save("basin")


def make_scene(name, eye, target, fov, seat_rot=0):
    sight = unit(V(eye) - V(target))
    pitch = -math.asin(sight[1])
    yaw = math.atan2(sight[0], sight[2])
    position = ", ".join(f"{v:.7f}" for v in eye)
    root_name = "WagonPaintBoard" if name == "yard" else "WashBasin"
    text = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="ArrayMesh" path="res://assets/narrative_props/prologue/{name}_scenery.res" id="1"]

[node name="{root_name}" type="Node3D"]

[node name="Scenery" type="MeshInstance3D" parent="."]
mesh = ExtResource("1")

[node name="TokenSeat" type="Marker3D" parent="."]
rotation = Vector3(0, {seat_rot}, 0)

[node name="Shot" type="Camera3D" parent="."]
position = Vector3({position})
rotation = Vector3({pitch:.8f}, {yaw:.8f}, 0)
near = 0.006
far = 3.0
fov = {fov}
"""
    if name == "basin":
        text += """
[node name="WickLight" type="OmniLight3D" parent="."]
position = Vector3(-0.111, 0.014, -0.069)
light_color = Color(1, 0.68, 0.34, 1)
light_energy = 0.068
omni_range = 0.25
omni_attenuation = 1.25
"""
    (ART / (name + ".tscn")).write_text(text, encoding="utf-8")


yard()
basin()
make_scene("yard", (0.067, 0.207, 0.206), (0.021, 0.0000, -0.0235), 30.5, -0.12)
make_scene("basin", (-0.034, 0.242, 0.121), (-0.012, -0.004, -0.010), 32, 0.08)

(OUT / "project.godot").write_text("config_version=5\\n", encoding="utf-8")
baker = Path(__file__).with_name("bake_workbench_mesh.gd")
subprocess.run(
    [
        args.godot,
        "--headless",
        "--audio-driver",
        "Dummy",
        "--path",
        str(OUT),
        "--script",
        str(baker),
        "--",
        str(OUT),
        str(ART),
    ],
    check=True,
)
temporary.cleanup()
