"""Bound the private measured M07 derivative; never installs a runtime asset."""
import argparse
import datetime
import json
from pathlib import Path

from run_candidate_authoring import row, unchanged, verify_outputs
from run_candidate_serial import launch_owned

HERE = Path(__file__).resolve().parent
FREEZE = HERE / 'M07/revised_source_r4_readiness.json'


def verify_geometry(authoring, source_contract):
    geometry = authoring['measured_baked_geometry']
    assert geometry['accepted_fold_probe_sha256'] == '90413a7482b29d0c7edaacd2185dc95cf35721628b9f0c5a28ae5805136979d5'
    assert geometry['retained_entry_exit_samples'] == 17
    assert set(geometry['clips']) == {'Idle', 'Investigate', 'Feed', 'Sleep'}
    for clip, samples in geometry['clips'].items():
        assert len(samples) == 17 and all(sample['sample_geometry_pass'] is True for sample in samples), clip
        assert sorted(authoring['ambient_clips'][clip]['bones']) == source_contract['clips'][clip]['active_bones'], clip
    assert geometry['clips']['Idle'][0]['width_fraction'] <= .75
    return {clip: len(samples) for clip, samples in geometry['clips'].items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--deadline-utc')
    args = parser.parse_args()
    plan = json.loads(FREEZE.read_text(encoding='utf-8'))
    work = Path(plan['work']).resolve()
    folder = Path(plan['folder']).resolve()
    evidence = Path(plan['evidence']).resolve()
    if not work.is_relative_to(HERE) or not evidence.is_relative_to(HERE) or not folder.is_relative_to(work):
        raise ValueError('Private M07 output escapes the isolated verification root')
    if (work / 'models').exists() or evidence.exists():
        raise ValueError('Existing derivative or process receipts must be preserved')
    if not unchanged(plan['inputs']):
        raise ValueError('Frozen M07 inputs changed')
    print(json.dumps({'asset': 'M07', 'ready': True, 'execute': args.execute, 'inputs': len(plan['inputs']), 'minimum_window_seconds': 450, 'output': str(folder)}), flush=True)
    if not args.execute:
        return 0
    if not args.deadline_utc:
        parser.error('An explicitly granted UTC deadline is required')
    deadline = datetime.datetime.fromisoformat(args.deadline_utc)
    if deadline.utcoffset() != datetime.timedelta(0):
        parser.error('Deadline must have a UTC offset')

    def remaining():
        return (deadline - datetime.datetime.now(datetime.timezone.utc)).total_seconds()

    if remaining() < 450:
        raise ValueError('Insufficient granted time for both owned stages and cleanup')
    evidence.mkdir(parents=False, exist_ok=False)
    result = {'asset': 'M07', 'passed': False, 'production_overwritten': False, 'native_verified': False,
              'visual_accepted': False, 'attack_profiles_recalibrated': False, 'runs': []}
    try:
        for stage in plan['commands']:
            if not unchanged(plan['inputs']):
                raise ValueError('Frozen M07 source input changed before ' + stage['label'])
            if remaining() < stage['cap_seconds'] + 15:
                raise ValueError('Deadline reached before ' + stage['label'])
            run = launch_owned(stage['argv'], evidence / (stage['label'] + '.log'), stage['cap_seconds'])
            result['runs'].append({'stage': stage['label'], **run})
            if not run.get('passed') or not run.get('owned_tree_exited'):
                raise ValueError('Owned M07 stage failed: ' + stage['label'])
        authored = json.loads((folder / 'authoring.json').read_text(encoding='utf-8'))
        contract = json.loads((folder / 'source_contract.json').read_text(encoding='utf-8'))
        if contract.get('status') != 'source_contract_pass' or contract.get('asset') != 'M07':
            raise ValueError('Missing maintained source contract')
        result['baked_clearance_samples'] = verify_geometry(authored, contract)
        result['outputs'] = verify_outputs(folder, 'M07', authored, contract)
        result['candidate_sha256'] = contract['candidate_sha256']
        result['candidate_bytes'] = contract['candidate_bytes']
        result['sources_unchanged'] = unchanged(plan['inputs'])
        result['passed'] = result['sources_unchanged']
    except (ValueError, OSError, TypeError, KeyError, AssertionError) as error:
        result['error'] = str(error)
        result['sources_unchanged'] = unchanged(plan['inputs'])
    with (evidence / 'receipt.json').open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'outputs'}), flush=True)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
