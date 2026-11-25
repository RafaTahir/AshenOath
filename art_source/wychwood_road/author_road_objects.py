"""Blender 5.2 authoring source. Run with --background --python FILE -- OUT."""
from math import cos, pi, sin
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector

out = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0


def patina(metal):
    name = "Forged scale" if metal else "Split oak grain"
    existing = bpy.data.images.get(name)
    if existing: return existing
    from math import floor
    def field(x,y,nx,ny):
        a,b = floor(x),floor(y)
        dx,dy=x-a,y-b
        dx,dy=dx*dx*(3-2*dx),dy*dy*(3-2*dy)
        def noise(i,j):
            h=((i%nx)*374761393+(j%ny)*668265263)&0xffffffff
            h=((h^(h>>13))*1274126177)&0xffffffff
            return ((h^(h>>16))&0xffff)/65535
        return ((1-dx)*noise(a,b)+dx*noise(a+1,b))*(1-dy)+((1-dx)*noise(a,b+1)+dx*noise(a+1,b+1))*dy
    size=192
    pixels=[]
    for yy in range(size):
        for xx in range(size):
            u,v=xx/size,yy/size
            grit=field(u*85,v*85,85,85)
            age=field(u*9,v*8,9,8)
            if metal:
                pitting=max(0.0,(grit-0.65)*1.7)
                oxide=max(0.0,(age-.55)*1.7)
                val=.53+.41*age-.47*pitting
                rgb=(val+.16*oxide,val-.14*oxide,val-.24*oxide)
            else:
                bend=u+.031*sin(tau*v)+.012*sin(3*tau*v)+.030*field(u*4,v*4,4,4)
                fibre=field(bend*62,v*5,62,5)
                ring=abs(sin(tau*(bend*13+.48*field(u*3,v*2,3,2))))
                split=max(0.,(.36-fibre)*2.9)*(.19+.65*age)
                val=.57+.29*fibre+.12*grit+.10*age-.23*(1-ring)**3-split
                rgb=(val*1.035,val,val*(.92+.09*age))
            pixels.extend((*[max(.10,min(.99,k)) for k in rgb],1))
    im=bpy.data.images.new(name,size,size,alpha=False)
    im.pixels.foreach_set(pixels)
    im.file_format="PNG"
    im.pack()
    return im


def finish(obj, name, color, metal=False, bevel=0.0):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mesh_edit = bmesh.new()
    mesh_edit.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(mesh_edit, faces=list(mesh_edit.faces))
    mesh_edit.to_mesh(obj.data)
    mesh_edit.free()
    if bevel:
        beveler = obj.modifiers.new("Worn arrises", "BEVEL")
        beveler.width, beveler.segments = bevel, 2
        bpy.ops.object.modifier_apply(modifier=beveler.name)
    pbr = "Hammered iron" if metal else "Paint, fibre and cut wood"
    mat = bpy.data.materials.get(pbr)
    if mat is None:
        mat = bpy.data.materials.new(pbr)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = 0.57 if metal else 0.87
        shader.inputs["Metallic"].default_value = 0.64 if metal else 0
        attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Pigment"
        tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image=patina(metal)
        mix=mat.node_tree.nodes.new("ShaderNodeMixRGB")
        mix.blend_type="MULTIPLY"
        mix.inputs[0].default_value=1
        mat.node_tree.links.new(attr.outputs["Color"],mix.inputs[1])
        mat.node_tree.links.new(tex.outputs["Color"],mix.inputs[2])
        mat.node_tree.links.new(mix.outputs[0],shader.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    bpy.context.view_layer.update()
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name="Hand cut grain")
    for face in obj.data.polygons:
        normal=(obj.matrix_world.to_3x3() @ face.normal).normalized()
        for li in face.loop_indices:
            x,y,z=obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co
            if abs(normal.z)>.74: across,along=x,y
            elif abs(normal.y)>abs(normal.x): across,along=x,z
            else: across,along=y,z
            if name in ["Whittled crow","Worn wing","Reused name tally","Knife-cut flight feather"]:
                across,along=along,across
            uv.data[li].uv=(across/.19,along/.34)
    colors = obj.data.color_attributes.new(name="Pigment", type="BYTE_COLOR", domain="CORNER")
    for face in obj.data.polygons:
        # Cut planes and worn edges show small differences in grain and oxide.
        variation = 0.93 + 0.10 * (0.5 + 0.5 * sin(face.index * 4.137))
        for i in face.loop_indices:
            colors.data[i].color_srgb = [min(1.0, c * variation) for c in color] + [1.0]
    return obj


