"""Preserve the brow's own strand UVs instead of a tiny fragmented face bake."""
import bpy
from pathlib import Path
HERE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_likeness_v013.blend'))
mat=bpy.data.materials.new('Anwen_Soft_Brow_Fibers');mat.use_nodes=True
mat.surface_render_method='DITHERED';mat.use_backface_culling=False
n=mat.node_tree.nodes;l=mat.node_tree.links;b=n.get('Principled BSDF')
tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(HERE/'evidence/anwen_v014/Anwen_Brow_Fibers.png'))
l.new(tex.outputs['Color'],b.inputs['Base Color']);l.new(tex.outputs['Alpha'],b.inputs['Alpha'])
b.inputs['Roughness'].default_value=.85;b.inputs['Specular IOR Level'].default_value=.22
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj.name.startswith('Anwen_Brow_v004_'):
        obj.data.materials.clear();obj.data.materials.append(mat)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig['art_status']='REWORK_v014_NOT_ACCEPTED'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_brow_v014.blend'),compress=True)
print('BROW_STRAND_SOURCE_COMPLETE',flush=True)
