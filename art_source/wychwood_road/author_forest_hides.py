"""Paint three skinned Wychwood hides in bind space and bake into their native UVs.

Run with Python, NumPy and Pillow. Inputs are the retained production GLBs.
The narrow painted areas follow the mesh through its existing animations.
"""
import argparse
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[2] / "outputs/AshenOathTheRoadBetweenCrowns"
CREATURES = GAME / "assets_external/design_pack_v1/creatures"
HIDES = {
    "M01": ("M01_PeatSkin", "M01_ghoulkin_peat_albedo.png"),
    "M19": ("M19_OliveGreyHide", "M19_raider_woad_albedo.png"),
    "M20": ("M20_CharcoalOliveHide", "M20_brute_scar_albedo.png"),
}
SIZE = 768


def read_surface(path, material):
    blob = path.read_bytes()
    json_length = struct.unpack_from("<I", blob, 12)[0]
    doc = json.loads(blob[20:20 + json_length])
    data = blob[28 + json_length:]

    def accessor(index):
        item = doc["accessors"][index]
        view = doc["bufferViews"][item["bufferView"]]
        dtype = np.dtype({5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[item["componentType"]])
        count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[item["type"]]
        return np.ndarray((item["count"], count), dtype=dtype, buffer=data,
                          offset=view.get("byteOffset", 0) + item.get("byteOffset", 0),
                          strides=(view.get("byteStride", count * dtype.itemsize), dtype.itemsize))

    surface, = [part for mesh in doc["meshes"] for part in mesh["primitives"]
                if doc["materials"][part["material"]]["name"] == material]
    attrs = surface["attributes"]
    pos = accessor(attrs["POSITION"])
    return (pos / pos[:, 1].max(), accessor(attrs["NORMAL"]),
            accessor(attrs["TEXCOORD_0"]), accessor(surface["indices"]).reshape(-1, 3))


def rasterize(pos, norm, uv, triangles):
    # Wrap only at the final pixel address. Interpolating already-wrapped UVs
    # would stretch triangles crossing the repeat boundary over the whole hide.
    surface = np.zeros((SIZE, SIZE, 6), np.float32)
    coverage = np.zeros((SIZE, SIZE), bool)
    values = np.column_stack((pos, norm))
    for face in triangles:
        a, b, c = uv[face].astype(np.float64) * SIZE - 0.5
        ab, ac = b - a, c - a
        det = ab[0] * ac[1] - ac[0] * ab[1]
        if abs(det) < 1.e-7:
            continue
        lo = np.ceil(np.minimum(np.minimum(a, b), c)).astype(int)
        hi = np.floor(np.maximum(np.maximum(a, b), c)).astype(int)
        if np.any(lo > hi):
            continue
        yy, xx = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
        dx, dy = xx - a[0], yy - a[1]
        u = (dx * ac[1] - dy * ac[0]) / det
        v = (ab[0] * dy - ab[1] * dx) / det
        inside = (u >= -1.e-7) & (v >= -1.e-7) & (u + v <= 1.0000001)
        u, v = u[inside, None], v[inside, None]
        x, y = xx[inside] % SIZE, yy[inside] % SIZE
        surface[y, x] = values[face[0]] * (1 - u - v) + values[face[1]] * u + values[face[2]] * v
        coverage[y, x] = True
    if coverage.sum() < SIZE * SIZE // 4:
        raise ValueError("Unexpectedly sparse native skin UVs")
    return surface[coverage], coverage


def smooth(lo, hi, v):
    t = np.clip((v - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def band(v, center, width):
    return np.exp(-((v - center) / width) ** 2)


def noise(x, y, z):
    """Continuous repeatable value noise in rest-position space."""
    grid = np.floor(np.stack((x, y, z), axis=0)).astype(np.int64)
    f = np.stack((x, y, z), axis=0) - grid
    f = f * f * (3 - 2 * f)
    out = np.zeros_like(x)
    for i in range(2):
        for j in range(2):
            for k in range(2):
                n = ((grid[0] + i) * 73856093) ^ ((grid[1] + j) * 19349663) ^ ((grid[2] + k) * 83492791)
                n = (n ^ (n >> 13)) * 1274126177
                sample = ((n ^ (n >> 16)) & 65535) / 65535.0
                out += sample * (f[0] if i else 1-f[0]) * (f[1] if j else 1-f[1]) * (f[2] if k else 1-f[2])
    return out


def glaze(rgb, color, amount):
    return rgb + (np.asarray(color) - rgb) * np.clip(amount, 0, 1)[:, None]


def line(x, y, points, width):
    nearest = np.full_like(x, 100.0)
    for a, b in zip(points, points[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = np.clip(((x - a[0]) * dx + (y - a[1]) * dy) / (dx*dx + dy*dy), 0, 1)
        nearest = np.minimum(nearest, np.hypot(x-a[0]-t*dx, y-a[1]-t*dy))
    return 1 - smooth(width * 0.34, width, nearest)


def paint(identity, sample):
    x, y, z, nx, ny, nz = sample.T
    ax = np.abs(x)
    coarse = noise(x*13+3, y*13, z*13+5)
    grain = noise(x*56, y*56+9, z*56)
    pores = noise(x*194, y*194, z*194+4)
    wander = (coarse - 0.5) * 0.014 + (grain - 0.5) * 0.003
    front = smooth(-0.24, 0.55, nz)
    head = smooth(0.895, 0.931, y) * (1-smooth(0.064, 0.085, ax))
    torso = (1-smooth(0.099, 0.163, ax)) * smooth(0.545, 0.63, y) * (1-smooth(0.888, 0.922, y))
    forearm = smooth(0.28, 0.45, ax)
    ends = np.maximum(smooth(0.34, 0.55, ax), 1-smooth(0.04, 0.22, y))
    chest = torso * front
    hip = band(y, 0.56, 0.10)
    muscle = (np.cos((ax*1.8-y+z*1.3+0.014*coarse)*146) * 0.5 + 0.5) ** 5
    eye = np.exp(-((ax-0.027)/0.018)**2 - ((y-0.953-wander*0.16)/0.014)**2) * front
    cheek = np.exp(-((ax-0.029)/0.025)**2 - ((y-0.933)/0.014)**2) * front
    collar = band(y, 0.853-ax*0.15+wander*0.25, 0.011) * chest
    ribphase = (y - ax*0.36 + ax**2*3.0 + wander*0.27) * 40.0
    ribs = (0.5 + 0.5*np.cos(ribphase*2*np.pi))**3
    ribs *= chest * smooth(0.006, 0.036, ax) * band(y, 0.761, 0.064)
    field = np.empty((len(x), 3), float)
    if identity == "M01":
        # The Ghoulkin has a parchment-colored rib cage, congested sockets
        # and peat-stained extremities. Violet pools break up the warm flesh.
        field[:] = (138, 108, 79)
        field = glaze(field, (82, 52, 69), 0.78*smooth(0.35, 0.78, coarse) + 0.42*hip)
        field = glaze(field, (209, 181, 128), 0.68*chest + 0.53*head + 0.19*smooth(0.5, 0.85, grain))
        field = glaze(field, (76, 39, 53), 0.94*eye + 0.48*cheek + 0.37*forearm)
        field = glaze(field, (54, 49, 48), ends*0.89)
        field = glaze(field, (221, 192, 141), 0.72*ribs + 0.64*collar)
        # Thin interrupted vessels branch over the inner arms and upper legs.
        vessel = (1-smooth(0.014, 0.115, np.abs(np.sin((x*1.7+y+0.046*coarse+0.011*grain)*116))))
        field = glaze(field, (117, 65, 73), vessel*(0.15+0.32*grain)*(1-ends)*front)
    elif identity == "M19":
        # Indigo woad is laid on by hand. Its diagonal goes from one shoulder
        # to the opposite ribs and reappears on the signal hand and cheek.
        field[:] = (152, 99, 63)
        field = glaze(field, (87, 62, 59), 0.62*smooth(0.3, 0.8, coarse) + 0.36*hip)
        field = glaze(field, (198, 150, 102), 0.48*chest+0.43*head+0.23*collar+0.15*ribs)
        field = glaze(field, (63, 46, 40), ends*0.82 + eye*0.85)
        diagonal = x - (y-0.754)*1.23 + wander
        panel = (1-smooth(0.028, 0.038, np.abs(diagonal))) * chest
        piping = band(np.abs(diagonal), 0.046, 0.0043) * chest
        sleeve = band(ax, 0.199 + wander, 0.043) * smooth(0.0, 0.12, x)
        hand = band(x, 0.405 + 0.20*(z+0.044) + wander*0.3, 0.034)
        face = band(x+(y-0.948)*0.46, 0.022+wander*0.2, 0.012) * head * front
        paint_mask = np.maximum.reduce((panel, sleeve, hand, face))
        pigment = 0.84 + 0.14*grain - 0.28*smooth(0.66, 0.86, pores)
        field = glaze(field, (38, 86, 99), pigment * paint_mask)
        field = glaze(field, (198, 166, 101), piping*0.91)
        stroke = (1-smooth(0.10, 0.28, abs(np.sin((y+0.24*x+wander*0.3)*243))))
        field = glaze(field, (126, 160, 147), stroke*paint_mask*0.52)
    else:
        # A cold shale mantle, oxidized margins and healed antler-shaped
        # fissures make the Brute readable on the shaded side of the ford.
        field[:] = (105, 114, 113)
        islands = smooth(0.31, 0.75, coarse + (grain-0.5)*0.42)
        field = glaze(field, (66, 62, 73), 0.83*islands)
        mantle = smooth(0.74, 0.89, y+np.minimum(ax,0.28)*0.20) * (1-smooth(0.25, 0.36, ax))
        field = glaze(field, (154, 150, 133), mantle*(0.39+0.42*grain) + (0.27*ribs+0.48*collar))
        field = glaze(field, (77, 50, 48), 0.68*ends + 0.79*eye)
        field = glaze(field, (167, 106, 71), cheek*0.85 + 0.28*band(ax,0.32,0.09)*grain)
        crack_path = [(0.135,0.86),(0.094,0.832),(0.067,0.802),(0.036,0.79),(-0.012,0.744),(-0.04,0.70)]
        split = [(0.067,0.802),(0.065,0.776),(0.075,0.75),(0.072,0.726)]
        face_path = [(-0.04,0.977),(-0.028,0.964),(-0.013,0.957),(0.008,0.94)]
        def fissure(width):
            return np.maximum.reduce([line(x+wander*0.4, y, pts, width) for pts in (crack_path,split,face_path)]) * front
        field = glaze(field, (93, 48, 41), fissure(0.013)*0.91)
        field = glaze(field, (215, 164, 111), fissure(0.0055)*0.94)
        mottling = smooth(0.55, 0.76, grain+(coarse-0.5)*0.5) * mantle
        field = glaze(field, (161, 149, 100), mottling*0.43)
    # Pores, directional fibres, and the underside of folds retain value
    # variation at both portrait and encounter distance. No scene light baked.
    field += ((coarse-0.5)*30 + (grain-0.5)*25 + (pores-0.5)*13 + (muscle-0.24)*8)[:, None]
    return np.uint8(np.clip(field, 12, 236))


def bake(identity, material, name, output):
    positions, coverage = rasterize(*read_surface(next(CREATURES.glob(identity + "_*.glb")), material))
    rgb = np.zeros((SIZE,SIZE,3), np.uint8)
    rgb[coverage] = paint(identity, positions)
    # Bleed island edges into the gutter for bilinear sampling and mipmaps.
    valid = coverage.copy()
    for _ in range(9):
        total = np.zeros_like(rgb, dtype=np.uint16)
        count = np.zeros_like(valid, dtype=np.uint8)
        for dy, dx in ((-1,0), (1,0), (0,-1), (0,1)):
            neighbors = np.roll(valid, (dy,dx), (0,1))
            total += np.roll(rgb, (dy,dx), (0,1)) * neighbors[...,None]
            count += neighbors
        edge = ~valid & (count > 0)
        rgb[edge] = total[edge] // count[edge,None]
        valid |= edge
    rgb[~valid] = np.median(rgb[coverage],axis=0).astype(np.uint8)
    output.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgb).save(output / name, optimize=True)
    print(identity, int(coverage.sum()), name, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=CREATURES / "textures")
    args = parser.parse_args()
    for identity, (material, name) in HIDES.items():
        bake(identity, material, name, args.output)
