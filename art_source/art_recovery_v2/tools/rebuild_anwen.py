"""Review-only Anwen reconstruction; never overwrites a published actor.

CC0 MakeHuman head topology replaces the generic face. The existing body rig,
hands and boots are retained; garments/hair/materials are separately editable.
"""
import bpy, bmesh, math, sys, json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'design_pack_v1/tools'))
import build_anwen as old

HERE=Path(__file__).resolve().parents[1]
OUT=HERE/'exports'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=HERE.parents[1]/'art_source/design_pack_v1/models/C01_anwen_v001.blend'
UP=HERE/'upstream/makehuman'

def mat(name,color,rough=.7,metal=0):
    m=old.material(name,color,rough,metal)
    return m

def material_detail(m,scale,bump_strength,rough):
    n=m.node_tree.nodes; l=m.node_tree.links; b=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=scale
    tex.inputs['Detail'].default_value=3
    bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.35
    bump.inputs['Distance'].default_value=bump_strength
    l.new(tex.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs['Normal'],b.inputs['Normal'])
    ramp=n.new('ShaderNodeValToRGB'); c=b.inputs['Base Color'].default_value[:3]
    ramp.color_ramp.elements[0].color=(*[x*.62 for x in c],1)
    ramp.color_ramp.elements[1].color=(*[x*1.15 for x in c],1)
    l.new(tex.outputs['Fac'],ramp.inputs[0]); l.new(ramp.outputs[0],b.inputs['Base Color'])
    b.inputs['Roughness'].default_value=rough
    if 'Wool' in m.name or 'Linen' in m.name:
        warp=n.new('ShaderNodeTexWave');warp.bands_direction='X';warp.inputs['Scale'].default_value=480
        weft=n.new('ShaderNodeTexWave');weft.bands_direction='Y';weft.inputs['Scale'].default_value=480
        weave=n.new('ShaderNodeMath');weave.operation='MULTIPLY'
        l.new(warp.outputs['Fac'],weave.inputs[0]);l.new(weft.outputs['Fac'],weave.inputs[1])
        l.new(weave.outputs[0],bump.inputs['Height']);bump.inputs['Distance'].default_value=.00055

def skin_material():
    m=mat('Anwen_Skin_Olive_Mature',(.43,.285,.205),.57)
    n=m.node_tree.nodes; l=m.node_tree.links; b=n.get('Principled BSDF')
    b.inputs['Subsurface Weight'].default_value=.08
    attr=n.new('ShaderNodeVertexColor'); attr.layer_name='SkinRegions'
    diffuse=UP/'system_assets/skins/middleage_caucasian_female/middleage_lightskinned_female_diffuse.png'
    tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(diffuse))
    l.new(tex.outputs['Color'],b.inputs['Base Color'])
    noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=430
    bump=n.new('ShaderNodeBump'); bump.inputs['Distance'].default_value=.00022
    bump.inputs['Strength'].default_value=.3
    l.new(noise.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs['Normal'],b.inputs['Normal'])
    return m

def field(p,c,r): return math.exp(-sum(((p[i]-c[i])/r[i])**2 for i in range(3))*2)

