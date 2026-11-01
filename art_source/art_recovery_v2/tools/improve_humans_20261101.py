"""Tailored, non-destructive human costume refinement; run one ID in Blender.

Imports the current runtime GLB instead of regenerating an older authoring recipe.
Only writes into the dated refinement folders. Original resources are never touched.
"""
import argparse
import hashlib
import json
import math
import sys
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
MODEL_ROOT = ROOT / "models/refinement_20261101/humans"
EVIDENCE_ROOT = ROOT / "evidence/refinement_20261101/humans"
RUNTIME_ROOT = GAME / "art_review/refinement_20261101/humans"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exported_contract(path):
    content=path.read_bytes()
    if content[:4]!=b"glTF":
        raise ValueError("Expected binary glTF derivative")
    length,kind=struct.unpack_from("<II",content,12)
    document=json.loads(content[20:20+length])
    primitives=[primitive for mesh in document.get("meshes",[]) for primitive in mesh["primitives"]]
    for primitive in primitives:
        material=document["materials"][primitive["material"]]
        if "baseColorTexture" not in material.get("pbrMetallicRoughness",{}):
            raise ValueError("A new surface lacks the game's required albedo texture: "+material.get("name",""))
        if "TEXCOORD_0" not in primitive["attributes"] or "JOINTS_0" not in primitive["attributes"]:
            raise ValueError("A derivative surface lost UVs or skinning")
    return {"meshes":len(document.get("meshes",[])),"skins":len(document.get("skins",[])),"primitives":len(primitives),"images":len(document.get("images",[])),"animations":len(document.get("animations",[])),"all_surfaces_textured_skinned":True}


PALETTE = [
    ("Welt_Leather", (0.083, 0.050, 0.027, 1), .84, 0),
    ("Waxed_Thread", (.23, .175, .105, 1), .94, 0),
    ("Worn_Brass", (.25, .16, .064, 1), .58, .72),
    ("Forged_Iron", (.055, .065, .068, 1), .58, .65),
    ("Pale_Linen", (.38, .32, .23, 1), .95, 0),
    ("Cloth_Binding", (.026, .035, .040, 1), .96, 0),
    ("Dried_Herb", (.085, .13, .055, 1), .96, 0),
]


def palette_material(asset_id):
    import bpy
    def srgb(value):
        return 12.92*value if value <= .0031308 else 1.055*value**(1/2.4)-.055
    albedo=bpy.data.images.new(asset_id+"_TailoredPalette_Albedo",width=16*len(PALETTE),height=16,alpha=True)
    orm=bpy.data.images.new(asset_id+"_TailoredPalette_ORM",width=16*len(PALETTE),height=16,alpha=True)
    orm.colorspace_settings.name="Non-Color"
    albedo_row=[]
    orm_row=[]
    for label,color,roughness,metallic in PALETTE:
        albedo_row+=([srgb(c) for c in color[:3]]+[1.0])*16
        orm_row+=[1.0,roughness,metallic,1.0]*16
    albedo.pixels=albedo_row*16
    orm.pixels=orm_row*16
    albedo.pack()
    orm.pack()
    mat=bpy.data.materials.new(asset_id+"_TailoredPalette_PBR")
    mat.use_nodes=True
    mat.diffuse_color=(.12,.08,.04,1)
    p=mat.node_tree.nodes.get("Principled BSDF")
    albedo_node=mat.node_tree.nodes.new("ShaderNodeTexImage")
    albedo_node.image=albedo
    albedo_node.interpolation="Closest"
    orm_node=mat.node_tree.nodes.new("ShaderNodeTexImage")
    orm_node.image=orm
    orm_node.interpolation="Closest"
    separate=mat.node_tree.nodes.new("ShaderNodeSeparateColor")
    separate.mode="RGB"
    mat.node_tree.links.new(albedo_node.outputs["Color"],p.inputs["Base Color"])
    mat.node_tree.links.new(orm_node.outputs["Color"],separate.inputs["Color"])
    mat.node_tree.links.new(separate.outputs["Green"],p.inputs["Roughness"])
    mat.node_tree.links.new(separate.outputs["Blue"],p.inputs["Metallic"])
    return mat


def read_asset(asset_id):
    row = next(r for r in json.loads((ROOT / "stylized_roster.json").read_text())["assets"] if r["id"] == asset_id)
    current = GAME / row["destination_resource"].removeprefix("res://")
    return row, current


