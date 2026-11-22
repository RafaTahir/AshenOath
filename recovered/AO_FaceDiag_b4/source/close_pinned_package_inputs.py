"""Force the exact existing source bytes through the updated Git attributes."""
from pathlib import Path
import hashlib
import json
import subprocess

repo = Path('D:/Temp/af')
pins = json.loads((repo / 'art_source/art_recovery_v2/evidence/lower_face_repair_20261111/packaging_input_bytes.json').read_bytes())['inputs']
with (repo / '.gitattributes').open('a', encoding='utf-8', newline='\n') as stream:
    stream.write('\n# Generated Web transport retains its packaged CRLF line endings.\n')
    for name in ('web/index.html', 'web/release_manifest.json', 'web/runtime_pack_manifest.json'):
        stream.write(name + ' whitespace=cr-at-eol\n')
subprocess.run(['git', '-C', str(repo), 'add', '--renormalize', '--sparse', '--', *[p['path'] for p in pins]], check=True)
subprocess.run(['git', '-C', str(repo), 'add', '--', '.gitattributes'], check=True)
for pin in pins:
    data = subprocess.check_output(['git', '-C', str(repo), 'show', ':' + pin['path']])
    if hashlib.sha256(data).hexdigest() != pin['sha256']:
        raise ValueError('Staged packaging input mismatch: ' + pin['path'])
print(json.dumps({'exact_staged_packaging_inputs': len(pins)}))
