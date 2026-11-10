"""Keep the thirteen retained equipment entries individually accountable."""
import hashlib
import json
from math import isfinite
from pathlib import Path
from copy import deepcopy
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs
from living_asset_coverage import digest, native_motion_evidence

ART = Path(__file__).resolve().parents[1]
GAME = ART.parents[1] / 'outputs/AshenOathTheRoadBetweenCrowns'
OUT = ART / 'evidence/living_assets_stage3_20261107'
DETAILS = {
    'C01_staff': ('character_presentation.gd', 'uses_fitted_anwen_staff', 'Retain measured Stage1 right-hand staff grip and planted shaft through left-hand care work.', 'Stage1 native contact evidence retained; new-stage carry/garment observation pending.', 'No new mesh or ticker; existing IK owner.'),
    'Kael_arrow': ('arrow_visual.gd', 'kael_arrow', 'Retain true arrow geometry and projectile/nock owner; inspect fletching clearance in quiver, hand and fired states.', 'New-stage actual nock/quiver/stow review pending.', 'No new mesh or ticker.'),
    'forge_hammer': ('character_presentation.gd', 'forge_hammer', 'Retain Stage1 native hammer grip and real anvil strike; check holstered/working silhouette.', 'Stage1 contact proof retained; new-stage stow/garment observation pending.', 'No new mesh; existing contact effect owner.'),
    'player_sword_steel_and_oathblade': ('player_controller.gd', 'Oathblade', 'Preserve blade sockets/reach and established steel, cyan, brass and leather response; inspect sheath/cape and hand clearance.', 'New-stage idle/carry/equip/stow material and fit review pending.', 'No new mesh or combat tracks.'),
    'player_bow': ('player_controller.gd', 'bow', 'Remove inherited-scale discontinuity across back/hand transfer while retaining source scale .44; inspect actual grip and string clearance.', 'Runtime continuity correction implemented; native visual transition review pending.', 'Transform correction only; no new geometry or ticker.'),
    'quiver': ('player_controller.gd', 'quiver', 'Retain open rim and seated arrows; review strap/cape attachment during new unarmed idles and equip transitions.', 'New-stage back/strap/arrow clearance review pending.', 'No new geometry; retained player skeleton owner.'),
    'activity_rope': ('character_presentation.gd', 'attach_activity_tool', 'Fit retained coil mesh to measured hand palm only for actual carried activity; supported Nera/Rook work uses real station straps.', 'Per-actor palm and exact coil vertex calibration pending.', 'Existing cached mesh; one attachment fit, no prop ticker.'),
    'activity_bowl': ('character_presentation.gd', 'attach_activity_tool', 'Fit a real retained bowl rim vertex into the measured palm for meals; preserve open vessel dimensions.', 'Per-actor palm/rim calibration and meal clearance pending.', 'Existing cached vessel mesh; one attachment fit.'),
    'activity_bread': ('character_presentation.gd', 'ScoredFlatbreadCrust', 'Fit an actual baked flatbread side vertex into the measured palm; preserve scores and shape during meals.', 'Exact mesh vertex/palm calibration and bite-side clearance pending.', 'Existing mesh and score child; one attachment fit.'),
    'activity_cloth': ('character_presentation.gd', 'attach_activity_tool', 'Fit retained folded linen to the real free palm; preserve Anwen right-staff/left-care ownership and suppress unrelated carry cloth during supported work.', 'Stage1 Anwen contact proof retained; remaining per-actor fit and garment review pending.', 'Existing cached mesh; one attachment fit.'),
    'activity_supply': ('character_presentation.gd', 'HeldProps.vessel', 'Fit the retained narrow supply vessel to actual closed-palm Idle/Walking carry poses for the ten reachable named actors; preserve its distinct .055/.11/.23 dimensions.', 'All ten actual palm/rim and carried-body clearance fits remain pending; native carrier export is a separate gate.', 'Existing cached vessel; one attachment fit, no independent ticker.'),
    'Vargan_spear': ('character_presentation.gd', '_add_spear', 'Resolve actual live native versus procedural equipment ownership before grip correction; retain combat reach and existing shaft/head geometry.', 'Prepared owner and shaft hand-contact inspection pending; no native improvement claimed.', 'No geometry or runtime change claimed yet.'),
    'Vargan_shield': ('character_presentation.gd', '_add_shield', 'Resolve actual live native versus procedural equipment ownership; inspect real forearm/shield contact and garment clearance.', 'Prepared owner and wrist/forearm fit inspection pending; no native improvement claimed.', 'No geometry or runtime change claimed yet.'),
    'Vargan_record_books': ('character_presentation.gd', 'VarganRecordBook', 'Retain C09/C10 fused pelvis books. Authored station ledger/receipt work and Merrow cup provide purposeful hand action; legacy carried-book helper is fallback-only.', 'Native fused belt-book ownership source-confirmed; new-stage belt/garment visual review pending.', 'Native belt geometry unchanged; no extra carried book for these actors.'),
}


