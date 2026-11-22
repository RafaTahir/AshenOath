"""Build licensed rig-preserving Spectral Bestiary derivatives.

The original buffers, skeleton nodes, skin binds and animation accessors remain
unchanged. Authored body positions/normals/colours and skinned spectral ribbons
use new accessors. This does not author gameplay or claim visual approval.
"""
from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import math
import os
import struct
from pathlib import Path

import numpy as np
from PIL import Image

from build_opening_character_assemblies import accessor_bytes, append_compact_accessor

ROOT = Path(__file__).resolve().parents[1]
UNIVERSAL = "assets_external/characters_universal/runtime/"
ENEMIES = "assets_external/enemies/"
SPECS = [
    ("ghoulkin", "ghoulkin_creature", "Pallbearer", UNIVERSAL + "Ghoulkin_Authored_Atlas.gltf", UNIVERSAL + "spectral/Ghoulkin_Spectral_Atlas.gltf", (0.56, 0.48, 0.76), 0.82),
    ("wychwood_stalker", "wychwood_stalker_creature", "Thorn Veil", ENEMIES + "ultimate_monsters/Demon.gltf", ENEMIES + "spectral/Stalker_Spectral.gltf", (0.42, 0.47, 0.82), 0.66),
    ("wychwood_raider", "wychwood_raider_creature", "Oathless Shade", ENEMIES + "ultimate_monsters/Orc.gltf", ENEMIES + "spectral/Raider_Spectral.gltf", (0.68, 0.35, 0.61), 0.74),
    ("wychwood_brute", "wychwood_brute_creature", "Hollow Crown", ENEMIES + "ultimate_monsters/BlueDemon.gltf", ENEMIES + "spectral/Brute_Spectral.gltf", (0.51, 0.38, 0.72), 0.88),
    ("bog_wretch", "bog_wretch_creature", "Fen Lantern", UNIVERSAL + "BogWretch_Playfix.glb", UNIVERSAL + "spectral/BogWretch_Spectral_Atlas.gltf", (0.46, 0.65, 0.31), 0.86),
    ("bell_eater", "bell_eater_boss", "The Unrung", UNIVERSAL + "BellEater_Playfix.glb", UNIVERSAL + "spectral/BellEater_Spectral_Atlas.gltf", (0.85, 0.48, 0.23), 0.91),
    ("rootbound_colossus", "rootbound_colossus_boss", "Root Revenant", ENEMIES + "ultimate_monsters/Creep.glb", ENEMIES + "spectral/Rootbound_Spectral.gltf", (0.59, 0.66, 0.28), 0.94),
    ("ashwing", "ashwing_boss", "Cinder Apparition", ENEMIES + "Ashwing_Playfix.glb", ENEMIES + "spectral/Ashwing_Spectral.gltf", (0.76, 0.36, 0.60), 0.96),
    ("white_hart_avatar", "white_hart_boss", "The Moonlit Hart", ENEMIES + "WhiteHart_Stag.glb", ENEMIES + "spectral/WhiteHart_Spectral.gltf", (0.84, 0.76, 0.48), 0.98),
    ("gravebound_knight", "gravebound_knight_creature", "Barrow Watcher", ".release-gate/spectral-monsters/Gravebound_Source.glb", ENEMIES + "spectral/Gravebound_Spectral.gltf", (0.49, 0.44, 0.79), 0.94),
]
DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_document(path: Path) -> tuple[dict, bytearray]:
    raw = path.read_bytes()
    if path.suffix == ".glb":
        assert raw[:4] == b"glTF"
        pos, document, binary = 12, None, None
        while pos < len(raw):
            size, kind = struct.unpack_from("<I4s", raw, pos)
            chunk = raw[pos + 8:pos + 8 + size]
            if kind == b"JSON": document = json.loads(chunk)
            elif kind == b"BIN\x00": binary = bytearray(chunk)
            pos += size + 8
        assert document is not None and binary is not None
    else:
        document = json.loads(raw)
        uri = document["buffers"][0]["uri"]
        binary = bytearray(base64.b64decode(uri.split(",", 1)[1]) if uri.startswith("data:") else (path.parent / uri).read_bytes())
    assert len(document["buffers"]) == 1, "Multi-buffer source needs explicit ownership"
    return document, binary


