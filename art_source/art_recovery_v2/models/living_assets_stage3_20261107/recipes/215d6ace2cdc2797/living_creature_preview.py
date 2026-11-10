"""Bounded source-review frames; these are not native gameplay acceptance."""
import math
from pathlib import Path

import bpy
from mathutils import Vector


def render_views(rig, actions, meshes, folder, fps):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = 'BOTH'
    scene.display.shading.background_type = 'WORLD'
    if scene.world is None:
        scene.world = bpy.data.worlds.new('CreatureSourceReviewWorld')
    scene.world.color = (.075, .085, .095)
    camera_data = bpy.data.cameras.new('CreatureSourceReview')
    camera = bpy.data.objects.new('CreatureSourceReview', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = 'ORTHO'
    output = Path(folder)/'source_review'
    output.mkdir(parents=True, exist_ok=True)
    samples = [('Idle', [0, .25, .5, .75]), ('Investigate', [.5]),
               ('Feed', [.38, .61]), ('Sleep', [.5])]

    def evaluate(clip, phase):
        action, rig_slot, morph_slots, seconds = actions[clip]
        rig.animation_data.action = action
        rig.animation_data.action_slot = rig_slot
        for binding in morph_slots:
            obj, slot = binding[:2]
            morph_action = binding[2] if len(binding) > 2 else action
            obj.data.shape_keys.animation_data.action = morph_action
            obj.data.shape_keys.animation_data.action_slot = slot
        frame = phase*seconds*fps
        scene.frame_set(int(frame), subframe=frame-int(frame))
        bpy.context.view_layer.update()

    # Keep one camera for the whole comparison. Reframing each inflated sac
    # or moved antenna would hide the scale of its actual authored motion.
    points = []
    for clip, phases in samples:
        for phase in phases:
            evaluate(clip, phase)
            graph = bpy.context.evaluated_depsgraph_get()
            for obj in meshes:
                evaluated = obj.evaluated_get(graph)
                points.extend(evaluated.matrix_world @ Vector(point) for point in evaluated.bound_box)
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    centre = (low+high)*.5
    size = high-low
    span = max(size.x, size.y, size.z, .3)
    direction = Vector((1.15, -1.7, .85)).normalized()
    camera.location = centre+direction*span*2.8
    camera.rotation_euler = (centre-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.ortho_scale = max(size.z, max(size.x, size.y)*.85)*1.45
    results = []
    for clip, phases in samples:
        for phase in phases:
            evaluate(clip, phase)
            path = output/(clip+'_%02d.png' % round(phase*100))
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            results.append(str(path))
    return results
