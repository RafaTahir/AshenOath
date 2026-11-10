"""Bounded source diagnostic for cup handle clearance; never exports assets."""
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import closest_point_on_tri

sys.path.insert(0,str(Path(__file__).parent))
import author_merrow_cup as author
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'models/living_cast_stage2_20261107/props'
cal=json.loads((folder/'merrow_cup_calibration.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(folder/'merrow_cup.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
root=bpy.data.objects['MerrowCup']
inverse=root.matrix_world.inverted()
points=[];faces=[]
for obj in root.children:
    if obj.type!='MESH':continue
    start=len(points)
    points.extend([inverse @ obj.matrix_world @ v.co for v in obj.data.vertices])
    faces.extend([[start+i for i in p.vertices] for p in obj.data.polygons])
tree=BVHTree.FromPolygons(points,faces)
minimum=Vector([min(p[i] for p in points) for i in range(3)])
maximum=Vector([max(p[i] for p in points) for i in range(3)])
actors=[]
for obj in bpy.data.objects:
    if obj.type!='MESH' or not obj.vertex_groups:continue
    groups={g.index for g in obj.vertex_groups if g.name.endswith('_r') and g.name.startswith(('hand','thumb','index','middle','ring','pinky'))}
    ids={v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.80}
    obj.data.calc_loop_triangles()
    edges={tuple(sorted((t.vertices[i],t.vertices[(i+1)%3]))) for t in obj.data.loop_triangles for i in range(3) if any(v in ids for v in t.vertices)}
    actors.append((obj,edges))
baseline={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
hand=rig.matrix_world @ rig.pose.bones['hand_r'].matrix
original=hand.to_quaternion()
scale=hand.to_scale()
palm=Vector(cal['actual_palm']['local'])
grip=root.matrix_world @ author.xyz(cal['actual_handle_surface']['gltf'])
normal=root.matrix_world.to_quaternion() @ Vector(cal['handle_surface_normal_blender'])
fingers=root.matrix_world.to_quaternion() @ Vector((0,1,0))
results=[]
for height in (.095,):
  triangles=[[points[i] for i in face] for face in faces]
  candidates=[]
  for triangle in triangles:
    n=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
    if n.x>.9 and min(p.x for p in triangle)>.105:
      point=closest_point_on_tri(Vector((.119,.002,height)),*triangle)
      candidates.append(((point-Vector((.119,.002,height))).length,point))
  grip=root.matrix_world @ min(candidates,key=lambda x:x[0])[1]
  for roll in (0,):
    for tilt in (0,):
        for b in rig.pose.bones:b.matrix_basis=baseline[b.name].copy()
        rotation=Quaternion(normal,math.radians(roll)) @ Quaternion(fingers,math.radians(tilt)) @ original
        wrist=grip+normal*cal.get('nominal_palm_surface_clearance_m',0)-Matrix.LocRotScale(Vector(),rotation,scale).to_3x3() @ palm
        local=rig.matrix_world.inverted() @ Matrix.LocRotScale(wrist,rotation,scale)
        author.pose_hand(rig,wrist,local.to_quaternion())
        graph=bpy.context.evaluated_depsgraph_get();hits=[];hit_details=[]
        for obj,edges in actors:
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            pos=[inverse @ evaluated.matrix_world @ v.co for v in mesh.vertices]
            for a,b in edges:
                start,end=pos[a],pos[b]
                if any(max(start[i],end[i])<minimum[i] or min(start[i],end[i])>maximum[i] for i in range(3)):continue
                delta=end-start;length=delta.length
                if length<.004:continue
                hit,n,face,d=tree.ray_cast(start,delta/length,length)
                if hit is not None and .002<d<length-.002:
                    depth=min(abs(n.dot(start-hit)),abs(n.dot(end-hit)))
                    if depth>.002:
                        hits.append(depth)
                        hit_details.append({'edge':[a,b],'depth':depth,'point':list(hit),
                            'groups':[[obj.vertex_groups[g.group].name for g in obj.data.vertices[i].groups if g.weight>.2] for i in (a,b)]})
            evaluated.to_mesh_clear()
        results.append({'height':height,'roll_degrees':roll,'tilt_degrees':tilt,'crossings':len(hits),'maximum_depth':max(hits,default=0),'details':hit_details})
results.sort(key=lambda r:(r['crossings'],r['maximum_depth'],abs(r['roll_degrees'])+abs(r['tilt_degrees'])))
(folder/'merrow_cup_orientation_probe.json').write_text(json.dumps(results,indent=2)+'\n')
print('CUP_ORIENTATION_CANDIDATES',results[:10],flush=True)