def array(document: dict, binary: bytes, index: int) -> np.ndarray:
    a = document["accessors"][index]
    values = np.frombuffer(accessor_bytes(document, binary, index), dtype=DTYPES[a["componentType"]]).reshape(-1, WIDTHS[a["type"]]).copy()
    if a.get("normalized") and a["componentType"] != 5126:
        values = values.astype(np.float32) / np.iinfo(DTYPES[a["componentType"]]).max
    return values


def put(document: dict, binary: bytearray, values: np.ndarray, kind: str, component: int = 5126) -> int:
    values = np.asarray(values, dtype=DTYPES[component])
    return append_compact_accessor(document, binary, document["bufferViews"], document["accessors"], values.tobytes(),
        {"componentType": component, "type": kind}, len(values), 34963 if kind == "SCALAR" else 34962,
        values.min(0).tolist() if kind == "VEC3" else None, values.max(0).tolist() if kind == "VEC3" else None)


def normals(points: np.ndarray, indices: np.ndarray) -> np.ndarray:
    faces = indices.reshape(-1, 3)
    output = np.zeros_like(points)
    cross = np.cross(points[faces[:, 1]] - points[faces[:, 0]], points[faces[:, 2]] - points[faces[:, 0]])
    for corner in range(3): np.add.at(output, faces[:, corner], cross)
    # Smooth geometric seams without changing UVs, joints, weights or topology.
    _, inverse = np.unique(np.round(points, 5), axis=0, return_inverse=True)
    grouped = np.zeros((inverse.max() + 1, 3), dtype=np.float32)
    np.add.at(grouped, inverse, output)
    output = grouped[inverse]
    return output / np.maximum(np.linalg.norm(output, axis=1, keepdims=True), 1e-10)


