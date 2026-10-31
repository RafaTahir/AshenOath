"""Replace the rejected simulated shell with continuous authored pattern meshes."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared


def weights(p):
    if p.z>=.98:return shared.body_weights(p)
    t=max(0,min(1,(1-p.z)/.78));leg=.25*t*t*(3-2*t)
    side=.5+.5*math.tanh(p.x/.09)
    return {'pelvis':1-leg,'thigh_l':leg*side,'thigh_r':leg*(1-side)}


def surface(z,a,lining=False):
    u=max(0,min(1,(1.045-z)/.845))
    if z<1.045:
        rx=.15+.165*u;ry=.115+.09*u
    else:
        v=(z-1.045)/.405
        rx=.15+.036*math.sin(v*math.pi*.78);ry=.115+.022*math.sin(v*math.pi)
    fold=0
    # Individually placed gravity folds, not an evenly fluted tube. The short
    # upper creases converge toward the belt; lower folds broaden with drape.
    for origin,depth,width in [(-.30,.009,.075),(-.66,.014,.11),(-1.25,.010,.13),
                                (.24,.008,.08),(.56,.015,.10),(1.10,.009,.13),
                                (1.93,.014,.12),(2.53,.011,.12),(3.40,.013,.15),
                                (4.30,.010,.12),(5.0,.014,.12)]:
        center=origin+.035*math.sin(u*2.1+origin)
        d=math.atan2(math.sin(a-center),math.cos(a-center))
        breadth=width*(.6+.7*u)
        fold+=depth*(.25+.75*u)*math.exp(-(d/breadth)**2)
        fold-=depth*.38*(.25+.75*u)*math.exp(-((d-breadth*.9)/(breadth*.6))**2)
    gather=math.exp(-((z-1.045)/.065)**2)
    fold+=.0035*math.sin(a*17+.7)*gather
    inset=.014 if lining else 0
    x=(rx+fold-inset)*math.sin(a)
    y=.025-(ry+fold-inset)*math.cos(a)
    return (x,y,z)


def pattern(rig,lining=False):
    rows=104;cols=160;hem=.15 if lining else .21
    verts=[];faces=[];uv=[]
    for row in range(rows+1):
        z=hem+(1.445-hem)*row/rows
        for col in range(cols+1):
            opening=0 if lining else .13
            a=opening+(math.tau-2*opening)*col/cols
            zz=z+.003*math.sin(a*3+.8)*max(0,min(1,(.40-z)/.20))
            verts.append(surface(zz,a,lining));uv.append((col/cols,row/rows))
            if row and col:
                k=row*(cols+1)+col;faces.append((k-cols-2,k-cols-1,k,k-1))
    mat=bpy.data.materials['Anwen_Unbleached_Linen' if lining else 'Anwen_Repaired_Slate_Wool']
    obj=shared.mesh_object('Anwen_Linen_ContinuousPattern' if lining else 'Anwen_Wool_ContinuousPattern',verts,faces,mat,uv)
    shared.bind(obj,rig,weights)
    bpy.context.view_layer.objects.active=obj
    sol=obj.modifiers.new('Turned fabric thickness','SOLIDIFY');sol.thickness=.0012 if lining else .002
    bpy.ops.object.modifier_move_up(modifier=sol.name);bpy.ops.object.modifier_apply(modifier=sol.name)
    return obj


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_textiles_v016.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for obj in list(bpy.data.objects):
        if obj.type=='MESH' and obj.name.startswith(('Anwen_Wool_Draped_Gown','Anwen_linen_Gore_','Anwen_wool_Stitched_Seam','Anwen_linen_Stitched_Seam')):
            bpy.data.objects.remove(obj,do_unlink=True)
    outer=pattern(rig);pattern(rig,True)
    tree=BVHTree.FromObject(outer,bpy.context.evaluated_depsgraph_get())
    for obj in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Anwen_Handsewn_Repair','Anwen_Repair_Stitch'))]:
        for v in obj.data.vertices:
            hit,normal,_,_=tree.find_nearest(v.co)
            v.co=hit+normal*.0010
        obj.data.update()
    for obj in [o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Anwen_Continuous_Wool_Shawl_')]:
        for v in obj.data.vertices:
            p=v.co;a=math.atan2(p.x,.025-p.y)
            t=max(0,min(1,(1.50-p.z)/.24))
            p.z+=.016*math.sin(a-.4)*t+.003*math.sin(t*12+a*2)*math.sin(math.pi*t)
        obj.data.update()
    rig['art_status']='REWORK_v017_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_pattern_v017.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v017';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO'
    for label,pos,target,size in [('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('cloth_detail',(.3,-2,1.2),(0,-.02,1.13),.75),
                                  ('front',(0,-4,1.2),(0,0,.92),2.12),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('AUTHORED_PATTERN_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
