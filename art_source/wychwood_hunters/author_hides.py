"""Blender: build two hand-weighted hunting silhouettes in the actors' native bind coordinates.

Run with --background --factory-startup --python author_hides.py -- OUTPUT_DIR.
The .blend keeps both editable garments and their named skin groups. The Godot cook
maps these groups onto the retained creature rigs and bakes their motion libraries.
"""
import math
import json
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
import numpy as np

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
TAU = math.tau
WINE, OCHRE, LINEN = (.21,.024,.031), (.47,.205,.062), (.69,.54,.28)
TAR, HIDE, LEAF, TEAL = (.035,.022,.022), (.115,.048,.030), (.032,.071,.072), (.045,.22,.19)
RUST, HORN, IVORY, AMBER = (.28,.102,.034), (.32,.26,.17), (.68,.61,.40), (.95,.34,.032)

def mix(a, b, t):
    return tuple(v*(1-t)+w*t for v,w in zip(a,b))

class Garment:
    def __init__(self,name):
        self.name=name
        self.v=[];self.f=[];self.c=[];self.w=[]
    def point(self,p,w):
        self.v.append((p[0],-p[2],p[1]))
        self.w.append({w:1.0} if isinstance(w,str) else w)
        return len(self.v)-1
    def face(self,indices,color):
        self.f.append(tuple(indices));self.c.append(color)
    def sheet(self,rows,color):
        n=len(rows[0])
        for i in range(len(rows)-1):
            for j in range(n-1):
                self.face([rows[i][j],rows[i+1][j],rows[i+1][j+1],rows[i][j+1]],color(i,j))
    def tube(self,path,radii,bone,color,n=7):
        pts=[Vector(v) for v in path]; rows=[]
        d=(pts[-1]-pts[0]).normalized()
        a=d.cross(Vector((0,0,1)) if abs(d.z)<.84 else Vector((1,0,0))).normalized()
        b=d.cross(a).normalized()
        for i,(pt,rad) in enumerate(zip(pts,radii)):
            row=[self.point(pt+rad*(a*math.cos(TAU*j/n)+b*math.sin(TAU*j/n)),bone) for j in range(n)]
            rows.append(row+[row[0]])
        self.sheet(rows,lambda i,j:mix(color,LINEN,.04*(j%3)))
        self.face(rows[0][:-1],color);self.face(rows[-1][:-1],color)
    def vane(self,base,tip,width,normal,bone,color,tipcolor):
        base,tip,normal=map(Vector,(base,tip,normal))
        along=(tip-base).normalized()
        across=along.cross(normal).normalized()
        if across.length < .1: raise ValueError("Vane has no width")
        high=across.cross(along).normalized()
        rows=[]
        for i,(t,w,h) in enumerate([(0,.34,.2),(.23,.90,.61),(.49,1.,.89),(.74,.64,.64),(1,.025,.05)]):
            mid=base.lerp(tip,t);bow=math.sin(t*math.pi)*width*.40
            row=[]
            for offset,ridge in [(-1,.0),(-.70,.26),(.08,1.),(.72,.24),(1,.0)]:
                row.append(self.point(mid+across*(w*width*offset)+high*(bow+h*width*.45*ridge),bone))
            rows.append(row)
        self.sheet(rows,lambda i,j:mix(color,tipcolor, max(.0,(i-1)*.18)+(.29 if j in [0,3] else (.08 if j==1 else .015))))
    def strap(self,centers,width,bone,color):
        centers=[Vector(v) for v in centers];rows=[]
        for p in centers:
            row=[self.point(p+d*width,bone) for d in [Vector((-.92,-.38,0)),Vector((0,0,.009)),Vector((.92,.38,0))]]
            rows.append(row)
        self.sheet(rows,lambda i,j:mix(color,OCHRE,.13 if j else .03))
    def export(self):
        m=bpy.data.meshes.new(self.name);m.from_pydata(self.v,[],self.f);m.update()
        art=bpy.data.objects.new(self.name,m);bpy.context.collection.objects.link(art)
        mat=bpy.data.materials.new(self.name+" pigment"); mat.use_nodes=True
        node=mat.node_tree.nodes.new("ShaderNodeVertexColor");node.layer_name="Pigment"
        shader=mat.node_tree.nodes.get("Principled BSDF");mat.node_tree.links.new(node.outputs["Color"],shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value=.77
        m.materials.append(mat)
        colors=m.color_attributes.new(name="Pigment",type="BYTE_COLOR",domain="CORNER")
        for poly,col in zip(m.polygons,self.c):
            for loop in poly.loop_indices: colors.data[loop].color=(*col,1)
        rig=bpy.data.armatures.new(self.name+" binding")
        arm=bpy.data.objects.new(self.name+" bind",rig);bpy.context.collection.objects.link(arm)
        bpy.context.view_layer.objects.active=arm;arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        # Retain the real bind hierarchy for editing and pose checks in Blender.
        actor_dir=Path(__file__).resolve().parents[2]/"outputs/AshenOathTheRoadBetweenCrowns/assets_external/design_pack_v1/creatures"
        source=next(actor_dir.glob(self.name[:3]+"_*.glb")).read_bytes()
        size=struct.unpack_from("<I",source,12)[0]
        gltf=json.loads(source[20:20+size])
        data=source[28+size:]
        def accessor(index):
            entry=gltf["accessors"][index]; view=gltf["bufferViews"][entry["bufferView"]]
            width={"VEC3":3,"VEC4":4,"VEC2":2,"MAT4":16,"SCALAR":1}[entry["type"]]
            dtype={5121:"u1",5123:"<u2",5125:"<u4",5126:"<f4"}[entry["componentType"]]
            return np.frombuffer(data,dtype,count=entry["count"]*width,offset=view.get("byteOffset",0)+entry.get("byteOffset",0)).reshape(-1,width)
        skin=gltf["skins"][0]
        joints=skin["joints"]; names=[gltf["nodes"][n]["name"] for n in joints]
        matrices=np.linalg.inv(accessor(skin["inverseBindMatrices"]).reshape(-1,4,4).transpose(0,2,1))
        axis=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
        for idx,bname in enumerate(names):
            mat=Matrix(matrices[idx].tolist()); loc=axis@mat.translation
            basis=axis@mat.to_3x3(); eb=rig.edit_bones.new(bname)
            eb.head=loc; eb.tail=loc+basis.col[1].normalized()*.08; eb.align_roll(basis.col[2].normalized())
        for idx,node_id in enumerate(joints):
            parent=rig.edit_bones[names[idx]]
            children=[joints.index(n) for n in gltf["nodes"][node_id].get("children",[]) if n in joints]
            for child in children: rig.edit_bones[names[child]].parent=parent
            if children:
                distance=min((rig.edit_bones[names[c]].head-parent.head).length for c in children)
                parent.length=max(.02,distance)
        bpy.ops.object.mode_set(mode="OBJECT")
        groups={b:art.vertex_groups.new(name=b) for b in sorted(set(b for row in self.w for b in row))}
        for i,weights in enumerate(self.w):
            for b,weight in weights.items():
                if weight: groups[b].add([i],weight,'REPLACE')
        mod=art.modifiers.new("Skin","ARMATURE");mod.object=arm;art.parent=arm
        bpy.ops.object.select_all(action="DESELECT");arm.select_set(True);art.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT/(self.name+".glb")),use_selection=True,export_format="GLB",export_animations=False)
        # Keep a lightweight untextured copy of the actual rest body as the fitting
        # reference. The GLB above contains the new silhouette alone.
        ref_vertices=[];ref_faces=[];ref_weights=[]
        for primitive in gltf["meshes"][0]["primitives"]:
            attrs=primitive["attributes"]; start=len(ref_vertices)
            ref_vertices.extend(tuple(axis@Vector(v)) for v in accessor(attrs["POSITION"]))
            ref_faces.extend(tuple(int(v)+start for v in tri) for tri in accessor(primitive["indices"]).reshape(-1,3))
            ref_weights.extend(zip(accessor(attrs["JOINTS_0"]),accessor(attrs["WEIGHTS_0"])))
        reference_mesh=bpy.data.meshes.new(self.name+" original bind surface")
        reference_mesh.from_pydata(ref_vertices,[],ref_faces);reference_mesh.update()
        reference=bpy.data.objects.new(self.name+" / retained body reference",reference_mesh)
        bpy.context.collection.objects.link(reference); reference.parent=arm
        ref_groups=[reference.vertex_groups.new(name=b) for b in names]
        for vi,(js,ws) in enumerate(ref_weights):
            for joint,weight in zip(js,ws):
                if weight>0: ref_groups[int(joint)].add([vi],float(weight),"REPLACE")
        ref_skin=reference.modifiers.new("Original binding","ARMATURE");ref_skin.object=arm
        return arm

