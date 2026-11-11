"""Label producer witnesses and add derived raw-bind anchor metadata only.

Reads archived certificates and GLBs. It never starts an engine or changes a
model, Blender master, animation, prepared scene, or original producer anchor.
The shared admission helper performs all geometric admission afterward.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition,message):
    if not condition: raise ValueError("Anchor metadata augmentation: "+message)


def encoded(value):
    return (json.dumps(value,indent=2)+"\n").encode("utf-8")


def replace_bytes(path,data):
    temporary = path.with_name(path.name+".raw_bind_metadata.tmp")
    require(not temporary.exists(),"temporary output already exists")
    temporary.write_bytes(data)
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository",type=Path,required=True)
    parser.add_argument("--write",action="store_true",required=True)
    args = parser.parse_args()
    root = args.repository.resolve(strict=True)
    helper_path = root/"art_source/art_recovery_v2/tools/face_repair_provenance.py"
    spec = importlib.util.spec_from_file_location("face_repair_source_geometry",helper_path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper_sha = digest(helper_path.read_bytes())
    registry_path = root/"outputs/AshenOathTheRoadBetweenCrowns/data/design_pack_assets.json"
    registry = json.loads(registry_path.read_bytes())
    updates = []
    for asset,entry in sorted(registry["assets"].items()):
        pointer = entry.get("face_repair_certificate")
        if pointer is None: continue
        cert_path = helper._path(root,pointer["path"])
        original_bytes = cert_path.read_bytes()
        require(digest(original_bytes) == pointer["sha256"],"registry certificate digest differs: "+asset)
        certificate = json.loads(original_bytes)
        require(certificate.get("asset") == asset and certificate.get("certificate_kind") == "lower_face_repair_v1","certificate identity differs")
        old = helper.Document(helper._artifact(root,certificate["baseline_model"],"baseline model"))
        new = helper.Document(helper._artifact(root,certificate["new_glb"],"repaired model"))
        result = copy.deepcopy(certificate)
        count = 0
        for row in result["allowed_edits"]:
            if row["kind"] != "beard": continue
            anchors = row.get("beard_anchors")
            require(isinstance(anchors,list) and len(anchors) == len(row["vertices"]),"producer anchor inventory differs")
            part = old.json["meshes"][row["mesh"]]["primitives"][row["primitive"]]
            positions = old.accessor(part["attributes"]["POSITION"],(5126,"VEC3"))
            wrapped = []
            for vertex,anchor in zip(row["vertices"],anchors):
                if "producer_neutral_bind_anchor" in anchor:
                    require(anchor["producer_neutral_bind_anchor"].get("frame") == "producer_float32_neutral_bind","existing frame label differs")
                    producer = copy.deepcopy(anchor["producer_neutral_bind_anchor"]["anchor"])
                else:
                    producer = copy.deepcopy(anchor)
                surface = producer["surface"]
                original_part = old.json["meshes"][surface["mesh"]]["primitives"][surface["primitive"]]
                repaired_part = new.json["meshes"][surface["mesh"]]["primitives"][surface["primitive"]]
                source = old.accessor(original_part["attributes"]["POSITION"],(5126,"VEC3"))
                repaired = new.accessor(repaired_part["attributes"]["POSITION"],(5126,"VEC3"))
                indices = [v[0] for v in old.accessor(original_part["indices"])]
                start = surface["triangle"]*3
                require(indices[start:start+3] == surface["vertices"],"producer original triangle identity differs")
                before_triangle = [(source[i][0],-source[i][2],source[i][1]) for i in surface["vertices"]]
                after_triangle = [(repaired[i][0],-repaired[i][2],repaired[i][1]) for i in surface["vertices"]]
                point = (positions[vertex][0],-positions[vertex][2],positions[vertex][1])
                canonical = helper.canonical_raw_bind_anchor(point,before_triangle,after_triangle,producer)
                wrapped.append({"producer_neutral_bind_anchor":{"frame":"producer_float32_neutral_bind","anchor":producer},"raw_bind_anchor_proof":canonical})
                count += 1
            row["beard_anchors"] = wrapped
        if not count: continue
        previous = certificate.get("raw_bind_anchor_canonicalization")
        backup = cert_path.with_name("face_repair.producer_neutral_bind.json")
        if previous is None:
            require(not backup.exists(),"original producer-certificate backup already exists")
            backup_bytes = original_bytes
        else:
            require(backup.is_file(),"original producer-certificate backup missing")
            backup_bytes = backup.read_bytes()
            require(previous.get("producer_certificate",{}).get("sha256") == digest(backup_bytes),"original producer-certificate backup differs")
        # Prove preservation of every original field by stripping only this
        # wrapper from the proposed metadata and comparing the original JSON.
        unwrapped = copy.deepcopy(result)
        unwrapped.pop("raw_bind_anchor_canonicalization",None)
        for row in unwrapped["allowed_edits"]:
            if row["kind"] == "beard":
                row["beard_anchors"] = [value["producer_neutral_bind_anchor"]["anchor"] for value in row["beard_anchors"]]
        require(unwrapped == json.loads(backup_bytes),"original producer certificate fields would change")
        result["raw_bind_anchor_canonicalization"] = {
            "evidence_kind":"derived_source_metadata","runtime_observation":False,
            "producer_frame":"producer_float32_neutral_bind","canonical_frame":"raw_glb_bind",
            "method":"same_retained_triangle_float64_ericson_normal_offset",
            "helper_sha256":helper_sha,
            "producer_certificate":{"path":backup.relative_to(root).as_posix(),"sha256":digest(backup_bytes)},
            "baseline_model_sha256":certificate["baseline_model"]["sha256"],
            "model_sha256":certificate["model"]["sha256"],"anchor_count":count,
        }
        new_bytes = encoded(result)
        pointer["sha256"] = digest(new_bytes)
        updates.append((asset,cert_path,new_bytes,backup,backup_bytes,count))
    # All source reads and preservation checks precede the first write.
    for asset,path,data,backup,backup_bytes,count in updates:
        if not backup.exists(): backup.write_bytes(backup_bytes)
        replace_bytes(path,data)
    if updates: replace_bytes(registry_path,encoded(registry))
    print(json.dumps({"metadata_only":True,"runtime_observation":False,"assets":{asset:count for asset,_,_,_,_,count in updates},"helper_sha256":helper_sha}))


if __name__ == "__main__":
    main()
