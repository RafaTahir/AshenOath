"""Copy the complete ledger's candidates into a private game-source snapshot."""

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit


REPO = Path(__file__).resolve().parents[3]
RECOVERY = REPO / "art_source/art_recovery_v2"
GAME = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
OUTPUT = Path("D:/Temp/AshenOath/stylized_review/project")
REQUIRED = {"P01", *(f"C{i:02}" for i in range(1, 13)),
            *(f"M{i:02}" for i in range(1, 21))}
DIRECTORIES = {"assets", "assets_external", "data", "scenes", "scripts", "shaders", "tools"}
ROOT_FILES = {"project.godot", "export_presets.cfg", "web_boot_shell.html"}
SKIP_DIRS = {".git", ".godot", ".release-gate", ".verification-cache", "art_review",
             "art_source", "raw", "downloads", "release_reports", "build", "builds", "dist",
             "node_modules", "__pycache__", "verification_screenshots", "development_gallery"}
SKIP_FILES = {"runtime_pack_candidates.json", "override.cfg", "export_credentials.cfg",
              ".env", ".env.local", "publish_living_road.ps1", "vercel_git_release.py",
              "build_story_release.ps1"}
SKIP_SUFFIXES = {".zip", ".7z", ".rar", ".tar", ".gz", ".pck", ".wasm",
                 ".exe", ".dll", ".pyc", ".log", ".tmp"}
TEXTURES = {".png", ".jpg", ".jpeg", ".webp", ".tga", ".exr", ".hdr"}


def on_d(path, exists=True):
    path = Path(path).resolve(strict=exists)
    if path.drive.upper() != "D:":
        raise ValueError(f"Path must resolve on D: {path}")
    return path


def input_file(value, base):
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Missing source_path or runtime_path in candidate ledger")
    path = Path(value)
    path = on_d(path if path.is_absolute() else base / path)
    if not path.is_file():
        raise ValueError(f"Missing input file: {path}")
    return path


