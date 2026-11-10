"""Carry protected native animation buffers unchanged into a retained GLB.

The derivative may change ambient actions/morphs. Combat and locomotion data
are copied byte-for-byte only after matching every targeted node's rest matrix
and parent identity. No production file is ever written by this module.
"""
import copy
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

from living_creature_motion_profiles import REPLACED_CLIPS


def read_glb(path):
    raw = Path(path).read_bytes()
    if len(raw) < 28 or raw[:4] != b"glTF":
        raise ValueError("Expected a binary glTF source")
    version, total = struct.unpack_from("<II", raw, 4)
    if version != 2 or total != len(raw):
        raise ValueError("Invalid retained GLB version or size")
    size, kind = struct.unpack_from("<II", raw, 12)
    if kind != 0x4E4F534A:
        raise ValueError("Expected initial JSON chunk")
    document = json.loads(raw[20:20+size])
    position = 20+size
    if position+8 > len(raw) or len(document.get("buffers", [])) != 1:
        raise ValueError("Expected one retained binary buffer")
    binary_size, binary_kind = struct.unpack_from("<II", raw, position)
    if binary_kind != 0x004E4942 or position+8+binary_size != len(raw):
        raise ValueError("Expected one retained binary buffer")
    return document, raw[position+8:position+8+binary_size]


