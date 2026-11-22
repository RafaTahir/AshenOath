"""Copy only changed, validated static artifacts; retain both prior candidates."""
import hashlib
import json
import shutil
import sys
from pathlib import Path

root = Path('D:/Projects/AshenOath')
project = root / 'outputs/AshenOathTheRoadBetweenCrowns'
sys.path.insert(0, str(project / 'tools'))
from build_web_runtime_manifest import inspect_packaged_export

candidate = root / '.release-gate/web-efficiency-20261101-r2/export'
previous = root / '.release-gate/web-efficiency-20261101/export'
web = root / 'web'
inspect_packaged_export(candidate)
inspect_packaged_export(web)
old = json.loads((web / 'release_manifest.json').read_text())
new = json.loads((candidate / 'release_manifest.json').read_text())
assert old['build_id'] == 'web-efficiency-20261101-77a0e8e'
assert new['build_id'] == 'web-efficiency-20261101-r2'
old_paths = {r['path'] for r in old['artifacts']} | {'release_manifest.json'}
new_paths = {r['path'] for r in new['artifacts']} | {'release_manifest.json'}
assert old_paths == new_paths, 'Unexpected artifact-path change; review before installation'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

changed = []
for relative in sorted(new_paths):
    path = Path(relative)
    assert not path.is_absolute() and '..' not in path.parts
    assert sha(web / path) == sha(previous / path), f'Current web changed since baseline: {path}'
    if sha(web / path) != sha(candidate / path):
        changed.append(path)
for path in changed:
    shutil.copy2(candidate / path, web / path)
inspection = inspect_packaged_export(web)
assert inspection['build_id'] == new['build_id']
print(json.dumps({'status': 'pass', 'copied_artifacts': [p.as_posix() for p in changed], 'bytes': inspection['directory_bytes']}))