def sha256(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def resource_path(value):
    if not isinstance(value, str) or not value.startswith("res://assets_external/design_pack_v1/"):
        raise ValueError(f"Not a design-pack resource: {value!r}")
    parts = value.removeprefix("res://").split("/")
    if any(not part or part in {".", ".."} or part.endswith((".", " "))
           or any(ord(c) < 32 or c in '\\:<>"|?*' for c in part) for part in parts):
        raise ValueError(f"Unsafe resource path: {value}")
    path = Path(*parts)
    if path.is_reserved():
        raise ValueError(f"Reserved resource path: {value}")
    return path


def check_glb(item, declared):
    with item["source"].open("rb") as stream:
        header = stream.read(20)
        if len(header) != 20:
            raise ValueError(f"Truncated GLB: {item['source']}")
        magic, version, size, length, kind = struct.unpack("<4sIIII", header)
        if (magic != b"glTF" or version != 2 or size != item["bytes"]
                or kind != 0x4E4F534A or length > size - 20):
            raise ValueError(f"Invalid GLB: {item['source']}")
        document = json.loads(stream.read(length))
    if any(buffer.get("uri") for buffer in document.get("buffers", [])):
        raise ValueError("GLB must embed its vertex buffers")
    for image in document.get("images", []):
        uri = image.get("uri", "")
        if not uri or uri.startswith("data:"):
            continue
        url = urlsplit(uri)
        path = unquote(url.path)
        if url.scheme or url.netloc or url.query or url.fragment or path.startswith("/"):
            raise ValueError(f"Nonlocal texture URI: {uri}")
        target = "res://" + str(PurePosixPath(item["path"].removeprefix("res://")).parent / path)
        resource_path(target)
        if target.casefold() not in declared:
            raise ValueError(f"External texture must be ledger-declared: {target}")


def ignore_sources(directory, names):
    ignored = []
    for name in names:
        path = Path(directory) / name
        relative = path.relative_to(GAME)
        if (name.lower() in SKIP_DIRS or name.lower() in SKIP_FILES
                or path.suffix.lower() in SKIP_SUFFIXES or path.suffix.lower().startswith(".blend")
                or relative.as_posix() in {"assets_external/characters_prepared", "data/prepared_actors.json"}):
            ignored.append(name)
        else:
            on_d(path)
    return ignored


def prepare(ledger_path,resume_incomplete=False):
    ledger_path = on_d(ledger_path)
    game, output = on_d(GAME), on_d(OUTPUT, exists=False)
    if output != OUTPUT.absolute() or (output.exists() and not resume_incomplete):
        raise ValueError(f"Snapshot destination must be new and unredirected: {OUTPUT}")
    if resume_incomplete and (not output.is_dir() or (output/'private_review_preparation.json').exists()):
        raise ValueError('Resume is limited to the unfinished private copy, never a completed snapshot')
    ledger_hash = sha256(ledger_path)
    ledger = read_json(ledger_path)
    rows = ledger.get("assets")
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise ValueError("Ledger must contain an assets array")
    ids = [row.get("id") for row in rows]
    if any(not isinstance(asset_id, str) for asset_id in ids):
        raise ValueError("Each candidate requires a string id")
    if len(ids) != len(set(ids)) or set(ids) != REQUIRED:
        raise ValueError(f"Require exactly 33 unique IDs; missing={sorted(REQUIRED - set(ids))}; "
                         f"unexpected={sorted(set(ids) - REQUIRED)}")
    designs = read_json(on_d(game / "data/design_pack_assets.json"))
    runtime = read_json(on_d(game / "runtime_asset_manifest.json"))
    overlays, bodies, native_sources = [], {}, {}
    destinations, inputs = set(), set()

    def add_file(asset_id, source, target, allowed):
        relative = resource_path(target)
        source = input_file(source, ledger_path.parent)
        if relative.suffix.lower() not in allowed or source.suffix.lower() != relative.suffix.lower():
            raise ValueError(f"{asset_id}: invalid GLB/texture extension: {source}")
        existing = next((item for item in overlays if item['path'].casefold()==target.casefold()),None)
        if existing is not None and allowed == TEXTURES and existing['source']==source:
            if asset_id not in existing['asset_ids']:
                existing['asset_ids'].append(asset_id)
            return existing
        if target.casefold() in destinations or str(source).casefold() in inputs:
            raise ValueError(f"Duplicate candidate path: {source} -> {target}")
        destinations.add(target.casefold())
        inputs.add(str(source).casefold())
        item = dict(id=asset_id, asset_ids=[asset_id], path=target, source=source,
                    bytes=source.stat().st_size, sha256=sha256(source))
        overlays.append(item)
        return item

    for row in rows:
        asset_id = row["id"]
        native = input_file(row.get("source_path"), ledger_path.parent)
        if str(native).casefold() in inputs:
            raise ValueError(f"Duplicate source_path: {native}")
        inputs.add(str(native).casefold())
        native_sources[asset_id] = str(native)
        expected = designs["assets"][asset_id]["path"]
        if row.get("destination_resource", expected) != expected:
            raise ValueError(f"{asset_id}: destination_resource must remain {expected}")
        bodies[asset_id] = add_file(asset_id, row.get("runtime_path"), expected, {".glb"})
        textures = row.get("textures", [])
        if not isinstance(textures, list):
            raise ValueError(f"{asset_id}: textures must be an array")
        for texture in textures:
            add_file(asset_id, texture["source_path"], texture["runtime_path"], TEXTURES)
    for body in bodies.values():
        check_glb(body, destinations)
    roles = designs["roles"]
    if set(roles.values()) != REQUIRED:
        raise ValueError("Source role mapping must cover all 33 IDs")
    for role, asset_id in roles.items():
        record = runtime["roles"][role]
        if record["model"] != bodies[asset_id]["path"] or record.get("design_id") != asset_id:
            raise ValueError(f"Runtime role disagrees with design manifest: {role}")
    for name in ROOT_FILES:
        on_d(game / name)

    # Complete ledger validation happens before creating the disposable copy.
    output.mkdir(parents=True, exist_ok=resume_incomplete)
    def copy_source(source,target):
        source,target=Path(source),Path(target)
        if resume_incomplete and target.is_file():
            a,b=source.stat(),target.stat()
            if a.st_size==b.st_size and a.st_mtime_ns==b.st_mtime_ns:
                return str(target)
        return shutil.copy2(source,target)
    for path in sorted(game.iterdir()):
        if path.name in DIRECTORIES and path.is_dir():
            shutil.copytree(on_d(path), output / path.name, ignore=ignore_sources,
                            dirs_exist_ok=resume_incomplete,copy_function=copy_source)
        elif path.is_file() and path.name not in SKIP_FILES and (path.name in ROOT_FILES or path.suffix == ".json"):
            shutil.copy2(on_d(path), output / path.name)
    # Raw libraries are already excluded by this project's imports/exports.
    # Keep any interrupted-copy files inert, without deleting source or scratch.
    for name in ('raw','downloads'):
        directory=output/'assets_external'/name
        source_ignore=game/'assets_external'/name/'.gdignore'
        if directory.exists() and source_ignore.is_file():
            shutil.copy2(source_ignore,directory/'.gdignore')
    # Old, export-excluded OBJ references still need their original sidecars
    # for a clean editor import. Preserve the library; repair only this copy.
    sidecars = [
        ('characters', 'quaternius_lowpoly_rpg_characters/RPG Characters - Nov 2020/OBJ',
         ('Cleric', 'Warrior', 'Ranger', 'Monk')),
        ('characters', 'quaternius_lowpoly_animated_knight/Knight Character by @Quaternius/OBJ',
         ('Helmet1',)),
        ('enemies', 'quaternius_animated_animals_lowpoly/Animal Pack Vol.2 by @Quaternius/OBJ',
         ('Dog', 'Wolf')),
    ]
    restored = []
    for family, directory, names in sidecars:
        for name in names:
            target = output / 'assets_external' / family / (name + '.mtl')
            if not target.exists():
                source = on_d(game / 'assets_external/raw' / directory / (name + '.mtl'))
                shutil.copy2(source, target)
                restored.append(dict(path=str(target.relative_to(output)), sha256=sha256(target)))
    for item in overlays:
        target = output / resource_path(item["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item["source"], target)
        if sha256(target) != item["sha256"]:
            raise ValueError(f"Candidate changed during copy: {item['source']}")
    for asset_id, body in bodies.items():
        record = designs["assets"][asset_id]
        row=next(row for row in rows if row['id']==asset_id)
        if row.get('authored_bind_bounds'):
            if row['authored_bind_bounds']['asset_sha256']!=body['sha256']:
                raise ValueError('Stale authored bind bounds: '+asset_id)
            record['authored_bind_bounds']=row['authored_bind_bounds']
        if "blender_report" in record:
            record["baseline_blender_report"] = record.pop("blender_report")
        record.update(bytes=body["bytes"], sha256=body["sha256"], private_review_only=True,
                      candidate_source_path=native_sources[asset_id], candidate_runtime_path=str(body["source"]))
    for role, asset_id in roles.items():
        runtime["roles"][role].update(
            runtime_files=[{key: item[key] for key in ("path", "bytes", "sha256")}
                           for item in overlays if asset_id in item['asset_ids']],
            approved=False, visual_reviewed=False, runtime_acceptance="unverified",
            private_review_only=True, status="private_stylized_review_only")
    designs.update(runtime_acceptance="unverified", private_review_only=True)
    runtime.update(status="private_stylized_review_only", private_review_only=True)
    (output/'override.cfg').write_text(
        '[application]\nconfig/name="AshenOath_Anwen_ArtReview_20261030"\n'
        'config/use_custom_user_dir=false\n',encoding='utf-8')
    if sha256(ledger_path) != ledger_hash:
        raise ValueError("Ledger changed during preparation; snapshot is incomplete")
    for relative, data in (("data/design_pack_assets.json", designs), ("runtime_asset_manifest.json", runtime)):
        (output / relative).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    frozen_ledger=output/'private_candidate_ledger.json'
    shutil.copy2(ledger_path,frozen_ledger)
    receipt = dict(status="private_review_only", publication_authorized=False,
                   ledger=str(ledger_path), ledger_sha256=ledger_hash, source_project=str(game),
                   frozen_ledger=str(frozen_ledger),
                   restored_legacy_sidecars=restored,
                   authoring_sources=native_sources,
                   overlays=[dict(item, source=str(item["source"])) for item in overlays],
                   prepared_actors="omitted; main must regenerate", build_performed=False, qa_performed=False)
    (output / "private_review_preparation.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=RECOVERY / "stylized_roster.json")
    parser.add_argument('--resume-incomplete',action='store_true')
    args = parser.parse_args()
    try:
        output = prepare(args.ledger,args.resume_incomplete)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"PRIVATE REVIEW PREPARATION: FAIL - {error}", file=sys.stderr)
        return 1
    print(f"PRIVATE REVIEW PREPARATION: {output}; no engine, build, QA or publication run")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
