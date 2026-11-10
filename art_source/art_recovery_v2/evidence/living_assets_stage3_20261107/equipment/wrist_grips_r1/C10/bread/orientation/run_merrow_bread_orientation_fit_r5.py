"""Try exact C10 r2 orientations with the unchanged complete Blender fit gates."""
from __future__ import annotations

import inspect
from pathlib import Path

import run_merrow_bread_wrist_r2_fit as previous


MOTION = previous.MOTION
SOURCE_FIT = previous.source_fit
MEASUREMENT = MOTION / 'merrow_bread_resolve_measurement_r3.json'
MEASUREMENT_SHA = 'f02fc2f6d44b1792347c119f302133256026b34cc788cb54c7990da394b3e8da'
FIT_OUTPUT = 'compatible_c10_bread_orientation_fit_r5'
digest, read, require = previous.digest, previous.read, previous.require


def source_seeds():
    require(digest(MEASUREMENT) == MEASUREMENT_SHA, 'Exact Merrow source measurement changed')
    data = read(MEASUREMENT)
    require(data['asset'] == 'C10' and data['style'] == 'bread' and data['selected']['kind'] == 'exact_r2_alternate_orientation'
            and len(data['checkpoints']) == 17 and data['failed_r2_verified_frames'] == 146 and data['expected_fit_frames'] == 839
            and data['grip_verified'] is False and data['runtime_output'] is False and data['visual_accepted'] is False,
            'Expected the measured exact r2 orientation evidence')
    rows = [row['retained_grip'] for row in data['exact_r2']['whole_checkpoint_survivors']]
    values = [(*row['palm_vertex'], row['prop_primary_vertex'], row['prop_support_direction_index'],
               row['twist_degrees'], row['contact_offset_m']) for row in rows]
    require(values == [(3, 1974, 198, 8, 0, .0003), (3, 1974, 198, 8, 0, .00085)], 'Measured orientation seeds changed')
    return data, values


def accepted_seed_inputs(actor, style):
    native, receipt, sources = previous.accepted_directional_inputs(actor, style)
    data, _ = source_seeds()
    source_hashes = data['source_sha256']
    require(source_hashes.get(str(native)) == digest(native)
            and all(Path(path).is_file() and digest(path) == expected for path, expected in source_hashes.items()),
            'Orientation measurement does not bind the exact r2 source and rejected fit')
    return native, receipt, (*sources, MEASUREMENT, Path(previous.__file__), *(Path(path) for path in source_hashes))


def seeded_source(fitter):
    _, seeds = source_seeds()
    replace = SOURCE_FIT.base.replace
    code = fitter.decode('utf-8')
    code = replace(code, 'CONTACT_LIMIT = 0.001', f'CONTACT_LIMIT = 0.001\nORIENTATION_SEEDS = {seeds!r}')
    code = replace(code, '            finalist, trials = [], Counter()',
                   '            finalist, trials = [], Counter()\n            seed_matches, seed_midpoint_passes = set(), set()')
    code = replace(code, '                for direction in directions:',
                   '                for direction_index, direction in enumerate(directions):')
    code = replace(code, '                            problem, _ = clearance(candidate, points, geometry)',
                   '                            _, source_palm = palm_rows[palm_id]\n'
                   '                            key = (source_palm["surface"], source_palm["vertex"], anchors.index(anchor_id), direction_index, twist, offset)\n'
                   '                            seed_index = ORIENTATION_SEEDS.index(key) if key in ORIENTATION_SEEDS else None\n'
                   '                            if seed_index is not None:\n'
                   '                                seed_matches.add(seed_index)\n'
                   '                            problem, _ = clearance(candidate, points, geometry)')
    code = replace(code, '                                candidate["rank"] = ((1 - up.normalized().y) if style == "supply" else 0.0,',
                   '                                candidate["source_seed_index"] = seed_index\n'
                   '                                if seed_index is not None:\n'
                   '                                    seed_midpoint_passes.add(seed_index)\n'
                   '                                candidate["rank"] = (seed_index if seed_index is not None else len(ORIENTATION_SEEDS),\n'
                   '                                                     (1 - up.normalized().y) if style == "supply" else 0.0,')
    code = replace(code, '            report["fits"][style] = fit\n            record()',
                   '            fit["orientation_measurement"] = {"sha256": "' + MEASUREMENT_SHA + '",\n'
                   '                "matched": sorted(seed_matches), "midpoint_passes": sorted(seed_midpoint_passes),\n'
                   '                "shortlisted": [row["source_seed_index"] for row in finalist if row["source_seed_index"] is not None],\n'
                   '                "selected": None}\n'
                   '            report["fits"][style] = fit\n            record()\n'
                   '            require(seed_matches == set(range(len(ORIENTATION_SEEDS))), "Exact measured C10 orientations were not reconstructed")')
    code = replace(code, '            best = finalist[0]\n',
                   '            best = finalist[0]\n            fit["orientation_measurement"]["selected"] = best["source_seed_index"]\n')
    return code.encode('utf-8')


def fit_sources(actor, native_path, carrier_path, output, inspector, fitter):
    inspector, fitter, extras, witness = SOURCE_FIT.fit_sources(actor, native_path, carrier_path, output, inspector, fitter)
    return inspector, seeded_source(fitter), extras, witness


def main():
    text = inspect.getsource(SOURCE_FIT.main)
    text = SOURCE_FIT.base.replace(text, 'f"compatible_{actor.lower()}_{style}_measured_wrist_fit_r3"', f'"{FIT_OUTPUT}"')
    text = SOURCE_FIT.base.replace(text, 'measured.measured.STYLES', '{"C10": ("bread",)}')
    context = {**vars(SOURCE_FIT), '__file__': __file__, 'accepted_measured_inputs': accepted_seed_inputs, 'fit_sources': fit_sources}
    exec(compile(text, __file__, 'exec'), context)
    return context['main']()


if __name__ == '__main__':
    raise SystemExit(main())
