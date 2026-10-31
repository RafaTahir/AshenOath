"""Close the anatomical neck gap and construct a continuous wool shawl."""
import bpy,bmesh,math,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared


def neck(head,rig):
    bpy.context.view_layer.objects.active=head
    bpy.ops.object.select_all(action='DESELECT');head.select_set(True)
    bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
    bm=bmesh.new();bm.from_mesh(head.data)
    edges=[e for e in bm.edges if e.is_boundary and all(v.co.z<1.57 for v in e.verts)]
    assert edges,'Expected the source neck boundary'
    neighbours={}
    for e in edges:
        for a,b in ((e.verts[0],e.verts[1]),(e.verts[1],e.verts[0])):
            neighbours.setdefault(a,[]).append(b)
    assert all(len(v)==2 for v in neighbours.values()),'Neck boundary must be a simple ring'
    ordered=[edges[0].verts[0]];previous=None
    while True:
        choices=[v for v in neighbours[ordered[-1]] if v!=previous]
        next_vertex=choices[0]
        if next_vertex==ordered[0]:break
        previous=ordered[-1];ordered.append(next_vertex)
        assert len(ordered)<=len(neighbours),'Broken neck cycle'
    assert len(ordered)==len(neighbours),'Unexpected second neck boundary'
    edge=next(e for e in edges if ordered[0] in e.verts and ordered[1] in e.verts)
    reverse=edge.link_loops[0].vert==ordered[0]
    deform=bm.verts.layers.deform.verify()
    neck_index=head.vertex_groups['neck_01'].index
    spine=head.vertex_groups.get('spine_03') or head.vertex_groups.new(name='spine_03')
    layers=list(bm.loops.layers.uv.values())
    original_uv={v:[v.link_loops[0][layer].uv.copy() for layer in layers] for v in ordered}
    upper=ordered
    for row in range(1,5):
        t=row/4;lower=[]
        for v in ordered:
            a=math.atan2(v.co.x,v.co.y-.020)
            target=Vector((.047*math.sin(a),.020+.041*math.cos(a),1.435))
            p=v.co.lerp(target,t)
            new=bm.verts.new(p)
            for collection in (bm.verts.layers.float,bm.verts.layers.int,bm.verts.layers.float_color,bm.verts.layers.color):
                for layer in collection.values():new[layer]=v[layer]
            new[deform].clear();new[deform][neck_index]=1-t;new[deform][spine.index]=t
            lower.append(new)
        for i in range(len(ordered)):
            j=(i+1)%len(ordered)
            vs=(upper[j],upper[i],lower[i],lower[j]) if reverse else (upper[i],upper[j],lower[j],lower[i])
            face=bm.faces.new(vs);face.material_index=0;face.smooth=True
            for loop in face.loops:
                index=i if loop.vert in (upper[i],lower[i]) else j
                for layer_index,layer in enumerate(layers):
                    uv=original_uv[ordered[index]][layer_index].copy()
                    uv.y-=.006*(t if loop.vert in lower else (row-1)/4)
                    loop[layer].uv=uv
        upper=lower
    bm.normal_update();bm.to_mesh(head.data);bm.free();head.data.update()
    head['neck_repair']='Continuous skinned neck to upper torso; previous open uneven cut removed'
    print('NECK_RING_EXTENDED',len(ordered),flush=True)


def shawl(rig):
    mat=bpy.data.materials['Anwen_Ash_Wool_Shawl']
    for o in list(bpy.data.objects):
        if o.name=='Anwen_Draped_Asymmetric_Shawl' or o.name.startswith('Anwen_Wrapped_Wool_Fold'):
            bpy.data.objects.remove(o,do_unlink=True)
    def weights(p):
        arm=max(0,min(.25,(abs(p.x)-.15)*2.8))
        return {'spine_03':1-arm,'upperarm_l' if p.x>0 else 'upperarm_r':arm}
    for layer in range(2):
        verts=[];faces=[];uv=[];rows=24;cols=96 if layer==0 else 64
        for i in range(rows+1):
            t=i/rows
            for j in range(cols+1):
                a=math.tau*j/cols if layer==0 else -.95+3.25*j/cols
                tt=t if layer==0 else t*.61
                back=max(0,-math.cos(a));front=max(0,math.cos(a))
                rx=.073+.174*math.sin(tt*math.pi/2)
                ry=.069+.099*tt
                z=1.493-tt*(.122+.160*back)
                z+=.005*math.sin(a*4+tt*4)*tt+.003*math.sin(a*13)*tt**5
                z+=.010 if layer else 0
                y=.025-ry*math.cos(a)-(.004*front if layer else 0)
                verts.append((rx*math.sin(a),y,z));uv.append((j/cols,t))
                if i and j:
                    k=i*(cols+1)+j;faces.append((k-cols-2,k-1,k,k-cols-1))
        obj=shared.mesh_object('Anwen_Continuous_Wool_Shawl_'+str(layer),verts,faces,mat,uv)
        shared.bind(obj,rig,weights)
        bpy.context.view_layer.objects.active=obj
        thick=obj.modifiers.new('Wool turned hem','SOLIDIFY');thick.thickness=.0025
        bpy.ops.object.modifier_move_up(modifier=thick.name);bpy.ops.object.modifier_apply(modifier=thick.name)
        edge=[verts[rows*(cols+1)+j] for j in range(cols+1)]
        shared.tube('Anwen_Shawl_Sewn_Edge',edge,[.00075]*len(edge),mat,rig,weights,4)


def append_groom(rig):
    for obj in list(bpy.data.objects):
        if obj.type=='MESH' and obj.name.startswith('Anwen_Hair_v004_'):
            bpy.data.objects.remove(obj,do_unlink=True)
    previous=set(bpy.data.objects)
    with bpy.data.libraries.load(str(HERE/'models/C01_anwen_authored_v008.blend'),link=False) as (source,target):
        target.objects=[name for name in source.objects if name.startswith('Anwen_Hair_v004_')]
    for obj in target.objects:
        if obj is None:continue
        bpy.context.collection.objects.link(obj)
        obj.parent=rig
        for modifier in obj.modifiers:
            if modifier.type=='ARMATURE':modifier.object=rig
    for obj in list(bpy.data.objects):
        if obj not in previous and obj.type=='ARMATURE':bpy.data.objects.remove(obj,do_unlink=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_draped_v005.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    neck(bpy.data.objects['Anwen_MatureFace_Neck'],rig);shawl(rig);append_groom(rig)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_continuous_v009.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v009';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO'
    for label,pos,target,size in [('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('face',(.8,-2,1.70),(0,-.015,1.666),.37),
                                  ('front',(0,-4,1.2),(0,0,.92),2.12),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('NECK_AND_SHAWL_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
