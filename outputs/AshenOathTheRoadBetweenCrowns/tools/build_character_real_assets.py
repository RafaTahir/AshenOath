import bpy, math, os, sys
from mathutils import Vector

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets_external", "characters_real"))
os.makedirs(OUT, exist_ok=True)

ROLES = {
    "GhoulGaunt_Real": {"monster": True, "skin": (0.18,0.20,0.15,1), "hair": (0.02,0.02,0.015,1), "cloth": (0.07,0.055,0.04,1), "accent": (0.25,0.05,0.025,1), "lean": True},
    "GhoulStalker_Real": {"monster": True, "skin": (0.11,0.15,0.13,1), "hair": (0.01,0.012,0.01,1), "cloth": (0.04,0.05,0.045,1), "accent": (0.34,0.06,0.03,1), "lean": True, "hood": True},
    "GhoulBrute_Real": {"monster": True, "skin": (0.24,0.17,0.12,1), "hair": (0.025,0.018,0.012,1), "cloth": (0.09,0.055,0.035,1), "accent": (0.38,0.055,0.02,1), "brute": True},
}

def mat(name, color, rough=.72, metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF"); bs.inputs["Base Color"].default_value=color
    bs.inputs["Roughness"].default_value=rough; bs.inputs["Metallic"].default_value=metal
    return m

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
        if hasattr(block, "remove"):
            pass

def armature(monster=False):
    data=bpy.data.armatures.new("AshenHumanoidSkeleton"); obj=bpy.data.objects.new("AshenHumanoidSkeleton",data)
    bpy.context.collection.objects.link(obj); bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    specs={
      "Root":((0,0,0),(0,0,.12),None),"Hips":((0,0,.86),(0,0,1.02),"Root"),
      "Spine":((0,0,1.0),(0,0,1.28),"Hips"),"Chest":((0,0,1.27),(0,0,1.48),"Spine"),
      "Neck":((0,0,1.47),(0,0,1.58),"Chest"),"Head":((0,0,1.57),(0,0,1.82),"Neck"),
      "UpperArm.L":((.22,0,1.43),(.39,-.005,1.27),"Chest"),"Forearm.L":((.39,-.005,1.27),(.54,-.045,1.06),"UpperArm.L"),"Hand.L":((.54,-.045,1.06),(.60,-.10,.98),"Forearm.L"),
      "UpperArm.R":((-.22,0,1.43),(-.39,.005,1.27),"Chest"),"Forearm.R":((-.39,.005,1.27),(-.54,.045,1.06),"UpperArm.R"),"Hand.R":((-.54,.045,1.06),(-.60,.10,.98),"Forearm.R"),
      "Thigh.L":((.14,0,.91),(.15,0,.52),"Hips"),"Shin.L":((.15,0,.52),(.15,0,.14),"Thigh.L"),"Foot.L":((.15,0,.14),(.15,-.18,.08),"Shin.L"),
      "Thigh.R":((-.14,0,.91),(-.15,0,.52),"Hips"),"Shin.R":((-.15,0,.52),(-.15,0,.14),"Thigh.R"),"Foot.R":((-.15,0,.14),(-.15,-.18,.08),"Shin.R"),
    }
    for n,(h,t,p) in specs.items():
        b=data.edit_bones.new(n); b.head=h; b.tail=t
        if p: b.parent=data.edit_bones[p]
    bpy.ops.object.mode_set(mode='OBJECT'); return obj

def primitive(name, loc, scale, material, bone, rig, kind="sphere", verts=12):
    if kind=="sphere": bpy.ops.mesh.primitive_uv_sphere_add(segments=verts, ring_count=max(8,verts//2), location=loc)
    elif kind=="cube": bpy.ops.mesh.primitive_cube_add(location=loc)
    else: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=1, depth=2, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    mod=o.modifiers.new("Armature","ARMATURE"); mod.object=rig
    vg=o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    o.parent=rig
    return o

def consolidate_skinned_meshes(rig):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and o.parent==rig]
    if not meshes:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.join()
    joined=bpy.context.object
    joined.name="CharacterBody"

    polygon_materials=[]
    for polygon in joined.data.polygons:
        slot_index=min(polygon.material_index,max(len(joined.material_slots)-1,0))
        polygon_materials.append(joined.material_slots[slot_index].material if joined.material_slots else None)
    unique=[]
    for material in polygon_materials:
        if material is not None and material not in unique:
            unique.append(material)
    joined.data.materials.clear()
    for material in unique:
        joined.data.materials.append(material)
    for polygon,material in zip(joined.data.polygons,polygon_materials):
        polygon.material_index=unique.index(material) if material in unique else 0

def build(role,cfg):
    clear(); rig=armature(cfg.get("monster", False))
    skin=mat("Skin",cfg["skin"],.68); hair=mat("Hair",cfg["hair"],.84)
    cloth=mat("Cloth",cfg["cloth"],.86); accent=mat("Leather",cfg["accent"],.78)
    eye=mat("Eyes",(0.035,0.09,0.10,1) if not cfg.get("monster") else (0.90,0.16,0.025,1),.3)
    # Monster bodies are deliberately consolidated to six runtime surfaces:
    # skin, cloth, accent, eyes, dark facial cavities, and teeth. Reusing the
    # dark facial material for the socket, mouth, and torn lip keeps the same
    # readable horror contrast without breaking the Compatibility budget.
    socket=mat("MonsterDark",(0.025,0.018,0.015,1),.92)
    mouth=socket if cfg.get("monster") else mat("MouthCavity",(0.012,0.006,0.005,1),.96)
    white=mat("EyeWhite",(0.72,0.70,0.64,1),.55)
    lip=socket if cfg.get("monster") else mat("Lips",(0.30,0.09,0.075,1),.72)
    metal=mat("Metal",(0.20,0.22,0.24,1),.32,.65)
    brute=1.16 if cfg.get("brute") else 1.0; lean=.80 if cfg.get("lean") else 1.0
    primitive("Torso",(0,0,1.25),(.29*brute,.18,.31),cloth,"Chest",rig)
    primitive("Abdomen",(0,0,1.04),(.235*brute,.155,.19),cloth,"Spine",rig)
    primitive("Waist",(0,0,.92),(.22*brute,.15,.14),accent,"Hips",rig)
    primitive("Neck",(0,0,1.52),(.074*brute,.068,.105),skin,"Neck",rig,kind="cylinder",verts=12)
    primitive("ShoulderLine",(0,0,1.43),(.36*brute,.16,.105),cloth,"Chest",rig)
    head_depth=.16 if cfg.get("monster") else .125
    head_height=.22 if cfg.get("monster") else .18
    primitive("Head",(0,-.005,1.68),(.145*brute,head_depth,head_height),skin,"Head",rig,verts=16)
    primitive("Nose",(0,-.132,1.68),(.032,.045,.060),skin,"Head",rig,verts=16)
    primitive("EarL",(.145*brute,0,1.68),(.025,.018,.048),skin,"Head",rig,verts=12)
    primitive("EarR",(-.145*brute,0,1.68),(.025,.018,.048),skin,"Head",rig,verts=12)
    for x in (-.054,.054):
        if cfg.get("monster"):
            primitive("EyeSocket", (x,-.142,1.725),(.050,.017,.036),socket,"Head",rig,verts=16)
            primitive("Eye", (x,-.158,1.725),(.026,.013,.022),eye,"Head",rig,verts=16)
            primitive("Iris", (x,-.171,1.725),(.011,.007,.012),mouth,"Head",rig,verts=12)
            primitive("BrowRidge", (x,-.155,1.775),(.058,.018,.016),skin,"Head",rig,kind="cube")
        else:
            primitive("Eye", (x,-.119,1.715),(.029,.014,.021),white,"Head",rig,verts=16)
            primitive("Iris", (x,-.133,1.715),(.013,.008,.013),eye,"Head",rig,verts=12)
    primitive("UpperLip",(0,-.143,1.622),(.058,.010,.011),lip,"Head",rig,kind="cube")
    primitive("LowerLip",(0,-.145,1.606),(.052,.011,.010),lip,"Head",rig,kind="cube")
    if cfg.get("monster"):
        primitive("Jaw",(0,-.065,1.59),(.14*brute,.145,.13),skin,"Head",rig,verts=16)
        primitive("MouthCavity",(0,-.177,1.615),(.098*brute,.014,.052),mouth,"Head",rig,verts=16)
        for x in (-.050,-.017,.017,.050):
            primitive("Tooth",(x,-.194,1.615),(.010,.009,.032 if abs(x) < .03 else .024),white,"Head",rig,kind="cube")
        primitive("BrowScar",(.055,-.163,1.765),(.012,.008,.046),accent,"Head",rig,kind="cube")
    else:
        primitive("Chin",(0,-.112,1.585),(.083,.045,.055),skin,"Head",rig,verts=16)
        primitive("HairCap",(0,.018,1.76),(.153*brute,.132,.105),hair,"Head",rig,verts=20)
        primitive("HairBack",(0,.095,1.68),(.145*brute,.055,.16),hair,"Head",rig,verts=20)
        primitive("BrowL",(.052,-.137,1.755),(.045,.009,.008),hair,"Head",rig,kind="cube")
        primitive("BrowR",(-.052,-.137,1.755),(.045,.009,.008),hair,"Head",rig,kind="cube")
    for side,s in (("L",1),("R",-1)):
        if cfg.get("monster"):
            primitive("UpperArm"+side,(s*.315,0,1.35),(.165*brute,.11,.12),cloth,"UpperArm."+side,rig)
            primitive("Elbow"+side,(s*.43,-.018,1.23),(.11*brute,.095,.11),skin,"Forearm."+side,rig)
            primitive("Forearm"+side,(s*.515,-.045,1.10),(.17*brute,.085,.09),skin,"Forearm."+side,rig)
            primitive("Hand"+side,(s*.59,-.08,.99),(.115*brute,.068,.09),skin,"Hand."+side,rig)
            primitive("Claw"+side,(s*.62,-.14,.94),(.065*brute,.045,.10),accent,"Hand."+side,rig,kind="cylinder",verts=10)
        else:
            primitive("UpperArm"+side,(s*.385,0,1.39),(.205*brute,.105,.11),cloth,"UpperArm."+side,rig)
            primitive("Elbow"+side,(s*.515,-.008,1.335),(.105*brute,.092,.098),skin if cfg.get("monster") else cloth,"Forearm."+side,rig)
            primitive("Forearm"+side,(s*.595,-.018,1.29),(.175*brute,.082,.085),skin if cfg.get("monster") else accent,"Forearm."+side,rig)
            primitive("Hand"+side,(s*.755,-.045,1.22),(.105*brute,.062,.075),skin,"Hand."+side,rig)
        primitive("Thigh"+side,(s*.14,0,.70),(.115*brute,.12,.25),cloth,"Thigh."+side,rig)
        primitive("Knee"+side,(s*.15,-.01,.49),(.105*brute,.11,.12),cloth,"Shin."+side,rig)
        primitive("Shin"+side,(s*.15,0,.30),(.092*lean,.10,.23),accent,"Shin."+side,rig)
        primitive("Foot"+side,(s*.15,-.10,.10),(.095*brute,.18,.075),accent,"Foot."+side,rig)
    primitive("Belt",(0,-.01,.94),(.27*brute,.18,.045),accent,"Hips",rig,kind="cube")
    if cfg.get("monster"):
        primitive("RibPlateL",(-.11,-.168,1.27),(.075,.026,.16),accent,"Chest",rig,kind="cube")
        primitive("RibPlateR",(.11,-.168,1.27),(.075,.026,.16),accent,"Chest",rig,kind="cube")
        primitive("TornCloth",(0,-.18,.78),(.19,.025,.17),cloth,"Hips",rig,kind="cube")
    if cfg.get("armor"):
        primitive("Breastplate",(0,-.14,1.29),(.30,.045,.29),metal,"Chest",rig,kind="cube")
        primitive("ShoulderL",(.29,0,1.43),(.13,.17,.08),metal,"UpperArm.L",rig)
        primitive("ShoulderR",(-.29,0,1.43),(.13,.17,.08),metal,"UpperArm.R",rig)
    if cfg.get("hood"):
        primitive("Hood",(0,.025,1.72),(.18,.16,.22),cloth,"Head",rig,verts=14)
    if role=="SisterAnwen_Real":
        primitive("Robe",(0,.015,.80),(.32,.20,.42),cloth,"Hips",rig)
        primitive("StoleL",(.075,-.185,1.22),(.045,.025,.36),accent,"Chest",rig,kind="cube")
        primitive("StoleR",(-.075,-.185,1.22),(.045,.025,.36),accent,"Chest",rig,kind="cube")
    if role=="Kael_Real":
        primitive("HunterCloak",(0,.16,1.18),(.31,.045,.43),cloth,"Chest",rig,kind="cube")
        primitive("Scar",(.038,-.151,1.69),(.009,.006,.07),accent,"Head",rig,kind="cube")
    consolidate_skinned_meshes(rig)
    animate(rig)
    bpy.context.view_layer.objects.active=rig; rig.select_set(True)
    out=os.path.join(OUT,role+".glb")
    bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',use_selection=False,export_animations=True,export_skins=True,export_morph=False,export_apply=False)
    print("EXPORTED",out)

def animate(rig):
    bpy.context.view_layer.objects.active=rig
    for name,frames in {"Idle":(1,40),"Walk":(1,24),"Run":(1,16),"Attack":(1,20),"HeavyAttack":(1,28),"RecieveHit":(1,14),"Dodge":(1,18),"Death":(1,32)}.items():
        act=bpy.data.actions.new(name); rig.animation_data_create(); rig.animation_data.action=act
        for f in frames:
            for b in rig.pose.bones:
                b.rotation_mode='XYZ'
                b.rotation_euler=(0,0,0)
                b.location=(0,0,0)
            phase=0 if f==frames[0] else math.pi
            if name in ("Walk","Run"):
                rig.pose.bones["Thigh.L"].rotation_euler.x=.45*math.cos(phase)
                rig.pose.bones["Thigh.R"].rotation_euler.x=-.45*math.cos(phase)
                rig.pose.bones["UpperArm.L"].rotation_euler.x=-.30*math.cos(phase)
                rig.pose.bones["UpperArm.R"].rotation_euler.x=.30*math.cos(phase)
            elif name in ("Attack","HeavyAttack"):
                rig.pose.bones["Chest"].rotation_euler.z=(-.35 if f==frames[0] else .55)
                rig.pose.bones["UpperArm.R"].rotation_euler.x=(-1.1 if f==frames[0] else .65)
            elif name=="RecieveHit": rig.pose.bones["Chest"].rotation_euler.x=(-.18 if f==frames[0] else .12)
            elif name=="Dodge": rig.pose.bones["Root"].location.x=(0 if f==frames[0] else .45)
            elif name=="Death": rig.pose.bones["Root"].rotation_euler.x=(0 if f==frames[0] else 1.35)
            for b in rig.pose.bones:
                b.keyframe_insert("rotation_euler",frame=f); b.keyframe_insert("location",frame=f)
        track=rig.animation_data.nla_tracks.new(); track.name=name; strip=track.strips.new(name,frames[0],act)
    rig.animation_data.action=None

for role,cfg in ROLES.items(): build(role,cfg)
