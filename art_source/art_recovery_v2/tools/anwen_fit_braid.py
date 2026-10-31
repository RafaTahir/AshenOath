"""Fit the credited braid source to Anwen; retain the supplied design authority."""
import bpy,math,sys
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parents[1]
UP=HERE/'upstream/makehuman'
FOLDER=UP/'community_hair/elvs_reverse_french_braid_bun'
sys.path.insert(0,str(HERE.parents[0]/'design_pack_v1/tools'))
import build_anwen as shared


def fitted_points():
    verts=[]
    for line in (UP/'base.obj').read_text().splitlines():
        if line.startswith('v '):verts.append(Vector(tuple(map(float,line.split()[1:]))))
    for name,w in [('caucasian-female-young.target',.62),('caucasian-female-old.target',.38)]:
        for line in (UP/name).read_text().splitlines():
            if not line or line.startswith('#'):continue
            i,x,y,z=line.split();verts[int(i)]+=Vector((float(x),float(y),float(z)))*w
    bindings=[];active=False;scales={}
    for line in (FOLDER/'elvs_reverse_french_braid_bun.mhclo').read_text().splitlines():
        words=line.split()
        if words and words[0] in ('x_scale','y_scale','z_scale'):
            axis='xyz'.index(words[0][0]);a,b=int(words[1]),int(words[2])
            scales[axis]=abs(verts[a][axis]-verts[b][axis])/float(words[3])
        if line=='verts 0':active=True;continue
        if active and len(words)==9:
            try:bindings.append(([int(x) for x in words[:3]],[float(x) for x in words[3:6]],Vector(tuple(map(float,words[6:])))))
            except ValueError:break
        elif active and bindings:break
    points=[]
    for indices,weights,offset in bindings:
        v=sum((verts[i]*w for i,w in zip(indices,weights)),Vector())+Vector(tuple(offset[i]*scales[i] for i in range(3)))
        p=Vector((v.x*.105,-v.z*.105+.046,v.y*.12+.856))
        # Sweep the forelock above the brow by rotating its volume, not clipping
        # every low vertex to the same blunt horizontal line.
        influence=max(0,min(1,(-p.y-.035)/.065))*max(0,min(1,(1.80-p.z)/.07))
        pivot=Vector((0,.015,1.744))
        p=p.lerp(pivot+Matrix.Rotation(math.radians(-10),3,'X')@(p-pivot),influence)
        # The source bun is higher than Anwen's pinned nape. Move only the
        # projecting coil, blending into the scalp instead of shearing its root.
        bun=max(0,min(1,(p.y-.115)/.045))
        p.z-=.040*bun;p.y+=.004*bun
        points.append(tuple(p))
    return points


def hair(rig):
    points=fitted_points();uvs=[];faces=[]
    for line in (FOLDER/'rev_fr_braidbun1.obj').read_text().splitlines():
        if line.startswith('vt '):uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('f '):faces.append([tuple(int(k)-1 for k in v.split('/')[:2]) for v in line.split()[1:]])
    mat=shared.material('Anwen_v006_PalePinnedHair',(.16,.15,.13),.77)
    n=mat.node_tree.nodes;l=mat.node_tree.links;b=n.get('Principled BSDF')
    # The core CC0 strand atlas has the compatible layout; do not use the
    # purple "grapewash" colour treatment packaged with the mesh.
    source=bpy.data.images.load(str(UP/'system_assets/hair/braid01/braid01_diffuse.png'))
    pix=np.asarray(source.pixels[:],dtype=np.float32).reshape(-1,4).copy()
    lum=pix[:,:3]@np.array([.2126,.7152,.0722])
    grey=np.clip(lum**.72*.80+.022,0,1)
    pix[:,:3]=grey[:,None]*np.array([1.0,.965,.91])
    image=bpy.data.images.new('Anwen_v006_AshGrey_Strands',width=source.size[0],height=source.size[1],alpha=True)
    image.pixels.foreach_set(pix.ravel())
    out=HERE/'evidence/anwen_v006';out.mkdir(parents=True,exist_ok=True)
    image.filepath_raw=str(out/'Anwen_AshGrey_Strands.png');image.file_format='PNG';image.save()
    tex=n.new('ShaderNodeTexImage');tex.image=image
    l.new(tex.outputs['Color'],b.inputs['Base Color']);l.new(tex.outputs['Alpha'],b.inputs['Alpha'])
    mat.surface_render_method='DITHERED';mat.use_backface_culling=False
    obj=shared.mesh_object('Anwen_Hair_Cards',points,[[i for i,_ in f] for f in faces],mat)
    layer=obj.data.uv_layers.new(name='UVMap')
    for poly,face in zip(obj.data.polygons,faces):
        for loop,(_,index) in zip(poly.loop_indices,face):layer.data[loop].uv=uvs[index]
    shared.bind(obj,rig,lambda p:{'Head':1})
    obj['provenance']='Elvaerwyn reverse French braid bun; MakeHuman hair01_cc0 distribution. Embedded legacy CC_by attribution retained; see PROVENANCE.md. Core CC0 braid01 atlas, recoloured and fitted for Anwen.'
    print('HAIR_BOUNDS',list(obj.dimensions),len(points),len(faces),flush=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'models/C01_anwen_draped_v005.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for o in list(bpy.data.objects):
        if o.type=='MESH' and o.name.startswith('Anwen_Hair_v004_'):bpy.data.objects.remove(o,do_unlink=True)
    hair(rig)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'models/C01_anwen_fitted_v006.blend'),compress=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
    scene.render.resolution_x=720;scene.render.resolution_y=900
    cam=scene.camera;cam.data.type='ORTHO';out=HERE/'evidence/anwen_v006'
    for label,pos,target,size in [('quarter_face',(.8,-2,1.70),(0,-.015,1.666),.37),
                                  ('rear_face',(0,2,1.70),(0,.015,1.666),.37),
                                  ('quarter',(2.5,-4,1.6),(0,0,.95),2.12),
                                  ('front',(0,-4,1.2),(0,0,.92),2.12),
                                  ('rear',(0,4,1.2),(0,0,.92),2.12)]:
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=size;scene.render.filepath=str(out/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    print('ANWEN_FITTED_SOURCE_COMPLETE',flush=True)


if __name__=='__main__':main()
