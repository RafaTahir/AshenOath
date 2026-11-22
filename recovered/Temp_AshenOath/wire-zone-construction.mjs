import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
const root='D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/scripts/';
const {selected,fields}=JSON.parse(fs.readFileSync('D:/Temp/AshenOath/zone-construction-extraction.json','utf8'));
const original=execFileSync('git',['show','HEAD:outputs/AshenOathTheRoadBetweenCrowns/scripts/game.gd'],{cwd:'D:/Projects/AshenOath',encoding:'utf8',maxBuffer:8e6}).replace(/\r\n/g,'\n');
let context=fs.readFileSync(root+'zone_build_context.gd','utf8');
for(const name of selected) context=context.replaceAll('_host.'+name+'(', 'construction_host().'+name+'(');
fs.writeFileSync(root+'zone_build_context.gd',context);
let game=fs.readFileSync(root+'game.gd','utf8');
game=game.replace('var world_vfx\n','var _unbound_zone_fields := ZoneBuildContext.new_fields()\nvar world_vfx\n');
for(const name of fields){
  const match=original.match(new RegExp('^var '+name+'(?:\\s*:\\s*([\\w\\[\\]]+))?([^\\n]*)','m'));
  if(!match) throw new Error('missing field '+name);
  let type=match[1] ? ': '+match[1] : '';
  if(!type && match[2].includes(':=')) type= /:=\s*(true|false)/.test(match[2])?': bool':/new\(\)/.test(match[2])?'':': int';
  const declaration=game.match(new RegExp('^var '+name+'[^\\n]*','m'));
  if(!declaration) throw new Error('missing active field '+name);
  game=game.replace(declaration[0],`var ${name}${type}:\n\tget: return _zone_runtime_fields()["${name}"]\n\tset(value): _zone_runtime_fields()["${name}"] = value`);
}
game+='\nfunc _zone_runtime_fields() -> Dictionary:\n\treturn ZoneBuildContext.fields_for(zone_root) if is_instance_valid(zone_root) else _unbound_zone_fields\n';
fs.writeFileSync(root+'game.gd',game);
let facade=fs.readFileSync(root+'zone_construction_host.gd','utf8');
for(const name of fields){
  const match=original.match(new RegExp('^var '+name+'(?:\\s*:\\s*([\\w\\[\\]]+))?([^\\n]*)','m'));
  let type=match[1] ? ': '+match[1] : '';
  if(!type && match[2].includes(':=')) type=/^\s*:=\s*(true|false)/.test(match[2])?': bool':/new\(\)/.test(match[2])?'':': int';
  facade=facade.replace(new RegExp('^var '+name+':?$','m'),`var ${name}${type}:`);
}
// Runtime callbacks must always target the coordinator, never keep a retired facade alive.
facade=facade.replace(/(\.connect\()(_on_\w+|_enemy_attack_token)(\))/g,'$1coordinator.$2$3');
facade=facade.replace('enemy.attack_gate = _enemy_attack_token','enemy.attack_gate = coordinator._enemy_attack_token');
facade=facade.replace(/Callable\(self, "(_on_\w+)"\)/g,'Callable(coordinator, "$1")');
fs.writeFileSync(root+'zone_construction_host.gd',facade);
console.log('Wired root-owned construction fields and coordinator callbacks.');
