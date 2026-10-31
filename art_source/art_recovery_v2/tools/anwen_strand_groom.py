"""High-detail directional strand groom; retained independently of game LODs."""
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "models/C01_anwen_review_v027.blend"))
rig = bpy.data.objects["C01_Anwen_Rig"]
head = bpy.data.objects["Anwen_MatureFace_Neck"]
tree = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())
for obj in list(bpy.data.objects):
    if obj.name.startswith("Anwen_Hair_") and not any(tag in obj.name for tag in ("PinnedPlait", "SidePlait")):
        bpy.data.objects.remove(obj, do_unlink=True)

material = bpy.data.materials.new("Anwen_v030_AshSilver_Strands")
material.use_nodes = True
nodes, links = material.node_tree.nodes, material.node_tree.links
shader = nodes.get("Principled BSDF")
hair = nodes.new("ShaderNodeHairInfo")
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (.075, .060, .044, 1)
ramp.color_ramp.elements[1].color = (.43, .395, .33, 1)
ramp.color_ramp.elements.new(.55).color = (.24, .215, .17, 1)
links.new(hair.outputs["Random"], ramp.inputs[0])
links.new(ramp.outputs[0], shader.inputs["Base Color"])
shader.inputs["Roughness"].default_value = .64
shader.inputs["Specular IOR Level"].default_value = .30
shader.inputs["Anisotropic"].default_value = .55

data = bpy.data.curves.new("Anwen_Combed_Continuous_Strands", "CURVE")
data.dimensions = "3D"
data.resolution_u = 1
data.bevel_depth = .000095
data.bevel_resolution = 1
data.resolution_u = 1
obj = bpy.data.objects.new("Anwen_Hair_v030_AuthoredStrands", data)
bpy.context.collection.objects.link(obj)
data.materials.append(material)
obj.parent = rig
# The groom moves rigidly with the cranium; cloth and face keep their own skins.
obj.parent_type = "BONE"
obj.parent_bone = "Head"
obj.matrix_world.identity()
obj["production_role"] = "high-detail groom source, not an approved runtime LOD"
rng = random.Random(3021)
total = 0


def cubic(points, t):
    return (1-t)**3*points[0] + 3*(1-t)**2*t*points[1] + 3*(1-t)*t*t*points[2] + t**3*points[3]


def strand(controls, seed, length=1):
    global total
    spline = data.splines.new("POLY")
    spline.points.add(35)
    wobble = rng.uniform(.0005, .0024)
    for index, point in enumerate(spline.points):
        t = index / 35 * length
        p = cubic(controls, t)
        hit, normal, _, _ = tree.find_nearest(p)
        # Shape-following waves retain a controlled silhouette rather than
        # independent cylinders or a cap covering the facial hairline.
        lift = .0012 + .0045*math.sin(t*math.pi) + wobble*math.sin(t*12 + seed)
        lift += .002*math.sin(t*math.pi)**2*math.sin(t*7 + seed*.3)
        p = hit + normal*max(.0004, lift)
        point.co = (*p, 1)
        point.radius = (.55 + .6*rng.random()) * (1 - .92*(index/35)**7)
    total += 1


for i in range(7200):
    a = rng.uniform(-2.5, 2.5)
    line = 1.670 + .068*max(0, math.cos(a))
    root = Vector((.083*math.sin(a), .012-.10*math.cos(a), line+rng.uniform(-.0015,.008)))
    side = 1 if root.x > -.008 else -1
    twist = rng.uniform(-.008,.008)
    controls = [root,
                Vector((side*(.073+twist), -.052+rng.uniform(-.012,.012), 1.805+rng.uniform(-.004,.008))),
                Vector((side*(.094+twist), .057, 1.755+rng.uniform(-.012,.006))),
                Vector((side*.038, .105, 1.658+rng.uniform(-.01,.01)))]
    strand(controls, i*.71, rng.uniform(.85, 1))