def rig(document: dict, binary: bytes, skin_index: int) -> tuple[list[str], np.ndarray]:
    skin = document["skins"][skin_index]
    names = [document["nodes"][i].get("name", "") for i in skin["joints"]]
    inverse = array(document, binary, skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    return names, np.linalg.inv(inverse)[:, :3, 3]


def sculpt(points: np.ndarray, joints: np.ndarray, weights: np.ndarray, names: list[str], centers: np.ndarray, slender: float, creature: str) -> np.ndarray:
    lo, hi = points.min(0), points.max(0)
    height = max(float(hi[1] - lo[1]), 1e-3)
    result = np.zeros_like(points)
    feet = np.zeros(len(points), dtype=bool)
    for slot in range(joints.shape[1]):
        for bone, name in enumerate(names):
            selected = (joints[:, slot] == bone) & (weights[:, slot] > 0)
            if not selected.any(): continue
            scale = np.ones(3)
            key = name.lower()
            if any(part in key for part in ["foot", "toe", "hoof", "ankle"]): feet |= selected
            if any(part in key for part in ["spine", "torso", "abdomen", "chest", "pelvis", "hips"]):
                scale = np.array([slender, 1.0, max(slender, 0.77)])
            elif any(part in key for part in ["upperarm", "lowerarm", "upper_arm", "forearm"]):
                scale = np.array([1.0, slender, slender])
            elif any(part in key for part in ["thigh", "calf", "upperleg", "lowerleg"]):
                scale = np.array([max(slender, 0.79), 1.0, max(slender, 0.79)])
            elif key == "head" and creature not in ["ashwing", "white_hart_avatar"]:
                scale = np.array([max(slender, 0.82), 1.0, 0.88])
            result[selected] += (centers[bone] + (points[selected] - centers[bone]) * scale) * weights[selected, slot, None]
    # Quiet anatomical furrows across the trunk; no new collision or rig scale.
    if creature not in ["ashwing", "white_hart_avatar", "gravebound_knight"]:
        x = (points[:, 0] - (lo[0] + hi[0]) / 2) / height
        y = (points[:, 1] - lo[1]) / height
        ridges = np.sin(y * 95.0 + np.abs(x) * 15.0) * np.exp(-np.square(x / 0.15))
        mask = np.clip((y - 0.42) / 0.12, 0, 1) * np.clip((0.80 - y) / 0.12, 0, 1)
        result[:, 2] += ridges * mask * height * 0.006
    # Keep the existing mesh envelope and foot topology exactly. Normalization
    # and initial posed grounding must not silently move an attack contact.
    protected = feet | np.any(np.isclose(points, lo, atol=1e-6) | np.isclose(points, hi, atol=1e-6), axis=1)
    result[protected] = points[protected]
    return np.clip(result, lo, hi).astype(np.float32)


def colours(points: np.ndarray, tint: tuple, creature: str) -> np.ndarray:
    lo, hi = points.min(0), points.max(0)
    height = max(float(hi[1] - lo[1]), 1e-3)
    p = (points - lo) / height
    grain = (np.sin(p[:, 0] * 93 + np.sin(p[:, 1] * 41)) * np.sin(p[:, 2] * 71 - p[:, 1] * 17) + 1) / 2
    vein = np.power(np.clip(1 - np.abs(np.sin(p[:, 1] * 47 + np.sin(p[:, 0] * 23) * 2 + p[:, 2] * 13)), 0, 1), 14)
    illumination = 0.20 + 0.30 * grain + 0.26 * vein
    if creature == "white_hart_avatar":
        rgb = np.array([0.80, 0.84, 0.86])[None, :] * (0.78 + 0.20 * grain[:, None])
    else:
        rgb = np.array(tint)[None, :] * illumination[:, None] + np.array([0.045, 0.045, 0.065])[None, :]
    return np.column_stack([np.clip(rgb, 0, 1), np.ones(len(points))]).astype(np.float32)


def spectral_forms(points: np.ndarray, names: list[str], centers: np.ndarray, tint: tuple, creature: str) -> tuple:
    """Author tapered torn veils and orbiting marrow filaments inside the envelope."""
    lo, hi = points.min(0), points.max(0)
    height = max(float(hi[1] - lo[1]), 1e-3)
    positions, joints, weights, colours_out, indices, uv = [], [], [], [], [], []
    bone_by_name = {name.lower(): i for i, name in enumerate(names)}
    def bone(*aliases):
        return next((bone_by_name[a.lower()] for a in aliases if a.lower() in bone_by_name), 0)
    torso = bone("spine_03", "Torso", "Chest", "Body", "Abdomen")
    pelvis = bone("pelvis", "Hips", "Body", "Root")
    head = bone("Head", "head", "Body")
    center = centers[torso].copy()
    center[1] = np.clip(center[1], lo[1] + 0.40 * height, hi[1] - 0.20 * height)
    def ribbon(path, width, owner, phase, bright=1.0):
        offset = len(positions)
        for row, point in enumerate(path):
            t = row / (len(path) - 1)
            tangent = path[min(row + 1, len(path) - 1)] - path[max(row - 1, 0)]
            side = np.cross(tangent, np.array([0.0, 0.0, 1.0]))
            if np.linalg.norm(side) < 1e-8: side = np.array([1.0, 0.0, 0.0])
            side /= np.linalg.norm(side)
            taper = max(0.02, math.sin(math.pi * t) ** 0.5)
            for sign in (-1, 1):
                p = np.clip(point + side * width * taper * sign, lo + (hi - lo) * 0.003, hi - (hi - lo) * 0.003)
                positions.append(p); joints.append((owner, 0, 0, 0)); weights.append((1, 0, 0, 0))
                colours_out.append((*np.minimum(np.array(tint) * bright + 0.16, 1), 1))
                uv.append((0 if sign < 0 else 1, t + phase))
        for row in range(len(path) - 1):
            a = offset + row * 2; indices.extend((a, a + 2, a + 1, a + 1, a + 2, a + 3))
    # Deliberate winding negative spaces, not cylinders standing in for limbs.
    for side in (-1, 1):
        for strand in range(3):
            path = []
            for row in range(13):
                t = row / 12
                p = center.copy()
                p[0] += side * height * (0.08 + 0.028 * strand + 0.035 * math.sin(t * math.pi * 1.4))
                p[1] += height * (0.08 - t * (0.27 + 0.03 * strand))
                p[2] -= height * (0.055 + 0.035 * math.sin(t * math.pi * 2 + strand))
                path.append(p)
            ribbon(np.array(path), height * (0.008 + strand * 0.002), torso, strand * 0.19)
    # Broken chest crescents read as an internal supernatural pulse.
    for ring in range(3):
        path = []
        for row in range(19):
            angle = (-0.88 + row / 18 * 1.76) * math.pi
            p = center.copy()
            p[0] += math.sin(angle) * height * (0.075 + ring * 0.014)
            p[1] += math.cos(angle) * height * (0.04 + ring * 0.012)
            candidates = points[np.argsort(np.square(points[:, 0] - p[0]) + np.square(points[:, 1] - p[1]))[:32]]
            p[2] = np.quantile(candidates[:, 2], 0.90) + height * 0.001
            path.append(p)
        ribbon(np.array(path), height * 0.0028, torso, ring * 0.31, 1.2)
    # A modest head halo keeps the stag recognizable and frames humanoid horns.
    if creature in ["white_hart_avatar", "bell_eater", "gravebound_knight"]:
        c = centers[head]
        for arc in range(2):
            path = []
            for row in range(17):
                angle = (0.13 + row / 16 * 0.74 + arc) * math.pi
                path.append(c + np.array([math.cos(angle), math.sin(angle), 0.12]) * height * 0.075)
            ribbon(np.array(path), height * 0.003, head, arc * 0.27, 1.4)
    return np.asarray(positions, dtype=np.float32), np.asarray(joints), np.asarray(weights), np.asarray(colours_out), np.asarray(uv), np.asarray(indices).reshape(-1, 1)


def build(spec: tuple) -> dict:
    creature, role, title, source_name, output_name, tint, slender = spec
    source, output = ROOT / source_name, ROOT / output_name
    document, binary = read_document(source)
    original = copy.deepcopy(document)
    before_binary = bytes(binary)
    original_nodes = len(document["nodes"])
    owned = {}
    for node_index, node in enumerate(document["nodes"]):
        if "mesh" in node and "skin" in node: owned.setdefault(node["mesh"], (node["skin"], node_index))
    if not owned: raise ValueError("No skinned body: " + source_name)
    if creature.startswith("wychwood_"):
        label = creature.removeprefix("wychwood_")
        artifact = ROOT.parents[1] / ".release-gate/spectral-monsters/anatomical-bodies" / (label + "_body.npz")
        authored = np.load(artifact)
        authored_positions = authored['positions'].copy()
        if label == 'raider':
            # Fit the new soles to the original authored startup grounding.
            # Measured against the immutable native rig/contact fixture.
            fade = np.clip((0.22-authored_positions[:,1])/0.10,0,1)
            authored_positions[:,1] -= fade * 0.031276035
        # The original node/skin/channel hierarchy remains the animation owner.
        # Old cartoon bodies and separate props no longer render.
        body = min(owned)
        for old_mesh, (_, old_node) in list(owned.items()):
            if old_mesh != body:
                document["nodes"][old_node].pop("mesh", None)
        attrs = {"POSITION":put(document,binary,authored_positions,"VEC3"),
                 "NORMAL":put(document,binary,authored['normals'],"VEC3"),
                 "JOINTS_0":put(document,binary,authored['joints'],"VEC4",5123),
                 "WEIGHTS_0":put(document,binary,authored['weights'],"VEC4")}
        document["meshes"][body] = {"name":"AuthoredSpectralAnatomy_" + label,"primitives":[{
            "mode":4,"material":0,"attributes":attrs,"indices":put(document,binary,authored['indices'].reshape(-1,1),"SCALAR",5125)}]}
        owned = {body:owned[body]}
    meshes_info = []
    primary = max(owned, key=lambda m: sum(document["accessors"][p["attributes"]["POSITION"]]["count"] for p in document["meshes"][m]["primitives"]))
    primary_points, primary_rig = [], None
    total_triangles = 0
    for mesh_index, (skin_index, node_index) in owned.items():
        names, centers = rig(document, binary, skin_index)
        for primitive in document["meshes"][mesh_index]["primitives"]:
            attrs = primitive["attributes"]
            if not {"POSITION", "JOINTS_0", "WEIGHTS_0"}.issubset(attrs): raise ValueError("Missing skin attributes")
            points, js, ws = (array(document, binary, attrs[key]) for key in ["POSITION", "JOINTS_0", "WEIGHTS_0"])
            idx = array(document, binary, primitive["indices"])
            second = 'WEIGHTS_1' in attrs
            if second:
	                js = np.concatenate([js,array(document,binary,attrs['JOINTS_1'])],axis=1)
	                ws = np.concatenate([ws,array(document,binary,attrs['WEIGHTS_1'])],axis=1)
            sums = ws.sum(1,keepdims=True)
            if np.any(sums <= 0) or np.any(ws < 0): raise ValueError("Invalid source skin weights")
            # Godot normalizes retained FBX-derived weights on import. Make that
            # same normalization explicit in the authored interchange asset.
            ws = ws / sums
            attrs['WEIGHTS_0'] = put(document,binary,ws[:,:4],'VEC4')
            if second: attrs['WEIGHTS_1'] = put(document,binary,ws[:,4:],'VEC4')
            altered = points if creature.startswith("wychwood_") else sculpt(points, js, ws, names, centers, slender, creature)
            attrs["POSITION"] = put(document, binary, altered, "VEC3")
            attrs["NORMAL"] = put(document, binary, normals(altered, idx), "VEC3")
            attrs["COLOR_0"] = put(document, binary, colours(altered, tint, creature), "VEC4")
            extent = np.maximum(points.max(0)-points.min(0), 0.001)
            center = (points.max(0)+points.min(0))/2
            uv = np.column_stack([np.arctan2(points[:,2]-center[2],points[:,0]-center[0])/(2*math.pi)+0.5,(points[:,1]-points[:,1].min())/extent[1]])
            attrs["TEXCOORD_0"] = put(document,binary,uv,"VEC2")
            attrs.pop("TANGENT", None)
            primitive["material"] = 0
            if not np.allclose(points.min(0), altered.min(0), atol=1e-6) or not np.allclose(points.max(0), altered.max(0), atol=1e-6): raise ValueError("Changed normalization envelope")
            total_triangles += idx.size // 3
            meshes_info.append({"mesh":mesh_index, "vertices":len(points), "triangles":idx.size // 3, "source_bounds":[points.min(0).tolist(),points.max(0).tolist()]})
            if mesh_index == primary: primary_points.append(altered); primary_rig = names, centers
    names, centers = primary_rig
    points, js, ws, cs, uv, idx = spectral_forms(np.concatenate(primary_points), names, centers, tint, creature)
    primitive = {"mode":4, "material":1, "attributes":{
        "POSITION":put(document,binary,points,"VEC3"), "NORMAL":put(document,binary,normals(points,idx),"VEC3"),
        "JOINTS_0":put(document,binary,js,"VEC4",5123), "WEIGHTS_0":put(document,binary,ws,"VEC4"),
        "COLOR_0":put(document,binary,cs,"VEC4"), "TEXCOORD_0":put(document,binary,uv,"VEC2")},
        "indices":put(document,binary,idx,"SCALAR",5125)}
    mesh_index = len(document["meshes"])
    document["meshes"].append({"name":"SpectralVeil", "primitives":[primitive]})
    source_node = document["nodes"][owned[primary][1]]
    veil_node = {key:copy.deepcopy(value) for key,value in source_node.items() if key in ["skin","matrix","translation","rotation","scale"]}
    veil_node.update({"name":"SpectralVeil", "mesh":mesh_index, "extras":{"spectral_effect":True}})
    document["nodes"].append(veil_node)
    for node in document["nodes"][:original_nodes]:
        if owned[primary][1] in node.get("children",[]): node["children"].append(original_nodes)
    for scene in document.get("scenes",[]):
        if owned[primary][1] in scene.get("nodes",[]): scene["nodes"].append(original_nodes)
    atlas = ROOT / "assets_external/enemies/spectral/spectral_surface.png"
    make_surface(atlas)
    document["materials"] = [
        {"name":"SpectralBody", "doubleSided":True, "pbrMetallicRoughness":{"baseColorFactor":[0.42,0.42,0.42,1] if creature != "white_hart_avatar" else [1,1,1,1],"metallicFactor":0.05,"roughnessFactor":0.78},"emissiveFactor":[float(v)*0.008 for v in tint]},
        {"name":"SpectralVeil", "doubleSided":True, "pbrMetallicRoughness":{"baseColorFactor":[1,1,1,1],"metallicFactor":0,"roughnessFactor":0.5},"emissiveFactor":list(tint),"extensions":{"KHR_materials_emissive_strength":{"emissiveStrength":2.5}}},
    ]
    for material in document['materials']:
        material['pbrMetallicRoughness']['baseColorTexture'] = {'index':0}
    document["extensionsUsed"] = sorted(set(document.get("extensionsUsed",[])) | {"KHR_materials_emissive_strength"})
    document['images'] = [{'uri':os.path.relpath(atlas,output.parent).replace(os.sep,'/')}]
    document['textures'] = [{'source':0,'sampler':0}]
    document['samplers'] = [{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]
    document["buffers"] = [{"uri":output.with_suffix(".bin").name,"byteLength":len(binary)}]
    document["asset"]["generator"] = "AshenOath Spectral Bestiary authoring pipeline"
    document["asset"]["extras"] = {"title":title,"source":source_name,"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"license":"CC0 retained-source derivative; original project spectral geometry","visual_approval":"pending_user_review"}
    assert document["skins"] == original["skins"]
    assert document.get("animations",[]) == original.get("animations",[])
    assert bytes(binary[:len(before_binary)]) == before_binary
    output.parent.mkdir(parents=True,exist_ok=True)
    output.with_suffix(".bin").write_bytes(binary)
    output.write_text(json.dumps(document,indent=2)+"\n")
    return {"enemy_id":creature,"role":role,"title":title,"source":"res://"+source_name,"path":"res://"+output_name,
        "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"skins":[len(s["joints"]) for s in document["skins"]],
        "animations":[a.get("name","") for a in document.get("animations",[])],"source_meshes":meshes_info,
        "triangles":total_triangles+len(idx)//3,"veil_triangles":len(idx)//3,"materials":2,"textures":[512,512],
        "spectral_color":list(tint),"source_mesh_height":float(np.ptp(np.concatenate(primary_points)[:,1])),
        "authored_changes":["bone-local gaunt anatomy","surface furrows","spectral vertex coloration","skinned torn veils and chest filaments"],
        "files":{p.name:{"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in [output,output.with_suffix('.bin')]},
        "visual_approval":"pending_user_review","rig_and_animation_payloads":"unchanged"}


def make_surface(path: Path) -> None:
    """Original periodic pigment/filament texture, shared across the pack."""
    size=512
    y,x=np.mgrid[0:size,0:size]/size
    detail=sum(np.sin((x*a+y*b)*2*math.pi+phase)*weight for a,b,phase,weight in [(3,5,0,.19),(11,-7,1.4,.11),(29,17,.3,.06),(71,-59,2,.025)])
    veins=np.power(np.maximum(0,1-np.abs(np.sin(2*math.pi*(x*7+y*9)+np.sin(x*2*math.pi*3)*1.4))),15)
    tone=np.clip(.60+detail+veins*.16,.16,.96)
    pixels=np.stack([tone*.93,tone*.95,tone],axis=2)
    path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray((pixels*255).astype(np.uint8)).save(path,optimize=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only',nargs='*')
    args=parser.parse_args()
    selected=[s for s in SPECS if not args.only or s[0] in args.only]
    result=[]
    for spec in selected:
        record=build(spec); result.append(record); print(json.dumps({k:record[k] for k in ['enemy_id','path','triangles','skins','veil_triangles']}))
    manifest=ROOT/'assets_external/enemies/spectral/SPECTRAL_BESTIARY_BUILD.json'
    old=json.loads(manifest.read_text()) if manifest.exists() else {"version":1,"pack":"AshenOath Spectral Bestiary","assets":[]}
    ids={r['enemy_id'] for r in result}
    old['assets']=sorted([r for r in old['assets'] if r['enemy_id'] not in ids]+result,key=lambda r:r['enemy_id'])
    manifest.parent.mkdir(parents=True,exist_ok=True); manifest.write_text(json.dumps(old,indent=2)+'\n')


if __name__ == '__main__': main()