def inspect(asset_id):
    import bpy
    from mathutils import Vector
    row, current = read_asset(asset_id)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(current))
    result = {"id": asset_id, "current": str(current), "sha256": digest(current), "objects": [], "materials": [], "actions": []}
    for ob in bpy.context.scene.objects:
        entry = {"name": ob.name, "type": ob.type, "dimensions": list(ob.dimensions), "location": list(ob.location)}
        if ob.type == "MESH":
            points = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
            entry.update(vertices=len(ob.data.vertices), faces=len(ob.data.polygons),
                         bounds=[[min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]],
                         materials=[m.name if m else "" for m in ob.data.materials],
                         groups=[g.name for g in ob.vertex_groups], modifiers=[m.type for m in ob.modifiers])
            entry["surface_bounds"] = []
            for slot, mat in enumerate(ob.data.materials):
                coords = [ob.matrix_world @ ob.data.vertices[v].co for p in ob.data.polygons if p.material_index == slot for v in p.vertices]
                if coords:
                    entry["surface_bounds"].append({"material": mat.name, "polygons": sum(p.material_index == slot for p in ob.data.polygons),
                        "bounds": [[min(p[i] for p in coords) for i in range(3)], [max(p[i] for p in coords) for i in range(3)]]})
            parents = list(range(len(ob.data.vertices)))
            def find(v):
                while parents[v] != v:
                    parents[v] = parents[parents[v]]
                    v = parents[v]
                return v
            for polygon in ob.data.polygons:
                base = find(polygon.vertices[0])
                for vertex in polygon.vertices[1:]:
                    parents[find(vertex)] = base
            groups = {}
            for vertex in ob.data.vertices:
                groups.setdefault(find(vertex.index), []).append(vertex.index)
            component_materials={}
            for polygon in ob.data.polygons:
                if polygon.material_index < len(ob.data.materials):
                    component_materials.setdefault(find(polygon.vertices[0]),set()).add(ob.data.materials[polygon.material_index].name)
            entry["components"] = []
            for root_index,vertices in groups.items():
                coords = [ob.matrix_world @ ob.data.vertices[v].co for v in vertices]
                entry["components"].append({"vertices": len(vertices), "materials": sorted(component_materials.get(root_index,set())),
                    "bounds": [[min(p[i] for p in coords) for i in range(3)], [max(p[i] for p in coords) for i in range(3)]]})
        elif ob.type == "ARMATURE":
            entry["bones"] = [{"name": b.name, "head": list(b.head_local), "tail": list(b.tail_local)} for b in ob.data.bones]
        result["objects"].append(entry)
    for mat in bpy.data.materials:
        if mat.node_tree:
            p = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            result["materials"].append({"name": mat.name, "color": list(p.inputs["Base Color"].default_value) if p else None,
                                      "roughness": p.inputs["Roughness"].default_value if p else None,
                                      "images": [n.image.name for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]})
    result["actions"] = [a.name for a in bpy.data.actions]
    out = EVIDENCE_ROOT / asset_id
    out.mkdir(parents=True, exist_ok=True)
    (out / "before_inspection.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"id":asset_id,"objects":[{"name":o["name"],"type":o["type"],"vertices":o.get("vertices"),"surfaces":o.get("surface_bounds")} for o in result["objects"]]},indent=2))


class Tailor:
    def __init__(self, body, rig, asset_id):
        import bpy
        from mathutils.kdtree import KDTree
        from mathutils.bvhtree import BVHTree
        self.body, self.rig, self.asset_id = body, rig, asset_id
        self.vertices, self.faces, self.material_ids, self.weights = [], [], [], []
        self.changes = []
        self.tree = KDTree(len(body.data.vertices))
        self.source_points = [body.matrix_world @ v.co for v in body.data.vertices]
        for i, point in enumerate(self.source_points):
            self.tree.insert(point, i)
        self.tree.balance()
        self.bvh = BVHTree.FromPolygons(self.source_points, [tuple(p.vertices) for p in body.data.polygons])
        self.source_weights = []
        for vertex in body.data.vertices:
            self.source_weights.append({body.vertex_groups[g.group].name: g.weight for g in vertex.groups if g.weight > 0})
        # One added PBR surface covers all leather, thread and metal details.
        # Palette tile centers stay far from mip/filter boundaries.
        self.materials = [palette_material(asset_id)]

    def point(self, x, z, front=True, clearance=.003):
        from mathutils import Vector
        sign = -1 if front else 1
        location, normal, face, distance = self.bvh.ray_cast(Vector((x, sign * 1.5, z)), Vector((0, -sign, 0)), 3)
        if location is None:
            raise ValueError(f"No costume surface at x={x}, z={z}, front={front}")
        return Vector((location.x, location.y + sign * clearance, location.z))

    def vertex(self, point, bone=None):
        from mathutils import Vector
        if bone and bone not in self.rig.data.bones:
            raise ValueError("Unknown retained bone: "+bone)
        self.vertices.append(tuple(point))
        nearest, index, distance = self.tree.find(Vector(point))
        weights = {bone: 1.0} if bone else self.source_weights[index]
        if not weights:
            raise ValueError("Refinement vertex cannot be weighted")
        self.weights.append(weights)
        return len(self.vertices) - 1

    def face(self, indices, mat=0):
        self.faces.append(tuple(indices))
        self.material_ids.append(mat)

    def tube(self, points, radius=.0018, mat=0, bone=None, closed=False, sides=6):
        from mathutils import Vector
        points = [Vector(p) for p in points]
        if len(points) < 2:
            return
        rings = []
        for i, p in enumerate(points):
            prev = points[i-1] if i > 0 or closed else p
            nxt = points[(i+1) % len(points)] if i < len(points)-1 or closed else p
            tangent = (nxt-prev).normalized()
            normal = tangent.cross(Vector((0, 1, 0))).normalized()
            if normal.length < .1:
                normal = tangent.cross(Vector((0, 0, 1))).normalized()
            binormal = tangent.cross(normal).normalized()
            rings.append([self.vertex(p + radius * (normal * math.cos(2*math.pi*j/sides) + binormal * math.sin(2*math.pi*j/sides)), bone) for j in range(sides)])
        for i in range(len(rings) if closed else len(rings)-1):
            first, second = rings[i], rings[(i+1) % len(rings)]
            for j in range(sides):
                self.face((first[j], first[(j+1)%sides], second[(j+1)%sides], second[j]), mat)
        if not closed:
            self.face(tuple(reversed(rings[0])), mat)
            self.face(rings[-1], mat)

    def stud(self, center, radius=.004, mat=2, bone=None):
        from mathutils import Vector
        center = Vector(center)
        vertices = []
        for i in range(8):
            a = 2*math.pi*i/8
            vertices.append(self.vertex(center + Vector((radius*math.cos(a),0,radius*math.sin(a))), bone))
        tip = self.vertex(center + Vector((0, -.0025, 0)), bone)
        for i in range(8):
            self.face((vertices[i], vertices[(i+1)%8], tip), mat)

    def ribbon(self, points, width=.015, mat=0, bone=None):
        from mathutils import Vector
        points = [Vector(p) for p in points]
        rows=[]
        for i,p in enumerate(points):
            direction = points[min(i+1,len(points)-1)]-points[max(i-1,0)]
            perpendicular=Vector((-direction.z,0,direction.x)).normalized()*width/2
            rows.append([self.vertex(p-perpendicular,bone),self.vertex(p+perpendicular,bone)])
        for a,b in zip(rows,rows[1:]):
            self.face((a[0],a[1],b[1],b[0]),mat)
        for side in (0,1):
            self.tube([self.vertices[r[side]] for r in rows], radius=.0015, mat=1, bone=bone)

    def cylinder(self,start,end,radius=.02,mat=0,bone="pelvis",sides=12):
        from mathutils import Vector
        start,end=Vector(start),Vector(end)
        direction=(end-start).normalized()
        normal=direction.cross(Vector((0,1,0))).normalized()
        if normal.length < .1:
            normal=direction.cross(Vector((0,0,1))).normalized()
        binormal=direction.cross(normal).normalized()
        rings=[]
        for center in (start,end):
            rings.append([self.vertex(center+radius*(normal*math.cos(j*2*math.pi/sides)+binormal*math.sin(j*2*math.pi/sides)),bone) for j in range(sides)])
        self.face(tuple(reversed(rings[0])),mat)
        self.face(rings[1],mat)
        for j in range(sides):
            self.face((rings[0][j],rings[0][(j+1)%sides],rings[1][(j+1)%sides],rings[1][j]),mat)

    def herb_bundle(self,x,z,front=True,bone="pelvis"):
        from mathutils import Vector
        center=self.point(x,z,front,.017)
        for i,shift in enumerate((-.015,0,.015)):
            start=center+Vector((shift,0,0))
            end=start+Vector((shift*.8,-.002,.11-abs(shift)))
            self.tube((start,end),radius=.0015,mat=0,bone=bone)
            for index in range(3):
                root=start+(end-start)*(.37+index*.2)
                side=-1 if index%2 else 1
                points=[root,root+Vector((side*.014,-.001,.011)),root+Vector((side*.027,0,.013)),root+Vector((side*.011,.002,-.003))]
                self.face([self.vertex(p,bone) for p in points],6)
                self.face([self.vertex(p+Vector((0,.001,0)),bone) for p in reversed(points)],6)
        self.ribbon([center+Vector((-.023,-.005,.025)),center+Vector((.024,-.005,.025))],width=.009,bone=bone)
        self.changes.append("Three modest dried herb sprigs tucked into a sewn waist keeper; stem and leaf geometry, no billboard")

    def border(self, material_tokens, zmin, zmax, xmax=.28, radius=.002, mat=0):
        """Weld UV duplicates before finding genuine open garment boundaries."""
        from mathutils import Vector
        edges, positions, normals = {}, {}, {}
        for polygon in self.body.data.polygons:
            material = self.body.data.materials[polygon.material_index].name
            if not any(token.lower() in material.lower() for token in material_tokens):
                continue
            for first, second in zip(polygon.vertices, (*polygon.vertices[1:], polygon.vertices[0])):
                a,b = self.source_points[first],self.source_points[second]
                keys = [tuple(round(v,5) for v in p) for p in (a,b)]
                edge = tuple(sorted(keys))
                edges[edge] = edges.get(edge, 0)+1
                positions[keys[0]],positions[keys[1]] = a,b
        count=0
        for (a,b),uses in edges.items():
            if uses != 1:
                continue
            pa,pb=positions[a],positions[b]
            if not all(zmin < p.z < zmax and abs(p.x) < xmax for p in (pa,pb)):
                continue
            if (pb-pa).length < .0008:
                continue
            self.tube((pa,pb),radius=radius,mat=mat)
            count+=1
        if count:
            self.changes.append(f"{count} genuine garment boundary segments finished with {radius*2000:.1f} mm rounded welt; UV seams excluded")

    def pouch(self, x, z, width=.105, height=.135, front=True, mat=0, bone="pelvis"):
        """A shaped, bevelled leather pouch with overlapping flap and belt loops."""
        from mathutils import Vector
        sign = -1 if front else 1
        center = self.point(x,z,front,.003)
        # Rounded eight-sided silhouette; bottom is narrower and sags at center.
        outline=[(-.48,.45),(.48,.45),(.52,.25),(.47,-.43),(.30,-.5),(-.30,-.5),(-.47,-.43),(-.52,.25)]
        back=[self.vertex(center+Vector((u*width,0,v*height)),bone) for u,v in outline]
        face=[self.vertex(center+Vector((u*width,sign*(.026 if v>0 else .035),v*height)),bone) for u,v in outline]
        self.face(tuple(reversed(back)),mat)
        self.face(face,mat)
        for i in range(8):
            self.face((back[i],back[(i+1)%8],face[(i+1)%8],face[i]),mat)
        self.tube([self.vertices[v] for v in face],radius=.0015,mat=1,bone=bone,closed=True)
        flap=[]
        for u,v in [(-.50,.48),(.50,.48),(.47,.15),(.25,.02),(0,-.04),(-.25,.02),(-.47,.15)]:
            flap.append(center+Vector((u*width,sign*.039,v*height)))
        indices=[self.vertex(p,bone) for p in flap]
        self.face(indices,mat)
        self.tube(flap,radius=.0015,mat=1,bone=bone,closed=True)
        self.stud(center+Vector((0,sign*.042,.04*height)),radius=.0038,mat=2,bone=bone)
        for offset in (-.31,.31):
            loop=[center+Vector((width*offset,sign*.004,height*.58)),center+Vector((width*offset,sign*.041,height*.47)),center+Vector((width*offset,sign*.042,height*.26))]
            self.ribbon(loop,width=.014,mat=0,bone=bone)
        fabric="linen seed bag" if mat==4 else "leather pouch"
        self.changes.append("Volumetric fitted "+fabric+" with shaped bottom, overlapping flap, brass fastening, rounded welt and two anchored leather belt loops")

    def patch(self,x,z,width,height,front=True,mat=0,bone=None):
        # A gridded pocket conforms across a bulging apron. Projecting corners
        # alone made a flat n-gon disappear into the cloth between its corners.
        rows,cols=6,8
        grid=[]
        positions=[]
        for row in range(rows+1):
            v=-.5+row/rows
            taper=.77 if row==0 else (.94 if row==1 else 1.0)
            ring=[]
            points=[]
            for col in range(cols+1):
                u=-.5+col/cols
                point=self.point(x+u*width*taper,z+v*height,front,.010+.004*(row/rows)**4)
                points.append(point)
                ring.append(self.vertex(point,bone))
            grid.append(ring)
            positions.append(points)
        for row in range(rows):
            for col in range(cols):
                self.face((grid[row][col],grid[row][col+1],grid[row+1][col+1],grid[row+1][col]),mat)
        edge=positions[0]+[positions[row][-1] for row in range(1,rows+1)]+list(reversed(positions[-1][:-1]))+[positions[row][0] for row in range(rows-1,0,-1)]
        self.tube(edge,radius=.0013,mat=1,bone=bone,closed=True)
        self.tube(positions[-1],radius=.0022,mat=mat,bone=bone)
        return edge

    def brooch(self,x,z,radius=.012,bone="spine_03"):
        from mathutils import Vector
        center=self.point(x,z,True,.006)
        points=[center+Vector((radius*math.cos(a*math.tau/12),0,radius*math.sin(a*math.tau/12))) for a in range(12)]
        self.tube(points,radius=.0018,mat=2,bone=bone,closed=True)
        diamond=[center+Vector((0,-.002,radius*.68)),center+Vector((radius*.48,-.003,0)),center+Vector((0,-.002,-radius*.68)),center+Vector((-radius*.48,-.003,0))]
        self.face([self.vertex(p,bone) for p in diamond],3)
        self.stud(center+Vector((0,-.004,0)),radius=.0028,bone=bone)

    def book(self,x,z,front=False,width=.10,height=.14,bone="pelvis"):
        from mathutils import Vector
        sign=-1 if front else 1
        center=self.point(x,z,front,.018)
        def slab(y0,y1,mat,margin=0):
            vertices=[self.vertex(center+Vector((u*(width+margin)/2,sign*y,v*(height+margin)/2)),bone) for y in (y0,y1) for v in (-1,1) for u in (-1,1)]
            for face in ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)):
                self.face([vertices[i] for i in face],mat)
        slab(0,.004,0,.006)
        slab(.004,.026,4)
        slab(.026,.030,0,.006)
        # Spine has rounded welt and a real retaining strap over the cover.
        for side in (-1,1):
            self.tube([center+Vector((side*width/2,sign*y,height/2)) for y in (0,.03)],radius=.002,mat=0,bone=bone)
        self.ribbon([center+Vector((-.02,sign*.034,height*.61)),center+Vector((-.02,sign*.035,-height*.46))],width=.014,bone=bone)
        self.stud(center+Vector((-.02,sign*.039,-height*.18)),radius=.0038,bone=bone)
        self.changes.append("Compact leather-bound working ledger with inset page block, projecting covers, rounded spine and retaining strap")

    def finish(self):
        import bpy
        mesh=bpy.data.meshes.new(self.asset_id+"_TailoredConstruction")
        mesh.from_pydata(self.vertices,[],self.faces)
        mesh.update()
        uv=mesh.uv_layers.new(name="UVMap")
        ob=bpy.data.objects.new(self.asset_id+"_TailoredConstruction",mesh)
        bpy.context.collection.objects.link(ob)
        for material in self.materials:
            mesh.materials.append(material)
        for polygon,material in zip(mesh.polygons,self.material_ids):
            polygon.material_index=0
            polygon.use_smooth=True
            for loop in polygon.loop_indices:
                uv.data[loop].uv=((material+.5)/len(PALETTE),.5)
        for name in {key for weights in self.weights for key in weights}:
            group=ob.vertex_groups.new(name=name)
            for i,weights in enumerate(self.weights):
                if name in weights:
                    group.add([i],weights[name],"REPLACE")
        # Join into the original skinned assembly: no separate runtime objects.
        bpy.ops.object.select_all(action="DESELECT")
        self.body.select_set(True)
        ob.select_set(True)
        bpy.context.view_layer.objects.active=self.body
        bpy.ops.object.join()
        return len(self.vertices),len(self.faces)


