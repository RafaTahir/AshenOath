"""Build Harl's cart bell and removable cemetery fittings in Blender 5.2.

blender --background --factory-startup --python author_bell.py
The optional argument following -- selects a different runtime output folder.
One Blender unit is one metre. Z is up, the filed area faces -Y.
"""
from math import cos, sin, pi
from pathlib import Path
import sys

import bpy
from mathutils import Vector

source_dir = Path(__file__).resolve().parent
project = source_dir.parents[2] / "outputs" / "AshenOathTheRoadBetweenCrowns"
runtime = project / "assets/narrative_props/bell"
if "--" in sys.argv:
    runtime = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
runtime.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def finish(name, rgb, metal, rough):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    mat.diffuse_color = (*rgb, 1)
    return mat


# The original bell clasp supplies the project's forged iron finish.
iron = finish("Forged iron", (0.13, 0.15, 0.16), 0.70, 0.55)
# Bake a small seamless iron/oxide wash. Its variation crosses face boundaries.
from random import Random
rng = Random(184)
aged_iron = finish("Cart iron • thumb-worn patina", (1, 1, 1), 0.64, 0.63)
patina = bpy.data.images.new("Harl — rubbed and oxidized iron", width=256, height=128, alpha=False)
pixels = []
for v in range(128):
    h = v / 127
    for u in range(256):
        a = 2 * pi * u / 256
        grain = rng.uniform(-.04, .04)
        deposit = max(0.0, min(1.0, .43 + .23*sin(3*a + 5*h)
                      + .19*sin(6*a - 15*h + sin(2*a)) + .12*cos(14*a + 41*h) + grain))
        base = (.132, .145, .141)
        rust = (.132, .067, .034)
        polish = max(0.0, 1.0 - abs(h-.15)*12.0) * max(0.0, cos(a+1.6)) * .033
        pixels.extend([base[k]*(1-deposit) + rust[k]*deposit + grain*.17 + polish for k in range(3)] + [1.0])
patina.pixels.foreach_set(pixels)
patina.pack()
tex = aged_iron.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = patina
aged_iron.node_tree.links.new(tex.outputs["Color"], aged_iron.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
rubbed = finish("Iron • polished by handling", (0.25, 0.222, 0.184), 0.71, 0.40)
inside = finish("Cart bell • sheltered inside", (0.071, 0.078, 0.077), 0.57, 0.68)
filed = finish("Nearly erased file cuts", (0.078, 0.075, 0.067), 0.47, 0.68)
wool = finish("Mira’s waxed wool", (0.27, 0.234, 0.166), 0.0, 0.80)
wax = finish("Beeswax", (0.47, 0.347, 0.188), 0.0, 0.49)

bell = collection("Harl — empty cart bell")
striker_group = collection("Tor — temporary striker")
wrap_group = collection("Mira — waxed hand grip")
residue = collection("Elna — wax left after return")


def mesh_object(group, name, vertices, faces, mats, face_mats=None, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    for mat in mats:
        data.materials.append(mat)
    for i, poly in enumerate(data.polygons):
        poly.use_smooth = smooth
        if face_mats:
            poly.material_index = face_mats[i]
    return obj


def tube(group, name, path, radius, material, sides=9):
    vertices, faces = [], []
    for i, center in enumerate(path):
        center = Vector(center)
        tangent = (Vector(path[min(i+1, len(path)-1)]) - Vector(path[max(i-1, 0)])).normalized()
        start = Vector((0, 1, 0)) if abs(tangent.y) < 0.90 else Vector((1, 0, 0))
        normal = tangent.cross(start).normalized()
        side = tangent.cross(normal)
        for j in range(sides):
            angle = 2*pi*j/sides
            vertices.append(center + radius*(cos(angle)*normal + sin(angle)*side))
        if i:
            for j in range(sides):
                a = (i-1)*sides+j
                b = (i-1)*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))), tuple(len(vertices)-sides+j for j in range(sides))]
    return mesh_object(group, name, vertices, faces, [material], smooth=True)


def casting(theta, r, z):
    # Rounded rectangular mouth, uneven shoulder and two flat hammer facets.
    c,s = cos(theta),sin(theta)
    def oval(a): return (1 if a >= 0 else -1)*abs(a)**0.84
    wear = 1.0 + 0.013*sin(3*theta+1.7) + 0.010*cos(7*theta+z*29)
    return (r*oval(c)*wear, 0.84*r*oval(s)*wear, z + 0.0005*(1+sin(3*theta))*min(r/.064,1.0))


