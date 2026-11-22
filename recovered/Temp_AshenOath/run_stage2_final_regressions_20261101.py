from pathlib import Path
import hashlib,json,os,re,subprocess,time
project=Path(r'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns')
receipt=Path(r'D:\Temp\AshenOath\stage2_final_regressions_20261101');receipt.mkdir(parents=True,exist_ok=True)
fixtures=['verify_native_attack_timing.gd','verify_cylinder_occlusion.gd','verify_oil_weakness_damage.gd','verify_story_attack_buffer.gd','verify_low_obstacle_clearance.gd','verify_blade_strike_window.gd','verify_combat_002.gd']
paths=set(project.joinpath('scripts').rglob('*.gd'))
paths.update(project.joinpath('data').rglob('*.json'))
paths.update(project.glob('*.json'))
paths.update(project/'tools'/x for x in fixtures+['verify_cylinder_combat.gd','verify_native_attack_profiles.py'])
def snapshot():return {p.relative_to(project).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(paths)}
before=snapshot();(receipt/'source-hashes-before.json').write_text(json.dumps(before,indent=2)+'\n')
print('BEFORE_HASHES',len(before),flush=True)
godot=r'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
results=[]
for name in fixtures:
 stem=Path(name).stem; env=os.environ.copy();env['APPDATA']=str(receipt/'userdata'/stem/'appdata');env['LOCALAPPDATA']=str(receipt/'userdata'/stem/'localappdata')
 args=[godot,'--headless','--path',str(project),'--script','res://tools/'+name,'--log-file',str(receipt/(stem+'.log'))]
 if name=='verify_combat_002.gd':args += ['--','--locked-bow-only']
 started=time.monotonic();print('START',name,flush=True)
 try:
  run=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
  output=run.stdout.decode('utf-8',errors='replace');code=run.returncode
 except subprocess.TimeoutExpired as ex:
  output=(ex.stdout or b'').decode('utf-8',errors='replace')+'\nFIXTURE TIMEOUT';code=-999
 (receipt/(stem+'.stdout.log')).write_text(output,encoding='utf-8')
 issues=[line for line in output.splitlines() if re.search(r'(^|\s)(SCRIPT ERROR|ERROR)(:|\s)',line)]
 passed=code==0 and not issues
 summary=[line for line in output.splitlines() if any(word in line for word in ['VERIFIER:', 'MATRIX:', 'COMBAT:', 'TIMING:', 'DAMAGE:', 'BUFFER:', 'CLEARANCE:', 'WINDOW:'])]
 result={'fixture':name,'exit_code':code,'error_lines':issues,'passed':passed,'seconds':round(time.monotonic()-started,3),'summary':summary};results.append(result)
 print(json.dumps(result),flush=True)
 if not passed: print(output[-16000:],flush=True)
python=r'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
run=subprocess.run([python,'-B',str(project/'tools/verify_native_attack_profiles.py'),'--project',str(project)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
output=run.stdout.decode('utf-8',errors='replace');(receipt/'verify_native_attack_profiles.log').write_text(output)
results.append({'fixture':'verify_native_attack_profiles.py','exit_code':run.returncode,'passed':run.returncode==0,'summary':output.splitlines()});print(output,flush=True)
after=snapshot();(receipt/'source-hashes-after.json').write_text(json.dumps(after,indent=2)+'\n')
changed=[p for p in sorted(before.keys()|after.keys()) if before.get(p)!=after.get(p)]
report={'project':str(project),'source_files':len(before),'changed_sources':changed,'results':results,'passed':not changed and all(r['passed'] for r in results)}
(receipt/'regression-results.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',json.dumps({'passed':report['passed'],'source_files':len(before),'changed_sources':changed,'passed_fixtures':sum(r['passed'] for r in results),'total_fixtures':len(results)}),flush=True)
raise SystemExit(0 if report['passed'] else 1)