def head(rig):
    verts=[]; uvs=[]; faces=[]; group=''; source_ids=[]
    for line in (UP/'base.obj').read_text().splitlines():
        if line.startswith('v '): verts.append(Vector(tuple(map(float,line.split()[1:]))))
        elif line.startswith('vt '): uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('g '): group=line[2:]
        elif line.startswith('f ') and group=='body': faces.append([tuple(int(k)-1 for k in x.split('/')[:2]) for x in line.split()[1:]])
    for name,w in [('caucasian-female-young.target',.62),('caucasian-female-old.target',.38)]:
        for line in (UP/name).read_text().splitlines():
            if not line or line.startswith('#'): continue
            i,x,y,z=line.split(); verts[int(i)]+=Vector((float(x),float(y),float(z)))*w
    faces=[f for f in faces if all(verts[i][1]>5.23 for i,_ in f)]
    selected=sorted({i for f in faces for i,_ in f}); mapping={k:i for i,k in enumerate(selected)}
    points=[]
    for i in selected:
        x,h,depth=verts[i]
        p=Vector((x*.105,-depth*.105+.046,h*.12+.856))
        # Reference sculpt: long alert face, firm jaw, slightly asymmetric brow,
        # hollowed under-eye/cheek planes, continuous neck, not a new generic head.
        front=max(0,min(1,(-p.y-.015)/.06)); sx=1 if p.x>=0 else -1
        p.x+=sx*(.003*field(p,(sx*.046,-.072,1.575),(.045,.08,.034))
                    -.002*field(p,(sx*.047,-.065,1.63),(.032,.07,.026)))*front
        p.y+=.0025*field(p,(sx*.032,-.08,1.652),(.027,.05,.010))*front
        p.y-=.002*field(p,(0,-.105,1.66),(.018,.05,.034))*front
        p.z+=.0013*field(p,(-.032,-.08,1.684),(.032,.045,.013))
        # Stronger individual planes than the rejected millimetric base edits:
        # projecting nasal bridge, lower tip, broad cheekbone and hollow below.
        p.y-=.005*field(p,(0,-.104,1.650),(.018,.055,.035))*front
        p.z-=.0025*field(p,(0,-.119,1.636),(.020,.035,.018))*front
        p.x+=sx*.0035*field(p,(sx*.050,-.072,1.638),(.023,.05,.025))*front
        p.y+=.005*field(p,(sx*.046,-.072,1.612),(.027,.05,.021))*front
        p.y-=.0035*field(p,(sx*.028,-.084,1.686),(.028,.035,.013))*front
        if p.z<1.56:
            t=max(0,min(1,(1.56-p.z)/.07))
            p.x=p.x*(1-t)+max(-.047,min(.047,p.x))*t
            p.y=.025+(p.y-.025)*(1-.45*t)
        # Sculpt shallow folds on sufficient topology; avoid painted black lines.
        for level in (1.704,1.714):
            p.y+=.00035*math.exp(-((p.z-level-.001*math.cos(p.x*60))/.0015)**2)*math.exp(-(p.x/.055)**6)*front
        points.append(tuple(p))
    mesh=bpy.data.meshes.new('Anwen_IndividualHeadTopology'); mesh.from_pydata(points,[],[[mapping[i] for i,_ in f] for f in faces]); mesh.update()
    obj=bpy.data.objects.new('Anwen_MatureFace_Neck',mesh); bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new(name='UVMap')
    for p,source in zip(mesh.polygons,faces):
        p.use_smooth=True
        for loop,(_,ti) in zip(p.loop_indices,source): uv.data[loop].uv=uvs[ti]
    colors=mesh.color_attributes.new(name='SkinRegions',type='FLOAT_COLOR',domain='POINT')
    for v in mesh.vertices:
        p=v.co; front=max(0,min(1,(-p.y-.01)/.07))
        cheek=field(p,(math.copysign(.041,p.x),-.085,1.625),(.029,.07,.025))*front
        lips=field(p,(0,-.097,1.588),(.026,.04,.008))*front
        eye=field(p,(math.copysign(.030,p.x),-.08,1.654),(.023,.06,.012))*front
        freckle=max(0,math.sin(p.x*5173+math.sin(p.z*711))*math.sin(p.z*4207)-.76)*.23*cheek
        fold=math.exp(-((abs(p.x)-(.013+max(0,1.628-p.z)*.55))/.0027)**2)*math.exp(-((p.z-1.609)/.026)**4)*front
        colors.data[v.index].color=(.31*(1-.22*eye-.30*lips-freckle-.12*fold),.185*(1-.20*cheek-.30*lips-.22*eye-freckle-.16*fold),.115*(1-.12*cheek-.18*lips-.15*eye-freckle-.15*fold),1)
    mesh.materials.append(skin_material())
    def weights(p):
        neck=max(0,min(1,(1.55-p.z)/.055))
        jaw=field(p,(0,-.075,1.577),(.07,.085,.022))*.45
        side='L' if p.x>0 else 'R'
        upper=field(p,(math.copysign(.031,p.x),-.091,1.671),(.020,.030,.0055))*.85
        lower=field(p,(math.copysign(.031,p.x),-.091,1.660),(.020,.030,.0045))*.65
        brow=field(p,(math.copysign(.030,p.x),-.089,1.687),(.028,.035,.010))*.50
        mouth=field(p,(math.copysign(.014,p.x),-.099,1.588),(.012,.030,.007))*.50
        values={'neck_01':neck,'Face_Jaw':jaw,'Face_LidUpper_'+side:upper,'Face_LidLower_'+side:lower,'Face_Brow_'+side:brow,'Face_Mouth_'+side:mouth}
        values['Head']=max(0,1-sum(values.values()))
        return values
    # Bind only the actual retained facial joints; do not invent names.
    names=set(rig.data.bones.keys())
    def valid(p):
        result={}
        for k,w in weights(p).items(): result[k if k in names else 'Head']=result.get(k if k in names else 'Head',0)+w
        return result
    old.bind(obj,rig,valid)
    sub=obj.modifiers.new('Facial subdivision for sculpted planes','SUBSURF'); sub.levels=1
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.modifier_move_up(modifier=sub.name); bpy.ops.object.modifier_apply(modifier=sub.name)
    for v in obj.data.vertices:
        p=v.co;front=max(0,min(1,(-p.y-.020)/.07))
        for level in (1.702,1.713,1.724):
            curve=level+.002*math.cos(p.x*48)+.0008*math.sin(p.x*127)
            p.y+=.00065*math.exp(-((p.z-curve)/.0015)**2)*math.exp(-(p.x/.052)**6)*front
        groove=.015+max(0,1.632-p.z)*.50
        p.y+=.0013*math.exp(-((abs(p.x)-groove)/.0022)**2)*math.exp(-((p.z-1.609)/.024)**4)*front
    obj.data.update()
    obj['provenance']='MakeHuman hm08 CC0 base + female young/old target blend; reference-specific authored sculpt; NOT scanned identity'
    return obj

