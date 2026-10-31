"""Publish the exact user-authorized roster inputs, without claiming acceptance."""

import hashlib
import json
import shutil
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
ART = REPO / 'art_source/art_recovery_v2'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def main():
    gate = read(ART / 'quality_gate.json')
    if gate.get('status') != 'user_authorized_candidate_publication' or gate.get('publication_authorized') is not True:
        raise ValueError('Explicit user candidate-publication authorization is required')
    ledger = read(ART / 'stylized_roster.json')
    rows = {row['id']: row for row in ledger['assets']}
    required = {'P01', *(f'C{i:02}' for i in range(1, 13)), *(f'M{i:02}' for i in range(1, 21))}
    if set(rows) != required or len(ledger['assets']) != 33:
        raise ValueError('Require all 33 current candidates')
    designs = read(PROJECT / 'data/design_pack_assets.json')
    runtime = read(PROJECT / 'runtime_asset_manifest.json')
    copies = {}
    resources = {}
    for asset_id, row in rows.items():
        destination = designs['assets'][asset_id]['path']
        if destination != row['destination_resource']:
            raise ValueError(f'Changed actor identity: {asset_id}')
        files = [(row['runtime_path'], destination, row['runtime'])]
        files += [(t['source_path'], t['runtime_path'], t) for t in row.get('textures', [])]
        resources[asset_id] = []
        for source, resource, identity in files:
            source = Path(source).resolve(strict=True)
            target = (PROJECT / resource.removeprefix('res://')).resolve()
            if not source.is_relative_to(REPO) or not target.is_relative_to(PROJECT / 'assets_external/design_pack_v1'):
                raise ValueError(f'Asset path escapes its owner: {resource}')
            with source.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            size = source.stat().st_size
            if digest != identity['sha256'] or size != identity['bytes']:
                raise ValueError(f'Candidate input changed: {asset_id}: {source}')
            previous = copies.get(target)
            if previous and previous != source:
                raise ValueError(f'Conflicting material owner: {resource}')
            copies[target] = source
            resources[asset_id].append(dict(path=resource, bytes=size, sha256=digest))
    # Validate every input before replacing any production source file.
    for target, source in copies.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for asset_id, row in rows.items():
        record = designs['assets'][asset_id]
        if 'blender_report' in record:
            record['baseline_blender_report'] = record.pop('blender_report')
        record.update(bytes=row['runtime']['bytes'], sha256=row['runtime']['sha256'],
                      authored_bind_bounds=row['authored_bind_bounds'],
                      private_review_only=False, user_accepted=False,
                      candidate_source_path=row['source_path'],
                      status='user_authorized_release_candidate')
    for role, asset_id in designs['roles'].items():
        runtime['roles'][role].update(runtime_files=resources[asset_id],
            inclusion_authorized=True, authorization_kind='user_requested_live_roster_release',
            approved=False, visual_reviewed=False, user_accepted=False,
            private_review_only=False, runtime_acceptance='unverified',
            status='user_authorized_release_candidate')
    designs.update(private_review_only=False, runtime_acceptance='unverified')
    runtime.update(private_review_only=False, status='user_authorized_release_candidate')
    write(PROJECT / 'data/design_pack_assets.json', designs)
    write(PROJECT / 'runtime_asset_manifest.json', runtime)
    print(f'Integrated {len(rows)} candidates and {len(copies)} exact resource files; user acceptance remains unverified')


if __name__ == '__main__':
    main()
