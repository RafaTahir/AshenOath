"""Rendered art inspection of exact production resources in an isolated profile."""
import argparse,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parents[1]/'outputs/AshenOathTheRoadBetweenCrowns'
PROJECT=Path('D:/Temp/AshenOath/asset_refinement_20261101/project')
LOGS=PROJECT.parent/'logs'
GODOT=Path('C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe')
parser=argparse.ArgumentParser();parser.add_argument('--ids',nargs='*');args=parser.parse_args()
ledger=json.loads((ROOT/'stylized_roster.json').read_text())
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
for row in ledger['assets']:
    key=row['id']
    if args.ids and key not in args.ids:continue
    assert row.get('refinement_20261101'),key+' not integrated'
    output=ROOT/'evidence/refinement_20261101/native'/key;output.mkdir(parents=True,exist_ok=True)
    record=output/'review.json'
    if record.exists() and json.loads(record.read_text()).get('asset_sha256')==row['runtime']['sha256']:
        print('CURRENT_NATIVE',key,flush=True);continue
    command=[str(GODOT),'--log-file',str(LOGS/(key+'-native-engine.log')),'--path',str(PROJECT),
        '--rendering-method','gl_compatibility','--resolution','800x800','--position','15000,15000',
        '--script',str(ROOT/'tools/review_scene.gd'),'--','--generic','--asset='+row['destination_resource'],'--output-dir='+str(output)]
    if key[0] in 'CP':command.append('--humanoid')
    log=LOGS/(key+'-native.log')
    with log.open('w',encoding='utf-8') as stream:
        result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=180,
            creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
    content=log.read_text(encoding='utf-8',errors='replace')
    errors=re.findall(r'(?m)^.*(?:SCRIPT ERROR:|^ERROR:).*$',content)
    if result.returncode or errors or not record.exists():raise RuntimeError(f'{key}: {result.returncode}; {errors[:5]}; {log}')
    assert json.loads(record.read_text())['asset_sha256']==row['runtime']['sha256']
    print('NATIVE_CAPTURED',key,flush=True)
