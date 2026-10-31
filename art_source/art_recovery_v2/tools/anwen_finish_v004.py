"""Continue Anwen's layered art source; never modifies production registries."""
import bpy, math, sys, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared

OUT=HERE/'evidence/anwen_v004'
OUT.mkdir(parents=True,exist_ok=True)


def hair_material():
    mat=shared.material('Anwen_v004_AshGrey_Fibers',(.22,.20,.17),.67)
    n=mat.node_tree.nodes;l=mat.node_tree.links;b=n.get('Principled BSDF')
    uv=n.new('ShaderNodeTexCoord')
    wave=n.new('ShaderNodeTexWave');wave.bands_direction='X'
    wave.inputs['Scale'].default_value=22;wave.inputs['Distortion'].default_value=1.2
    wave.inputs['Detail Scale'].default_value=3
    l.new(uv.outputs['UV'],wave.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(.095,.086,.073,1)
    ramp.color_ramp.elements[1].color=(.34,.32,.28,1)
    l.new(wave.outputs['Color'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.00007
    bump.inputs['Strength'].default_value=.25
    l.new(wave.outputs[0],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
    b.inputs['Anisotropic'].default_value=.3
    return mat


def cubic(points,t):
    return (1-t)**3*points[0]+3*(1-t)**2*t*points[1]+3*(1-t)*t*t*points[2]+t**3*points[3]


def lock_mesh(name,guide,width,material,rig,tree=None,card=False):
    centers=[];normals=[]
    for index,p in enumerate(guide):
        if tree:
            hit,normal,_,_=tree.find_nearest(p)
            lift=.0028+(.006*math.sin(math.pi*index/(len(guide)-1)) if card else 0)
            centers.append(hit+normal*lift);normals.append(normal)
        else:
            centers.append(p);normals.append(Vector((0,1,0)))
    verts=[];faces=[];uv=[];across=8
    for row,(p,normal) in enumerate(zip(centers,normals)):
        t=row/(len(centers)-1)
        tangent=centers[min(row+1,len(centers)-1)]-centers[max(0,row-1)]
        lateral=tangent.cross(normal).normalized()
        w=width*(.18+.82*math.sin(math.pi*(.07+.9*t))**.42)*(1-.65*t**8)
        for col in range(across+1):
            u=col/across;v=2*u-1
            crest=(1-v*v)*w*(.035 if card else .23)
            if not card:crest+=.00016*math.cos(u*math.tau*3)*math.sin(math.pi*u)
            verts.append(tuple(p+lateral*v*w+normal*crest));uv.append((u,t))
            if row and col:
                k=row*(across+1)+col;faces.append((k-across-2,k-1,k,k-across-1))
    obj=shared.mesh_object(name,verts,faces,material,uv)
    # A scalp lock's outward side must face away from its fitted surface.
    for poly in obj.data.polygons:
        if poly.normal.dot(normals[min(len(normals)-1,poly.vertices[0]//(across+1))])<0:
            poly.flip()
    shared.bind(obj,rig,lambda p:{'Head':1})
    return obj


def groom(head,rig,card_material=None):
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    mat=card_material if card_material is not None else hair_material()
    # A fitted, irregular hairline rather than a solid bob or a face-covering cap.
    points=[];faces=[];uv=[];indices={}
    for poly in ([] if card_material else head.data.polygons):
        p=poly.center
        front=max(0,min(1,(-p.y-.005)/.08))
        line=1.644+.099*front+.013*math.exp(-((abs(p.x)-.058)/.018)**2)
        line+=.0015*math.sin(p.x*390)+.001*math.sin(p.y*330)
        if p.z<line:continue
        face=[]
        for i in poly.vertices:
            if i not in indices:
                v=head.data.vertices[i];indices[i]=len(points)
                points.append(tuple(v.co+v.normal*.0018))
                uv.append((.5+math.atan2(v.co.x,v.co.y-.015)/math.tau,(v.co.z-1.64)/.18))
            face.append(indices[i])
        faces.append(face)
    if card_material:
        # Continuous hairline rings avoid the saw-toothed polygon selection
        # boundary of the earlier cap. Rays fit the rings to the actual skull.
        rows=32;cols=128
        center=Vector((0,.012,1.68))
        for row in range(rows+1):
            t=.002+.998*row/rows
            for col in range(cols+1):
                a=math.tau*col/cols
                line=1.672+.075*max(0,math.cos(a))-.030*max(0,-math.cos(a))
                end=math.acos(max(-1,min(1,(line-1.68)/.12)))
                phi=t*end
                direction=Vector((.087*math.sin(phi)*math.sin(a),-.102*math.sin(phi)*math.cos(a),.12*math.cos(phi))).normalized()
                hit,normal,_,_=tree.ray_cast(center,direction)
                assert hit is not None,'Scalp ring must meet the head'
                points.append(tuple(hit+normal*.0018))
                uv.append((col/cols+.12*(1-t),.10+.65*t))
                if row and col:
                    k=row*(cols+1)+col;faces.append((k-cols-2,k-cols-1,k,k-1))
    root_mat=shared.material('Anwen_Ash_Roots',(.048,.043,.035),.85) if card_material else mat
    if card_material:
        n=root_mat.node_tree.nodes;l=root_mat.node_tree.links
        image=next(node.image for node in mat.node_tree.nodes if node.type=='TEX_IMAGE')
        tex=n.new('ShaderNodeTexImage');tex.image=image
        mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.048,.043,.035,1)
        l.new(tex.outputs['Alpha'],mix.inputs[0]);l.new(tex.outputs['Color'],mix.inputs[2])
        l.new(mix.outputs[0],n.get('Principled BSDF').inputs['Base Color'])
    cap=shared.mesh_object('Anwen_Hair_v004_FittedRoots',points,faces,root_mat,uv)
    shared.bind(cap,rig,lambda p:{'Head':1})
    for side in (-1,1):
        for j in range(38):
            f=j/37
            control=[Vector((side*(.005+.004*f),-.106+.086*f,1.752+.036*f)),
                     Vector((side*.083,-.085+.11*f,1.828-.006*f)),
                     Vector((side*(.106-.014*f),.057,1.755-.018*f)),
                     Vector((side*(.058-.020*f),.125,1.656+.014*f))]
            guide=[cubic(control,i/29) for i in range(30)]
            lock_mesh('Anwen_Hair_v004_Swept_%s_%02d'%(side,j),guide,.0032+.0012*math.sin(f*math.pi),mat,rig,tree,card=card_material is not None)
        for j in range(18):
            f=j/17
            control=[Vector((side*.004,.005+.075*f,1.801-.016*f)),
                     Vector((side*.045,.113,1.809)),Vector((side*.069,.144,1.713)),
                     Vector((side*.018,.122,1.646))]
            lock_mesh('Anwen_Hair_v004_Nape_%s_%02d'%(side,j),[cubic(control,i/27) for i in range(28)],.0038,mat,rig,tree,card=card_material is not None)
    # Three interwoven locks around a low, flattened coiled braid. Every strand
    # follows the same plait axis; its alternating crossings are actual geometry.
    for strand in range(3):
        guide=[]
        for i in range(121):
            t=i/120;a=math.tau*t*(1.7 if card_material else 1);phase=t*math.tau*11+strand*math.tau/3
            r=(1-.72*t) if card_material else 1
            axis=Vector((.038*r*math.sin(a),.126+.006*t,1.661+.029*r*math.cos(a)))
            radial=Vector((math.sin(a),0,math.cos(a)))
            guide.append(axis+radial*.0062*math.cos(phase)+Vector((0,.0062*math.sin(phase),0)))
        radii=[.0049*(.85+.15*math.sin(i/120*math.pi)) for i in range(121)]
        shared.tube('Anwen_Hair_v004_PinnedPlait_%s'%strand,guide,radii,mat,rig,lambda p:{'Head':1},8)
    rng=random.Random(72)
    for side in (-1,1):
        for j in range(12):
            f=j/11
            control=[Vector((side*(.040+.025*f),-.095+.040*f,1.752-.015*f)),
                     Vector((side*(.073+.014*f),-.105+.045*f,1.744)),
                     Vector((side*(.090+.005*f),-.069+.045*f,1.706)),
                     Vector((side*(.072+.008*f),-.061+.045*f,1.682-rng.random()*.021))]
            lock_mesh('Anwen_Hair_v004_TempleWisp', [cubic(control,i/15) for i in range(16)],.00028,mat,rig,card=card_material is not None)


def eyebrows(head,rig):
    tree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    mat=shared.material('Anwen_v004_BrowFoundation',(.065,.044,.027),.88)
    n=mat.node_tree.nodes;l=mat.node_tree.links
    uv=n.new('ShaderNodeTexCoord');wave=n.new('ShaderNodeTexWave')
    wave.bands_direction='X';wave.inputs['Scale'].default_value=42
    wave.inputs['Distortion'].default_value=2
    l.new(uv.outputs['UV'],wave.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.025,.018,.012,1)
    ramp.color_ramp.elements[1].color=(.12,.085,.052,1)
    l.new(wave.outputs[0],ramp.inputs[0]);l.new(ramp.outputs[0],n.get('Principled BSDF').inputs['Base Color'])
    for side in (-1,1):
        verts=[];faces=[];uv=[];rows=48;cols=6
        for i in range(rows+1):
            t=i/rows;x=side*(.012+.041*t)
            center=1.686+.0055*math.sin(t*math.pi)+(.0012 if side<0 else 0)-.0012*t
            width=.0017*math.sin(math.pi*(.07+.9*t))**.6
            for j in range(cols+1):
                u=j/cols;z=center+(2*u-1)*width+.00012*math.sin(i*2.7+j)
                hit,normal,_,_=tree.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)))
                assert hit is not None,'Brow must remain on facial surface'
                verts.append(tuple(hit+normal*(.00008+.00018*math.sin(u*math.pi))))
                uv.append((t,u))
                if i and j:
                    k=i*(cols+1)+j;faces.append((k-cols-2,k-cols-1,k,k-1))
        obj=shared.mesh_object('Anwen_Brow_v004_'+str(side),verts,faces,mat,uv)
        for p in obj.data.polygons:
            if p.normal.y>0:p.flip()
        shared.bind(obj,rig,lambda p,s=side:{'Head':.5,'Face_Brow_L' if s>0 else 'Face_Brow_R':.5})


def garments():
    for obj in [o for o in bpy.data.objects if o.type=='MESH']:
        if '_Gore_' in obj.name:
            for v in obj.data.vertices:
                p=v.co;angle=math.atan2(p.x,.025-p.y)
                gather=math.exp(-((p.z-1.055)/.095)**2)
                drape=.0045*math.sin(37*p.z+angle*4+.7)*gather
                # The belt compresses cloth; gravity folds broaden below it.
                drape+=.003*math.sin(angle*7+p.z*3)*(1-gather)*max(0,min(1,(1.1-p.z)/.5))
                p.x+=drape*math.sin(angle);p.y-=drape*math.cos(angle)
                p.z+=.004*math.sin(angle*3+.4)*max(0,min(1,(.45-p.z)/.2))
            obj.data.update()
        if obj.name=='Anwen_Linen_Open_Collar':
            for v in obj.data.vertices:
                p=v.co;t=max(0,min(1,(p.z-1.435)/.075))
                p.z-=.014*t*(.5+.5*math.cos(math.atan2(p.x,.025-p.y)))
            obj.data.update()
        if obj.name=='Anwen_Draped_Asymmetric_Shawl':
            for v in obj.data.vertices:
                p=v.co;a=math.atan2(p.x,.025-p.y)
                front=max(0,math.cos(a));back=max(0,-math.cos(a))
                t=max(0,min(1,(((p.x/.234)**2+((p.y-.025)/.166)**2)**.5-.28)/.72))
                p.z-=.027*front*t+.036*back*t
                p.z+=.006*math.sin(a*5+.5)*t+.002*math.sin(a*39)*t**5
            # The former annular shawl had inward-facing outer normals.
            for p in obj.data.polygons:p.flip()
            obj.data.update()
        if obj.name.startswith('Anwen_Wrapped_Wool_Fold'):
            # Keep the useful scarf layers but flatten their round pipe profile.
            center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
            for v in obj.data.vertices:v.co.z=center.z+(v.co.z-center.z)*.55
            obj.data.update()
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        if any(s in mat.name for s in ('Repaired_Slate_Wool','Ash_Wool_Shawl','Unbleached_Linen')):
            for node in mat.node_tree.nodes:
                if node.type=='BUMP':node.inputs['Distance'].default_value=.00022


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_face_v003.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    for o in list(bpy.data.objects):
        if o.type=='MESH' and (o.name=='Anwen_Hair_Cards' or o.name.startswith('Anwen_Brow_v003')):
            bpy.data.objects.remove(o,do_unlink=True)
    key=head.data.shape_keys.key_blocks['Anwen_ReferencePlanes_v003']
    for item in key.data:
        p=item.co;x,y,z=p;front=max(0,min(1,(-y-.02)/.07))
        # Retain folds but reduce the overly deep central furrows seen in Godot.
        p.y-=.00040*math.exp(-((abs(x)-.006)/.0015)**2)*math.exp(-((z-1.698)/.018)**4)*front
        # Broader, supported lip corners, without changing the jaw control.
        mouth=math.exp(-((z-1.590)/.010)**2)*math.exp(-(x/.035)**6)*front
        p.x*=1+.045*mouth
    head.data.update();bpy.context.view_layer.update()
    eyebrows(head,rig);groom(head,rig);garments()
    rig['art_status']='REWORK_v004_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_full_v004.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    cam=scene.camera;cam.data.type='ORTHO'
    views=[('face',(0,-2,1.70),(0,-.015,1.666),.37),
           ('quarter_face',(.8,-2,1.70),(0,-.015,1.666),.37),
           ('rear_face',(0,2,1.70),(0,.015,1.666),.37),
           ('front',(0,-4,1.2),(0,0,.92),2.12),
           ('rear',(0,4,1.2),(0,0,.92),2.12),
           ('quarter',(2.5,-4,1.6),(0,0,.95),2.12)]
    for label,pos,target,size in views:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(OUT/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('ANWEN_V004_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
