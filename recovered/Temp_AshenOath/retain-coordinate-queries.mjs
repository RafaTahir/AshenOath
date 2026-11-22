import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
const path='D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/scripts/game.gd';
const original=execFileSync('git',['show','HEAD:outputs/AshenOathTheRoadBetweenCrowns/scripts/game.gd'],{cwd:'D:/Projects/AshenOath',encoding:'utf8',maxBuffer:8e6}).replace(/\r\n/g,'\n');
let current=fs.readFileSync(path,'utf8');
const block=(text,name)=>{const from=text.search(new RegExp('^func '+name+'\\(','m'));const next=text.slice(from+1).search(/^func /m);return text.slice(from,next<0?text.length:from+1+next);};
for(const name of ['_river_center','_zone_half_extents','get_zone_half_extents','_mat','_terrain_material','_road_material','_performance_mode','_compatibility_budget_mode','_keep_performance_light','_environment_role_scale','_visual_role_for_legacy_character','should_defer_character_role','_is_interaction_removed','_world_prop_spec','_role_for_interactable','_label_for_interactable','_boss_is_resolved','_emissive_mat']) current=current.replace(block(current,name),block(original,name));
fs.writeFileSync(path,current);
// Keep only constants needed by construction code or forwarding signatures.
const facadePath=path.replace('game.gd','zone_construction_host.gd');
let facade=fs.readFileSync(facadePath,'utf8');
const constants=[...facade.matchAll(/^const (\w+)[^\n]*(?:\n(?:\t[^\n]*|[\]}][^\n]*|\s*))*\n/gm)];
let remaining=facade;
for(const constant of constants) remaining=remaining.replace(constant[0],'');
const used=new Set([...remaining.matchAll(/\b\w+\b/g)].map(v=>v[0]));
let changed=true;
while(changed){changed=false;for(const constant of constants)if(used.has(constant[1]))for(const token of constant[0].matchAll(/\b\w+\b/g))if(!used.has(token[0])){used.add(token[0]);changed=true;}}
for(const constant of constants) if(!used.has(constant[1]))facade=facade.replace(constant[0],'');
fs.writeFileSync(facadePath,facade);
console.log('Retained menu-safe coordinator queries and pruned unused construction dependencies.');
