"""Check staged release bytes and whole-index file sizes without an engine."""
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path("D:/Temp/af")
def git(*args, data=None):
    return subprocess.run(["git", "-C", str(REPO), *args], input=data, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

entries = {}
for row in git("ls-files", "--stage", "-z").split(b"\0"):
    if not row: continue
    info, name = row.split(b"\t", 1)
    mode, oid, stage = info.split()
    if stage != b"0": raise ValueError("Unmerged release source")
    entries[name.decode("utf-8")] = (mode, oid)
changed = [row.decode("utf-8") for row in git("diff", "--cached", "--name-only", "--diff-filter=ACM", "-z").split(b"\0") if row]
process = subprocess.Popen(["git", "-C", str(REPO), "cat-file", "--batch"],
                           stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
try:
    for name in changed:
        process.stdin.write(entries[name][1] + b"\n")
        process.stdin.flush()
        header = process.stdout.readline().split()
        if len(header) != 3 or header[1] != b"blob": raise ValueError("Missing staged blob: " + name)
        remaining = int(header[2])
        stored = hashlib.sha256()
        while remaining:
            chunk = process.stdout.read(min(1024 * 1024, remaining))
            if not chunk: raise ValueError("Truncated staged blob")
            stored.update(chunk)
            remaining -= len(chunk)
        if process.stdout.read(1) != b"\n": raise ValueError("Bad Git batch boundary")
        with (REPO / name).open("rb") as stream:
            physical = hashlib.file_digest(stream, "sha256").digest()
        if stored.digest() != physical: raise ValueError("Git normalized release bytes: " + name)
    process.stdin.close()
    if process.wait(): raise ValueError(process.stderr.read().decode(errors="replace"))
finally:
    if process.poll() is None:
        process.terminate()
        process.wait()
objects = {oid: name for name, (mode, oid) in entries.items() if mode != b"160000"}
rows = git("cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)", data=b"\n".join(objects) + b"\n")
largest = (0, "")
for row in rows.splitlines():
    oid, kind, size = row.split()
    size = int(size)
    if kind != b"blob": continue
    if size >= 100 * 1024 * 1024: raise ValueError("Committed file reaches 100 MiB: " + objects[oid])
    if size > largest[0]: largest = (size, objects[oid])
print(json.dumps({"staged_files_byte_identical": len(changed), "largest_committed_file_bytes": largest[0],
                  "largest_committed_file_path": largest[1]}))