def write_glb(path, document, binary):
    document["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" "*((-len(encoded)) % 4)
    binary += b"\0"*((-len(binary)) % 4)
    total = 12+8+len(encoded)+8+len(binary)
    Path(path).write_bytes(struct.pack("<4sII", b"glTF", 2, total)+
        struct.pack("<II", len(encoded), 0x4E4F534A)+encoded+
        struct.pack("<II", len(binary), 0x004E4942)+binary)


def matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"]).reshape(4, 4).T
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    value = np.eye(4)
    value[:3, :3] = np.array([
        [1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w],
        [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w],
        [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y],
    ]) @ np.diag(node.get("scale", [1, 1, 1]))
    value[:3, 3] = node.get("translation", [0, 0, 0])
    return value


def accessor_bytes(document, binary, index):
    item = document["accessors"][index]
    if "sparse" in item:
        raise ValueError("Sparse native action buffers require an explicit migration")
    view = document["bufferViews"][item["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise ValueError("Native action points outside the retained binary buffer")
    size = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[item["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[item["type"]]*size
    offset = view.get("byteOffset", 0)+item.get("byteOffset", 0)
    stride = view.get("byteStride", width)
    count = item["count"]
    end = offset + (count-1)*stride + width
    view_end = view.get("byteOffset", 0)+view["byteLength"]
    if count <= 0 or stride < width or offset < view.get("byteOffset", 0) or end > view_end or view_end > len(binary):
        raise ValueError("Native action accessor exceeds its retained buffer view")
    return b"".join(binary[offset+i*stride:offset+i*stride+width] for i in range(item["count"]))


def action_digest(document, binary, animation):
    digest = hashlib.sha256()
    for channel in animation["channels"]:
        sampler = animation["samplers"][channel["sampler"]]
        target = channel["target"]
        name = document["nodes"][target["node"]]["name"]
        digest.update(json.dumps([name, target["path"], sampler.get("interpolation", "LINEAR")]).encode())
        for key in ("input", "output"):
            accessor = document["accessors"][sampler[key]]
            digest.update(json.dumps([accessor["type"], accessor["componentType"], accessor["count"]]).encode())
            digest.update(accessor_bytes(document, binary, sampler[key]))
    return digest.hexdigest()


def preserve(original_path, derivative_path):
    original, original_bin = read_glb(original_path)
    derivative, derivative_bin = read_glb(derivative_path)
    by_name = {}
    for index, node in enumerate(derivative["nodes"]):
        if "name" in node:
            by_name.setdefault(node["name"], []).append(index)
    parents_original = {child: parent for parent, node in enumerate(original["nodes"]) for child in node.get("children", [])}
    parents_derivative = {child: parent for parent, node in enumerate(derivative["nodes"]) for child in node.get("children", [])}
    protected = [action for action in original["animations"] if action["name"] not in REPLACED_CLIPS]
    target_map = {}
    maximum_rest_error = 0.0
    checked = set()

    def map_node(source_index):
        nonlocal maximum_rest_error
        if source_index in checked:
            return target_map[source_index]
        source_node = original["nodes"][source_index]
        options = by_name.get(source_node.get("name", ""), [])
        if len(options) != 1:
            raise ValueError("Protected action target is missing or ambiguous: "+source_node.get("name", ""))
        target_index = options[0]
        error = float(np.abs(matrix(source_node)-matrix(derivative["nodes"][target_index])).max())
        maximum_rest_error = max(maximum_rest_error, error)
        if not np.isfinite(error) or error > 1e-5:
            raise ValueError("Cannot reuse native curves across changed rest basis: "+source_node["name"])
        old_parent = parents_original.get(source_index)
        new_parent = parents_derivative.get(target_index)
        if (old_parent is None) != (new_parent is None):
            raise ValueError("Cannot reuse native curves across a changed parent: "+source_node["name"])
        if old_parent is not None and map_node(old_parent) != new_parent:
            raise ValueError("Cannot reuse native curves across a changed parent: "+source_node["name"])
        checked.add(source_index)
        target_map[source_index] = target_index
        return target_index

    for animation in protected:
        for channel in animation["channels"]:
            map_node(channel["target"]["node"])
    output = bytearray(derivative_bin)
    accessors, views = {}, {}

    def copy_accessor(index):
        if index in accessors:
            return accessors[index]
        source = copy.deepcopy(original["accessors"][index])
        if "sparse" in source:
            raise ValueError("Sparse protected actions are unsupported")
        view_index = source["bufferView"]
        if view_index not in views:
            view = copy.deepcopy(original["bufferViews"][view_index])
            offset = view.get("byteOffset", 0)
            payload = original_bin[offset:offset+view["byteLength"]]
            output.extend(b"\0"*((-len(output)) % 4))
            view["byteOffset"] = len(output)
            view["buffer"] = 0
            output.extend(payload)
            views[view_index] = len(derivative["bufferViews"])
            derivative["bufferViews"].append(view)
        source["bufferView"] = views[view_index]
        accessors[index] = len(derivative["accessors"])
        derivative["accessors"].append(source)
        return accessors[index]

    retained = {animation["name"]: animation for animation in derivative["animations"]}
    signatures = {}
    for original_animation in protected:
        # Validate ranges before copying: a truncated slice must never be
        # mistaken for an exact, valid native sample payload.
        for sampler in original_animation["samplers"]:
            for key in ("input", "output"):
                accessor_bytes(original, original_bin, sampler[key])
        animation = copy.deepcopy(original_animation)
        for sampler in animation["samplers"]:
            sampler["input"] = copy_accessor(sampler["input"])
            sampler["output"] = copy_accessor(sampler["output"])
        for channel in animation["channels"]:
            channel["target"]["node"] = target_map[channel["target"]["node"]]
        retained[animation["name"]] = animation
        signatures[animation["name"]] = action_digest(original, original_bin, original_animation)
    derivative["animations"] = [retained[action["name"]] for action in original["animations"]]
    write_glb(derivative_path, derivative, bytes(output))
    checked, checked_bin = read_glb(derivative_path)
    for animation in checked["animations"]:
        if animation["name"] in signatures and action_digest(checked, checked_bin, animation) != signatures[animation["name"]]:
            raise ValueError("Protected native action bytes changed: "+animation["name"])
    return {"protected_action_byte_signatures": signatures, "protected_action_bytes_equal": True,
            "maximum_target_rest_error": maximum_rest_error, "appended_native_buffer_bytes": len(output)-len(derivative_bin)}
