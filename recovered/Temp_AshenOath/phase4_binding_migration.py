from pathlib import Path
import re,json,sys
from collections import Counter
project=Path(r"D:/Temp/AshenOath/phase-0-architecture-ratchet-and-ci/outputs/AshenOathTheRoadBetweenCrowns/")
scripts=project/"scripts"
base=scripts/"systems/game_bindings.gd"
text=base.read_text(encoding="utf-8-sig")
sources={p.relative_to(scripts).as_posix():p.read_text(encoding="utf-8-sig") for p in scripts.rglob("*.gd")}
facade=sources["zone_construction_host.gd"]+sources["core/zone_construction_api.gd"]
overrides=set(re.findall(r"^func (\w+)",facade,re.M))
alltext="\n".join(v for k,v in sources.items() if k!="systems/game_bindings.gd")
definitions=Counter(re.findall(r"^func (\w+)\(",alltext,re.M))
mentions=Counter(re.findall(r"\b_\w+\b",alltext))
strings=set(re.findall(r"[\"'](_\w+)[\"']",alltext))
candidates=[]
for match in re.finditer(r"^func (\w+)\([^\n]*:.*_systems\[\"([^\"]+)\"\]\.(\w+)\(",text,re.M):
 name,owner,entry=match.groups()
 if name!=entry or name in overrides or name in ["configure","_gameplay_script","_create_owned_timer","_cancel_owned_timers"]: continue
 if name in strings: continue
 if definitions[name]!=1: continue
 candidates.append({"name":name,"owner":owner,"references":mentions[name]-1})
print(json.dumps(candidates))
