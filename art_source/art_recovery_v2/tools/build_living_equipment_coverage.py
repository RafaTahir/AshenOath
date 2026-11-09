"""Keep the thirteen retained equipment entries individually accountable."""
import hashlib
import json
from pathlib import Path
from copy import deepcopy
from living_coverage_freshness import preserve_removed, refresh_review, resource_inputs

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
    'Vargan_spear': ('character_presentation.gd', '_add_spear', 'Resolve actual live native versus procedural equipment ownership before grip correction; retain combat reach and existing shaft/head geometry.', 'Prepared owner and shaft hand-contact inspection pending; no native improvement claimed.', 'No geometry or runtime change claimed yet.'),
    'Vargan_shield': ('character_presentation.gd', '_add_shield', 'Resolve actual live native versus procedural equipment ownership; inspect real forearm/shield contact and garment clearance.', 'Prepared owner and wrist/forearm fit inspection pending; no native improvement claimed.', 'No geometry or runtime change claimed yet.'),
    'Vargan_record_books': ('character_presentation.gd', 'VarganRecordBook', 'Retain C09/C10 fused pelvis books. Authored station ledger/receipt work and Merrow cup provide purposeful hand action; legacy carried-book helper is fallback-only.', 'Native fused belt-book ownership source-confirmed; new-stage belt/garment visual review pending.', 'Native belt geometry unchanged; no extra carried book for these actors.'),
}


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
        inputs = resource_inputs(game, paths, cache)
        result.append(refresh_review(row, old, inputs))
    return result


def main():
    baseline = json.loads((OUT / 'retained_source_inventory.json').read_text())['held_equipment_checklist']
    rows = []
    for original in baseline['assets']:
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
        rows.append({'id': identity, 'retained_geometry_and_material_treatment': original['change'],
                     'stage3_treatment': treatment, 'assessment': status,
                     'runtime_reference': 'res://' + path.relative_to(GAME).as_posix(),
                     'runtime_symbol': symbol, 'reference_lines': hits,
                     'runtime_source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'incremental_performance_cost': cost,
                     'current_visual_evidence': [], 'native_verified': False,
                     'visual_accepted': False, 'user_accepted': False})
    destination = OUT / 'equipment_coverage.json'
    previous = json.loads(destination.read_text(encoding='utf-8-sig')) if destination.exists() else {}
    rows = refresh_equipment(rows, previous, GAME)
    result = {'schema_version': 1, 'scope': 'All thirteen retained equipment checklist entries; native versus fallback ownership remains explicit.',
              'baseline_date': baseline['date'], 'assets': rows,
              'publication_ready': False,
              'note': 'Source contracts and historical prop-stage captures do not substitute for current actual gameplay carry/stow/grip/garment review.'}
    for key, value in previous.items():
        if key not in result:
            result[key] = deepcopy(value)
    result['removed_from_runtime_scope'] = preserve_removed(previous.get('assets', []), rows, previous.get('removed_from_runtime_scope', []))
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print('EQUIPMENT_COVERAGE', len(rows), str(destination))


if __name__ == '__main__':
    main()
