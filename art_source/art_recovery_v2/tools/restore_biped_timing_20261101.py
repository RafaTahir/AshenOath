"""Restore import FPS in masters and exact clip duration in exported derivatives.

Only animation input time bytes change in GLBs. Geometry, skin weights, texture
payloads and sampled poses are retained byte-for-byte. Ratios are derived from
the immutable pre-refinement resource, not assumed from an export setting.
"""
import hashlib,json,sys,argparse
from pathlib import Path
import bpy,numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from integrate_refinement_20261101 import unpack,pack,accessor,identity
ledger=json.loads((ROOT/'stylized_roster.json').read_text());audit=[]
parser=argparse.ArgumentParser();parser.add_argument('--ids',nargs='*');parser.add_argument('--revision',default='v003')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for key in (args.ids or ['M01','M05','M02','M19','M20','M03','M04','M06']):
    file=ROOT/'evidence/refinement_20261101/bipeds'/key/'candidate.json';record=json.loads(file.read_text())
    baseline=Path(record['baseline_runtime']);target=Path(record['runtime_path'])
    old,oldbin=unpack(baseline);data,binary=unpack(target);original=bytes(binary)
    def durations(d,b):return {a['name']:max(float(accessor(d,b,s['input']).max()) for s in a['samplers']) for a in d.get('animations',[])}
    expected=durations(old,oldbin);current=durations(data,original);ratios={k:expected[k]/current[k] for k in expected}
    values={};accessors={}
    for action in data['animations']:
        ratio=ratios[action['name']]
        for sampler in action['samplers']:
            index=sampler['input'];a=data['accessors'][index];view=data['bufferViews'][a['bufferView']]
            assert a['componentType']==5126 and a['type']=='SCALAR'
            if index in accessors:assert abs(accessors[index]-ratio)<1e-5
            accessors[index]=ratio
            start=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',4)
            oldvalues=accessor(data,original,index).reshape(-1)
            for i,value in enumerate(oldvalues):
                offset=start+i*stride;revised=np.float32(float(value)*ratio).tobytes()
                if offset in values:assert values[offset]==revised
                values[offset]=revised
    for offset,value in values.items():binary[offset:offset+4]=value
    for index,ratio in accessors.items():
        a=data['accessors'][index]
        for limit in ['min','max']:
            if limit in a:a[limit]=[v*ratio for v in a[limit]]
    pack(target,data,binary)
    finaldurations=durations(*unpack(target))
    assert all(abs(expected[k]-finaldurations[k])<.0001 for k in expected)
    source=Path(record['source_path']);bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
    bpy.context.scene.render.fps=24
    master=source.with_name(key+'_refined_timing_'+args.revision+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(master))
    record['previous_surface_source']=str(source);record['source_path']=str(master)
    record['source_sha256']=identity(master)['sha256'];record['runtime_sha256']=identity(target)['sha256']
    record['timing_verification']={'baseline_durations':expected,'final_durations':finaldurations,'source_fps':24,'sampled_pose_bytes_preserved':True}
    file.write_text(json.dumps(record,indent=2)+'\n')
    audit.append({'id':key,'baseline_durations':expected,'before_durations':current,'final_durations':finaldurations,'runtime_sha256':identity(target)['sha256']})
    print('TIMING_RESTORED',key,flush=True)
review_path=ROOT/'evidence/refinement_20261101/biped_timing_review.json'
previous=json.loads(review_path.read_text()).get('assets',[]) if review_path.exists() else []
rows={r['id']:r for r in previous};rows.update({r['id']:r for r in audit})
review_path.write_text(json.dumps({'assets':list(rows.values()),'scope':'Exact clip time accessor comparison; not final motion acceptance'},indent=2)+'\n')
