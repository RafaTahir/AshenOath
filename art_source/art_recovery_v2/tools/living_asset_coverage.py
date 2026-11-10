"""Current coverage over selected resources and immutable authoring receipts.

This is a view of existing evidence, never a replacement inventory or a producer
of historical receipts. A passing source/native contract is not level acceptance.
"""
from copy import deepcopy
import hashlib
import json
from pathlib import Path

SCENERY_SPLITS = {'road_checkpoint':'checkpoint_cloth', 'marsh_landscape':'marsh_reeds',
                  'hart_fitted_woodland':'hart_ferns', 'ash_mill_architecture':'ash_mill_wheel'}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).is_file() else None


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def resource_path(value):
    if not isinstance(value, str) or not value.startswith('res://'):
        raise ValueError('Expected an exact resource path: ' + str(value))
    local = value[6:]
    if not local or '\\' in local or local.startswith('/') or ':' in local or any(p in ('', '.', '..') for p in local.split('/')):
        raise ValueError('Resource path escapes or is not canonical: ' + value)
    return value


def normalized_resources(packed, assets_only=True):
    """Merge import/remap aliases by resource, retaining actual packed paths."""
    result = {}
    for path, owners in packed.items():
        path = path[6:] if path.startswith('res://') else path
        resource_path('res://' + path)
        if assets_only and not path.startswith(('assets/', 'assets_external/', 'shaders/')):
            continue
        normal = path[:-6] if path.endswith('.remap') else (path[:-7] if path.endswith('.import') else path)
        key = resource_path('res://' + normal)
        if not isinstance(owners, (list, tuple, set)) or not owners or any(not isinstance(v, str) or not v for v in owners):
            raise ValueError('Missing selected resource ownership: ' + path)
        row = result.setdefault(key, {'path': key, 'pack_owners': set(), 'packed_paths': set()})
        row['pack_owners'].update(owners)
        row['packed_paths'].add(path)
    return [{'path': row['path'], 'pack_owners': sorted(row['pack_owners']), 'packed_paths': sorted(row['packed_paths'])}
            for _, row in sorted(result.items())]


def flatten_environment(records, selected=None):
    """Flatten grouped authored variants, preserving parent provenance/owner."""
    rows, ids, paths = [], set(), set()
    for parent in records:
        if not isinstance(parent, dict) or not isinstance(parent.get('id'), str) or not parent['id']:
            raise ValueError('Malformed authored environment identity')
        candidates = []
        if 'path' in parent:
            candidates.append({k: deepcopy(v) for k, v in parent.items() if k != 'assets'})
        if 'assets' in parent:
            if not isinstance(parent['assets'], list) or not parent['assets']:
                raise ValueError('Malformed authored environment group: ' + parent['id'])
            for child in parent['assets']:
                if not isinstance(child, dict) or 'assets' in child or not isinstance(child.get('variant'), str) or not child['variant']:
                    raise ValueError('Malformed authored environment variant: ' + parent['id'])
                merged = {k: deepcopy(v) for k, v in parent.items() if k not in ('assets', 'path')}
                merged.update(deepcopy(child))
                merged['id'] = child.get('id', parent['id'] + '_' + child['variant'])
                merged['group_id'] = parent['id']
                candidates.append(merged)
        if not candidates:
            raise ValueError('Authored environment has no resource: ' + parent['id'])
        for row in candidates:
            identity = row['id']
            path = resource_path(row.get('path'))
            if not isinstance(identity, str) or not identity or identity in ids or path in paths:
                raise ValueError('Duplicate authored environment identity/path: ' + str(identity))
            ids.add(identity); paths.add(path)
            if selected is not None:
                if path not in selected:
                    continue
                row['declared_pack_owner'] = row.get('pack_owner')
                row['pack_owners'] = sorted(set(selected[path]))
                row['pack_owner'] = row['pack_owners'][0] if len(row['pack_owners']) == 1 else None
            rows.append(row)
    return rows


def resolve(repo, game, value):
    """Resolve copied provenance into this checkout; never overwrite its source."""
    repo, game = Path(repo).resolve(), Path(game).resolve()
    text = str(value).replace('\\', '/')
    if text.startswith('res://'):
        return game / resource_path(text)[6:]
    for marker in ('art_source/', 'outputs/AshenOathTheRoadBetweenCrowns/'):
        if marker in text:
            local = text[text.index(marker):]
            result = (repo / local).resolve()
            if not result.is_relative_to(repo):
                raise ValueError('Provenance escapes checkout: ' + text)
            return result
    result = (repo / text).resolve() if not Path(text).is_absolute() else Path(text).resolve()
    if not result.is_relative_to(repo):
        raise ValueError('Unbound external evidence path: ' + text)
    return result