def prism(name, outline, y, depth, color, bevel=0.0):
    # Relief outlines are drawn looking at the front of the object (negative Y).
    n = len(outline)
    vertices = [(x, y + t, z) for t in (0, depth) for x, z in outline]
    faces = [list(range(n)), list(reversed(range(n, 2*n)))]
    faces += [(i, i+n, (i+1) % n+n, (i+1) % n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, color, bevel=bevel)


def shaft(name, a, b, radius_a, radius_b, col, sides=10, metal=False, bevel=0):
    start, end = Vector(a), Vector(b)
    delta = end - start
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius_a, radius2=radius_b,
                                    depth=delta.length, location=(start + end) * 0.5)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, col, metal, bevel)


def strand(name, points, radius, color, metal=False, closed=False):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth, curve.bevel_resolution, curve.resolution_u = radius, 1, 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for point, xyz in zip(spline.points, points):
        point.co = (*xyz, 1)
    spline.use_cyclic_u = closed
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return finish(bpy.context.object, name, color, metal)


oak = (0.31, 0.205, 0.121)
endgrain = (0.62, 0.458, 0.281)
oldgrain = (0.43, 0.333, 0.223)
black = (0.126, 0.145, 0.148)
rust = (0.38, 0.251, 0.165)
iron = (0.48, 0.465, 0.391)
hemp = (0.60, 0.47, 0.31)
red = (0.48, 0.143, 0.105)
tau = 2*pi


def carters_axle():
    # A length of axle, driven into the verge after the wheel broke. Its iron
    # tyre fragment acts as a sounding plate; the hanging ring can strike it.
    profile = [(-.115,0),(.116,0),(.112,.46),(.091,.68),(.106,.79),
               (.041,.757),(.015,.826),(-.014,.768),(-.072,.797),(-.1,.69)]
    prism("Splintered oak spindle",profile,-.065,.145,oak,.012)
    for x,z,length in [(-.072,.11,.19),(-.036,.40,.20),(.069,.05,.24),(.038,.54,.17)]:
        prism("Exposed winter grain",[(x,z),(x+.008,z+.027),(x+.018,z+length),
              (x+.008,z+length*.78)],-.067,.002,oldgrain)
    shaft("Tyre socket",(-.128,0,.53),(.139,0,.535),.109,.099,black,12,True,.004)
    shaft("Peened end",(-.130,0,.53),(-.127,0,.53),.096,.098,rust,12,True)
    for x in [-.093,.092]:
        shaft("Rusted collar",(x,0,.53),(x+.014,0,.53),.111,.111,rust,12,True)
    # Plate is wider than the post, giving a readable silhouette from the ford.
    plate = prism("Hanging strike plate",[(-.148,.42),(.15,.415),(.156,.57),
                  (.116,.615),(-.138,.604)],-.121,.025,black,.006)
    plate.data.materials[0] = bpy.data.materials["Hammered iron"]
    for x in [-.117,.119]:
        shaft("Rivet", (x,-.128,.574),(x,-.115,.574),.013,.014,iron,8,True)
    for x in [-.078,-.040,.066]:
        prism("Scored carter tally",[(x-.011,.449),(x+.002,.453),
              (x+.018,.529),(x+.012,.54)],-.123,.002,(.25,.206,.15),.001)
        prism("Rubbed lip",[(x-.008,.450),(x-.003,.451),(x+.014,.525),
              (x+.012,.535)],-.124,.001,(.61,.54,.395),.0005)
    strand("Forged keeper",[(-.018,-.126,.633),(-.023,-.163,.643),(0,-.178,.657),
           (.024,-.16,.641),(.02,-.124,.633)],.009,iron,True)
    strand("Loose oval striker",[(.062*cos(tau*i/24),-.166+.009*cos(tau*i/24),
           .56+.085*sin(tau*i/24)) for i in range(24)],.009,iron,True,True)
    # Frayed binding at the foot, partly sunk into the verge.
    pts = [(.125*cos(i*tau/15),.097*sin(i*tau/15),.127+i*.0008) for i in range(47)]
    strand("Old foot lashing",pts,.0065,hemp)
    strand("Frayed end",[pts[-1],(.129,.026,.131),(.153,.039,.081),(.179,.062,.055)],.004,hemp)


