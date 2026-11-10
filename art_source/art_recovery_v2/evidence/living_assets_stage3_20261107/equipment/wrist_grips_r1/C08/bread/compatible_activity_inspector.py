"""Inspect an immutable native activity carrier through the actual Blender importer.

Only C08 is enabled for this initial precursor. No carrier, skin, bone, frame,
animation, prop or exporter repair is permitted here. Pure helpers import without
bpy; the actual inspection requires a separately granted background Blender job.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from activity_pose_weight_transport import f32, normalize_f32, pack_f32

POSITION_TOLERANCE = 0.0001
REST_TOLERANCE = 0.00001
SOURCE_COMPONENT_TOLERANCE = 0.000001
CLIPS = ('Authoring_Eat', 'Authoring_Carry_Idle', 'Authoring_Carry_Walking')
ACCEPTED_C08_RECEIPT = "0b7587f31ed2805984e0441a1f1800b255239d28b8cc5ed77599d9271610479b"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def distance(a, b):
    require(len(a) == len(b) == 3 and all(math.isfinite(v) for v in (*a, *b)), "Nonfinite three-dimensional point")
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def identity():
    return [[float(i == j) for j in range(4)] for i in range(4)]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def point(matrix, value):
    return [sum(matrix[i][j] * value[j] for j in range(3)) + matrix[i][3] for i in range(3)]


def frame_columns(columns):
    require(len(columns) == 4 and all(len(column) == 3 for column in columns), "Invalid native frame columns")
    result = identity()
    for column in range(4):
        for row in range(3): result[row][column] = columns[column][row]
    return result


def matrix_error(first, second):
    require(all(len(matrix) == 4 and all(len(row) == 4 for row in matrix) for matrix in (first, second)), "Invalid four-dimensional frame")
    require(all(math.isfinite(value) for matrix in (first, second) for row in matrix for value in row), "Nonfinite frame")
    return max(math.sqrt(sum((first[row][column] - second[row][column]) ** 2 for row in range(4))) for column in range(4))


def check_mesh_inventory(names, expected):
    """C08 has no rigid helper meshes: every mesh must match its skin plan."""
    names = list(names)
    require(len(names) == len(set(names)) and set(names) == set(expected),
            "Complete mesh inventory differs (unexpected, missing or duplicated source mesh)")


def checked_action_binding(obj, clip, duration):
    """Check what the importer actually bound, including its stashed slot."""
    animation = getattr(obj, "animation_data", None)
    tracks = [track for track in animation.nla_tracks if track.name == clip] if animation else []
    require(len(tracks) <= 1, "Ambiguous imported clip track: " + obj.name)
    if not tracks:
        require(animation is None or animation.action is None, "Prior action survived a missing requested clip: " + obj.name)
        require(obj.type != "ARMATURE", "Requested activity clip is absent from its armature owner: " + clip)
        return None
    require(len(tracks[0].strips) == 1, "Imported clip must have one explicit source strip")
    strip = tracks[0].strips[0]
    action, slot = animation.action, animation.action_slot
    require(action is not None and action == strip.action and action.name == clip,
            "Bound imported action differs from requested clip: " + clip)
    require(slot is not None and slot == strip.action_slot and bool(slot.identifier),
            "Bound imported action slot differs from the requested source strip")
    require(abs(float(action.frame_range[0])) <= 0.0001 and
            abs(float(action.frame_range[1]) / 120.0 - duration) <= SOURCE_COMPONENT_TOLERANCE,
            "Imported action timing changed")
    return {"object": obj.name, "action": action.name, "slot": slot.identifier, "source_track": tracks[0].name}


def node_matrix(node):
    if "matrix" in node:
        require(len(node["matrix"]) == 16, "Invalid glTF node matrix")
        return [[node["matrix"][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    require(abs(x*x + y*y + z*z + w*w - 1.0) <= 0.00001, "Invalid retained quaternion")
    rotation = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    scale = node.get("scale", [1.0, 1.0, 1.0])
    translation = node.get("translation", [0.0, 0.0, 0.0])
    result = identity()
    for i in range(3):
        for j in range(3):
            result[i][j] = rotation[i][j] * scale[j]
        result[i][3] = translation[i]
    require(all(math.isfinite(v) for row in result for v in row), "Nonfinite retained frame")
    return result


def world_matrices(document):
    nodes = document["nodes"]
    parents = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            require(type(child) is int and 0 <= child < len(nodes) and child not in parents, "Ambiguous glTF node parent")
            parents[child] = i
    result = {}
    active = set()
    def visit(index):
        require(index not in active, "Cyclic retained glTF hierarchy")
        if index in result:
            return result[index]
        active.add(index)
        local = node_matrix(nodes[index])
        result[index] = multiply(visit(parents[index]), local) if index in parents else local
        active.remove(index)
        return result[index]
    for index in range(len(nodes)):
        visit(index)
    return result, parents


class Carrier:
    def __init__(self, path):
        self.path = Path(path)
        raw = self.path.read_bytes()
        require(len(raw) >= 28, "Truncated GLB")
        magic, version, size = struct.unpack_from("<III", raw)
        require(magic == 0x46546C67 and version == 2 and size == len(raw), "Invalid GLB header")
        offset, chunks = 12, []
        while offset < len(raw):
            require(offset + 8 <= len(raw), "Truncated GLB chunk header")
            length, kind = struct.unpack_from("<II", raw, offset)
            offset += 8
            require(length % 4 == 0 and offset + length <= len(raw), "Invalid GLB chunk length")
            chunks.append((kind, raw[offset:offset+length]))
            offset += length
        require([kind for kind, _ in chunks] == [0x4E4F534A, 0x004E4942], "Only a self-contained JSON/BIN GLB is supported")
        self.document = json.loads(chunks[0][1])
        self.binary = chunks[1][1]
        require(len(self.document.get("buffers", [])) == 1 and "uri" not in self.document["buffers"][0], "External animation/geometry buffers are unsupported")
        self.cache = {}

    def accessor(self, index):
        if index in self.cache:
            return self.cache[index]
        accessor = self.document["accessors"][index]
        require("sparse" not in accessor and not accessor.get("normalized", False), "Sparse/normalized activity accessors are unsupported")
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor["type"]]
        code, byte_size = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}[accessor["componentType"]]
        view = self.document["bufferViews"][accessor["bufferView"]]
        require(view.get("buffer", 0) == 0, "Accessor uses a different buffer")
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", byte_size * width)
        count = accessor["count"]
        require(type(count) is int and count > 0 and stride >= byte_size * width, "Invalid accessor shape")
        end = start + (count - 1) * stride + byte_size * width
        require(end <= view.get("byteOffset", 0) + view["byteLength"] and end <= len(self.binary), "Accessor escapes its exact buffer view")
        rows = [struct.unpack_from("<" + code * width, self.binary, start + i * stride) for i in range(count)]
        require(all(math.isfinite(value) for row in rows for value in row), "Nonfinite retained accessor")
        self.cache[index] = rows
        return rows


def cyclic(triangle):
    require(len(triangle) == 3, "Non-triangle face")
    value = tuple(triangle)
    return min(value, value[1:] + value[:1], value[2:] + value[:2])


def build_mesh_plan(carrier, manifest):
    """Prove explicit source indices, then derive the documented importer order.

    No position lookup is used. Coincident seam vertices retain their original
    separate indices, named skin vectors and wound triangle multiplicities.
    """
    document = carrier.document
    worlds, parents = world_matrices(document)
    plans = {}
    for name, source in manifest["meshes"].items():
        matching = [(i, node) for i, node in enumerate(document["nodes"]) if node.get("name") == name and "mesh" in node and "skin" in node]
        require(len(matching) == 1, "Missing or ambiguous source mesh identity: " + name)
        node_index, node = matching[0]
        skin = document["skins"][node["skin"]]
        joints = skin["joints"]
        names = [document["nodes"][index]["name"] for index in joints]
        require(len(names) == len(set(names)), "Ambiguous named skin joint")
        primitives = document["meshes"][node["mesh"]]["primitives"]
        require(len(primitives) == len(source["surfaces"]), "Source surface inventory changed")
        rows, faces, lookup, surfaces, duplicates = [], Counter(), {}, [], []
        for surface, (primitive, original) in enumerate(zip(primitives, source["surfaces"])):
            require(primitive.get("mode", 4) == 4 and not primitive.get("targets"), "Unexpected primitive or morph ownership")
            attrs = primitive["attributes"]
            positions = carrier.accessor(attrs["POSITION"])
            indices = [int(row[0]) for row in carrier.accessor(primitive["indices"])]
            require(indices == original["indices"] and len(indices) % 3 == 0, "Explicit wound triangle/index order changed")
            require(len(positions) == len(original["vertices"]), "Explicit source vertex inventory changed")
            used = sorted(set(indices))
            require(used == list(range(len(positions))), "Unreferenced or invalid vertices prevent a complete import identity proof")
            stride = original["stride"]
            require(stride in (4, 8), "Unsupported retained influence count")
            js = [carrier.accessor(attrs[f"JOINTS_{group}"]) for group in range(stride // 4)]
            ws = [carrier.accessor(attrs[f"WEIGHTS_{group}"]) for group in range(stride // 4)]
            base = len(rows)
            equivalent = {}
            for rank, vertex in enumerate(used):
                retained = original["vertices"][vertex]
                require(max(abs(a-b) for a, b in zip(positions[vertex], retained["position"])) <= SOURCE_COMPONENT_TOLERANCE, "Explicit rest vertex/order changed")
                source_joints = [names[js[group][vertex][slot]] for group in range(stride // 4) for slot in range(4)]
                weights = [ws[group][vertex][slot] for group in range(stride // 4) for slot in range(4)]
                require(source_joints == retained["joints"], "Explicit named joint slot/order changed")
                require(pack_f32(normalize_f32(normalize_f32(weights))) == retained["q"], "Carrier no longer occupies the original native weight cells")
                # Blender's importer writes positive slots in order using REPLACE.
                # Preserve and check that exact operation; world probes still test
                # it against the original unnormalized native uint16 skin.
                imported_groups = {}
                for joint, weight in zip(source_joints, weights):
                    if weight != 0.0:
                        imported_groups[joint] = weight
                record = {"surface": surface, "vertex": vertex, "imported_vertex": base + rank,
                          "position": list(positions[vertex]), "groups": imported_groups,
                          "joint_slots": source_joints, "native_q": retained["q"]}
                rows.append(record)
                lookup[(surface, vertex)] = base + rank
                key = (tuple(positions[vertex]), tuple(source_joints), tuple(retained["q"]), tuple(weights))
                equivalent.setdefault(key, []).append(vertex)
            for vertices in equivalent.values():
                if len(vertices) > 1:
                    duplicates.append({"surface": surface, "vertices": vertices, "multiplicity": len(vertices),
                                       "complete_position_named_skin_equivalence": True, "indices_kept_distinct": True})
            for first in range(0, len(indices), 3):
                faces[(surface, cyclic(indices[first:first+3]))] += 1
            surfaces.append({"surface": surface, "vertices": len(used), "triangles": len(indices)//3, "import_vertex_offset": base})
        plans[name] = {"node": node_index, "world": worlds[node_index], "joint_nodes": joints, "joint_names": names,
                       "joint_worlds": {name: worlds[index] for name, index in zip(names, joints)},
                       "joint_parents": {name: document["nodes"][parents[index]]["name"] if parents.get(index) in joints else None for name, index in zip(names, joints)},
                       "rows": rows, "lookup": lookup, "faces": faces, "surfaces": surfaces, "equivalent_duplicates": duplicates}
    require(plans, "Empty retained skin manifest")
    return plans


def check_topology(plan, polygons):
    require(len(polygons) == sum(plan["faces"].values()), "Imported face inventory changed")
    actual = Counter()
    for polygon in polygons:
        require(len(polygon) == 3, "Imported topology is not triangular")
        require(all(type(index) is int and 0 <= index < len(plan["rows"]) for index in polygon), "Imported face references an unknown vertex")
        rows = [plan["rows"][index] for index in polygon]
        require(len({row["surface"] for row in rows}) == 1, "Imported face mixes retained surfaces")
        actual[(rows[0]["surface"], cyclic([row["vertex"] for row in rows]))] += 1
    require(actual == plan["faces"], "Imported wound triangle identity/multiplicity changed")


def load_contract(receipt_path):
    receipt_path = Path(receipt_path).resolve()
    require(digest(receipt_path) == ACCEPTED_C08_RECEIPT, "The explicit accepted C08 native receipt differs from this inspector's pinned input")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
    require(receipt.get("asset") == "C08" and receipt.get("status") == "authoring_pose_exported", "Only the accepted C08 carrier is enabled")
    require(receipt.get("roundtrip", {}).get("verified") is True and receipt.get("source_animations_changed") is False, "Original native carrier gate did not pass")
    require(receipt["roundtrip"]["position_tolerance_m"] == POSITION_TOLERANCE, "Native position tolerance changed")
    paths = {"receipt": receipt_path}
    for key in ("carrier", "raw_carrier", "retained_skin_manifest"):
        path = receipt_path.parent / Path(receipt[key + "_path"].replace("\\", "/")).name
        require(path.is_file() and digest(path) == receipt[key + "_sha256"], "Immutable input differs: " + key)
        paths[key] = path
    carrier = Carrier(paths["carrier"])
    manifest = json.loads(paths["retained_skin_manifest"].read_text())
    plans = build_mesh_plan(carrier, manifest)
    mesh_nodes = [node for node in carrier.document["nodes"] if "mesh" in node]
    check_mesh_inventory([node.get("name") for node in mesh_nodes], plans)
    require(all("skin" in node for node in mesh_nodes), "C08-only contract does not accept rigid mesh ownership")
    worlds, parents = world_matrices(carrier.document)
    for name, frame in ((receipt["role"], receipt["normalized_visual_frame"]), ("Armature", receipt["skeleton_frame"])):
        nodes = [i for i, node in enumerate(carrier.document["nodes"]) if node.get("name") == name]
        require(len(nodes) == 1 and matrix_error(worlds[nodes[0]], frame_columns(frame)) <= REST_TOLERANCE, "Carrier root/rest frame differs from native receipt: " + name)
    clips = {row["clip"]: row for row in receipt["clips"]}
    require(set(clips) == set(CLIPS) and len(receipt["clips"]) == len(CLIPS), "Unexpected activity clip inventory")
    animations = carrier.document["animations"]
    require({row["name"] for row in animations} == set(CLIPS) and len(animations) == len(CLIPS), "Carrier animation identity changed")
    for animation in animations:
        times = [time[0] for sampler in animation["samplers"] for time in carrier.accessor(sampler["input"])]
        require(min(times) == 0.0 and abs(max(times) - clips[animation["name"]]["duration"]) <= SOURCE_COMPONENT_TOLERANCE, "Carrier clip timing differs from native samples")
    samples = receipt["roundtrip"]["skin_samples"]
    require(len(samples) == 5 * len(CLIPS) and Counter(row["clip"] for row in samples) == Counter({clip: 5 for clip in CLIPS}), "All 15 original native skin samples are required")
    for sample in samples:
        require(sample.get("verified") is True and sample["position_tolerance_m"] == POSITION_TOLERANCE, "Unverified original native skin sample")
        seen = set()
        for probe in sample["original_world_probes"]:
            key = (probe["mesh"], probe["surface"], probe["vertex"])
            require(key not in seen, "Duplicate original native probe identity")
            seen.add(key)
            plan = plans[probe["mesh"]]
            index = plan["lookup"][(probe["surface"], probe["vertex"])]
            require(distance(plan["rows"][index]["position"], probe["retained_rest_point"]) <= REST_TOLERANCE, "Original probe does not identify its declared source vertex")
        require(len(seen) == sample["vertices_sampled"], "Native probe count differs")
    return receipt, carrier, plans, paths


def inspect_blender(receipt_path, output, prepared):
    import bpy
    from mathutils import Matrix
    from io_scene_gltf2.blender.imp.animation_utils import restore_animation_on_object
    receipt, carrier, plans, paths = prepared
    frozen = {str(path): digest(path) for path in paths.values()}
    frozen[str(Path(__file__).resolve())] = digest(__file__)
    frozen[str(Path(sys.argv[sys.argv.index("--root") + 1]) / "art_source/art_recovery_v2/tools/activity_pose_weight_transport.py")] = digest(Path(sys.argv[sys.argv.index("--root") + 1]) / "art_source/art_recovery_v2/tools/activity_pose_weight_transport.py")
    import io_scene_gltf2
    importer_root = Path(io_scene_gltf2.__file__).resolve().parent
    importer_files = [importer_root / relative for relative in ("__init__.py", "blender/imp/mesh.py", "blender/imp/vnode.py", "blender/imp/animation_utils.py", "blender/imp/animation_node.py")]
    frozen.update({str(path): digest(path) for path in importer_files})
    report = {"asset": "C08", "status": "fail", "verified": False, "scope": "Actual Blender imported skin versus immutable original native probes",
              "source_sha256": frozen, "blender_version": bpy.app.version_string, "position_tolerance_m": POSITION_TOLERANCE,
              "rest_tolerance_m": REST_TOLERANCE, "nearest_point_matching": False, "frame_correction_applied": False,
              "grip_verified": False, "body_clearance_verified": False, "visual_accepted": False, "runtime_output": False,
              "rigid_body_obstacle_fidelity_verified": False,
              "carrier_rigid_mesh_inventory": [node.get("name") for node in carrier.document["nodes"] if "mesh" in node and "skin" not in node],
              "meshes": [], "samples": [], "errors": []}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.fps = 120
        scene.render.fps_base = 1.0
        scene.frame_start = 0
        options = {"filepath": str(paths["carrier"]), "merge_vertices": False, "bone_heuristic": "BLENDER",
                   "guess_original_bind_pose": False, "disable_bone_shape": True, "import_shading": "NORMALS"}
        bpy.ops.import_scene.gltf(**options)
        report["import_options"] = options
        objects = list(scene.objects)
        convert = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        inverse = convert.inverted()
        imported = {}
        check_mesh_inventory([obj.name for obj in objects if obj.type == "MESH"], plans)
        for obj in objects:
            if obj.type != "MESH": continue
            imported[obj.name] = obj
        for obj in objects:
            restore_animation_on_object(obj, "")
        scene.frame_set(0)
        bpy.context.view_layer.update()
        worlds, parents = world_matrices(carrier.document)
        report["root_frames"] = []
        for name in ("ActivityPose_C08", receipt["role"], "Armature"):
            source_nodes = [index for index, node in enumerate(carrier.document["nodes"]) if node.get("name") == name]
            imported_nodes = [obj for obj in objects if obj.name == name]
            require(len(source_nodes) == len(imported_nodes) == 1, "Imported root/frame identity is ambiguous: " + name)
            actual = inverse @ imported_nodes[0].matrix_world @ convert
            error = matrix_error(actual, worlds[source_nodes[0]])
            require(error <= REST_TOLERANCE, "Imported retained root/frame changed: " + name)
            report["root_frames"].append({"name": name, "maximum_error": error})
        for name, plan in plans.items():
            obj = imported[name]
            require(len(obj.data.vertices) == len(plan["rows"]), "Imported vertex identity/multiplicity changed")
            check_topology(plan, [list(poly.vertices) for poly in obj.data.polygons])
            modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
            require(len(modifiers) == 1 and len(obj.modifiers) == 1, "Unexpected imported skin/modifier ownership")
            armature = modifiers[0].object
            require(armature is not None and set(armature.data.bones.keys()) == set(plan["joint_names"]), "Imported named skin joint inventory differs")
            rest_error, bone_error = 0.0, 0.0
            for row in plan["rows"]:
                vertex = obj.data.vertices[row["imported_vertex"]]
                actual = inverse @ obj.matrix_world @ vertex.co
                expected = point(plan["world"], row["position"])
                rest_error = max(rest_error, distance(actual, expected))
                actual_groups = {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight != 0.0}
                require(set(actual_groups) == set(row["groups"]), "Imported per-vertex named skin ownership changed")
                require(all(abs(actual_groups[joint] - weight) <= SOURCE_COMPONENT_TOLERANCE for joint, weight in row["groups"].items()), "Importer changed encoded skin weights")
            # BLENDER bone heuristic adds the documented fixed +90deg local X
            # display orientation. Undo only that coordinate convention while
            # comparing source rests; never change actual imported bone data.
            for joint in plan["joint_names"]:
                bone = armature.data.bones[joint]
                parent = bone.parent.name if bone.parent else None
                require(parent == plan["joint_parents"][joint], "Imported joint parent changed")
                original_axis_frame = armature.matrix_world @ bone.matrix_local @ convert.inverted()
                actual = inverse @ original_axis_frame @ convert
                expected = Matrix(plan["joint_worlds"][joint])
                bone_error = max(bone_error, matrix_error(actual, expected))
            require(rest_error <= REST_TOLERANCE, f"Imported rest mesh moved: {rest_error:.9g}m")
            require(bone_error <= REST_TOLERANCE, f"Imported joint rest/frame changed: {bone_error:.9g}")
            report["meshes"].append({"name": name, "vertices": len(plan["rows"]), "triangles": sum(plan["faces"].values()),
                                      "surfaces": plan["surfaces"], "equivalent_duplicate_vertices": plan["equivalent_duplicates"],
                                      "maximum_rest_vertex_error_m": rest_error, "maximum_joint_rest_error": bone_error})
        for sample in receipt["roundtrip"]["skin_samples"]:
            clip = sample["clip"]
            bound = []
            for obj in objects:
                restore_animation_on_object(obj, clip)
                binding = checked_action_binding(obj, clip, next(row["duration"] for row in receipt["clips"] if row["clip"] == clip))
                if binding is not None:
                    bound.append(binding)
            require(any(obj.type == "ARMATURE" and obj.animation_data and obj.animation_data.action for obj in objects), "Activity action has no actual armature owner")
            frame = sample["time"] * 120.0
            integer = math.floor(frame)
            scene.frame_set(integer, subframe=frame - integer)
            bpy.context.view_layer.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated = {}
            try:
                for name, obj in imported.items():
                    owner = obj.evaluated_get(depsgraph)
                    mesh = owner.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
                    evaluated[name] = (owner, mesh)
                    require(len(mesh.vertices) == len(plans[name]["rows"]), "Evaluated skin changed vertex identity")
                    check_topology(plans[name], [list(poly.vertices) for poly in mesh.polygons])
                maximum, worst = 0.0, None
                for probe in sample["original_world_probes"]:
                    plan = plans[probe["mesh"]]
                    index = plan["lookup"][(probe["surface"], probe["vertex"])]
                    owner, mesh = evaluated[probe["mesh"]]
                    actual = inverse @ owner.matrix_world @ mesh.vertices[index].co
                    error = distance(actual, probe["world_point"])
                    if error >= maximum:
                        maximum = error
                        worst = {"mesh": probe["mesh"], "surface": probe["surface"], "source_vertex": probe["vertex"],
                                 "imported_vertex": index, "expected": probe["world_point"], "actual": list(actual)}
                report["samples"].append({"clip": clip, "time": sample["time"], "blender_frame": frame, "bound_actions": bound,
                                          "probes": len(sample["original_world_probes"]), "maximum_world_vertex_error_m": maximum, "worst": worst,
                                          "verified": maximum <= POSITION_TOLERANCE})
                require(maximum <= POSITION_TOLERANCE, f"Actual Blender skin differs from original native {clip}@{sample['time']}: {maximum:.9g}m")
            finally:
                for owner, mesh in evaluated.values(): owner.to_mesh_clear()
        require(len(report["samples"]) == 5 * len(CLIPS), "Not every original native phase was evaluated")
        report["verified"] = True
        report["status"] = "pass"
    except Exception as error:
        report["errors"].append(str(error))
    for path, expected in frozen.items():
        if digest(path) != expected:
            report["errors"].append("Immutable input changed: " + path)
            report["verified"] = False
            report["status"] = "fail"
    Path(output).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("ACTIVITY_BLENDER_IMPORT_FIDELITY", report["status"].upper(), "C08", "native_original_probes", sum(row["probes"] for row in report["samples"]))
    require(report["verified"], "; ".join(report["errors"]))


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(arguments)
    require(not args.output.exists(), "Inspection receipt must be fresh")
    require(args.output.parent.is_dir(), "Inspection output directory must already exist")
    inspect_blender(args.receipt, args.output)


if __name__ == "__main__":
    main()
