"""Read-only source inventory; Blender background, no asset generation."""
import bpy, json
from pathlib import Path
root = Path(__file__).resolve().parents[3]
out = Path('D:/Temp/AshenOath/art_recovery_v2')
out.mkdir(parents=True, exist_ok=True)
records = {}
for source in sorted((root/'art_source/design_pack_v1/models').glob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    records[source.stem] = {
        'source': str(source),
        'meshes': [{'name':o.name, 'vertices':len(o.data.vertices),
                    'materials':[m.name for m in o.data.materials if m],
                    'bounds':[list(min(v.co[i] for v in o.data.vertices) for i in range(3)),
                              list(max(v.co[i] for v in o.data.vertices) for i in range(3))],
                    'modifiers':[(m.name,m.type) for m in o.modifiers]}
                   for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('PREVIEW')],
        'rigs':[{'name':o.name,'bones':len(o.data.bones), 'pose':o.data.pose_position}
                for o in bpy.data.objects if o.type=='ARMATURE'],
        'actions':[a.name for a in bpy.data.actions],
        'textures':[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file)}
                    for i in bpy.data.images if i.type=='IMAGE'],
    }
    print('INVENTORIED',source.stem,flush=True)
(out/'source_inventory.json').write_text(json.dumps(records,indent=2))
