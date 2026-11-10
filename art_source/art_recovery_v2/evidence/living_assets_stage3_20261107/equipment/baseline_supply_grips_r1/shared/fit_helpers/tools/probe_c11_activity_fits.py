"""Propose C11 grips from the retained hand skin and exact runtime prop meshes.

Run in an isolated background Blender process. Writes only a fresh review folder.
The output is source evidence and an editable scene, never runtime grip metadata.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_living_activity_carrier import (Carrier, POSITION_TOLERANCE, checked_action_binding,
    check_mesh_inventory, check_topology, cyclic, digest, frame_columns, load_contract,
    matrix_error, require)
from inspect_retained_prop_carrier import prove_carrier

HAND = "hand_r"
HERTZ = 120
CONTACT_LIMIT = 0.001
CONTACT_OFFSETS = (0.0003, 0.00085)
FITS = {"bread": ("Authoring_Eat",),
        "supply": ("Authoring_Carry_Idle", "Authoring_Carry_Walking")}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_props(root, proof_path):
    proof = read_json(proof_path)
    require(proof.get("accepted") is True and proof.get("grip_verified") is False,
            "An accepted retained-prop extraction receipt is required")
    require([job["name"] for job in proof["runs"]] == ["parse", "synthetic_contract", "actual_props"]
            and all(job["passed"] for job in proof["runs"]), "Prop extraction has incomplete native gates")
    outputs = {}
    for relative, row in proof["outputs"].items():
        path = (root / relative).resolve()
        require(path.is_relative_to(root) and path.is_file() and path.name not in outputs,
                "Unexpected retained prop output path")
        require(path.stat().st_size == row["bytes"] and digest(path) == row["sha256"],
                "Retained prop output bytes changed: " + relative)
        outputs[path.name] = path
    require(len(outputs) == 11, "Incomplete retained prop extraction")
    result = {}
    for style in FITS:
        stem = "retained_" + style
        carrier = Carrier(outputs[stem + ".glb"])
        manifest = read_json(outputs[stem + "_mesh_manifest.json"])
        channel = read_json(outputs[stem + "_channel_manifest.json"])
        result[style] = (carrier, manifest, outputs[stem + ".glb"])
        require(prove_carrier(carrier, manifest, channel)["verified"], "Retained prop identity failed")
    return result, {str(path): digest(path) for path in [proof_path, *outputs.values()]}


def component_topology(points, triangles, bindings):
    """Diagnose topology without welding or changing the evaluated mesh."""
    require(len(points) == len(bindings), "Incomplete topology binding inventory")
    keys = [(tuple(round(float(axis), 6) for axis in p), binding) for p, binding in zip(points, bindings)]
    owners = defaultdict(list)
    all_edges = []
    degenerate = 0
    for index, triangle in enumerate(triangles):
        a, b, c = (keys[i] for i in triangle)
        if len({a, b, c}) < 3:
            degenerate += 1
            all_edges.append(())
            continue
        edges = tuple((min(x, y), max(x, y), 1 if x < y else -1) for x, y in ((a, b), (b, c), (c, a)))
        for x, y, sign in edges:
            owners[(x, y)].append((index, sign))
        all_edges.append(edges)
    seen = set()
    components = []
    for start, edges in enumerate(all_edges):
        if not edges or start in seen:
            continue
        stack = [start]
        seen.add(start)
        component = []
        closed = True
        while stack:
            index = stack.pop()
            component.append(index)
            for x, y, _ in all_edges[index]:
                uses = owners[(x, y)]
                closed = closed and len(uses) == 2 and uses[0][1] != uses[1][1]
                for neighbor, _ in uses:
                    if neighbor not in seen:
                        seen.add(neighbor)
                        stack.append(neighbor)
        used = sorted({vertex for face_index in component for vertex in triangles[face_index]})
        index_map = {vertex: index for index, vertex in enumerate(used)}
        components.append({"triangles": component, "closed": closed,
                           "representative": triangles[min(component)][0], "vertices": used,
                           "local_triangles": [tuple(index_map[v] for v in triangles[i]) for i in component]})
    return components, degenerate


def native_sample_times(clip):
    samples = clip["hand_samples"]
    require(len(samples) == clip["frames"] and len(samples) >= 2, "Incomplete 120 Hz native hand samples")
    times = [row["time"] for row in samples]
    require(times[0] == 0 and math.isclose(times[-1], clip["duration"], abs_tol=1e-6), "Native endpoints missing")
    require(all(math.isfinite(t) and abs(t - index / HERTZ) <= 1e-6 for index, t in enumerate(times[:-1]))
            and times[-2] < times[-1], "Unexpected native sampling schedule")
    return samples


def run(args):
    import bpy
    import numpy as np
    from mathutils import Matrix, Quaternion, Vector
    from mathutils.bvhtree import BVHTree
    from io_scene_gltf2.blender.imp.animation_utils import restore_animation_on_object

    start = time.monotonic()
    output = args.output.resolve()
    require(output.is_relative_to((args.root / ".verification/motion").resolve()), "Review output escapes the worktree")
    output.mkdir(parents=True, exist_ok=False)
    report = {"asset": "C11", "status": "incomplete", "grip_verified": False,
              "body_clearance_verified": False, "runtime_output": False, "visual_accepted": False,
              "fits": {}, "errors": []}
    def record():
        temporary = output / "receipt.tmp"
        temporary.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        temporary.replace(output / "receipt.json")
    def guard():
        require(time.monotonic() - start < args.work_seconds, "Source fitting work deadline reached")

    try:
        receipt, _, plans, actor_paths = load_contract(args.activity_receipt)
        verified_import = read_json(args.blender_proof)
        require(verified_import.get("verified") is True and len(verified_import.get("samples", [])) == 15
                and verified_import.get("source_sha256", {}).get(str(actor_paths["carrier"])) == digest(actor_paths["carrier"]),
                "The exact activity carrier must have passed Blender import fidelity")
        require(verified_import["blender_version"] == bpy.app.version_string, "Blender version differs from retained import proof")
        for name, expected in verified_import["source_sha256"].items():
            require(Path(name).is_file() and digest(Path(name)) == expected, "Blender import proof input changed: " + name)
        props, frozen = load_props(args.root.resolve(), args.props_proof.resolve())
        frozen.update({str(path): digest(path) for path in [args.blender_proof, *actor_paths.values(), Path(__file__)]})
        report["input_sha256"] = frozen
        report["contact_limit_m"] = CONTACT_LIMIT
        report["contact_offsets_m"] = CONTACT_OFFSETS
        require(receipt["sample_hz"] == HERTZ and len(plans) == 1, "Unexpected C11 native sampling or mesh inventory")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.fps = HERTZ
        scene.render.fps_base = 1.0
        scene.frame_start = 0
        scene.frame_end = math.ceil(max(clip["duration"] for clip in receipt["clips"]) * HERTZ)
        convert = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
        inverse = convert.inverted()
        options = dict(merge_vertices=False, bone_heuristic="BLENDER", guess_original_bind_pose=False,
                       disable_bone_shape=True, import_shading="NORMALS")
        bpy.ops.import_scene.gltf(filepath=str(actor_paths["carrier"]), **options)
        actor_objects = list(scene.objects)
        check_mesh_inventory([obj.name for obj in actor_objects if obj.type == "MESH"], plans)
        name, plan = next(iter(plans.items()))
        body = scene.objects[name]
        require(len(body.modifiers) == 1 and body.modifiers[0].type == "ARMATURE", "Retained C11 armature modifier changed")
        rig = body.modifiers[0].object
        require(rig and rig.pose.bones.get(HAND),
                "Retained C11 skin and right hand are required")
        body_faces = [tuple(poly.vertices) for poly in body.data.polygons]
        check_topology(plan, body_faces)
        require(len(body.data.vertices) == len(plan["rows"]), "Imported C11 vertex inventory changed")
        palm_ids = [row["imported_vertex"] for row in plan["rows"] if row["groups"].get(HAND, 0.0) >= 0.9]
        incident = {index: [face for face in body_faces if index in face] for index in palm_ids}
        body_components, body_degenerate = component_topology(
            [row["position"] for row in plan["rows"]], body_faces,
            [tuple(sorted(row["groups"].items())) for row in plan["rows"]])
        report["body_topology"] = {"triangles": len(body_faces), "closed_components": sum(c["closed"] for c in body_components),
                                    "open_components": sum(not c["closed"] for c in body_components),
                                    "degenerate_triangles": body_degenerate}
        clips = {row["clip"]: row for row in receipt["clips"]}
        prop_imports = {}
        for style, (_, manifest, path) in props.items():
            old = set(scene.objects)
            bpy.ops.import_scene.gltf(filepath=str(path), **options)
            objects = [obj for obj in scene.objects if obj not in old]
            mesh_rows = {row["name"]: row for row in manifest["meshes"]}
            check_mesh_inventory([obj.name for obj in objects if obj.type == "MESH"], mesh_rows)
            roots = [obj for obj in objects if obj.parent not in objects]
            require(len(roots) == 1, "Retained prop import has ambiguous root")
            main = scene.objects[manifest["meshes"][0]["name"]]
            main_frame = main.matrix_world.copy()
            expected_main = Matrix(frame_columns(mesh_rows[main.name]["frame"]))
            vertices, faces, anchors = [], [], []
            for obj in objects:
                if obj.type != "MESH": continue
                matrix = inverse @ main_frame.inverted() @ obj.matrix_world
                expected = expected_main.inverted() @ Matrix(frame_columns(mesh_rows[obj.name]["frame"]))
                require(matrix_error(matrix @ convert, expected) <= 1e-6,
                        "Blender changed the native prop child frame: " + obj.name)
                rest = []
                expected = Counter()
                for surface in mesh_rows[obj.name]["surfaces"]:
                    base = len(rest)
                    rest.extend(surface["attributes"]["POSITION"])
                    indices = surface["gltf_winding_indices"]
                    require(set(indices) == set(range(surface["vertices"])), "Retained prop contains unbound vertices")
                    expected.update(cyclic(tuple(base + i for i in indices[j:j+3])) for j in range(0, len(indices), 3))
                require(len(rest) == len(obj.data.vertices), "Blender prop vertex inventory changed")
                require(Counter(cyclic(tuple(poly.vertices)) for poly in obj.data.polygons) == expected,
                        "Blender prop wound triangle inventory changed")
                for index, vertex in enumerate(obj.data.vertices):
                    local = inverse @ vertex.co
                    require((local - Vector(rest[index])).length <= 1e-6, "Blender retained prop vertex identity changed")
                offset = len(vertices)
                vertices.extend(matrix @ vertex.co for vertex in obj.data.vertices)
                faces.extend(tuple(offset + index for index in poly.vertices) for poly in obj.data.polygons)
                if obj == main: anchors.extend(range(offset, len(vertices)))
            require(anchors and vertices and faces, "Missing retained prop placement surface")
            components, degenerate = component_topology(vertices, faces, [()] * len(vertices))
            prop_imports[style] = (objects, roots[0], main_frame, vertices, faces, anchors, components, degenerate)
            for obj in objects:
                obj.hide_render = True
                obj.hide_set(True)

        def bind(clip):
            for obj in actor_objects:
                restore_animation_on_object(obj, clip)
                checked_action_binding(obj, clip, clips[clip]["duration"])

        def frame(row, scale_ref=None):
            guard()
            target = Matrix(frame_columns(row["hand_frame"]))
            columns = [target.to_3x3().col[i] for i in range(3)]
            scale = columns[0].length
            require(scale > 0.001 and all(abs(v.length-scale) <= 0.0001 for v in columns), "Native hand scale is not uniform")
            unit = target.to_3x3() * (1.0 / scale)
            require(abs(unit.determinant()-1.0) <= 0.0001 and all(abs(columns[i].dot(columns[j])) <= 0.0001 for i,j in ((0,1),(1,2),(0,2))),
                    "Native hand basis is reflected or sheared")
            scale_ref = scale if scale_ref is None else scale_ref
            require(abs(scale / scale_ref - 1.0) <= 0.0001, "A single compensated attachment cannot preserve prop scale")
            tick = row["time"] * HERTZ
            scene.frame_set(math.floor(tick), subframe=tick - math.floor(tick))
            bpy.context.view_layer.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated_rig = rig.evaluated_get(depsgraph)
            actual = inverse @ evaluated_rig.matrix_world @ evaluated_rig.pose.bones[HAND].matrix
            require(matrix_error(actual, target) <= POSITION_TOLERANCE, "Blender hand frame differs from actual native frame")
            owner = body.evaluated_get(depsgraph)
            mesh = owner.to_mesh()
            try:
                require(len(mesh.vertices) == len(plan["rows"]) and len(mesh.polygons) == len(body_faces), "Evaluated body inventory changed")
                coords = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
                mesh.vertices.foreach_get("co", coords)
                transform = np.array(Matrix.Scale(scale_ref, 4) @ target.inverted() @ inverse @ owner.matrix_world)
                points = coords.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3]
                require(np.isfinite(points).all(), "Nonfinite body surface sample")
                return points, scale_ref
            finally:
                owner.to_mesh_clear()

        def inside(tree, point, maximum_steps):
            near, _, _, distance = tree.find_nearest(point)
            if near is None or distance <= 0.000001:
                return None
            votes = []
            for direction in (Vector((1, .117, .419)), Vector((-.371, 1, .211)), Vector((.227, -.389, 1))):
                direction.normalize()
                origin = Vector(point)
                crossings = 0
                for _ in range(maximum_steps):
                    hit, _, _, _ = tree.ray_cast(origin, direction)
                    if hit is None: break
                    next_origin = hit + direction * 0.000001
                    if (next_origin-origin).dot(direction) <= 0: return None
                    origin = next_origin
                    crossings += 1
                else:
                    return None
                votes.append(crossings % 2)
            return bool(votes[0]) if len(set(votes)) == 1 else None

        def volumes(points, components):
            result = []
            for component in components:
                if not component["closed"]: continue
                triangles = component["local_triangles"]
                region = points[component["vertices"]]
                result.append((BVHTree.FromPolygons(region.tolist(), triangles, all_triangles=True),
                               region.min(axis=0), region.max(axis=0), len(triangles) + 1))
            return result

        def contained(closed, representatives):
            for tree, low, high, steps in closed:
                for point in representatives:
                    if np.all(point >= low) and np.all(point <= high):
                        if inside(tree, point, steps) is not False:
                            return True
            return False

        def body_geometry(points):
            tree = BVHTree.FromPolygons(points.tolist(), body_faces, all_triangles=True)
            return [tree, None, [points[c["representative"]] for c in body_components]]

        def prop_candidate(vertices, faces, components, basis, translation, hand_id, anchor):
            coords = vertices @ np.array(basis).T + np.array(translation)
            return {"basis": basis, "translation": translation, "hand_id": hand_id, "anchor": anchor,
                    "contact": np.array(basis @ anchor + translation),
                    "tree": BVHTree.FromPolygons(coords.tolist(), faces, all_triangles=True),
                    "coords": coords, "components": components, "volumes": None,
                    "representatives": [coords[c["representative"]] for c in components],
                    "samples": 0, "maximum_contact_error_m": 0.0}

        def clearance(candidate, points, geometry):
            contact = float(np.linalg.norm(candidate["contact"] - points[candidate["hand_id"]]))
            tree, _, representatives = geometry
            if contact > CONTACT_LIMIT: return "palm contact exceeds 1 mm", contact
            overlaps = tree.overlap(candidate["tree"])
            if overlaps:
                candidate["intersections"] = overlaps
                return "body/prop triangle crossing or contact", contact
            if geometry[1] is None:
                geometry[1] = volumes(points, body_components)
            if candidate["volumes"] is None:
                candidate["volumes"] = volumes(candidate["coords"], candidate["components"])
            if contained(geometry[1], candidate["representatives"]) or contained(candidate["volumes"], representatives):
                return "closed-component containment or ambiguous winding", contact
            return "", contact

        def palm_approaches(points, hand_id, normal):
            # Tilt within the outward hemisphere only. The local support score
            # favors directions clear of neighboring closed fingers and skin.
            pivot = Vector(points[hand_id])
            neighborhood = points - points[hand_id]
            neighborhood = neighborhood[np.linalg.norm(neighborhood, axis=1) <= 0.045]
            tangent = normal.orthogonal().normalized()
            tilts = []
            for angle in (25, 45, 60):
                for around in range(0, 360, 45):
                    axis = Quaternion(normal, math.radians(around)) @ tangent
                    direction = Quaternion(axis, math.radians(angle)) @ normal
                    clearance = float(np.max(neighborhood @ np.array(direction)))
                    tilts.append((clearance, angle, around, direction))
            tilts.sort(key=lambda row: row[:3])
            approaches = [normal]
            for _, _, _, direction in tilts:
                if all(direction.dot(prior) < 0.96 for prior in approaches):
                    approaches.append(direction)
                if len(approaches) == 3: break
            return pivot, approaches

        def face_owner(face_index):
            weights = Counter()
            for index in body_faces[face_index]:
                weights.update(plan["rows"][index]["groups"])
            return weights.most_common(1)[0][0] if weights else "unweighted"

        for style, requested_clips in FITS.items():
            guard()
            objects, source_root, main_frame, vertices, faces, anchors, components, degenerate = prop_imports[style]
            reference_clip = requested_clips[0]
            bind(reference_clip)
            reference_rows = native_sample_times(clips[reference_clip])
            reference = reference_rows[len(reference_rows)//2]
            points, scale = frame(reference)
            geometry = body_geometry(points)
            palm_target = Vector((0, .045, -.012)) * scale
            eligible = [index for index in palm_ids if .025 <= points[index][1] / scale <= .085
                        and .005 < np.linalg.norm(points[index]) / scale < .179]
            require(eligible, "No measured high-weight retained palm surface inside the established wrist region")
            palms = sorted(eligible, key=lambda i: ((Vector(points[i])-palm_target).length, i))
            directions = [Vector((x,y,z)).normalized() for x,y,z in ((0,1,0),(0,-1,0),(1,0,0),(-1,0,0),(0,0,1),(0,0,-1),
                         (1,1,0),(-1,1,0),(0,1,1),(0,1,-1))]
            support = [(direction, max(anchors, key=lambda i: (vertices[i].dot(direction), -i))) for direction in directions]
            prop_vertices = np.array([list(vertex) for vertex in vertices])
            trials = Counter()
            conflicts = Counter()
            closest_overlap = None
            owners = {}
            finalists = []
            fit = {"reference_time": reference["time"], "measured_palm_candidates": len(palms), "reference_trials": {},
                   "verified_frames": 0, "expected_frames": sum(clips[c]["frames"] for c in requested_clips),
                   "surface_clearance_verified": False, "closed_component_containment_verified": False,
                   "open_prop_components": sum(not c["closed"] for c in components), "degenerate_prop_triangles": degenerate,
                   "shortlist_count": 0, "failures": [], "proposal": None}
            report["fits"][style] = fit
            for hand_id in palms:
                guard()
                normal = sum(((Vector(points[b])-Vector(points[a])).cross(Vector(points[c])-Vector(points[a]))
                              for a,b,c in incident[hand_id]), Vector())
                if normal.length <= 1e-8: continue
                normal.normalize()
                pivot, approaches = palm_approaches(points, hand_id, normal)
                for approach in approaches:
                    for offset in CONTACT_OFFSETS:
                        guard()
                        contact = pivot + approach * offset
                        for direction, anchor_index in support:
                            # Support vertex of the complete primary retained mesh.
                            anchor = vertices[anchor_index]
                            align = direction.rotation_difference(-approach)
                            for twist in (0, 45, 90, 135, 180, 225, 270, 315):
                                basis = (Quaternion(approach, math.radians(twist)) @ align).to_matrix()
                                candidate = prop_candidate(prop_vertices, faces, components, basis,
                                                           contact-basis @ anchor, hand_id, anchor)
                                problem, _ = clearance(candidate, points, geometry)
                                trials[problem or "reference pass"] += 1
                                intersections = candidate.get("intersections", [])
                                if intersections:
                                    for body_face, _ in intersections:
                                        if body_face not in owners:
                                            owners[body_face] = face_owner(body_face)
                                        conflicts[owners[body_face]] += 1
                                    if closest_overlap is None or len(intersections) < closest_overlap["count"]:
                                        closest_overlap = {"count": len(intersections), "palm_vertex": hand_id,
                                                           "prop_primary_vertex": anchor_index, "offset_m": offset,
                                                           "pairs": [{"body_face": body_face, "prop_face": prop_face,
                                                                      "dominant_bone": owners[body_face]}
                                                                     for body_face, prop_face in intersections[:12]]}
                                if not problem:
                                    candidate["anchor_index"] = anchor_index
                                    up = Matrix(frame_columns(reference["hand_frame"])).to_3x3() @ basis @ Vector((0,1,0))
                                    candidate["rank"] = ((1 - up.normalized().y) if style == "supply" else 0,
                                                         (pivot-palm_target).length, offset, twist)
                                    finalists.append(candidate)
                                    finalists.sort(key=lambda row: row["rank"])
                                    del finalists[8:]
                fit.update(reference_trials=dict(trials), reference_conflicts_by_dominant_bone=dict(conflicts),
                           closest_reference_overlap=closest_overlap, shortlist_count=len(finalists))
                record()
            # Verify the bounded shortlist against every retained frame, sharing evaluated body geometry.
            for clip in requested_clips:
                if not finalists: break
                bind(clip)
                for index, row in enumerate(native_sample_times(clips[clip])):
                    points, _ = frame(row, scale)
                    geometry = body_geometry(points)
                    survivors = []
                    for candidate in finalists:
                        problem, distance = clearance(candidate, points, geometry)
                        if problem:
                            fit["failures"].append({"clip": clip, "sample": index, "time": row["time"],
                                                    "reason": problem, "contact_error_m": distance})
                        else:
                            candidate["samples"] += 1
                            candidate["maximum_contact_error_m"] = max(candidate["maximum_contact_error_m"], distance)
                            survivors.append(candidate)
                    finalists = survivors
                    if not finalists: break
                    fit["verified_frames"] += 1
                    if fit["verified_frames"] % 120 == 0: record()
            if not finalists: continue
            best = finalists[0]
            require(best["samples"] == fit["expected_frames"], "Full-cycle clearance is incomplete")
            source = plan["rows"][best["hand_id"]]
            fit.update(surface_clearance_verified=True, closed_component_containment_verified=True,
                       proposal={"bone": HAND, "palm": list(best["contact"] / scale), "anchor": list(best["anchor"]),
                                 "basis": [list(col) for col in best["basis"].col], "measured_scale": scale,
                                 "palm_source": {"mesh": name, "surface": source["surface"], "vertex": source["vertex"]},
                                 "prop_primary_vertex": best["anchor_index"], "maximum_contact_error_m": best["maximum_contact_error_m"]})
            bind(reference_clip)
            frame(reference, scale)
            socket = bpy.data.objects.new("C11_" + style + "_ReviewSocket", None)
            scene.collection.objects.link(socket)
            constraint = socket.constraints.new("COPY_TRANSFORMS")
            constraint.target = rig
            constraint.subtarget = HAND
            local = best["basis"].to_4x4()
            local.translation = best["translation"]
            source_relative = main_frame.inverted() @ source_root.matrix_world
            source_root.parent = socket
            source_root.matrix_parent_inverse = Matrix.Identity(4)
            source_root.matrix_basis = Matrix.Scale(1/scale, 4) @ local @ inverse @ source_relative
            for obj in objects:
                obj.hide_render = False
                obj.hide_set(False)
            for other_style, prop in prop_imports.items():
                if other_style != style:
                    for obj in prop[0]:
                        obj.hide_render = True
                        obj.hide_set(True)
            bpy.context.view_layer.update()
            primary = scene.objects[props[style][1]["meshes"][0]["name"]]
            expected = convert @ Matrix(frame_columns(reference["hand_frame"])) @ Matrix.Scale(1/scale, 4) @ local @ inverse
            require(matrix_error(primary.matrix_world, expected) <= POSITION_TOLERANCE,
                    "Editable Blender attachment differs from the verified native-space proposal")
            editable = output / ("C11_" + style + "_fit_proposal.blend")
            bpy.ops.file.pack_all()
            bpy.ops.wm.save_as_mainfile(filepath=str(editable), compress=True)
            fit["editable_scene"] = {"path": editable.name, "sha256": digest(editable)}
            record()
        require(all(digest(Path(path)) == expected for path, expected in frozen.items()), "Frozen fitting inputs changed")
        report["status"] = "source_probe_complete"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
        record()
        raise
    record()
    print("C11 HAND FIT PROBE: SOURCE COMPLETE", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "activity-receipt", "blender-proof", "props-proof", "output"):
        parser.add_argument("--" + name, required=True, type=Path)
    parser.add_argument("--work-seconds", type=int, default=300, choices=range(60, 331))
    run(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]))
