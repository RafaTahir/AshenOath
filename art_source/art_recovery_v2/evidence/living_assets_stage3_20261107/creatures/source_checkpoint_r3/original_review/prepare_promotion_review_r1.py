"""Prepare evidence only; never import, replace, stage or promote game assets."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
ROOT=Path(r'D:/Temp/AO_LivingCast_Stages234')
ART=ROOT/'art_source/art_recovery_v2'
GAME=ROOT/'outputs/AshenOathTheRoadBetweenCrowns'
sys.path.insert(0,str(ART/'tools'))
from preserve_creature_action_bytes import read_glb,accessor_bytes,matrix
VIEWS=json.loads(r'''[{"asset":"M13","file":"Idle_25.png"},{"asset":"M13","file":"Idle_75.png"},{"asset":"M13","file":"Feed_38.png"},{"asset":"M13","file":"Sleep_50.png"},{"asset":"M07","file":"Idle_25.png"},{"asset":"M07","file":"Idle_75.png"},{"asset":"M07","file":"Feed_38.png"},{"asset":"M07","file":"Sleep_50.png"},{"asset":"M17","file":"Idle_25.png"},{"asset":"M17","file":"Idle_75.png"},{"asset":"M17","file":"Feed_38.png"},{"asset":"M17","file":"Sleep_50.png"},{"asset":"M18","file":"Idle_25.png"},{"asset":"M18","file":"Idle_75.png"},{"asset":"M18","file":"Feed_38.png"},{"asset":"M18","file":"Sleep_50.png"},{"asset":"M09","file":"Idle_25.png"},{"asset":"M09","file":"Idle_75.png"},{"asset":"M09","file":"Feed_38.png"},{"asset":"M09","file":"Sleep_50.png"},{"asset":"M10","file":"Idle_25.png"},{"asset":"M10","file":"Idle_75.png"},{"asset":"M10","file":"Feed_38.png"},{"asset":"M10","file":"Sleep_50.png"},{"asset":"M11","file":"Idle_25.png"},{"asset":"M11","file":"Idle_75.png"},{"asset":"M11","file":"Feed_38.png"},{"asset":"M11","file":"Sleep_50.png"},{"asset":"M12","file":"Idle_25.png"},{"asset":"M12","file":"Idle_75.png"},{"asset":"M12","file":"Feed_38.png"},{"asset":"M12","file":"Sleep_50.png"},{"asset":"M14","file":"Idle_25.png"},{"asset":"M14","file":"Idle_75.png"},{"asset":"M14","file":"Feed_38.png"},{"asset":"M14","file":"Sleep_50.png"},{"asset":"M08","file":"Idle_25.png"},{"asset":"M08","file":"Idle_75.png"},{"asset":"M08","file":"Feed_38.png"},{"asset":"M08","file":"Sleep_50.png"},{"asset":"M02","file":"Idle_25.png"},{"asset":"M02","file":"Idle_75.png"},{"asset":"M02","file":"Feed_38.png"},{"asset":"M02","file":"Sleep_50.png"},{"asset":"M03","file":"Idle_25.png"},{"asset":"M03","file":"Idle_75.png"},{"asset":"M03","file":"Feed_38.png"},{"asset":"M03","file":"Sleep_50.png"},{"asset":"M04","file":"Idle_25.png"},{"asset":"M04","file":"Idle_75.png"},{"asset":"M04","file":"Feed_38.png"},{"asset":"M04","file":"Sleep_50.png"},{"asset":"M05","file":"Idle_25.png"},{"asset":"M05","file":"Idle_75.png"},{"asset":"M05","file":"Feed_38.png"},{"asset":"M05","file":"Sleep_50.png"},{"asset":"M06","file":"Idle_25.png"},{"asset":"M06","file":"Idle_75.png"},{"asset":"M06","file":"Feed_38.png"},{"asset":"M06","file":"Sleep_50.png"},{"asset":"M19","file":"Idle_25.png"},{"asset":"M19","file":"Idle_75.png"},{"asset":"M19","file":"Feed_38.png"},{"asset":"M19","file":"Sleep_50.png"},{"asset":"M20","file":"Idle_25.png"},{"asset":"M20","file":"Idle_75.png"},{"asset":"M20","file":"Feed_38.png"},{"asset":"M20","file":"Sleep_50.png"},{"asset":"M18","file":"Idle_00.png"},{"asset":"M18","file":"Investigate_50.png"},{"asset":"M12","file":"Idle_00.png"},{"asset":"M12","file":"Investigate_50.png"},{"asset":"M07","file":"Investigate_50.png"},{"asset":"M05","file":"Investigate_50.png"},{"asset":"M04","file":"Feed_61.png"},{"asset":"M11","file":"Idle_00.png"}]''')
NOTES=json.loads(r'''{"M02":["Idle quarter frames show a readable small muzzle/neck change with stable broad shoulder silhouette. Feed crouches low and Sleep curls onto the side.","Feed38 and Sleep50 crop fingers/extremities at the lower frame edge; source camera is insufficient for complete hand/floor clearance review."],"M03":["Idle glance is restrained. Feed stands much more upright; Sleep is supine, so the states remain visually distinct.","Feed exposes sharp upward waist/abdominal panels; compare retained pose before classifying a new garment defect. Sleep feet are cropped; floor contact is unassessed."],"M04":["Helmet/shoulder movement is very subtle; Feed bends deeply and Sleep is supine while retaining the armor silhouette.","Sword hilt appears offset above the closed fist in Idle25/75 and Feed38/61. Verify retained versus candidate hand/socket alignment; Sleep boot tips are cropped."],"M05":["Head inclination changes slightly around the bell in idle; Feed bows toward the opening.","Sleep50 tips the bell above the supine torso with substantial visible separation; compare retained attachment and pose before acceptance. No source contact claim."],"M06":["Arms and crown shift minimally while large feet and trunk silhouette remain steady.","Feed and Sleep remain near the standing idle silhouette; full-cycle/game-distance readability is not established by these stills."],"M07":["Small wing-tip/neck changes are visible; the wing membrane silhouette remains continuous in inspected views.","All inspected states retain fully spread wings, including Sleep; the folded-wing intent is not demonstrated. Feed reads near alert idle. Held for a real wing-rest/feeding revision review."],"M08":["Quarter-phase antler/neck positions differ subtly; Sleep lowers the head/body and bends the front legs.","Feed38 head remains high and resembles idle; a feeding/contact interpretation and floor clearance need contextual/full-cycle review."],"M09":["Anterior head/jaw and body curvature differ slightly between quarter phases; Sleep lowers the broad head while ring silhouette stays continuous.","Small substrate-probe motion needs full-cycle and intended-distance review; no actual substrate contact is shown."],"M10":["Independent claw positions change while shell and support-leg silhouette remain stable; Sleep brings the claws lower.","Dark triangular openings are visible around both claw ends across frames; determine retained mesh opening versus overlap before declaring a defect. No surface contact proof."],"M11":["Fore/hind wing angles differ at opposite phases and head lowers in Sleep; the body silhouette is retained.","Fore/hind wing overlap produces a dark band already present at Idle00. Side/native motion comparison is needed to distinguish underside shadow from sheet intersection. Feed coil motion is subtle."],"M12":["Anterior suction ring and segment curvature change slightly; Sleep lowers/tilts the ring.","Sleep50 exposes a dark separation at the mouth-ring/body junction, less exposed in Idle00/25/75 and Investigate50. Retained-versus-candidate comparison required."],"M13":["Head and tail positions change subtly between quarters; Sleep visibly lowers the head and eyelids. Limbs and dorsal plates remain coherent in these views.","Feed remains close to idle at this sample. Companion scale/facing, pet/feed contact and actual floor contact remain separate unverified scopes."],"M14":["Foreleg angles change independently while the other leg silhouette is largely stable; Sleep lowers the head/chelicerae.","Long legs cross in projection and some outer extremities approach/cross the frame boundary. Actual self/floor clearance and strand contact need native/context checks."],"M17":["Left/right eye-stalk directions differ between quarters; Sleep lowers the head/stalks against the shell. No newly obvious breakup in the inspected silhouette.","Lower-feeler/Feed motion is subtle at this framing. No protective-retreat or contact acceptance is inferred from a single Sleep apex."],"M18":["Idle/Feed fin edge and tail differences are restrained; the ray body remains broadly continuous in those frames.","Sleep50 exposes a small dark slit/wedge near a dorsal eye region that is not apparent in Idle00/25/75 or Investigate50. Held for identical-camera retained/candidate comparison; no water-contact claim."],"M19":["Directional head change is visible in idle; Feed leans forward and Sleep is supine. Main body contours remain coherent.","Sleep foot tips are cropped. Off-hand reset is small and needs a full-cycle/context review; floor contact is unassessed."],"M20":["Shoulder/head changes are restrained; Feed bows and Sleep lies supine without an obvious new silhouette tear in the visible region.","Sleep extremities are cropped. Weight/readability and floor contact need full-cycle/context review."]}''')
OUT=ROOT/'.verification/creatures/promotion_review_r1'
def sha(data):return hashlib.sha256(data).hexdigest()
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def row(p):
 b=p.read_bytes();return {'path':p.relative_to(ROOT).as_posix(),'bytes':len(b),'sha256':sha(b)}
def save(name,value):
 p=OUT/name
 with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
 return row(p)
def raw_bind_bounds(path):
 doc,binary=read_glb(path);nodes=doc['nodes'];parents={}
 for i,n in enumerate(nodes):
  for c in n.get('children',[]):
   if c in parents:raise ValueError('Ambiguous node parent')
   parents[c]=i
 cache={}
 def world(i,stack=()):
  if i in stack:raise ValueError('Node cycle')
  if i not in cache:
   m=matrix(nodes[i]);assert np.isfinite(m).all()
   cache[i]=(world(parents[i],stack+(i,))@m) if i in parents else m
  return cache[i]
 meshes=[]
 for i,n in enumerate(nodes):
  if 'mesh' not in n:continue
  transform=world(i);primitives=[]
  for pi,p in enumerate(doc['meshes'][n['mesh']]['primitives']):
   a=p['attributes']['POSITION'];accessor=doc['accessors'][a]
   assert accessor['componentType']==5126 and accessor['type']=='VEC3'
   raw=accessor_bytes(doc,binary,a);v=np.frombuffer(raw,dtype='<f4').reshape(-1,3)
   assert len(v) and np.isfinite(v).all()
   w=(np.column_stack((v,np.ones(len(v))))@transform.T)[:,:3]
   primitives.append({'primitive':pi,'vertices':len(v),'position_bytes_sha256':sha(raw),
     'local_min':v.min(0).tolist(),'local_max':v.max(0).tolist(),
     'world_min':w.min(0).tolist(),'world_max':w.max(0).tolist()})
  meshes.append({'node_index':i,'node_name':n.get('name',''),'mesh_index':n['mesh'],
    'world_matrix':transform.tolist(),'skin_index':n.get('skin'),'primitives':primitives})
 skins=[]
 for s in doc.get('skins',[]):
  joints=s['joints']
  skins.append({'joints':joints,'joint_names':[nodes[i].get('name','') for i in joints],
   'joint_world_matrices':[world(i).tolist() for i in joints],
   'inverse_bind_bytes_sha256':sha(accessor_bytes(doc,binary,s['inverseBindMatrices'])) if 'inverseBindMatrices' in s else None})
 result={'scope':'Pure GLB raw neutral POSITION bounds and retained bind frames, not engine AABB/normalization/collision proof','meshes':meshes,'skins':skins}
 return result,sha(canonical(result))
def main():
 OUT.mkdir(exist_ok=False)
 viewed=[]
 for v in VIEWS:
  p=ART/'models/living_assets_stage3_20261107/creatures'/v['asset']/'source_review'/v['file']
  viewed.append({'asset':v['asset'],'frame':v['file'],**row(p),'viewed':True})
 review={'scope':'Actual fixed-camera clay PNG inspection only, no render or model changes',
   'reviewer':'asset_life_plan','files_viewed':viewed,'view_count':len(viewed),'asset_count':len(NOTES),
   'observations':{a:{'observed':n[0],'follow_up':n[1],'introduced_by_candidate':None,
    'source_preview_reviewed':True,'visual_accepted':False} for a,n in NOTES.items()},
   'explicit_visual_holds':['M07','M18'],'comparison_needed':['M04','M05','M12','M18'],
   'limitations':['Quarter-phase stills do not prove full-cycle continuity, contact or timing.',
    'No ground plane, target object, actual materials or level lighting is shown.',
    'Several extremities are cropped; absence of an observed tear is not complete clearance proof.'],
   'in_level_accepted':False,'material_accepted':False,'performance_verified':False,'user_accepted':False}
 review_row=save('source_preview_review.json',review)
 native_paths={'M01':'candidate_m01_paired_20261110_r1','M15':'candidate_m15_paired_20261110_r1','M16':'candidate_m16_20261110_r1'}
 assets=[]
 for index in range(1,21):
  asset=f'M{index:02}';folder=ART/'models/living_assets_stage3_20261107/creatures'/asset
  author_path=folder/'authoring.json';contract_path=folder/'source_contract.json'
  author=json.loads(author_path.read_text());contract=json.loads(contract_path.read_text())
  original=GAME/author['production_resource'].removeprefix('res://')
  retained=folder/(asset+'_retained_input.glb');candidate=folder/(asset+'_living_candidate.glb')
  orig_row,ret_row,cand_row=map(row,(original,retained,candidate))
  assert orig_row['sha256']==ret_row['sha256']==author['production_sha256']==contract['retained_source_sha256']
  assert cand_row['sha256']==author['candidate_sha256']==contract['candidate_sha256']
  assert contract['status']=='source_contract_pass' and contract['protected_action_bytes_equal'] is True
  before,before_hash=raw_bind_bounds(retained);after,after_hash=raw_bind_bounds(candidate)
  assert before_hash==after_hash,(asset,'raw bind bounds mismatch')
  bind_row=save(asset+'_raw_bind_bounds.json',{'asset':asset,'retained':ret_row,'candidate':cand_row,
     'retained_sha256':before_hash,'candidate_sha256':after_hash,'equal':True,'raw_bind_bounds':before})
  native={'status':'pending_remaining17_native','verified':False}
  if asset in native_paths:
   p=ROOT/'.verification/motion'/native_paths[asset]/'native.json';n=json.loads(p.read_text());e=n['native_equivalence']
   assert n['status']=='pass' and not n['failures'] and e['verified'] is True
   assert n['binding_proof']['source_sha256']==cand_row['sha256'] and e['retained_sha256']==ret_row['sha256']
   bounds={k:e[k] for k in ('aggregate_bounds','mesh_bounds','frames','rests')}
   native={'status':'exact_candidate_raw_native_pass','verified':True,'receipt':row(p),
           'raw_bind_bounds_proof_sha256':sha(canonical(bounds)),
           'prepared_role_scale_verified':False,'collision_dimensions_verified':False}
  assets.append({'asset':asset,'species':author['species'],'original':orig_row,'retained':ret_row,'candidate':cand_row,
    'authoring':row(author_path),'source_contract':row(contract_path),'source_verified':True,
    'raw_bind_bounds':{'retained_sha256':before_hash,'candidate_sha256':after_hash,'equal':True,'evidence':bind_row},
    'native_proof':native,'source_review':review['observations'].get(asset,{'source_preview_reviewed':False,'scope':'Prior separate source review; not re-reviewed in this17-unit pass'}),
    'visual_hold':asset in review['explicit_visual_holds'],'promotion_authorized':False,
    'in_level_accepted':False,'performance_verified':False,'user_accepted':False,
    'attack_profiles_recalibrated':False,'production_replaced':False})
 manifest={'schema_version':1,'scope':'Non-executable promotion preparation only; exact current candidate/source identities',
   'source_preview_review':review_row,'assets':assets,'asset_count':20,'source_verified_count':20,
   'native_proof_available_count':3,'remaining_native_count':17,'promotion_authorized':False,
   'production_replaced':False,'required_before_replacement':['Remaining17 exact native proofs',
     'Resolve per-asset visual holds/follow-ups','Explicit parent authorization for local runtime replacement',
     'Prepared role/companion scale/facing and collision proof','Attack source-profile recalibration',
     'Actual-level and performance validation before publication']}
 m=save('promotion_manifest.json',manifest)
 print(json.dumps({'review':review_row,'manifest':m,'assets':len(assets),'viewed':len(viewed),'raw_bind_bounds_equal':20,'native_proofs':3,'promotion_authorized':False}))
if __name__=='__main__':main()

