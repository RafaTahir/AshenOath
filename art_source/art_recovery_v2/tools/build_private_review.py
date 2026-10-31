"""Minimum isolated art-review compilation/package; no QA or publication path."""
import hashlib
import gzip
import json
import os
import importlib.util
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
PROJECT = Path('D:/Temp/AshenOath/stylized_review/project')
OUTPUT = PROJECT.parent
GODOT = Path('C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe')
PYTHON = Path(sys.executable)
PACKS = [('base','Base'),('opening','Opening'),('adjacent','Adjacent'),('campaign','Campaign'),
         ('characters','Characters'),('monsters','Monsters'),('audio','Audio'),('quality_materials','Quality Materials')]

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def run(name, command, timeout=3600):
    log = OUTPUT/'logs'/(name+'.log')
    log.parent.mkdir(parents=True,exist_ok=True)
    print('PRIVATE BUILD:',name,flush=True)
    if Path(command[0]) == GODOT:
        # Explicit D: log avoids the editor build's default-user-log crash.
        command = [command[0], '--log-file', OUTPUT/'logs'/(name+'-engine.log'), *command[1:]]
    with log.open('w',encoding='utf-8') as stream:
        environment=os.environ.copy()
        if Path(command[0])==GODOT:
            environment['APPDATA']=str(OUTPUT/'appdata')
            environment['LOCALAPPDATA']=str(OUTPUT/'local-appdata')
            (OUTPUT/'appdata/Godot/app_userdata/AshenOath_Anwen_ArtReview_20261030').mkdir(parents=True,exist_ok=True)
        result=subprocess.run([str(c) for c in command],cwd=PROJECT,stdout=stream,stderr=subprocess.STDOUT,
                              timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW,env=environment)
    text=log.read_text(encoding='utf-8',errors='replace')
    errors=re.findall(r'(?m)^.*(?:SCRIPT ERROR:|^ERROR:|Failed to load script|Error parsing script).*$',text)
    if result.returncode or errors:
        raise RuntimeError(f'{name}: exit {result.returncode}; compiler/resource errors={errors[:12]}; log={log}')