def make_ghoul():
    g=Garment("M01_BurialShroud")
    # A torn winding sheet opens at the throat. Pleats and irregular triangular
    # hems differ around the body and remain connected to the broad collar.
    rows=[]
    lengths=[.38,.39,.34,.41,.33,.48,.37,.42,.26,.38,.33,.45,.29,.39,.34,.44,.27,.36,.32,.43,.35,.41,.33,.38,.35]
    for i in range(6):
        row=[]
        for j in range(25):
            a=.22+(TAU-.44)*j/24; side=math.sin(a);front=math.cos(a)
            depth=lengths[j]+.12*max(0.,side) + .15*max(0.,-front)
            radius=[.108,.190,.280,.275,.252,.244][i]
            zrad=[.092,.143,.184,.191,.196,.201][i];pleat=1+.065*math.cos(j*2.82)*i/5
            y=[1.458,1.425,1.362,1.312-depth*.22,1.325-depth*.62,1.326-depth][i]
            x=radius*side*pleat;z=zrad*front*pleat-.035
            w=0 if i<3 else [0,0,0,.22,.62,.78][i]
            row.append(g.point((x,y,z),{"spine_03":1-w,"spine_01":w}))
        rows.append(row)
    def shroud(i,j):
        if i==0:return mix(TAR,WINE,.38)
        if i==1:return mix(WINE,OCHRE,.09 if j%3 else .20)
        if i==4:return mix(WINE,HIDE,.22+.085*(j%4))
        return mix(WINE,LINEN,.024+(.095 if j%5==1 else 0)+.022*math.sin(j*1.73))
    g.sheet(rows,shroud)
    # Broken salt-coloured seam follows the back's actual pleated hem. Its staggered
    # stitches cross the darker border where the shroud was repaired.
    for i,j in [(2,9),(2,10),(2,11),(2,12),(2,13),(2,14),(2,15),(2,16),
                (3,9),(3,16)]:
        span = [rows[i][j],rows[i][j+1],rows[i+1][j],rows[i+1][j+1]]
        positions = [Vector((g.v[idx][0],g.v[idx][2],-g.v[idx][1])) for idx in span]
        a,b,c,d = positions
        lw = g.w[span[2]]
        def patch(u,v):
            pos = a.lerp(b,u).lerp(c.lerp(d,u),v)
            pos.z -= .005
            return g.point(pos,lw)
        g.face([patch(0,.22),patch(.98,.22),patch(.98,.39),patch(0,.39)],mix(OCHRE,LINEN,.28))
        if j % 2 == 0:
            g.face([patch(.23,.04),patch(.37,.04),patch(.63,.62),patch(.49,.62)],LINEN)
    # Raised mourning seam; smooth, heavy double wraps frame the neck.
    for y,xr,zr in [(1.442,.145,.110),(1.420,.190,.149)]:
        arc=[(xr*math.sin(a),y-.011*math.cos(a),-.033+zr*math.cos(a)) for a in [TAU*j/18 for j in range(19)]]
        for a,b in zip(arc,arc[1:]):g.tube([a,b],[.010,.010],"spine_03",TAR,5)
    # Partial hood around the back and temples. Its open brow leaves face readable.
    rows=[]
    for k,(height,rx,rz,zoff) in enumerate([(1.440,.131,.107,-.028),(1.536,.117,.123,-.017),(1.625,.109,.110,-.007),(1.670,.084,.092,-.013),(1.692,.020,.026,-.025)]):
        row=[]
        for j in range(17):
            a=.73+(TAU-1.46)*j/16
            row.append(g.point((rx*math.sin(a),height+.013*math.sin(a),zoff+rz*math.cos(a)),"Head"))
        rows.append(row)
    g.sheet(rows,lambda i,j:mix(WINE,HIDE,.25+.09*((i+j)%3)))
    # Three split ash grave markers on the carried shoulder, each lashed and cut
    # with painted tally strokes. Their irregular broken tops are the distant read.
    for i in range(3):
        base=(.085+i*.042,1.29,-.132-i*.026)
        tip=(.16+i*.081,1.68+i*.040,-.24-i*.033)
        g.vane(base,tip,.031+i*.002,(0,.12,-1),"spine_03",OCHRE,IVORY)
        for t in [.40,.47,.66+i*.032]:
            m=Vector(base).lerp(Vector(tip),t)
            g.tube([m+Vector((-.022,-.003,-.015)),m+Vector((.019,.003,-.015))],[.008,.007],"spine_03",TAR,5)
    g.strap([(.196,1.401,.055),(.146,1.353,.136),(.064,1.258,.174),(-.048,1.162,.156),(-.128,1.086,.117),(-.168,1.057,.061)],.025,"spine_03",TAR)
    for j in range(3):
        x=-.108+j*.040
        g.vane((x,1.124,.145),(x-.026,1.03-j*.03,.160),.014,(0,0,1),"spine_02",OCHRE,LINEN)
    # Raking wrist twists inside its burial binding.
    for x in [-.476,-.509,-.536,-.575]:
        g.tube([(x,1.375,-.065),(x-.016,1.375,-.065)],[.052,.050],"lowerarm_r",HIDE if x<-.53 else WINE,9)
    return g.export()

