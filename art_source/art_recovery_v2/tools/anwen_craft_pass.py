"""Anwen-only authored hair, brow and scarf refinement on the clean pattern source."""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE.parents[0] / 'design_pack_v1/tools'))
import build_anwen as shared
sys.path.insert(0, str(HERE / 'tools'))
from anwen_finish_v004 import cubic, lock_mesh


def join(pieces, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object


def brows(head, rig):
    tree = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())
    for obj in list(bpy.data.objects):
        if obj.name.startswith('Anwen_Brow_v004_'):
            bpy.data.objects.remove(obj, do_unlink=True)
    mats = [shared.material('Anwen_Brow_Fiber_' + str(i), c, .78)
            for i, c in enumerate(((.037, .024, .015), (.060, .042, .028), (.090, .068, .045)))]
    rng = random.Random(1904)
    for side in (-1, 1):
        pieces = []
        for j in range(280):
            t = rng.random()
            x = side * (.011 + .044 * t)
            center = 1.6855 + .0068 * math.sin(t * math.pi * .94) - .0015 * t
            center += .0010 if side < 0 else -.0003
            width = .0031 * math.sin(math.pi * (.07 + .90 * t)) ** .6
            z = center + rng.uniform(-width, width)
            length = rng.uniform(.0018, .0039)
            dx = side * length * (.25 + .75 * t)
            dz = length * (.85 - .62 * t)
            points = []
            for row in range(5):
                u = row / 4
                hit, normal, _, _ = tree.ray_cast(Vector((x + dx * u, -.5, z + dz * u - .0006 * u*u)), Vector((0, 1, 0)))
                if hit is None:
                    break
                points.append(hit + normal * (.00025 + .00022 * math.sin(u * math.pi)))
            if len(points) != 5:
                continue
            radius = rng.uniform(.000075, .00013)
            weights = lambda p, s=side: {'Head': .35, 'Face_Brow_L' if s > 0 else 'Face_Brow_R': .65}
            pieces.append(shared.tube('Anwen_Brow_Fiber', points,
                [radius * (1 - .88 * i / 4) for i in range(5)], rng.choice(mats), rig, weights, 3))
        join(pieces, 'Anwen_Brow_v019_' + str(side))


