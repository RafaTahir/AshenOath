"""Continuous fitted hair fibres and tailored sleeve/repair geometry for C01."""
import bpy,math,random,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared
sys.path.insert(0,str(HERE/'tools'))
from anwen_authored_gown import surface,weights as gown_weights


def hairline(head,rig):
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    cap=bpy.data.objects['Anwen_Hair_v004_FittedRoots']
    for v in cap.data.vertices:
        p=v.co;a=math.atan2(p.x,.012-p.y)
        edge=max(0,min(1,(1.765-p.z)/.030))*max(0,math.cos(a))
        q=p.copy();q.z-=.013*edge
        hit,normal,_,_=tree.find_nearest(q)
        p[:]=hit+normal*(.0025+.004*max(0,min(1,(p.z-1.66)/.12)))
    cap.data.update()
    # Fine geometric strands break the silhouette and continue into the groom.
    # They are one mesh, not hundreds of independently scheduled objects.
    rng=random.Random(2208);verts=[];faces=[];uv=[];indices=[]
    colors=[(.055,.044,.031),(.095,.080,.059),(.155,.142,.117),(.22,.207,.177)]
    mats=[shared.material('Anwen_Hair_v022_Fiber_'+str(i),c,.72) for i,c in enumerate(colors)]
    for strand in range(740):
        a=rng.uniform(-1.8,1.8)
        line=1.672+.062*max(0,math.cos(a))
        root=Vector((.083*math.sin(a),.012-.100*math.cos(a),line+rng.uniform(-.004,.010)))
        side=1 if root.x>=-.012 else -1
        length=rng.uniform(.45,1)
        controls=[root,Vector((side*.080,-.055,1.795)),Vector((side*.095,.052,1.740)),Vector((side*.052,.086,1.668))]
        points=[];normals=[];count=22
        for row in range(count):
            t=row/(count-1)*length
            p=(1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3]
            hit,normal,_,_=tree.find_nearest(p)
            lift=.0035+.009*math.sin(t*math.pi)+.002*math.sin(t*14+strand*.7)
            p=hit+normal*lift
            if strand%13==0:p+=normal*.004*math.sin(t*math.pi)
            points.append(p);normals.append(normal)
        material=rng.choices(range(4),weights=(3,4,3,1))[0]
        radius=rng.uniform(.00009,.00018)
        start=len(verts)
        for row,p in enumerate(points):
            t=row/(count-1);tangent=points[min(row+1,count-1)]-points[max(0,row-1)]
            lateral=tangent.cross(normals[row]).normalized();normal=lateral.cross(tangent).normalized()
            r=radius*(1-.94*t**3)
            for j in range(4):
                angle=j*math.tau/3
                verts.append(tuple(p+r*(lateral*math.cos(angle)+normal*math.sin(angle))))
                uv.append((j/3,t))
                if row and j:
                    k=start+row*4+j;faces.append((k-5,k-1,k,k-4));indices.append(material)
    obj=shared.mesh_object('Anwen_Hair_v022_HairlineFibers',verts,faces,mats[0],uv)
    for m in mats[1:]:obj.data.materials.append(m)
    for p,i in zip(obj.data.polygons,indices):p.material_index=i
    shared.bind(obj,rig,lambda p:{'Head':1})


