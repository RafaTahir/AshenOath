"""Build Tor's left splinted cuff on the retained C04 bind mesh (Blender 5.2).

blender -b -P author_brace.py -- C04_Blacksmith_Tor.glb TorLeftBrace.blend brace.glb
The final GLB is an intermediate for cook_brace.gd. The editable file keeps
the separated staves, grain, bindings and tucked tie. Input units are metres.
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np

source, blend, output = [Path(value).resolve() for value in sys.argv[sys.argv.index("--") + 1:]]
raw = source.read_bytes()
if hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() != "80e890cc7dcc8ff3cb6ffdfaadb7767c3e4995be":
    raise ValueError("Tor's retained bind mesh differs from the measured C04 asset at 7248219")
length = struct.unpack_from("<I", raw, 12)[0]
model = json.loads(raw[20:20 + length])
payload = raw[28 + length:]
skin = model["skins"][0]
joint_names = [model["nodes"][index]["name"] for index in skin["joints"]]
arm_id = joint_names.index("lowerarm_l")


def accessor(index):
    spec = model["accessors"][index]
    view = model["bufferViews"][spec["bufferView"]]
    dtype = np.dtype({5121:"u1", 5123:"<u2", 5125:"<u4", 5126:"<f4"}[spec["componentType"]])
    width = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}[spec["type"]]
    return np.ndarray((spec["count"], width), dtype, payload,
                      offset=spec.get("byteOffset", 0) + view.get("byteOffset", 0),
                      strides=(view.get("byteStride", width * dtype.itemsize), dtype.itemsize))


inverse_bind = accessor(skin["inverseBindMatrices"])[arm_id].reshape(4, 4).T
limb = [arm_id, joint_names.index("upperarm_l"), joint_names.index("hand_l")]
triangles = []
for primitive in model["meshes"][0]["primitives"]:
    attr = primitive["attributes"]
    positions = accessor(attr["POSITION"])
    local = positions @ inverse_bind[:3, :3].T + inverse_bind[:3, 3]
    weights = accessor(attr["WEIGHTS_0"])
    belongs = np.any(np.isin(accessor(attr["JOINTS_0"]), limb) & (weights > 0), axis=1)
    indices = accessor(primitive["indices"]).reshape(-1, 3)
    tri = local[indices[np.any(belongs[indices], axis=1)]]
    triangles.extend(tri[(np.min(tri[:, :, 1], axis=1) < .263) & (np.max(tri[:, :, 1], axis=1) > .100)])
triangles = np.asarray(triangles)

# Take a true mesh section at each station. The fitted cloth follows the radius
# of Tor's flesh and sleeve in each direction rather than an ideal cylinder.
stations = np.linspace(.102, .257, 32)
angles = np.linspace(0, 2 * math.pi, 49)
sections = []
for station in stations:
    segments = []
    for tri in triangles:
        crossing = []
        for a, b in zip(tri, np.roll(tri, -1, axis=0)):
            if (a[1] <= station) != (b[1] <= station):
                p = a + (b - a) * ((station - a[1]) / (b[1] - a[1]))
                crossing.append(p[[0, 2]])
        if len(crossing) == 2:
            segments.append(crossing)
    segments = np.asarray(segments)
    points = segments.reshape(-1, 2)
    centre = (points.max(axis=0) + points.min(axis=0)) * .5
    offsets = segments[:, 0] - centre
    sides = segments[:, 1] - segments[:, 0]
    radii = []
    for angle in angles:
        ray = np.array([math.cos(angle), math.sin(angle)])
        cross = ray[0] * sides[:, 1] - ray[1] * sides[:, 0]
        valid = np.abs(cross) > 1e-10
        distance = np.zeros(len(cross))
        fraction = np.zeros(len(cross))
        distance[valid] = (offsets[valid, 0] * sides[valid, 1] - offsets[valid, 1] * sides[valid, 0]) / cross[valid]
        fraction[valid] = (offsets[valid, 0] * ray[1] - offsets[valid, 1] * ray[0]) / cross[valid]
        hits = distance[valid & (fraction >= 0) & (fraction <= 1) & (distance > 0)]
        if not len(hits):
            raise ValueError(f"Open arm section at {station:.3f} m, {angle:.3f} rad")
        radii.append(float(max(hits)))
    sections.append((centre, radii))


def section(angle, y):
    """Interpolate the baked radial section along the left lower arm."""
    k = np.clip((y - stations[0]) / (stations[-1] - stations[0]) * (len(stations) - 1), 0, len(stations) - 1)
    i = int(k)
    t = k - i
    a, b = sections[i], sections[min(i + 1, len(sections) - 1)]
    theta = angle % (2 * math.pi)
    radius = (1 - t) * np.interp(theta, angles, a[1]) + t * np.interp(theta, angles, b[1])
    return a[0] * (1 - t) + b[0] * t, radius


def point(angle, y, extra):
    centre, radius = section(angle, y)
    return (centre[0] + math.cos(angle) * (radius + extra), y, centre[1] + math.sin(angle) * (radius + extra))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
MATERIAL = {}
for name, roughness in [("Crate end grain", .86), ("Unbleached linen", .94)]:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = roughness
    colour = material.node_tree.nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Pigment"
    material.node_tree.links.new(colour.outputs["Color"], shader.inputs["Base Color"])
    MATERIAL[name] = material


def solid_grid(name, material, rows, palette):
    """rows contain pairs of outer/inner vertices; close the four edges."""
    n, m = len(rows), len(rows[0])
    vertices, faces, shades = [], [], []
    for row in rows:
        for pair in row:
            for x, y, z in pair:
                vertices.append((x, -z, y))  # native Godot/glTF Y up to Blender Z up
    def idx(i, j, layer): return (i*m + j)*2 + layer
    def quad(corners, color):
        faces.append(tuple(idx(*v) for v in corners))
        shades.append(color)
    for i in range(n - 1):
        for j in range(m - 1):
            for layer in (0, 1):
                quad([(i,j,layer),(i+1,j,layer),(i+1,j+1,layer),(i,j+1,layer)], palette(i, j, layer))
    for i in range(n - 1):
        for j in (0, m-1):
            quad([(i,j,0),(i+1,j,0),(i+1,j,1),(i,j,1)], palette(i, j, 1))
    for j in range(m - 1):
        for i in (0, n-1):
            quad([(i,j,0),(i,j+1,0),(i,j+1,1),(i,j,1)], palette(i, j, 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(MATERIAL[material])
    paint = mesh.color_attributes.new(name="Pigment",type="BYTE_COLOR",domain="CORNER")
    for polygon, shade in zip(mesh.polygons, shades):
        for loop in polygon.loop_indices:
            paint.data[loop].color_srgb = (*shade,1)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def dye(rgb, value):
    return tuple(min(1, max(0, c * value)) for c in rgb)


def stave_y(side):
    return (.107, .248) if side == 0 else (.111, .254)


def stave_width(side, t):
    smooth_tip = min(1, .61 + 7 * min(t, 1 - t))
    return (.036 if side == 0 else .033) * (.99 - .16 * t) * smooth_tip


def stave_span(side, y):
    start, end = stave_y(side)
    a = (.10 if side == 0 else math.pi + .17)
    radius = section(a, y)[1]
    return a, stave_width(side, (y-start)/(end-start)) / (2*radius)


# Two sanded pieces of crate wood. Narrow bevels, radial crown, hand-softened
# corners and broken grain vary by stave. The fingers remain completely free.
for side, name in enumerate(["Palm-side stave", "Back-of-wrist stave"]):
    start, end = stave_y(side)
    rows = []
    for k in range(9):
        y = start + k*(end-start)/8
        angle, width = stave_span(side, y)
        row = []
        for u in [-1,-.84,-.3,.32,.85,1]:
            a = angle + width*u
            crown = .005 + .0016*(1-u*u) - .0018*(abs(u)>.93)
            row.append((point(a,y,crown+.0015),point(a,y,.0009)))
        rows.append(row)
    wood = (.53,.366,.22) if side == 0 else (.60,.443,.275)
    solid_grid(name, "Crate end grain", rows,
               lambda i,j,l: dye(wood,(.83 if l else 1) * (.91 + .07 * math.sin(j*11.3 + .2*math.sin(i*.7)))))
    for mark, offset in enumerate([-.56, .25, .63]):
        rows = []
        for k in range(6):
            t=k/5
            y=start+(end-start)*(.07+mark*.058+t*(.59-mark*.04))
            a,w=stave_span(side,y)
            drift=.025*math.sin(t*7+mark)
            x=offset+drift
            line=.013+.011*math.sin(t*math.pi)
            rows.append([(point(a+w*(x+u*line),y,.0092-.0016*x*x),point(a+w*(x+u*line),y,.0072-.0016*x*x)) for u in [-1,1]])
        solid_grid(name+" grain "+str(mark+1),"Crate end grain",rows,
                   lambda i,j,l: dye(wood,.65 if mark in [0,2] else 1.16))


def binding_standoff(angle,y):
    extra=.0025
    for side in range(2):
        start,end=stave_y(side)
        if start<=y<=end:
            a,w=stave_span(side,y)
            rel=abs(math.remainder(angle-a,2*math.pi))
            # Linen stretches across each raised stave, then draws to the arm.
            extra+=.0077*np.clip((w+.21-rel)/.21,0,1)
    return extra


for n, (middle, pitch, turns, width) in enumerate([
    (.128, .009, 1.70, .0105),(.174,-.012,1.95,.0115),(.222,.010,1.82,.0102)
]):
    rows = []
    for i in range(43):
        t=i/42
        a=.72 + 2*math.pi*t*turns
        forward=(t-.5)*pitch*turns
        lift=(.0014 if t>1/turns else 0)
        row=[]
        for j,across in enumerate([-.5,-.08,.5]):
            y=middle+forward+across*width+.0007*math.sin(a*3+n)
            extra=binding_standoff(a,y)+lift
            fold=[.0002,.00135,.0001][j]
            row.append((point(a,y,extra+.0018+fold),point(a,y,extra)))
        rows.append(row)
    linen=[(.74,.689,.572),(.66,.616,.522),(.79,.735,.61)][n]
    solid_grid(["Elbow binding","Cross binding","Wrist binding"][n],"Unbleached linen",rows,
               lambda i,j,l: dye(linen,(.79 if l else 1)*(.92+.055*math.sin(j*19.83)+.025*math.cos(i*.55+n))))

# A tucked, folded end on the outer face of the middle wrap. It lies against
# the cuff to avoid intersecting the right-hand hammer during work animation.
for n,(width,length) in enumerate([(.008,.028),(.0055,.017)]):
    rows=[]
    for i in range(7):
        t=i/6; a=math.pi*.65+.51*t+.11*n
        y=.174-.006*n-length*t
        row=[]
        for u in [-.5,0,.5]:
            aa=a+u*width/section(a,y)[1]*(1-.27*t)
            extra=binding_standoff(aa,y)+.002+.0035*math.sin(t*math.pi)+.0015*(u==0)
            row.append((point(aa,y,extra+.0013),point(aa,y,extra)))
        rows.append(row)
    solid_grid("Tucked linen end "+str(n+1),"Unbleached linen",rows,
               lambda i,j,l: dye((.76,.692,.56),(.82 if l else 1)*(.94 if j else 1)))

bpy.context.scene.unit_settings.system="METRIC"
blend.parent.mkdir(parents=True,exist_ok=True)
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.object.join()
bpy.context.active_object.name = "TorLeftBrace"
bpy.ops.export_scene.gltf(filepath=str(output),export_format="GLB",use_selection=True,
                          export_animations=False,export_texcoords=False,export_vertex_color="MATERIAL")
