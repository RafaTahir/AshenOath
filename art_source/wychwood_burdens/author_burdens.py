"""Blender 5.2 background authoring. Pass an intermediate GLB directory after --.
Coordinates below are the retained creature mesh's bind space (Y up, +Z face).
Each part is named after the skin joint which moves it in the prepared game rig.
"""
from math import cos, sin, pi, tau
from pathlib import Path
import random
import sys

import bpy
import bmesh
from mathutils import Vector

out = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
rng = random.Random(432)
wood = (.46,.29,.15)
splinter = (.72,.49,.25)
iron = (.37,.46,.49)
hem = (.77,.57,.29)
brass = (.79,.62,.29)
teal = (.16,.52,.54)
dark = (.118,.072,.052)
leather = (.43,.25,.148)
red = (.65,.215,.126)
cloth_gold = (.70,.51,.275)
bone = (.77,.70,.51)
def surface_grain(metal):
    size=128
    image=bpy.data.images.new("Pitted gate iron" if metal else "Weathered surface tooth",size,size,alpha=False)
    pixels=[]
    for y in range(size):
        for x in range(size):
            f=.5+.5*sin(tau*(x*3/size+.31*sin(tau*y/size)))
            grain=.5+.5*sin(tau*(x*.25+y*.5))
            fleck=((x*197+y*521+(x^y)*19)%103)/102
            tone=.67+.21*f+.09*grain+.09*fleck if not metal else .61+.29*f+.12*fleck
            if metal and fleck<.06: tone*=.74
            pixels.extend((tone,tone,tone*.99,1))
    image.pixels.foreach_set(pixels)
    image.file_format="PNG"
    image.pack()
    return image

palette = {}
for label,metal,rough in [("Dyed cloth and salvaged timber",.05,.87),("Peened iron and worn brass",.53,.49)]:
    mat = bpy.data.materials.new(label)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Pigment"
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=surface_grain(metal>.1)
    mix=mat.node_tree.nodes.new("ShaderNodeMixRGB")
    mix.blend_type="MULTIPLY"
    mix.inputs[0].default_value=1
    mat.node_tree.links.new(attr.outputs["Color"],mix.inputs[1])
    mat.node_tree.links.new(tex.outputs["Color"],mix.inputs[2])
    mat.node_tree.links.new(mix.outputs[0],shader.inputs["Base Color"])
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    palette[metal > .1] = mat

def part(joint,label,verts,faces,color,metal=False):
    mesh = bpy.data.meshes.new(label)
    mesh.from_pydata([(x,-z,y) for x,y,z in verts],[],faces)
    mesh.update()
    topo = bmesh.new()
    topo.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(topo,faces=list(topo.faces))
    topo.to_mesh(mesh)
    topo.free()
    obj = bpy.data.objects.new(joint+"__"+label,mesh)
    active.objects.link(obj)
    mesh.materials.append(palette[metal])
    attr = mesh.color_attributes.new(name="Pigment",type="BYTE_COLOR",domain="CORNER")
    uv=mesh.uv_layers.new(name="Fibre grain")
    for poly in mesh.polygons:
        normal=poly.normal
        for k in poly.loop_indices:
            x,y,z=mesh.vertices[mesh.loops[k].vertex_index].co
            if abs(normal.z)>.68: u,v=x,y
            elif abs(normal.x)>abs(normal.y): u,v=y,z
            else: u,v=x,z
            uv.data[k].uv=(u/.31,v/.44)
        shade = .94 + .09*rng.random()
        for k in poly.loop_indices:
            attr.data[k].color_srgb = (*[min(1,c*shade) for c in color],1)
    return obj

def extrusion(joint,name,rings,color,metal=False):
    n=len(rings[0])
    faces=[list(reversed(range(n)))]
    for s in range(len(rings)-1):
        for j in range(n):
            a=s*n+j; b=s*n+(j+1)%n
            faces.append([a,b,b+n,a+n])
    faces.append(list(range((len(rings)-1)*n,len(rings)*n)))
    return part(joint,name,[p for ring in rings for p in ring],faces,color,metal)

