"""Offline Blender mesh, skin and clip authoring shared by the pack creatures.

All geometry is built in meters, Z up, facing -Y. Native skeletal clips are
exported with the authored bodies; no procedural geometry runs in Godot.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Quaternion, Vector, noise

import build_anwen as shared

TAU = math.tau
HERE = shared.HERE


def linear(code):
    a = [int(code[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in a)


def surface(name, color, rough=.8, metal=0):
    return shared.material(name, linear(color), rough, metal)


def grain(x, y, period, seed):
    rng=np.random.default_rng(seed)
    grid=rng.random((int(y.max()/period)+3,int(x.max()/period)+3)).astype(np.float32)
    gx,gy=x/period,y/period
    ix,iy=gx.astype(int),gy.astype(int)
    tx,ty=gx-ix,gy-iy
    tx=tx*tx*(3-2*tx); ty=ty*ty*(3-2*ty)
    return ((1-tx)*grid[iy,ix]+tx*grid[iy,ix+1])*(1-ty)+((1-tx)*grid[iy+1,ix]+tx*grid[iy+1,ix+1])*ty


class Creature:
    def __init__(self, asset_id, name, family, colors, size=2):
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        # Each invocation owns a factory scene. Fake-user clips otherwise survive
        # the previous creature and are offered to unrelated rigs by glTF export.
        for action in list(bpy.data.actions):
            bpy.data.actions.remove(action)
        bpy.data.orphans_purge(do_recursive=True)
        self.id, self.name, self.family, self.size = asset_id, name, family, size
        self.out = HERE / "exports" / asset_id
        self.out.mkdir(parents=True, exist_ok=True)
        self.mats = [surface(asset_id+"_"+str(i), c, .42 if i==2 else .78,
                             .65 if i==4 else 0) for i,c in enumerate(colors)]
        self.parts, self.core, self.bones, self.limbs = [], [], [], []
        self.bone("Root", (0,0,0), (0,0,.15))

    def bone(self, name, head, tail, parent="Root", radius=.1):
        self.bones.append(dict(name=name, head=Vector(head), tail=Vector(tail), parent=parent, radius=radius))
        return name

    def mesh(self, name, verts, faces, mat=0, uv=None, bone=None, core=False):
        obj = shared.mesh_object(self.id+"_"+name, verts, faces, self.mats[mat], uv)
        obj["binding"] = bone or "nearest"
        self.parts.append(obj)
        if core:
            self.core.append(obj)
        return obj

    def ellipsoid(self, name, center, radii, mat=0, bone=None, core=False,
                  rings=16, sides=28, rough=.01, direction=None):
        center=Vector(center)
        q=Vector((0,0,1)).rotation_difference(Vector(direction).normalized()) if direction else Quaternion()
        verts,faces,uv=[],[],[]
        for row in range(rings+1):
            phi=math.pi*row/rings
            for col in range(sides+1):
                a=TAU*col/sides
                p=Vector((math.sin(phi)*math.cos(a),math.sin(phi)*math.sin(a),math.cos(phi)))
                detail=noise.noise_vector(p*9+center)*rough
                local=Vector(tuple((p[i]+detail[i]*math.sin(phi))*radii[i] for i in range(3)))
                verts.append(tuple(center+q@local))
                uv.append((col/sides,row/rings))
                if row and col:
                    j=row*(sides+1)+col
                    faces.append((j-sides-2,j-sides-1,j,j-1))
        return self.mesh(name,verts,faces,mat,uv,bone,core)

    def tube(self,name,points,radii,mat=0,bone=None,core=False,sides=14,rough=.015):
        verts,faces,uv=[],[],[]
        for i,point in enumerate(points):
            center=Vector(point)
            tangent=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
            axis=tangent.cross(Vector((0,1,0)))
            if axis.length<.01:
                axis=tangent.cross(Vector((1,0,0)))
            axis.normalize()
            other=tangent.cross(axis).normalized()
            r=radii[i] if isinstance(radii,(tuple,list)) else radii
            rx,ry=r if isinstance(r,(tuple,list)) else (r,r)
            for j in range(sides+1):
                a=TAU*j/sides
                detail=1+rough*(math.sin(a*7+i*1.7)+.3*math.sin(a*13-i))
                verts.append(tuple(center+detail*(axis*math.cos(a)*rx+other*math.sin(a)*ry)))
                uv.append((j/sides,i/(len(points)-1)))
                if i and j:
                    k=i*(sides+1)+j
                    faces.append((k-sides-2,k-sides-1,k,k-1))
        faces.append(tuple(reversed(range(sides+1))))
        last=(len(points)-1)*(sides+1)
        faces.append(tuple(last+i for i in range(sides+1)))
        return self.mesh(name,verts,faces,mat,uv,bone,core)

    def limb(self,name,points,radii,parent="Body",mat=0,core=True,phase=0,kind="leg"):
        chain=[]
        for i in range(len(points)-1):
            bone=self.bone(name+"_"+str(i),points[i],points[i+1],parent if not i else chain[-1],
                           max(radii[i] if isinstance(radii[i],(float,int)) else radii[i][0],.025))
            chain.append(bone)
        if core and all(isinstance(r,(int,float)) for r in radii):
            smooth_points=[]; smooth_radii=[]
            for segment in range(len(points)-1):
                a,b=Vector(points[segment]),Vector(points[segment+1])
                for step in range(8):
                    t=step/8
                    smooth_points.append(a.lerp(b,t))
                    base=radii[segment]*(1-t)+radii[segment+1]*t
                    smooth_radii.append(base*(1+.13*math.sin(math.pi*t)))
            smooth_points.append(Vector(points[-1])); smooth_radii.append(radii[-1])
            self.tube(name,smooth_points,smooth_radii,mat,None,core,sides=24)
        else:
            self.tube(name,points,radii,mat,None,core,sides=20)
        self.limbs.append(dict(bones=chain,phase=phase,kind=kind))
        return chain

    def eye(self,center,radius,bone="Head",iris=2,axis=(0,-1,0)):
        normal=Vector(axis).normalized()
        lateral=normal.cross(Vector((0,0,1)))
        if lateral.length<.1: lateral=Vector((1,0,0))
        lateral.normalize()
        vertical=lateral.cross(normal).normalized()
        self.ellipsoid("EyeSocket",center,(radius*1.24,radius*.88,radius*.30),3,bone,
                       rough=0,direction=normal)
        p=Vector(center)+normal*radius*.15
        self.ellipsoid("Eye",p,(radius,radius*.70,radius*.30),iris,bone,
                       rough=0,rings=12,sides=20,direction=normal)
        p+=normal*radius*.25
        self.ellipsoid("Pupil",p,(radius*.45,radius*.51,radius*.08),3,bone,
                       rough=0,rings=10,sides=16,direction=normal)
        for upper in (False,True):
            points=[]
            for i in range(17):
                angle=math.pi*i/16+(0 if upper else math.pi)
                points.append(Vector(center)+lateral*(radius*1.06*math.cos(angle))
                              +vertical*(radius*.73*math.sin(angle))+normal*radius*.14)
            self.tube("FittedEyelid",points,[radius*.13]*17,0,bone,sides=7)

    def fang(self,name,start,end,radius,mat=1,bone="Jaw"):
        a,b=Vector(start),Vector(end)
        return self.tube(name,[a,a.lerp(b,.35),a.lerp(b,.7),b],
                         [radius,radius*.8,radius*.42,.0008],mat,bone,sides=8)

    def crest(self,name,center,length,width,depth,bone="Body",mat=1,direction=(0,1,-.3)):
        c=Vector(center)
        d=Vector(direction).normalized()*length
        lateral=Vector((1,0,0))*width
        if abs(d.normalized().dot(Vector((1,0,0))))>.8:
            lateral=Vector((0,1,0))*width
        normal=lateral.cross(d).normalized()*depth
        verts=[c-lateral,c+lateral,c+d*.5+normal,c+d,c+d*.3-normal]
        faces=[(0,1,2),(0,2,3),(1,3,2),(0,3,4),(1,4,3),(0,4,1)]
        return self.mesh(name,[tuple(p) for p in verts],faces,mat,
                         [(0,0),(1,0),(.5,.5),(.5,1),(.5,.5)],bone)

    def merge_flesh(self):
        if not self.core:
            return
        remaining=[part for part in self.parts if part not in self.core]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.core: obj.select_set(True)
        obj=self.core[0]
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.join()
        self.parts=remaining+[obj]
        # A continuous surface at shoulders, hips and neck, rather than stacked
        # disconnected primitives. The modifier is baked before weighting.
        remesh=obj.modifiers.new("Continuous anatomical surface","REMESH")
        remesh.mode="VOXEL"
        remesh.voxel_size=self.size/240
        remesh.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        smooth=obj.modifiers.new("Sculpt surface relax","SMOOTH")
        smooth.factor=.62
        smooth.iterations=3
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        count=len(obj.data.polygons)
        if count>22000:
            reduce=obj.modifiers.new("Offline surface retopology","DECIMATE")
            reduce.ratio=22000/count
            bpy.ops.object.modifier_apply(modifier=reduce.name)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj["binding"]="nearest"
        for polygon in obj.data.polygons: polygon.use_smooth=True
        self.core=[obj]

    def skin(self):
        data=bpy.data.armatures.new(self.id+"_Skeleton")
        rig=bpy.data.objects.new(self.id+"_Rig",data)
        bpy.context.collection.objects.link(rig)
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        bpy.context.view_layer.objects.active=rig
        bpy.ops.object.mode_set(mode="EDIT")
        for spec in self.bones:
            b=data.edit_bones.new(spec["name"])
            b.head,b.tail=spec["head"],spec["tail"]
            if spec["name"]!="Root": b.parent=data.edit_bones[spec["parent"]]
        bpy.ops.object.mode_set(mode="OBJECT")
        deform=[b for b in self.bones if b["name"]!="Root"]
        heads=np.array([tuple(b["head"]) for b in deform])
        tails=np.array([tuple(b["tail"]) for b in deform])
        vectors=tails-heads
        squared=np.sum(vectors*vectors,axis=1)
        widths=np.array([b["radius"] for b in deform])
        for obj in self.parts:
            binding=obj.get("binding","nearest")
            if binding!="nearest":
                shared.bind(obj,rig,lambda p,b=binding:{b:1})
                continue
            obj.parent=rig
            modifier=obj.modifiers.new("Authored skin","ARMATURE")
            modifier.object=rig
            groups=[obj.vertex_groups.new(name=b["name"]) for b in deform]
            points=np.array([tuple(v.co) for v in obj.data.vertices])
            t=np.clip(np.sum((points[:,None,:]-heads[None,:,:])*vectors[None,:,:],axis=2)/squared,0,1)
            nearest=heads[None,:,:]+t[:,:,None]*vectors[None,:,:]
            distance=np.linalg.norm(points[:,None,:]-nearest,axis=2)/widths
            best=np.argsort(distance,axis=1)[:,:3]
            for i,indices in enumerate(best):
                values=np.exp(-np.square(distance[i,indices])*2.5)
                if values.sum()<1e-12:
                    groups[indices[0]].add([i],1,"REPLACE")
                else:
                    values/=values.sum()
                    for j,w in zip(indices,values):
                        if w>.002: groups[j].add([i],float(w),"REPLACE")
        self.rig=rig
        return rig

    def texture(self):
        # Static material variation baked into an atlas, supplemented with
        # per-vertex crevice/height variation. No unsupported procedural nodes.
        n=1024
        yy,xx=np.mgrid[0:n,0:n].astype(np.float32)
        pixels=np.ones((n,n,4),np.float32)
        orm=np.ones((n,n,4),np.float32)
        normal=np.ones((n,n,4),np.float32)
        normal[:,:,:3]=(.5,.5,1)
        for index,mat in enumerate(self.mats):
            x0=(index%4)*256; y0=(index//4)*512
            x=xx[y0:y0+512,x0:x0+256]; y=yy[y0:y0+512,x0:x0+256]
            seed=int(self.id[1:])*29+index
            broad=grain(x,y,74,seed)
            medium=grain(x,y,19,seed+1)
            pores=grain(x,y,2.3,seed+2)*2-1
            field=.67+.23*broad+.14*medium+.06*pores
            relief=medium*.35+pores*.10
            if self.family in ("wyvern_two_wing_two_leg","reptile_four_limb") and index==0:
                row=np.floor(y/17)
                cx=((x+(row%2)*11)%22)/11-1
                cy=(y%17)/8.5-1
                scale=np.clip(1-(cx*cx+cy*cy),0,1)
                field*=.76+.24*scale
                relief+=scale*.28
            if self.family=="cervid_quadruped" and index in (0,6):
                fibres=np.sin(x*2.1+grain(x,y,33,seed+3)*4+np.sin(y*.04))
                field*=.90+.10*fibres
                relief+=fibres*.11
            color=np.array(mat.diffuse_color[:3])
            pixels[y0:y0+512,x0:x0+256,:3]=np.clip(color[None,None,:]*field[:,:,None],0,1)
            bsdf=mat.node_tree.nodes.get("Principled BSDF")
            orm[y0:y0+512,x0:x0+256,1]=np.clip(bsdf.inputs["Roughness"].default_value+.04*pores,0,1)
            orm[y0:y0+512,x0:x0+256,2]=bsdf.inputs["Metallic"].default_value
            dy,dx=np.gradient(relief)
            normal[y0:y0+512,x0:x0+256,0]=np.clip(.5-dx*.65,0,1)
            normal[y0:y0+512,x0:x0+256,1]=np.clip(.5-dy*.65,0,1)
        images={}
        for name,p in (("basecolor",pixels),("orm",orm),("normal",normal)):
            if name == "basecolor":
                linear_color=p[:,:,:3].copy()
                p[:,:,:3]=np.where(linear_color<=.0031308,linear_color*12.92,
                                   1.055*np.power(linear_color,1/2.4)-.055)
            image=bpy.data.images.new(self.id+"_"+name,width=n,height=n,alpha=True)
            image.colorspace_settings.name="sRGB" if name=="basecolor" else "Non-Color"
            image.pixels.foreach_set(p.reshape(-1))
            image.filepath_raw=str(self.out/(self.id+"_"+name+".png"))
            image.file_format="PNG"; image.save(); image.reload()
            images[name]=image
        atlas=surface(self.id+"_SurfaceAtlas","FFFFFF")
        nodes,links=atlas.node_tree.nodes,atlas.node_tree.links
        bsdf=nodes.get("Principled BSDF")
        for name in images:
            node=nodes.new("ShaderNodeTexImage"); node.image=images[name]
            if name=="basecolor":
                color=nodes.new("ShaderNodeVertexColor"); color.layer_name="SurfaceVariation"
                mix=nodes.new("ShaderNodeMixRGB"); mix.blend_type="MULTIPLY"; mix.inputs[0].default_value=1
                links.new(node.outputs["Color"],mix.inputs[1])
                links.new(color.outputs["Color"],mix.inputs[2])
                links.new(mix.outputs["Color"],bsdf.inputs["Base Color"])
            elif name=="orm":
                sep=nodes.new("ShaderNodeSeparateColor")
                links.new(node.outputs["Color"],sep.inputs["Color"])
                links.new(sep.outputs["Green"],bsdf.inputs["Roughness"])
                links.new(sep.outputs["Blue"],bsdf.inputs["Metallic"])
            else:
                normal_node=nodes.new("ShaderNodeNormalMap")
                links.new(node.outputs["Color"],normal_node.inputs["Color"])
                links.new(normal_node.outputs["Normal"],bsdf.inputs["Normal"])
        membrane=None
        for obj in self.parts:
            colors=obj.data.color_attributes.new(name="SurfaceVariation",type="FLOAT_COLOR",domain="POINT")
            for v in obj.data.vertices:
                p=v.co
                patch=noise.noise_vector(p*(5/self.size))[0]
                dark=.83+.14*patch
                foot=max(0,1-p.z/(self.size*.21))
                # Dirt follows the actual lower anatomy, not a material-wide wash.
                colors.data[v.index].color=(dark-foot*.23,dark-foot*.27,dark-foot*.30,1)
            uv=obj.data.uv_layers.active
            if uv is None:
                raise ValueError("Missing authored UVs: "+obj.name)
            for polygon in obj.data.polygons:
                old=obj.data.materials[polygon.material_index]
                index=self.mats.index(old)
                for loop in polygon.loop_indices:
                    u,v=uv.data[loop].uv
                    uv.data[loop].uv=((index%4)*.25+.004+u*.242,(index//4)*.5+.004+v*.492)
            material=atlas
            if obj.get("thin_membrane",False):
                if membrane is None:
                    membrane=atlas.copy()
                    membrane.name=self.id+"_ThinWingMembrane"
                    membrane.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value=.48
                    membrane.surface_render_method="DITHERED"
                    membrane.use_backface_culling=False
                material=membrane
            obj.data.materials.clear(); obj.data.materials.append(material)
            for p in obj.data.polygons: p.material_index=0

    def animate(self):
        rig=self.rig
        rig.animation_data_create()
        clips={"Idle":4.0,"Walking":1.15,"Running":.72,"Attack":1.05,"AttackHeavy":1.4,
               "Windup":.7,"Recovery":.8,"Block":1.0,"HitReact":.6,"Death":1.7,
               "Investigate":2.8,"Threaten":2.3,"Feed":3.2,"Sleep":4.6,"Interact":2.0}
        for name,seconds in clips.items():
            action=bpy.data.actions.new(name)
            action.use_fake_user=True
            rig.animation_data.action=action
            frames=max(8,round(seconds*24))
            for frame in range(frames+1):
                t=frame/frames
                phase=TAU*t
                for pose in rig.pose.bones:
                    pose.rotation_mode="QUATERNION"
                    pose.rotation_quaternion=Quaternion()
                    pose.location=(0,0,0); pose.scale=(1,1,1)
                def rotate(bone,axis,angle):
                    if bone in rig.pose.bones:
                        local=rig.data.bones[bone].matrix_local.to_3x3().inverted()@Vector(axis)
                        rig.pose.bones[bone].rotation_quaternion=Quaternion(local.normalized(),angle)
                body="Body" if "Body" in rig.pose.bones else "Spine"
                breathing=.009*math.sin(phase)
                rig.pose.bones[body].scale=(1+breathing,1+breathing*.5,1)
                rotate("Head",(0,0,1),.07*math.sin(phase))
                moving=name in ("Walking","Running")
                for limb in self.limbs:
                    wave=math.sin(phase+limb["phase"])
                    amplitude=(.33 if name=="Walking" else .52) if moving else .025
                    for j,bone in enumerate(limb["bones"]):
                        if limb["kind"]=="fin":
                            rotate(bone,(0,1,0),(.18 if moving else .07)*math.sin(phase+limb["phase"]-j*.7))
                        elif limb["kind"]=="wing":
                            rotate(bone,(0,1,0),(.42 if moving else .04)*math.sin(phase+limb["phase"]-j*.4))
                        elif limb["kind"]=="tail":
                            rotate(bone,(0,0,1),(.18 if moving else .045)*math.sin(phase-j*.5))
                        else:
                            rotate(bone,(1,0,0),wave*amplitude*(1 if j==0 else -.62))
                if name in ("Attack","AttackHeavy","Windup","Recovery"):
                    strike=math.sin(math.pi*t)**2
                    amount=.7 if name=="AttackHeavy" else .4
                    if name=="Windup": amount=-.22*t
                    if name=="Recovery": amount=.23*(1-t)
                    rotate(body,(1,0,0),amount*strike)
                    rotate("Jaw",(1,0,0),.28*strike)
                    for limb in self.limbs:
                        if limb["kind"] in ("arm","claw","wing"):
                            rotate(limb["bones"][0],(1,0,0),-.8*strike)
                elif name=="HitReact": rotate(body,(0,1,0),.18*math.sin(math.pi*t))
                elif name=="Death":
                    eased=t*t*(3-2*t)
                    rotate("Root",(0,1,0),1.35*eased)
                    rig.pose.bones["Root"].location.z=-self.size*.10*eased
                elif name=="Block": rotate(body,(1,0,0),-.1*math.sin(math.pi*t))
                elif name in ("Feed","Investigate","Interact"):
                    rotate("Head",(1,0,0),.22*math.sin(math.pi*t)**2)
                    rotate("Jaw",(1,0,0),.08*max(0,math.sin(phase*3)))
                elif name=="Threaten":
                    rotate(body,(1,0,0),-.10*math.sin(math.pi*t)**2)
                    rotate("Jaw",(1,0,0),.35*math.sin(math.pi*t)**2)
                elif name=="Sleep":
                    rotate("Head",(1,0,0),.28)
                for pose in rig.pose.bones:
                    pose.keyframe_insert("rotation_quaternion",frame=frame)
                    pose.keyframe_insert("location",frame=frame)
                    pose.keyframe_insert("scale",frame=frame)
            track=rig.animation_data.nla_tracks.new()
            track.name=name
            track.strips.new(name,0,action)
            track.mute=True
        rig.animation_data.action=None
        for pose in rig.pose.bones:
            pose.rotation_quaternion=Quaternion(); pose.location=(0,0,0); pose.scale=(1,1,1)
        self.clips=clips

    def finish(self,render=True):
        self.merge_flesh()
        self.skin()
        self.texture()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.parts: obj.select_set(True)
        bpy.context.view_layer.objects.active=self.parts[0]
        bpy.ops.object.join()
        mesh=bpy.context.object
        mesh.name=self.id+"_"+self.name+"_Skinned"
        mesh.data.validate(clean_customdata=False)
        bm=bmesh.new()
        bm.from_mesh(mesh.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh.data)
        bm.free()
        mesh.data.update()
        self.parts=[mesh]
        self.animate()
        self.rig["asset_design_id"]=self.id
        self.rig["character_asset_family"]="ashen_design_pack_v1"
        self.rig["character_animation_family"]=self.family
        bpy.ops.object.select_all(action="DESELECT")
        self.rig.select_set(True); mesh.select_set(True)
        bpy.context.view_layer.objects.active=self.rig
        path=self.out/(self.id+"_"+self.name+".glb")
        # glTF multiplies COLOR_0 into baseColorTexture itself. Export the
        # direct image link; the preview's arbitrary MixRGB graph is not glTF.
        preview_links=[]
        for mat in mesh.data.materials:
            nodes,links=mat.node_tree.nodes,mat.node_tree.links
            bsdf=nodes.get("Principled BSDF")
            source=bsdf.inputs["Base Color"].links[0].from_socket
            image_node=next(n for n in nodes if n.type=="TEX_IMAGE" and n.image.name.endswith("_basecolor"))
            preview_links.append((mat,source))
            links.new(image_node.outputs["Color"],bsdf.inputs["Base Color"])
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
                                  export_animations=True,export_animation_mode="ACTIONS",
                                  export_force_sampling=True,export_skins=True,export_yup=True,
                                  export_vertex_color="ACTIVE",export_all_vertex_colors=False)
        for mat,source in preview_links:
            mat.node_tree.links.new(source,mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
        report={"id":self.id,"name":self.name,"family":self.family,
                "status":"authored_pending_runtime_integration","triangles":sum(len(p.vertices)-2 for p in mesh.data.polygons),
                "bones":len(self.bones),"clips":self.clips,"glb_bytes":path.stat().st_size,
                "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"gameplay_tested":False,"user_accepted":False}
        (self.out/"production.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        self.studio(mesh)
        reference=next((HERE/"AshenOath_Asset_Pack/images/monsters").glob(self.id+"_*.png"))
        ref=bpy.data.objects.new("REFERENCE_NotRuntime",None)
        ref.empty_display_type="IMAGE"; ref.data=bpy.data.images.load(str(reference))
        ref.location=(self.size*2,0,self.size)
        ref.empty_display_size=self.size; ref.hide_render=True
        bpy.context.collection.objects.link(ref)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"models"/(self.id+"_"+self.name+".blend")),compress=True)
        if render:
            bpy.context.scene.render.filepath=str(self.out/(self.id+"_model.png"))
            bpy.ops.render.render(write_still=True)
        print("CREATURE_BUILD="+json.dumps(report),flush=True)

    def studio(self,mesh):
        scene=bpy.context.scene
        scene.render.engine="CYCLES"; scene.cycles.samples=24
        scene.render.resolution_x=1000; scene.render.resolution_y=900
        scene.render.resolution_percentage=100
        scene.world.color=(.24,.24,.24)
        bounds=[Vector(corner) for corner in mesh.bound_box]
        center=sum(bounds,Vector())/8
        span=max(max(p[i] for p in bounds)-min(p[i] for p in bounds) for i in range(3))
        bpy.ops.object.camera_add(location=center+Vector((.9,-1.8,.65))*span)
        camera=bpy.context.object
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.type="ORTHO"; camera.data.ortho_scale=span*1.23
        scene.camera=camera
        for position,energy,area in [((-.8,-1.2,1.7),950,1.0),((1.3,-.3,.8),450,.9),((.1,1.0,1.2),700,.8)]:
            bpy.ops.object.light_add(type="AREA",location=center+Vector(position)*span)
            light=bpy.context.object
            light.data.energy=energy*(span/2)**2; light.data.shape="DISK"; light.data.size=span*area
            light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
        bpy.ops.mesh.primitive_plane_add(size=span*200,location=(0,0,min(p.z for p in bounds)-.006))
        bpy.context.object.name="STUDIO_NotRuntime"
        bpy.context.object.data.materials.append(surface("StudioFloor","515858"))