# Crown paths fill the top of the head without an opaque scalp shell.
for i in range(2400):
    side = rng.choice((-1, 1))
    y = rng.uniform(-.068, .065)
    hit, normal, _, _ = tree.ray_cast(Vector((side*.002, y, 2)), Vector((0,0,-1)))
    if hit is None:
        hit, normal, _, _ = tree.find_nearest(Vector((side*.002,y,1.80)))
    assert hit is not None
    controls = [hit+normal*.0005,
                Vector((side*.065, y+.018, 1.825)),
                Vector((side*.100, .08, 1.74)),
                Vector((side*.025, .108, 1.65))]
    strand(controls, i*.63, rng.uniform(.85,1))

# Distribute roots over the scalp as well as its hairline and part. A groom
# seeded only on the part leaves a visible bare wedge between guide families.
for i in range(6800):
    a = rng.uniform(-math.pi, math.pi)
    line = 1.670 + .067*max(0,math.cos(a)) - .020*max(0,-math.cos(a))
    end = math.acos(max(-1,min(1,(line-1.68)/.12)))
    phi = math.acos(1-rng.random()*(1-math.cos(end)))
    direction = Vector((.087*math.sin(phi)*math.sin(a),-.102*math.sin(phi)*math.cos(a),.12*math.cos(phi))).normalized()
    root,normal,_,_=tree.ray_cast(Vector((0,.012,1.68)),direction)
    assert root is not None
    side=1 if root.x>0 else -1
    controls=[root+normal*.0005,
              root+Vector((side*.025,.027,.035)),
              Vector((side*.076,.090,1.74)),
              Vector((side*.024,.115,1.65))]
    strand(controls,i*.43,rng.uniform(.76,1))

# Relaxed short wisps are separate from the part so the face stays exposed.
for side in (-1, 1):
    for i in range(90):
        t = rng.random()
        controls = [Vector((side*(.055+.025*t), -.083+.02*t, 1.745-.025*t)),
                    Vector((side*(.085+.01*t), -.105, 1.74)),
                    Vector((side*.100, -.078, 1.70)),
                    Vector((side*(.078+.018*t), -.081, 1.665-.035*t))]
        spline = data.splines.new("POLY"); spline.points.add(27)
        for index, point in enumerate(spline.points):
            p = cubic(controls, index/27)
            point.co = (*p,1); point.radius = .65*(1-.97*(index/27)**3)

for item in bpy.data.objects:
    if item.type == "MESH" and item.name.startswith("Anwen_Hair_"):
        mat = material.copy(); mat.name = "Anwen_v030_Plait"
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        for link in list(bsdf.inputs["Base Color"].links): mat.node_tree.links.remove(link)
        bsdf.inputs["Base Color"].default_value = (.18,.16,.125,1)
        coords=mat.node_tree.nodes.new("ShaderNodeTexCoord")
        mapping=mat.node_tree.nodes.new("ShaderNodeVectorMath");mapping.operation="MULTIPLY";mapping.inputs[1].default_value=(90,3,1)
        noise=mat.node_tree.nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=9;noise.inputs["Detail"].default_value=2
        bump=mat.node_tree.nodes.new("ShaderNodeBump");bump.inputs["Distance"].default_value=.0003;bump.inputs["Strength"].default_value=.45
        ml=mat.node_tree.links;ml.new(coords.outputs["UV"],mapping.inputs[0]);ml.new(mapping.outputs[0],noise.inputs["Vector"]);ml.new(noise.outputs["Fac"],bump.inputs["Height"]);ml.new(bump.outputs[0],bsdf.inputs["Normal"])
        item.data.materials.clear(); item.data.materials.append(mat)

rig["art_status"] = "REWORK_v031_NOT_ACCEPTED"
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "models/C01_anwen_strands_v031.blend"), compress=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"; scene.cycles.samples = 32
scene.render.resolution_x = 720; scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
out = ROOT / "evidence/anwen_v031"; out.mkdir(parents=True, exist_ok=True)
camera = scene.camera; camera.data.type = "ORTHO"; camera.data.ortho_scale = .38
for label, position, target in [("face",(.8,-2,1.7),(0,0,1.666)), ("side",(2,0,1.7),(0,0,1.666)), ("rear",(0,2,1.7),(0,0,1.70))]:
    camera.location = position
    camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath = str(out / (label+".png"))
    bpy.ops.render.render(write_still=True)
print("STRAND_GROOM_SOURCE_COMPLETE", total, flush=True)
