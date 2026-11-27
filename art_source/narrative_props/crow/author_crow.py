"""Blender 5.x. Run --background --factory-startup --python author_crow.py -- BUILD_DIR.
The editable master remains in BUILD_DIR next to the intermediate GLB.
Authored coordinates are millimetres, frontal +depth. Godot receives +Z front and Y up.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

directory = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
tau = math.tau


def xyz(point):
    x, y, depth = point
    return (x * .001, -depth * .001, y * .001)


def swatch(name, color, metal=0.0, rough=.72):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    return mat


brass = swatch("Brass polished at the rim",(.44,.255,.088),.82,.38)
verdigris = swatch("Verdigris in the punched eye",(.056,.125,.089),.50,.73)
painted = swatch("Oren's cart paint on brass",(.41,.24,.09),.76,.44)
nodes,links = painted.node_tree.nodes,painted.node_tree.links
bsdf=nodes.get("Principled BSDF")
for tex,pin in [("OrenTokenColor.png","Base Color"),("OrenTokenORM.png",None)]:
    img=bpy.data.images.load(str(directory/tex));img.pack()
    node=nodes.new("ShaderNodeTexImage");node.image=img
    if pin:
        links.new(node.outputs["Color"],bsdf.inputs[pin])
    else:
        img.colorspace_settings.name="Non-Color"
        split=nodes.new("ShaderNodeSeparateColor")
        links.new(node.outputs["Color"],split.inputs[0])
        links.new(split.outputs["Green"],bsdf.inputs["Roughness"])
        links.new(split.outputs["Blue"],bsdf.inputs["Metallic"])
red=swatch("Madder red cord",(.38,.036,.018),0,.90)
red_fleck=swatch("Lighter twist of red flax",(.52,.080,.038),0,.87)
thread=swatch("Ash-grey burial thread",(.29,.30,.282),0,.93)
wire=swatch("Flattened warrant wire",(.24,.27,.26),.78,.43)
linen=swatch("Grey pouch linen",(.22,.237,.222),0,.94)
hem=swatch("Pale worn selvedge",(.35,.363,.33),0,.94)


class Builder:
    def __init__(self,name,materials):
        self.name=name; self.materials=materials;self.vertices=[];self.faces=[];self.indices=[];self.uv=[]
    def vert(self,p):
        self.vertices.append(p);return len(self.vertices)-1
    def face(self,points,material=0):
        self.faces.append(points);self.indices.append(material)
    def close(self):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata([xyz(p) for p in self.vertices],[],self.faces);mesh.update()
        obj=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(obj)
        for mat in self.materials:mesh.materials.append(mat)
        uv=mesh.uv_layers.new(name="Paint field") if self.uv else None
        for poly,material in zip(mesh.polygons,self.indices):
            poly.material_index=material;poly.use_smooth=True
            if uv:
                for li in poly.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        return obj


def catmull(anchors,steps=5):
    knots=[Vector(anchors[0]),*[Vector(v) for v in anchors],Vector(anchors[-1])]
    result=[]
    for i in range(1,len(knots)-2):
        a,b,c,d=knots[i-1:i+3]
        for k in range(steps):
            t=k/steps
            result.append((2*b+(c-a)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)*.5)
    return [*result,knots[-1]]


def tube(model,path,radius,sides=7,mat=0,flat=1):
    path=list(map(Vector,path));rings=[];prev=None
    for i,p in enumerate(path):
        z=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
        if prev is None:
            seed=Vector((0,0,1)) if abs(z.z)<.78 else Vector((0,1,0))
            x=(seed-z*seed.dot(z)).normalized()
        else:
            x=(prev-z*prev.dot(z)).normalized()
        y=z.cross(x).normalized();prev=x
        ring=[]
        for j in range(sides):
            a=tau*j/sides;r=radius(i/(len(path)-1)) if callable(radius) else radius
            ring.append(model.vert(p+(x*math.cos(a)*flat+y*math.sin(a))*r))
        rings.append(ring)
    for a,b in zip(rings,rings[1:]):
        for j in range(sides):
            k=(j+1)%sides;model.face([a[j],a[k],b[k],b[j]],mat)
    model.face(rings[0][::-1],mat);model.face(rings[-1],mat)


disc=Builder("OrenToken",[painted,brass,verdigris]); n=56
# Rings follow rays from the pierced hole. Both the hole and edge are real,
# including a rounded lip and a shallow rolled impression on the reverse.
sections=[(.0,1.00,2),(.023,1.67,1),(.050,1.81,0),(.45,1.88,0),
          (.86,1.72,0),(.920,1.53,0),(.941,1.82,0),(.968,1.77,0),(.992,1.35,1),(1,.67,1),
          (1,-.68,1),(.988,-1.38,1),(.950,-1.68,1),(.905,-1.40,2),(.88,-1.67,1),
          (.36,-1.82,1),(.042,-1.72,1),(.011,-1.28,1),(.0,-.95,2)]
rings=[]
for factor,depth,material in sections:
    ring=[]
    for j in range(n):
        a=tau*j/n;dx,dy=math.cos(a),math.sin(a)
        # A gently out-of-round, hammered 60 x 63 mm blank.
        ox,oy=.0,24;rx,ry=30,31.5
        aa=(dx/rx)**2+(dy/ry)**2;bb=2*oy*dy/ry**2;cc=(oy/ry)**2-1
        reach=(-bb+math.sqrt(bb*bb-4*aa*cc))/(2*aa)
        wear=.13*math.sin(7*a)+.15*math.cos(13*a)-.12*math.sin(3*a)
        r=2.25+(reach+wear-2.25)*factor
        x,y=ox+dx*r,oy+dy*r
        z=depth+.10*math.sin(3*a)*factor+.075*math.sin(11*a+factor*3)*factor
        ring.append(disc.vert((x,y,z)));disc.uv.append((.5+x/60.8,.5+y/63.8))
    rings.append(ring)
for i,a in enumerate(rings):
    b=rings[(i+1)%len(rings)]
    for j in range(n):
        k=(j+1)%n;disc.face([a[j],b[j],b[k],a[k]],sections[i][2])
disc.close()

cord=Builder("SellaCord",[red,red_fleck])
# The cord threads the hole, travels up the back, crosses the knot, and
# returns as a soft finger loop. Every knot strand follows an actual path.
route=[(-.7,24,2.45),(-.7,23.5,.15),(-.6,24.3,-2.5),(1.6,33,-2.1),(1,39,-.5),
       (1.9,46,.1),(7.3,58,-1),(14,74,-2.8),(12.9,85,-1.4),(7.9,89,1),(.4,84,1.5),
       (-3.8,71,1.2),(-5.6,58,2.3),(-4,48,1.6),(-1,39,2),(2.6,37,2.6),
       (3.1,33,.5),(1.5,32,-.8),(-2.6,35,-.7),(-3.1,38,2.6),(-.4,39,3.8),
       (1.4,37.6,1.6),(-.4,33,2.1),(-.7,24,2.45)]
def spin(model,centres,start,end,r,twists,mat,thick):
    basis=Vector((0,0,1))
    strand=[]
    for i,p in enumerate(centres):
        tangent=(centres[min(i+1,len(centres)-1)]-centres[max(i-1,0)]).normalized()
        basis=(basis-tangent*basis.dot(tangent)).normalized()
        t=i/(len(centres)-1);side=tangent.cross(basis)
        a=tau*twists*t
        strand.append(p+(basis*math.cos(a)+side*math.sin(a))*r)
    tube(model,strand,thick,4,mat)
centres=catmull(route,3)
tube(cord,centres,1.05,6)
spin(cord,catmull(route,7),0,1,1.00,34,1,.22)
for j,offset in enumerate([-.56,0,.58]):
    tube(cord,catmull([(1,37.2,2),(4,39,1),(6,40.8,.2),(8.1+offset,39+j*.4,-.6)]),.33,5,j%2)
cord.close()

binding=Builder("BurialThread",[thread]);centres=[]
for i in range(74):
    t=i/73;a=tau*8*t+.3
    centres.append((-.47+3.85*math.cos(a),40.1+5.8*t+.37*math.sin(a+.15),.19+2.32*math.sin(a)))
tube(binding,centres,.42,5)
tube(binding,catmull([centres[-1],(2.1,45.4,1.8),(-2.4,40.5,2.3),(-3.7,39.3,.9),(-5.7,38.8,.5)]),.39,6)
binding.close()
seal=Builder("TwoWireTurns",[wire]);wf=[]
for i in range(40):
    t=i/39;a=tau*2.02*t-.42
    wf.append((-.48+4.08*math.cos(a),40.65+t*3.95+.31*math.cos(a+.17),.18+2.71*math.sin(a)))
tube(seal,wf,.48,6,flat=.48);seal.close()

parcel=Builder("OldWrapping",[linen,hem])
# Rounded stuffed packet, hand-folded from two sides. Its broad face carries
# overlapping diagonal flaps with rolled selvedges; back and sides are closed.
def panel(points,material=0):
    coords=[Vector(p) for p in points]
    centre=sum(coords,Vector((0,0,0)))/len(coords); idx=parcel.vert(centre)
    ring=[parcel.vert(v) for v in coords]
    for j in range(len(ring)):parcel.face([idx,ring[j],ring[(j+1)%len(ring)]],material)
outline=[(-30,-29),(-24,-34),(-6,-35),(22,-31),(30,-25),(31,-8),(30,24),
         (23,31),(-9,33),(-26,30),(-32,24),(-34,4),(-32,-20)]
front=[];back=[];outer=[]
for i,(x,y) in enumerate(outline):
    front.append((x*.94,y*.94,4.0+1.1*math.sin(i*2.2)))
    outer.append((x,y,0))
    back.append((x*.94,y*.94,-4.2+.6*math.cos(i*3)))
panel(front);panel(back[::-1])
for j in range(len(front)):
    k=(j+1)%len(front)
    panel([front[k],front[j],outer[j],outer[k]])
    panel([outer[k],outer[j],back[j],back[k]])
flap=[(-30,-17,4.3),(-18,-27,5.2),(8,-32,4.1),(27,-24,4.4),
      (29,1,4.5),(17,10,5.9),(7,12,6.0),(-7,6,5.5),(-18,-5,5.6)]
panel(flap)
flap2=[(-30,20,4),(-25,29,4.3),(-6,31,4.2),(23,29,4.1),(28,20,4.7),
       (24,13,6.1),(13,6,7.1),(3,-3,8.1),(-4,-6.9,7.8),(-10,-3.9,6.9),(-22,8,5.9)]
panel(flap2[::-1])
tube(parcel,catmull(flap2[4:],4),.68,6,1)
tube(parcel,catmull([(29,1,4.6),(19,9,6.3),(11,11.5,6.5)]),.57,6,1)
for i in range(7):
    t=i/6
    tube(parcel,catmull([(-30+1.9*t,-14+5*t,4.5),(-27,-18+3.6*t,4.6),(-22,-22+t,4.5)],3),.19,5,1)
parcel.close()

for obj in bpy.context.scene.objects:
    obj.select_set(True)
bpy.context.scene.unit_settings.system="METRIC"
bpy.context.scene.unit_settings.scale_length=1
bpy.ops.wm.save_as_mainfile(filepath=str(directory/"OrensPaintedCrow.blend"))
bpy.ops.export_scene.gltf(filepath=str(directory/"CrowParts.glb"),export_format="GLB",use_selection=True,
                          export_cameras=False,export_lights=False,export_animations=False,export_yup=True)
