import json,os,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parent
config=json.loads((root/'config.json').read_text())
environment=os.environ.copy()
for key,leaf in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','temp'),('TMP','temp')]:
 folder=root/'profile'/leaf;folder.mkdir(parents=True,exist_ok=True);environment[key]=str(folder)
command=[config['godot'],'--headless','--path',config['project'],'--script',str(root/'probe.gd'),'--','--output',str(root)]
with (root/'probe.log').open('w',encoding='utf-8') as log:
 result=subprocess.run(command,env=environment,stdout=log,stderr=subprocess.STDOUT,timeout=180)
print('ACTUAL WORLD LOS exit='+str(result.returncode),flush=True)
print((root/'probe.log').read_text(encoding='utf-8')[-16000:],flush=True)
raise SystemExit(result.returncode)