def strand(name,points,radius,material,rig,bone='Head',sides=5):
    return old.tube(name,points,[radius*(1-.65*i/(len(points)-1)) for i in range(len(points))],material,rig,lambda p:{bone:1},sides)

def eyes(rig):
    sclera=mat('Eye_Sclera',(.50,.44,.34),.22); iris=mat('Eye_Hazel',(.075,.055,.021),.26); pupil=mat('Eye_Pupil',(.004,.005,.003),.18)
    for side in (-1,1):
        center=Vector((side*.0303,-.0847,1.6653))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=.0129,location=center)
        eye=bpy.context.object; eye.name='Anwen_Eyeball_'+str(side)
        bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
        eye.data.materials.append(sclera); old.bind(eye,rig,lambda p,s=side:{'Face_Eye_L' if s>0 else 'Face_Eye_R':1})
        for p in eye.data.polygons:p.use_smooth=True
        for label,r,depth,ma in [('Iris',.0059,-.0972,iris),('Pupil',.0025,-.0980,pupil)]:
            points=[(center.x,depth,center.z)]+[(center.x+r*math.cos(i*math.tau/48),depth+.0003,center.z+r*math.sin(i*math.tau/48)) for i in range(49)]
            obj=old.mesh_object('Anwen_'+label+str(side),points,[(0,i+1,i+2) for i in range(48)],ma)
            old.bind(obj,rig,lambda p,s=side:{'Face_Eye_L' if s>0 else 'Face_Eye_R':1})

