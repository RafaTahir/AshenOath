"""Check the actual authored GLB curves and retained-source receipts."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
from living_cast_stage2_profiles import CLIPS, PROFILES

ROOT=Path(__file__).resolve().parents[1]
EXPECTED={'Life_Idle_A':6.0,'Life_Idle_B':8.0,'Life_Work':4.0,'Life_Listen':4.0,'Life_Speak':4.0}


def verify(asset, models=None, expected_clips=None):
    expected=expected_clips if expected_clips is not None else {**CLIPS, **PROFILES[asset].get('extra_clips', {})}
    folder=(models if models is not None else ROOT/'models/living_cast_stage2_20261107')/asset
    receipt=json.loads((folder/'authoring.json').read_text())
    data=(folder/(asset+'_life_review.glb')).read_bytes()
    if hashlib.sha256(data).hexdigest()!=receipt['review_glb_sha256']:
        raise ValueError('Carrier changed since authored receipt')
    if hashlib.sha256(Path(receipt['production_source']).read_bytes()).hexdigest()!=receipt['production_sha256']:
        raise ValueError('Production source changed during authoring')
    recipe = receipt['recipe_snapshot']
    recorded = {}
    for item in recipe['files']:
        path = (ROOT/item['path']).resolve()
        if not path.is_relative_to(ROOT.resolve()):
            raise ValueError('Recipe snapshot leaves the authored source root')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
            raise ValueError('Authored recipe snapshot changed: '+item['name'])
        recorded[item['name']] = item['sha256']
    if hashlib.sha256(json.dumps(recorded,sort_keys=True).encode()).hexdigest()!=recipe['sha256']:
        raise ValueError('Recipe snapshot manifest changed')
    for field, name in [('authoring_tool_sha256','author_living_cast_stage2.py'), ('motion_recipe_sha256','living_cast_stage2_motion.py'), ('profile_sha256','living_cast_stage2_profiles.py')]:
        if recorded[name]!=receipt[field]:
            raise ValueError('Authored recipe provenance mismatch: '+name)
    size=struct.unpack_from('<I',data,12)[0]
    document=json.loads(data[20:20+size])
    binary=data[28+size:]
    def values(index):
        accessor=document['accessors'][index]
        if accessor['componentType']!=5126:
            raise ValueError('Animation samples must be floats')
        count={'SCALAR':1,'VEC3':3,'VEC4':4}[accessor['type']]
        view=document['bufferViews'][accessor['bufferView']]
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        stride=view.get('byteStride',4*count)
        return [struct.unpack_from('<'+'f'*count,binary,offset+i*stride) for i in range(accessor['count'])]
    if {a['name'] for a in document['animations']}!=set(expected):
        raise ValueError('Carrier must contain exactly the identity-specific authored life clips')
    animations={}
    signatures={}
    for animation in document['animations']:
        clip=animation['name'];largest_loop_error=0.0;body_variation=0.0;root_variation=0.0;duration=0.0
        signature=hashlib.sha256()
        for channel in animation['channels']:
            sampler=animation['samplers'][channel['sampler']]
            times=values(sampler['input']);samples=values(sampler['output'])
            if any(not math.isfinite(v) for row in times+samples for v in row):
                raise ValueError('Nonfinite authored animation sample')
            duration=max(duration,times[-1][0])
            if len(times)>1 and abs(times[-1][0]-expected[clip])>.001:
                raise ValueError('Incorrect actual clip duration '+clip)
            if any(b[0]<=a[0] for a,b in zip(times,times[1:])):
                raise ValueError('Nonmonotonic authored keys')
            bone=document['nodes'][channel['target']['node']]['name']
            variation=max(abs(v-samples[0][i]) for row in samples for i,v in enumerate(row))
            if bone=='root':root_variation=max(root_variation,variation)
            elif not bone.startswith('Face_'):
                body_variation=max(body_variation,variation)
                largest_loop_error=max(largest_loop_error,max(abs(a-b) for a,b in zip(samples[0],samples[-1])))
                if channel['target']['path']=='rotation':
                    signature.update(struct.pack('<'+'f'*len(samples[len(samples)//2]),*samples[len(samples)//2]))
        if abs(duration-expected[clip])>.001:
            raise ValueError('Incorrect aggregate clip duration '+clip)
        if body_variation<.001:
            raise ValueError('Authored clip is flat '+clip)
        if root_variation>.00001:
            raise ValueError('Authored clip contains root motion '+clip)
        if largest_loop_error>.0001:
            raise ValueError('Authored loop does not close '+clip)
        signatures[clip]=signature.hexdigest()
        animations[clip]={'duration_seconds':expected[clip],'body_variation':body_variation,'root_variation':root_variation,'loop_error':largest_loop_error}
    if len(set(signatures.values()))!=len(expected):
        raise ValueError('Two authored poses are identical at their midpoints')
    # Feet are intentionally planted; world-space motion cannot drift through
    # hand/torso additions even where root curves themselves remain constant.
    for clip in receipt['clips'].values():
        samples=clip['sampled_points']
        for sample in samples[1:]:
            for foot in ['foot_l','foot_r']:
                if max(abs(a-b) for a,b in zip(sample['points'][foot],samples[0]['points'][foot]))>.00001:
                    raise ValueError('Foot motion introduced by upper-body authoring')
    result={'asset':asset,'status':'source_contract_pass','animations':animations,
            'retained_production_sha256':receipt['production_sha256'],'review_glb_sha256':receipt['review_glb_sha256'],
            'runtime_workstation_and_visual_acceptance':False}
    (folder/'source_verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(asset,'SOURCE_CONTRACT_PASS')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--asset',nargs='+',default=list(PROFILES))
    for asset in parser.parse_args().asset:verify(asset)