def groom(head, rig):
    tree = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())
    card = next(m for m in bpy.data.materials if m.name.startswith('Anwen_Authored_Ash_Strands'))
    root = bpy.data.objects['Anwen_Hair_v004_FittedRoots']
    # Keep the fitted scalp but introduce the irregular volume of swept hair.
    for v in root.data.vertices:
        p = v.co
        a = math.atan2(p.x + .012, .010 - p.y)
        top = max(0, min(1, (p.z - 1.66) / .12))
        part = math.exp(-((p.x + .012) / .009) ** 2) * max(0, min(1, (.06 - p.y) / .13))
        volume = (.002 + .004 * math.sin(a * 3.3 + p.z * 55) ** 2) * top * (1 - .8 * part)
        v.co += v.normal * volume
    root.data.update()
    for obj in list(bpy.data.objects):
        if obj.name.startswith(('Anwen_Hair_v004_Swept_', 'Anwen_Hair_v004_Nape_', 'Anwen_Hair_v004_TempleWisp')):
            bpy.data.objects.remove(obj, do_unlink=True)

    for side in (-1, 1):
        for j in range(28):
            t = j / 27
            start = Vector((-.012, -.104 + .172*t, 1.754 + .052*math.sin(t*math.pi)))
            end = Vector((side*(.071-.012*t), .065+.018*t, 1.671-.020*t))
            controls = [start, Vector((side*.070, -.090+.12*t, 1.802+.006*math.sin(t*8))),
                Vector((side*.106, .038+.055*t, 1.745-.016*t)), end]
            guide = []
            for i in range(42):
                u=i/41
                p=cubic(controls,u)
                hit, normal, _, _=tree.find_nearest(p)
                lift=.0024+.006*math.sin(u*math.pi)**1.3+.0012*math.sin(u*11+j*.7)
                guide.append(hit+normal*lift)
            obj=lock_mesh('Anwen_Hair_v019_Swept',guide,.0052+.0018*math.sin(t*math.pi),card,rig,card=True)
            for uv in obj.data.uv_layers.active.data:
                uv.uv.x=(j%4+uv.uv.x)/4
        # A connected side braid follows the head behind the ear into the coil.
        controls=[Vector((side*.073,-.023,1.740)),Vector((side*.091,.045,1.727)),
                  Vector((side*.064,.091,1.668)),Vector((side*.013,.087,1.654))]
        for strand in range(3):
            guide=[]
            for i in range(101):
                t=i/100;p=cubic(controls,t)
                tangent=(cubic(controls,min(1,t+.003))-cubic(controls,max(0,t-.003))).normalized()
                n=Vector((side,1,0)).normalized();u=tangent.cross(n).normalized()
                n=u.cross(tangent).normalized();phase=t*math.tau*6+strand*math.tau/3
                guide.append(p+.0036*(u*math.cos(phase)+n*math.sin(phase)))
            shared.tube('Anwen_Hair_v019_SidePlait',guide,[.0033]*101,root.data.materials[0],rig,lambda p:{'Head':1},6)
        for j in range(8):
            f=j/7
            controls=[Vector((side*(.045+.019*f),-.092+.027*f,1.756-.012*f)),
                Vector((side*(.073+.009*f),-.111+.025*f,1.753)),
                Vector((side*(.085+.008*f),-.088+.022*f,1.708)),
                Vector((side*(.070+.013*f),-.070+.017*f,1.674-.024*f))]
            obj=lock_mesh('Anwen_Hair_v019_LooseTemple',[cubic(controls,i/31) for i in range(32)],
                .0018 if j<4 else .0007,card,rig,card=True)
            for uv in obj.data.uv_layers.active.data:
                uv.uv.x=(j%4+uv.uv.x)/4


def scarf(rig):
    for obj in list(bpy.data.objects):
        if obj.name.startswith(('Anwen_Continuous_Wool_Shawl_', 'Anwen_Shawl_Sewn_Edge')):
            bpy.data.objects.remove(obj, do_unlink=True)
    mat=bpy.data.materials['Anwen_Ash_Wool_Shawl']
    def weights(p):
        arm=max(0,min(.18,(abs(p.x)-.16)*2))
        return {'spine_03':1-arm,'upperarm_l' if p.x>0 else 'upperarm_r':arm}
    for layer in range(2):
        verts=[];faces=[];uv=[];rows=20;cols=160
        for j in range(cols+1):
            a=math.tau*j/cols
            front=max(0,math.cos(a));back=max(0,-math.cos(a))
            for i in range(rows+1):
                t=i/rows;v=2*t-1
                # Broad vertically draped loops, gathered unevenly at the nape.
                rx=.147+.022*math.cos(a+.7)+layer*.020
                ry=.113+.033*front+layer*.020
                z=1.411-.045*front+.021*back+layer*.045
                z+=.018*math.sin(a-.4)+v*(.040+.012*math.sin(a+1))
                fold=.009*math.cos(t*math.tau*2.1+a*.7)+.003*math.sin(t*math.tau*4.5-a*2)
                fold*=math.sin(t*math.pi)**.4
                radius=fold+.006*(1-v*v)
                verts.append(((rx+radius)*math.sin(a),.025-(ry+radius)*math.cos(a),z))
                uv.append((a*(.15/.27),(v*.05)/.27))
                if j and i:
                    k=j*(rows+1)+i;faces.append((k-rows-2,k-1,k,k-rows-1))
        obj=shared.mesh_object('Anwen_v019_Wrapped_Scarf_'+str(layer),verts,faces,mat,uv)
        shared.bind(obj,rig,weights)
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Wool folded edge thickness','SOLIDIFY');mod.thickness=.0025
        bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)
    # The asymmetrical broad tail is fabric, not a pipe or a floating plate.
    verts=[];faces=[];uv=[];rows=48;cols=24
    for i in range(rows+1):
        t=i/rows
        for j in range(cols+1):
            u=j/cols
            x=.04+.14*u+.012*math.sin(t*4+u*3)
            y=.118+.052*math.sin(t*math.pi/2)+.014*math.sin(u*math.tau*2+t*1.3)
            z=1.445-.34*t+.015*math.sin(u*6+t*2)*t
            verts.append((x,y,z));uv.append((u,t))
            if i and j:
                k=i*(cols+1)+j;faces.append((k-cols-2,k-1,k,k-cols-1))
    obj=shared.mesh_object('Anwen_v019_Scarf_Tail',verts,faces,mat,uv)
    shared.bind(obj,rig,weights)
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Tail thickness','SOLIDIFY');mod.thickness=.002
    bpy.ops.object.modifier_move_up(modifier=mod.name);bpy.ops.object.modifier_apply(modifier=mod.name)


