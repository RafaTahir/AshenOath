"""Rebake affected scenery derivatives sequentially; preserve and compare originals."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,time,sys
R=Path(__file__).resolve().parents[1];REPO=R.parents[1];G=REPO/'outputs/AshenOathTheRoadBetweenCrowns';B=REPO/'.release-gate/asset-refinement-20261101/before-world-bakes';E=R/'evidence/refinement_20261101/world_bakes';LOGS=REPO/'.release-gate/asset-refinement-20261101/world-bakes';GODOT=Path('C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe')
for p in (B,E,LOGS):p.mkdir(parents=True,exist_ok=True)

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d):p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
def identity(p):return {'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def files():return sorted(list((G/'assets_external/environment').rglob('*.res'))+list((G/'assets/landscape').glob('*.res'))+[G/'data/prepared_static_batches.res'])
def resource(p):return 'res://'+p.relative_to(G).as_posix()
env=os.environ.copy();env['APPDATA']=str(LOGS/'appdata');env['LOCALAPPDATA']=str(LOGS/'localappdata')
for p in (Path(env['APPDATA']),Path(env['LOCALAPPDATA'])):p.mkdir(parents=True,exist_ok=True)

def run(name,script,args=()):
 log=LOGS/(name+'.log');engine=LOGS/(name+'-engine.log')
 cmd=[str(GODOT),'--headless','--path',str(G),'--log-file',str(engine),'--script',script]
 if args:cmd+=['--',*args]
 with log.open('w',encoding='utf-8') as f:
  result=subprocess.run(cmd,cwd=G,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300,creationflags=subprocess.CREATE_NO_WINDOW)
 text=log.read_text(errors='replace');errors=[x for x in text.splitlines() if re.search(r'SCRIPT ERROR:|^ERROR:|Leak detected|ObjectDB instances leaked|Resources still in use',x,re.I)]
 if result.returncode or errors:raise RuntimeError(f'{name}: exit={result.returncode}; errors={errors[:8]}; {log}')
 print('WORLD_BAKE_STEP_OK',name,flush=True)
 return {'step':name,'script':script,'args':list(args),'exit_code':result.returncode,'log':str(log),'engine_log':str(engine)}

completed_receipt=E/'receipt.json'
if completed_receipt.exists():
 completed=read(completed_receipt)
 if completed['status']!='passed':raise RuntimeError('Existing dated bake needs review; preserve it rather than silently rebuilding')
 for entry in completed['source_inputs']:
  if identity(G/entry['path'].removeprefix('res://'))['sha256']!=entry['sha256']:raise RuntimeError('Source changed after this receipt; create a fresh dated candidate: '+entry['path'])
 for step in completed['steps']:
  if hashlib.sha256((G/step['script'].removeprefix('res://')).read_bytes()).hexdigest()!=step['tool_sha256']:raise RuntimeError('Constructor changed after this receipt; create a fresh dated candidate: '+step['script'])
 for entry in read(E/'output_inventory.json'):
  if identity(G/entry['path'].removeprefix('res://'))['sha256']!=entry['sha256']:raise RuntimeError('Derived output changed after this receipt: '+entry['path'])
 print('WORLD_BAKES_ALREADY_CURRENT: exact current inputs, constructors and outputs; no rerun',flush=True)
 sys.exit(0)
manifest=B/'before_files.json'
if not manifest.exists():
 before={}
 for p in files():
  dest=B/'resources'/p.relative_to(G);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest);before[resource(p)]=identity(p)
 write(manifest,before)
write(E/'resource_list.json',[resource(p) for p in files()])
if not (E/'before_semantics.json').exists():run('snapshot-before',str(R/'tools/snapshot_world_refinement_20261101.gd'),['--list='+str(E/'resource_list.json'),'--output='+str(E/'before_semantics.json')])
steps=[]
for variant in range(4):steps.append((f'house-{variant}','build_greyfen_house.gd',[f'--variant={variant}']))
for name in ['build_record_archive','build_vargan_architecture','build_assembly_court','build_campaign_wilds','build_cemetery_architecture','build_courtyard_service','build_greyfen_forge_work','build_greyfen_social','build_landscape_foundations','build_prepared_zone_geometry']:steps.append((name,name+'.gd',[]))
progress=read(E/'progress.json') if (E/'progress.json').exists() else []
for name,script,args in steps:
 if any(p['step']==name for p in progress):continue
 row=run(name,'res://tools/'+script,args);row['tool_sha256']=hashlib.sha256((G/'tools'/script).read_bytes()).hexdigest();progress.append(row);write(E/'progress.json',progress)
write(E/'resource_list.json',[resource(p) for p in files()]);run('snapshot-after',str(R/'tools/snapshot_world_refinement_20261101.gd'),['--list='+str(E/'resource_list.json'),'--output='+str(E/'after_semantics.json')])
before=read(manifest);after={resource(p):identity(p) for p in files()};bs={x['path']:x for x in read(E/'before_semantics.json')};ns={x['path']:x for x in read(E/'after_semantics.json')}
changed=[];issues=[]
def equal(a,b,tol=1e-5):
 if isinstance(a,(float,int)) and isinstance(b,(float,int)):return abs(a-b)<=tol
 if type(a)!=type(b):return False
 if isinstance(a,dict):return a.keys()==b.keys() and all(equal(a[k],b[k],tol) for k in a)
 if isinstance(a,list):return len(a)==len(b) and all(equal(x,y,tol) for x,y in zip(a,b))
 return a==b
for path,ident in after.items():
 if before.get(path)==ident:continue
 a,b=bs.get(path),ns[path];entry={'path':path,'before':before.get(path),'after':ident,'before_semantics':a,'after_semantics':b}
 if a:
  if a['class']!=b['class']:issues.append(path+': resource type changed')
  if a.get('collision_faces_sha256')!=b.get('collision_faces_sha256'):issues.append(path+': collision faces changed')
  if a.get('meta')!=b.get('meta') and not equal(a.get('meta'),b.get('meta'),.0001):issues.append(path+': non-source metadata changed')
  old_surfaces=[{k:v for k,v in s.items() if k not in ('vertices','indices','triangles')} for s in a.get('surfaces',[])]
  new_surfaces=[{k:v for k,v in s.items() if k not in ('vertices','indices','triangles')} for s in b.get('surfaces',[])]
  if not equal(old_surfaces,new_surfaces):issues.append(path+': surface names/material response/count changed')
  if a.get('bounds') and b.get('bounds'):
   av=a['bounds'];bv=b['bounds'];delta=max(abs(x-y) for key in ['position','size'] for x,y in zip(av[key]['values'],bv[key]['values']));entry['max_bounds_delta_m']=delta
   if delta>.005:issues.append(path+': visual bounds moved more than .005m: '+str(delta))
 changed.append(entry)
source=read(R/'evidence/refinement_20261101/environment/checklist.json')
changed_paths={entry['path'] for entry in changed}
inventory=[]
for path,ident in sorted(after.items()):
 semantic=ns[path]
 inventory.append(dict(path=path,**ident,**{'class':semantic['class']},triangles=semantic.get('triangles',0),surfaces=len(semantic.get('surfaces',[])),bounds=semantic.get('bounds'),changed=path in changed_paths,collision_faces_sha256=semantic.get('collision_faces_sha256')))
write(E/'output_inventory.json',inventory)
receipt={'date':'2026-11-01','status':'passed' if not issues else 'review_required','scope':'Sequential static resource constructors propagate the 28 refined OBJ sources into actual world derivatives. No journey/editor/import/gameplay acceptance.','backup':str(B),'steps':progress,'resource_count':len(after),'changed_count':len(changed),'changed_resources':changed,'issues':issues,'unchanged_undercoft_collision':bs['res://assets_external/environment/prepared/undercroft_roof_collision.res']==ns['res://assets_external/environment/prepared/undercroft_roof_collision.res'],'source_inputs':[{'path':x['resource'],'sha256':x['runtime_sha256']} for x in source['assets']],'source_population_layout_preserved':'Builder algorithms, placement/collision/population definitions and material/variant logic were not edited; semantics compared separately.','user_accepted':False}
write(E/'receipt.json',receipt)
print('WORLD_BAKES_COMPLETE',len(progress),'steps',len(changed),'changed resources','issues',len(issues),flush=True)
if issues:print('\n'.join(issues),flush=True)