def record_existing_private_export(preparation, commit, build):
    # Continue the existing identity checks on the same bytes while retaining
    # explicit release-budget failures. Only the disposable snapshot supports
    # this private assessment; the repository release tooling stays strict.
    export=OUTPUT/'export'
    sys.path.insert(0,str(PROJECT/'tools'))
    spec=importlib.util.spec_from_file_location('private_transport',PROJECT/'tools/build_web_runtime_manifest.py')
    packager=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    failures=[]
    integrity=packager.inspect_packaged_export(export,private_budget_observations=failures)
    if integrity['build_id']!=build:
        raise ValueError('Private export does not match the frozen ledger')
    files=[{'path':str(p.relative_to(export)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(export.rglob('*')) if p.is_file()]
    total=sum(f['bytes'] for f in files)
    if total>=104857600:
        failures.append(f'Recovery ceiling requires below 104857600 bytes; complete private export is {total}')
    policy=json.loads((PROJECT/'data/deployment_policy.json').read_text())
    receipt={'status':'compiled_private_review_release_blocked' if failures else 'compiled_private_review_only',
        'build_id':build,'baseline_commit':commit,'source_dirty':True,'source_snapshot':str(PROJECT),
        'ledger_sha256':preparation['ledger_sha256'],'export':str(export),'files':files,'total_bytes':total,
        'identity_integrity':'passed encoded/decoded hashes, encodings and runtime-pack graph on these exact bytes',
        'strict_release_validation':'failed_budget' if failures else 'passed', 'budget_failures':failures,
        'release_eligible':False,'runtime_acceptance':'unverified','user_accepted':False,'publication_authorized':False,
        'recovery_ceiling_bytes':104857600,'recovery_ceiling_excess_bytes':max(0,total-104857599),
        'ordinary_tooling_ceiling_bytes':policy['max_deployment_bytes'],
        'deployment_warning_bytes':policy['warning_deployment_bytes'],'git_file_limit_bytes':policy['max_git_file_bytes'],
        'budget_conflict':'Unresolved. Local review is not permission to commit oversized files or publish.'}
    (OUTPUT/'private_review_build.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:receipt[k] for k in ('status','build_id','total_bytes','budget_failures','export')}),flush=True)

def main():
    if not (PROJECT/'private_review_preparation.json').is_file() or PROJECT.resolve()!=PROJECT:
        raise ValueError('Require the isolated, unredirected D: preparation snapshot')
    preparation=json.loads((PROJECT/'private_review_preparation.json').read_text())
    if preparation.get('publication_authorized') is not False or sum(i['path'].endswith('.glb') for i in preparation.get('overlays',[]))!=33:
        raise ValueError('Private snapshot must contain all 33 unaccepted candidates')
    commit=subprocess.check_output(['git','-C',str(REPO),'rev-parse','HEAD'],text=True).strip()
    build='private-stylized-'+preparation['ledger_sha256'][:12]
    if '--assess-existing-private-export' in sys.argv:
        record_existing_private_export(preparation,commit,build)
        return
    # These are resource/asset compilation commands, not scene/gameplay runs.
    if '--package-only' not in sys.argv:
        run('import',[GODOT,'--headless','--path',PROJECT,'--editor','--import','--quit'])
        run('prepared-actors',[GODOT,'--headless','--path',PROJECT,'--script','res://tools/build_prepared_actors.gd'])
        run('environment',[GODOT,'--headless','--path',PROJECT,'--script','res://tools/build_environment_dependencies.gd'])
        run('pack-layout',[PYTHON,PROJECT/'tools/prepare_runtime_pack_layout.py'])
        if '--compile-only' in sys.argv:
            print('PRIVATE ASSET COMPILATION COMPLETE; no gameplay, package or publication run',flush=True)
            return
    packdir=OUTPUT/'runtime-packs'
    packdir.mkdir(exist_ok=True)
    reuse='--reuse-packs' in sys.argv
    prior={}
    if reuse:
        previous=json.loads((packdir/'runtime_pack_candidates.json').read_text())
        if previous['candidate_ledger_sha256']!=preparation['ledger_sha256'] or previous['generated_from_commit']!=commit:
            raise ValueError('Cannot reuse packs from different candidate inputs')
        prior={row['id']:row for row in previous['packs']}
    records=[]
    for key,preset in PACKS:
        target=packdir/(key+'.pck')
        if reuse:
            if digest(target)!=prior[key]['sha256'] or target.stat().st_size!=prior[key]['bytes']:
                raise ValueError('Previously built pack changed: '+key)
        else:
            run('pack-'+key,[GODOT,'--headless','--path',PROJECT,'--export-pack','Runtime Pack '+preset,target])
        if target.read_bytes()[:4]!=b'GDPC':
            raise ValueError('Bad PCK magic: '+str(target))
        records.append({'id':key,'version':build,'preset':'Runtime Pack '+preset,'artifact':target.name,
                        'bytes':target.stat().st_size,'sha256':digest(target),'status':'private_candidate'})
    policy=json.loads((PROJECT/'data/deployment_policy.json').read_text())
    candidates={'schema_version':2,'ticket':'ART-RECOVERY-PRIVATE','build_id':build,
                'generated_at_utc':datetime.now(timezone.utc).isoformat(), 'generated_from_commit':commit,
                'source_dirty':True,'source_identity':'private snapshot plus exact ledger overlays; HEAD is baseline only',
                'candidate_ledger_sha256':preparation['ledger_sha256'],'artifact_directory':str(packdir),
                'artifacts_are_external':True,'publication_authorized':False,'max_deployment_bytes':policy['max_deployment_bytes'],
                'packs':records,'total_bytes':sum(r['bytes'] for r in records),'errors':[]}
    candidate=packdir/'runtime_pack_candidates.json'
    candidate.write_text(json.dumps(candidates,indent=2)+'\n')
    manifest=PROJECT/'runtime_pack_manifest.json'
    run('pack-manifest',[PYTHON,PROJECT/'tools/sync_runtime_pack_manifest.py',manifest,candidate,
                          '--build-id',build,'--source-commit',commit])
    export=OUTPUT/'export'
    export.mkdir(exist_ok=True)
    run('web-export',[GODOT,'--headless','--path',PROJECT,'--export-release','Web Browser',export/'index.html'])
    shutil.copy2(PROJECT/'assets_external/ui/greyfen_menu_stylized.png',export/'menu-background.png')
    (export/'packs').mkdir(exist_ok=True)
    for key,_ in PACKS:
        if key!='base':
            shutil.copy2(packdir/(key+'.pck'),export/'packs'/(key+'.pck'))
    shutil.copy2(manifest,export/manifest.name)
    # The snapshot has no published web/ sibling. Reuse the real retained
    # engine only on exact decoded equality, otherwise use bounded gzip here.
    wasm=export/'index.wasm'
    decoded=wasm.read_bytes()
    if decoded.startswith(b'\x1f\x8b'):
        decoded=gzip.decompress(decoded)
    if not decoded.startswith(b'\0asm'):
        raise ValueError('Private export lacks the WebAssembly engine')
    encoded=gzip.compress(decoded,compresslevel=9,mtime=0)
    for retained in (REPO/'web/engine').glob('*/index.wasm'):
        payload=retained.read_bytes()
        if payload.startswith(b'\x1f\x8b') and len(payload)<len(encoded) and gzip.decompress(payload)==decoded:
            encoded=payload
    if gzip.decompress(encoded)!=decoded:
        raise ValueError('Private engine transport changed decoded bytes')
    wasm.write_bytes(encoded)
    run('web-transport',[PYTHON,PROJECT/'tools/build_web_runtime_manifest.py',export,
                         '--runtime-pack-manifest',manifest,'--source-commit',commit])
    files=[{'path':str(p.relative_to(export)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(export.rglob('*')) if p.is_file()]
    total=sum(f['bytes'] for f in files)
    receipt={'status':'compiled_private_review_only','build_id':build,'baseline_commit':commit,
             'source_dirty':True,'source_snapshot':str(PROJECT),'ledger_sha256':preparation['ledger_sha256'],
             'export':str(export),'files':files,'total_bytes':total,'runtime_acceptance':'unverified',
             'user_accepted':False,'publication_authorized':False,'recovery_ceiling_bytes':104857600,
             'recovery_ceiling_excess_bytes':max(0,total-104857599),
             'ordinary_tooling_ceiling_bytes':policy['max_deployment_bytes'],
             'budget_conflict':'unresolved; private compilation does not waive the recovery publication ceiling'}
    (OUTPUT/'private_review_build.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:receipt[k] for k in ('status','build_id','total_bytes','recovery_ceiling_excess_bytes','export')}),flush=True)

if __name__=='__main__':
    main()
