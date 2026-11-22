import gzip
import hashlib
import importlib.util
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(r"D:\Projects\AshenOath")
PROJECT = REPO / "outputs/AshenOathTheRoadBetweenCrowns"
GODOT = Path(r"D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe")
BUILD = sys.argv[1] if len(sys.argv) > 1 else "cohesion-bow-camera-20261025"
RUN = REPO / ".release-gate" / BUILD
WEB = REPO / "web"
OUT = RUN / "export"
PACKS = RUN / "runtime-packs"
CHANGED = [Path(name).stem for name in subprocess.check_output(["git","diff","--name-only","HEAD","--","outputs/AshenOathTheRoadBetweenCrowns/scripts"],cwd=REPO,text=True).splitlines() if name.endswith(".gd")]
REBUILD = set(sys.argv[2:])
RESUME_OPENING = "--resume-opening" in REBUILD
REBUILD.discard("--resume-opening")
RESUME_EXTERNAL = "--resume-external" in REBUILD
REBUILD.discard("--resume-external")

def digest(data):
    return hashlib.sha256(data).hexdigest()

def entries(data):
    assert data[:4] == b"GDPC" and struct.unpack_from("<I", data, 4)[0] == 3
    pos = struct.unpack_from("<Q", data, 32)[0]
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    result = []
    for _ in range(count):
        size = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        result.append(data[pos:pos+size].rstrip(b"\0").decode())
        pos += size + 8 + 8 + 16 + 4
    return result

def export(preset, target, tag):
    if RESUME_EXTERNAL and target.suffix == ".pck" and tag != "base":
        assert target.is_file()
        logs = (RUN / (tag + ".stdout.log")).read_text(errors="replace") + (RUN / (tag + ".stderr.log")).read_text(errors="replace")
        assert not any(text in logs for text in ["SCRIPT ERROR", "Parse Error", "Compile Error"])
        for name in entries(target.read_bytes()):
            source = name.removeprefix("res://")
            if source.endswith(".gdc"): source = source[:-4] + ".gd"
            if source.endswith(".gd.remap"): source = source[:-6]
            path = PROJECT/source
            if source.endswith(".gd") and path.is_file(): assert path.stat().st_mtime <= target.stat().st_mtime, source
        print("REUSING completed external export", preset, flush=True)
        return
    if RESUME_OPENING and tag == "opening":
        assert target.is_file()
        logs = (RUN / (tag + ".stdout.log")).read_text(errors="replace") + (RUN / (tag + ".stderr.log")).read_text(errors="replace")
        assert not any(text in logs for text in ["SCRIPT ERROR", "Parse Error", "Compile Error"])
        assert all(path.stat().st_mtime <= target.stat().st_mtime for path in (PROJECT/"scripts").rglob("*.gd"))
        print("REUSING completed opening export from this invocation", flush=True)
        return
    if RESUME_EXTERNAL:
        tag += "-root-aligned"
        attempt = 1
        while (RUN / (tag + ".stdout.log")).exists():
            attempt += 1
            tag = tag.split("-attempt-")[0] + f"-attempt-{attempt}"
    with (RUN / (tag + ".stdout.log")).open("wb") as out, (RUN / (tag + ".stderr.log")).open("wb") as err:
        process = subprocess.run([str(GODOT), "--headless", "--path", str(PROJECT), "--export-pack" if target.suffix == ".pck" else "--export-release", preset, str(target)], stdout=out, stderr=err, timeout=600)
    logs = (RUN / (tag + ".stdout.log")).read_text(errors="replace") + (RUN / (tag + ".stderr.log")).read_text(errors="replace")
    if process.returncode or any(text in logs for text in ["SCRIPT ERROR", "Parse Error", "Compile Error"]):
        raise RuntimeError(f"Build failed; inspect {tag} logs")
    print("BUILT", preset, flush=True)

