"""Anwen's authored swept card groom, not the rejected borrowed silhouette."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
import anwen_finish_v004 as author


def material():
    m=author.shared.material('Anwen_Authored_Ash_Strands',(.17,.16,.14),.78)
    nodes=m.node_tree.nodes;links=m.node_tree.links;b=nodes.get('Principled BSDF')
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(HERE/'evidence/anwen_v007/Anwen_Authored_AshStrands.png'))
    links.new(tex.outputs['Color'],b.inputs['Base Color'])
    links.new(tex.outputs['Alpha'],b.inputs['Alpha'])
    b.inputs['Specular IOR Level'].default_value=.28
    m.surface_render_method='DITHERED';m.use_backface_culling=False
    return m


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_draped_v005.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    for obj in list(bpy.data.objects):
        if obj.type=='MESH' and obj.name.startswith('Anwen_Hair_v004_'):
            bpy.data.objects.remove(obj,do_unlink=True)
    m=material();author.groom(head,rig,card_material=m)
    braid=m.copy();braid.name='Anwen_Ash_Plait_Fibers'
    b=braid.node_tree.nodes.get('Principled BSDF')
    for link in list(b.inputs['Alpha'].links):braid.node_tree.links.remove(link)
    b.inputs['Alpha'].default_value=1
    for index,obj in enumerate([o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Anwen_Hair_v004_')]):
        if 'PinnedPlait' in obj.name:
            obj.data.materials[0]=braid
        elif 'FittedRoots' not in obj.name:
            for uv in obj.data.uv_layers.active.data:uv.uv.x=(uv.uv.x+index%4)/4
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_authored_v008.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    cam=scene.camera;cam.data.type='ORTHO';out=HERE/'evidence/anwen_v008';out.mkdir(parents=True,exist_ok=True)
    for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,-.015,1.666),.37),
                                  ('rear_face',(0,2,1.70),(0,.015,1.666),.37),
                                  ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('front',(0,-4,1.2),(0,0,.92),2.12),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('AUTHORED_GROOM_COMPLETE',flush=True)


if __name__=='__main__':main()