def hair(rig):
    m=mat('Anwen_AshBlondGreyHair',(.16,.145,.12),.69)
    material_detail(m,115,.0007,.64)
    # Fitted scalp shell follows the new cranial surface, not the old helmet cap.
    source=bpy.data.objects['Anwen_MatureFace_Neck']
    points=[tuple(v.co+v.normal*.002) for v in source.data.vertices];faces=[]
    for poly in source.data.polygons:
        p=poly.center
        hairline=1.742 if p.y<-.018 else 1.664 if abs(p.x)>.062 else 1.610
        if p.z>hairline:faces.append(tuple(poly.vertices))
    cap=old.mesh_object('Anwen_Scalp_Contoured',points,faces,m)
    old.bind(cap,rig,lambda p:{'Head':1})
    # Swept clumps, divided part, crossed low braids and individually tapered wisps.
    tree=BVHTree.FromObject(source,bpy.context.evaluated_depsgraph_get())
    for side in (-1,1):
        for j in range(34):
            points=[]
            for i in range(25):
                t=i/24
                p0=Vector((side*.003,-.025+j*.0018,1.793))
                p1=Vector((side*.112,-.119+j*.0028,1.793-j*.001))
                p2=Vector((side*.075,.037+j*.001,1.663-j*.001))
                p=(1-t)**2*p0+2*t*(1-t)*p1+t*t*p2
                loc,normal,_,_=tree.find_nearest(p)
                points.append(tuple(loc+normal*(.003+.0007*(j%3))))
            strand('Anwen_CombedLock',points,.0016 if j%3 else .0024,m,rig,sides=6)
        for strand_id in range(3):
            points=[]
            for i in range(40):
                t=i/39; a=t*math.pi*9+strand_id*math.tau/3
                points.append((side*(.072*(1-t)+.008*math.cos(a)), .027+.088*t+.006*math.sin(a),1.711-.107*t+.005*math.cos(a)))
            strand('Anwen_Braid_Interwoven',points,.005,m,rig,sides=8)
        for j in range(14):
            points=[]
            for i in range(16):
                t=i/15
                points.append((side*(.061+.018*t+.003*math.sin(t*8+j)), -.055+j*.003+.02*t,1.754-j*.001-.105*t))
            strand('Anwen_Temple_Flyaway',points,.00045,m,rig,sides=3)
        brow=mat('Anwen_Brow_'+str(side),(.035,.021,.011),.86)
        tree=BVHTree.FromObject(source,bpy.context.evaluated_depsgraph_get())
        for strand_id in range(32):
            x=side*(.012+strand_id*.0010)
            z=1.686+.005*math.sin(strand_id/31*math.pi)+(0.001 if side<0 else 0)
            points=[]
            for i in range(4):
                xx=x+side*i*.0006;zz=z+i*.0014
                loc,normal,_,_=tree.ray_cast(Vector((xx,-.5,zz)),Vector((0,1,0)))
                if loc is not None:points.append(tuple(loc+Vector((0,-.0008,0))))
            if len(points)>1:strand('Anwen_Brow_Hair',points,.00045,brow,rig,bone='Face_Brow_L' if side>0 else 'Face_Brow_R',sides=4)
    for k in range(3):
        points=[((.025+.003*math.sin(i*.6+k))*math.cos(i*math.tau/48),.110+.004*k,1.607+(.024+.003*math.sin(i*.6+k))*math.sin(i*math.tau/48)) for i in range(49)]
        strand('Anwen_Low_Pinned_Bun',points,.006,m,rig,sides=8)

