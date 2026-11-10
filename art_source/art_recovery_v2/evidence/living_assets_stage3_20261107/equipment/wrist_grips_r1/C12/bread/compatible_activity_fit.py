"""Read-only C12 bread and supply fitting against the verified body and staff."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import importlib.util
import json
import math
from pathlib import Path
import sys
import time

sys.path.insert(0, sys.argv[sys.argv.index("--root") + 1] + "/art_source/art_recovery_v2/tools")
from inspect_anwen_activity_carrier import STAFF, load_contract
from inspect_living_activity_carrier import (POSITION_TOLERANCE, REST_TOLERANCE,
    check_mesh_inventory, check_topology, checked_action_binding, cyclic, digest,
    frame_columns, identity, matrix_error, multiply, point, require, world_matrices)

HAND = "hand_r"
CONTACT_LIMIT = 0.001
FIT_CLIPS = {"bread": ("Authoring_Eat",), "supply": ("Authoring_Carry_Idle", "Authoring_Carry_Walking")}
CONTACT_OFFSETS = (0.0003, 0.00085)
HELPERS = ".verification/motion/c11_activity_goal_trial_blender_r1/tools/probe_c11_activity_fits.py"


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def retained_helpers(root):
    path = root / HELPERS
    receipt_path = path.parent.parent / "receipt.json"
    frozen = read(receipt_path)["staged_source_sha256"]
    require(str(path) in frozen and all(Path(name).is_file() and digest(name) == expected
                                        for name, expected in frozen.items()), "Retained C11 fitting source changed")
    spec = importlib.util.spec_from_file_location("retained_c11_fit_helpers", path)
    module = importlib.util.module_from_spec(spec)
    original_path = sys.path[:]
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path[:] = original_path
    return module, {**frozen, str(receipt_path): digest(receipt_path)}


def exact_inputs(root, native_receipt, inspection_path, prop_receipt):
    import importlib.util
    source = Path(__file__).with_name("compatible_activity_inspector.py")
    spec = importlib.util.spec_from_file_location("compatible_activity_inspector", source)
    inspector = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inspector)
    prepared = inspector.load_contract(native_receipt)
    receipt, _, skin, paths = prepared
    clips = {row["clip"]: row for row in receipt["clips"]}
    require(receipt["sample_hz"] == 120 and len(skin) == 1 and all(row["hand"] == HAND for row in clips.values()),
            "Expected one retained skin and the actual native right hand")
    helpers, frozen = retained_helpers(root)
    for clip in clips.values():
        helpers.native_sample_times(clip)
    props, prop_hashes = helpers.load_props(root, prop_receipt)
    require(not inspection_path.exists(), "Actor import fidelity receipt must be fresh")
    inspector.inspect_blender(native_receipt, inspection_path, prepared)
    frozen.update(read(inspection_path)["source_sha256"])
    frozen.update(prop_hashes)
    frozen[str(inspection_path)] = digest(inspection_path)
    return paths, skin, {}, clips, props, helpers, frozen


def retained_prop_geometry(carrier, manifest):
    worlds, _ = world_matrices(carrier.document)
    nodes = carrier.document["nodes"]
    source = {row["name"]: row for row in manifest["meshes"]}
    primary = manifest["meshes"][0]["name"]
    points, faces, anchors, plans = [], [], [], {}
    for index, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        name = node["name"]
        require(name in source and name not in plans, "Unexpected retained prop geometry owner")
        if name == primary:
            require(matrix_error(worlds[index], identity()) <= REST_TOLERANCE, "Retained primary prop local frame changed")
        rows, winding = [], Counter()
        for surface, surface_row in enumerate(source[name]["surfaces"]):
            vertices = surface_row["attributes"]["POSITION"]
            indices = surface_row["gltf_winding_indices"]
            offset = len(points)
            if name == primary:
                anchors.extend(range(offset, offset + len(vertices)))
            rows.extend({"surface": surface, "vertex": vertex, "position": point(worlds[index], value)} for vertex, value in enumerate(vertices))
            points.extend(row["position"] for row in rows[-len(vertices):])
            for corner in range(0, len(indices), 3):
                triangle = indices[corner:corner + 3]
                faces.append(tuple(offset + vertex for vertex in triangle))
                winding[surface, cyclic(triangle)] += 1
        plans[name] = {"rows": rows, "faces": winding}
    require(set(plans) == set(source) and anchors, "Retained prop is missing its full visual inventory")
    return points, faces, anchors, plans, primary


def run(args):
    import bpy
    import numpy as np
    from mathutils import Matrix, Quaternion, Vector
    from mathutils.bvhtree import BVHTree
    from io_scene_gltf2.blender.imp.animation_utils import restore_animation_on_object

    start = time.monotonic()
    output = args.output.resolve()
    require(output.is_relative_to((args.root / ".verification/motion").resolve()), "C12 fit output escapes the worktree")
    output.mkdir(parents=True, exist_ok=False)
    report = {"asset": "C12", "status": "incomplete", "scope": "Stationary Eat, stationary Carry and forward Carry cycles. Other reachable supply aliases, gait blends, and interruption/reacquisition remain separate.",
              "grip_verified": False, "body_clearance_verified": False, "runtime_output": False, "visual_accepted": False,
              "fits": {}, "errors": []}

    def record():
        temporary = output / "receipt.tmp"
        temporary.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        temporary.replace(output / "receipt.json")

    def guard():
        require(time.monotonic() - start < args.work_seconds, "C12 fitting source deadline reached")

    try:
        paths, skin, staff, clips, props, helpers, frozen = exact_inputs(args.root, args.activity_receipt, args.blender_receipt, args.props_receipt)
        frozen[str(Path(__file__).resolve())] = digest(__file__)
        report["source_sha256"] = frozen
        prior = read(args.blender_receipt.with_name("inspection.json"))
        scene = bpy.context.scene
        scene.render.fps = 120
        scene.render.fps_base = 1.0
        scene.frame_start = 0
        scene.frame_end = math.ceil(max(clip["duration"] for clip in clips.values()) * 120)
        convert = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        inverse = convert.inverted()
        options = {key: value for key, value in prior["import_options"].items() if key != "filepath"}
        objects = list(scene.objects)
        mesh_objects = {obj.name: obj for obj in objects if obj.type == "MESH"}
        layouts, body_faces, palm_rows, all_components = [], [], {}, []
        vertex_offset = 0
        rig = mesh_objects[next(iter(skin))].modifiers[0].object
        for name, plan in skin.items():
            obj = mesh_objects[name]
            faces = [tuple(polygon.vertices) for polygon in obj.data.polygons]
            components, degenerate = helpers.component_topology([row["position"] for row in plan["rows"]], faces,
                [tuple(sorted(row.get("groups", {}).items())) for row in plan["rows"]])
            all_components.extend({**component, "mesh": name,
                                   "vertices": [vertex_offset + index for index in component["vertices"]],
                                   "representative": vertex_offset + component["representative"]} for component in components)
            layouts.append((obj, len(plan["rows"])))
            body_faces.extend(tuple(vertex_offset + index for index in face) for face in faces)
            palm_rows.update({vertex_offset + index: (name, row) for index, row in enumerate(plan["rows"]) if row.get("groups", {}).get(HAND, 0) >= 0.9})
            vertex_offset += len(plan["rows"])
            report.setdefault("body_meshes", []).append({"name": name, "triangles": len(faces), "degenerate_triangles": degenerate,
                "closed_components": sum(component["closed"] for component in components), "open_components": sum(not component["closed"] for component in components)})
        require(rig and rig.pose.bones.get(HAND) and palm_rows, "Measured right hand is absent")
        incident = defaultdict(list)
        for face in body_faces:
            for index in face:
                if index in palm_rows:
                    incident[index].append(face)
        all_faces = np.asarray(body_faces, dtype=np.int32)

        def bind(clip):
            for obj in objects:
                restore_animation_on_object(obj, clip)
                checked_action_binding(obj, clip, clips[clip]["duration"])

        def frame(row, scale_ref=None):
            guard()
            target = Matrix(frame_columns(row["hand_frame"]))
            axes = target.to_3x3()
            columns = [axes.col[index] for index in range(3)]
            scale = columns[0].length
            require(scale > 0.001 and axes.determinant() > 0 and all(abs(axis.length - scale) <= 0.0001 for axis in columns), "Invalid retained hand scale")
            require(all(abs(columns[first].dot(columns[second])) <= POSITION_TOLERANCE * scale * scale
                        for first in range(3) for second in range(first + 1, 3)), "Sheared retained right hand")
            scale_ref = scale if scale_ref is None else scale_ref
            require(abs(scale / scale_ref - 1) <= 0.0001, "A single compensated attachment cannot retain prop scale")
            tick = row["time"] * 120
            scene.frame_set(math.floor(tick), subframe=tick - math.floor(tick))
            bpy.context.view_layer.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated_rig = rig.evaluated_get(depsgraph)
            require(matrix_error(inverse @ evaluated_rig.matrix_world @ evaluated_rig.pose.bones[HAND].matrix, target) <= POSITION_TOLERANCE, "Blender hand differs from the native frame")
            metric = Matrix.Scale(scale_ref, 4) @ target.inverted() @ inverse
            chunks = []
            for obj, count in layouts:
                evaluated = obj.evaluated_get(depsgraph)
                mesh = evaluated.to_mesh()
                try:
                    require(len(mesh.vertices) == count, "Evaluated retained geometry changed inventory")
                    coords = np.empty(count * 3, dtype=np.float32)
                    mesh.vertices.foreach_get("co", coords)
                    transform = np.asarray(metric @ evaluated.matrix_world)
                    chunks.append(coords.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3])
                finally:
                    evaluated.to_mesh_clear()
            points = np.concatenate(chunks)
            require(np.isfinite(points).all(), "Nonfinite C12 geometry")
            return points, scale_ref

        def inside(tree, value, max_steps):
            near, _, _, distance = tree.find_nearest(value)
            if near is None or distance <= 0.000001:
                return None
            votes = []
            for direction in (Vector((1, .117, .419)), Vector((-.371, 1, .211)), Vector((.227, -.389, 1))):
                direction.normalize()
                origin = Vector(value)
                crossings = 0
                for _ in range(max_steps):
                    hit, _, _, _ = tree.ray_cast(origin, direction)
                    if hit is None:
                        break
                    next_origin = hit + direction * 0.000001
                    if (next_origin - origin).dot(direction) <= 0:
                        return None
                    origin = next_origin
                    crossings += 1
                else:
                    return None
                votes.append(crossings % 2)
            return bool(votes[0]) if len(set(votes)) == 1 else None

        def volumes(points, components):
            closed, representatives = [], []
            for component in components:
                representatives.append(points[component["representative"]])
                if component["closed"]:
                    region = points[component["vertices"]]
                    closed.append({"region": region, "low": region.min(axis=0), "high": region.max(axis=0),
                                   "triangles": component["local_triangles"], "tree": None})
            return closed, np.asarray(representatives).reshape(-1, 3)

        def contained(closed, representatives):
            for component in closed:
                mask = np.all(representatives >= component["low"], axis=1) & np.all(representatives <= component["high"], axis=1)
                if np.any(mask) and component["tree"] is None:
                    component["tree"] = BVHTree.FromPolygons(component["region"].tolist(), component["triangles"], all_triangles=True)
                for value in representatives[mask]:
                    if inside(component["tree"], value, len(component["triangles"]) + 1) is not False:
                        return True
            return False

        def body_geometry(points, low, high):
            # Any intersecting triangle necessarily overlaps the union AABB.
            # Full closed-component containment is separately evaluated below.
            selected = np.ones(len(all_faces), dtype=bool)
            for axis in range(3):
                coordinates = points[all_faces, axis]
                selected &= coordinates.max(axis=1) >= low[axis] - 1e-6
                selected &= coordinates.min(axis=1) <= high[axis] + 1e-6
            triangles = all_faces[selected]
            tree = None
            if len(triangles):
                used, remap = np.unique(triangles, return_inverse=True)
                tree = BVHTree.FromPolygons(points[used].tolist(), remap.reshape(-1, 3).tolist(), all_triangles=True)
            return tree, volumes(points, all_components)

        def clearance(candidate, points, geometry):
            error = float(np.linalg.norm(candidate["contact"] - points[candidate["palm_id"]]))
            if error > CONTACT_LIMIT:
                return "palm contact exceeds 1 mm", error
            tree, (closed, representatives) = geometry
            if tree is not None and tree.overlap(candidate["tree"]):
                return "prop crossed retained body triangle", error
            if contained(closed, candidate["representatives"]) or contained(candidate["volumes"], representatives):
                return "closed-component containment or ambiguous winding", error
            return "", error

        for style in (args.style,):
            phases = FIT_CLIPS[style]
            guard()
            carrier, manifest, prop_path = props[style]
            vertices, faces, anchors, prop_plans, primary_name = retained_prop_geometry(carrier, manifest)
            components, degenerate = helpers.component_topology(vertices, faces, [()] * len(vertices))
            vectors = [Vector(vertex) for vertex in vertices]
            vertex_array = np.asarray(vertices)
            prop_radius = max(vector.length for vector in vectors)
            bind(phases[0])
            reference = clips[phases[0]]["hand_samples"][clips[phases[0]]["frames"] // 2]
            points, scale = frame(reference)
            palm_target = Vector((0, .045, -.012)) * scale
            eligible = [index for index in palm_rows if .025 <= points[index][1] / scale <= .085 and .005 < np.linalg.norm(points[index]) / scale < .179]
            palms = sorted(eligible, key=lambda index: ((Vector(points[index]) - palm_target).length, index))[:12]
            require(palms, "No retained C12 right-palm vertices in the calibrated region")
            bounds = points[palms]
            geometry = body_geometry(points, bounds.min(axis=0) - 2 * prop_radius - CONTACT_LIMIT, bounds.max(axis=0) + 2 * prop_radius + CONTACT_LIMIT)
            directions = [Vector(value).normalized() for value in ((0,1,0),(0,-1,0),(1,0,0),(-1,0,0),(0,0,1),(0,0,-1),(1,1,0),(-1,1,0),(0,1,1),(0,1,-1))]
            finalist, trials = [], Counter()
            for palm_id in palms:
                guard()
                normal = sum(((Vector(points[b])-Vector(points[a])).cross(Vector(points[c])-Vector(points[a])) for a,b,c in incident[palm_id]), Vector())
                if normal.length <= 1e-8:
                    continue
                normal.normalize()
                for direction in directions:
                    anchor_id = max(anchors, key=lambda index: (vectors[index].dot(direction), -index))
                    anchor = vectors[anchor_id]
                    align = direction.rotation_difference(-normal)
                    for twist in range(0, 360, 45):
                        basis = (Quaternion(normal, math.radians(twist)) @ align).to_matrix()
                        for offset in CONTACT_OFFSETS:
                            contact = Vector(points[palm_id]) + normal * offset
                            translation = contact - basis @ anchor
                            coords = vertex_array @ np.asarray(basis).T + np.asarray(translation)
                            closed, representatives = volumes(coords, components)
                            candidate = {"basis": basis, "translation": translation, "palm_id": palm_id, "anchor": anchor, "anchor_id": anchor_id,
                                         "contact": np.asarray(contact), "low": coords.min(axis=0), "high": coords.max(axis=0),
                                         "tree": BVHTree.FromPolygons(coords.tolist(), faces, all_triangles=True), "volumes": closed,
                                         "representatives": representatives, "frames": 0, "contact_error_m": 0.0}
                            problem, _ = clearance(candidate, points, geometry)
                            trials[problem or "reference pass"] += 1
                            if not problem:
                                up = Matrix(frame_columns(reference["hand_frame"])).to_3x3() @ basis @ Vector((0,1,0))
                                candidate["rank"] = ((1 - up.normalized().y) if style == "supply" else 0.0,
                                                     (Vector(points[palm_id]) - palm_target).length, twist, offset)
                                finalist.append(candidate)
                                finalist.sort(key=lambda entry: entry["rank"])
                                del finalist[12:]
            fit = {"reference_trials": dict(trials), "verified_frames": 0, "expected_frames": sum(clips[clip]["frames"] for clip in phases),
                   "measured_palm_candidates": len(palms), "shortlist_count": len(finalist), "failures": [], "proposal": None, "surface_clearance_verified": False,
                   "closed_component_containment_verified": False, "open_prop_components": sum(not c["closed"] for c in components),
                   "degenerate_prop_triangles": degenerate}
            report["fits"][style] = fit
            record()
            for clip in phases:
                if not finalist:
                    break
                bind(clip)
                for sample in helpers.native_sample_times(clips[clip]):
                    points, _ = frame(sample, scale)
                    low = np.min([candidate["low"] for candidate in finalist], axis=0)
                    high = np.max([candidate["high"] for candidate in finalist], axis=0)
                    geometry = body_geometry(points, low, high)
                    survivors = []
                    for candidate in finalist:
                        problem, error = clearance(candidate, points, geometry)
                        if problem:
                            fit["failures"].append({"clip": clip, "time": sample["time"], "reason": problem, "contact_error_m": error})
                        else:
                            candidate["frames"] += 1
                            candidate["contact_error_m"] = max(candidate["contact_error_m"], error)
                            survivors.append(candidate)
                    finalist = survivors
                    if not finalist:
                        break
                    fit["verified_frames"] += 1
                    if fit["verified_frames"] % 120 == 0:
                        record()
            if not finalist:
                continue
            best = finalist[0]
            require(best["frames"] == fit["expected_frames"], "C12 grip candidate lacks full authored pose coverage")
            name, palm = palm_rows[best["palm_id"]]
            fit.update(surface_clearance_verified=True, closed_component_containment_verified=True,
                       proposal={"bone": HAND, "palm": [float(component) for component in best["contact"] / scale], "anchor": list(best["anchor"]),
                                 "basis": [list(col) for col in best["basis"].col], "palm_source": [name, palm["surface"], palm["vertex"]],
                                 "prop_primary_vertex": anchors.index(best["anchor_id"]),
                                 "maximum_contact_error_m": best["contact_error_m"]})
            record()
            old = set(scene.objects)
            bpy.ops.import_scene.gltf(filepath=str(prop_path), **options)
            prop_objects = [obj for obj in scene.objects if obj not in old]
            prop_meshes = {obj.name: obj for obj in prop_objects if obj.type == "MESH"}
            check_mesh_inventory([obj.name for obj in prop_objects if obj.type == "MESH"], prop_plans)
            for name, plan in prop_plans.items():
                obj = prop_meshes[name]
                check_topology(plan, [list(poly.vertices) for poly in obj.data.polygons])
                require(len(obj.data.vertices) == len(plan["rows"]), "Editable prop vertex inventory changed")
                require(all((inverse @ obj.matrix_world @ vertex.co - Vector(row["position"])).length <= REST_TOLERANCE
                            for row, vertex in zip(plan["rows"], obj.data.vertices)), "Editable prop mesh differs from measured geometry")
            roots = [obj for obj in prop_objects if obj.parent is None]
            require(len(roots) == 1, "Retained prop does not have one editable root")
            root = roots[0]
            primary = prop_meshes[primary_name]
            source_relative = primary.matrix_world.inverted() @ root.matrix_world
            bind(phases[0])
            frame(reference, scale)
            socket = bpy.data.objects.new("C12_" + style + "_ReviewSocket", None)
            scene.collection.objects.link(socket)
            constraint = socket.constraints.new("COPY_TRANSFORMS")
            constraint.target = rig
            constraint.subtarget = HAND
            local = best["basis"].to_4x4()
            local.translation = best["translation"]
            root.parent = socket
            root.matrix_parent_inverse = Matrix.Identity(4)
            root.matrix_basis = Matrix.Scale(1 / scale, 4) @ local @ inverse @ source_relative
            bpy.context.view_layer.update()
            expected = convert @ Matrix(frame_columns(reference["hand_frame"])) @ Matrix.Scale(1 / scale, 4) @ local @ inverse
            require(matrix_error(primary.matrix_world, expected) <= POSITION_TOLERANCE, "Editable grip differs from the measured proposal")
            editable = output / ("C12_" + style + "_fit_proposal.blend")
            bpy.ops.file.pack_all()
            bpy.ops.wm.save_as_mainfile(filepath=str(editable), compress=True)
            fit["editable_scene"] = {"path": editable.name, "sha256": digest(editable)}
            for obj in prop_objects:
                bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.objects.remove(socket, do_unlink=True)
            record()
        require(all(digest(Path(path)) == expected for path, expected in frozen.items()), "Frozen C12 fitting input changed")
        report["status"] = "source_probe_complete"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
        record()
        raise
    record()
    print("C12 HAND FIT PROBE: SOURCE COMPLETE", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "activity-receipt", "blender-receipt", "props-receipt", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--style", choices=FIT_CLIPS, required=True)
    parser.add_argument("--work-seconds", type=int, default=300, choices=range(60, 331))
    run(parser.parse_args(sys.argv[sys.argv.index("--") + 1:]))
