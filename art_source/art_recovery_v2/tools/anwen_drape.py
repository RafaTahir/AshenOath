"""Offline cloth settling and garment repair on an isolated Anwen source copy."""
import bpy,bmesh,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared


def collision(obj):
    obj.modifiers.new('Offline garment collision','COLLISION')
    obj.collision.thickness_outer=.003
    obj.collision.thickness_inner=.001


def settle_coat(rig):
    pieces=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Anwen_wool_Gore_')]
    for obj in pieces:
        # This source pattern has 48x16 authored quads before Solidify. Keep
        # those exact faces; a radial-normal test incorrectly removes deep
        # outward folds as well as the back shell.
        assert len(obj.data.polygons)>=48*16*2
        bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=list(bm.faces)[48*16:],context='FACES')
        bm.to_mesh(obj.data);bm.free();obj.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:obj.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]
    bpy.ops.object.join();coat=bpy.context.object;coat.name='Anwen_Wool_Draped_Gown'
    bm=bmesh.new();bm.from_mesh(coat.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00015)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(coat.data);bm.free();coat.data.update()
    cloth_pin=coat.vertex_groups.new(name='Offline_Drape_Pins')
    for v in coat.data.vertices:
        z=v.co.z
        pin=max(0,min(1,(z-1.405)/.035))
        pin=max(pin,math.exp(-((z-1.045)/.018)**4))
        if pin>.001:cloth_pin.add([v.index],pin,'REPLACE')
    hidden=[]
    lining=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Anwen_linen_Gore_')]
    for obj in lining:collision(obj)
    mat=shared.material('Offline_Collider_Not_Exported',(.1,.1,.1),1)
    for side in (-1,1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=12,location=(side*.082,.015,.58))
        body=bpy.context.object;body.name='OFFLINE_LEG_COLLIDER'
        body.scale=(.075,.095,.43);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        collision(body);body.hide_render=True;hidden.append(body)
    body=shared.garment('OFFLINE_TORSO_COLLIDER',[(.90,.13,.095,.025),(1.04,.145,.11,.025),(1.25,.16,.11,.025),(1.43,.16,.08,.025)],mat,rig,count=32,folds=0)
    collision(body);body.hide_render=True;hidden.append(body)
    armature=next(m for m in coat.modifiers if m.type=='ARMATURE')
    armature.show_viewport=False
    cloth=coat.modifiers.new('Gravity settled wool pattern','CLOTH')
    bpy.context.view_layer.objects.active=coat
    while coat.modifiers.find(cloth.name)>0:
        bpy.ops.object.modifier_move_up(modifier=cloth.name)
    s=cloth.settings;s.quality=8;s.mass=.28
    s.tension_stiffness=80;s.compression_stiffness=50;s.shear_stiffness=35;s.bending_stiffness=1.8
    s.vertex_group_mass=cloth_pin.name;s.pin_stiffness=1.0
    cloth.collision_settings.collision_quality=3
    cloth.collision_settings.distance_min=.003
    cloth.collision_settings.use_self_collision=True
    cloth.collision_settings.self_distance_min=.003
    cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=100
    for frame in range(1,101):
        bpy.context.scene.frame_set(frame)
        bpy.context.evaluated_depsgraph_get().update()
        if frame%20==0:print('CLOTH_SETTLE',frame,flush=True)
    bpy.context.view_layer.objects.active=coat
    bpy.ops.object.modifier_apply(modifier=cloth.name)
    armature.show_viewport=True
    # Offline construction only: remove collider objects and the temporary pin
    # group. Runtime deformation remains owned by the existing skeleton.
    for obj in hidden:bpy.data.objects.remove(obj,do_unlink=True)
    for obj in lining:
        for mod in list(obj.modifiers):
            if mod.type=='COLLISION':obj.modifiers.remove(mod)
    pin=coat.vertex_groups.get('Offline_Drape_Pins')
    if pin is not None:coat.vertex_groups.remove(pin)
    low=min(v.co.z for v in coat.data.vertices)
    assert low>.07,'Settled gown must remain above the floor'
    assert all(v.co.length<3 for v in coat.data.vertices),'Unstable cloth simulation'
    solid=coat.modifiers.new('Turned wool edge','SOLIDIFY');solid.thickness=.002
    bpy.ops.object.modifier_move_up(modifier=solid.name)
    bpy.ops.object.modifier_apply(modifier=solid.name)
    # Existing seam threads must follow the new fabric rather than float at
    # their previous analytical locations.
    tree=BVHTree.FromObject(coat,bpy.context.evaluated_depsgraph_get())
    for obj in [o for o in bpy.data.objects if o.name.startswith('Anwen_wool_Stitched_Seam')]:
        for v in obj.data.vertices:
            hit,normal,_,distance=tree.find_nearest(v.co)
            if distance<.04:v.co=hit+normal*.0004
        obj.data.update()
    bpy.context.scene.frame_set(1)
    return coat


