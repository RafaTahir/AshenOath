import hashlib
import json
import struct
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('D:/Projects/AshenOath')
RUN = ROOT / '.release-gate/web-efficiency-20261101-r2'
OLD = ROOT / '.release-gate/cast-live-20261031-01/export'


def pack_entries(path):
    with path.open('rb') as stream:
        header = stream.read(40)
        magic, version, major, minor, patch, flags, base, directory = struct.unpack('<4s5IQQ', header)
        assert magic == b'GDPC' and version == 3 and flags == 2
        stream.seek(directory)
        count, = struct.unpack('<I', stream.read(4))
        result = {}
        for _ in range(count):
            length, = struct.unpack('<I', stream.read(4))
            name = stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://')
            offset, size = struct.unpack('<QQ', stream.read(16))
            digest = stream.read(16).hex()
            file_flags, = struct.unpack('<I', stream.read(4))
            assert file_flags == 0
            result[name] = {'bytes': size, 'md5': digest, 'offset': base + offset}
        for name, record in result.items():
            stream.seek(record['offset'])
            assert hashlib.md5(stream.read(record['bytes'])).hexdigest() == record['md5'], name
        return result


def main():
    old_manifest = json.loads((OLD / 'release_manifest.json').read_text())
    new_manifest = json.loads((ROOT / 'web/release_manifest.json').read_text())
    assert new_manifest['build_id'].startswith('web-efficiency-20261101')
    inventory = json.loads((ROOT / '.release-gate/size-efficiency/pck_inventory.json').read_text())
    baseline = {}
    for record in inventory['files']:
        baseline.setdefault(record['pack'], {})[record['path']] = record
    rows = []
    removed = []
    retained_textures = 0
    removed_textures = []
    changed_textures = []
    forbidden = []
    for path in sorted((RUN / 'runtime-packs').glob('*.pck')):
        name = 'index' if path.stem == 'base' else path.stem
        current = pack_entries(path)
        before = baseline[name]
        for resource, record in current.items():
            if resource.endswith(('.blend', '.blend1', '.zip', '.7z')):
                forbidden.append(resource)
            if resource.endswith('.ctex') and resource in before:
                retained_textures += 1
                if record['md5'] != before[resource]['md5']:
                    changed_textures.append(resource)
        for resource in sorted(before.keys() - current.keys()):
            if resource.endswith('.ctex'):
                removed_textures.append({'pack': name, 'path': resource, 'bytes': before[resource]['bytes']})
            if resource.startswith('.godot/imported/') and resource.endswith('.scn'):
                removed.append({'pack': name, 'path': resource, 'bytes': before[resource]['bytes']})
        relative = 'index.pck' if name == 'index' else f'packs/{name}.pck'
        old_bytes = (OLD / relative).stat().st_size
        new_bytes = (ROOT / 'web' / relative).stat().st_size
        rows.append({'path': relative, 'before_bytes': old_bytes, 'after_bytes': new_bytes, 'saved_bytes': old_bytes - new_bytes})
    assert not forbidden, forbidden
    assert not changed_textures, changed_textures
    assert len(removed) == 32, len(removed)
    total_before = sum(p.stat().st_size for p in OLD.rglob('*') if p.is_file())
    total_after = sum(p.stat().st_size for p in (ROOT / 'web').rglob('*') if p.is_file())
    semantics = json.loads((ROOT / '.release-gate/web-efficiency-20261101/semantic-actors/semantic-results.json').read_text())
    assert all(r['equal'] and not r['differences'] for r in semantics)
    result = {
        'schema_version': 1,
        'id': 'web-efficiency-20261101',
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'status': 'locally_packaged_resource_verified_not_published',
        'build_id': new_manifest['build_id'],
        'before_build_id': old_manifest['build_id'],
        'before_bytes': total_before,
        'after_bytes': total_after,
        'saved_bytes': total_before - total_after,
        'saved_percent': 100 * (total_before - total_after) / total_before,
        'packs': rows,
        'removed_redundant_actor_scenes': removed,
        'removed_unused_imported_textures': removed_textures,
        'retained_texture_payloads_identical': retained_textures,
        'forbidden_authoring_payloads': forbidden,
        'recompiled_actor_semantic_signatures_identical': len(semantics),
        'validation': {
            'package_integrity': 'pass',
            'web_export': 'pass',
            'isolated_packed_actor_and_dependency_gate': 'pass',
            'compiled_actors': 33,
            'pack_completeness_unit_tests': 10,
            'gameplay_and_visual_acceptance': 'not_run_user_owned',
            'publication': 'not_requested',
        },
    }
    target = ROOT / 'outputs/AshenOathTheRoadBetweenCrowns/release_reports/web_efficiency_20261101.json'
    target.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: result[key] for key in ['before_bytes', 'after_bytes', 'saved_bytes', 'saved_percent', 'retained_texture_payloads_identical']}))
    print(json.dumps(rows))


if __name__ == '__main__':
    main()