def skin(head):
    mat=head.data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links
    bsdf=nodes.get('Principled BSDF')
    source=bsdf.inputs['Base Color'].links[0].from_socket
    tone=head.data.color_attributes.new(name='AnwenV019SkinRegions',type='FLOAT_COLOR',domain='POINT')
    for v in head.data.vertices:
        p=v.co;side=1 if p.x>=0 else -1
        cheek=math.exp(-((p.x-side*.041)/.025)**2-((p.z-1.637)/.020)**2)*max(0,min(1,(-p.y-.02)/.06))
        orbit=math.exp(-((p.x-side*.030)/.025)**2-((p.z-1.653)/.009)**2)*max(0,min(1,(-p.y-.02)/.06))
        tone.data[v.index].color=(.84+.09*cheek-.03*orbit,.77-.08*cheek-.05*orbit,.66-.07*cheek-.02*orbit,1)
    attr=nodes.new('ShaderNodeVertexColor');attr.layer_name=tone.name
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
    links.new(source,mix.inputs[1]);links.new(attr.outputs['Color'],mix.inputs[2])
    coord=nodes.new('ShaderNodeTexCoord')
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=95;noise.inputs['Detail'].default_value=3
    links.new(coord.outputs['Object'],noise.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.27;ramp.color_ramp.elements[0].color=(.65,.49,.37,1)
    ramp.color_ramp.elements[1].position=.65;ramp.color_ramp.elements[1].color=(1,.97,.91,1)
    links.new(noise.outputs['Fac'],ramp.inputs[0])
    mottling=nodes.new('ShaderNodeMixRGB');mottling.blend_type='MULTIPLY';mottling.inputs[0].default_value=.40
    links.new(mix.outputs[0],mottling.inputs[1]);links.new(ramp.outputs[0],mottling.inputs[2])
    links.new(mottling.outputs[0],bsdf.inputs['Base Color'])
    bsdf.inputs['Specular IOR Level'].default_value=.30
    bsdf.inputs['Subsurface Weight'].default_value=.10


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_soft_v018.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    head=bpy.data.objects['Anwen_MatureFace_Neck']
    brows(head,rig);groom(head,rig);scarf(rig);skin(head)
    rig['art_status']='REWORK_v019_NOT_ACCEPTED'
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_crafted_v019.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    out=HERE/'evidence/anwen_v019';out.mkdir(parents=True,exist_ok=True)
    cam=scene.camera;cam.data.type='ORTHO'
    for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,0,1.666),.38),
        ('front',(0,-4,1.2),(0,0,.92),2.12),('rear',(0,4,1.2),(0,0,.92),2.12),
        ('cloth_detail',(.3,-2,1.2),(0,-.02,1.32),.64)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('ANWEN_CRAFT_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
