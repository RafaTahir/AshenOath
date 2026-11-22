"""Adopt two byte-identical incoming archive files without altering their data."""
from pathlib import Path
import hashlib
import json
import subprocess

repo = Path('D:/Projects/AshenOath')
commit = 'a29972e73d6881aab0b80aff6e54da66cd2ca23c'
prefix = 'art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/companion/proofs/ad3bc684c0179d6b56661f8c1ba332c4e68edf78e82308fb59d2e2f917f90f26/9e9764880b034b9fd4f02d9e0b3b97ee53db9dd9b6bc34f05631c0fe4bfe073f/'
names = [prefix + name for name in ('bracken.scn', 'compiler_receipt.json')]
held = repo / 'outputs/AshenOathTheRoadBetweenCrowns/scripts/held_prop_geometry.gd'
held_before = held.read_bytes()

def git(*args, check=True):
    return subprocess.run(['git', '-c', 'core.longpaths=true', '-C', str(repo), *args], check=check,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)

if git('diff', '--cached', '--name-only').stdout.strip():
    raise ValueError('Canonical index has user changes; do not adopt files')
for name in names:
    if git('ls-files', '--', name).stdout.strip():
        raise ValueError('Archive was unexpectedly tracked already')
    if (repo / name).read_bytes() != git('show', commit + ':' + name).stdout:
        raise ValueError('Existing archive differs: ' + name)

git('restore', '--staged', '--source=' + commit, '--', *names)
result = git('-c', 'core.hooksPath=D:/Temp/af/.release-gate/lower-face-repair-20261112-1653ba2-r4/no-hooks',
             'merge', '--no-overwrite-ignore', '--ff-only', commit, check=False)
if result.returncode:
    git('restore', '--staged', '--source=HEAD', '--', *names)
if held.read_bytes() != held_before:
    raise ValueError('Local held-prop edit unexpectedly changed')
for name in names:
    if (repo / name).read_bytes() != git('show', commit + ':' + name).stdout:
        raise ValueError('Archive physical bytes changed')
head = git('rev-parse', 'HEAD').stdout.decode().strip()
record = {'canonical_fast_forward_exit': result.returncode, 'head': head,
          'adopted_byte_identical_archives': names, 'local_held_prop_bytes_preserved': True,
          'stdout': result.stdout.decode(errors='replace'), 'stderr': result.stderr.decode(errors='replace')}
Path('D:/Temp/af/.release-gate/lower-face-repair-20261112-1653ba2-r4/canonical_workspace.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in record.items() if key != 'stdout'}))
