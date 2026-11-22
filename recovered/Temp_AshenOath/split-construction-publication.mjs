import fs from 'node:fs';
const path='D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/scripts/zone_construction_host.gd';
let text=fs.readFileSync(path,'utf8');
const start=text.indexOf('func _flush_environment_batches() -> void:');
const end=text.indexOf('\nfunc ',start+1);
const original=text.slice(start,end);
const markers=['\tpreload("res://scripts/connected_route_geometry.gd")','\tvar visual_groups: Dictionary = {}','\tfor house_key in house_batch_data:','\tfor batch_key in house_module_batch_data:','\tfor batch_key in prop_batch_data:','\tif not tree_batch_data.is_empty()','\tif not deadfall_batch_data.is_empty():'];
const offsets=markers.map(v=>original.indexOf(v));
if(offsets.some(v=>v<0)) throw new Error('Publication groups changed; manual migration required.');
let replacement='func _flush_environment_batches() -> void:\n\tfor phase in range(7):\n\t\tflush_environment_batch_step(phase)\n\nfunc flush_environment_batch_step(phase: int) -> void:\n\tif context.zone_root == null:\n\t\treturn\n\tmatch phase:\n';
for(let i=0;i<7;i++)replacement+=`\t\t${i}: _publish_environment_${i}()\n`;
replacement+='\tif phase == 6:\n\t\tenvironment_batches_flushed = true\n\n';
for(let i=0;i<7;i++){
 let body=original.slice(offsets[i],offsets[i+1]??original.indexOf('\tenvironment_batches_flushed = true')).trimEnd();
 replacement+=`func _publish_environment_${i}() -> void:\n${body}\n\n`;
}
text=text.slice(0,start)+replacement+text.slice(end);
fs.writeFileSync(path,text);
console.log('Separated seven retained geometry publication groups.');
