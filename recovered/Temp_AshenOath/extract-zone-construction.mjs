import fs from 'node:fs';
const root = 'D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/scripts/';
const original = fs.readFileSync(root + 'game.gd', 'utf8').replace(/\r\n/g, '\n');
const context = fs.readFileSync(root + 'zone_build_context.gd', 'utf8').replace(/\r\n/g, '\n');
const starts = [...original.matchAll(/^func (\w+)\(/gm)];
const functions = new Map(starts.map((v, i) => [v[1], original.slice(v.index, starts[i + 1]?.index ?? original.length)]));
const runtime = new Set(['_begin_zone_world_reads', '_end_zone_world_reads', '_crow_shrine_choice_ready', '_road_ready_to_report', '_recover_from_river', '_connect_interactable', '_sync_camera_enemy_cache']);
const selected = new Set([...context.matchAll(/_host\.(_\w+)\(/g)].map(v => v[1]).filter(n => !runtime.has(n)));
for (const n of ['_add_visual_100_layer', '_install_world_prop_controller', '_flush_environment_batches', '_apply_first_route_materials', 'river_safe_position', 'validate_walkable_position']) selected.add(n);
for (const n of selected) {
  for (const call of functions.get(n)?.matchAll(/(?<![\w.])([A-Za-z_]\w*)\(/g) ?? []) {
    const name = call[1];
    if (functions.has(name) && !runtime.has(name) && !name.startsWith('_on_') && name !== '_enemy_attack_token') selected.add(name);
  }
}
const declarations = [...original.matchAll(/^(?:const|var) (\w+)[^\n]*(?:\n(?:\t[^\n]*|[\]}][^\n]*|\s*))*\n/gm)];
const declarationMap = new Map(declarations.map(v => [v[1], v[0]]));
const fields = ['active_enemies', 'interaction_candidates', 'interaction_area_cache', 'interaction_area_cache_ready', 'runtime_light_count', 'tree_batch_data', 'deadfall_batch_data', 'prop_batch_data', 'visual_box_batch_data', 'terrain_patch_batch_data', 'house_batch_data', 'house_module_batch_data', 'environment_batches_flushed', 'world_props', 'world_vfx', 'encounter_spatial_index', 'interaction_focus_dirty', 'spatial_service'];
let body = [...selected].map(n => functions.get(n)).join('\n');
const used = new Set([...body.matchAll(/\b[A-Za-z_]\w*\b/g)].map(v => v[0]));
let header = 'extends Node3D\n\n## Zone-bound construction and runtime facade. Shared campaign services remain\n## on the coordinator; mutable construction state belongs to this root.\nvar coordinator: Node\nvar context: ZoneBuildContext\n\n';
const specials = new Set([...fields, 'zone_root', 'current_zone_id', 'neighbor_building', 'scene_rng']);
for (const field of specials) {
  const type = field === 'zone_root' ? ': Node3D' : field === 'current_zone_id' ? ': String' : field === 'neighbor_building' ? ': bool' : field === 'scene_rng' ? ': RandomNumberGenerator' : '';
  const expr = field === 'zone_root' ? 'context.zone_root' : field === 'current_zone_id' ? 'context.zone_id' : field === 'neighbor_building' ? 'context.is_preparing()' : field === 'scene_rng' ? 'context.rng' : `context.owned_fields["${field}"]`;
  header += `var ${field}${type}:\n\tget: return ${expr}\n`;
  if (!['zone_root', 'current_zone_id', 'neighbor_building', 'scene_rng'].includes(field)) header += `\tset(value): context.owned_fields["${field}"] = value\n`;
}
// Constants can reference earlier constants. Preserve their exact authored values.
for (const [name, text] of declarationMap) if (text.startsWith('const ')) header += text;
for (const [name, text] of declarationMap) {
  if (!text.startsWith('var ') || specials.has(name) || !used.has(name)) continue;
  const type = text.match(/^var \w+(:\s*[\w\[\]]+)(?=\s*(?:=|:|\n))/)?.[1] ?? '';
  header += `var ${name}${type}:\n\tget: return coordinator.get("${name}")\n\tset(value): coordinator.set("${name}", value)\n`;
}
header += '\nfunc bind(host: Node, scope: ZoneBuildContext) -> void:\n\tcoordinator = host\n\tcontext = scope\n\tname = "ZoneConstructionHost"\n\tprocess_mode = Node.PROCESS_MODE_DISABLED\n\n';
header += 'func _get(property: StringName) -> Variant:\n\treturn coordinator.get(property) if is_instance_valid(coordinator) else null\n\n';
header += 'func _connect_interactable(area) -> void:\n\tcoordinator._connect_interactable(area, zone_root, interaction_area_cache)\n\n';
header += 'func _sync_camera_enemy_cache() -> void:\n\tif coordinator.zone_root == zone_root:\n\t\tcoordinator._sync_camera_enemy_cache()\n\n';
const splitArgs = s => {
  let depth = 0, quote = '', result = [], start = 0;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (quote) { if (ch === quote && s[i - 1] !== '\\') quote = ''; continue; }
    if (ch === '"' || ch === "'") quote = ch;
    else if ('([{'.includes(ch)) depth++;
    else if (')]}'.includes(ch)) depth--;
    else if (ch === ',' && depth === 0) { result.push(s.slice(start, i)); start = i + 1; }
  }
  if (s.slice(start).trim()) result.push(s.slice(start));
  return result.map(v => v.trim().match(/^(\w+)/)[1]);
};
let forwarded = '';
for (const [name, source] of functions) {
  if (selected.has(name) || ['_get', '_ready', '_process', '_physics_process', '_input', '_unhandled_input', '_notification', '_exit_tree', '_connect_interactable', '_sync_camera_enemy_cache'].includes(name)) continue;
  const line = source.slice(0, source.indexOf('\n'));
  const signature = line.match(/^func \w+\((.*)\)([^:]*):\s*$/);
  if (!signature) throw new Error('Non-single-line signature needs explicit migration: ' + line);
  const args = splitArgs(signature[1]);
  forwarded += line + '\n\t' + (signature[2].includes('void') ? '' : 'return ') + `coordinator.${name}(${args.join(', ')})\n\n`;
}
fs.writeFileSync(root + 'zone_construction_host.gd', header + '\n' + body + '\n' + forwarded);
let game = original;
for (const name of selected) {
  const source = functions.get(name);
  const line = source.slice(0, source.indexOf('\n'));
  const signature = line.match(/^func \w+\((.*)\)([^:]*):\s*$/);
  const args = splitArgs(signature[1]);
  const replacement = line + '\n\t' + (signature[2].includes('void') ? '' : 'return ') + `_zone_construction().${name}(${args.join(', ')})\n\n`;
  game = game.replace(source, replacement);
}
game += '\nfunc _zone_construction() -> Node3D:\n\treturn ZoneBuildContext.active_host(self)\n';
fs.writeFileSync(root + 'game.gd', game);
fs.writeFileSync('D:/Temp/AshenOath/zone-construction-extraction.json', JSON.stringify({selected:[...selected],fields}, null, 2));
console.log(JSON.stringify({moved: selected.size, facadeLines:(header+body+forwarded).split('\n').length, gameLines:game.split('\n').length}));
