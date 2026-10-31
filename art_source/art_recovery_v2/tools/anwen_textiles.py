"""Apply credited fabric foundations without changing the authored palette."""
import bpy,math
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
UP=HERE/'upstream/polyhaven'


def textile(mat,asset,palette):
    mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
    out=nodes.new('ShaderNodeOutputMaterial');b=nodes.new('ShaderNodeBsdfPrincipled')
    links.new(b.outputs[0],out.inputs['Surface'])
    b.inputs['Sheen Weight'].default_value=.13
    b.inputs['Specular IOR Level'].default_value=.25
    coords=nodes.new('ShaderNodeTexCoord')
    physical=nodes.new('ShaderNodeVectorMath');physical.operation='SCALE';physical.inputs[3].default_value=1/.27
    links.new(coords.outputs['Object'],physical.inputs[0])
    textures={}
    for channel in ('diff','rough','disp'):
        image=bpy.data.images.load(str(UP/asset/(asset+'_'+channel+'_1k.png')),check_existing=True)
        if channel!='diff':image.colorspace_settings.name='Non-Color'
        tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.projection='BOX';tex.projection_blend=.20
        links.new(physical.outputs[0],tex.inputs['Vector']);textures[channel]=tex
    pixels=np.asarray(textures['diff'].image.pixels[:],dtype=np.float32).reshape(-1,4)
    mean=float(np.mean(pixels[:,:3]@np.array([.2126,.7152,.0722])))
    grey=nodes.new('ShaderNodeRGBToBW');links.new(textures['diff'].outputs['Color'],grey.inputs[0])
    value=nodes.new('ShaderNodeMath');value.operation='MULTIPLY';value.inputs[1].default_value=1/max(.001,mean)
    links.new(grey.outputs[0],value.inputs[0])
    tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
    tint.inputs[1].default_value=(*palette,1)
    links.new(value.outputs[0],tint.inputs[2]);links.new(tint.outputs[0],b.inputs['Base Color'])
    rough=nodes.new('ShaderNodeMath');rough.operation='MULTIPLY_ADD';rough.inputs[1].default_value=.25;rough.inputs[2].default_value=.70
    links.new(textures['rough'].outputs['Color'],rough.inputs[0]);links.new(rough.outputs[0],b.inputs['Roughness'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00018 if asset=='caban' else .00026
    bump.inputs['Strength'].default_value=.65
    links.new(textures['disp'].outputs['Color'],bump.inputs['Height']);links.new(bump.outputs[0],b.inputs['Normal'])
    mat['foundation']='Poly Haven '+asset+'; colormass / Rico Cilliers; CC0; authored palette and application'


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_groomed_v015.blend'))
    for mat in bpy.data.materials:
        if mat.name.startswith('Anwen_Repaired_Slate_Wool'):textile(mat,'caban',(.022,.033,.045))
        elif mat.name.startswith('Anwen_Ash_Wool_Shawl'):textile(mat,'caban',(.014,.014,.013))
        elif mat.name.startswith('Anwen_Unbleached_Linen'):textile(mat,'rough_linen',(.28,.24,.18))
        elif mat.name.startswith('Anwen_Repair_Older_Slate_Wool'):textile(mat,'caban',(.016,.025,.036))
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    coil=[o for o in bpy.data.objects if o.type=='MESH' and '_PinnedPlait_' in o.name]
    points=[v.co for o in coil for v in o.data.vertices]
    center_z=(min(p.z for p in points)+max(p.z for p in points))/2
    hit,_,_,_=tree.ray_cast(Vector((0,.5,center_z)),Vector((0,-1,0)))
    assert hit is not None
    shift=hit.y+.001-min(p.y for p in points)
    for obj in coil:
        for v in obj.data.vertices:v.co.y+=shift
        obj.data.update()
    print('MEASURED_BUN_CONTACT_SHIFT',shift,flush=True)
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig['art_status']='REWORK_v016_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_textiles_v016.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v016';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO'
    for label,pos,target,size in [('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('cloth_detail',(.3,-2,1.2),(0,-.02,1.13),.75),
                                  ('profile',(2,0,1.70),(0,0,1.666),.38),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('TEXTILE_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
