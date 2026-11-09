"""Index the selected Web PCK closure, never the downloaded authoring library."""
import gzip
import hashlib
import json
from pathlib import Path
import struct
import argparse
from copy import deepcopy
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs
from living_asset_coverage import apply_unit, current_authored_units, current_creature_candidates, current_scenery_units, flatten_environment, normalized_resources

REPO = Path(__file__).resolve().parents[3]
GAME = REPO / 'outputs/AshenOathTheRoadBetweenCrowns'
OUT = GAME / 'release_reports/living_cast_20261107/asset_coverage.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(name):
    return json.loads((GAME/name).read_text(encoding='utf-8-sig'))


def pck_paths(data):
    if data.startswith(b'\x1f\x8b'):
        data = gzip.decompress(data)
    if data[:4] != b'GDPC' or struct.unpack_from('<I',data,4)[0] != 3:
        raise ValueError('Expected the current version-3 Godot PCK')
    directory = struct.unpack_from('<Q',data,32)[0]
    count = struct.unpack_from('<I',data,directory)[0]
    cursor = directory+4
    result = []
    for _ in range(count):
        size = struct.unpack_from('<I',data,cursor)[0]
        cursor += 4
        path = data[cursor:cursor+size].rstrip(b'\0').decode('utf-8')
        cursor += size+36
        result.append(path)
    if cursor != len(data):
        raise ValueError('PCK directory length mismatch')
    return result


def refresh_rows(rows, previous_rows, packed, selected_inputs, game=GAME, units=None):
    previous = {row['id']: row for row in previous_rows}
    result = []
    cache = {}
    selected_paths = {row['path'] for row in normalized_resources(packed, assets_only=False)}
    for current in rows:
        old = previous.get(current['id'], {})
        paths = list(current.get('compiled_resources', []))
        paths += [path for path in old.get('verification_inputs', {}) if path.startswith('res://')]
        paths += [current.get('source', current.get('path', ''))]
        candidate = old.get('candidate_motion', {})
        if candidate.get('path'):
            paths.append(candidate['path'])
        inputs = resource_inputs(game, [path for path in paths if path], cache)
        inputs.update(selected_inputs)
        unit = (units or {}).get(current['id'])
        if unit:
            inputs.update(unit['inputs'])
        row = refresh_review(current, old, inputs)
        if unit:
            row = apply_unit(row, unit, selected_paths)
        if 'candidate_motion' in row:
            row['candidate_motion']['present_in_selected_export'] = row['candidate_motion']['path'] in selected_paths
        result.append(row)
    return result