def oren_crow():
    # The painted bird is cut from an older tally. A sliver of the unpainted
    # name face and shallow cuts remain visible underneath its belly.
    prism("Reused name tally",[(-.118,.009),(.116,.009),(.131,.032),(.112,.061),
          (-.111,.063),(-.132,.044)],-.041,.093,endgrain,.009)
    outline=[(-.15,.074),(-.093,.118),(-.065,.151),(-.043,.174),(.019,.181),
             (.043,.22),(.075,.239),(.115,.232),(.133,.211),(.177,.190),
             (.12,.184),(.1,.139),(.071,.104),(.041,.085),(-.019,.081),
             (-.077,.077),(-.151,.059)]
    prism("Whittled crow",outline,-.030,.068,(.209,.225,.217),.007)
    for y in [-.037,.040]:
        prism("Worn wing",[(-.106,.088),(-.052,.133),(-.008,.162),(.037,.153),
              (.049,.139),(.013,.116),(-.058,.093)],y,.006,(.303,.332,.309),.003)
        for i in range(3):
            x,z=-.084+i*.027,.093+i*.007
            prism("Knife-cut flight feather",[(x,z),(x+.016,z+.004),
                  (x+.059,z+.036),(x+.056,z+.037)],y-.0015 if y<0 else y+.006,.001,
                  (.504,.451,.335))
    shaft("Finger-polished beak",(.130,0,.205),(.173,0,.19),.013,.001,
          (.58,.47,.313),8)
    for y in [-.032,.041]:
        shaft("Wooden eye",(.093,y,.210),(.093,y-.003,.210),.006,.006,endgrain,8)
    for x in [-.039,.033]:
        shaft("Carved foot",(x,0,.056),(x+.014,.001,.091),.013,.010,oak,7)
    for x in [-.080,-.048,-.007,.028]:
        prism("Scraped name strokes",[(x,.024),(x+.004,.025),(x+.014,.047),
              (x+.007,.043)],-.042,.001,oak)
    wire = [(-.022+.019*(i/47),.057*cos(tau*i/16),.057+.045*sin(tau*i/16))
            for i in range(48)]
    strand("Blackened binding",wire,.0036,black,True)
    strand("Bent tag end",[wire[-1],(.015,.058,.048),(.053,.071,.042),
           (.065,.063,.045)],.0028,rust,True)


def raider_tally():
    # The mesh origin is where the short lanyard meets the wrist cord.
    strand("Loop around cord",[(-.009,0,0),(-.012,.005,-.016),(-.003,.005,-.035),
           (.011,.003,-.029),(.013,-.002,-.014),(.006,-.005,0)],.0028,hemp)
    prism("Carter's split tally",[(-.022,-.026),(.017,-.027),(.024,-.039),
          (.018,-.101),(.007,-.111),(-.001,-.098),(-.020,-.107),(-.025,-.046)],
          -.004,.010,oldgrain,.002)
    for y in [-.005,.006]:
        for z in [-.050,-.058,-.076]:
            prism("Cut tally", [(-.020,z),(-.018,z-.003),(.009,z+.007),
                  (.012,z+.011)],y,.0015,endgrain)
    strand("Lost end of binding",[(.001,-.005,-.024),(.019,-.011,-.035),
           (.034,-.009,-.059),(.041,-.011,-.067)],.0025,red)


assets=[("Wychwood_CartersAxle",carters_axle),("CarvedCrowToken",oren_crow),
        ("Wychwood_RaiderTally",raider_tally)]
for asset, make in assets:
    before=set(bpy.data.objects)
    make()
    pieces=sorted(set(bpy.data.objects)-before,key=lambda ob: ob.name)
    group=bpy.data.collections.new(asset)
    bpy.context.scene.collection.children.link(group)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pieces:
        for collection in list(ob.users_collection):
            collection.objects.unlink(ob)
        group.objects.link(ob)
        ob.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]
    # glTF multiplies COLOR_0 by baseColorTexture. Export those two standard
    # inputs explicitly, then restore the editable Blender preview graph.
    for mat in bpy.data.materials:
        if not mat.use_nodes or not mat.node_tree.nodes.get("Image Texture"): continue
        mat.node_tree.links.new(mat.node_tree.nodes["Image Texture"].outputs["Color"],
                                mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    bpy.ops.export_scene.gltf(filepath=str(out/(asset+".glb")), export_format="GLB",
                              use_selection=True, export_vertex_color="ACTIVE",
                              export_animations=False, export_cameras=False, export_lights=False)
    for mat in bpy.data.materials:
        if not mat.use_nodes or not mat.node_tree.nodes.get("Image Texture"): continue
        mix=next(n for n in mat.node_tree.nodes if n.type=="MIX_RGB")
        mat.node_tree.links.new(mix.outputs[0],mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    # Organize the editable file as three independent, non-overlapping studies.
    for piece in pieces:
        piece.location.x += assets.index((asset,make))*0.85
bpy.ops.wm.save_as_mainfile(filepath=str(out/"WychwoodRoad.blend"),compress=True)
