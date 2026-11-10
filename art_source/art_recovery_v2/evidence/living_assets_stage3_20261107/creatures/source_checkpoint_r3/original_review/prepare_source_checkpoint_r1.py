"""Read-only exact-path source checkpoint preparation; never stages or promotes."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(r'D:/Temp/AO_LivingCast_Stages234')
ART=ROOT/'art_source/art_recovery_v2'
MODEL=ART/'models/living_assets_stage3_20261107/creatures'
OUT=ROOT/'.verification/creatures/source_checkpoint_r2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 OUT.mkdir(exist_ok=False)
 paths={};units=[]
 def include(p,kind,asset=None):
  p=p.resolve()
  if not p.is_relative_to(ROOT) or not p.is_file():raise ValueError('Invalid checkpoint input: '+str(p))
  rel=p.relative_to(ROOT).as_posix()
  if rel.startswith('outputs/') or p.suffix=='.blend1':raise ValueError('Runtime/backup file forbidden')
  entry=paths.setdefault(rel,{'path':rel,'bytes':p.stat().st_size,'sha256':sha(p),'kinds':[],'assets':[]})
  if kind not in entry['kinds']:entry['kinds'].append(kind)
  if asset and asset not in entry['assets']:entry['assets'].append(asset)
 for index in range(1,21):
  a=f'M{index:02}';folder=MODEL/a;author=json.loads((folder/'authoring.json').read_text());proof=json.loads((folder/'source_contract.json').read_text())
  assert sha(folder/(a+'_living_candidate.glb'))==author['candidate_sha256']==proof['candidate_sha256']
  assert sha(folder/(a+'_retained_input.glb'))==author['production_sha256']==proof['retained_source_sha256']
  assert sha(folder/(a+'_living_v001.blend'))==author['blend_sha256']
  assert sha(folder/(a+'_living_export.glb'))==author['blender_export_sha256']
  assert proof['status']=='source_contract_pass'
  allowed={a+'_living_candidate.glb',a+'_retained_input.glb',a+'_living_export.glb',a+'_living_v001.blend','authoring.json','source_contract.json'}
  actual={p.name for p in folder.iterdir() if p.is_file()}
  if actual!=allowed:raise ValueError('Unexpected current model file inventory '+a+str(actual-allowed))
  for name in sorted(allowed):include(folder/name,'current_creature_candidate',a)
  recipe=ART/author['recipe_snapshot']['directory']
  for name,expected in author['recipe_snapshot']['files'].items():
   p=recipe/name
   if sha(p)!=expected:raise ValueError('Archived recipe mismatch')
   include(p,'immutable_recipe_snapshot',a)
  for item in author['retained_external_inputs']:
   p=ART/item['path']
   if sha(p)!=item['sha256']:raise ValueError('Archived source texture mismatch')
   include(p,'retained_texture_closure',a)
  if 'source_review_frames' in author:
   for frame in author['source_review_frames']:include(Path(frame),'unaccepted_source_preview',a)
  elif a=='M15':
   preview_dir=folder/'review_iterations/preview_r2'
   preview=json.loads((preview_dir/'preview_receipt.json').read_text())
   assert preview['candidate_sha256']==author['candidate_sha256']
   assert preview['authoring_sha256']==sha(folder/'authoring.json')
   assert preview['source_contract_sha256']==sha(folder/'source_contract.json')
   for frame in preview['frames']:
    p=folder/frame['path'];assert sha(p)==frame['sha256'];include(p,'unaccepted_source_preview',a)
   for record in preview['recipe'].values():
    p=preview_dir/record['snapshot'];assert sha(p)==record['sha256'];include(p,'immutable_preview_recipe',a)
   for name in ('preview_receipt.json','root_source_review.json','source_visual_review.json'):
    include(preview_dir/name,'separate_source_preview_evidence',a)
  else:raise ValueError('Missing current source preview receipt: '+a)
  units.append({'asset':a,'candidate_sha256':author['candidate_sha256'],'source_sha256':author['production_sha256'],
    'archived_recipe_directory':str(recipe.relative_to(ROOT).as_posix()),'source_contract_verified':True,
    'visual_accepted':False,'runtime_promotion':False,
    'live_recipe_differs_from_snapshot':[n for n,h in author['recipe_snapshot']['files'].items() if sha(ART/'tools'/n)!=h]})
 live=['author_living_creature_motion.py','living_creature_motion_profiles.py','preserve_creature_action_bytes.py',
       'graft_creature_ambient.py','verify_living_creature_motion.py','living_creature_preview.py','creature_morph_lineage.py',
       'test_creature_morph_lineage.py','test_graft_creature_ambient.py','test_preserve_creature_action_bytes.py']
 for name in live:include(ART/'tools'/name,'current_authoring_tool_or_regression')
 review=ROOT/'.verification/creatures/promotion_review_r1'
 for p in sorted(review.glob('*.json')):include(p,'current_review_and_nonexecuting_promotion_evidence')
 include(ROOT/'.verification/creatures/prepare_promotion_review_r1.py','review_manifest_generator')
 include(Path(__file__),'checkpoint_manifest_generator')
 rows=[paths[p] for p in sorted(paths)]
 if any(r['bytes']>=100*1024*1024 for r in rows):raise ValueError('Per-file release limit exceeded')
 result=subprocess.run(['git','check-ignore','--stdin'],input='\n'.join(r['path'] for r in rows)+'\n',text=True,capture_output=True,cwd=ROOT)
 if result.returncode not in (0,1):raise ValueError(result.stderr)
 ignored=set(result.stdout.splitlines())
 for row in rows:row['currently_ignored']=row['path'] in ignored
 head=subprocess.check_output(['git','rev-parse','HEAD'],text=True,cwd=ROOT).strip()
 manifest={'schema_version':1,'scope':'Source-only checkpoint preparation; no staging, runtime replacement or publication',
  'audit_head':head,'candidate_count':20,'units':units,'files':rows,'path_count':len(rows),'total_bytes':sum(r['bytes'] for r in rows),
  'maximum_file_bytes':max(r['bytes'] for r in rows),'runtime_file_count':0,'requires_exact_staged_blob_comparison':True,
  'requires_narrow_attributes_audit_before_staging':True,'ignored_paths':[r['path'] for r in rows if r['currently_ignored']],
  'review_holds':{'M02':'Runtime parentless-root anchoring diagnosis pending; source contract remains pass',
   'M07':'Wing-rest/feeding visual revision required','M18':'Sleep dorsal slit retained/candidate comparison pending'},
  'other_review_followups':['M04 hand/sword alignment','M05 Sleep bell attachment','M12 Sleep mouth-ring seam','Cropped extremities and actual floor contact'],
  'current_native_status_scope':'Only prior M01/M15/M16 proof was bound in frozen promotion manifest; remaining17 not accepted',
  'source_intent_is_not_visual_acceptance':True,'level_accepted':False,'performance_verified':False,'user_accepted':False,'promotion_authorized':False}
 with (OUT/'manifest.json').open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(manifest,indent=2)+'\n')
 with (OUT/'paths.txt').open('x',encoding='utf-8',newline='\n') as f:f.write('\n'.join(r['path'] for r in rows)+'\n')
 print(json.dumps({'manifest':str(OUT/'manifest.json'),'sha256':sha(OUT/'manifest.json'),'paths':len(rows),
  'total_bytes':manifest['total_bytes'],'max_file_bytes':manifest['maximum_file_bytes'],'ignored':len(ignored),'runtime_files':0,'audit_head':head}))
if __name__=='__main__':main()

