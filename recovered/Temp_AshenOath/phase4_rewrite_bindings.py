from pathlib import Path
import json,re,sys
root=Path(r"D:/Temp/AshenOath/phase-0-architecture-ratchet-and-ci/outputs/AshenOathTheRoadBetweenCrowns/scripts")
owners={x["name"]:x["owner"] for x in json.loads(Path(r"D:/Temp/AshenOath/phase4_bindings_selected.json").read_text())}
paths={"startup":"opening_startup_service","session":"session_service","zone_lifecycle":"zone_lifecycle_service","save":"save_service","world":"world_presentation_service","quest":"quest_service","dialogue":"dialogue_service","combat":"combat_coordinator","inventory":"inventory_service","interaction":"interaction_service","hud":"hud_coordinator"}
def rewrite(text,path):
 out=[]; i=0; previous=""; count=0
 while i<len(text):
  c=text[i]
  if c=="#":
   end=text.find("\n",i)
   if end<0:end=len(text)
   out.append(text[i:end]);i=end;continue
  if c in "\"'":
   delim=c*3 if text.startswith(c*3,i) else c
   end=i+len(delim)
   while end<len(text) and not text.startswith(delim,end):
    end+=2 if text[end]=="\\" else 1
   end+=len(delim)
   out.append(text[i:end]); i=end; previous="string";continue
  if c.isalpha() or c=="_":
   end=i+1
   while end<len(text) and (text[end].isalnum() or text[end]=="_"):end+=1
   token=text[i:end]
   if token in owners and previous!="func":
    owner=owners[token]
    prefix=text[max(0,i-80):i]
    already=re.search(r'_systems\[\s*["\']'+owner+r'["\']\s*\]\.$',prefix)
    local=previous!="." and path=="systems/"+paths[owner]+".gd"
    if already or local:out.append(token)
    else:
     out.append('_systems["'+owner+'"].'+token);count+=1
   else:out.append(token)
   previous=token;i=end;continue
  out.append(c)
  if not c.isspace():previous=c
  i+=1
 return "".join(out),count
changes={}
for p in root.rglob("*.gd"):
 path=p.relative_to(root).as_posix(); source=p.read_text(encoding="utf-8-sig")
 if path=="systems/game_bindings.gd":
  result=re.sub(r"^func (\w+)[^\n]*\n",lambda m:"" if m[1] in owners else m[0],source,flags=re.M)
  count=len(owners)
 else:result,count=rewrite(source,path)
 if result!=source:
  changes[path]=count
  if "--apply" in sys.argv:p.write_text(result,encoding="utf-8",newline="\n")
print(json.dumps(changes,indent=2))
