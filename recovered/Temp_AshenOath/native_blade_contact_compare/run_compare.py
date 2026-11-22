"""Prepared actual P01 contact diagnostic. No engine without explicit --ready."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT/'config.json').read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ready', action='store_true')
    args = parser.parse_args()
    if not args.ready:
        print(json.dumps({'status':'PREPARED_NOT_RUN', **CONFIG}, indent=2))
        return 0
    assert not (ROOT/'comparison.json').exists(), 'Preserve completed evidence'
    environment = os.environ.copy()
    for key, leaf in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','temp'),('TMP','temp')]:
        folder = ROOT/'profile'/leaf
        folder.mkdir(parents=True, exist_ok=True)
        environment[key] = str(folder)
    receipts = {}
    for label in ('baseline','current'):
        graph = CONFIG['graphs'][label]
        assert hashlib.sha256(Path(graph['path']).read_bytes()).hexdigest() == graph['sha256']
        output = ROOT/(label+'.json')
        command = [CONFIG['godot'],'--headless','--path',CONFIG['project'],'--script',str(ROOT/'diagnostic.gd'),
                   '--','--graph',graph['path'],'--output',str(output)]
        result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120)
        (ROOT/(label+'.log')).write_text(result.stdout+result.stderr, encoding='utf-8')
        print(label+' exit='+str(result.returncode), flush=True)
        if result.returncode or not output.exists():
            print(result.stdout+result.stderr)
            return 1
        receipts[label] = json.loads(output.read_text())
        assert not receipts[label]['errors']
    baseline, current = receipts['baseline'], receipts['current']
    rows = []
    assert len(baseline['cases']) == len(current['cases']) == 9
    for old, new in zip(baseline['cases'],current['cases']):
        assert old['name'] == new['name']
        strikes = []
        for a,b in zip(old['strikes'],new['strikes']):
            maximum_marker_delta = max(math.dist(f[key],g[key]) for f,g in zip(a['frames'],b['frames']) for key in ('base','tip'))
            strikes.append({'baseline_damage':a['damage'], 'current_damage':b['damage'],
                            'baseline_accepted':a['accepted'], 'current_accepted':b['accepted'],
                            'baseline_contact_samples':len(a['contacts']), 'current_contact_samples':len(b['contacts']),
                            'maximum_marker_delta_m':maximum_marker_delta,
                            'contact_equivalent':abs(a['damage']-b['damage'])<0.0001 and len(a['contacts'])==len(b['contacts']) and maximum_marker_delta<0.001})
        rows.append({'case':new['name'], 'baseline_lock_established':old['lock_established'],
                     'current_lock_established':new['lock_established'], 'strikes':strikes})
    report={'status':'RECORDED', 'contact_equivalent':all(s['contact_equivalent'] for r in rows for s in r['strikes']),
            'all_inputs_accepted':all(s['baseline_accepted'] and s['current_accepted'] for r in rows for s in r['strikes']),
            'all_current_strikes_damage':all(s['current_damage']>0 for r in rows for s in r['strikes']),
            'configuration':CONFIG, 'cases':rows,
            'evidence_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.glob('*') if p.suffix in ('.json','.log','.gd')},
            'limits':'Model-backed diagnostic only, not browser/hardware/gameplay acceptance. Missing baseline/current contact remains explicit.'}
    (ROOT/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    return 0


if __name__=='__main__':
    raise SystemExit(main())