def input_key(repo, game, path):
    path, repo, game = Path(path).resolve(), Path(repo).resolve(), Path(game).resolve()
    if path.is_relative_to(game):
        return 'res://' + path.relative_to(game).as_posix()
    if path.is_relative_to(repo):
        return 'repo://' + path.relative_to(repo).as_posix()
    raise ValueError('Coverage evidence must belong to this checkout')


def bind(repo, game, inputs, errors, path, expected=None):
    path = Path(path)
    actual = digest(path)
    inputs[input_key(repo, game, path)] = actual
    if actual is None or (expected is not None and actual != expected):
        errors.append({'path': input_key(repo, game, path), 'expected': expected, 'actual': actual})
    return actual


def native_motion_evidence(repo, game):
    path = Path(repo) / 'art_source/art_recovery_v2/evidence/living_cast_stage2_20261107/native_reviews/native_work_phase_20261110_r2/receipt.json'
    inputs, errors = {}, []
    if not path.is_file():
        return {'verified': False, 'inputs': inputs, 'errors': [], 'recorded_pass': False}
    data = read(path)
    bind(repo, game, inputs, errors, path)
    for relative, expected in data.get('input_sha256', {}).items():
        bind(repo, game, inputs, errors, Path(game) / relative, expected)
    good = data.get('accepted') is True and bool(data.get('input_sha256')) and bool(data.get('results'))
    good &= all(row.get('accepted') is True and row.get('exit_code') == 0 and not row.get('timeout') and not row.get('errors') for row in data.get('results', []))
    motion = [row for row in data.get('results',[]) if row.get('fixture')=='verify_living_cast_motion.gd']
    named = data.get('scope',{}).get('roles')=='all_twelve_named_cast' and any('--motion-only' in row.get('command',[]) and '--skip-player' in row.get('command',[]) and not any(str(arg).startswith('--roles') for arg in row.get('command',[])) for row in motion)
    player = any('--player-only' in row.get('command',[]) for row in motion)
    return {'verified': bool(good and not errors), 'recorded_pass': bool(good), 'inputs': inputs, 'errors': errors,
            'receipt': str(path.relative_to(repo).as_posix()), 'scope': deepcopy(data.get('scope', {})),
            'covers_named_cast':bool(named),'covers_player':bool(player)}


