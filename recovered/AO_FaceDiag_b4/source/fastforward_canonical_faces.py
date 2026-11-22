"""Attempt a protected fast-forward without touching local or ignored work."""
import hashlib
import json
from pathlib import Path
import subprocess

repo = Path('D:/Projects/AshenOath')
held = repo / 'outputs/AshenOathTheRoadBetweenCrowns/scripts/held_prop_geometry.gd'
before = hashlib.sha256(held.read_bytes()).hexdigest()
result = subprocess.run(['git', '-C', str(repo), '-c',
                         'core.hooksPath=D:/Temp/af/.release-gate/lower-face-repair-20261112-1653ba2-r4/no-hooks',
                         'merge', '--no-overwrite-ignore', '--ff-only',
                         'a29972e73d6881aab0b80aff6e54da66cd2ca23c'],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
after = hashlib.sha256(held.read_bytes()).hexdigest()
if before != after:
    raise ValueError('Protected local held-prop edit changed unexpectedly')
record = {'canonical_fast_forward_exit': result.returncode, 'local_held_prop_bytes_preserved': True,
          'stdout': result.stdout.decode(errors='replace'), 'stderr': result.stderr.decode(errors='replace')}
path = Path('D:/Temp/af/.release-gate/lower-face-repair-20261112-1653ba2-r4/canonical_workspace.json')
path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record))
