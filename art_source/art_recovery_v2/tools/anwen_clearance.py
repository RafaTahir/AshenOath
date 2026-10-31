"""Resolve garment layer clearance explicitly; no further cloth simulation."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_continuous_v009.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    print('SOURCE_ACTION',rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None,flush=True)
    verts=[];faces=[]
    for obj in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Anwen_linen_Gore_')]:
        offset=len(verts);verts.extend([v.co.copy() for v in obj.data.vertices])
        faces.extend([tuple(offset+i for i in p.vertices) for p in obj.data.polygons])
    lining=BVHTree.FromPolygons(verts,faces)
    coat=bpy.data.objects['Anwen_Wool_Draped_Gown'];corrected=0
    assert len(coat.data.vertices)%2==0,'Expected the authored Solidify shell pairing'
    shell_count=len(coat.data.vertices)//2
    for vertex in list(coat.data.vertices)[:shell_count]:
        p=vertex.co;center=Vector((0,.025,p.z));radial=p-center
        radius=radial.length
        if radius<1e-8:continue
        direction=radial/radius
        hit,normal,_,distance=lining.ray_cast(center+direction*.7,-direction,.7)
        if hit is not None:
            support=(hit-center).length
            if radius<support+.006:
                delta=center+direction*(support+.006)-vertex.co
                vertex.co+=delta
                # Preserve the turned edge thickness. Projecting both shells
                # independently collapses them together and causes z-fighting.
                coat.data.vertices[vertex.index+shell_count].co+=delta
                corrected+=1
    coat.data.update()
    tree=BVHTree.FromObject(coat,bpy.context.evaluated_depsgraph_get())
    for obj in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Anwen_wool_Stitched_Seam','Anwen_Handsewn_Repair','Anwen_Repair_Stitch'))]:
        for v in obj.data.vertices:
            hit,normal,_,distance=tree.find_nearest(v.co)
            if distance<.08:v.co=hit+normal*.001
        obj.data.update()
    print('GARMENT_CLEARANCE_CORRECTIONS',corrected,flush=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_clearance_v011.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v011';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO'
    for label,pos,target,size in [('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('front',(0,-4,1.2),(0,0,.92),2.12),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('CLEARANCE_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
