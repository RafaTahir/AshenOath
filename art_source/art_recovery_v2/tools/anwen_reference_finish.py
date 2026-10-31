"""C01-only reference sculpt and mesh-card groom; no production registration."""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parents[0]/"design_pack_v1/tools"))
import build_anwen as shared

bpy.ops.wm.open_mainfile(filepath=str(ROOT/"models/C01_anwen_foundation_v041.blend"))
rig=bpy.data.objects["C01_Anwen_Rig"]
head=bpy.data.objects["Anwen_MatureFace_Neck"]
old_tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
keys=head.data.shape_keys.key_blocks
basis=keys[0]
mixed=[v.co.copy() for v in basis.data]
for key in list(keys)[1:]:
    if key.value==0 or key.mute:continue
    for p,a,b in zip(mixed,key.data,key.relative_key.data):p+=(a.co-b.co)*key.value
sculpt=head.shape_key_add(name="Anwen_v042_Orbital_Fatigue",from_mix=False)
sculpt.value=1
for index,p in enumerate(mixed):
    x,y,z=p;side=1 if x>=0 else -1
    front=max(0,min(1,(-y-.02)/.07))
    ridge=math.exp(-((x-side*.029)/.027)**2-((z-1.688)/.008)**2)*front
    lower=math.exp(-((abs(x)-.031)/.023)**2-((z-1.650)/.0027)**2)*front
    crease=0
    for slope in (-.36,-.02,.32):
        u=(abs(x)-.048)/.023
        if 0<u<1:
            line=1.661+slope*(abs(x)-.048)
            crease+=.00032*math.exp(-((z-line)/.00085)**2)*math.sin(u*math.pi)*front
    # A delta relative to Basis avoids applying every existing sculpt twice.
    sculpt.data[index].co=basis.data[index].co+Vector((0,-.0016*ridge-.0007*lower+crease,0))
head.data.update();bpy.context.view_layer.update()
tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
for obj in bpy.data.objects:
    if obj.type!="MESH" or not obj.name.startswith("Anwen_Brow_"):continue
    for vertex in obj.data.vertices:
        p=vertex.co;origin=Vector((p.x,-.5,p.z))
        before,_,_,_=old_tree.ray_cast(origin,Vector((0,1,0)))
        after,_,_,_=tree.ray_cast(origin,Vector((0,1,0)))
        if before is not None and after is not None:p.y+=after.y-before.y
    obj.data.update()
for obj in bpy.data.objects:
    if obj.type=="MESH" and obj.name.startswith("Anwen_EyeCorrected_"):
        colors=obj.data.color_attributes.get("IrisFibers")
        if colors:
            for item in colors.data:
                c=item.color;item.color=(c[0]*.75,c[1]*.70,c[2]*.65,c[3])

image=bpy.data.images.load(str(ROOT/"materials/anwen_groom_v029.png"),check_existing=True)
material=bpy.data.materials.new("Anwen_v042_Cutout_AshGrey_Strands");material.use_nodes=True
material.surface_render_method="DITHERED";material.use_backface_culling=False
nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get("Principled BSDF")
tex=nodes.new("ShaderNodeTexImage");tex.image=image
tint=nodes.new("ShaderNodeMixRGB");tint.blend_type="MULTIPLY";tint.inputs[0].default_value=1;tint.inputs[2].default_value=(.72,.72,.70,1)
links.new(tex.outputs["Color"],tint.inputs[1]);links.new(tint.outputs[0],bsdf.inputs["Base Color"])
links.new(tex.outputs["Alpha"],bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value=.74;bsdf.inputs["Specular IOR Level"].default_value=.28

guide=bpy.data.objects["Anwen_Hair_v030_AuthoredStrands"]
guide.hide_render=True;guide.hide_set(True);guide["review_baseline_only"]=True
selections=list(range(0,7200,90))+list(range(7200,9600,60))+list(range(9600,16400,114))+list(range(16400,16580,15))
rng=random.Random(4227);verts=[];faces=[];uv=[];normal_rows=[];across=2;rows=16
for ordinal,index in enumerate(selections):
    points=[guide.matrix_world@p.co.xyz for p in guide.data.splines[index].points]
    centres=[];normals=[]
    for row in range(rows+1):
        t=row/rows;cursor=t*(len(points)-1);lo=int(cursor);hi=min(lo+1,len(points)-1)
        p=points[lo].lerp(points[hi],cursor-lo)
        hit,n,_,_=tree.find_nearest(p)
        angle=math.atan2(p.x,.012-p.y)
        volume=.003+.010*(.5+.5*math.sin(angle*5.3+p.y*35))**2
        part=math.exp(-((p.x+.008)/.007)**2)
        crown=max(0,min(1,(p.z-1.66)/.12))
        p+=n*volume*math.sin(t*math.pi)**.65*crown*(1-.7*part)
        centres.append(p);normals.append(n)
    width=rng.uniform(.0057,.0078) if index<16400 else rng.uniform(.0008,.0018)
    start=len(verts);column=ordinal%4
    for row,(p,n) in enumerate(zip(centres,normals)):
        t=row/rows;tangent=centres[min(row+1,rows)]-centres[max(0,row-1)]
        lateral=tangent.cross(n).normalized()
        w=width*(.35+.65*math.sin(math.pi*(.06+.9*t))**.4)*(1-.60*t**7)
        for j in range(across+1):
            u=j/across;v=2*u-1
            verts.append(tuple(p+lateral*w*v+n*(1-v*v)*w*.12))
            uv.append(((column+.02+.96*u)/4,.015+.97*t));normal_rows.append(n)
            if row and j:
                k=start+row*(across+1)+j;faces.append((k-across-2,k-1,k,k-across-1))
cards=shared.mesh_object("Anwen_Hair_v042_CardGroom",verts,faces,material,uv)
for polygon in cards.data.polygons:
    if polygon.normal.dot(normal_rows[polygon.vertices[0]])<0:polygon.flip()
shared.bind(cards,rig,lambda p:{"Head":1})
cards["source"]="Authored meshes follow retained combed guides; no opaque cap; four-clump diffuse/alpha atlas"
for obj in bpy.data.objects:
    if obj.type!="MESH" or not obj.name.startswith("Anwen_Hair_") or obj==cards:continue
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:continue
        b=mat.node_tree.nodes.get("Principled BSDF")
        if b:b.inputs["Base Color"].default_value=(.072,.066,.052,1);b.inputs["Roughness"].default_value=.78

rig["art_status"]="REFERENCE_REWORK_v042_NOT_ACCEPTED"
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"models/C01_anwen_reference_v042.blend"),compress=True)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=32
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
camera=scene.camera;camera.data.type="ORTHO"
out=ROOT/"evidence/anwen_v042";out.mkdir(parents=True,exist_ok=True)
for label,position,target,size in [("face",(.8,-2,1.70),(0,0,1.666),.38),("face_side",(2,0,1.70),(0,0,1.666),.38),("rear_face",(0,2,1.70),(0,0,1.70),.38),("quarter",(2.5,-4,1.6),(0,0,.95),2.12)]:
    camera.location=position;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler();camera.data.ortho_scale=size
    scene.render.filepath=str(out/(label+".png"));bpy.ops.render.render(write_still=True)
print("REFERENCE_SOURCE_COMPLETE",len(selections),"mesh cards",flush=True)