def fit_stalker_mantle(g):
    """A continuous, fringed hide over the actual shoulders with the body's own weights."""
    from mathutils.bvhtree import BVHTree

    source_dir = Path(__file__).resolve().parents[2] / "outputs/AshenOathTheRoadBetweenCrowns/assets_external/design_pack_v1/creatures"
    glb = next(source_dir.glob("M02_*.glb")).read_bytes()
    size = struct.unpack_from("<I", glb, 12)[0]
    gltf = json.loads(glb[20:20 + size])
    binary = glb[28 + size:]
    def array(accessor_id, count):
        acc = gltf["accessors"][accessor_id]
        view = gltf["bufferViews"][acc["bufferView"]]
        kind = {5126:"<f4",5125:"<u4",5123:"<u2",5121:"u1"}[acc["componentType"]]
        start = acc.get("byteOffset",0) + view.get("byteOffset",0)
        return np.frombuffer(binary,kind,count*acc["count"],start).reshape(-1,count)
    src = gltf["meshes"][0]["primitives"][0]
    attrs = src["attributes"]
    verts = [Vector(x) for x in array(attrs["POSITION"],3)]
    faces = array(src["indices"],1).reshape(-1,3).tolist()
    joints = array(attrs["JOINTS_0"],4)
    values = array(attrs["WEIGHTS_0"],4)
    names = [gltf["nodes"][j]["name"] for j in gltf["skins"][0]["joints"]]
    hull = BVHTree.FromPolygons(verts,faces,all_triangles=True)

    def fit(angle,height,clearance):
        outward = Vector((math.sin(angle),0,math.cos(angle)))
        center = Vector((0,height,.102))
        hit,normal,index,_ = hull.ray_cast(center + outward, -outward,1.5)
        if index is None:
            raise ValueError(f"Shoulder fitting ray missed at {height}, {angle}")
        ids = faces[index]
        a,b,c = [verts[k] for k in ids]
        # Barycentric interpolation retains the same native multi-bone deformation.
        full = (b-a).cross(c-a).length
        coords = [(q-hit).cross(r-hit).length / full for q,r in [(b,c),(c,a),(a,b)]]
        binding = {}
        for k,factor in zip(ids,coords):
            for j,value in zip(joints[k],values[k]):
                if value > 0:
                    bone = names[j]
                    binding[bone] = binding.get(bone,0.) + factor * float(value)
        nearest = sorted(binding,key=binding.get,reverse=True)[:4]
        total = sum(binding[b] for b in nearest)
        return g.point(hit + outward*clearance, {b:binding[b]/total for b in nearest})

    rows = []
    for i,t in enumerate([0.,.09,.23,.38,.50,.57,.68,.82,.90,1.]):
        row = []
        for j in range(29):
            u=j/28
            a=math.radians(59+242*u)
            side=abs(math.sin(a))
            top=1.486-.155*side**2
            bottom=1.003+.132*side**2 + .039*(j%2) - .023*math.cos(7*a)
            y=top*(1-t)+bottom*t
            puff=.016+.017*math.sin(t*math.pi)+.012*(.5+.5*math.cos(j*2.6))
            row.append(fit(a,y,puff))
        rows.append(row)
    deep=(.058,.158,.145); moss=(.22,.37,.235); gold=(.52,.41,.18)
    def dye(i,j):
        if i == 0: return mix(moss,HORN,.35)
        if i == 4: return mix(gold,moss,(j%4)*.14)
        if i >= 7: return mix(deep,moss,.08+.13*((j+i)%3))
        return mix(deep,moss,.15+.20*(j%3==1)+.10*math.sin(.8*j+i))
    g.sheet(rows,dye)

