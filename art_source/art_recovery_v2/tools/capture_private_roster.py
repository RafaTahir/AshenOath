"""Sequentially use the existing native art viewer on the frozen private roster."""
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = Path('D:/Temp/AshenOath/stylized_review/project')
LOGS = PROJECT.parent/'logs'
GODOT = Path('C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe')
ledger = json.loads((PROJECT/'private_candidate_ledger.json').read_text())
ENVIRONMENT_NOTE = "ERROR: Can't create shader cache folder, no shader caching will happen: user://"

def art_errors(text):
    # A cache-directory failure does not affect these untimed rendered art
    # samples. Keep it disclosed; all material/rig/script failures still stop.
    return [line for line in re.findall(r'(?m)^.*(?:SCRIPT ERROR:|^ERROR:).*$',text)
            if line.strip() != ENVIRONMENT_NOTE]

for asset in ledger['assets']:
    key = asset['id']
    body = PROJECT/asset['destination_resource'].removeprefix('res://')
    sha = hashlib.sha256(body.read_bytes()).hexdigest()
    assert sha == asset['runtime']['sha256'], key+' private body changed'
    output = ROOT/'evidence/stylized'/key/'godot'
    output.mkdir(parents=True,exist_ok=True)
    record = output/'review.json'
    log = LOGS/('art-'+key+'.log')
    if record.is_file():
        prior = json.loads(record.read_text())
        clean_log = log.is_file() and not art_errors(log.read_text(encoding='utf-8',errors='replace'))
        pose_current = key not in ('C03','C04','C09','C11') or prior.get('owned_locomotion',False)
        if prior.get('asset_sha256')==sha and prior.get('walk_cycle_seconds') and prior.get('framing_source') and clean_log and pose_current:
            print('REUSE current native art capture:',key,flush=True)
            continue
    args = [GODOT,'--log-file',LOGS/('art-'+key+'-engine.log'),'--path',PROJECT,
            '--rendering-method','gl_compatibility','--resolution','800x800',
            '--script',ROOT/'tools/review_scene.gd','--','--generic',
            '--asset='+asset['destination_resource'],'--output-dir='+str(output)]
    if key[0] in ('C','P'):
        args.append('--humanoid')
    print('NATIVE ART CAPTURE:',key,flush=True)
    with log.open('w',encoding='utf-8') as stream:
        environment=os.environ.copy()
        environment['APPDATA']=str(PROJECT.parent/'appdata')
        environment['LOCALAPPDATA']=str(PROJECT.parent/'local-appdata')
        (PROJECT.parent/'appdata/Godot/app_userdata/AshenOath_Anwen_ArtReview_20261030').mkdir(parents=True,exist_ok=True)
        result = subprocess.run([str(a) for a in args],cwd=PROJECT,stdout=stream,stderr=subprocess.STDOUT,
                                timeout=150,creationflags=subprocess.CREATE_NO_WINDOW,env=environment)
    text = log.read_text(encoding='utf-8',errors='replace')
    errors = art_errors(text)
    if result.returncode or errors or not record.is_file():
        raise RuntimeError(f'{key}: exit {result.returncode}; {errors[:8]}; {log}')
    if ENVIRONMENT_NOTE in text:
        data=json.loads(record.read_text())
        data['environment_limitation']='Native shader cache directory unavailable; untimed captures completed without cache. Not performance evidence.'
        record.write_text(json.dumps(data,indent=2)+'\n')
print('33 native art captures available; visual review and user acceptance remain separate.',flush=True)
