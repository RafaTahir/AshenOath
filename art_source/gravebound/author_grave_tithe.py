"""Blender --background --python author_grave_tithe.py -- <export directory>."""
import math
import sys
from pathlib import Path

import bpy
import bmesh

out = Path(sys.argv[sys.argv.index("--") + 1])
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
material = bpy.data.materials.new("Tarnished iron and stained ash")
material.use_nodes = True
shader = material.node_tree.nodes.get("Principled BSDF")
colors = material.node_tree.nodes.new("ShaderNodeVertexColor")
colors.layer_name = "Pigment"
material.node_tree.links.new(colors.outputs["Color"], shader.inputs["Base Color"])
shader.inputs["Metallic"].default_value = 0.40
shader.inputs["Roughness"].default_value = 0.54
verts, faces, paints = [], [], []
wood = (0.16, 0.062, 0.033)
iron = (0.085, 0.125, 0.15)
bronze = (0.40, 0.22, 0.075)
edge = (0.48, 0.58, 0.62)
hide = (0.14, 0.026, 0.018)

def rings(rows, pigments):
    first = len(verts)
    width = len(rows[0])
    for row in rows:
        verts.extend((x, -z, y) for x, y, z in row)
    for i in range(len(rows) - 1):
        for j in range(width):
            a = first + i * width + j
            b = first + i * width + (j + 1) % width
            faces.append((a, a + width, b + width, b))
            paints.append(pigments(i, j))
    faces.extend((tuple(first + j for j in range(width)), tuple(first + (len(rows)-1)*width + j for j in reversed(range(width)))))
    paints.extend((pigments(0, 0), pigments(len(rows)-2, 0)))

def lathe(levels, color, x=0.0, z=0.0, grain=0.08):
    rows = [[(x+r*math.cos(j*math.tau/10), y, z+r*math.sin(j*math.tau/10)) for j in range(10)] for y,r in levels]
    rings(rows, lambda i,j: tuple(c*(1+grain*math.cos(2*j+0.3*i)) for c in color))

lathe([(-0.47,.020),(-.43,.030),(-.19,.029),(.28,.034),(.68,.029),(.91,.037),(.98,.027)], wood, grain=.23)
for y, radius, height, metal in [(-.47,.036,.06,iron),(.65,.040,.031,bronze),(.76,.044,.11,iron),(.91,.050,.095,iron),(.925,.054,.014,bronze)]:
    lathe([(y,radius*.83),(y+.005,radius),(y+height-.005,radius),(y+height,radius*.86)], metal)
for i in range(10):
    y = -.14+i*.029
    lathe([(y,.034),(y+.005,.039),(y+.023,.037),(y+.028,.034)], hide)

# Offset ridgeline, a cold cutting bevel and three hand-cut grave tally marks.
spans = [(0,.916,.098),(.07,.947,.123),(.17,.958,.124),(.31,.947,.112),
         (.46,.91,.100),(.58,.851,.080),(.70,.769,.064),(.80,.661,.039),(.87,.52,.003)]
rows = []
for x,y,width in spans:
    thick = .018 * min(1.0, width/.045)
    rows.append([(x,y+width*.38,0),(x,y+width*.17,thick),(x,y-width*.61,thick*.46),
                 (x,y-width*.83,0),(x,y-width*.61,-thick*.46),(x,y+width*.17,-thick)])
rings(rows,lambda i,j: edge if j in (2,3) else (tuple(c*1.42 for c in iron) if j in (0,5) else iron))
for x,y in [(.12,.95),(.154,.954),(.19,.955)]:
    rows = [[(x+dx,y+dy,z) for dx,dy in [(0,-.022),(.010,-.020),(.001,.015),(-.008,.012)]] for z in (.016,.019)]
    rings(rows,lambda i,j: bronze)
mesh = bpy.data.meshes.new("Grave tithe")
mesh.from_pydata(verts, [], faces)
mesh.update()
topology = bmesh.new()
topology.from_mesh(mesh)
bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
topology.to_mesh(mesh)
topology.free()
model = bpy.data.objects.new("GraveTithe", mesh)
scene.collection.objects.link(model)
mesh.materials.append(material)
pigment = mesh.color_attributes.new(name="Pigment", type="BYTE_COLOR", domain="CORNER")
for poly, color in zip(mesh.polygons, paints):
    for k in poly.loop_indices:
        pigment.data[k].color = (*color, 1)
# The empties are children of the rendered mesh. Godot reads their actual world positions.
for name, xyz in [("EdgeHeel",(.07,.851,0)),("EdgeTip",(.87,.52,0))]:
    marker=bpy.data.objects.new(name,None)
    scene.collection.objects.link(marker)
    marker.parent=model
    marker.location=(xyz[0],-xyz[2],xyz[1])
    marker.empty_display_size=.04
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().with_name("GraveTithe.blend")), compress=True)
bpy.ops.export_scene.gltf(filepath=str(out/"grave_tithe_scythe.glb"), export_format="GLB", export_materials="EXPORT")