def make_stalker():
    g=Garment("M02_SplinterMantle")
    fit_stalker_mantle(g)
    # Broad ridged plates follow the actual creature's shoulder girdle. Each pale
    # tip faces aft. The darker field stays readable against the original hide.
    for side in [-1,1]:
        bone="Arm1.L" if side==1 else "Arm1.R"
        for i in range(4):
            x=(.11+.071*i)*side
            base=(x,1.416-.023*i,.083+.018*i)
            tip=(x+side*(.12+.024*i),1.53-.059*i,-.230-.036*i)
            g.vane(base,tip,.092-.004*i,(side*.28,.86,-.24),bone if i>2 else "Chest",TEAL,IVORY if i in [1,3] else HORN)
            # Pale central keel and ochre lash at its root.
            if i in [0,2]:
                v=Vector(base).lerp(Vector(tip),.77)
                g.vane((base[0],base[1]+.018,base[2]),(v.x,v.y+.027,v.z),.023,(side*.2,.95,0),"Chest",HORN,IVORY)
        for j in range(3):
            t=j/4.
            base=(side*(.16+.047*j),1.27-.039*j,-.110)
            tip=(side*(.28+.050*j),1.25-.055*j,-.37+.024*j)
            g.vane(base,tip,.056,(side*.39,.58,-.6),"Chest",TEAL,HORN)
        # Forward-facing facial plate + amber crescent bordering the real eye.
        g.vane((side*.171,1.446,.354),(side*.147,1.448,.570),.060,(side*.94,.22,.17),"Head",LEAF,HORN)
        g.vane((side*.163,1.462,.401),(side*.139,1.446,.558),.014,(side*.92,.2,.3),"Head",RUST,AMBER)
        g.vane((side*.134,1.53,.348),(side*.246,1.675,.131),.044,(side*.48,.80,.05),"Head",LEAF,HORN)
        # Matched protective splints leave the hooked hand and elbow free.
        arm="Arm2.L" if side==1 else "Arm2.R"
        for j in range(3):
            base=(side*(.515+j*.012),.982,.060+j*.030)
            tip=(side*(.632+j*.015),.716,.25+j*.024)
            g.vane(base,tip,.032,(side*.93,.13,-.25),arm,LEAF,IVORY if j==1 else TEAL)
    for j in range(4):
        y=1.42-.092*j; reach=.36-.033*j
        g.vane((0,y,-.08),(0,y+.065,-reach),.069,(0.,.9,-.34),"Chest" if j<2 else "Torso",LEAF,TEAL)
    return g.export()

a=make_ghoul();b=make_stalker()
a.location.x=-1.15
b.location.x=1.15
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().with_name("WychwoodHunters.blend")),compress=True)
