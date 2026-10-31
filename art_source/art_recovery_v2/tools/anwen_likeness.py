"""Reference-specific mature facial planes, preserving rig, UVs and identity."""
import bpy,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parents[1]


def field(p,c,r):
    return math.exp(-sum(((p[i]-c[i])/r[i])**2 for i in range(3))*2)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_bound_v012.blend'))
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    before=head.shape_key_add(name='Before_v012')
    key=head.shape_key_add(name='Anwen_Mature_Reference_v013');key.value=1
    for vertex in key.data:
        p=vertex.co;x,y,z=p;side=1 if x>=0 else -1
        front=max(0,min(1,(-y-.020)/.07))
        # The previous face was gaunter and older than the supplied woman.
        # Support the cheek and lower orbit rather than erasing age lines.
        cheek=field(p,(side*.043,-.083,1.626),(.031,.055,.027))*front
        orbit=field(p,(side*.032,-.093,1.650),(.025,.035,.011))*front
        p.y-=.0018*cheek+.0012*orbit
        p.x+=side*.0012*cheek
        jaw=field(p,(side*.039,-.064,1.581),(.029,.06,.020))*front
        chin=field(p,(0,-.085,1.562),(.032,.05,.014))*front
        p.x+=side*.0022*jaw
        p.x*=1+.07*chin
        p.y-=.0008*chin
        # Keep the nasolabial and forehead folds, reducing the accumulated
        # duplicate sculpt depth that made the neutral look overly severe.
        groove=.015+max(0,1.632-z)*.50
        p.y-=.00055*math.exp(-((abs(x)-groove)/.0022)**2)*math.exp(-((z-1.609)/.024)**4)*front
        for level in (1.702,1.713,1.724):
            curve=level+.002*math.cos(x*48)+.0008*math.sin(x*127)
            p.y-=.00022*math.exp(-((z-curve)/.0015)**2)*math.exp(-(x/.052)**6)*front
        lip=field(p,(0,-.113,1.595),(.024,.025,.005))*front
        p.y-=.0005*lip
    head.data.update()
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    rig['art_status']='REWORK_v013_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_likeness_v013.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v013';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO';cam.data.ortho_scale=.37
    for label,pos in [('face',(0,-2,1.70)),('quarter_face',(.8,-2,1.70)),('profile',(2,0,1.70))]:
        cam.location=pos;cam.rotation_euler=(Vector((0,-.015,1.666))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
    print('ANWEN_LIKENESS_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
