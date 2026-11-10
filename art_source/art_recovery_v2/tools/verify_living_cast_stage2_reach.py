"""Verify authored contact reach against measured retained bone lengths."""
import json
import hashlib
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
MODELS=ROOT/'models/living_cast_stage2_20261107'
EVIDENCE=ROOT/'evidence/living_cast_stage2_20261107'
from living_cast_stage2_profiles import PROFILES
GOALS={asset:profile['palm_goals_lateral_forward_height'] for asset,profile in PROFILES.items() if profile['contact_required']}


def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))


def main(assets=None):
    results=[]
    for asset,goals in GOALS.items():
        if assets and asset not in assets:continue
        report=json.loads((MODELS/asset/'authoring.json').read_text())
        if hashlib.sha256((MODELS/asset/(asset+'_life_review.glb')).read_bytes()).hexdigest()!=report['review_glb_sha256']:
            raise ValueError(asset+' carrier changed since reach samples were authored')
        data=(EVIDENCE/(asset+'_baseline.glb')).read_bytes()
        document=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
        nodes={node['name']:node for node in document['nodes'] if 'name' in node}
        samples=report['clips']['Life_Work']['sampled_points']
        start=next(s for s in samples if s['phase']==0)
        contact=next(s for s in samples if s['phase']==.5)
        scale=distance(start['world_points']['Head'],start['world_points']['foot_l'])/distance(start['points']['Head'],start['points']['foot_l'])
        for side,goal in goals.items():
            arm=sum(distance(nodes[name]['translation'],[0,0,0]) for name in ['lowerarm_'+side,'hand_'+side])*scale
            shoulder=contact['world_points']['upperarm_'+side]
            hand=contact['world_points']['hand_'+side]
            probe=contact.get('world_contact_probes',{}).get(side,hand)
            wrist_goal=[goal[i]-(probe[i]-hand[i]) for i in range(3)]
            required=distance(shoulder,wrist_goal);margin=arm-required
            numbers=shoulder+hand+goal+[arm,required,margin]
            if not all(math.isfinite(v) for v in numbers) or margin<.006:
                raise ValueError(f'{asset}/{side} is not comfortably reachable without stretching: {margin:.6f}m')
            if distance(probe,goal)>.002:
                raise ValueError(f'{asset}/{side} authored palm misses the physical contact by over 2mm')
            results.append({'asset':asset,'hand':'hand_'+side,'goal_lateral_forward_height':goal,
                            'authored_shoulder':shoulder,'authored_hand':hand,'authored_contact_probe':probe,'required_wrist_goal':wrist_goal,'retained_arm_length':arm,
                            'required_reach':required,'reach_margin':margin,'native_palm_goal_residual':distance(probe,goal),
                            'shoulder_forward_shift':shoulder[1]-start['world_points']['upperarm_'+side][1]})
        for sample in samples:
            for foot in ['foot_l','foot_r']:
                if distance(sample['world_points'][foot],start['world_points'][foot])>1e-5:
                    raise ValueError(asset+' displaced a retained foot')
    output={'status':'source_reach_pass','coordinate_order':['lateral','forward','height'],
            'contacts':results,'runtime_verified':False,'user_accepted':False,
            'note':'Reachability is measured from source FK and retained bone lengths. Exact native runtime contact still requires the existing IK and in-game fixture.'}
    (MODELS/'source_reach.json').write_text(json.dumps(output,indent=2)+'\n')
    for asset in sorted({row['asset'] for row in results}):
        receipt=json.loads((MODELS/asset/'authoring.json').read_text())
        per_asset={**output,'asset':asset,'contacts':[row for row in results if row['asset']==asset],
                   'blend_sha256':receipt['blend_sha256'],'review_glb_sha256':receipt['review_glb_sha256']}
        (MODELS/asset/'source_reach.json').write_text(json.dumps(per_asset,indent=2)+'\n')
    for row in results:print(row['asset'],row['hand'],'margin',round(row['reach_margin'],6),'native residual',round(row['native_palm_goal_residual'],6))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--asset',nargs='+')
    main(parser.parse_args().asset)