def grip_review(out, game, actors):
    folder = out / 'equipment/grip_runtime_r1'
    if not folder.exists():
        return {}, {}
    repo = game.parents[1].resolve()

    def require(condition, detail):
        if not condition:
            raise ValueError('Equipment grip evidence: ' + detail)

    def repo_path(relative):
        path = (repo / relative).resolve()
        require(path.is_relative_to(repo) and path.relative_to(repo).as_posix() == relative,
                f'noncanonical repository path {relative}')
        return path

    def checked(path, expected):
        actual = digest(path)
        require(actual is not None and actual == expected, f'missing or stale {path}')
        return actual

    def accepted(run):
        return (run['passed'] is True and run['timed_out'] is False and run['owned_tree_exited'] is True
                and run['exit_code'] == 0 and run['active_processes_after_cleanup'] == 0)

    compiled_path = folder / 'compiled_libraries.json'
    strict_path = folder / 'strict_cast.json'
    strict = json.loads(strict_path.read_bytes())
    compiled_sha = checked(compiled_path, strict['compiled_receipt_sha256'])
    compiled = json.loads(compiled_path.read_bytes())
    log = folder / 'strict_cast.log'
    checked(log, strict['log_sha256'])
    checked(game / 'tools/verify_living_cast_motion.gd', strict['script_sha256'])
    require(strict['accepted'] is True and accepted(strict['run']) and compiled['accepted'] is True,
            'strict cast or compilation did not pass')
    require([run['stage'] for run in compiled['runs']] == ['opening', 'stage2']
            and all(accepted(run) for run in compiled['runs']), 'compiled runs are incomplete')
    lines = log.read_text(encoding='utf-8-sig').splitlines()
    summary = [line for line in lines if line.startswith('LIVING CAST MOTION: PASS')]
    require(summary == strict['summary'] and len(summary) == 1
            and summary[0].endswith('actors=12 player=true equipment_validation_deferred=false complete_cast=true'),
            'strict cast summary does not cover the complete cast')
    measurements = [json.loads(line.removeprefix('LIVING CAST HELD GRIP: ')) for line in lines
                    if line.startswith('LIVING CAST HELD GRIP: ')]
    by_fit = {(row['style'], row['source_sha256']): row for row in measurements}
    require(len(by_fit) == len(measurements) == strict['measurements'], 'strict measurement count or uniqueness differs')
    require(all(isfinite(row['error']) and 0 <= row['error'] <= 0.001 for row in measurements)
            and max(row['error'] for row in measurements) == strict['maximum_contact_error_m'],
            'strict contact error differs or exceeds one millimetre')
    source_hashes = compiled['source_sha256']
    game_prefix = game.resolve().relative_to(repo).as_posix() + '/tools/'
    builder = game_prefix + 'build_story_release.ps1'
    fixture = game_prefix + 'verify_living_activity_grip_compile.gd'
    order_path = folder / 'builder_order.json'
    order = json.loads(order_path.read_bytes())
    require(order['preceding_sha256'] == source_hashes[builder], 'builder successor does not link to compilation')
    regressions_path = folder / 'owner_regressions.json'
    regressions = json.loads(regressions_path.read_bytes())
    compiler_checks = [run for run in regressions['runs'] if run['stage'] == 'compiler']
    require(regressions['accepted'] is True and len(compiler_checks) == 1 and accepted(compiler_checks[0]),
            'updated compiler fixture did not pass')
    checked(folder / 'compiled_source_fixture.log', compiler_checks[0]['log_sha256'])
    successors = {builder: order['source_sha256'], fixture: compiler_checks[0]['script_sha256']}
    for relative, expected in source_hashes.items():
        checked(repo_path(relative), successors.get(relative, expected))

    roster = {actor['asset']: actor for actor in actors}
    libraries = {row['asset']: row for row in compiled['compiled']}
    require(len(roster) == len(actors) == len(libraries) == len(compiled['compiled']) and roster.keys() == libraries.keys(),
            'compiled actor roster differs from reachability contract')
    manifests = {path.split('/')[-2]: path for path in source_hashes if path.endswith('/activity_grips.json')}
    require(manifests.keys() == roster.keys(), 'compiled actor manifest roster differs')
    reviewed = {'bread': [], 'supply': []}
    for asset, actor in roster.items():
        entry = libraries[asset]
        library = repo_path(entry['library'])
        require(library == game.resolve() / actor['library'].removeprefix('res://'), f'{asset} runtime library differs')
        checked(library, entry['sha256'])
        require(library.stat().st_size == entry['bytes'], f'{asset} runtime library size differs')
        manifest_path = repo_path(manifests[asset])
        manifest_sha = checked(manifest_path, entry['grip_manifest_sha256'])
        manifest = json.loads(manifest_path.read_bytes())
        fits = manifest['fits']
        require(manifest['schema_version'] == 1 and manifest['asset'] == asset
                and fits.keys() == set(actor['required_activity_prop_grips']), f'{asset} manifest styles differ')
        for style, source in fits.items():
            fit_path = repo_path(source['evidence'])
            fit_sha = checked(fit_path, source['evidence_sha256'])
            measurement = by_fit.pop((style, fit_sha), None)
            require(measurement is not None, f'{asset} {style} lacks a strict native measurement')
            proof = json.loads(fit_path.read_bytes())
            fit = proof['fits'][style]
            inputs = proof.get('source_sha256', proof.get('input_sha256', {}))
            require(proof['asset'] == asset and fit['proposal']['bone'] == actor['hand']
                    and fit['surface_clearance_verified'] is True and fit['closed_component_containment_verified'] is True,
                    f'{asset} {style} lacks the retained hand and clearance proof')
            scene = fit['editable_scene']
            require(Path(scene['path']).name == scene['path'] and scene['path'].endswith('.blend'),
                    f'{asset} {style} editable scene path differs')
            checked(fit_path.parent / scene['path'], scene['sha256'])
            native = {}
            clips = {}
            for field in ('native_pose_evidence', 'route_pose_evidence'):
                if field not in source:
                    continue
                pose_path = repo_path(source[field])
                pose_sha = digest(pose_path)
                require(pose_sha is not None and pose_sha in inputs.values(), f'{asset} {style} pose hash differs')
                pose = json.loads(pose_path.read_bytes())
                require(pose['asset'] == asset and pose['sample_hz'] == 120 and pose['roundtrip']['verified'] is True
                        and pose['status'] == 'authoring_pose_exported',
                        f'{asset} {style} lacks a native 120 Hz roundtrip')
                native[field] = {'path': source[field], 'sha256': pose_sha}
                for clip in pose['clips']:
                    if clip['prop'] == style and clip['hand'] == actor['hand']:
                        clips[clip['clip']] = clip['frames']
            if 'route_pose_evidence' in source:
                # The composite uses only the visible route subset and the standing alias.
                route = 'Authoring_Carry_Scheduler_Route'
                clips = {'Authoring_Carry_Idle': clips['Authoring_Carry_Idle'], route: fit['native_socket_frames']}
                require(clips == fit['verified_by_clip'], f'{asset} {style} route subset differs')
            require(clips and sum(clips.values()) == fit['verified_frames'] == fit['expected_frames'],
                    f'{asset} {style} verified clip count differs')
            reviewed[style].append({'asset': asset, 'hand': actor['hand'], 'library': actor['library'],
                                    'library_sha256': entry['sha256'], 'manifest': manifests[asset],
                                    'manifest_sha256': manifest_sha, 'fit_receipt': source['evidence'],
                                    'fit_receipt_sha256': fit_sha, 'native_receipts': native,
                                    'verified_samples_by_clip': clips, 'strict_contact_error_m': measurement['error']})
    require(not by_fit, 'strict cast contains measurements outside the verified actor/style records')
    return reviewed, {'compiled_receipt': compiled_path.relative_to(repo).as_posix(),
                      'compiled_receipt_sha256': compiled_sha, 'strict_receipt': strict_path.relative_to(repo).as_posix(),
                      'strict_receipt_sha256': digest(strict_path), 'strict_log_sha256': strict['log_sha256'],
                      'builder_order_receipt_sha256': digest(order_path),
                      'owner_regressions_receipt_sha256': digest(regressions_path)}