def rod(joint,name,path,radii,color,metal=False,sides=8):
    pts=[Vector(x) for x in path];rings=[]
    for i,p in enumerate(pts):
        axis=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        normal=Vector((0,1,0)) if abs(axis.y)<.8 else Vector((1,0,0))
        u=axis.cross(normal).normalized();v=axis.cross(u)
        rings.append([p+radii[i]*(u*cos(tau*k/sides)+v*sin(tau*k/sides)) for k in range(sides)])
    return extrusion(joint,name,rings,color,metal)

def ribbon(joint,label,path,width,color,axis=(1,0,0),thick=.008,metal=False):
    w=Vector(axis).normalized()*width*.5
    rows=[]
    for i,point in enumerate(path):
        p=Vector(point)
        along=Vector(path[min(len(path)-1,i+1)])-Vector(path[max(0,i-1)])
        relief=along.cross(w).normalized()*thick
        rows.append([p-w-relief,p+w-relief,p+w+relief,p-w+relief])
    return extrusion(joint,label,rows,color,metal)

def cloth(joint,label,levels,color,sag=.0,begin=0.,end=tau,fold=.0):
    # Closed thickness and an irregular double hem. Subpanels follow the wearer.
    slices=32
    verts=[]
    for y,rx,rz in levels:
        for t in range(slices+1):
            a=begin+(end-begin)*t/slices
            zfrac=(y-levels[0][0])/(levels[-1][0]-levels[0][0])
            rip=(sin(7*a+.7)+.34*sin(13*a))*fold*zfrac
            verts.append(((rx+rip)*sin(a),y-zfrac*sag*(.5+.5*cos(3*a+.3)),(rz+rip)*cos(a)))
    n=len(verts);verts += [(x*.97,y,z*.97) for x,y,z in verts]
    faces=[]
    for row in range(len(levels)-1):
        for j in range(slices):
            a=row*(slices+1)+j; b=a+slices+1
            faces.extend(([a,b,b+1,a+1],[a+1+n,b+1+n,b+n,a+n]))
    for row in [0,len(levels)-1]:
        for j in range(slices):
            a=row*(slices+1)+j
            faces.append([a,a+1,a+1+n,a+n])
    for j in [0,slices]:
        for row in range(len(levels)-1):
            a=row*(slices+1)+j; b=a+slices+1
            faces.append([a,b,b+n,a+n])
    return part(joint,label,verts,faces,color)

def shield():
    joint="lowerarm_l"
    # The shield runs along the forearm in bind pose. Convex transverse sections,
    # offset plank seams and brass nails read in both rim-light and shadow.
    def xyz(u,v,d):
        return (.60+v,1.515+u,.095+d + .065*(1-(u/.235)**2))
    width=[(-.305,.016),(-.230,.093),(-.085,.179),(.085,.204),(.225,.180),(.278,.123)]
    rows=[]
    for v,w in width:
        rows.append([xyz(-w,v,-.024),xyz(-w*.48,v,.005),xyz(0,v,.012),xyz(w*.50,v,.005),xyz(w,v,-.024),xyz(w,v,-.050),xyz(0,v,-.032),xyz(-w,v,-.050)])
    extrusion(joint,"Bent tollgate boards",rows,wood)
    for sign in [-1,1]:
        path=[xyz(sign*w,v,-.012) for v,w in width]
        rod(joint,"Folded rim",path,[.013]*len(path),iron,True)
    ribbon(joint,"Blue warden paint",[xyz(0,v,.016) for v,w in width[1:]],.041,teal,axis=(0,1,0),thick=.003)
    for u in [-.105,-.055,.062,.118]:
        vv=[v for v,w in width if w>abs(u)+.005]
        rod(joint,"Split plank seam",[xyz(u,v,.013) for v in vv],[.0026]*len(vv),dark,False,4)
    for v,w in [(-.105,.140),(.19,.155)]:
        rod(joint,"Stitched iron strap",[xyz(x,v,.018) for x in [-w,-w/2,0,w/2,w]],[.013]*5,iron,True,7)
        for u in [-w*.84,0,w*.84]:
            rod(joint,"Domed rivet",[xyz(u,v,.027),xyz(u,v,.036),xyz(u,v,.040)],[.012,.012,.005],brass,True)
    for v in [.002,.039,.076]:
        rod(joint,"Keeper tally",[xyz(-.072,v,.028),xyz(-.025,v+.018,.028)],[.006,.006],cloth_gold,False,5)
    for u in [-.1,.1]:
        for v in [-.075,.102]:
            rod(joint,"Arm grip",[xyz(u,v,-.045),(.60+v,1.51+u*.37,-.07)],[.015,.018],leather)

