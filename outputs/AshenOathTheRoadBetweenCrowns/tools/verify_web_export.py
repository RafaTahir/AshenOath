import argparse
import hashlib
import json
from pathlib import Path

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
}
FORBIDDEN_SUFFIXES = {".map", ".debug", ".zip", ".blend"}


def mb(size: int) -> float:
    return size / (1024 * 1024)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()

    export_dir = args.export_dir.resolve()
    failures = []
    if not export_dir.is_dir():
        print(f"WEB EXPORT: FAIL - missing export directory: {export_dir}")
        return 1

    paths = {path.name: path for path in export_dir.iterdir() if path.is_file()}
    missing = sorted(EXPECTED_FILES - paths.keys())
    extras = sorted(paths.keys() - EXPECTED_FILES)
    if missing:
        failures.append("missing files: " + ", ".join(missing))
    forbidden = [name for name in extras if Path(name).suffix.lower() in FORBIDDEN_SUFFIXES]
    if forbidden:
        failures.append("forbidden development files: " + ", ".join(forbidden))

    html = paths.get("index.html")
    if html:
        html_text = html.read_text(encoding="utf-8", errors="ignore")
        for runtime_name in ("index.js", "index.wasm", "index.pck"):
            if runtime_name not in html_text:
                failures.append(f"index.html does not reference {runtime_name}")

    total_bytes = sum(path.stat().st_size for path in paths.values())
    if mb(total_bytes) >= MAX_TOTAL_MB:
        failures.append(f"payload {mb(total_bytes):.1f} MB exceeds {MAX_TOTAL_MB:.0f} MB")
    pck = paths.get("index.pck")
    if pck and mb(pck.stat().st_size) >= MAX_PCK_MB:
        failures.append(f"index.pck {mb(pck.stat().st_size):.1f} MB exceeds {MAX_PCK_MB:.0f} MB")
    empty = [name for name, path in paths.items() if path.stat().st_size == 0]
    if empty:
        failures.append("empty runtime files: " + ", ".join(sorted(empty)))

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
        "file_count": len(paths),
        "total_bytes": total_bytes,
        "total_megabytes": round(mb(total_bytes), 3),
        "limits": {"total_megabytes": MAX_TOTAL_MB, "pck_megabytes": MAX_PCK_MB},
        "extras": extras,
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