def fitted_hair_cards(rig):
    # Use actual strand-card topology/UVs as a licensed foundation. Fit it to the
    # morphed skull and coil the long braid into the reference's low pinned bun.
    verts=[]
    for line in (UP/'base.obj').read_text().splitlines():
        if line.startswith('v '):verts.append(Vector(tuple(map(float,line.split()[1:]))))
    for name,w in [('caucasian-female-young.target',.62),('caucasian-female-old.target',.38)]:
        for line in (UP/name).read_text().splitlines():
            if not line or line.startswith('#'):continue
            i,x,y,z=line.split();verts[int(i)]+=Vector((float(x),float(y),float(z)))*w
    folder=UP/'system_assets/hair/braid01'
    source=[];uvs=[];faces=[]
    for line in (folder/'braid01.obj').read_text().splitlines():
        if line.startswith('v '):source.append(tuple(map(float,line.split()[1:])))
        elif line.startswith('vt '):uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('f '):faces.append([tuple(int(k)-1 for k in t.split('/')[:2]) for t in line.split()[1:]])
    bindings=[];active=False
    for line in (folder/'braid01.mhclo').read_text().splitlines():
        if line=='verts 0':active=True;continue
        values=line.split()
        if active and len(values)==9:
            try:bindings.append(([int(x) for x in values[:3]],[float(x) for x in values[3:6]],Vector(tuple(map(float,values[6:])))))
            except ValueError:break
        elif active and bindings:break
    assert len(bindings)==len(source),(len(bindings),len(source))
    scales=Vector((abs(verts[5399].x-verts[11998].x)/1.398,abs(verts[791].y-verts[881].y)/2.2048,abs(verts[962].z-verts[5320].z)/1.8461))
    points=[]
    for indices,weights,offset in bindings:
        v=sum((verts[i]*w for i,w in zip(indices,weights)),Vector())+Vector(tuple(offset[i]*scales[i] for i in range(3)))
        p=Vector((v.x*.105,-v.z*.105+.046,v.y*.12+.856))
        if p.y<-.035 and abs(p.x)<.075 and p.z<1.745:
            p.z=1.745+(1.745-p.z)*.10
        if p.z<1.595:
            t=(1.595-p.z)/.34;a=t*math.tau*1.25
            p=Vector((p.x*.60+.025*math.sin(a),.122+(p.y-.13)*.25+.007*math.cos(a),1.595+.024*(1-math.cos(a))))
        points.append(tuple(p))
    m=mat('Anwen_Hair_Cards_AshGrey',(.25,.23,.20),.83)
    n=m.node_tree.nodes;l=m.node_tree.links;b=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexImage');original=bpy.data.images.load(str(folder/'braid01_diffuse.png'))
    import numpy as np
    pixels=np.array(original.pixels[:],dtype=np.float32).reshape(-1,4)
    luminance=pixels[:,:3]@np.array([.2126,.7152,.0722])
    pixels[:,:3]=np.clip((luminance[:,None]*.85+pixels[:,:3]*.15)*1.45,0,1)
    derived=bpy.data.images.new('Anwen_AshGrey_Hair',width=original.size[0],height=original.size[1],alpha=True)
    derived.pixels.foreach_set(pixels.ravel());derived.filepath_raw=str(OUT/'Anwen_AshGrey_Hair.png');derived.file_format='PNG';derived.save()
    tex.image=derived
    # Desaturate and lift the original brown strand image into pale grey-blonde,
    # preserving its strand detail and alpha instead of painting a flat cap.
    l.new(tex.outputs['Color'],b.inputs['Base Color']);l.new(tex.outputs['Alpha'],b.inputs['Alpha'])
    m.surface_render_method='DITHERED';m.use_backface_culling=False
    obj=old.mesh_object('Anwen_Hair_Cards',points,[[i for i,_ in f] for f in faces],m)
    uv=obj.data.uv_layers.new(name='UVMap')
    for poly,f in zip(obj.data.polygons,faces):
        for loop,(_,ti) in zip(poly.loop_indices,f):uv.data[loop].uv=uvs[ti]
    old.bind(obj,rig,lambda p:{'Head':1})
    obj['provenance']='MakeHuman CC0 braid01 topology and texture, retargeted and reworked into low pinned braid; not original authorship'