def collar(rig):
    previous=bpy.data.objects.get('Anwen_Linen_Open_Collar')
    mat=previous.data.materials[0]
    bpy.data.objects.remove(previous,do_unlink=True)
    verts=[];faces=[];uv=[];rows=10;cols=64
    for i in range(rows+1):
        t=i/rows
        for j in range(cols+1):
            a=.22+(math.tau-.44)*j/cols
            roll=.004*math.sin(t*math.pi)
            z=1.443+.053*t-.012*max(0,math.cos(a))*t
            verts.append(((.058+roll)*math.sin(a),.025-(.053+roll)*math.cos(a),z))
            uv.append((j/cols,t))
            if i and j:
                k=i*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
    obj=shared.mesh_object('Anwen_Linen_Rolled_Collar',verts,faces,mat,uv)
    shared.bind(obj,rig,lambda p:{'neck_01':.20,'spine_03':.80})
    thick=obj.modifiers.new('Linen folded edge','SOLIDIFY');thick.thickness=.0015
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_move_up(modifier=thick.name);bpy.ops.object.modifier_apply(modifier=thick.name)


def repairs(coat,rig):
    tree=BVHTree.FromObject(coat,bpy.context.evaluated_depsgraph_get())
    mat=coat.data.materials[0].copy();mat.name='Anwen_Repair_Older_Slate_Wool'
    for node in mat.node_tree.nodes:
        if node.type=='VALTORGB':
            for e in node.color_ramp.elements:
                e.color=(e.color[0]*.70,e.color[1]*.75,e.color[2]*.8,1)
    thread=shared.material('Anwen_Repair_Thread',(.19,.17,.13),.95)
    for index,(x,z,w,h) in enumerate([(-.115,.70,.065,.08),(.147,.36,.06,.045)]):
        verts=[];faces=[];uv=[];rows=10;cols=10
        for i in range(rows+1):
            for j in range(cols+1):
                xx=x+(j/cols-.5)*w;zz=z+(i/rows-.5)*h
                hit,normal,_,_=tree.ray_cast(Vector((xx,-.5,zz)),Vector((0,1,0)))
                assert hit is not None,'Repair must sit on existing cloth'
                verts.append(tuple(hit+normal*.0012));uv.append((j/cols,i/rows))
                if i and j:
                    k=i*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
        obj=shared.mesh_object('Anwen_Handsewn_Repair_'+str(index),verts,faces,mat,uv)
        shared.bind(obj,rig,shared.body_weights)
        for edge in ([verts[j] for j in range(cols+1)], [verts[rows*(cols+1)+j] for j in range(cols+1)],
                     [verts[i*(cols+1)] for i in range(rows+1)], [verts[i*(cols+1)+cols] for i in range(rows+1)]):
            for a,b in zip(edge,edge[1:]):
                start=Vector(a).lerp(Vector(b),.1)+Vector((0,-.0006,0))
                end=Vector(a).lerp(Vector(b),.65)+Vector((0,-.0006,0))
                shared.tube('Anwen_Repair_Stitch',[start,end],[.0004,.0004],thread,rig,shared.body_weights,3)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_full_v004.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    coat=settle_coat(rig);collar(rig);repairs(coat,rig)
    for mat in bpy.data.materials:
        if 'Dull_Bell_Bronze' in mat.name:
            b=mat.node_tree.nodes.get('Principled BSDF')
            b.inputs['Base Color'].default_value=(.16,.145,.11,1)
            b.inputs['Roughness'].default_value=.62
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_draped_v005.blend'),compress=True)
    print('DRAPED_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
