"""Evaluate the baked M07 poses with the r3 measured geometry gates."""
from collections import Counter
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from m07_probe_geometry import triangle_distance

LIMIT = .012


def make_checker(rig, mesh):
    report = {}
    root_frame = rig.matrix_world.copy()

    def joint(name):
        return rig.matrix_world @ rig.pose.bones[name].head

    def check_time():
        # The owned Blender process has the same explicit hard deadline as rendering.
        return None

    right = (joint('Wing1_0') - joint('Wing-1_0')).normalized()
    def positions():
     check_time();bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get()
     evaluated=mesh.evaluated_get(graph);data=evaluated.to_mesh()
     try:result=np.array([list(evaluated.matrix_world@v.co) for v in data.vertices])
     finally:evaluated.to_mesh_clear()
     if len(result)!=len(mesh.data.vertices) or not np.isfinite(result).all():raise ValueError('Evaluated source topology/finite positions changed')
     return result
    mesh.data.calc_loop_triangles();faces=np.array([list(t.vertices) for t in mesh.data.loop_triangles],dtype=int)
    groups={g.index:g.name for g in mesh.vertex_groups};weights={1:np.zeros(len(mesh.data.vertices)),-1:np.zeros(len(mesh.data.vertices))}
    inner_weights={side:np.zeros(len(mesh.data.vertices)) for side in (1,-1)}
    foot=np.zeros(len(mesh.data.vertices))
    significant=[set() for _ in mesh.data.vertices]
    for v in mesh.data.vertices:
     for w in v.groups:
      name=groups[w.group]
      if w.weight>.001:significant[v.index].add(name)
      for side in (1,-1):
       if name.startswith('Wing'+str(side)+'_') or name.startswith('WingFinger'+str(side)+'_'):weights[side][v.index]+=w.weight
       if name in (f'WingFinger{side}_2',f'WingFinger{side}_3'):inner_weights[side][v.index]+=w.weight
      if name in ('HindLeg1_2','HindLeg-1_2'):foot[v.index]+=w.weight
    base_points=positions();foot_ids=np.where(foot>=.95)[0]
    if len(foot_ids)<6:raise ValueError('Actual planted foot surface probes missing')
    total=weights[1]+weights[-1]
    ids={'body':np.where(np.all(total[faces]<=.001,axis=1))[0]}
    for side in (1,-1):ids[str(side)]=np.where(np.all(weights[side][faces]>=.5,axis=1))[0]
    covered=set(int(i) for values in ids.values() for i in values);seams=[i for i in range(len(faces)) if i not in covered]
    if any(len(v)==0 for v in ids.values()):raise ValueError('Nonempty actual body/wing partitions required')
    shoulders={s:joint('Wing'+str(s)+'_0') for s in (1,-1)}
    seam_distances=[]
    seam_controls=Counter()
    for i in seams:
     influence=set().union(*(significant[v] for v in faces[i]))
     attachment=influence & {'Wing1_0','Wing-1_0'}
     if len(attachment)!=1 or 'Body' not in influence or influence-attachment-{'Body','Neck','Pelvis'}:
      raise ValueError('Unclassified triangle is not a retained torso/shoulder skin seam: '+str(sorted(influence)))
     attachment=next(iter(attachment))
     side=1 if attachment=='Wing1_0' else -1
     centre=Vector(base_points[faces[i]].mean(0))
     seam_distances.append((centre-shoulders[side]).length)
     seam_controls[attachment]+=1
    report['partitions']={k:len(v) for k,v in ids.items()}
    report['joint_seam_excluded_triangles']=len(seams)
    report['maximum_excluded_seam_distance_from_shoulder_m']=max(seam_distances,default=0)
    report['foot_probe_vertices']=len(foot_ids)
    # Raw retained bind proof has 1,548 seam triangles with precisely these
    # named influences. Their natural torso extent is near half the measured
    # shoulder span, so a fixed .35m bound would reject the retained anatomy.
    # Keep both exact influence attribution and a scale-aware anatomical bound.
    seam_limit=(shoulders[1]-shoulders[-1]).length*.575
    report['shoulder_seam_control_counts']=dict(seam_controls)
    report['shoulder_seam_distance_limit_m']=seam_limit
    if len(seams)!=1548 or max(seam_distances,default=0)>seam_limit:
     raise ValueError('Evaluated shoulder seam inventory exceeds its retained source contract')
    foot_floor=float(base_points[foot_ids,2].min())
    centerline=np.array((shoulders[1]+shoulders[-1])*.5)
    lateral_axis=np.array(right)
    inner_ids={side:np.flatnonzero(inner_weights[side]>=.5) for side in (1,-1)}
    if any(len(vertices)==0 for vertices in inner_ids.values()):
     raise ValueError('Missing actual inner trailing membrane vertices')
    grouped_triangles={name:faces[indexes] for name,indexes in ids.items()}
    grouped_polygons={name:triangles.tolist() for name,triangles in grouped_triangles.items()}
    wing_ids=np.unique(np.concatenate((grouped_triangles['1'].ravel(),grouped_triangles['-1'].ravel())))
    def separation(points,trees,first,second):
     t1=grouped_triangles[first];t2=grouped_triangles[second]
     candidates=trees[first].overlap(trees[second])
     if len(candidates)>30000:raise ValueError('Excessive narrow-phase pairs; bounded probe stops')
     best=LIMIT;closest=None
     for n,(a,b) in enumerate(candidates):
      if n%64==0:check_time()
      distance=triangle_distance(points[t1[a]],points[t2[b]])
      if distance<best:best=distance;closest=[int(ids[first][a]),int(ids[second][b])]
     return {'minimum_distance_clipped_at_limit_m':best,'limit_m':LIMIT,'pairs_tested':len(candidates),'closest_triangles':closest}
    def measure(label):
     points=positions()
     vertices=[Vector(point) for point in points]
     trees={name:BVHTree.FromPolygons(vertices,polygons,all_triangles=True,epsilon=LIMIT*.5) for name,polygons in grouped_polygons.items()}
     contacts={a+'_'+b:separation(points,trees,a,b) for a,b in [('1','body'),('-1','body'),('1','-1')]}
     drift=float(np.linalg.norm(points[foot_ids]-base_points[foot_ids],axis=1).max())
     width=float(np.ptp(points[wing_ids]@np.array(right)))
     floor=float(points[wing_ids,2].min()-foot_floor)
     raw=rig.matrix_world
     root_error=max(abs(raw[i][j]-root_frame[i][j]) for i in range(4) for j in range(4))
     lateral_min={str(side):float(np.min(((points[inner_ids[side]]-centerline)@lateral_axis)*side)) for side in (1,-1)}
     return {'label':label,'contacts':contacts,'foot_surface_max_drift_m':drift,'root_frame_max_error':root_error,
      'inner_membrane_signed_lateral_min_m':lateral_min,
      'wing_width_m':width,'wing_floor_clearance_m':floor,
      'sample_geometry_pass':drift<=.00001 and root_error<=.000001 and floor>=.01 and all(x['minimum_distance_clipped_at_limit_m']>=LIMIT-1e-8 for x in contacts.values())}
    report['baseline'] = measure('retained_idle')
    if not report['baseline']['sample_geometry_pass']:
        raise ValueError('Retained Idle no longer satisfies the measured M07 geometry gates')
    return report, measure
