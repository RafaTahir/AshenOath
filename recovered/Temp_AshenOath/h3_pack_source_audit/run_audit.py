"""Config-driven model-free package source audit; --ready explicitly permits engine children."""
import argparse
import gzip
import hashlib
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / 'config.json').read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def child(arguments, label):
    # Never inherit the real user's application-data or temporary directories.
    environment = os.environ.copy()
    for key, leaf in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local'), ('TEMP', 'temp'), ('TMP', 'temp')]:
        destination = ROOT / 'profile' / leaf
        destination.mkdir(parents=True, exist_ok=True)
        environment[key] = str(destination)
    result = subprocess.run(arguments, cwd=ROOT, env=environment, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
    (ROOT / (label + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(label + ' failed: ' + result.stdout + result.stderr)
    print(label + ': PASS', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ready', action='store_true', help='Root has released the engine slot and authorized this resource-only audit')
    args = parser.parse_args()
    if not args.ready:
        print(json.dumps({'status': 'PREPARED_NOT_RUN', **CONFIG}, indent=2))
        return 0
    if (ROOT / 'audit.json').exists():
        raise RuntimeError('Preserve completed evidence; use a fresh audit directory')
    export = pathlib.Path(CONFIG['export'])
    project = pathlib.Path(CONFIG['source_project'])
    prefix = project.relative_to(pathlib.Path(CONFIG['source_repo'])).as_posix()
    manifest_path = export / 'release_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    assert manifest['source']['git_commit'] == CONFIG['expected_commit'], 'Wrong package source commit'
    head = subprocess.check_output(['git', '-C', CONFIG['source_repo'], 'rev-parse', 'HEAD'], text=True).strip()
    assert head == CONFIG['expected_commit'], 'Wrong frozen source checkout'
    assert CONFIG['scripts'] and len(CONFIG['scripts']) == len(set(CONFIG['scripts']))
    encoded_path = export / 'index.pck'
    encoded = encoded_path.read_bytes()
    expected = manifest['root_pck']
    assert len(encoded) == expected['bytes'] and digest(encoded_path) == expected['sha256']
    decoded = gzip.decompress(encoded) if encoded[:2] == b'\x1f\x8b' else encoded
    assert len(decoded) == expected['decoded_bytes'] and hashlib.sha256(decoded).hexdigest() == expected['decoded_sha256']
    decoded_path = ROOT / 'index.raw.pck'
    decoded_path.write_bytes(decoded)
    decode = {'transport': str(encoded_path), 'transport_bytes': len(encoded), 'transport_sha256': digest(encoded_path),
              'decoded': str(decoded_path), 'decoded_bytes': len(decoded), 'decoded_sha256': digest(decoded_path)}
    (ROOT / 'decode.json').write_text(json.dumps(decode, indent=2) + '\n')
    raw_records = []
    pack_manifest = {pack['id']: pack for pack in manifest['packs']}
    for pack_id in CONFIG['packs']:
        path = pathlib.Path(CONFIG['raw_packs']) / (pack_id + '.pck')
        record = {'id': pack_id, 'path': str(path), 'bytes': path.stat().st_size, 'sha256': digest(path)}
        if not pack_manifest[pack_id].get('embedded', False):
            assert record['bytes'] == pack_manifest[pack_id]['bytes'] and record['sha256'] == pack_manifest[pack_id]['sha256'], 'Raw pack does not match actual candidate: ' + pack_id
        raw_records.append(record)
    engine = [CONFIG['godot'], '--headless', '--path', str(ROOT)]
    configuration = ['--', '--config', str(ROOT / 'config.json')]
    child(engine + ['--main-pack', str(decoded_path), '--script', str(ROOT / 'inspect_pack_scripts.gd')] + configuration, 'extract')
    child(engine + ['--script', str(ROOT / 'decode_tokens.gd')] + configuration, 'decode-tokens')
    child([sys.executable, '-B', str(ROOT / 'compare_tokens.py')], 'compare-tokens')
    child(engine + ['--main-pack', str(decoded_path), '--script', str(ROOT / 'inspect_mounts.gd')] + configuration, 'mount-hashes')
    comparison = json.loads((ROOT / 'comparison.json').read_text(encoding="utf-8-sig"))
    mounts = json.loads((ROOT / 'mounted_hashes.json').read_text(encoding="utf-8-sig"))
    assert comparison['status'] == 'PASS' and len(comparison['scripts']) == len(CONFIG['scripts'])
    assert all(record['frozen_matches_expected_commit_lf'] and record['tokens_match'] and record['indentation_matches'] for record in comparison['scripts'])
    assert len(mounts) == 1 + len(CONFIG['packs']) and all(record['matches_actual_root'] for record in mounts[1:])
    resources = []
    for relative in CONFIG.get('resources', []):
        packed = ROOT / 'root' / relative
        frozen = project / relative
        original = subprocess.check_output(['git', '-C', CONFIG['source_repo'], 'show', CONFIG['expected_commit'] + ':' + prefix + '/' + relative])
        assert packed.read_bytes() == frozen.read_bytes(), 'Packed data differs from frozen bytes: ' + relative
        assert frozen.read_bytes().replace(b'\r\n', b'\n') == original.replace(b'\r\n', b'\n'), 'Frozen data differs from Git commit: ' + relative
        resources.append({'path': relative, 'sha256': digest(packed), 'packed_matches_frozen_bytes': True, 'frozen_matches_expected_commit_lf': True})
    receipt = {'status': 'PASS', 'label': CONFIG.get('label', ''), 'expected_commit': CONFIG['expected_commit'],
               'export_root': str(export), 'build_id': manifest['build_id'], 'release_manifest_sha256': digest(manifest_path), 'root_pck': decode,
               'script_count': len(CONFIG['scripts']), 'compiled_token_count': sum(record['packed_tokens'] for record in comparison['scripts']),
               'statement_indentation_boundaries': sum(record['indentation_boundaries'] for record in comparison['scripts']),
               'comparison': {'path': str(ROOT / 'comparison.json'), 'sha256': digest(ROOT / 'comparison.json')},
               'pack_override_check': {'path': str(ROOT / 'mounted_hashes.json'), 'sha256': digest(ROOT / 'mounted_hashes.json'), 'pack_count': len(CONFIG['packs'])},
               'raw_packs': raw_records, 'data_resources': resources, 'isolated_child_profile': str(ROOT / 'profile'),
               'execution': 'FileAccess/map/token inspection only; no models, world, browser, save, source import or production edit'}
    (ROOT / 'audit.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('COMPILED SOURCE AUDIT: PASS; ' + str(ROOT / 'audit.json') + '; sha256=' + digest(ROOT / 'audit.json'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