def main(web_root=None):
    web = Path(web_root) if web_root is not None else REPO/'web'
    release_data = (web/'release_manifest.json').read_bytes()
    release = json.loads(release_data)
    runtime_data = (web/'runtime_pack_manifest.json').read_bytes()
    runtime = json.loads(runtime_data)
    packed = {}
    transport = []
    for artifact in release['artifacts']:
        if not artifact['path'].endswith('.pck'):
            continue
        data = (web/artifact['path']).read_bytes()
        if digest(data) != artifact['sha256'] or len(data) != artifact['bytes']:
            raise ValueError('Selected export differs: '+artifact['path'])
        owner = 'base' if artifact['path']=='index.pck' else Path(artifact['path']).stem
        paths = pck_paths(data)
        for path in paths:
            packed.setdefault(path,[]).append(owner)
        transport.append({'id':owner,'path':artifact['path'],'sha256':artifact['sha256'],'entries':len(paths)})
    designs = read('data/design_pack_assets.json')['assets']
    catalog = read('data/prepared_actors.json')
    roles = read('runtime_asset_manifest.json')
    cast = []
    for asset,record in designs.items():
        compiled = sorted({v['path'] for v in catalog.values() if v['source']==record['path']})
        actual = [p for p in compiled if p[6:] in packed]
        if not actual:
            raise ValueError('Current cast has no selected prepared resource: '+asset)
        aliases = sorted(k for k,v in roles['roles'].items() if v.get('design_id')==asset)
        cast.append({'id':asset,'source':record['path'],'source_sha256':digest((GAME/record['path'][6:]).read_bytes()),
            'roles':aliases,'compiled_resources':actual,'pack_owners':sorted({o for p in actual for o in packed[p[6:]]}),
            'life_status':'queued','authored':False,'runtime_verified':False,'native_verified':False,
            'visual_accepted':False,'in_level_accepted':False,'performance_verified':False,'user_accepted':False})
    selected = {row['path']: row['pack_owners'] for row in normalized_resources(packed, assets_only=False)}
    environment = []
    for record in flatten_environment(roles.get('authored_environment_derivatives',[]), selected):
        environment.append({'id':record['id'],'path':record['path'],'pack_owners':record['pack_owners'],
            **{key: record[key] for key in ('group_id','variant','declared_pack_owner') if key in record},
            'life_status':'queued','authored':False,'runtime_verified':False,'native_verified':False,
            'visual_accepted':False,'in_level_accepted':False,'performance_verified':False,'user_accepted':False})
    inventory = normalized_resources(packed)
    previous = json.loads(OUT.read_text(encoding='utf-8-sig')) if OUT.exists() else {}
    selected_inputs = {'selected_export:release_manifest': digest(release_data),
                       'selected_export:runtime_manifest': digest(runtime_data)}
    units, prop_units = current_authored_units(REPO, GAME)
    units.update(current_creature_candidates(REPO,GAME))
    cast = refresh_rows(cast, previous.get('cast', []), packed, selected_inputs, GAME, units)
    environment = refresh_rows(environment, previous.get('environment', []), packed, selected_inputs, GAME, current_scenery_units(REPO,GAME))
    result = {'schema_version':1,'id':'living-cast-20261107','scope':'selected_export_runtime_closure',
        'baseline':{'build_id':release['build_id'],'source':release['source'],
            'release_manifest_sha256':digest(release_data),'runtime_manifest_sha256':digest(runtime_data)},
        'policy':'Every listed physical resource is present in the selected Web PCKs. Cast aliases collapse to source identity. Downloaded unused libraries are excluded. Presence is not improvement or user acceptance.',
        'publication_authorized':True,'user_accepted':False,'packs':transport,'cast':cast,'environment':environment,
        'runtime_asset_resources':inventory,
        'coverage_counts':{'packs':len(transport),'cast':len(cast),'environment_derivatives':len(environment),
            'physical_asset_resources':len(inventory),'normalized_unique_resources':len(inventory),
            'selected_asset_file_entries':sum(len(row['packed_paths']) for row in inventory)},
        'additional_review_groups':['held_equipment_and_props','foliage_water_and_weather','combat_effects','audio','interface_art'],
        'notes':['Coverage records the selected local Web export, not a claim about current provider deployment.',
                 'Non-cast physical resources remain queued until assigned per-asset review evidence; shared textures count as dependencies rather than a separate animation requirement.']}
    # Independent top-level notes and audit/history survive an inventory refresh.
    for key, value in previous.items():
        if key not in result:
            result[key] = deepcopy(value)
    result['notes'] = list(dict.fromkeys(previous.get('notes', []) + result['notes']))
    removed = result.setdefault('removed_from_runtime_scope', {})
    for category in ['cast', 'environment']:
        removed[category] = preserve_removed(previous.get(category, []), result[category], removed.get(category, []))
    additions = []
    old_additions = {row['id']:row for row in previous.get('compiled_additions', [])}
    props = {row['id']:row for row in prop_units}
    for identity in sorted(set(old_additions) | set(props)):
        old = old_additions.get(identity, {})
        template = old_additions.get(identity, props.get(identity))
        current = {'id': identity, 'path': template['path'], 'authored': False,
                   'runtime_verified': False, 'user_accepted': False}
        paths = [current['path']] + [path for path in old.get('verification_inputs', {}) if path.startswith('res://')]
        inputs = resource_inputs(GAME, paths)
        inputs.update(selected_inputs)
        if identity in props:
            inputs.update(props[identity]['verification_inputs'])
        record = refresh_review(current, old, inputs)
        if identity in props:
            record.update({key:deepcopy(value) for key,value in props[identity].items() if key not in ('verification_inputs','runtime_verified','user_accepted','visual_accepted','in_level_accepted','performance_verified')})
        record['present_in_selected_export'] = record['path'] in selected
        record['actual_selected_pack_owners']=selected.get(record['path'],[])
        additions.append(record)
    if additions or 'compiled_additions' in previous:
        result['compiled_additions'] = additions
    result['current_authoring_counts'] = {'compiled_human_libraries':sum(bool(row.get('authored')) for row in cast if row['id'].startswith(('C','P'))),
        'native_motion_verified_libraries':sum(bool(row.get('native_verified')) for row in cast if row['id'].startswith(('C','P'))),
        'compiled_prop_units':sum(bool(row.get('authored')) for row in additions),
        'authored_creature_candidates':sum(bool(row.get('authored')) for row in cast if row['id'].startswith('M')),
        'native_current_creature_candidates':sum(bool(row.get('native_verified')) for row in cast if row['id'].startswith('M')),
        'in_level_accepted':sum(bool(row.get('in_level_accepted')) for row in cast+environment+additions),
        'user_accepted':sum(bool(row.get('user_accepted')) for row in cast+environment+additions)}
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['coverage_counts']))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web-root',type=Path,help='Exact selected export directory; its manifests and every pack are verified read-only')
    main(parser.parse_args().web_root)