def current_authored_units(repo, game):
    """Bind completed libraries/props to their actual retained source/output."""
    repo, game = Path(repo), Path(game)
    art = repo / 'art_source/art_recovery_v2'
    models = art / 'models'
    native = native_motion_evidence(repo, game)
    cast, additions = {}, []
    receipts = [models / 'living_cast_20261107/library_compile_C01_C04_C03_C02.json']
    receipts += sorted((models / 'living_cast_stage2_20261107').glob('library_compile_C*.json'))
    receipts += [models / 'living_assets_stage3_20261107/player/library_compile_P01.json']
    for receipt in receipts:
        if not receipt.is_file():
            continue
        data = read(receipt)
        for unit in data.get('libraries', []):
            identity = unit['asset']
            if identity in cast:
                raise ValueError('Duplicate current library receipt: ' + identity)
            inputs, errors = {}, []
            bind(repo, game, inputs, errors, receipt)
            source = resolve(repo, game, unit['source'])
            bind(repo, game, inputs, errors, source, unit['source_sha256'])
            bind(repo, game, inputs, errors, game / resource_path(unit['path'])[6:], unit['sha256'])
            bind(repo, game, inputs, errors, game / resource_path(unit['model'])[6:], unit['model_sha256'])
            contract = receipt.parent / identity / 'source_verification.json'
            bind(repo, game, inputs, errors, contract)
            checked = read(contract) if contract.is_file() else {}
            contract_ok = checked.get('status') == 'source_contract_pass' and checked.get('review_glb_sha256') == unit['source_sha256']
            retained = checked.get('retained_production_sha256', checked.get('production_sha256'))
            contract_ok &= retained == unit['model_sha256']
            authored = not errors and contract_ok and data.get('status') == 'compiled'
            covered = native.get('covers_player',False) if identity=='P01' else native.get('covers_named_cast',False)
            native_current = bool(authored and covered and native['verified'] and native['inputs'].get(unit['path']) == unit['sha256'])
            # Bind the whole fixture scope, not just the unchanged library filename.
            inputs.update(native['inputs'])
            cast[identity] = {'authored': bool(authored), 'native_verified': native_current, 'inputs': inputs,
                'errors': errors + ([] if contract_ok else [{'error': 'Source contract does not bind compiled source'}]),
                'candidate_motion': {**{key: deepcopy(unit[key]) for key in ('path', 'sha256', 'bytes', 'source_sha256')},
                    'expected_pack_owner':'actor_'+identity.lower(),'current_bytes_verified_in_selected_export':False},
                'clips': list(unit.get('clips', {})), 'compile_receipt': receipt.relative_to(repo).as_posix(),
                'native_test': {key: deepcopy(native[key]) for key in ('receipt', 'scope', 'recorded_pass', 'errors') if key in native},
                'native_scope': 'Retained native motion/contacts and interruption; equipment matrix and actual-level review remain separate.'}
    satchel_archive = art/'evidence/living_cast_stage2_20261107/retained_props/satchel_compiler_20261107_060919_r1'
    satchel_receipt = satchel_archive/'satchel_compile.json' if (satchel_archive/'archive_manifest.json').is_file() else models/'living_cast_20261107/props/satchel_compile.json'
    prop_receipts = [satchel_receipt]
    prop_receipts += sorted((models / 'living_cast_stage2_20261107/props').glob('*_compile.json'))
    for receipt in prop_receipts:
        if not receipt.is_file():
            continue
        unit = read(receipt)
        inputs, errors = {}, []
        bind(repo, game, inputs, errors, receipt)
        if receipt.parent==satchel_archive:
            archive_path=satchel_archive/'archive_manifest.json'
            archive=read(archive_path)
            bind(repo,game,inputs,errors,archive_path)
            if archive.get('verified_exact_source_and_output_bytes') is not True or archive.get('recompiled') is not False:
                errors.append({'error':'Satchel archival provenance is incomplete'})
            for item in archive.get('files',[]):
                path=(satchel_archive/item['path']).resolve()
                if not path.is_relative_to(satchel_archive.resolve()):raise ValueError('Satchel evidence escapes archive')
                bind(repo,game,inputs,errors,path,item['sha256'])
            historical=archive.get('historical_receipt',{})
            bind(repo,game,inputs,errors,resolve(repo,game,historical['path']),historical['sha256'])
        bind(repo, game, inputs, errors, game / resource_path(unit['path'])[6:], unit['sha256'])
        for child in unit.get('resources', []):
            bind(repo, game, inputs, errors, game / resource_path(child['path'])[6:], child['sha256'])
        name = Path(unit['path']).stem
        if name == 'rook_station_satchel':
            authoring = models/'living_cast_20261107/props/satchel_authoring.json'
            authored = read(authoring) if authoring.is_file() else {}
            carrier = resolve(repo, game, authored.get('carrier', str(authoring.with_suffix('.glb'))))
        elif name == 'merrow_cup':
            authoring = resolve(repo, game, unit['calibration_archive'])
            authored = read(authoring) if authoring.is_file() else {}
            carrier = receipt.parent / 'merrow_cup_world.glb'
        else:
            authoring = receipt.parent / (name + '_authoring.json')
            authored = read(authoring) if authoring.is_file() else {}
            carrier = receipt.parent / (name + '.glb')
        bind(repo, game, inputs, errors, authoring, unit.get('calibration_sha256'))
        bind(repo, game, inputs, errors, carrier, unit.get('source_sha256', authored.get('carrier_sha256')))
        native_current = not errors and native.get('covers_named_cast',False) and native['verified'] and native['inputs'].get(unit['path']) == unit['sha256']
        inputs.update(native['inputs'])
        additions.append({'id': name, 'path': unit['path'], 'sha256': unit['sha256'], 'authored': not errors,
                          'native_verified': bool(native_current), 'runtime_verified': False, 'user_accepted': False,
                          'visual_accepted': False, 'in_level_accepted': False, 'performance_verified': False,
                          'compile_receipt': receipt.relative_to(repo).as_posix(), 'verification_inputs': inputs,
                          'expected_pack_owner':{'rook_station_satchel':'actor_c02','merrow_cup':'actor_c10','station_nessa':'actor_c11',
                              'station_elna':'actor_c05','station_toma':'actor_c06','station_nera':'actor_c12','station_vale':'actor_c09',
                              'station_merrow':'actor_c10','station_edric':'actor_c08'}.get(name),
                          'current_bytes_verified_in_selected_export':False,
                          'current_authoring_errors': errors,
                          'native_test':{'recorded_pass':native['recorded_pass'], 'inputs_current':native['verified'],
                              'current_output_matches_tested_bytes':native['inputs'].get(unit['path'])==digest(game/unit['path'][6:]),
                              'receipt':native.get('receipt'), 'scope':deepcopy(native.get('scope',{}))},
                          'native_scope': 'Supported prop geometry and matching native motion fixture; no actual-level review.'})
    return cast, additions


