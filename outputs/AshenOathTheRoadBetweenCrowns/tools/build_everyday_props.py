"""Original lightweight leisure props; run with Blender --background --python.

No renders or runtime checks. Editable source and glTF share the same geometry.
"""
import math
from pathlib import Path
import bpy

PROJECT = Path(__file__).resolve().parent.parent
SOURCE = PROJECT.parents[1] / "art_source" / "everyday_life"
OUTPUT = PROJECT / "assets" / "everyday"
SOURCE.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metal=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = 0.55 if metal else 0.78
    return result

wood = material("Warm ash wood", (0.29, 0.16, 0.075))
iron = material("Forged iron", (0.13, 0.15, 0.16), 0.7)
brass = material("Worn brass", (0.48, 0.36, 0.12), 0.65)
paper = material("Unbleached folded paper", (0.73, 0.70, 0.55))
cord = material("Waxed flax", (0.45, 0.40, 0.28))
eye = material("Fish eyes", (0.024, 0.032, 0.025))
belly = material("Fish belly", (0.59, 0.64, 0.47))
fin = material("Fin rays", (0.30, 0.36, 0.20))
silver = material("River dace", (0.25, 0.39, 0.36), 0.2)
copper = material("Copper perch", (0.43, 0.29, 0.12), 0.1)

def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def cylinder(name, radius, depth, position, mat, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=position, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Rounded worked edge", "BEVEL")
    bevel.width = min(radius * .12, .006)
    bevel.segments = 2
    return obj

def box(name, size, position, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Soft handled edges", "BEVEL")
    bevel.width = .003
    bevel.segments = 2
    return obj

def export(name, before):
    objects = [obj for obj in bpy.context.scene.objects if obj not in before]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (name + ".glb")), use_selection=True,
                             export_format="GLB", export_apply=True, export_animations=False)
    for obj in objects:
        obj.hide_set(True)
        obj.hide_render = True

def fish(name, mat, length, girth):
    before = set(bpy.context.scene.objects)
    vertices, faces = [], []
    profiles = [(0,.08),(.12,.64),(.30,1),(.55,.91),(.78,.46),(.90,.16),(1,.08)]
    for x, width in profiles:
        for i in range(16):
            angle = i * math.tau / 16
            vertices.append(((x-.5)*length, math.cos(angle)*girth*width*.57, math.sin(angle)*girth*width))
    for ring in range(len(profiles)-1):
        for i in range(16):
            a=ring*16+i; b=ring*16+(i+1)%16
            faces.append((a,b,b+16,a+16))
    faces += [tuple(reversed(range(16))), tuple(range((len(profiles)-1)*16,len(profiles)*16))]
    body=mesh(name+"_body",vertices,faces,mat)
    body.data.materials.append(belly)
    for polygon in body.data.polygons:
        polygon.use_smooth=True
        if polygon.center.z < -girth*.25: polygon.material_index=1
    tailx=length*.46
    mesh(name+"_forked_tail",[(tailx,0,0),(length*.68,.008,girth*.9),(length*.61,0,0),(length*.68,-.008,-girth*.9),(tailx+.015,0,0)],[(0,1,2,4),(4,2,3,0)],fin)
    dorsal = mesh(name+"_dorsal",[(-length*.15,0,girth*.9),(length*.12,0,girth*1.45),(length*.25,0,girth*.62)],[(0,1,2)],fin)
    dorsal.modifiers.new("Thin fin membrane", "SOLIDIFY").thickness = .002
    for side in [-1,1]:
        pectoral = mesh(name+"_pectoral",[(-length*.25,side*girth*.45,-.008),(-length*.05,side*girth*1.05,-girth*.45),(0,side*girth*.50,-girth*.45)],[(0,1,2)],fin)
        pectoral.modifiers.new("Thin fin membrane", "SOLIDIFY").thickness = .002
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.008, location=(-length*.38,side*girth*.35,girth*.22))
        bpy.context.object.data.materials.append(eye)
    export(name,before)

fish("river_dace",silver,.29,.047)
fish("copper_perch",copper,.34,.074)
before=set(bpy.context.scene.objects)
for i in range(4):
    cylinder("Tapered ash section",.014-i*.0025,.46,(0,0,.23+i*.45),wood)
cylinder("Cord grip",.019,.26,(0,0,.18),cord)
for z in [.45,.95,1.40,1.78]:
    bpy.ops.mesh.primitive_torus_add(major_radius=.022,minor_radius=.003,major_segments=12,minor_segments=6,location=(.018,0,z),rotation=(math.pi/2,0,0))
    bpy.context.object.data.materials.append(brass)
export("fishing_rod",before)
before=set(bpy.context.scene.objects)
# A hollow, rolled-rim pot rather than a closed cylinder.
vertices=[]; faces=[]
for radius,z in [(.10,0),(.13,.04),(.14,.15),(.13,.16),(.12,.15),(.11,.03)]:
    for i in range(24): vertices.append((math.cos(i*math.tau/24)*radius,math.sin(i*math.tau/24)*radius,z))
for ring in range(5):
    for i in range(24):
        a=ring*24+i; b=ring*24+(i+1)%24
        faces.append((a,b,b+24,a+24))
faces.append(tuple(range(120,144)))
mesh("Hollow cooking pot",vertices,faces,iron)
cylinder("Ladle handle",.009,.31,(.16,0,.17),wood,(0,math.pi/3,0))
export("cooking_pot",before)
for name in ["worn_hammer","folded_letter","bell_clasp","rope_knot","record_seal","seed_case"]:
    before=set(bpy.context.scene.objects)
    if name=="worn_hammer":
        cylinder("Grain-following handle",.018,.32,(0,0,0),wood)
        box("Peened hammer head",(.13,.045,.055),(0,0,.13),iron)
        for x in [-.025,0,.025]: box("Maker notch",(.003,.001,.013),(x,-.023,.14),brass)
    elif name=="folded_letter":
        box("Closed folded letter",(.19,.005,.12),(0,0,0),paper)
        cylinder("Unbroken seal",.018,.008,(0,-.008,0),brass,(math.pi/2,0,0))
    elif name=="bell_clasp":
        bpy.ops.mesh.primitive_torus_add(major_radius=.055,minor_radius=.009,major_segments=24,minor_segments=8)
        bpy.context.object.data.materials.append(brass)
        box("Clasp pin",(.009,.11,.009),(0,0,0),iron)
    elif name=="rope_knot":
        for x in [-.022,.022]:
            bpy.ops.mesh.primitive_torus_add(major_radius=.04,minor_radius=.009,major_segments=20,minor_segments=6,location=(x,0,0),rotation=(0,x*12,0))
            bpy.context.object.data.materials.append(cord)
    elif name=="record_seal":
        cylinder("Seal die",.04,.025,(0,0,0),brass)
        cylinder("Turned handle",.022,.09,(0,0,.05),wood)
        box("Account mark",(.03,.006,.003),(0,0,-.014),iron)
    else:
        box("Seed case",(.11,.07,.035),(0,0,0),wood)
        box("Sliding lid",(.115,.075,.006),(0,0,.02),wood)
        cylinder("Finger notch",.012,.006,(.035,0,.025),brass)
    export(name,before)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "everyday_props.blend"))
print("Authored 10 original low-poly leisure props; no textures, external assets or renders.")
