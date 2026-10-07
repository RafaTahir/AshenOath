import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

MAX_TOTAL_MB = 100.0
MAX_PCK_MB = 60.0
EXPECTED_FILES = {
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "index.png",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
    "runtime_pack_manifest.json",
    "release_manifest.json",
}
FORBIDDEN_SUFFIXES = {".map", ".debug", ".zip", ".blend"}
ALLOWED_RUNTIME_SUBDIRECTORIES = {"packs"}


def mb(size: int) -> float:
    return size / (1024 * 1024)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decoded_pck(path: Path) -> bytes:
    payload = path.read_bytes()
    return gzip.decompress(payload) if payload.startswith(b"\x1f\x8b") else payload


def verify_pack_files(export_dir: Path, manifest: dict) -> list[str]:
    failures = []
    if not isinstance(manifest, dict):
        return ["runtime manifest must be an object"]
    packs = manifest.get("packs")
    if not isinstance(packs, dict) or not packs:
        return ["runtime manifest has no pack definitions"]
    root = export_dir.resolve()
    for pack_id, pack in packs.items():
        if not isinstance(pack, dict):
            failures.append(f"{pack_id}: invalid pack definition")
            continue
        dependencies = pack.get("dependencies", [])
        if not isinstance(dependencies, list) or any(not isinstance(item, str) for item in dependencies):
            failures.append(f"{pack_id}: dependencies must be a list of pack IDs")
            dependencies = []
        for dependency in dependencies:
            if dependency not in packs:
                failures.append(f"{pack_id}: unknown dependency {dependency}")
        url = str(pack.get("url", ""))
        embedded = str(pack.get("status", "")).startswith("embedded")
        if not url:
            if not embedded:
                failures.append(f"{pack_id}: missing URL without embedded ownership")
            continue
        if embedded:
            failures.append(f"{pack_id}: embedded ownership conflicts with external URL")
            continue
        digest = str(pack.get("sha256", "")).lower()
        if not digest or digest not in url or str(pack.get("cache_key", "")).lower() != digest:
            failures.append(f"{pack_id}: URL/cache key is not content-addressed by SHA-256")
        parsed = urlsplit(url)
        path = (root / unquote(parsed.path).lstrip("/")).resolve()
        if parsed.scheme or parsed.netloc or not path.is_relative_to(root / "packs"):
            failures.append(f"{pack_id}: pack URL must resolve inside exported packs/")
            continue
        if not path.is_file():
            failures.append(f"{pack_id}: missing required pack {path.relative_to(root)}")
            continue
        try:
            payload = decoded_pck(path)
        except (OSError, EOFError):
            failures.append(f"{pack_id}: compressed pack is corrupt")
            continue
        if not payload.startswith(b"GDPC"):
            failures.append(f"{pack_id}: payload is not a Godot PCK")
        if len(payload) != pack.get("bytes"):
            failures.append(f"{pack_id}: pack byte count differs from runtime manifest")
        if hashlib.sha256(payload).hexdigest() != str(pack.get("sha256", "")).lower():
            failures.append(f"{pack_id}: pack SHA-256 differs from runtime manifest")
    visited, visiting = set(), set()

    def visit(pack_id):
        if pack_id in visiting:
            failures.append(f"{pack_id}: cyclic pack dependency")
            return
        if pack_id in visited:
            return
        visiting.add(pack_id)
        pack = packs.get(pack_id)
        dependencies = pack.get("dependencies", []) if isinstance(pack, dict) else []
        if isinstance(dependencies, list):
            for dependency in dependencies:
                if isinstance(dependency, str) and dependency in packs:
                    visit(dependency)
        visiting.remove(pack_id)
        visited.add(pack_id)

    for pack_id in packs:
        visit(pack_id)
    return failures