def apply_unit(row, unit, selected):
    """Promote only independently revalidated source/native scopes."""
    result = deepcopy(row)
    result['authored'] = bool(unit['authored'])
    result['native_verified'] = bool(unit['native_verified'])
    result['current_authoring'] = {k: deepcopy(v) for k, v in unit.items() if k not in ('inputs', 'candidate_motion')}
    if 'candidate_motion' in unit:
        result['candidate_motion'] = deepcopy(unit['candidate_motion'])
        result['candidate_motion']['present_in_selected_export'] = unit['candidate_motion']['path'] in selected
    if 'runtime_scene' in unit:
        result['current_authoring']['runtime_scene_present_in_selected_export']=unit['runtime_scene'] in selected
        result['current_authoring']['current_bytes_verified_in_selected_export']=False
    result['life_status'] = (('native_motion_verified_pending_level_review' if 'candidate_motion' in unit else 'native_geometry_verified_pending_level_review') if unit['native_verified'] else
                             'authored_compiled_pending_native_review' if unit['authored'] else 'changed_inputs_pending_review')
    if unit.get('kind') == 'creature_candidate':
        result['candidate_source']=deepcopy(unit['candidate_source'])
        result['life_status']=('authored_candidate_native_verified_pending_pack_and_attack_profiles' if unit['native_verified'] else
                               'authored_candidate_pending_current_native_review' if unit['authored'] else 'changed_inputs_pending_review')
    return result


def current_creature_candidates(repo, game):
    repo, game = Path(repo), Path(game)
    base = repo/'art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures'
    units = {}
    for receipt in sorted(base.glob('M[0-9][0-9]/authoring.json')):
        author = read(receipt)
        identity = author['asset']
        inputs, errors = {}, []
        bind(repo,game,inputs,errors,receipt)
        candidate = receipt.parent/(identity+'_living_candidate.glb')
        bind(repo,game,inputs,errors,candidate,author['candidate_sha256'])
        bind(repo,game,inputs,errors,game/resource_path(author['production_resource'])[6:],author['production_sha256'])
        contract_path = receipt.parent/'source_contract.json'
        bind(repo,game,inputs,errors,contract_path)
        contract=read(contract_path) if contract_path.is_file() else {}
        good=not errors and contract.get('status')=='source_contract_pass' and contract.get('candidate_sha256')==author['candidate_sha256'] and contract.get('retained_source_sha256')==author['production_sha256']
        good &= all(contract.get(key) is True for key in ('protected_action_bytes_equal','retained_base_geometry_unchanged','retained_materials_skin_hierarchy_equal'))
        native={'historical_recorded_pass':False,'inputs_current':False,'errors':[]}
        proof=receipt.parent/'native_reviews/candidate_r2/source_receipt_manifest.json'
        if proof.is_file():
            snapshot=read(proof)
            native_errors=[]
            bind(repo,game,inputs,native_errors,proof)
            for item in snapshot.get('files',[]):
                path=(proof.parent/item['path']).resolve()
                if not path.is_relative_to(proof.parent.resolve()):raise ValueError('Native evidence path escapes archive')
                bind(repo,game,inputs,native_errors,path,item['sha256'])
            runner=read(proof.parent/'receipt.json')
            recorded=not native_errors and snapshot.get('candidate_sha256')==author['candidate_sha256'] and snapshot.get('native_candidate_verified') is True and runner.get('accepted') is True
            for path,expected in runner.get('input_sha256',{}).items():
                bind(repo,game,inputs,native_errors,resolve(repo,game,path),expected)
            native={'historical_recorded_pass':bool(recorded),'inputs_current':bool(recorded and not native_errors),
                    'errors':native_errors,'receipt':proof.relative_to(repo).as_posix(),'checks':snapshot.get('checks'),
                    'scope':snapshot.get('scope'),'prepared_pack_verified':False,'attack_profiles_recalibrated':False}
        units[identity]={'kind':'creature_candidate','authored':bool(good),'native_verified':bool(good and native['inputs_current']),
                         'inputs':inputs,'errors':errors,'candidate_source':{'path':input_key(repo,game,candidate),'sha256':author['candidate_sha256'],
                         'production_overwritten':False,'present_in_selected_export':False},'native_test':native,
                         'attack_recalibration_required':True,'prepared_pack_verified':False}
    return units


