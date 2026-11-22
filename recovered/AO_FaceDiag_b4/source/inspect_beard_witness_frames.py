"""Read existing authored bytes only; quantify raw-frame beard witnesses."""
from pathlib import Path
import importlib.util
import json
import math
import sys

ROOT = Path('D:/Temp/af')
PATH = ROOT/'art_source/art_recovery_v2/tools/face_repair_provenance.py'
spec=importlib.util.spec_from_file_location('face_provenance_readback',PATH)
h=importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)

def point(row): return (row[0],-row[2],row[1])

for cert_path in sorted((ROOT/'art_source/art_recovery_v2/models/lower_face_repair_20261111').glob('*/face_repair.json')):
    cert=json.loads(cert_path.read_text())
    old=h.Document(ROOT/cert['baseline_model']['path'])
    new=h.Document(ROOT/cert['new_glb']['path'])
    count=0
    normal_worst=(0,None)
    normal_count=0
    worst={k:(0,None) for k in ('old_normal','new_normal','barycentric','old_surface_point','new_surface_point','new_position')}
    for row in cert['allowed_edits']:
        if row['kind']=='normal_ring':
            prim=new.json['meshes'][row['mesh']]['primitives'][row['primitive']]
            pv=new.accessor(prim['attributes']['POSITION'])
            nv=new.accessor(prim['attributes']['NORMAL'])
            ids=[x[0] for x in new.accessor(prim['indices'])]
            sums={i:[0.0,0.0,0.0] for i in row['vertices']}
            for at in range(0,len(ids),3):
                tri=ids[at:at+3]
                a,b,c=[pv[i] for i in tri]
                normal=h._cross(h._subtract(b,a),h._subtract(c,a))
                for i in tri:
                    if i in sums: sums[i]=h._add(sums[i],normal)
            for i,summed in sums.items():
                expected=h._unit(summed)
                error=max(abs(x-y) for x,y in zip(expected,nv[i]))
                if error>normal_worst[0]: normal_worst=(error,{'mesh':row['mesh'],'primitive':row['primitive'],'vertex':i,'actual':nv[i],'reference':expected})
                normal_count+=1
        if row['kind']!='beard': continue
        prim=old.json['meshes'][row['mesh']]['primitives'][row['primitive']]
        before=old.accessor(prim['attributes']['POSITION'])
        after=new.accessor(prim['attributes']['POSITION'])
        for vertex,a in zip(row['vertices'],row['beard_anchors']):
            s=a['surface']
            head=old.json['meshes'][s['mesh']]['primitives'][s['primitive']]
            op=old.accessor(head['attributes']['POSITION'])
            np=new.accessor(head['attributes']['POSITION'])
            original=[point(op[i]) for i in s['vertices']]
            repaired=[point(np[i]) for i in s['vertices']]
            p=point(before[vertex])
            hit,bary=h.closest_triangle_point(p,*original)
            newhit=h._barycentric_point(bary,repaired)
            on=h._unit(h._cross(h._subtract(original[1],original[0]),h._subtract(original[2],original[0])))
            nn=h._unit(h._cross(h._subtract(repaired[1],repaired[0]),h._subtract(repaired[2],repaired[0])))
            dot=h._dot(on,nn)
            qv,qw=h._cross(on,nn),1+dot
            length=math.sqrt(h._dot(qv,qv)+qw*qw)
            qv,qw=h._scale(qv,1/length),qw/length
            off=h._subtract(p,hit)
            turn=h._cross(qv,off)
            rot=h._add(off,h._add(h._scale(turn,2*qw),h._scale(h._cross(qv,turn),2)))
            expect=h._add(newhit,rot)
            values={'old_normal':on,'new_normal':nn,'barycentric':bary,'old_surface_point':hit,'new_surface_point':newhit,'new_position':point(after[vertex])}
            for key,value in values.items():
                reference=expect if key=='new_position' else a[key]
                error=max(abs(x-y) for x,y in zip(value,reference))
                if error>worst[key][0]: worst[key]=(error,{'vertex':vertex,'surface':s,'actual':list(value),'reference':list(reference)})
            count+=1
    if count:
        print(json.dumps({'asset':cert['asset'],'beard_vertices':count,'max_abs_errors':worst},separators=(',',':')))
    print(json.dumps({'asset':cert['asset'],'normal_cells':normal_count,'max_abs_normal_error':normal_worst},separators=(',',':')))
