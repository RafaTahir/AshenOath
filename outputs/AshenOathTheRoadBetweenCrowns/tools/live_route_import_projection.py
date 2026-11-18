"""Import-remap preparation for the genuine adjusted1c performance baseline.

This projects missing generated remaps only, never source resources or scripts.
The baseline and candidate must already share the same imported-artifact cache.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import struct

RUNTIME_DIRS = ("scripts", "data", "scenes", "assets", "assets_external", "shaders")
IMPORT_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".ttf", ".otf", ".woff", ".woff2",
                   ".wav", ".ogg", ".mp3", ".glb", ".gltf", ".fbx", ".blend", ".obj", ".hdr", ".exr", ".tga", ".bmp", ".dds"}
STAFF = "assets_external/design_pack_v1/C01_ash_staff.glb"
STAFF_IMAGES = {"C01_StaffAshWood_fine_normal", "C01_StaffAshWood_authored_grain",
                "C01_StaffGrip_fine_normal", "C01_StaffGrip_authored_grain"}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def resource(root: Path, value: str, imported: bool = False) -> Path:
    if not value.startswith("res://") or "\\" in value:
        raise ValueError("Noncanonical import resource path: " + value)
    relative = PurePosixPath(value[6:])
    if relative.is_absolute() or not relative.parts or any(part in ("..", ".") or ":" in part for part in relative.parts):
        raise ValueError("Import path escapes project: " + value)
    if imported and relative.parts[:2] != (".godot", "imported"):
        raise ValueError("Import artifact is outside the imported cache: " + value)
    allowed = (root / ".godot/imported").resolve(strict=True) if imported else root.resolve(strict=True)
    path = root.joinpath(*relative.parts).resolve(strict=True)
    if not path.is_relative_to(allowed) or not path.is_file():
        raise ValueError("Import resource escaped or is missing: " + value)
    return path


def declarations(sidecar: Path, expected_source: str) -> list[str]:
    text = sidecar.read_text(encoding="utf-8")
    source = re.search(r'(?m)^source_file\s*=\s*("(?:[^"\\]|\\.)*")\s*$', text)
    destinations = re.search(r'(?ms)^dest_files\s*=\s*\[(.*?)\]', text)
    if source is None or json.loads(source.group(1)) != expected_source or destinations is None:
        raise ValueError("Import remap has no exact declared source/destinations: " + str(sidecar))
    paths = [json.loads(item) for item in re.findall(r'"(?:[^"\\]|\\.)*"', destinations.group(1))]
    remap = text.split("[remap]", 1)[-1].split("[", 1)[0]
    remap_paths = [json.loads(item) for item in re.findall(r'(?m)^path(?:\.\w+)?\s*=\s*("(?:[^"\\]|\\.)*")\s*$', remap)]
    # Godot's wavefront importer legitimately repeats the same mesh in its
    # dest_files list. Retain/validate each declaration; hash a shared path once.
    if not paths or not remap_paths or not set(remap_paths).issubset(paths):
        raise ValueError("Import remap paths do not match declared artifacts: " + str(sidecar))
    return paths


def shared_cache(baseline: Path, candidate: Path) -> Path:
    actual = (baseline / ".godot/imported").resolve(strict=True)
    if actual != (candidate / ".godot/imported").resolve(strict=True):
        raise ValueError("Adjusted baseline must use the same immutable imported-artifact cache")
    return actual


def baseline_imports(project: Path) -> set[str]:
    return {path.relative_to(project).as_posix() + ".import" for directory in RUNTIME_DIRS
            for path in (project / directory).rglob("*") if path.is_file() and path.suffix.lower() in IMPORT_SUFFIXES}


def native_staff_images(baseline: Path, candidate: Path, create: bool = False) -> dict:
    """Reproduce only the four importer-generated images from baseline's GLB."""
    source = resource(baseline,"res://"+STAFF)
    source_hash = digest(source)
    if source_hash != digest(resource(candidate,"res://"+STAFF)):
        raise ValueError("Native image extraction source differs between1c/candidate")
    raw = source.read_bytes()
    if len(raw)<20 or struct.unpack_from("<4sII",raw)!=(b"glTF",2,len(raw)):
        raise ValueError("Invalid baseline native GLB header")
    chunks, cursor = {}, 12
    while cursor<len(raw):
        size, kind = struct.unpack_from("<II",raw,cursor)
        cursor += 8
        if cursor+size>len(raw) or kind in chunks: raise ValueError("Invalid/duplicate GLB chunk")
        chunks[kind] = raw[cursor:cursor+size]
        cursor += size
    document = json.loads(chunks[0x4E4F534A])
    binary = chunks[0x004E4942]
    images = document.get("images",[])
    if len(images)!=4 or {image.get("name") for image in images}!=STAFF_IMAGES:
        raise ValueError("Native staff image set differs from the four retained embedded images")
    rows, pending = [], []
    for image in images:
        if "uri" in image or image.get("mimeType")!="image/png" or type(image.get("bufferView")) is not int:
            raise ValueError("Native staff images must be embedded PNG bufferViews, never external URIs")
        view = document["bufferViews"][image["bufferView"]]
        offset, length = view.get("byteOffset",0), view["byteLength"]
        if view.get("buffer",0)!=0 or type(offset) is not int or type(length) is not int or offset<0 or length<=0 or offset+length>len(binary):
            raise ValueError("Embedded image bufferView escapes baseline GLB")
        pixels = binary[offset:offset+length]
        if not pixels.startswith(b"\x89PNG\r\n\x1a\n"): raise ValueError("Embedded image is not PNG bytes")
        name = str(Path(STAFF).with_name(Path(STAFF).stem+"_"+image["name"]+".png")).replace("\\","/")
        expected = hashlib.sha256(pixels).hexdigest()
        if digest(resource(candidate,"res://"+name))!=expected:
            raise ValueError("Cached external image identity does not match baseline embedded bytes")
        destination = baseline/name
        if destination.exists() and digest(destination)!=expected:
            raise ValueError("Existing baseline native extraction has different bytes")
        if not destination.exists(): pending.append((destination,pixels))
        rows.append({"resource":name,"buffer_view":image["bufferView"],"byte_offset":offset,"bytes":length,"sha256":expected})
    if create:
        for destination,pixels in pending: destination.write_bytes(pixels)
    return {"kind":"native_import_image_extraction","source":STAFF,"source_sha256":source_hash,"images":rows,
            "policy":"PNG bytes come from genuine baseline GLB bufferViews; cached candidate loose-image identities are equality checks only, never copy sources."}