def garments(rig):
    slate=mat('Anwen_Repaired_Slate_Wool',(.022,.033,.045),.88)
    linen=mat('Anwen_Unbleached_Linen',(.28,.24,.18),.92)
    ash=mat('Anwen_Ash_Wool_Shawl',(.014,.014,.013),.94)
    leather=mat('Anwen_Worn_Belt',(.059,.031,.016),.73)
    metal=mat('Anwen_Dull_Bell_Bronze',(.19,.13,.064),.49,.72)
    for m in (slate,linen,ash): material_detail(m,230,.0010,.90)
    material_detail(leather,130,.0006,.73)
    # Independent six-gore pattern pieces with seam allowances. Gathered upper
    # folds resolve into broad gravity folds below the belt, not one tapered tube.
    for layer,ma,hem,offset in [('linen',linen,.15,-.015),('wool',slate,.21,0)]:
        for panel in range(6):
            vertices=[]; faces=[]; uv=[]; nr=48; nc=16
            for row in range(nr+1):
                t=row/nr; z=hem+(1.45-hem)*t
                if z<1.04:
                    u=(z-hem)/(1.04-hem); rx=.31*(1-u)+.15*u; ry=.205*(1-u)+.115*u
                else:
                    u=(z-1.04)/.41; rx=.15+.038*math.sin(u*math.pi*.78); ry=.115+.022*math.sin(u*math.pi)
                for col in range(nc+1):
                    opening=.14 if layer=='wool' else 0
                    a=opening+(panel+col/nc)/6*(math.tau-2*opening)
                    fullness=(.021*(1-t)+.004)*math.sin(a*11+.3+t*.45)+.004*math.sin(a*23+t*4)
                    fold=.006*math.sin(z*65+a*4)*math.exp(-((z-1.035)/.10)**2)
                    zz=z+.004*math.sin(a*3)*(1-t)**3
                    vertices.append(((rx+offset+fullness+fold)*math.sin(a),.025-(ry+offset+fullness)*math.cos(a),zz))
                    uv.append((col/nc,t))
                    if row and col:
                        i=row*(nc+1)+col; faces.append((i-nc-2,i-nc-1,i,i-1))
            obj=old.mesh_object('Anwen_'+layer+'_Gore_'+str(panel),vertices,faces,ma,uv)
            old.bind(obj,rig,old.body_weights)
            sol=obj.modifiers.new('Turned fabric edge','SOLIDIFY');sol.thickness=.002
            bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_move_up(modifier=sol.name);bpy.ops.object.modifier_apply(modifier=sol.name)
            # A real stitched seam follows the panel and remains skinned to it.
            seam=[vertices[row*(nc+1)] for row in range(2,nr-1)]
            old.tube('Anwen_'+layer+'_Stitched_Seam',seam,[.00065]*len(seam),linen if layer=='wool' else slate,rig,old.body_weights,4)
    old.garment('Anwen_Linen_Open_Collar',[(1.435,.064,.056,.025),(1.510,.051,.050,.025)],linen,rig,32,opening=.20,folds=.003)
    for side in ('l','r'): old.sleeve(rig,side,slate,linen)
    # Asymmetric shawl pattern: narrow at neck, broad over shoulders and a
    # pointed back. Edge and several wrapped folds have actual depth.
    vertices=[]; faces=[]; uv=[]; rows=32; cols=96
    for row in range(rows+1):
        t=row/rows
        for col in range(cols+1):
            a=col/cols*math.tau; back=max(0,-math.cos(a)); front=max(0,math.cos(a))
            rx=.061+.173*math.sin(t*math.pi/2); ry=.067+.099*t
            z=1.484-t*(.110+.16*back)+.012*math.sin(a+.5)*t
            z+=.009*math.sin(t*17+a*2)*t*(1-t)
            vertices.append(((rx+.004*math.sin(a*7+t*3))*math.sin(a),.025-ry*math.cos(a),z))
            uv.append((col/cols,t))
            if row and col:
                i=row*(cols+1)+col; faces.append((i-cols-2,i-cols-1,i,i-1))
    obj=old.mesh_object('Anwen_Draped_Asymmetric_Shawl',vertices,faces,ash,uv)
    def shawl_weights(p):
        arm=max(0,min(.65,(abs(p.x)-.12)*5))
        return {'spine_03':1-arm,'upperarm_l' if p.x>0 else 'upperarm_r':arm}
    old.bind(obj,rig,shawl_weights)
    sol=obj.modifiers.new('Wool hem thickness','SOLIDIFY');sol.thickness=.003
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_move_up(modifier=sol.name);bpy.ops.object.modifier_apply(modifier=sol.name)
    for j in range(3):
        points=[((.076+j*.019)*math.sin(i*math.tau/64),.025-(.076+j*.023)*math.cos(i*math.tau/64),1.477-j*.026-.014*math.cos(i*math.tau/64-.4)) for i in range(65)]
        strand('Anwen_Wrapped_Wool_Fold',points,.009,ash,rig,bone='spine_03',sides=8)
    old.garment('Anwen_Continuous_Leather_Belt',[(1.020,.177,.140,.025),(1.065,.175,.139,.025)],leather,rig,64,folds=0)
    old.bell(rig,metal,leather)
    points=[(.025*math.cos(i*math.tau/48),-.123,1.044+.023*math.sin(i*math.tau/48)) for i in range(49)]
    strand('Anwen_Worn_Buckle',points,.003,metal,rig,bone='pelvis',sides=8)

