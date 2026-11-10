"""Prove explicit native vertex identities in actual retained prop GLBs; no Blender."""
import math
import struct

from inspect_living_activity_carrier import Carrier, frame_columns, matrix_error, world_matrices
from activity_pose_rigid_channel_transport import decode_q, pack, normalized

EPSILON = 0.000001


def require(condition, message):
    if not condition:
        raise ValueError(message)


def _same_native_float32(first, second):
    # Godot's JSON writer rounds the decimal spelling of its float32 channels.
    # Compare their native bits, without applying a component tolerance.
    encoding = struct.Struct("<" + "f" * len(first))
    try:
        return encoding.pack(*first) == encoding.pack(*second)
    except (OverflowError, struct.error):
        return False


def prove_carrier(carrier, manifest, channel_manifest=None):
    require(manifest.get("verified") is True and manifest.get("schema_version") == 1, "Unverified native prop manifest")
    document = carrier.document
    require(not document.get("skins") and not document.get("animations"), "Retained prop must not introduce a skin or animation")
    nodes = [(index, node) for index, node in enumerate(document["nodes"]) if "mesh" in node]
    expected = manifest["meshes"]
    require(len(nodes) == len(expected) == manifest["mesh_count"], "Complete native prop mesh inventory differs")
    names = [node.get("name") for _, node in nodes]
    require(len(set(names)) == len(names) and set(names) == {row["name"] for row in expected}, "Native prop mesh names are missing, extra or ambiguous")
    if channel_manifest is not None:
        require(channel_manifest.get("schema_version") == 1 and channel_manifest.get("engine_version") == "4.6.3", "Unverified packed-cell manifest schema")
        require(set(channel_manifest["meshes"]) == set(names), "Packed-cell complete mesh inventory differs")
    worlds, _ = world_matrices(document)
    result = {"verified": True, "explicit_native_vertex_ids": True, "nearest_point_mapping": False,
              "component_tolerance": EPSILON, "meshes": [], "grip_verified": False, "visual_accepted": False}
    for original in expected:
        node_index, node = next((index, node) for index, node in nodes if node["name"] == original["name"])
        require("skin" not in node and not node.get("weights"), "Retained prop gained deformation ownership")
        require(matrix_error(worlds[node_index], frame_columns(original["frame"])) <= EPSILON, "Native prop source frame changed")
        primitives = document["meshes"][node["mesh"]]["primitives"]
        require(len(primitives) == len(original["surfaces"]), "Native prop surface/material-role inventory differs")
        reports = []
        packed_mesh = channel_manifest["meshes"][original["name"]] if channel_manifest is not None else None
        if packed_mesh is not None:
            require(packed_mesh["original_path"] == original["path"] and len(packed_mesh["surfaces"]) == len(original["surfaces"]), "Packed-cell source mesh/path/surface identity differs")
        for surface_index, (surface, primitive) in enumerate(zip(original["surfaces"], primitives)):
            packed = packed_mesh["surfaces"][surface_index] if packed_mesh is not None else None
            if packed is not None:
                require(packed["attributes"] == surface["attributes"] and packed["indices"] == surface["gltf_winding_indices"], "Packed-cell original channels or winding differ")
                require(set(packed["cells"]) == set(surface["attributes"]) & {"NORMAL", "TANGENT"}, "Packed-cell channel inventory differs")
            require(primitive.get("mode", 4) == 4 and not primitive.get("targets"), "Unexpected retained prop topology/deformation")
            require(set(primitive["attributes"]) == set(surface["attributes"]), "Native prop vertex-channel inventory differs")
            maximum = {}
            for semantic, raw in surface["attributes"].items():
                values = carrier.accessor(primitive["attributes"][semantic])
                require(len(values) == len(raw) == surface["vertices"], "Native prop vertex count/order differs")
                error = 0.0
                cells = packed["cells"].get(semantic) if packed is not None else None
                if cells is not None:
                    require(len(cells) == len(raw), "Packed-cell explicit vertex count differs")
                    require(document["accessors"][primitive["attributes"][semantic]]["componentType"] == 5126, "Packed-cell transport requires float32 vectors")
                for index, (before, after) in enumerate(zip(raw, values)):
                    require(len(before) == len(after) and all(math.isfinite(v) for v in (*before, *after)), "Nonfinite or malformed explicit native vertex channel")
                    error = max(error, *(abs(a-b) for a, b in zip(before, after)))
                    if cells is None:
                        require(error <= EPSILON, f"Native prop vertex identity/channel differs: {original['name']}/{semantic}/{index}")
                    else:
                        q = cells[index]
                        require(len(q) == 2 and all(type(v) is int and 0 <= v <= 65535 for v in q), "Invalid actual native packed cells")
                        tangent = semantic == "TANGENT"
                        require(_same_native_float32(decode_q(q, tangent), before),
                                "Original packed cells do not equal actual native float32 channel readback")
                        require(pack(after, tangent) == q, "Transported vector leaves the original packed cells")
                        if tangent:
                            require(after[3] == before[3], "Tangent handedness changed")
                        else:
                            require(pack(normalized(after)) == q, "Importer normal normalization leaves original packed cells")
                maximum[semantic] = error
            indices = [row[0] for row in carrier.accessor(primitive["indices"])] if "indices" in primitive else list(range(surface["vertices"]))
            require(indices == surface["gltf_winding_indices"], "Native prop explicit ordered winding/index identity differs")
            require(all(type(value) is int and 0 <= value < surface["vertices"] for value in indices), "Invalid native prop triangle indices")
            reports.append({"surface": surface["surface"], "vertices": surface["vertices"], "triangles": len(indices)//3,
                            "native_vertex_to_glb_vertex": "same explicit index", "maximum_component_errors": maximum,
                            "normal_tangent_transport": "exact original uint16 cells" if packed is not None else "direct original floats"})
        result["meshes"].append({"name": original["name"], "native_path": original["path"], "node": node_index, "surfaces": reports})
    return result


def inspect(path, manifest, channel_manifest=None):
    return prove_carrier(Carrier(path), manifest, channel_manifest)