def verify_release_identity(export_dir: Path, runtime: dict, release: dict) -> list[str]:
    failures: list[str] = []
    if not isinstance(release, dict) or int(release.get("schema_version", 0)) < 2:
        return ["release_manifest.json is missing the PACK-002 schema"]
    build_id = str(release.get("build_id", ""))
    if not build_id or build_id not in {str(runtime.get("release_id", "")), str(runtime.get("build_id", ""))}:
        failures.append("release build ID differs from runtime pack identity")
    source = release.get("source", {})
    if not isinstance(source, dict) or str(source.get("git_commit", "")) != str(runtime.get("generated_from_commit", "")):
        failures.append("release source commit differs from runtime pack source")

    actual = {
        path.relative_to(export_dir).as_posix(): path
        for path in export_dir.rglob("*")
        if path.is_file() and path.name != "release_manifest.json"
    }
    recorded = release.get("artifacts", [])
    recorded_by_path = {
        str(item.get("path", "")): item
        for item in recorded if isinstance(item, dict) and item.get("path")
    }
    if set(actual) != set(recorded_by_path):
        failures.append("release artifact inventory differs from files on disk")
    for relative, path in actual.items():
        item = recorded_by_path.get(relative)
        if item is None:
            continue
        if int(item.get("bytes", -1)) != path.stat().st_size or str(item.get("sha256", "")).lower() != sha256(path):
            failures.append(f"release artifact identity differs: {relative}")
        if relative.endswith(".pck"):
            try:
                decoded = decoded_pck(path)
                if not path.read_bytes().startswith(b"\x1f\x8b") \
                        or item.get("content_encoding") != "gzip" \
                        or item.get("decoded_bytes") != len(decoded) \
                        or item.get("decoded_sha256") != hashlib.sha256(decoded).hexdigest() \
                        or not decoded.startswith(b"GDPC"):
                    failures.append(f"compressed PCK identity is stale or invalid: {relative}")
            except (OSError, EOFError):
                failures.append(f"compressed PCK is corrupt: {relative}")
        if relative == "index.wasm" and path.read_bytes().startswith(b"\x1f\x8b"):
            try:
                decoded = gzip.decompress(path.read_bytes())
                if item.get("content_encoding") != "gzip" or not decoded.startswith(b"\x00asm") \
                        or item.get("decoded_bytes") != len(decoded) \
                        or item.get("decoded_sha256") != hashlib.sha256(decoded).hexdigest():
                    failures.append("compressed WebAssembly decoded identity is stale or invalid")
            except (OSError, EOFError):
                failures.append("compressed WebAssembly is corrupt")
    expected_total = sum(path.stat().st_size for path in actual.values())
    if int(release.get("artifacts_total_bytes", -1)) != expected_total:
        failures.append("release artifact total is stale")

    for key, relative in (("runtime_pack_manifest", "runtime_pack_manifest.json"), ("root_pck", "index.pck")):
        record = release.get(key, {})
        path = actual.get(relative)
        if not isinstance(record, dict) or path is None \
                or str(record.get("path", "")) != relative \
                or int(record.get("bytes", -1)) != path.stat().st_size \
                or str(record.get("sha256", "")).lower() != sha256(path):
            failures.append(f"release {key} identity is stale")

    release_packs = {str(item.get("id", "")): item for item in release.get("packs", []) if isinstance(item, dict)}
    runtime_packs = runtime.get("packs", {})
    if set(release_packs) != set(runtime_packs):
        failures.append("release pack graph differs from runtime pack graph")
    for pack_id, pack in runtime_packs.items():
        item = release_packs.get(str(pack_id), {})
        for field in ("url", "sha256", "bytes", "dependencies"):
            if item.get(field) != pack.get(field):
                failures.append(f"{pack_id}: release pack {field} differs from runtime manifest")
                break

    html = actual.get("index.html")
    if html is not None:
        text = html.read_text(encoding="utf-8", errors="ignore")
        if f'const SHELL_BUILD_ID = {json.dumps(build_id)};' not in text \
                or f'const RUNTIME_PACK_CONTRACT = {json.dumps(build_id)};' not in text:
            failures.append("index.html shell identity differs from release build ID")
    compatibility_key = str(release.get("compatibility_key", ""))
    if len(compatibility_key) != 64 or any(character not in "0123456789abcdef" for character in compatibility_key.lower()):
        failures.append("release compatibility key is not SHA-256")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--json-report", type=Path)
    parser.add_argument("--runtime-manifest", type=Path,
                        help="Manifest embedded by this export; defaults to its sidecar or current project manifest")
    args = parser.parse_args()

    export_dir = args.export_dir.resolve()
    failures = []
    if not export_dir.is_dir():
        print(f"WEB EXPORT: FAIL - missing export directory: {export_dir}")
        return 1

    manifest_path = export_dir / "runtime_pack_manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        failures.extend(verify_pack_files(export_dir, manifest))
    except (OSError, ValueError, TypeError) as exc:
        manifest = {}
        failures.append(f"invalid runtime pack manifest: {exc}")
    if args.runtime_manifest is not None:
        try:
            if args.runtime_manifest.resolve().read_bytes() != manifest_path.read_bytes():
                failures.append("exported runtime pack manifest differs from requested source manifest")
        except OSError as exc:
            failures.append(f"unable to compare runtime pack manifest: {exc}")

    root_paths = {path.name: path for path in export_dir.iterdir() if path.is_file()}
    nested_paths = {}
    for directory in export_dir.iterdir():
        if not directory.is_dir():
            continue
        if directory.name not in ALLOWED_RUNTIME_SUBDIRECTORIES:
            failures.append(f"unexpected export subdirectory: {directory.name}")
            continue
        for path in directory.rglob("*"):
            if path.is_file():
                nested_paths[path.relative_to(export_dir).as_posix()] = path
    paths = {**root_paths, **nested_paths}
    missing = sorted(EXPECTED_FILES - root_paths.keys())
    extras = sorted(root_paths.keys() - EXPECTED_FILES)
    if missing:
        failures.append("missing files: " + ", ".join(missing))
    release_path = paths.get("release_manifest.json")
    if release_path is not None:
        try:
            release = json.loads(release_path.read_text(encoding="utf-8-sig"))
            failures.extend(verify_release_identity(export_dir, manifest, release))
        except (OSError, ValueError, TypeError) as exc:
            failures.append(f"invalid release manifest: {exc}")
    forbidden = [name for name in extras if Path(name).suffix.lower() in FORBIDDEN_SUFFIXES]
    if forbidden:
        failures.append("forbidden development files: " + ", ".join(forbidden))

    html = paths.get("index.html")
    if html:
        html_text = html.read_text(encoding="utf-8", errors="ignore")
        for runtime_name in ("index.js", "index.wasm", "index.pck"):
            if runtime_name not in html_text:
                failures.append(f"index.html does not reference {runtime_name}")
        # Godot injects the runtime byte sizes into the custom shell. A stale
        # size makes the visible progress bar claim readiness before the PCK is
        # actually available, so treat the shell/artifact pair as one contract.
        size_match = re.search(r'"fileSizes"\s*:\s*\{([^{}]*)\}', html_text)
        if size_match is None:
            failures.append("index.html is missing the generated Engine fileSizes contract")
        else:
            declared_sizes = {
                name: int(value)
                for name, value in re.findall(r'"(index\.(?:wasm|pck))"\s*:\s*(\d+)', size_match.group(1))
            }
            for runtime_name in ("index.wasm", "index.pck"):
                actual_path = paths.get(runtime_name)
                declared = declared_sizes.get(runtime_name)
                if actual_path is None or declared is None:
                    failures.append(f"index.html fileSizes is missing {runtime_name}")
                elif declared != (len(gzip.decompress(actual_path.read_bytes()))
                                  if actual_path.read_bytes().startswith(b"\x1f\x8b")
                                  else actual_path.stat().st_size):
                    failures.append(
                        f"index.html fileSizes.{runtime_name}={declared} does not match "
                        f"artifact bytes {actual_path.stat().st_size}"
                    )

    total_bytes = sum(path.stat().st_size for path in paths.values())
    if mb(total_bytes) >= MAX_TOTAL_MB:
        failures.append(f"payload {mb(total_bytes):.1f} MB exceeds {MAX_TOTAL_MB:.0f} MB")
    pck = paths.get("index.pck")
    if pck and mb(pck.stat().st_size) >= MAX_PCK_MB:
        failures.append(f"index.pck {mb(pck.stat().st_size):.1f} MB exceeds {MAX_PCK_MB:.0f} MB")
    empty = [name for name, path in paths.items() if path.stat().st_size == 0]
    if empty:
        failures.append("empty runtime files: " + ", ".join(sorted(empty)))

    for name, path in nested_paths.items():
        if Path(name).suffix.lower() in FORBIDDEN_SUFFIXES:
            failures.append(f"forbidden development file: {name}")
        if Path(name).suffix.lower() == ".pck":
            try:
                if not decoded_pck(path).startswith(b"GDPC"):
                    failures.append(f"invalid Godot PCK: {name}")
            except (OSError, EOFError):
                failures.append(f"corrupt compressed Godot PCK: {name}")

    file_report = {
        name: {
            "bytes": path.stat().st_size,
            "megabytes": round(mb(path.stat().st_size), 3),
            "sha256": sha256(path),
        }
        for name, path in sorted(paths.items())
    }
    report = {
        "schema_version": 1,
        "status": "fail" if failures else "pass",
        "export_dir": str(export_dir),
        "runtime_manifest": str(manifest_path.resolve()),
        "file_count": len(paths),
        "total_bytes": total_bytes,
        "total_megabytes": round(mb(total_bytes), 3),
        "limits": {"total_megabytes": MAX_TOTAL_MB, "pck_megabytes": MAX_PCK_MB},
        "extras": extras,
        "nested_files": sorted(nested_paths),
        "failures": failures,
        "files": file_report,
    }
    if args.json_report:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if failures:
        for failure in failures:
            print(f"WEB EXPORT: FAIL - {failure}")
        return 1
    print(
        f"WEB EXPORT: PASS - {len(paths)} files, {mb(total_bytes):.1f} MB, "
        f"PCK {mb(pck.stat().st_size):.1f} MB"
    )
    print(f"WEB EXPORT PCK SHA256: {file_report['index.pck']['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
