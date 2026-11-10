"""Evaluate the current recipe before replacing a saved authoring artifact.

This probe is a source-authoring diagnostic, not a native or visual acceptance.
The saved-source inspectors must still run after a successful full export.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import author_living_cast_stage2 as author
from living_cast_stage2_motion import relax_work_fingers


def main(asset):
    folder = ROOT/'models/living_cast_stage2_20261107'/asset
    source = folder/(asset+'_living_cast_v001.blend')
    if source.is_file():
        receipt = json.loads((folder/'authoring.json').read_text())
        if hashlib.sha256(source.read_bytes()).hexdigest() != receipt['blend_sha256']:
            raise ValueError('Saved input differs from its source receipt')
        bpy.ops.wm.open_mainfile(filepath=str(source))
        idle_name = 'Life_Idle_A'
    else:
        source = ROOT/'evidence/living_cast_stage2_20261107'/(asset+'_baseline.glb')
        receipt = {'blend_sha256':None}
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
        idle_name = 'Idle'
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    action = bpy.data.actions[idle_name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    baseline = {bone.name:bone.matrix_basis.copy() for bone in rig.pose.bones}
    rig.animation_data.action = None
    if asset not in ('C07','C12'):
        for side in ('l','r'):
            relax_work_fingers(rig,side,1.0)
    bpy.context.view_layer.update()
    author.CONTACT_PROBES[asset] = author.measure_palm_surfaces(rig)
    selections = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not obj.vertex_groups:
            continue
        groups = {g.index for g in obj.vertex_groups if g.name.startswith(
            ('lowerarm_','hand_','index_','middle_','ring_','pinky_','thumb_'))}
        indices = [v.index for v in obj.data.vertices if sum(
            g.weight for g in v.groups if g.group in groups) >= .80]
        if indices:
            selections.append((obj,indices))
    failures = []
    contact = {}
    for frame in range(121):
        for bone in rig.pose.bones:
            bone.matrix_basis = baseline[bone.name]
        bpy.context.view_layer.update()
        author.pose(rig,asset,'Life_Work',frame/120)
        bpy.context.view_layer.update()
        graph = bpy.context.evaluated_depsgraph_get()
        intrusions = []
        for obj,indices in selections:
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            for index in indices:
                point = evaluated.matrix_world @ mesh.vertices[index].co
                if abs(point.x)<.55 and .365<point.y<1.16 and .950<point.z<.998:
                    intrusions.append((point,index,obj.name))
            if frame == 60:
                for side in ('l','r'):
                    probe = author.CONTACT_PROBES[asset][side]
                    if probe['source_mesh'] != obj.name:
                        continue
                    point = evaluated.matrix_world @ mesh.vertices[probe['source_vertex_index']].co
                    normal = (evaluated.matrix_world.to_3x3().inverted().transposed() @
                              mesh.vertices[probe['source_vertex_index']].normal).normalized()
                    names = {g.index for g in obj.vertex_groups if g.name.endswith('_'+side)
                             and g.name.startswith(('index_','middle_','ring_','pinky_','thumb_'))}
                    finger_vertices = [v.index for v in obj.data.vertices if sum(
                        g.weight for g in v.groups if g.group in names)>=.90]
                    minimum, minimum_index = min(((evaluated.matrix_world @ mesh.vertices[i].co).z,i)
                                                 for i in finger_vertices)
                    minimum_weights = {obj.vertex_groups[g.group].name:g.weight
                                       for g in obj.data.vertices[minimum_index].groups if g.weight>.05}
                    target = Vector(author.PROFILES[asset]['palm_goals_lateral_forward_height'][side])
                    contact[side] = {'surface':list(point),'normal':list(normal),
                                     'target_distance':(point-target).length,
                                     'finger_minimum_height':minimum,
                                     'finger_minimum_vertex':minimum_index,'finger_minimum_weights':minimum_weights,
                                     'finger_clearance_to_work_plane':minimum-target.z}
            evaluated.to_mesh_clear()
        if intrusions:
            point,index,name = min(intrusions,key=lambda row:row[0].z)
            failures.append({'phase':frame/120,'vertices':len(intrusions),
                             'maximum_depth':1-point.z,'source_mesh':name,
                             'source_vertex_index':index,'world_point':list(point)})
    report = {'asset':asset,'saved_input_blend_sha256':receipt['blend_sha256'],
              'input_path':str(source),'input_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
              'recipe_sha256':hashlib.sha256((Path(__file__).parent/'living_cast_stage2_motion.py').read_bytes()).hexdigest(),
              'source_trajectory_clear':not failures,'intrusions':failures,'contact':contact,
              'saved_output_verified':False,'native_verified':False,'visual_accepted':False}
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'work_recipe_probe.json').write_text(json.dumps(report,indent=2)+'\n')
    print('RECIPE_CLEARANCE',asset,'intrusion_frames',len(failures),'contact',contact,flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset',required=True,nargs='+')
    for asset in parser.parse_args(sys.argv[sys.argv.index('--')+1:]).asset:
        main(asset)