def render_views(asset_id, body, rig, folder):
    import bpy
    from mathutils import Vector, Matrix
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.render.resolution_x,scene.render.resolution_y=640,800
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.film_transparent=False
    scene.display.shading.light="STUDIO"
    scene.display.shading.studio_light="paint.sl"
    scene.display.shading.color_type="TEXTURE"
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type="WORLD"
    scene.display.shading.curvature_ridge_factor=1.1
    scene.display.shading.curvature_valley_factor=.8
    scene.display.shading.show_specular_highlight=True
    scene.display.shading.background_type="WORLD"
    scene.world.color=(.055,.063,.07)
    scene.view_settings.view_transform="Standard"
    # Existing source uses a T-pose. Lower arms only for neutral review views.
    posed=[]
    for name,angle in (("upperarm_l",math.radians(65)),("upperarm_r",math.radians(-65))):
        bone=rig.pose.bones.get(name)
        if bone:
            original=bone.matrix.copy()
            pivot=rig.matrix_world@bone.head
            rotation=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,"Y")@Matrix.Translation(-pivot)
            bone.matrix=rig.matrix_world.inverted()@rotation@rig.matrix_world@original
            posed.append((bone,original))
    bpy.context.view_layer.update()
    camera_data=bpy.data.cameras.new("RefinementReviewCamera")
    camera=bpy.data.objects.new("RefinementReviewCamera",camera_data)
    scene.collection.objects.link(camera)
    scene.camera=camera
    camera_data.type="ORTHO"
    camera_data.ortho_scale=2.13
    target=Vector((0,0,.93))
    scene.render.use_stamp=True
    scene.render.use_stamp_date=False
    scene.render.use_stamp_time=False
    scene.render.use_stamp_render_time=False
    scene.render.use_stamp_frame=False
    scene.render.use_stamp_filename=False
    scene.render.use_stamp_scene=False
    scene.render.use_stamp_camera=False
    scene.render.use_stamp_note=True
    scene.render.stamp_note_text=asset_id+" | authored costume refinement | studio texture preview"
    scene.render.stamp_font_size=11
    for name,position in (("front",(0,-4,1.3)),("side",(4,0,1.3)),("rear",(0,4,1.3)),("quarter",(2.7,-3.2,1.6))):
        camera.location=position
        camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=str(folder/(name+".png"))
        bpy.ops.render.render(write_still=True)
    for bone,matrix in posed:
        bone.matrix=matrix
    bpy.context.view_layer.update()


