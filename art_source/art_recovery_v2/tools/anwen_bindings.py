"""Calibrate Anwen's retained skin/pose contract from the actual Godot review."""
import bpy,math
from pathlib import Path
HERE=Path(__file__).resolve().parents[1]


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_clearance_v011.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig['anwen_staff_pose']=True
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    head_group=head.vertex_groups['Head']
    lids={group.index for group in head.vertex_groups if 'Face_Lid' in group.name}
    for vertex in head.data.vertices:
        moved=0
        for group in list(vertex.groups):
            if group.group in lids:
                original=group.weight;head.vertex_groups[group.group].add([vertex.index],original*.58,'REPLACE')
                moved+=original*.42
        if moved:
            original=next((g.weight for g in vertex.groups if g.group==head_group.index),0)
            head_group.add([vertex.index],original+moved,'REPLACE')
    # The lining and wool must share one continuous skirt response. Their old
    # weights referenced different positions after settling, exposing the lining.
    names=('Anwen_Wool_Draped_Gown','Anwen_linen_Gore_','Anwen_wool_Stitched_Seam','Anwen_linen_Stitched_Seam','Anwen_Handsewn_Repair','Anwen_Repair_Stitch')
    for obj in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(names)]:
        groups={name:obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name) for name in ('pelvis','thigh_l','thigh_r')}
        for v in obj.data.vertices:
            if v.co.z>=.98:continue
            for g in list(v.groups):obj.vertex_groups[g.group].remove([v.index])
            t=max(0,min(1,(1-v.co.z)/.78));leg=.25*t*t*(3-2*t)
            side=.5+.5*math.tanh(v.co.x/.09)
            for name,w in [('pelvis',1-leg),('thigh_l',leg*side),('thigh_r',leg*(1-side))]:
                if w>0:groups[name].add([v.index],w,'REPLACE')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_bound_v012.blend'),compress=True)
    print('ANWEN_BINDINGS_COMPLETE',flush=True)


if __name__=='__main__':main()