RUN.mkdir(exist_ok=RESUME_OPENING or RESUME_EXTERNAL)
OUT.mkdir(exist_ok=RESUME_OPENING or RESUME_EXTERNAL)
PACKS.mkdir(exist_ok=RESUME_OPENING or RESUME_EXTERNAL)
head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
candidates = json.loads((PROJECT / "runtime_pack_candidates.json").read_text(encoding="utf-8-sig"))
old_build = candidates["build_id"]
for pack in candidates["packs"]:
    if pack["id"] == "base": continue
    if pack["id"] in REBUILD:
        export(pack["preset"], PACKS/pack["artifact"], pack["id"])
        data = (PACKS/pack["artifact"]).read_bytes()
        pack.update(bytes=len(data),sha256=digest(data),version=BUILD)
        pack.pop("reused_from_build",None)
        (PACKS/(pack["id"]+".pck.gz")).write_bytes(gzip.compress(data,compresslevel=9,mtime=0))
        continue
    encoded = (WEB / "packs" / (pack["id"] + ".pck")).read_bytes()
    data = gzip.decompress(encoded)
    assert len(data) == pack["bytes"] and digest(data) == pack["sha256"]
    names = entries(data)
    conflicts = [name for name in names if any(name.endswith("/"+script+suffix) for script in CHANGED for suffix in [".gd", ".gdc", ".gd.remap"])]
    if conflicts: raise RuntimeError(f"Changed script owned by external {pack['id']}: {conflicts}")
    shutil.copyfile(WEB / "packs" / (pack["id"] + ".pck"), PACKS / (pack["id"] + ".pck.gz"))
    pack["version"] = BUILD
    pack["reused_from_build"] = old_build
export("Runtime Pack Base", PACKS / "base.pck", "base")
base = next(p for p in candidates["packs"] if p["id"] == "base")
base.update(bytes=(PACKS/"base.pck").stat().st_size, sha256=digest((PACKS/"base.pck").read_bytes()), version=BUILD)
candidates.update(build_id=BUILD, generated_from_commit=head, source_dirty=True)
candidates["total_bytes"] = sum(p["bytes"] for p in candidates["packs"])
candidate_path = RUN / "runtime_pack_candidates.json"
candidate_path.write_text(json.dumps(candidates, indent=2)+"\n")
subprocess.run([sys.executable, str(PROJECT/"tools/sync_runtime_pack_manifest.py"), str(PROJECT/"runtime_pack_manifest.json"), str(candidate_path), "--build-id", BUILD, "--source-commit", head], check=True)
export("Web Browser", OUT / "index.html", "production")
spec = importlib.util.spec_from_file_location("packaging", PROJECT/"tools/build_web_runtime_manifest.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
previous = json.loads((WEB / "release_manifest.json").read_text())
for record in previous["artifacts"]:
    name = record["path"]
    if not name.startswith("engine/"): continue
    raw = OUT / Path(name).name
    encoded = (WEB/name).read_bytes()
    decoded = gzip.decompress(encoded) if encoded[:2] == b"\x1f\x8b" else encoded
    assert raw.read_bytes() == decoded, f"Engine bytes changed: {name}"
    raw.write_bytes(encoded)
engine = module.prepare_engine_transport(OUT)
(OUT/"packs").mkdir(exist_ok=RESUME_EXTERNAL or RESUME_OPENING)
for pack in candidates["packs"]:
    if pack["id"] != "base": shutil.copyfile(PACKS/(pack["id"]+".pck.gz"), OUT/"packs"/(pack["id"]+".pck"))
for name in ["menu-background.png", "index.png"]:
    shutil.copyfile(WEB/name, OUT/name)
shutil.copyfile(PROJECT/"runtime_pack_manifest.json", OUT/"runtime_pack_manifest.json")
module.compress_pck_transport(OUT)
manifest = module.build_manifest(OUT, PROJECT/"runtime_pack_manifest.json", head, engine)
(OUT/"release_manifest.json").write_text(json.dumps(manifest,separators=(",",":"))+"\n")
report = module.inspect_packaged_export(OUT)
print(json.dumps(report), flush=True)
assert sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file()) < 104857600
for source in OUT.rglob("*"):
    if not source.is_file(): continue
    destination = WEB / source.relative_to(OUT)
    if destination.exists() and destination.read_bytes() == source.read_bytes(): continue
    if destination.exists():
        backup = RUN / "previous-web" / source.relative_to(OUT)
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(destination, backup)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
print("SYNCHRONIZED", BUILD, flush=True)