def author(asset_id, source_baseline=None):
    import bpy
    row,current=read_asset(asset_id)
    if source_baseline:
        current=Path(source_baseline).resolve()
        if not current.is_file():
            raise ValueError("Explicit preserved baseline is unavailable: "+str(current))
    before_sha=digest(current)
    previous_receipt=EVIDENCE_ROOT/asset_id/"candidate.json"
    if previous_receipt.exists():
        original_sha=json.loads(previous_receipt.read_text())["before"]["sha256"]
        if before_sha!=original_sha:
            raise ValueError("Canonical source changed after dated baseline; refuse double refinement. Use --consolidate or the preserved original source.")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(current))
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    if len(rigs)!=1:
        raise ValueError("Require one authoritative human rig")
    rig=rigs[0]
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and len(o.data.materials)>0 and any(m.type=="ARMATURE" for m in o.modifiers)]
    if not meshes:
        raise ValueError("Require canonical skinned human geometry")
    body=max(meshes,key=lambda ob:len(ob.data.vertices))
    source_bones=[b.name for b in rig.data.bones]
    source_actions=[a.name for a in bpy.data.actions]
    source_vertex_count=len(body.data.vertices)
    source_polygon_count=len(body.data.polygons)
    original_coordinates=[vertex.co.copy() for vertex in body.data.vertices]
    source_surfaces=[]
    from mathutils import Vector
    for mesh in meshes:
        points=[mesh.matrix_world@Vector(corner) for corner in mesh.bound_box]
        source_surfaces.append({"mesh":mesh.name,"vertices":len(mesh.data.vertices),"polygons":len(mesh.data.polygons),
            "materials":[material.name for material in mesh.data.materials],
            "bounds":[[min(point[i] for point in points) for i in range(3)],[max(point[i] for point in points) for i in range(3)]]})
    inspect_folder=EVIDENCE_ROOT/asset_id
    inspect_folder.mkdir(parents=True,exist_ok=True)
    if not (inspect_folder/"before_inspection.json").exists():
        (inspect_folder/"before_inspection.json").write_text(json.dumps({"id":asset_id,"current":str(current),"sha256":before_sha,"source_surfaces":source_surfaces,"actions":source_actions},indent=2)+"\n")
    tailor=Tailor(body,rig,asset_id)
    if asset_id=="P01":
        tailor.border(["MI_Ranger"],1.09,1.60,xmax=.28,radius=.0018,mat=0)
        tailor.pouch(.115,1.075,width=.105,height=.135,front=False)
        # Small matched shoulder rivets anchor the existing cowl; no new armor.
        for x in (-.155,.155):
            tailor.stud(tailor.point(x,1.48,True,.005),radius=.004)
        tailor.changes.append("Two recessed aged-brass shoulder fasteners on the existing ranger cowl")
    elif asset_id=="C01":
        tailor.border(["Review_body"],1.22,1.51,xmax=.25,radius=.0018,mat=5)
        tailor.pouch(.132,1.035,width=.074,height=.106,front=True)
        for x in (-.027,.027):
            tailor.stud(tailor.point(x,1.42,True,.0035),radius=.0032,mat=2,bone="spine_03")
        tailor.changes.append("Paired small shawl fastening pins; preserved retained facial study, brows, hair and bell")
    elif asset_id=="C02":
        tailor.border(["MI_Peasant","AuthoredClothes"],1.10,1.58,xmax=.29,radius=.0018,mat=0)
        from mathutils import Vector
        center=tailor.point(.125,1.205,False,.034)
        tailor.cylinder(center+Vector((0,0,-.11)),center+Vector((0,0,.11)),radius=.026,mat=0,bone="spine_01")
        for height in (-.08,.08):
            tailor.cylinder(center+Vector((0,0,height-.006)),center+Vector((0,0,height+.006)),radius=.028,mat=2,bone="spine_01")
        tailor.cylinder(center+Vector((0,0,.11)),center+Vector((0,0,.128)),radius=.021,mat=4,bone="spine_01")
        for height in (-.065,.065):
            a=tailor.point(.095,1.205+height,False,.004)
            b=center+Vector((-.03,.028,height))
            c=tailor.point(.155,1.205+height,False,.004)
            tailor.ribbon((a,b,c),width=.016,bone="spine_01")
        tailor.changes.append("Fitted cylindrical map case behind the belt, with linen roll, two brass end bands and leather retaining straps")
    elif asset_id=="C03":
        tailor.border(["MI_Peasant","AuthoredClothes"],1.23,1.58,xmax=.27,radius=.0018,mat=0)
        tailor.patch(.077,1.115,.082,.105,mat=0,bone="spine_01")
        tailor.herb_bundle(-.085,1.095,bone="spine_01")
        for x in (-.125,.125):
            tailor.stud(tailor.point(x,1.40,True,.005),radius=.0035,mat=2,bone="spine_03")
        tailor.changes.append("Shaped leather apron pocket with rounded stitched edge and paired riveted apron anchors")
    elif asset_id=="C04":
        tailor.border(["MI_Peasant","AuthoredClothes"],1.29,1.58,xmax=.28,radius=.002,mat=0)
        tailor.patch(0,1.075,.16,.105,mat=0,bone="spine_01")
        from mathutils import Vector
        keeper=tailor.point(-.16,1.05,True,.025)
        # Slim closed tongs hang from a sewn work-apron keeper.
        for side in (-1,1):
            tailor.cylinder(keeper+Vector((side*.007,-.006,-.12)),keeper+Vector((side*.004,-.006,.07)),radius=.004,mat=3,bone="pelvis",sides=8)
            tailor.tube((keeper+Vector((side*.004,-.006,.07)),keeper+Vector((side*.02,-.006,.10)),keeper+Vector((side*.027,-.006,.092))),radius=.004,mat=3,bone="pelvis")
        tailor.stud(keeper+Vector((0,-.012,.045)),radius=.005,mat=3,bone="pelvis")
        tailor.ribbon((keeper+Vector((-.022,0,.018)),keeper+Vector((.022,0,.018))),width=.02,bone="pelvis")
        for x in (-.125,.125):
            tailor.stud(tailor.point(x,1.355,True,.005),radius=.0045,mat=3,bone="spine_03")
        tailor.changes.append("Smith's stitched work pocket, reinforced apron anchors and compact forged tongs secured through a leather keeper")
    elif asset_id=="C05":
        tailor.border(["AuthoredClothes"],1.23,1.52,xmax=.28,radius=.0017,mat=4)
        chain=[]
        for i in range(17):
            x=-.075+.15*i/16
            z=1.385-.035*math.sin(math.pi*i/16)
            chain.append(tailor.point(x,z,True,.005))
        tailor.tube(chain,radius=.0016,mat=2,bone="spine_03")
        for x in (-.075,.075):
            tailor.brooch(x,1.385,radius=.010)
        tailor.patch(-.135,.69,.07,.08,mat=0)
        tailor.changes.append("Paired small shawl brooches with a sagging bronze closure chain; stitched modest skirt repair patch")
    elif asset_id=="C06":
        tailor.border(["MI_Peasant","AuthoredClothes"],1.10,1.58,xmax=.29,radius=.0017,mat=0)
        tailor.pouch(.13,1.045,width=.097,height=.13,front=True,mat=4)
        from mathutils import Vector
        tie=tailor.point(.13,1.125,True,.043)
        for sign in (-1,1):
            tailor.tube((tie,tie+Vector((sign*.018,-.001,-.016)),tie+Vector((sign*.012,-.002,-.036))),radius=.0015,mat=0,bone="pelvis")
        tailor.changes.append("Linen seed bag secured to the rope belt with leather keeper loops and two loose tied cords")
    elif asset_id=="C07":
        tailor.border(["MI_Ranger"],1.09,1.60,xmax=.29,radius=.002,mat=3)
        for side in (-1,1):
            for x,z in ((.13,1.49),(.17,1.47),(.20,1.43)):
                tailor.stud(tailor.point(side*x,z,True,.006),radius=.0045,mat=3)
        tailor.pouch(-.12,1.065,width=.105,height=.12,front=False)
        tailor.changes.append("Six ordered forged-iron cowl rivets, reinforced armor boundaries and a fitted command-kit belt pouch")
    elif asset_id=="C08":
        tailor.border(["AuthoredClothes","MI_Peasant"],1.10,1.58,xmax=.29,radius=.0017,mat=0)
        chain=[]
        for i in range(25):
            x=-.11+.22*i/24
            z=1.425-.065*math.sin(math.pi*i/24)
            chain.append(tailor.point(x,z,True,.006))
        tailor.tube(chain,radius=.0017,mat=2,bone="spine_03")
        tailor.brooch(0,1.36,radius=.016)
        for x in (-.11,.11):
            tailor.stud(tailor.point(x,1.425,True,.007),radius=.004,mat=2,bone="spine_03")
        tailor.changes.append("Restrained chain of office with anchored ends and openwork diamond seal over the oxblood coat")
    elif asset_id=="C09":
        tailor.border(["AuthoredClothes"],.32,1.48,xmax=.19,radius=.0015,mat=4)
        tailor.book(.12,1.06,front=False,width=.105,height=.145)
        for x in (-.11,.11):
            tailor.stud(tailor.point(x,1.405,True,.005),radius=.0035,bone="spine_03")
        tailor.changes.append("Reinforced tabard edges and small shoulder anchors; original key and indigo identity retained")
    elif asset_id=="C10":
        tailor.border(["AuthoredClothes","MI_Peasant"],1.10,1.58,xmax=.30,radius=.0018,mat=0)
        tailor.book(-.12,1.075,front=False,width=.09,height=.125)
        tailor.brooch(-.105,1.415,radius=.012)
        from mathutils import Vector
        keeper=tailor.point(.15,1.12,True,.005)
        tailor.ribbon((keeper+Vector((0,0,.025)),keeper+Vector((0,-.009,-.035))),width=.02,bone="pelvis")
        tailor.changes.append("Steward's small office badge, strapped pocket ledger and a sewn belt keeper above the retained key bunch")
    elif asset_id=="C11":
        tailor.border(["AuthoredClothes"],1.24,1.49,xmax=.27,radius=.0016,mat=4)
        tailor.patch(0,1.075,.15,.095,mat=4)
        waistband=[tailor.point(-.17+.34*i/16,1.16,True,.006) for i in range(17)]
        tailor.ribbon(waistband,width=.017,mat=4)
        for x in (-.13,.13):
            tailor.stud(tailor.point(x,1.36,True,.005),radius=.0035,bone="spine_03")
        tailor.changes.append("Canvas apron work pocket, fitted sewn waist tie and paired reinforced bib anchors; copper braid retained")
    elif asset_id=="C12":
        tailor.border(["AuthoredClothes","MI_Peasant"],1.13,1.56,xmax=.26,radius=.0018,mat=0)
        tailor.pouch(.125,1.055,width=.09,height=.12,front=False)
        for z in (1.12,1.18,1.24):
            for x in (-.025,.025):
                tailor.stud(tailor.point(x,z,True,.0045),radius=.0028,mat=2)
        tailor.brooch(0,1.475,radius=.009)
        tailor.changes.append("Six small fitted bodice lacing eyelets, a scarf fastening and practical rear relief-kit pouch")
    else:
        raise ValueError("Recipe requires individual source inspection: "+asset_id)
    added_vertices,added_faces=tailor.finish()
    if any((body.data.vertices[i].co-point).length>1e-6 for i,point in enumerate(original_coordinates)):
        raise ValueError("Refinement changed an original body vertex")
    folder=EVIDENCE_ROOT/asset_id
    folder.mkdir(parents=True,exist_ok=True)
    model=MODEL_ROOT/(asset_id+"_tailored_v001.blend")
    runtime=RUNTIME_ROOT/current.name
    model.parent.mkdir(parents=True,exist_ok=True)
    runtime.parent.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene
    scene["refinement_source"]=str(current)
    scene["refinement_source_sha256"]=before_sha
    scene["refinement_scope"]="Tailored costume construction. Faces, source palette, bones, rest mesh and clip inventory preserved."
    # Keep only actual exported geometry selected; never export custom shapes.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for image in bpy.data.images:
        if image.has_data and not image.packed_file:
            image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(model))
    bpy.ops.export_scene.gltf(filepath=str(runtime),export_format="GLB",use_selection=True,export_animations=True,export_skins=True,export_rest_position_armature=True,export_apply=False,export_yup=True)
    contract=exported_contract(runtime)
    if [b.name for b in rig.data.bones]!=source_bones or [a.name for a in bpy.data.actions]!=source_actions:
        raise ValueError("Human skeleton or animation inventory changed")
    render_views(asset_id,body,rig,folder)
    candidate={"id":asset_id,"status":"authored_candidate_pending_native_inspection","before":{"path":str(current),"sha256":before_sha,"vertices":source_vertex_count,"polygons":source_polygon_count},
        "source_path":str(model),"runtime_path":str(runtime),"destination_resource":row["destination_resource"],"sha256":digest(runtime),"source_sha256":digest(model),
        "retained_authoring_source":row["source_path"],"retained_runtime_baseline":row["runtime_path"],"inspected_source_surfaces":source_surfaces,
        "changes":tailor.changes,"added_vertices":added_vertices,"added_polygons":added_faces,
        "skeleton_bones_preserved":source_bones,"source_actions_preserved":source_actions,
        "export_contract":contract,"original_vertex_positions_preserved":True,
        "detail_material_surfaces":1,"detail_palette":"112x16 packed authored albedo and ORM; one additional PBR surface; no source material remapping",
        "evidence":{name:str(folder/(name+".png")) for name in ("front","side","rear","quarter")},
        "limits":["Studio texture previews establish costume geometry only; native Godot material/motion and region inspection remain required.","Existing faces, body anatomy and upstream texture resolution retained; no claim of new bespoke animation.","New details use existing bones and join the existing mesh; small material surfaces add bounded draw cost."]}
    (folder/"candidate.json").write_text(json.dumps(candidate,indent=2)+"\n")
    print(json.dumps({"id":asset_id,"runtime":str(runtime),"added_vertices":added_vertices,"changes":tailor.changes}))