def back_panel():
    # The spine and shoulder blades make a flatter back than the chest. Cut
    # this storm flap across the back, with a centre fold and a diagonal hem.
    widths=[.11,.21,.225,.19]
    heights=[1.575,1.493,1.38,1.245]
    depth=[.178,.213,.203,.17]
    rows=[]
    seg=14
    for row,(width,height,z) in enumerate(zip(widths,heights,depth)):
        ring=[]
        for i in range(seg+1):
            t=2*i/seg-1
            tilt=(.044*t+.012*sin(2*pi*t))*row/3
            ring.append((t*width-.018*row/3,height+tilt,-z+.018*t*t+.009*sin(5*pi*t)*row/3))
        rows.append(ring)
    vertices=[v for row in rows for v in row]
    n=len(vertices)
    vertices += [(x,y,z+.006) for x,y,z in vertices]
    faces=[]
    for r in range(len(rows)-1):
        for i in range(seg):
            a=r*(seg+1)+i;b=a+seg+1
            faces.extend([[a,a+1,b+1,b],[a+n,b+n,b+1+n,a+1+n]])
    for i in range(seg):
        a=3*(seg+1)+i
        faces.append([a,a+1,a+1+n,a+n])
    part("spine_03","Split shoulder storm flap",vertices,faces,teal)
    for k in [0,1]:
        row=[(x,y+.012+k*.015,z-.004) for x,y,z in rows[-1]]
        rod("spine_03","Faded road piping",row,[.004 if k else .009]*len(row),hem,False,5)

def raider():
    back_panel()
    cloth("spine_03","Woad watch mantle",[(1.60,.107,.096),(1.55,.215,.158),(1.48,.265,.192),(1.405,.241,.175)],teal,.07,-2.92,2.67,.013)
    cloth("spine_03","Bound ochre hem",[(1.435,.249,.18),(1.410,.247,.179)],hem,.07,-2.92,2.67,.007)
    cloth("pelvis","Split tabard",[(1.057,.185,.148),(.973,.214,.169),(.79,.232,.165),(.712,.214,.153)],teal,.052,-1.4,1.34,.013)
    cloth("pelvis","Tattered skirts",[(1.029,.190,.148),(.92,.207,.156),(.75,.228,.151)],leather,.075,1.67,4.55,.017)
    cloth("pelvis","Belt of cart leather",[(1.051,.191,.154),(1.021,.194,.156),(.979,.202,.164)],dark)
    ribbon("spine_03","Diagonal binding",[(.155,1.53,.096),(.104,1.48,.169),(-.02,1.39,.186),(-.145,1.305,.13)],.055,leather,axis=(.69,-.72,0))
    for x,y,z in [(0.118,1.492,.18),(.082,1.463,.19)]:
        ribbon("spine_03","Bronze keeper clasp",[(x,y,z),(x-.033,y+.016,z+.002)],.014,brass,axis=(.5,-1,0),metal=True)
    for j in range(3):
        ribbon("pelvis","Notched counterweight",[(.105+j*.022,1.018,.126-j*.012),(.11+j*.024,.89+.018*(j%2),.143-j*.012)],.012,brass,metal=True)
    shield()

