"""Fit a CC0 garment topology to C01; preserve editable materials and skin."""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / "upstream/makehuman"
sys.path.insert(0, str(ROOT.parents[0] / "design_pack_v1/tools"))
import build_anwen as shared
sys.path.insert(0, str(ROOT / "tools"))
from anwen_authored_gown import weights as gown_weights


def fit(folder, filename, mode="outer"):
    base = []
    for line in (UP / "base.obj").read_text().splitlines():
        if line.startswith("v "):
            base.append(Vector(tuple(map(float, line.split()[1:]))))
    for filename_target, strength in [("caucasian-female-young.target", .62), ("caucasian-female-old.target", .38)]:
        for line in (UP / filename_target).read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            index, x, y, z = line.split()
            base[int(index)] += Vector((float(x), float(y), float(z))) * strength
    active = False; scales = {}; points = []
    header = (folder / filename).read_text()
    if "# license: CC0" not in header:
        raise RuntimeError("Foundation license not established")
    for line in header.splitlines():
        words = line.split()
        if words and words[0] in ("x_scale", "y_scale", "z_scale"):
            axis = "xyz".index(words[0][0]); a, b = int(words[1]), int(words[2])
            scales[axis] = abs(base[a][axis]-base[b][axis]) / float(words[3])
        if line == "verts 0":
            active = True; continue
        if active and len(words) == 9:
            try:
                ids = [int(v) for v in words[:3]]
                weights = [float(v) for v in words[3:6]]
                offset = Vector(tuple(map(float, words[6:])))
            except ValueError:
                break
            p = sum((base[i]*w for i,w in zip(ids,weights)), Vector())
            p += Vector(tuple(offset[i]*scales[i] for i in range(3)))
            points.append(Vector((p.x*.105, -p.z*.105+.046, p.y*.12+.856)))
        elif active and points:
            break
    obj_name = next(line.split(maxsplit=1)[1] for line in header.splitlines() if line.startswith("obj_file "))
    uvs = []; faces = []
    for line in (folder / obj_name).read_text().splitlines():
        if line.startswith("vt "): uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith("f "):
            faces.append([tuple(int(v)-1 for v in item.split("/")[:2]) for item in line.split()[1:]])
    mesh = bpy.data.meshes.new("Donitz_Retained_Garment_Topology")
    mesh.from_pydata(points, [], [[v for v,_ in f] for f in faces]); mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for polygon, source in zip(mesh.polygons,faces):
        polygon.use_smooth = True
        for loop,(_,index) in zip(polygon.loop_indices,source): uv.data[loop].uv = uvs[index]
    obj = bpy.data.objects.new("Anwen_v034_"+mode, mesh)
    bpy.context.collection.objects.link(obj)
    obj["provenance"] = "Donitz; CC0; suits02; fitted hm08 female age targets; reference-specific alterations"
    if folder.name=="donitz_monk_robe":
        parent=list(range(len(points)))
        def root(i):
            while parent[i]!=i:
                parent[i]=parent[parent[i]];i=parent[i]
            return i
        for face in faces:
            for i,_ in face[1:]:parent[root(i)]=root(face[0][0])
        parts={}
        for i in range(len(points)):parts.setdefault(root(i),[]).append(i)
        keep=set();body=set();arms=[]
        for ids in parts.values():
            if len(ids)==5225:
                body.update(ids)
                if mode!="cape":keep.update(ids)
            elif len(ids)==800:
                arms.append(ids)
                if mode=="outer":keep.update(ids)
            elif len(ids)==2304 and mode=="cape":keep.update(ids)
        assert len(body)==5225 and len(arms)==2,"Upstream robe component layout changed"
        floor=min(mesh.vertices[i].co.z for i in body)
        for i in body:
            p=mesh.vertices[i].co
            if p.z<1.045:p.z=.21+(p.z-floor)/(1.045-floor)*.835
            else:p.z=1.045+(p.z-1.045)*.86
        # Fit each actual sleeve's principal axis and radial offsets, rather
        # than a centreline contaminated by the separate shoulder cape.
        for ids in arms:
            sign=1 if sum(mesh.vertices[i].co.x for i in ids)>0 else -1
            positions=np.array([(abs(mesh.vertices[i].co.x),mesh.vertices[i].co.y,mesh.vertices[i].co.z) for i in ids])
            centre=positions.mean(axis=0);_,axes=np.linalg.eigh(np.cov((positions-centre).T))
            axis=Vector(axes[:,-1]);axis*=1 if axis.x>0 else -1
            front=(Vector((0,1,0))-axis*axis.y).normalized();up=axis.cross(front).normalized()
            cursor=[(Vector(p)-Vector(centre)).dot(axis) for p in positions];lo=min(cursor);hi=max(cursor)
            for i,p,s in zip(ids,positions,cursor):
                q=Vector(p)-Vector(centre)-axis*s;t=(s-lo)/(hi-lo)
                mesh.vertices[i].co=(sign*(.165+.415*t),.055+q.dot(front)*.78,1.418+q.dot(up)*.72)
        bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context="VERTS")
        # Match the underlying diagonals before cutting the outer front. The
        # two independently tessellated non-planar quad shells did not agree.
        bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method="FIXED")
        if mode=="outer":
            for sign in (-1,1):
                bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(sign*.008,0,1.42),plane_no=(sign,0,.025))
            cut=[f for f in bm.faces if (p:=f.calc_center_median()).y<.025 and p.z<1.43 and abs(p.x)<.008+.025*max(0,1.42-p.z)-.00001]
            bmesh.ops.delete(bm,geom=cut,context="FACES")
        loose=[v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm,geom=loose,context="VERTS")
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
        if mode in ("inner","outer"):
            rest=mesh.attributes.new("skin_reference",type="FLOAT_VECTOR",domain="POINT")
            for v,item in zip(mesh.vertices,rest.data):item.vector=v.co
            # Scaling toward a body axis does not inset concave fabric folds.
            # Keep the actual surface correspondence and its normal instead.
            outward=sum(p.normal.dot(Vector((p.center.x,p.center.y-.025,0))) for p in mesh.polygons)
            sign=1 if outward>=0 else -1
            if mode=="inner":
                template=bpy.data.objects.new("Anwen_Hem_Source_NotRuntime",mesh.copy())
                bpy.context.collection.objects.link(template)
                template.hide_render=True;template.hide_set(True);template["review_baseline_only"]=True
                for vertex in mesh.vertices:vertex.co-=vertex.normal*(sign*.008)
            # Game geometry retains exposed linen and a hidden overlap margin,
            # not an independently animated full duplicate inside opaque wool.
            # The complete source layer remains in earlier editable sources.
            bm=bmesh.new();bm.from_mesh(mesh)
            if mode=="inner":
                for sign in (-1,1):
                    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(sign*.020,0,1.42),plane_no=(sign,0,.025))
                hidden=[f for f in bm.faces if not ((p:=f.calc_center_median()).y<.025 and abs(p.x)<.020+.025*max(0,1.42-p.z))]
                bmesh.ops.delete(bm,geom=hidden,context="FACES")
                bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
        elif mode=="cape":
            for v in mesh.vertices:
                p=v.co
                front=max(0,min(1,(-p.y+.015)/.10))
                p.y-=front*(.012*math.exp(-((p.z-1.455-.06*p.x)/.021)**2)+.009*math.exp(-((p.z-1.405-.04*p.x)/.024)**2))
                p.z-=.015*front*max(0,min(1,(abs(p.x)-.09)/.20))
                p.z-=.060*max(0,min(1,(p.z-1.46)/.072))
    return obj


