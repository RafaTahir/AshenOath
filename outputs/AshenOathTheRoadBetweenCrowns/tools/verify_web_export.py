import sys
from pathlib import Path

WARNING_TOTAL_MB = 200.0
WARNING_PCK_MB = 100.0
WARNING_SINGLE_FILE_MB = 100.0


def mb(size: int) -> float:
    return size / (1024 * 1024)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify_web_export.py <export_dir>")
        return 2
    export_dir = Path(sys.argv[1])
    if not export_dir.exists():
        print(f"missing export directory: {export_dir}")
        return 1
    files = {path.name.lower(): path for path in export_dir.iterdir() if path.is_file()}
    required_exact = ["index.html"]
    required_exts = [".wasm", ".pck", ".js"]
    missing = []
    for name in required_exact:
        if name not in files:
            missing.append(name)
    for ext in required_exts:
        if not any(path.suffix.lower() == ext for path in files.values()):
            missing.append(f"*{ext}")
    if missing:
        print("web export is incomplete; missing: " + ", ".join(missing))
        return 1
    html = files["index.html"].read_text(encoding="utf-8", errors="ignore")
    if ".wasm" not in html or ".pck" not in html:
        print("warning: index.html does not explicitly mention .wasm/.pck; Godot loader may still reference them through config")
    total_bytes = sum(path.stat().st_size for path in files.values())
    print(f"web export verified: {len(files)} files, {mb(total_bytes):.1f} MB")
    for path in sorted(files.values(), key=lambda item: item.stat().st_size, reverse=True):
        print(f"  {path.name}: {mb(path.stat().st_size):.1f} MB")
    pck_files = [path for path in files.values() if path.suffix.lower() == ".pck"]
    if pck_files:
        pck_size = mb(max(path.stat().st_size for path in pck_files))
        if pck_size > WARNING_PCK_MB:
            print(f"warning: .pck is {pck_size:.1f} MB; static hosts are happier below {WARNING_PCK_MB:.0f} MB")
    if mb(total_bytes) > WARNING_TOTAL_MB:
        print(f"warning: total export is {mb(total_bytes):.1f} MB; target slim web builds below {WARNING_TOTAL_MB:.0f} MB")
    large_files = [path.name for path in files.values() if mb(path.stat().st_size) > WARNING_SINGLE_FILE_MB]
    if large_files:
        print("warning: files over static-host comfort threshold: " + ", ".join(sorted(large_files)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
