"""Prepared source audit. Explicit --ready is required after root's build READY."""
import argparse
import gzip
import hashlib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / 'config.json').read_text())
SHA = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


def child(arguments, label):
    result = subprocess.run(arguments, cwd=ROOT, capture_output=True, text=True, timeout=90)
    (ROOT / (label + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(label + ' failed: ' + result.stdout + result.stderr)
    print(label + ': PASS', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ready', action='store_true', help='Root has confirmed the fresh package is READY; permit the model-free engine audit')
    args = parser.parse_args()
    if not args.ready:
        print(json.dumps({'status': 'PREPARED_NOT_RUN', **CONFIG}, indent=2))
        return 0
    if (ROOT / 'audit.json').exists():
        raise RuntimeError('Existing completed evidence must be retained; use a separate fresh audit directory')
    export = pathlib.Path(CONFIG['export'])
    manifest_path = export / 'release_manifest.json'
    manifest = json.loads(manifest_path.read_text())
    assert manifest['source']['git_commit'] == CONFIG['expected_commit'], 'Wrong package source commit'
    actual_head = subprocess.check_output(['git', '-C', CONFIG['source_repo'], 'rev-parse', 'HEAD'], text=True).strip()
    assert actual_head == CONFIG['expected_commit'], 'Wrong frozen source checkout'
    encoded_path = export / 'index.pck'
    encoded = encoded_path.read_bytes()
    expected = manifest['root_pck']
    assert len(encoded) == expected['bytes'] and SHA(encoded_path) == expected['sha256']
    decoded = gzip.decompress(encoded) if encoded[:2] == b'\x1f\x8b' else encoded
    assert len(decoded) == expected['decoded_bytes'] and hashlib.sha256(decoded).hexdigest() == expected['decoded_sha256']
    decoded_path = ROOT / 'index.raw.pck'
    decoded_path.write_bytes(decoded)
    decode = {'transport': str(encoded_path), 'transport_bytes': len(encoded), 'transport_sha256': SHA(encoded_path),
              'decoded': str(decoded_path), 'decoded_bytes': len(decoded), 'decoded_sha256': SHA(decoded_path)}
    (ROOT / 'decode.json').write_text(json.dumps(decode, indent=2) + '\n')
    prefix = [CONFIG['godot'], '--headless', '--path', str(ROOT)]
    child(prefix + ['--main-pack', str(decoded_path), '--script', str(ROOT / 'inspect_pack_scripts.gd'),
                    '--', '--output', str(ROOT / 'root')], 'extract')
    child(prefix + ['--script', str(ROOT / 'decode_tokens.gd')], 'decode-tokens')
    child([sys.executable, '-B', str(ROOT / 'compare_tokens.py')], 'compare-tokens')
    child(prefix + ['--main-pack', str(decoded_path), '--script', str(ROOT / 'inspect_mounts.gd')], 'mount-hashes')
    comparison = json.loads((ROOT / 'comparison.json').read_text())
    mounts = json.loads((ROOT / 'mounted_hashes.json').read_text())
    assert comparison['status'] == 'PASS' and len(comparison['scripts']) == 7
    assert all(record['frozen_matches_expected_commit_lf'] and record['tokens_match'] and record['indentation_matches']
               for record in comparison['scripts'])
    assert all(record['matches_actual_root'] for record in mounts[1:])
    coordinator = next(record for record in comparison['scripts'] if record['path'] == 'scripts/zone_runtime_coordinator.gd')
    source = (pathlib.Path(CONFIG['source_project']) / coordinator['path']).read_text()
    advance = source.split('func advance_transition() -> void:', 1)[1].split('\nfunc ', 1)[0]
    begin = source.split('func begin_transition(', 1)[1].split('\nfunc ', 1)[0]
    assert '_restoring_source = false' in begin
    primary_probe = advance.index('var grounded: Variant = host._grounded_spawn_position(host.pending_spawn_position)')
    recovery_reset = advance.index('_arrival_recovered = false')
    fallback = advance.index('if grounded == null and (host.zone_transition_frames > 3 or Time.get_ticks_msec() >= _support_deadline_msec):')
    assert primary_probe < recovery_reset < fallback
    assert 'host.zone_transition_frames > 3 or Time.get_ticks_msec() >= _support_deadline_msec' in advance
    assert advance.index('grounded = host._grounded_spawn_position(recovery)') < advance.index('if grounded == null:\n\t\tif Time.get_ticks_msec() >= _support_deadline_msec:')
    receipt = {'status': 'PASS', 'expected_commit': CONFIG['expected_commit'], 'export_root': str(export),
               'build_id': manifest['build_id'], 'release_manifest_sha256': SHA(manifest_path), 'root_pck': decode,
               'script_count': 7, 'compiled_token_count': sum(record['packed_tokens'] for record in comparison['scripts']),
               'statement_indentation_boundaries': sum(record['indentation_boundaries'] for record in comparison['scripts']),
               'comparison': {'path': str(ROOT / 'comparison.json'), 'sha256': SHA(ROOT / 'comparison.json')},
               'pack_override_check': {'path': str(ROOT / 'mounted_hashes.json'), 'sha256': SHA(ROOT / 'mounted_hashes.json')},
               'coordinator_patch': {'compiled_sha256': coordinator['compiled_sha256'], 'frozen_source_sha256': coordinator['frozen_source_sha256'],
                                     'new_reset_arrival_recovered_each_primary_probe_before_fallback': True,
                                     'new_probe_recovery_before_timeout_rollback': True,
                                     'preexisting_restoring_source_reset_at_transition_begin': True},
               'execution': 'FileAccess/map/token inspection only; no models, world, Chrome, save, source import or production edit'}
    (ROOT / 'audit.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('FRESH H1 COMPILED SOURCE AUDIT: PASS; ' + str(ROOT / 'audit.json') + '; sha256=' + SHA(ROOT / 'audit.json'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
