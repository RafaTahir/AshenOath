"""Matched source reviews with the actual supported station and hand labels."""
import math
import bpy
from mathutils import Vector


def render_views(rig, asset, destination, models, profiles, clips, fps):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ReviewWorld")
    scene.world.color = (.055, .055, .055)
    props = []
    profile = profiles[asset]
    if profile["contact_required"]:
        carrier = models / "props" / ("station_" + profile["identity"] + ".glb")
        if not carrier.is_file():
            raise ValueError("Source review requires the actual authored station prop: " + str(carrier))
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(carrier))
        props = [obj for obj in bpy.data.objects if obj not in before]
        for obj in props:
            if obj.parent is None:
                obj.location = (0, .40, 1.00)
        mat = bpy.data.materials.new("ReviewOnly_TableTimber")
        mat.diffuse_color = (.17, .11, .065, 1)
        for centre, size in [((0, .76, .975), (1.10, .80, .05)),
                             ((-.48, .43, .475), (.08, .08, .95)),
                             ((.48, .43, .475), (.08, .08, .95)),
                             ((-.48, 1.09, .475), (.08, .08, .95)),
                             ((.48, 1.09, .475), (.08, .08, .95))]:
            bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
            table = bpy.context.object
            table.name = "ReviewOnly_SupportedTable"
            table.scale = size
            table.data.materials.append(mat)
            props.append(table)
    data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (3.6, 5.5, 2.7)
    camera.rotation_euler = (Vector((0, .22, .95))-camera.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = 2.45
    labels = []
    for side in ("l", "r"):
        text = bpy.data.curves.new("ReviewOnly_HandLabel_"+side, "FONT")
        text.size = .055
        text.align_x = "CENTER"
        text.body = "hand_"+side
        obj = bpy.data.objects.new(text.name, text)
        scene.collection.objects.link(obj)
        obj.rotation_euler = camera.rotation_euler
        labels.append((side, obj))
    moments = [("Life_Idle_A", .25), ("Life_Idle_B", .5), ("Life_Work", .25),
               ("Life_Work", .5), ("Life_Work", .75), ("Life_Listen", .56), ("Life_Speak", .43)]
    moments.extend((name, .5) for name in clips if name not in {value[0] for value in moments})
    for clip, phase in moments:
        for obj in props:
            obj.hide_render = clip not in ("Life_Work", "Life_Lower_Book")
        action = bpy.data.actions[clip]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        scene.frame_set(round(clips[clip]*fps*phase))
        bpy.context.view_layer.update()
        for side, label in labels:
            label.location = rig.matrix_world @ rig.pose.bones["hand_"+side].head + Vector((-.08 if side == "l" else .10, .04, .10))
        scene.render.filepath = str(destination / (clip+"_"+str(round(phase*100))+".png"))
        bpy.ops.render.render(write_still=True)
