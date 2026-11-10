"""Inspect the saved native cup trajectory against retained physical geometry.

This is source evidence, not a substitute for the real imported actor fixture
or the in-level visual review. The cup follows its measured hand attachment.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_living_cast_prop_clearance import inside_solid

ROOT = Path(__file__).resolve().parents[1]


def main(frames=None):
    frames = list(range(121)) if frames is None else list(frames)
    models = ROOT/'models/living_cast_stage2_20261107'
    receipt = json.loads((models/'C10/authoring.json').read_text())
    calibration = json.loads((models/'props/merrow_cup_calibration.json').read_text())
    source = models/'C10/C10_living_cast_v001.blend'
    if hashlib.sha256(source.read_bytes()).hexdigest() != receipt['blend_sha256']:
        raise ValueError('Stale Merrow authored source')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    actors = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not obj.vertex_groups:
            continue
        hands = {g.index for g in obj.vertex_groups if g.name.startswith(
            ('lowerarm_', 'hand_', 'index_', 'middle_', 'ring_', 'pinky_', 'thumb_'))}
        indices = {v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in hands) >= .80}
        right_hand_groups = {g.index for g in obj.vertex_groups if g.name.endswith('_r') and g.name.startswith(
            ('hand_', 'index_', 'middle_', 'ring_', 'pinky_', 'thumb_'))}
        right_hand = {v.index for v in obj.data.vertices
                      if sum(g.weight for g in v.groups if g.group in right_hand_groups) >= .80}
        head_groups = {g.index for g in obj.vertex_groups if g.name == 'Head' or g.name.startswith('Face_')}
        head = {v.index for v in obj.data.vertices
                if sum(g.weight for g in v.groups if g.group in head_groups) >= .60}
        obj.data.calc_loop_triangles()
        triangles = [tuple(triangle.vertices) for triangle in obj.data.loop_triangles]
        head_triangles = [triangle for triangle in triangles if all(i in head for i in triangle)]
        hand_edges = {tuple(sorted((triangle[i], triangle[(i+1) % 3])))
                      for triangle in triangles for i in range(3)
                      if all(v in right_hand for v in triangle)}
        actors.append((obj, indices, triangles, right_hand, head_triangles, hand_edges))
    action = bpy.data.actions['Life_Drink']
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(60)
    bpy.context.view_layer.update()
    hand = rig.matrix_world @ rig.pose.bones['hand_r'].matrix
    cup_sip = Matrix(calibration['poses']['sip']['cup_world_blender'])
    cup_in_hand = hand.inverted() @ cup_sip
    carrier = models/'props/merrow_cup_world.glb'
    if hashlib.sha256(carrier.read_bytes()).hexdigest() != calibration['carrier_sha256']:
        raise ValueError('Stale retained cup carrier')
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(carrier))
    cup_objects = [obj for obj in bpy.data.objects if obj not in before and obj.type == 'MESH']
    points = []
    faces = []
    lookup = {}
    for obj in cup_objects:
        indices = {}
        for vertex in obj.data.vertices:
            point = cup_sip.inverted() @ obj.matrix_world @ vertex.co
            key = tuple(round(v, 6) for v in point)
            if key not in lookup:
                lookup[key] = len(points)
                points.append(point)
            indices[vertex.index] = lookup[key]
        faces.extend([[indices[i] for i in poly.vertices] for poly in obj.data.polygons])
    edges = Counter(tuple(sorted((face[i], face[(i+1) % len(face)])))
                    for face in faces for i in range(len(face)))
    closed = bool(edges) and all(count == 2 for count in edges.values())
    open_edges = sum(count != 2 for count in edges.values())
    tree = BVHTree.FromPolygons(points, faces)
    minimum = Vector([min(p[i] for p in points) for i in range(3)])
    maximum = Vector([max(p[i] for p in points) for i in range(3)])
    grip = Vector(calibration['actual_handle_surface']['gltf'])
    grip = Vector((grip.x, -grip.z, grip.y))
    palm = calibration['actual_palm']
    reports = []
    for clip in ('Life_Cup_Hold', 'Life_Drink'):
        action = bpy.data.actions[clip]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        intrusions = []
        face_contacts = []
        minimum_hand_to_face = float('inf')
        maximum_grip_error = 0.0
        for frame in frames:
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            cup_world = rig.matrix_world @ rig.pose.bones['hand_r'].matrix @ cup_in_hand
            inverse = cup_world.inverted()
            graph = bpy.context.evaluated_depsgraph_get()
            hits = []
            for obj, hand_vertices, triangles, right_hand, head_triangles, hand_edges in actors:
                evaluated = obj.evaluated_get(graph)
                mesh = evaluated.to_mesh()
                world_points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
                local_points = [inverse @ point for point in world_points]
                if not head_triangles or not right_hand:
                    raise ValueError('Actual head/face and complete hand skin bindings are required')
                face_tree = BVHTree.FromPolygons(world_points, head_triangles, all_triangles=True)
                frame_face_hits = []
                for index in right_hand:
                    closest, normal, face, distance = face_tree.find_nearest(world_points[index])
                    if closest is None:
                        raise ValueError('Native face surface cannot be queried')
                    minimum_hand_to_face = min(minimum_hand_to_face, distance)
                    if distance < .002:
                        frame_face_hits.append({'vertex': index, 'distance': distance,
                                                'method': 'actual hand skin is within 2mm of actual face surface'})
                for edge in hand_edges:
                    start, finish = [world_points[i] for i in edge]
                    delta = finish-start
                    length = delta.length
                    if length < .00001:
                        continue
                    hit, normal, face, distance = face_tree.ray_cast(start, delta/length, length)
                    if hit is not None and .0001 < distance < length-.0001:
                        frame_face_hits.append({'edge': list(edge), 'depth': min(distance, length-distance),
                                                'method': 'actual hand skin crosses actual face triangle'})
                if frame_face_hits:
                    face_contacts.append({'phase': frame/120, 'mesh': obj.name,
                                          'contacts': frame_face_hits})
                for vertex in mesh.vertices:
                    point = local_points[vertex.index]
                    if obj.name == palm['source_mesh'] and vertex.index == palm['source_vertex_index']:
                        maximum_grip_error = max(maximum_grip_error, (point-grip).length)
                    if any(point[i] <= minimum[i] or point[i] >= maximum[i] for i in range(3)):
                        continue
                    closest, normal, face, distance = tree.find_nearest(point)
                    if closed and closest is not None and distance > .002 and inside_solid(tree, point):
                        hits.append({'mesh': obj.name, 'vertex': vertex.index, 'depth': distance,
                                     'body_part': 'hand_forearm' if vertex.index in hand_vertices else 'body_head'})
                # The retained mug has intentional open seams. Do not invent a
                # closed volume: test the actual skin edges against its wall
                # triangles instead. Two millimetres only tolerates tangency
                # at an edge endpoint; crossings through skin remain failures.
                checked = set()
                for triangle in triangles:
                    vertices = [local_points[i] for i in triangle]
                    if any(max(p[i] for p in vertices) < minimum[i] or min(p[i] for p in vertices) > maximum[i]
                           for i in range(3)):
                        continue
                    for edge_index in range(3):
                        edge = tuple(sorted((triangle[edge_index], triangle[(edge_index+1) % 3])))
                        if edge in checked:
                            continue
                        checked.add(edge)
                        start, finish = [local_points[i] for i in edge]
                        delta = finish-start
                        length = delta.length
                        if length <= .004:
                            continue
                        hit, normal, face, distance = tree.ray_cast(start, delta/length, length)
                        perpendicular_depth = (min(abs(normal.dot(start-hit)), abs(normal.dot(finish-hit)))
                                               if hit is not None else 0.0)
                        if hit is not None and .002 < distance < length-.002 and perpendicular_depth > .002:
                            hits.append({'mesh': obj.name, 'edge': list(edge),
                                         'depth': perpendicular_depth, 'edge_crossing_depth': min(distance,length-distance),
                                         'cup_face': face, 'cup_local_intersection': list(hit),
                                         'skin_groups': [[obj.vertex_groups[g.group].name for g in obj.data.vertices[i].groups if g.weight>.2] for i in edge],
                                         'method': 'actual skin edge crosses retained cup triangle',
                                         'body_part': 'hand_forearm' if any(i in hand_vertices for i in edge) else 'body_head'})
                evaluated.to_mesh_clear()
            if hits:
                intrusions.append({'phase': frame/120, 'vertices': len(hits),
                                   'deepest': max(hits, key=lambda item: item['depth'])})
        reports.append({'clip': clip, 'intrusions': intrusions, 'maximum_grip_error': maximum_grip_error,
                        'hand_face_contacts': face_contacts, 'minimum_hand_to_face_clearance': minimum_hand_to_face,
                        'clear': not intrusions and not face_contacts and maximum_grip_error <= .002})
    result = {'actor_blend_sha256': receipt['blend_sha256'], 'actor_carrier_sha256': receipt['review_glb_sha256'],
              'cup_carrier_sha256': calibration['carrier_sha256'], 'sample_hz': 30,
              'sampled_frames': frames, 'full_trajectory_sampled': frames == list(range(121)),
              'closed_retained_cup': closed, 'nonmanifold_or_open_edges': open_edges,
              'surface_crossings_checked': True, 'maximum_skin_intrusion_m': .002,
              'clips': reports, 'source_trajectory_clear': frames == list(range(121)) and all(row['clear'] for row in reports),
              'inspection_recipe_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'native_verified': False, 'visual_accepted': False}
    path = models/('C10/source_cup_clearance.json' if frames == list(range(121)) else 'C10/source_cup_probe.json')
    path.write_text(json.dumps(result, indent=2)+'\n')
    print('MERROW_CUP_TRAJECTORY', [(row['clip'], row['clear'], len(row['intrusions'])) for row in reports], flush=True)


if __name__ == '__main__':
    main()