def consolidate(asset_id):
    """Losslessly combine dated detail materials; source geometry is untouched."""
    import bpy
    model=MODEL_ROOT/(asset_id+"_tailored_v001.blend")
    folder=EVIDENCE_ROOT/asset_id
    candidate=json.loads((folder/"candidate.json").read_text())
    bpy.ops.wm.open_mainfile(filepath=str(model))
    rig=next(ob for ob in bpy.context.scene.objects if ob.type=="ARMATURE")
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and len(o.data.materials)>0 and any(m.type=="ARMATURE" for m in o.modifiers)]
    labels={label:i for i,(label,*rest) in enumerate(PALETTE)}
    palette=palette_material(asset_id)
    count=0
    for ob in meshes:
        lookup={i:labels[mat.name.removeprefix(asset_id+"_Refined_")] for i,mat in enumerate(ob.data.materials) if mat and mat.name.startswith(asset_id+"_Refined_")}
        if not lookup:
            continue
        index=len(ob.data.materials)
        ob.data.materials.append(palette)
        uv=ob.data.uv_layers.active
        for polygon in ob.data.polygons:
            if polygon.material_index not in lookup:
                continue
            tile=lookup[polygon.material_index]
            for loop in polygon.loop_indices:
                uv.data[loop].uv=((tile+.5)/len(PALETTE),.5)
            polygon.material_index=index
            count+=1
    if not count:
        raise ValueError("No dated multi-material details to consolidate")
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(model))
    runtime=Path(candidate["runtime_path"])
    bpy.ops.export_scene.gltf(filepath=str(runtime),export_format="GLB",use_selection=True,export_animations=True,export_skins=True,export_rest_position_armature=True,export_apply=False,export_yup=True)
    candidate["export_contract"]=exported_contract(runtime)
    candidate["source_sha256"]=digest(model)
    candidate["sha256"]=digest(runtime)
    candidate["detail_material_surfaces"]=1
    candidate["detail_palette"]="112x16 packed authored albedo and ORM; one additional PBR surface; no source material remapping"
    render_views(asset_id,max(meshes,key=lambda ob:len(ob.data.vertices)),rig,folder)
    (folder/"candidate.json").write_text(json.dumps(candidate,indent=2)+"\n")
    print(json.dumps({"id":asset_id,"consolidated_polygons":count,"export_contract":candidate["export_contract"]}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", required=True)
    parser.add_argument("--inspect", action="store_true")
    parser.add_argument("--consolidate", action="store_true")
    parser.add_argument("--source-baseline", help="Explicit preserved original GLB for repairing an integrated candidate; prior before-SHA must match")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None)
    if args.inspect:
        inspect(args.asset)
    elif args.consolidate:
        consolidate(args.asset)
    else:
        author(args.asset,args.source_baseline)


if __name__ == "__main__":
    main()