def brute():
    cloth("pelvis","Oxblood haul apron",[(1.18,.232,.170),(1.09,.263,.188),(.93,.265,.184),(.76,.253,.17)],red,.105,-1.68,1.50,.021)
    cloth("pelvis","Chafed side blanket",[(1.16,.238,.175),(1.05,.264,.182),(.845,.281,.178)],leather,.073,1.51,4.61,.017)
    cloth("pelvis","Hauler cinch",[(1.194,.232,.171),(1.14,.247,.179),(1.093,.258,.185)],dark)
    # Split yoke rises above both shoulders. Its charred ends and forked pins
    # make the load readable even when the pale chest is fully foreshortened.
    j="spine_03"
    path=[(-.525,1.81,-.160),(-.42,1.79,-.14),(-.26,1.729,-.127),(0,1.705,-.18),(.25,1.73,-.13),(.42,1.785,-.141),(.545,1.84,-.15)]
    rod(j,"Lightning split oak shoulder yoke",path,[.051,.073,.085,.072,.085,.07,.030],wood,False,9)
    for side in [-1,1]:
        s=side
        rod(j,"Pale torn splinter",[(s*.412,1.781,-.145),(s*.548,1.842,-.15),(s*.592,1.893,-.172)],[.047,.030,.002],splinter,False,5)
        rod(j,"Iron ferrule",[(s*.342,1.76,-.139),(s*.374,1.77,-.142)],[.086,.082],iron,True,10)
        rod(j,"Haul pin",[(s*.307,1.743,-.14),(s*.333,1.826,-.137),(s*.34,1.852,-.131)],[.025,.023,.034],iron,True,8)
        ribbon(j,"Belt crossing collarbone",[(s*.253,1.73,-.128),(s*.22,1.737,-.005),(s*.176,1.688,.115),(s*.146,1.60,.194),(s*.092,1.50,.214)],.067,dark,axis=(1,0,0),thick=.011)
        ribbon(j,"Slanting rear harness",[(s*.239,1.714,-.191),(s*.204,1.635,-.224),(s*.115,1.51,-.230),(s*.052,1.414,-.194)],.056,leather,axis=(1,0,0),thick=.011)
        ribbon(j,"Wear at shoulder",[(s*.19,1.71,.095),(s*.155,1.639,.173),(s*.139,1.59,.204)],.039,hem,axis=(1,0,0),thick=.01)
        for k in range(3):
            a=(s*(.083+k*.039),1.137,.19-k*.006)
            ribbon("pelvis","Embroidered haul bars",[a,(a[0]+s*.018,a[1]-.12+.012*k,a[2]+.005)],.011,cloth_gold)
    # A peaked, broken brow splint protects the upper face and leaves the eyes,
    # tusks and mouth visible. The exposed sides visually mark the weak angles.
    h="Head"
    for s in [-1,1]:
        extrusion(h,"Hinged brow splint",[
            [(s*.012,1.968,.06),(s*.026,1.959,.12),(s*.029,1.919,.169),(s*.008,1.912,.158)],
            [(s*.095,1.951,.031),(s*.144,1.923,.076),(s*.14,1.879,.128),(s*.093,1.891,.152)]],iron,True)
        rod(h,"Hooded brow edge",[(s*.012,1.914,.162),(s*.096,1.895,.153),(s*.143,1.88,.13)],[.012,.014,.01],splinter,False,6)
    cloth("Head","Crown lash",[(1.929,.117,.107),(1.908,.132,.12)],leather,0.,.85,5.44)
    for joint,x in [("lowerarm_l",.622),("lowerarm_r",-.622)]:
        points=[(x-.052,1.645,-.076),(x+.052,1.645,-.076)]
        rod(joint,"Split hide wrist bind",points,[.098,.089],dark,False,10)
        for dx in [-.035,.034]:
            rod(joint,"Beaten iron band",[(x+dx-.009,1.645,-.076),(x+dx+.009,1.645,-.076)],[.101,.101],iron,True,10)

for label,builder in [("wychwood_raider",raider),("wychwood_brute",brute)]:
    active=bpy.data.collections.new(label)
    bpy.context.scene.collection.children.link(active)
    builder()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in active.objects: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(label+"_regalia.glb")),export_format="GLB",use_selection=True,export_materials="EXPORT",
                              export_vertex_color="NAME",export_vertex_color_name="Pigment",
                              export_all_vertex_colors=False)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().with_name("RoadWardAndHauler.blend")),compress=True)
