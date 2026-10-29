from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1]/'upstream/makehuman'
v=[]; groups={}; group=''
for line in (root/'base.obj').read_text().splitlines():
    if line.startswith('v '): v.append(list(map(float,line.split()[1:])))
    elif line.startswith('g '): group=line[2:]; groups.setdefault(group,set())
    elif line.startswith('f '): groups[group].update(int(x.split('/')[0])-1 for x in line.split()[1:])
v=np.array(v)
for name,weight in [('caucasian-female-young.target',.62),('caucasian-female-old.target',.38)]:
    for line in (root/name).read_text().splitlines():
        if not line or line.startswith('#'): continue
        index,x,y,z=line.split(); v[int(index)]+=np.array([float(x),float(y),float(z)])*weight
for name in groups:
    if 'eye' in name or name=='body':
        points=v[list(groups[name])]
        print(name, len(points), points.min(0), points.max(0), points.mean(0))