def prepare_projection(baseline: Path, candidate: Path, receipt_path: Path, prior_path: Path | None = None, native_images: dict | None = None) -> dict:
    if receipt_path.exists():
        raise ValueError("Do not overwrite an import-projection receipt")
    cache = shared_cache(baseline, candidate)
    rows, skipped, pending = [], [], []
    prior = json.loads(prior_path.read_text(encoding="utf-8")) if prior_path is not None else None
    previous = {row["sidecar"]:row for row in prior["entries"]} if prior is not None else {}
    if prior is not None and (Path(prior["baseline_project"]).resolve()!=baseline.resolve() or Path(prior["candidate_project"]).resolve()!=candidate.resolve()):
        raise ValueError("Prior projection belongs to different projects")
    artifact_hashes: dict[Path, str] = {}
    for directory in RUNTIME_DIRS:
        for supplied in sorted((candidate / directory).rglob("*.import")):
            relative = supplied.relative_to(candidate).as_posix()
            source_name = relative[:-7]
            if not (baseline / source_name).is_file():
                skipped.append(relative)
                continue
            source_uri = "res://" + source_name
            baseline_source, candidate_source = resource(baseline, source_uri), resource(candidate, source_uri)
            source_hash = digest(baseline_source)
            if source_hash != digest(candidate_source):
                raise ValueError("No candidate remap fallback for changed baseline resource: " + source_name)
            retained = baseline / relative
            selected = retained if retained.exists() else supplied
            artifacts = []
            for uri in declarations(selected, source_uri):
                artifact = resource(baseline, uri, imported=True)
                if artifact not in artifact_hashes:
                    artifact_hashes[artifact] = digest(artifact)
                artifacts.append({"resource":uri, "bytes":artifact.stat().st_size, "sha256":artifact_hashes[artifact]})
            rows.append({"sidecar":relative, "kind":"existing_retained" if retained.exists() else "missing_projected",
                         "resource":source_name, "source_sha256":source_hash, "sidecar_sha256":digest(selected), "artifacts":artifacts})
            if relative in previous:
                if {key:value for key,value in rows[-1].items() if key!="kind"}!={key:value for key,value in previous[relative].items() if key!="kind"}:
                    raise ValueError("Prior import-projection bytes changed: "+relative)
                if previous[relative]["kind"] in ("missing_projected","prior_projected"): rows[-1]["kind"] = "prior_projected"
            if not retained.exists():
                pending.append((supplied, retained))
    missing = baseline_imports(baseline) - {row["sidecar"] for row in rows}
    if set(previous)-{row["sidecar"] for row in rows}: raise ValueError("Prior import projection has lost resources")
    if missing:
        raise ValueError("Baseline resources have no validated import remap: " + repr(sorted(missing)))
    # Validate the complete plan before the first write. Existing remaps, source
    # bytes, scripts and prepared scenes are never replaced.
    for supplied, retained in pending:
        shutil.copyfile(supplied, retained)
    receipt = {"kind":"missing_import_remap_projection", "baseline_project":str(baseline), "candidate_project":str(candidate),
               "shared_imported_cache":str(cache), "entries":rows, "skipped_candidate_only":skipped,
               "projected_count":len(pending), "retained_count":sum(row["kind"]=="existing_retained" for row in rows),
               "prior_projected_count":sum(row["kind"]=="prior_projected" for row in rows),
               "policy":"Missing generated .import remaps only; corresponding genuine baseline/candidate source bytes must be equal. Existing tracked remaps retained, all declared artifacts validated. No candidate source/runtime fallback."}
    if prior_path is not None: receipt["prior_projection"] = {"path":str(prior_path.resolve()),"sha256":digest(prior_path)}
    if native_images is not None: receipt["native_image_extraction"] = native_images
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    return receipt