def sleeves(rig):
    wool=bpy.data.materials['Anwen_Repaired_Slate_Wool'];linen=bpy.data.materials['Anwen_Unbleached_Linen']
    for obj in list(bpy.data.objects):
        if obj.name.startswith(('C01_SlateSleeve_','C01_LinenCuff_')):bpy.data.objects.remove(obj,do_unlink=True)
    for side,sign in [('l',1),('r',-1)]:
        def arm_weights(p):
            if abs(p.x)<.21:
                t=max(0,min(1,(abs(p.x)-.15)/.06));return {'spine_03':1-t,'upperarm_'+side:t}
            t=max(0,min(1,(abs(p.x)-.35)/.085));return {'upperarm_'+side:1-t,'lowerarm_'+side:t}
        for cuff in (False,True):
            verts=[];faces=[];uv=[];rows=64 if not cuff else 20;cols=64
            for i in range(rows+1):
                t=i/rows
                x=sign*(.115+.455*t) if not cuff else sign*(.548+.057*t)
                for j in range(cols+1):
                    a=j/cols*math.tau
                    if cuff:
                        r=.054-.003*t+.0035*math.sin(t*math.pi*3)+.002*math.cos(a*9+t*2)
                        dz=.0018*math.sin(a*5+t*4)
                    else:
                        r=.035+min(1,t*5)*.039-.023*t
                        compression=math.exp(-((t-.57)/.19)**2)
                        r+=.0055*math.sin(t*math.pi*17+1.4*math.cos(a))*compression
                        r+=.0025*math.sin(a*7+t*2)+.004*max(0,-math.sin(a))*math.sin(t*math.pi)
                        dz=-.003*math.sin(t*math.pi)
                    verts.append((x,.055+r*math.cos(a),1.418+r*math.sin(a)+dz))
                    uv.append((j/cols,t))
                    if i and j:
                        k=i*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
            obj=shared.mesh_object('Anwen_v022_'+('RolledCuff_' if cuff else 'TailoredSleeve_')+side,verts,faces,linen if cuff else wool,uv)
            shared.bind(obj,rig,lambda p:{'lowerarm_'+side:1} if cuff else arm_weights(p))
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Sewn sleeve thickness','SOLIDIFY');mod.thickness=.0015
            bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)


def repair(rig):
    mat=bpy.data.materials['Anwen_Repair_Older_Slate_Wool']
    verts=[];faces=[];uv=[];rows=20;cols=20
    for i in range(rows+1):
        t=i/rows;z=.46+.135*t
        for j in range(cols+1):
            u=j/cols;a=.72+.39*u+.013*math.sin(t*4)
            p=Vector(surface(z,a));normal=Vector((math.sin(a),-math.cos(a),0))
            verts.append(tuple(p+normal*.0018));uv.append((u,t))
            if i and j:
                k=i*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
    obj=shared.mesh_object('Anwen_v022_Visible_DarnedPatch',verts,faces,mat,uv);shared.bind(obj,rig,gown_weights)
    linen=bpy.data.materials['Anwen_Unbleached_Linen']
    for edge in range(4):
        for i in range(17):
            t=(i+.25)/17
            u,z=((t,.466) if edge==0 else (t,.590) if edge==1 else (.03,.466+.124*t) if edge==2 else (.97,.466+.124*t))
            a=.72+.39*u
            pa=Vector(surface(z,a));pb=Vector(surface(z+.0025,a+.010))
            normal=Vector((math.sin(a),-math.cos(a),0))
            shared.tube('Anwen_v022_Patch_Thread',[pa+normal*.0024,pb+normal*.0024],[.0004,.0004],linen,rig,gown_weights,3)


def shoulder_support():
    bpy.context.view_layer.update()
    points=[];polys=[]
    for obj in bpy.data.objects:
        if obj.type!='MESH' or not (obj.name.startswith('Anwen_v022_TailoredSleeve_') or obj.name=='Anwen_Wool_ContinuousPattern'):
            continue
        mesh=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        offset=len(points);points.extend(v.co.copy() for v in mesh.vertices)
        polys.extend(tuple(offset+i for i in p.vertices) for p in mesh.polygons)
        obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    tree=BVHTree.FromPolygons(points,polys)
    for obj in bpy.data.objects:
        if not obj.name.startswith('Anwen_v020_Fitted_Scarf_'):continue
        half=len(obj.data.vertices)//2
        for i in range(half):
            p=obj.data.vertices[i].co
            if abs(p.x)<.115 or abs(p.y-.025)>.078:continue
            hit,_,_,_=tree.ray_cast(Vector((p.x,p.y,1.62)),Vector((0,0,-1)),.35)
            if hit is None:continue
            shift=max(0,hit.z+.004-p.z)
            obj.data.vertices[i].co.z+=shift
            obj.data.vertices[i+half].co.z+=shift
        obj.data.update()


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_details_v021.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    hairline(bpy.data.objects['Anwen_MatureFace_Neck'],rig);sleeves(rig);repair(rig);shoulder_support()
    rig['art_status']='REWORK_v022_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_tailored_v022.blend'),compress=True)
    scene=bpy.context.scene;scene.cycles.samples=32
    out=HERE/'evidence/anwen_v022';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera
    for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
        ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
        ('cloth_detail',(.3,-2,1.2),(0,-.02,1.25),.70),('side',(4,0,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('ANWEN_TAILORED_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