def run():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "models/C01_anwen_review_v027.blend"))
    rig = bpy.data.objects["C01_Anwen_Rig"]
    base = UP / "donitz_robe/clothes"
    robe = fit(base / "donitz_monk_robe", "donitz_monk_robe.mhclo")
    hood = fit(base / "donitz_monk_robe", "donitz_monk_robe.mhclo", "cape")
    lining = fit(base / "donitz_monk_robe", "donitz_monk_robe.mhclo", "inner")
    for obj in (robe,hood,lining):
        print("FOUNDATION_BOUNDS",obj.name,[min(v.co[i] for v in obj.data.vertices) for i in range(3)],[max(v.co[i] for v in obj.data.vertices) for i in range(3)],len(obj.data.vertices),flush=True)
    # Lift the source A-pose sleeves to the retained animation skeleton's rest
    # line without shearing the torso or changing the actor's hand sockets.
    source_arm = [v.co.copy() for v in robe.data.vertices if abs(v.co.x)>.28 and v.co.z>1.1]
    groups = []
    for lo,hi in ((.30,.34),(.45,.49),(.55,.59)):
        samples=[p.z for p in source_arm if lo<abs(p.x)<hi]
        if samples: groups.append(((lo+hi)/2,sum(samples)/len(samples)))
    print("SOURCE_SLEEVE_CENTRES",groups,flush=True)
    bpy.context.view_layer.objects.active=hood
    sub=hood.modifiers.new("Supported cloth tessellation","SUBSURF");sub.subdivision_type="SIMPLE";sub.levels=1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    def garment_weights(p):
        if abs(p.x)<.17 or p.z<1.16:return gown_weights(p)
        side="l" if p.x>0 else "r"
        if abs(p.x)<.22:
            t=max(0,min(1,(abs(p.x)-.17)/.05));return {"spine_03":1-t,"upperarm_"+side:t}
        t=max(0,min(1,(abs(p.x)-.35)/.085));return {"upperarm_"+side:1-t,"lowerarm_"+side:t}
    for obj, material in ((robe,"Anwen_Repaired_Slate_Wool"),(hood,"Anwen_Ash_Wool_Shawl"),(lining,"Anwen_Unbleached_Linen")):
        obj.data.materials.append(bpy.data.materials[material])
        shared.bind(obj,rig,garment_weights if obj==robe else gown_weights)
    # Both layers inherit the exact same original position's skin weights.
    # Recomputing after inset changes the leg blend and makes the liner cross
    # the outer surface even when both rest meshes are correctly nested.
    for layer,weight_function in ((lining,gown_weights),(robe,garment_weights)):
        layer.vertex_groups.clear()
        for vertex,reference in zip(layer.data.vertices,layer.data.attributes["skin_reference"].data):
            values=weight_function(reference.vector);total=sum(values.values())
            for bone,value in values.items():
                if value<=0:continue
                group=layer.vertex_groups.get(bone) or layer.vertex_groups.new(name=bone)
                group.add([vertex.index],value/total,"REPLACE")
    from mathutils.bvhtree import BVHTree
    template=bpy.data.objects["Anwen_Hem_Source_NotRuntime"]
    contour=BVHTree.FromPolygons([v.co for v in template.data.vertices],[list(p.vertices) for p in template.data.polygons])
    verts=[];faces=[];uv=[];refs=[];cols=192;rows=12
    for j in range(cols+1):
        a=math.tau*j/cols;direction=Vector((math.sin(a),-math.cos(a),0));hit=None
        for step in range(46):
            z=.205+.002*step
            origin=Vector((0,.025,z))+direction*.65
            hit,normal,_,_=contour.ray_cast(origin,-direction,.65)
            if hit is not None:break
        if hit is None:raise RuntimeError("Garment hem contour absent at sector "+str(j))
        origin=Vector((0,.025,hit.z+.012))+direction*.65
        support,normal,_,_=contour.ray_cast(origin,-direction,.65)
        if support is not None:hit=support
        ref=hit.copy();start=hit-direction*.006
        for i in range(rows+1):
            t=i/rows;p=start.copy();p+=direction*.002*t;p.z+=.004-.055*t+.0012*math.sin(a*7+.4)*t
            verts.append(tuple(p));refs.append(ref);uv.append((j/cols,t))
            if i and j:
                k=j*(rows+1)+i;faces.append((k-rows-2,k-1,k,k-rows-1))
    hem=shared.mesh_object("Anwen_v040_Contour_Linen_Hem",verts,faces,bpy.data.materials["Anwen_Unbleached_Linen"],uv)
    shared.bind(hem,rig,gown_weights)
    hem.vertex_groups.clear()
    for vertex,ref in zip(hem.data.vertices,refs):
        values=gown_weights(ref);total=sum(values.values())
        for bone,value in values.items():
            if value<=0:continue
            group=hem.vertex_groups.get(bone) or hem.vertex_groups.new(name=bone)
            group.add([vertex.index],value/total,"REPLACE")
    for obj in bpy.data.objects:
        if obj in (robe,hood,lining): continue
        if obj.type=="MESH" and (obj.name in ("Anwen_Wool_ContinuousPattern","Anwen_Linen_ContinuousPattern") or obj.name.startswith(("Anwen_v022_TailoredSleeve_","Anwen_v019_Scarf_Tail","Anwen_v020_Fitted_Scarf_","Anwen_Shawl_Sewn_Edge","Anwen_wool_Stitched_Seam","Anwen_linen_Stitched_Seam"))):
            obj.hide_render=True; obj.hide_set(True)
    tail=bpy.data.objects.get("Anwen_v019_Scarf_Tail")
    if tail:tail.hide_render=False;tail.hide_set(False)
    # The retained anatomy selection included a flat fragment of the former
    # dress hem at the ankles. It is neither a boot nor a body part.
    anatomy=bpy.data.objects["Anwen_Retained_Hands_Boots"]
    bm=bmesh.new();bm.from_mesh(anatomy.data);pending=set(bm.verts);stray=[]
    while pending:
        todo=[pending.pop()];component=[]
        while todo:
            v=todo.pop();component.append(v)
            for edge in v.link_edges:
                other=edge.other_vert(v)
                if other in pending:pending.remove(other);todo.append(other)
        if len(component)==130 and max(v.co.z for v in component)-min(v.co.z for v in component)<.001 and max(v.co.x for v in component)-min(v.co.x for v in component)>.5:
            stray.extend(component)
    if len(stray)!=130:raise RuntimeError("Identified legacy hem fragment changed; inspect instead of deleting anatomy")
    bmesh.ops.delete(bm,geom=stray,context="VERTS");bm.to_mesh(anatomy.data);bm.free()
    bpy.context.view_layer.update()
    # Fit the shawl to the actual posed wool, then return each correction to
    # its own rest-space skin. This changes neither the rig nor the animation.
    evaluated=robe.evaluated_get(bpy.context.evaluated_depsgraph_get())
    posed=evaluated.to_mesh()
    support=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in posed.vertices],[list(p.vertices) for p in posed.polygons])
    evaluated.to_mesh_clear()
    by_group={g.index:g.name for g in hood.vertex_groups}
    fitted=0
    for vertex in hood.data.vertices:
        skin=Matrix(((0,0,0,0),)*4)
        for group in vertex.groups:
            bone=rig.pose.bones.get(by_group[group.group])
            if bone:skin+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight
        if abs(skin.determinant())<1e-9:continue
        rest_to_rig=rig.matrix_world.inverted()@hood.matrix_world
        world=rig.matrix_world@skin@rest_to_rig@vertex.co
        if abs(world.x)<.09:continue
        hit,_,_,_=support.ray_cast(Vector((world.x,world.y,1.75)),Vector((0,0,-1)),.65)
        if hit is None or hit.z+.006<=world.z:continue
        world.z=hit.z+.006
        vertex.co=rest_to_rig.inverted()@skin.inverted()@rig.matrix_world.inverted()@world
        fitted+=1
    hood.data.update()
    print("POSED_SHOULDER_SUPPORT_VERTICES",fitted,flush=True)
    tree=BVHTree.FromPolygons([v.co for v in robe.data.vertices],[list(p.vertices) for p in robe.data.polygons])
    old=bpy.data.objects["Anwen_Wool_ContinuousPattern"]
    old_tree=BVHTree.FromPolygons([v.co for v in old.data.vertices],[list(p.vertices) for p in old.data.polygons])
    for obj in bpy.data.objects:
        if obj.type!="MESH" or not any(tag in obj.name for tag in ("Belt","Buckle","Bell")):continue
        for v in obj.data.vertices:
            p=v.co;direction=Vector((p.x,p.y-.025,0)).normalized()
            if direction.length<.5:continue
            origin=Vector((0,.025,max(1.02,min(1.065,p.z))))
            before,_,_,_=old_tree.ray_cast(origin,direction)
            after,_,_,_=tree.ray_cast(origin,direction)
            if before is not None and after is not None:p+=direction*((after-origin).length-(before-origin).length)
    for obj in bpy.data.objects:
        if obj.type=="MESH" and obj.name.startswith(("Anwen_v022_Visible_DarnedPatch","Anwen_v022_Patch_Thread","Anwen_Handsewn_Repair","Anwen_Repair_Stitch")):
            for v in obj.data.vertices:
                p,n,_,_=tree.find_nearest(v.co);v.co=p+n*.0012
    # Keep the packed old groom as historical source, not an overlapping layer.
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Anwen_Hair_"):bpy.data.objects.remove(obj,do_unlink=True)
    with bpy.data.libraries.load(str(ROOT/"models/C01_anwen_strands_v031.blend"),link=False) as (source,target):
        target.objects=[name for name in source.objects if name.startswith("Anwen_Hair_")]
    for obj in target.objects:
        bpy.context.collection.objects.link(obj);world=obj.matrix_world.copy();obj.parent=rig;obj.matrix_world=world
        for modifier in obj.modifiers:
            if modifier.type=="ARMATURE":modifier.object=rig
    rig["art_status"]="FOUNDATION_FIT_v041_NOT_ACCEPTED"
    for obj in bpy.context.scene.objects:
        if not obj.name.startswith("PREVIEW_Floor"):continue
        for mat in obj.data.materials:
            if mat and mat.use_nodes:
                bsdf=mat.node_tree.nodes.get("Principled BSDF")
                if bsdf:bsdf.inputs["Roughness"].default_value=1;bsdf.inputs["Specular IOR Level"].default_value=0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "models/C01_anwen_foundation_v041.blend"),compress=True)
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=24
    scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    out=ROOT / "evidence/anwen_v041";out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type="ORTHO"
    for label,pos,target,size in [("front",(0,-4,1.2),(0,0,.92),2.12),("rear",(0,4,1.2),(0,0,.92),2.12),("cloth",(.3,-2,1.2),(0,-.02,1.2),.80)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler();cam.data.ortho_scale=size
        scene.render.filepath=str(out/(label+".png"));bpy.ops.render.render(write_still=True)
    print("GARMENT_FOUNDATION_FIT_COMPLETE",flush=True)


if __name__=="__main__":run()
