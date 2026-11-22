"""Stage only the completed face candidate and its exact packaging inputs."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

REPO = Path('D:/Temp/af')
GAME = 'outputs/AshenOathTheRoadBetweenCrowns/'
ART = 'art_source/art_recovery_v2/'
EVIDENCE = ART + 'evidence/lower_face_repair_20261111/'
RELEASE = REPO / '.release-gate/lower-face-repair-20261112-1653ba2-r4'

def git(*args):
    return subprocess.run(['git', '-C', str(REPO), *args], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

inputs = [GAME + name for name in (
    'assets_external/environment/forest/CommonTree_5.obj',
    'assets_external/environment/forest/TwistedTree_2.obj',
    'assets_external/environment/forest/TwistedTree_4.obj',
    'scripts/prepared_forest_trees.gd',
    'tools/build_prepared_zone_geometry.gd',
    'tools/prepared_zone_geometry_factory.gd',
)]
pins = []
for name in inputs:
    physical = (REPO / name).read_bytes()
    stored = git('show', 'HEAD:' + name)
    if physical.replace(b'\r\n', b'\n') != stored.replace(b'\r\n', b'\n'):
        raise ValueError('Unexpected source-content change: ' + name)
    pins.append({'path': name, 'sha256': hashlib.sha256(physical).hexdigest(),
                 'previous_git_sha256': hashlib.sha256(stored).hexdigest(),
                 'change': 'preserve_exact_CRLF_input_already_used_by_package',
                 'logical_content_changed': False})

generated = [ART + 'evidence/living_assets_stage3_20261107/' + name for name in (
    'companion/prepared_companion.json',
    'scenery/ash_mill_wheel_compile.json',
    'scenery/checkpoint_cloth_compile.json',
    'scenery/hart_ferns_compile.json',
    'scenery/marsh_reeds_compile.json',
    'scenery/split_equivalence.json',
)]
generated += [ART + 'models/' + name for name in (
    'living_cast_20261107/library_compile_face_repair_C01_C04_C03_C02.json',
    'living_cast_stage2_20261107/library_compile_face_repair_C11_C05_C06_C12_C07_C09_C10_C08.json',
)]
generated += [GAME + name for name in (
    'data/environment_material_dependencies.json',
    'data/prepared_forest_trees.json',
    'export_presets.cfg',
    'runtime_pack_candidates.json',
    'runtime_pack_manifest.json',
)]

attribute_paths = []
for name in inputs + generated:
    result = git('check-attr', 'text', '--', name).decode().strip().rsplit(': ', 1)[-1]
    if result != 'unset':
        attribute_paths.append(name)
with (REPO / '.gitattributes').open('a', encoding='utf-8', newline='\n') as stream:
    stream.write('\n# Preserve the exact inputs and receipts consumed by the face package.\n')
    for name in attribute_paths:
        stream.write(name + ' -text whitespace=cr-at-eol\n')

(REPO / EVIDENCE / 'packaging_input_bytes.json').write_text(
    json.dumps({'kind': 'packaging_input_byte_closure', 'runtime_test': False,
                'build_id': RELEASE.name, 'inputs': pins}, indent=2) + '\n', encoding='utf-8')
shutil.copyfile(RELEASE / 'publication_receipt.json', REPO / EVIDENCE / 'package_candidate.json')

binary_outputs = [GAME + name for name in (
    'assets_external/characters_prepared/companions/bracken.scn',
    'assets_external/environment_prepared/living_world/ash_mill_wheel.scn',
    'assets_external/environment_prepared/living_world/checkpoint_cloth.scn',
    'assets_external/environment_prepared/living_world/hart_ferns.scn',
    'assets_external/environment_prepared/living_world/marsh_reeds.scn',
)]
companion = REPO / ART / 'evidence/living_assets_stage3_20261107/companion'
proof_root = companion / 'proofs/ad3bc684c0179d6b56661f8c1ba332c4e68edf78e82308fb59d2e2f917f90f26'
proofs = []
for sha in ('9e9764880b034b9fd4f02d9e0b3b97ee53db9dd9b6bc34f05631c0fe4bfe073f',
            '57c83b7539598f4a7ec381115cbf533b308cbb8dc9fb9ab437dd956ff195d1d8'):
    folder = proof_root / sha
    scene = folder / 'bracken.scn'
    if hashlib.sha256(scene.read_bytes()).hexdigest() != sha:
        raise ValueError('Companion archive hash mismatch')
    proofs.extend(path.relative_to(REPO).as_posix() for path in folder.iterdir() if path.is_file())

paths = ['.gitattributes', 'web'] + inputs + generated + binary_outputs + proofs + [
    EVIDENCE + 'retained_input_completion.json',
    EVIDENCE + 'packaging_input_bytes.json',
    EVIDENCE + 'package_candidate.json',
]
git('add', '--sparse', '-f', '--', *paths)
print(json.dumps({'staged_explicit_paths': len(paths), 'exact_input_pins': pins,
                  'attribute_additions': attribute_paths}))