def validate_projection(receipt: dict, baseline: Path, candidate: Path) -> None:
    if Path(receipt["baseline_project"]).resolve() != baseline.resolve() or Path(receipt["candidate_project"]).resolve() != candidate.resolve():
        raise ValueError("Import projection belongs to different projects")
    if str(shared_cache(baseline, candidate)) != receipt["shared_imported_cache"]:
        raise ValueError("Imported cache identity changed")
    if "native_image_extraction" in receipt and native_staff_images(baseline,candidate)!=receipt["native_image_extraction"]:
        raise ValueError("Native embedded-image extraction provenance changed")
    if "prior_projection" in receipt:
        origin = receipt["prior_projection"]
        if digest(Path(origin["path"]))!=origin["sha256"]: raise ValueError("Prior import-projection proof changed")
        previous = {row["sidecar"]:row for row in json.loads(Path(origin["path"]).read_text(encoding="utf-8"))["entries"]}
        current = {row["sidecar"]:row for row in receipt["entries"]}
        for name,row in previous.items():
            if name not in current or {k:v for k,v in row.items() if k!="kind"}!={k:v for k,v in current[name].items() if k!="kind"}:
                raise ValueError("Current projection does not retain its exact origin entries")
    seen, artifact_hashes = set(), {}
    for row in receipt["entries"]:
        if row["sidecar"] in seen or row["sidecar"] != row["resource"]+".import":
            raise ValueError("Duplicate or invalid import projection entry")
        seen.add(row["sidecar"])
        for project in (baseline, candidate):
            if digest(resource(project,"res://"+row["resource"])) != row["source_sha256"]:
                raise ValueError("Import source bytes changed: "+row["resource"])
        sidecar = resource(baseline,"res://"+row["sidecar"])
        if digest(sidecar) != row["sidecar_sha256"]:
            raise ValueError("Baseline import-remap bytes changed: "+row["sidecar"])
        declared = declarations(sidecar,"res://"+row["resource"])
        if declared != [entry["resource"] for entry in row["artifacts"]]:
            raise ValueError("Declared imported-artifact list changed")
        for entry in row["artifacts"]:
            artifact = resource(baseline,entry["resource"],imported=True)
            if artifact not in artifact_hashes:
                artifact_hashes[artifact] = digest(artifact)
            if artifact_hashes[artifact] != entry["sha256"] or artifact.stat().st_size != entry["bytes"]:
                raise ValueError("Imported-artifact bytes changed: "+entry["resource"])
    if baseline_imports(baseline) != seen:
        raise ValueError("Baseline required import-remap closure changed")


def validate_prepared_identity(receipt: dict, baseline: Path, candidate: Path) -> None:
    rows = receipt.get("prepared_scenes", [])
    expected = {row["path"] for row in rows}
    if receipt.get("passed") is not True or len(rows) != 18 or len(expected) != 18:
        raise ValueError("The exact18 retained prepared-monster identity proof is required")
    for project, key in ((baseline,"baseline_sha256"),(candidate,"candidate_sha256")):
        actual = {path.relative_to(project).as_posix() for path in (project/"assets_external/characters_prepared/monsters").glob("*.scn")}
        if actual != expected:
            raise ValueError("Prepared-monster scene closure changed")
        for row in rows:
            if row.get("identical") is not True or row["baseline_sha256"] != row["candidate_sha256"] or digest(resource(project,"res://"+row["path"])) != row[key]:
                raise ValueError("Prepared-monster scene bytes differ from1c: "+row["path"])