def refresh_equipment(rows, previous, game=GAME):
    old_rows = {row['id']: row for row in previous.get('assets', [])}
    result = []
    cache = {}
    for row in rows:
        old = old_rows.get(row['id'], {})
        audit = old.get('runtime_ownership_audit', {})
        paths = [row['runtime_reference']]
        paths += [path for path in old.get('verification_inputs', {}) if path.startswith('res://')]
        paths += audit.get('resources', [])
        paths += [receipt['path'] for receipt in audit.get('source_receipts', [])]
        paths += [fit['library'] for fit in row.get('activity_grip_evidence', [])]
        inputs = resource_inputs(game, paths, cache)
        if row.get('activity_contract_sha256'):
            inputs['coverage:activity_contract_sha256']=row['activity_contract_sha256']
        if row.get('activity_grip_strict_sha256'):
            inputs['coverage:activity_grip_strict_sha256'] = row['activity_grip_strict_sha256']
        result.append(refresh_review(row, old, inputs))
    return result


def main():
    baseline = json.loads((OUT / 'retained_source_inventory.json').read_text())['held_equipment_checklist']
    contract_path = OUT/'held_prop_contracts_20261110.json'
    contract = json.loads(contract_path.read_text()) if contract_path.is_file() else {}
    live_actors = contract.get('actors',[])
    destination = OUT / 'equipment_coverage.json'
    previous = json.loads(destination.read_text(encoding='utf-8-sig')) if destination.exists() else {}
    verified_grips, grip_sources = grip_review(OUT, GAME, live_actors)
    if previous.get('activity_grip_evidence_sources') and not grip_sources:
        raise ValueError('Equipment grip evidence: previously supplied strict receipts are missing')
    originals = deepcopy(baseline['assets'])
    if any('supply' in actor.get('required_activity_prop_grips',[]) for actor in live_actors):
        originals.append({'id':'activity_supply','change':'Existing live supply vessel is distinct from the wider bowl; added to current coverage from actual scheduled carry contract, not newly authored geometry.'})
    rows = []
    for original in originals:
        identity = original['id']
        filename, symbol, treatment, status, cost = DETAILS[identity]
        path = GAME / 'scripts' / filename
        if not path.is_file():
            matches = list((GAME / 'scripts').rglob(filename))
            if len(matches) != 1:
                raise ValueError('Resolve equipment runtime file: ' + filename)
            path = matches[0]
        lines = path.read_text(encoding='utf-8-sig').splitlines()
        hits = [i + 1 for i, line in enumerate(lines) if symbol.lower() in line.lower()]
        fallback = identity in ('Vargan_spear','Vargan_shield')
        required_style = 'bread' if identity=='activity_bread' else ('supply' if identity=='activity_supply' else None)
        required = [actor for actor in live_actors if required_style in actor.get('required_activity_prop_grips',[])] if required_style else []
        accepted = verified_grips.get(required_style, [])
        rows.append({'id': identity, 'retained_geometry_and_material_treatment': original['change'],
                     'stage3_treatment': treatment, 'assessment': status,
                     'runtime_reference': 'res://' + path.relative_to(GAME).as_posix(),
                     'runtime_symbol': symbol, 'reference_lines': hits,
                     'runtime_source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'incremental_performance_cost': cost,
                     'inventory_origin':'current_reachable_activity_contract' if identity=='activity_supply' else 'retained_thirteen_entry_checklist',
                     'runtime_usage_scope':'conditional_legacy_fallback_not_instantiated_for_authored_cast' if fallback else ('scheduled_named_cast_prop' if required else 'retained_runtime_owner_pending_context_review'),
                     'confirmed_world_usage':False,
                     'named_cast_runtime_reachable':False if fallback else (True if required else None),
                     'required_actor_fits':[actor['asset'] for actor in required],
                     'accepted_actor_fits':[fit['asset'] for fit in accepted],
                     'activity_contract_sha256':digest(contract_path) if required else None,
                     'current_visual_evidence': [], 'native_verified': False,
                     'visual_accepted': False, 'in_level_accepted':False,'performance_verified':False,'user_accepted': False})
        if accepted:
            rows[-1]['activity_grip_evidence'] = accepted
            rows[-1]['activity_grip_strict_sha256'] = grip_sources['strict_receipt_sha256']
    rows = refresh_equipment(rows, previous, GAME)
    # The original independent audit is retained verbatim, even when its input
    # hashes are historical. Current hashes do not silently re-certify that audit.
    for row in rows:
        audit = row.get('runtime_ownership_audit',{})
        receipts = audit.get('source_receipts',[])
        row['historical_ownership_audit_inputs_current']=bool(receipts) and all(digest(GAME/item['path'][6:])==item['sha256'] for item in receipts)
        row['current_runtime_reference_sha256']=digest(GAME/row['runtime_reference'][6:])
        if row['id'] in ('Vargan_spear','Vargan_shield'):
            row['assessment']='Retained conditional fallback. Current authored cast bypasses this helper; no confirmed world use, native fit or geometry improvement is claimed.'
        if row['id'] in ('activity_bread','activity_supply'):
            if row['accepted_actor_fits']:
                row['native_verified'] = True
                count = len(row['accepted_actor_fits'])
                scope = ('standing meals' if row['id'] == 'activity_bread' else
                         'stationary carry, full-speed forward Walk, and Nessa’s measured work-to-errand route')
                row['assessment'] = f'{count} named-actor grips passed source clearance and strict native verification for {scope}. Current gameplay and visual review are pending.'
            else:
                row['assessment'] = str(len(row['required_actor_fits'])) + ' reachable named-actor fits remain pending actual closed-palm and full activity clearance proof.'
    native = native_motion_evidence(GAME.parents[1],GAME)
    for row in rows:
        if row['id'] in ('C01_staff','forge_hammer','player_bow') and native.get('recorded_pass'):
            row['native_scope_evidence']={key:deepcopy(native[key]) for key in ('receipt','scope','recorded_pass','errors') if key in native}
            row['native_scope_evidence']['inputs_current']=native['verified']
            row['native_scope_evidence']['complete_equipment_review']=False
    result = {'schema_version': 2, 'scope': 'Current equipment coverage: thirteen retained entries plus the reachable supply vessel; conditional fallback is not confirmed world use.',
              'baseline_date': baseline['date'], 'assets': rows,
              'publication_ready': False,
              'note': 'Source contracts and historical prop-stage captures do not substitute for current actual gameplay carry/stow/grip/garment review.',
              'coverage_counts':{'retained_checklist_entries':len(baseline['assets']),'current_review_entries':len(rows),
                  'conditional_fallback_entries':sum(row['id'] in ('Vargan_spear','Vargan_shield') for row in rows),
                  'required_named_actor_fits':sum(len(actor.get('required_activity_prop_grips',[])) for actor in live_actors),
                  'accepted_named_actor_fits':sum(len(row['accepted_actor_fits']) for row in rows),
                  'confirmed_world_usage_entries':sum(row['confirmed_world_usage'] for row in rows)}}
    if grip_sources:
        result['activity_grip_evidence_sources'] = grip_sources
    for key, value in previous.items():
        if key not in result:
            result[key] = deepcopy(value)
    result['removed_from_runtime_scope'] = preserve_removed(previous.get('assets', []), rows, previous.get('removed_from_runtime_scope', []))
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print('EQUIPMENT_COVERAGE', len(rows), str(destination))


if __name__ == '__main__':
    main()