def current_scenery_units(repo, game):
    repo, game = Path(repo), Path(game)
    art = repo / 'art_source/art_recovery_v2'
    evidence = art / 'evidence/living_assets_stage3_20261107'
    result = {}
    for identity, name in SCENERY_SPLITS.items():
        receipt = evidence / ('scenery/' + name + '_compile.json')
        if not receipt.is_file():
            continue
        data = read(receipt)
        inputs, errors = {}, []
        bind(repo, game, inputs, errors, receipt)
        bind(repo, game, inputs, errors, game / resource_path(data['path'])[6:], data['sha256'])
        author_path = resolve(repo, game, data['authoring_receipt'])
        bind(repo, game, inputs, errors, author_path, data['authoring_receipt_sha256'])
        author = read(author_path) if author_path.is_file() else {}
        for key in ('blend','carrier','raw_carrier','recipe','transport_helper','retained_input','retained_native','retained_receipt'):
            value = author.get(key)
            if not value or not author.get(key + '_sha256'):
                errors.append({'error':'Missing scenery source provenance: ' + key})
                continue
            path = art / value if not Path(value).is_absolute() else resolve(repo, game, value)
            bind(repo, game, inputs, errors, path, author[key + '_sha256'])
        # The maintained compiler requires the editable recipe and transport
        # helper to match the archived authoring inputs too. Archive identity
        # alone cannot establish that a current rebuild would be accepted.
        for filename, key in (('author_living_world_parts.py', 'recipe'),
                              ('living_world_gltf_transport.py', 'transport_helper')):
            expected = author.get(key + '_sha256')
            if expected:
                bind(repo, game, inputs, errors, art / 'tools' / filename, expected)
        for path, expected in data.get('source_hashes', {}).items():
            bind(repo, game, inputs, errors, game / resource_path(path)[6:], expected)
        bind(repo, game, inputs, errors, game / 'tools/build_living_world_blender.gd', data.get('compiler_sha256'))
        bind(repo, game, inputs, errors, game / 'tools/living_world_geometry_contract.gd', data.get('geometry_contract_sha256'))
        authored = not errors and data.get('blender_authored') is True and author.get('blender_authored') is True
        parts = data.get('parts', [])
        native = authored and bool(parts) and all(p.get('triangle_attribute_multiplicity_equivalent') is True and p.get('geometry_palette_equivalent') is True and p.get('winding_normals_uvs_partitions_equivalent') is True for p in parts)
        result[identity] = {'authored':bool(authored),'compiled':bool(authored),'native_verified':bool(native),
            'inputs':inputs,'errors':errors,'runtime_scene':data['path'],'bytes':data.get('bytes'),
            'expected_pack_owner':'campaign','current_bytes_verified_in_selected_export':False,
            'moving_part_count':len(parts),'compile_receipt':receipt.relative_to(repo).as_posix(),
            'native_scope':'Compiled moving-part geometry/palette/pivot contract; separate union receipt and level observation remain distinct.'}
    receipt = evidence / 'endings/native-r1/receipt.json'
    if receipt.is_file():
        data = read(receipt)
        for row in data.get('resource_validation', {}).get('resources', []):
            if row.get('covenant') not in ('concord','open_road'):
                continue
            inputs, errors = {}, []
            bind(repo, game, inputs, errors, receipt)
            bind(repo, game, inputs, errors, game / resource_path(row['path'])[6:], row['sha256'])
            for source in data.get('sources', []):
                text = source['path'].replace('\\','/')
                if '/tools/' in text or '/scripts/' in text:
                    bind(repo, game, inputs, errors, resolve(repo, game, text), source['sha256'])
            valid = not errors and data.get('passed') is True and data.get('resource_validation',{}).get('status')=='pass'
            result['hart_aftermath_' + row['covenant']] = {'authored':bool(valid),'compiled':bool(valid),
                'native_verified':bool(valid),'inputs':inputs,'errors':errors,'path':row['path'],
                'sha256':row['sha256'],'bytes':row['bytes'],'pack_owner':'community',
                'compile_receipt':receipt.relative_to(repo).as_posix(),
                'native_scope':'Exact generated memorial resource geometry/obstacles; no in-level or ending enactment acceptance.'}
    return result
