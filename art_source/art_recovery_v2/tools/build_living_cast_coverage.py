"""Index the selected Web PCK closure, never the downloaded authoring library."""
import gzip
import hashlib
import json
from pathlib import Path
import struct
from copy import deepcopy
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs

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


def refresh_rows(rows, previous_rows, packed, selected_inputs, game=GAME):
    previous = {row['id']: row for row in previous_rows}
    result = []
    cache = {}
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
        row = refresh_review(current, old, inputs)
        if 'candidate_motion' in row:
            row['candidate_motion']['present_in_selected_export'] = row['candidate_motion']['path'][6:] in packed
        result.append(row)
    return result


def main():
    web = REPO/'web'
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
            'life_status':'queued','authored':False,'runtime_verified':False,'user_accepted':False})
    environment = []
    for record in roles.get('authored_environment_derivatives',[]):
        path = record.get('path','')
        if path.startswith('res://') and path[6:] in packed:
            environment.append({'id':record['id'],'path':path,'pack_owners':packed[path[6:]],
                'life_status':'queued','authored':False,'runtime_verified':False,'user_accepted':False})
    inventory = []
    for path, owners in sorted(packed.items()):
        if not path.startswith(('assets/','assets_external/','shaders/')):
            continue
        if path.endswith('.remap'):
            path = path[:-6]
        elif path.endswith('.import'):
            path = path[:-7]
        inventory.append({'path':'res://'+path,'pack_owners':sorted(owners)})
    previous = json.loads(OUT.read_text(encoding='utf-8-sig')) if OUT.exists() else {}
    selected_inputs = {'selected_export:release_manifest': digest(release_data),
                       'selected_export:runtime_manifest': digest(runtime_data)}
    cast = refresh_rows(cast, previous.get('cast', []), packed, selected_inputs, GAME)
    environment = refresh_rows(environment, previous.get('environment', []), packed, selected_inputs, GAME)
    result = {'schema_version':1,'id':'living-cast-20261107','scope':'selected_export_runtime_closure',
        'baseline':{'build_id':release['build_id'],'source':release['source'],
            'release_manifest_sha256':digest(release_data),'runtime_manifest_sha256':digest(runtime_data)},
        'policy':'Every listed physical resource is present in the selected Web PCKs. Cast aliases collapse to source identity. Downloaded unused libraries are excluded. Presence is not improvement or user acceptance.',
        'publication_authorized':True,'user_accepted':False,'packs':transport,'cast':cast,'environment':environment,
        'runtime_asset_resources':inventory,
        'coverage_counts':{'packs':len(transport),'cast':len(cast),'environment_derivatives':len(environment),'physical_asset_resources':len(inventory)},
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
    for old in previous.get('compiled_additions', []):
        current = {'id': old['id'], 'path': old['path'], 'authored': False,
                   'runtime_verified': False, 'user_accepted': False}
        paths = [old['path']] + [path for path in old.get('verification_inputs', {}) if path.startswith('res://')]
        inputs = resource_inputs(GAME, paths)
        inputs.update(selected_inputs)
        record = refresh_review(current, old, inputs)
        record['present_in_selected_export'] = record['path'][6:] in packed
        additions.append(record)
    if 'compiled_additions' in previous:
        result['compiled_additions'] = additions
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['coverage_counts']))


if __name__=='__main__':
    main()