profile = [
    (.065,0),(.069,.0011),(.070,.0037),(.069,.0057),(.066,.0071),
    (.061,.014),(.057,.020),(.050,.031),(.042,.048),(.037,.064),(.034,.080),
    (.030,.087),(.023,.091),(.011,.0928),(.003,.093),
    (.003,.089),(.015,.0889),(.024,.086),(.030,.080),(.033,.063),(.038,.046),
    (.046,.030),(.053,.018),(.060,.007),(.064,.0033)
]
count = 64
verts = [casting(2*pi*i/count,r,z) for r,z in profile for i in range(count)]
quads, slots = [], []
for band in range(len(profile)):
    next_band=(band+1)%len(profile)
    for i in range(count):
        j=(i+1)%count
        quads.append((band*count+i, band*count+j, next_band*count+j, next_band*count+i))
        if band>14: idx=2
        elif band in (0,1,2,3,12,13): idx=1
        else: idx=0
        slots.append(idx)
shell = mesh_object(bell, "Hammered hollow shell", verts, quads, [aged_iron,rubbed,inside], slots, True)
uv = shell.data.uv_layers.new(name="Bell patina")
for polygon in shell.data.polygons:
    band, index = divmod(polygon.index, count)
    for loop_index, column, row in zip(polygon.loop_indices, [index,index+1,index+1,index],
                                      [band,band,(band+1)%len(profile),(band+1)%len(profile)]):
        uv.data[loop_index].uv = (column/count,profile[row][1]/.094)


# Make a small set of worn discontinuous marks, conforming to the flared wall.
# They can catch the light when Elna turns the lip; they do not spell out a name.
def outside(z):
    for (r0,z0),(r1,z1) in zip(profile[4:13],profile[5:14]):
        if z0 <= z <= z1:
            return r0+(r1-r0)*(z-z0)/(z1-z0)
    raise ValueError(z)


for i,(at,height) in enumerate([(-1.98,.005),(-1.85,.008),(-1.72,.004),(-1.62,.007),(-1.47,.006),(-1.31,.003)]):
    points=[]
    for z, off in [(.009,0),(.010, -.009),(.009+height,.022),(.009+height*.70,.026)]:
        points.append(casting(at+off,outside(z)+.00023,z))
    mesh_object(bell,"Filed remnant %02d"%i,points,[(0,1,2,3)], [filed])

# Forged arch has a straight section that can actually be grasped or tied.
handle=[(-.023,0,.089),(-.023,0,.104),(-.021,0,.122),(-.017,0,.131),
        (-.012,0,.134),(0,0,.135),(.012,0,.134),(.018,0,.13),
        (.022,0,.122),(.023,0,.103),(.023,0,.089)]
tube(bell,"Cart bail",handle,.0037,rubbed,12)
for sign in (-1,1):
    tube(bell,"Peened foot",[(sign*.023,0,.088),(sign*.023,0,.092),(sign*.023,0,.0933)],.0053,iron,12)
eye=[(.006*cos(t),0,.083+.006*sin(t)) for t in [i*2*pi/24 for i in range(25)]]
tube(bell,"Empty striker eye",eye,.0015,inside)

# Prepared version has a separate striker and a short binding around the grip.
tube(striker_group,"Striker hanger",[(0,0,.082),(-.003,0,.076),(.001,0,.066),(0,0,.031)],.00165,iron)
striker=[(.001,.019),(.005,.020),(.007,.024),(.006,.029),(.004,.032),(.001,.033)]
verts=[(r*cos(t*2*pi/16),r*sin(t*2*pi/16),z) for r,z in striker for t in range(16)]
faces=[(i*16+j,i*16+(j+1)%16,(i+1)*16+(j+1)%16,(i+1)*16+j) for i in range(len(striker)-1) for j in range(16)]
mesh_object(striker_group,"Temporary striker",verts,faces,[rubbed],smooth=True)
wrap=[]
for i in range(181):
    u=i/180; a=2*pi*7*u
    wrap.append((-.011+.022*u,.0041*cos(a),.1348+.0041*sin(a)))
tube(wrap_group,"Seven turns of waxed wool",wrap,.00155,wool,7)
tube(wrap_group,"Tucked wool end",[(.010,-.004,.135),(.013,-.004,.1315),(.015,-.002,.1305)],.0015,wool)
tube(residue,"Wax in bail seam",[(.018,-.0018,.1315),(.017,-.0028,.1328),(.013,-.0032,.1337)],.0010,wax,7)

bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/"HarlsCartBell.blend"),compress=True)
# Join copies only for export. The saved Blender file keeps each part editable.
for group, filename in [(bell,"harl_cart_bell"),(striker_group,"temporary_striker"),
                        (wrap_group,"waxed_wool"),(residue,"wax_residue")]:
    bpy.ops.object.select_all(action="DESELECT")
    pieces = []
    for source in list(group.objects):
        piece = source.copy()
        piece.data = source.data.copy()
        bpy.context.scene.collection.objects.link(piece)
        piece.select_set(True)
        pieces.append(piece)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
    result = bpy.context.view_layer.objects.active
    result.name = filename
    if group == striker_group:
        for vertex in result.data.vertices:
            vertex.co.z -= .082
    bpy.ops.export_scene.gltf(filepath=str(runtime/(filename+".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_animations=False, export_cameras=False,
        export_lights=False, export_extras=False)
    bpy.data.objects.remove(result, do_unlink=True)