def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for p in rig.pose.bones: p.rotation_mode='QUATERNION'; p.rotation_quaternion=(1,0,0,0)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side,sign in [('L',1),('R',-1)]:
        centers={'Eye':(sign*.0303,-.0847,1.6653),'LidUpper':(sign*.031,-.091,1.671),'LidLower':(sign*.031,-.091,1.660),'Brow':(sign*.030,-.089,1.687),'Mouth':(sign*.014,-.099,1.588)}
        for name,center in centers.items():
            bone=rig.data.edit_bones['Face_'+name+'_'+side]
            axis=bone.tail-bone.head;bone.head=center;bone.tail=bone.head+axis
    jaw=rig.data.edit_bones['Face_Jaw'];axis=jaw.tail-jaw.head;jaw.head=(0,-.075,1.577);jaw.tail=jaw.head+axis
    bpy.ops.object.mode_set(mode='OBJECT')
    # Preserve hands and boots, discard the rejected face/costume in this copy.
    obj=bpy.data.objects['C01_Anwen_Skinned']
    bm=bmesh.new();bm.from_mesh(obj.data)
    remove=[f for f in bm.faces if not (all(v.co.z<.175 for v in f.verts) or all(abs(v.co.x)>.607 for v in f.verts))]
    bmesh.ops.delete(bm,geom=remove,context='FACES'); bm.to_mesh(obj.data);bm.free()
    obj.name='Anwen_Retained_Hands_Boots'
    for o in list(bpy.data.objects):
        if o!=rig and o!=obj: bpy.data.objects.remove(o,do_unlink=True)
    head(rig); eyes(rig); fitted_hair_cards(rig); garments(rig)
    for mesh in [o for o in bpy.data.objects if o.type=='MESH']:
        mesh['art_status']='REVIEW_ONLY_NOT_ACCEPTED'
    rig['art_status']='REVIEW_ONLY_NOT_ACCEPTED'
    return rig

def save_and_render(rig):
    # Source remains layered; the GLB is a review derivative, never registered as
    # the production Anwen. Materials will be baked before runtime review.
    old.preview_scene(rig)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
    scene.render.resolution_x=800;scene.render.resolution_y=1000
    bpy.ops.file.pack_all()
    models=HERE/'models';models.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(models/'C01_anwen_reconstruction_v002.blend'),compress=True)
    camera=scene.camera; camera.data.ortho_scale=2.12
    for label,pos,target,scale in [
        ('front',(0,-4,1.2),(0,0,.92),2.12),('side',(4,0,1.2),(0,0,.92),2.12),
        ('rear',(0,4,1.2),(0,0,.92),2.12),('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
        ('face',(.35,-2,1.72),(0,-.03,1.66),.43)]:
        camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
        scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)

if __name__=='__main__':save_and_render(prepare())
