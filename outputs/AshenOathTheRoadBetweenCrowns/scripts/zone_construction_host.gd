extends "res://scripts/core/zone_construction_api.gd"
## Explicit, root-bound construction facade; campaign services retain their existing owners.
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
const Rules = preload("res://scripts/models/zone_construction_rules.gd")
var _epoch: int = 0
const TerrainAndWaterBuilder = preload("res://scripts/builders/terrain_and_water_builder.gd")
var terrain_and_water_builder: TerrainAndWaterBuilder
const ArchitectureBatchBuilder = preload("res://scripts/builders/architecture_batch_builder.gd")
var architecture_batch_builder: ArchitectureBatchBuilder
const FoliageAndPropBuilder = preload("res://scripts/builders/foliage_and_prop_builder.gd")
var foliage_and_prop_builder: FoliageAndPropBuilder
const ZoneActorSpawner = preload("res://scripts/builders/zone_actor_spawner.gd")
var zone_actor_spawner: ZoneActorSpawner
const InteractionStationBuilder = preload("res://scripts/builders/interaction_station_builder.gd")
var interaction_station_builder: InteractionStationBuilder
const SettlementDetailBuilder = preload("res://scripts/builders/settlement_detail_builder.gd")
var settlement_detail_builder: SettlementDetailBuilder
func bind(host: Node3D, build_context: ZoneBuildContext) -> void:
	coordinator = host.coordinator if host.has_method("retire_construction_host") else host
	context = build_context
	_construction_scope = context.scope
	_epoch = context.scope.generation
	_host = coordinator
	_state = coordinator._state
	_systems = coordinator._systems
	name = "ZoneConstructionHost"
	process_mode = Node.PROCESS_MODE_DISABLED
	terrain_and_water_builder = TerrainAndWaterBuilder.new(self, context.scope)
	architecture_batch_builder = ArchitectureBatchBuilder.new(self, context.scope)
	foliage_and_prop_builder = FoliageAndPropBuilder.new(self, context.scope)
	zone_actor_spawner = ZoneActorSpawner.new(self, context.scope)
	interaction_station_builder = InteractionStationBuilder.new(self, context.scope)
	settlement_detail_builder = SettlementDetailBuilder.new(self, context.scope)
func retire_construction_host() -> void:
	context.cancel()
	queue_free()
func _run_build(action: Callable, fallback: Variant = null) -> Variant:
	return action.callv([]) if context.scope.is_current(_epoch) else fallback
func read_construction_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
	return node.get_meta(key, fallback) if is_instance_valid(node) else fallback
func write_construction_tag(node: Node, key: StringName, value: Variant) -> void:
	if is_instance_valid(node): node.set_meta(key, value)
func _connect_interactable(area: Variant, owner_root: Node3D = null, owned_cache: Array = []) -> void:
	if not context.scope.is_current(_epoch) or not is_instance_valid(area) or not context.zone_root.is_ancestor_of(area): return
	context.scope.interaction_areas.append(area)
	coordinator._connect_interactable(area, context.zone_root, context.scope.interaction_area_cache)
func _sync_camera_enemy_cache() -> void:
	if context.scope.is_current(_epoch) and coordinator.zone_root == context.zone_root: coordinator._sync_camera_enemy_cache()
func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void: _run_build(terrain_and_water_builder._make_ground.bind(pos, size, color, collision_enabled))
func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void: _run_build(terrain_and_water_builder._make_split_ground.bind(width, depth, river_z, river_span, color, bridge_width, bridge_length, bridge_approach_length))
func _make_play_area_bounds(width: float, depth: float, color: Color) -> void: _run_build(terrain_and_water_builder._make_play_area_bounds.bind(width, depth, color))
func _make_road(pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_road.bind(pos, size, color))
func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_terrain_patch.bind(name, pos, size, color))
func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_water_patch.bind(id, pos, size, color))
func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_fog_sheet.bind(pos, scale_value, color))
func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void: _run_build(terrain_and_water_builder._make_bridge_corridor_collision.bind(bridge_width, river_z, bridge_length, approach_length, zone_depth))
func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void: _run_build(terrain_and_water_builder._make_boundary_edge.bind(edge_id, width, depth, color))
func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_terrain_patch_raw.bind(name, pos, size, color))
func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3: return _run_build(terrain_and_water_builder.river_safe_position.bind(pos, margin), Vector3.ZERO)
func validate_walkable_position(pos: Vector3) -> Vector3: return _run_build(terrain_and_water_builder.validate_walkable_position.bind(pos), Vector3.ZERO)
func _river_center(zone: String = current_zone_id) -> float: return _run_build(terrain_and_water_builder._river_center.bind(zone), 0.0)
func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool: return _run_build(terrain_and_water_builder._is_river_excluded.bind(pos, margin), false)
func _route_safe_position(pos: Vector3, target_x: float) -> Vector3: return _run_build(terrain_and_water_builder._route_safe_position.bind(pos, target_x), Vector3.ZERO)
func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_low_berm.bind(pos, size, color))
func _make_invisible_wall(pos: Vector3, size: Vector3) -> void: _run_build(terrain_and_water_builder._make_invisible_wall.bind(pos, size))
func _finish_greyfen_ground_surfaces() -> void: _run_build(terrain_and_water_builder._finish_greyfen_ground_surfaces.bind())
func _finish_greyfen_paved_roads() -> void: _run_build(terrain_and_water_builder._finish_greyfen_paved_roads.bind())
func _make_road_ruts() -> void: _run_build(terrain_and_water_builder._make_road_ruts.bind())
func _make_greyfen_terrain_layers() -> void: _run_build(terrain_and_water_builder._make_greyfen_terrain_layers.bind())
func _make_wychwood_terrain_layers() -> void: _run_build(terrain_and_water_builder._make_wychwood_terrain_layers.bind())
func _make_greyfen_path_edges() -> void: _run_build(terrain_and_water_builder._make_greyfen_path_edges.bind())
func _make_wychwood_path_edges() -> void: _run_build(terrain_and_water_builder._make_wychwood_path_edges.bind())
func _make_monster_clearing(pos: Vector3) -> void: _run_build(terrain_and_water_builder._make_monster_clearing.bind(pos))
func _make_ritual_stone(pos: Vector3) -> void: _run_build(terrain_and_water_builder._make_ritual_stone.bind(pos))
func _make_rubble(pos: Vector3) -> void: _run_build(terrain_and_water_builder._make_rubble.bind(pos))
func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void: _run_build(terrain_and_water_builder._make_dark_track.bind(name, pos, size, color))
func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void: _run_build(terrain_and_water_builder._make_claw_marks.bind(name, pos, vertical))
func _make_all_evidence_safe_edge() -> void: _run_build(terrain_and_water_builder._make_all_evidence_safe_edge.bind())
func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void: _run_build(terrain_and_water_builder._make_world_wheel.bind(id, pos, radius, depth, color, rotation_degrees))
func _make_fence(pos: Vector3, vertical: bool) -> void: _run_build(terrain_and_water_builder._make_fence.bind(pos, vertical))
func _append_prepared_detail(id: String) -> void: _run_build(architecture_batch_builder._append_prepared_detail.bind(id))
func _make_prepared_prop(id: String) -> void: _run_build(architecture_batch_builder._make_prepared_prop.bind(id))
func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void: _run_build(architecture_batch_builder._make_village_house_dressed.bind(pos, yaw, node_name))
func _make_house_collision(parent: Node3D) -> void: _run_build(architecture_batch_builder._make_house_collision.bind(parent))
func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D: return _run_build(architecture_batch_builder._make_multimesh_batch.bind(node_name, mesh, count, material, use_colors), null)
func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void: _run_build(architecture_batch_builder._upload_static_batch.bind(instance, transforms, colors))
func _flush_environment_batches() -> void: _run_build(architecture_batch_builder._flush_environment_batches.bind())
func flush_environment_batch_step(phase: int) -> void: _run_build(architecture_batch_builder.flush_environment_batch_step.bind(phase))
func flush_environment_next_unit() -> bool: return _run_build(architecture_batch_builder.flush_environment_next_unit.bind(), false)
func _publish_connected_route(index: int) -> void: _run_build(architecture_batch_builder._publish_connected_route.bind(index))
func _publish_environment_0(install_routes: bool = true) -> void: _run_build(architecture_batch_builder._publish_environment_0.bind(install_routes))
func _publish_environment_1() -> void: _run_build(architecture_batch_builder._publish_environment_1.bind())
func _publish_environment_2(only_key: String = "") -> void: _run_build(architecture_batch_builder._publish_environment_2.bind(only_key))
func _publish_environment_3(only_key: String = "") -> void: _run_build(architecture_batch_builder._publish_environment_3.bind(only_key))
func _publish_environment_4(only_key: String = "") -> void: _run_build(architecture_batch_builder._publish_environment_4.bind(only_key))
func _publish_environment_5() -> void: _run_build(architecture_batch_builder._publish_environment_5.bind())
func _publish_environment_6(include_ecology: bool = true) -> void: _run_build(architecture_batch_builder._publish_environment_6.bind(include_ecology))
func _make_shrine_scene(pos: Vector3) -> void: _run_build(architecture_batch_builder._make_shrine_scene.bind(pos))
func _make_blacksmith_scene(pos: Vector3) -> void: _run_build(architecture_batch_builder._make_blacksmith_scene.bind(pos))
func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int: return _run_build(architecture_batch_builder._ensure_mesh_surface_materials.bind(mesh, fallback), 0)
func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void: _run_build(architecture_batch_builder._make_collision_box.bind(name, pos, size))
func _make_grass_tufts(points: Array, color: Color) -> void: _run_build(foliage_and_prop_builder._make_grass_tufts.bind(points, color))
func _make_path_stone(pos: Vector3, scale_value: float) -> void: _run_build(foliage_and_prop_builder._make_path_stone.bind(pos, scale_value))
func _make_tree_cluster(points: Array) -> void: _run_build(foliage_and_prop_builder._make_tree_cluster.bind(points))
func _make_tree(pos: Vector3) -> void: _run_build(foliage_and_prop_builder._make_tree.bind(pos))
func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void: _run_build(foliage_and_prop_builder._make_tree_wall.bind(axis_extent, fixed_pos, count, along_x))
func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void: _run_build(foliage_and_prop_builder._make_prop_box.bind(name, pos, size, color, render_geometry, prepared))
func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D: return _run_build(foliage_and_prop_builder._make_visual_box.bind(name, pos, size, color), null)
func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D: return _run_build(foliage_and_prop_builder._make_loose_role.bind(role_name, pos, scale_value, yaw), null)
func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D: return _run_build(foliage_and_prop_builder._make_role_visual.bind(role_name, category, scale_value), null)
func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3: return _run_build(foliage_and_prop_builder._environment_role_scale.bind(role_name, target_size), Vector3.ZERO)
func _make_deadfall(pos: Vector3) -> void: _run_build(foliage_and_prop_builder._make_deadfall.bind(pos))
func _flush_authored_tree_assets() -> bool: return _run_build(foliage_and_prop_builder._flush_authored_tree_assets.bind(), false)
func _make_crow_silhouettes() -> void: _run_build(foliage_and_prop_builder._make_crow_silhouettes.bind())
func _make_fake_fog_bank(pos: Vector3) -> void: _run_build(foliage_and_prop_builder._make_fake_fog_bank.bind(pos))
func _make_herb(id: String, pos: Vector3, color: Color) -> Variant: return _run_build(foliage_and_prop_builder._make_herb.bind(id, pos, color), null)
func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void: _run_build(foliage_and_prop_builder._make_black_feather_scatter.bind(base_name, center, count, spread))
func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color) -> Variant: return _run_build(zone_actor_spawner._make_clue.bind(id, prompt, pos, quest_id, objective_id, color), null)
func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE) -> Variant: return _run_build(zone_actor_spawner._make_named_interactable.bind(id, type, prompt, pos, color, scale_override), null)
func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3) -> Variant: return _run_build(zone_actor_spawner._make_zone_gate.bind(prompt, pos, zone_target, spawn_pos), null)
func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node: return _run_build(zone_actor_spawner._spawn_enemy.bind(id, pos, visual_role), null)
func _configure_npc_animation(mapped: Node3D, id: String) -> bool: return _run_build(zone_actor_spawner._configure_npc_animation.bind(mapped, id), false)
func should_defer_character_role(_role: String, _actor_id: String) -> bool: return _run_build(zone_actor_spawner.should_defer_character_role.bind(_role, _actor_id), false)
func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void: _run_build(zone_actor_spawner._make_token_interaction_visual.bind(area, scale_override))
func _remove_interactable(id: String) -> void: _run_build(zone_actor_spawner._remove_interactable.bind(id))
func _has_interactable(id: String) -> bool: return _run_build(zone_actor_spawner._has_interactable.bind(id), false)
func _has_living_enemy(enemy_id: String) -> bool: return _run_build(zone_actor_spawner._has_living_enemy.bind(enemy_id), false)
func _build_design_pack_ecology(only_index: int = -1) -> void: _run_build(zone_actor_spawner._build_design_pack_ecology.bind(only_index))
func _make_narrative_aftermath(zone_id: String) -> void: _run_build(zone_actor_spawner._make_narrative_aftermath.bind(zone_id))
func _make_post_ghoulkin_story_clue() -> void: _run_build(zone_actor_spawner._make_post_ghoulkin_story_clue.bind())
func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color) -> Variant: return _run_build(interaction_station_builder._make_village_place.bind(id, type, prompt, pos, size, color), null)
func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void: _run_build(interaction_station_builder._make_board_game_staging.bind(area, id, size))
func _make_board_game_solidity(area: Node3D, size: Vector3) -> bool: return _run_build(interaction_station_builder._make_board_game_solidity.bind(area, size), false)
func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void: _run_build(interaction_station_builder._make_board_game_chair.bind(area, position, yaw, batch, first_index))
func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void: _run_build(interaction_station_builder._make_ledger_interaction_visual.bind(area, scale_override))
func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void: _run_build(interaction_station_builder._make_gate_marker.bind(parent, color, scale_override))
func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void: _run_build(interaction_station_builder._apply_greyfen_well_visual.bind(visual, pos))
func _add_physical_door_visual(area: Node3D, zone_target: String) -> void: _run_build(interaction_station_builder._add_physical_door_visual.bind(area, zone_target))
func _make_interaction_label(area: Node3D, text: String, pos: Vector3, font_size: int, pixel_size: float, outlined: bool) -> void: _run_build(interaction_station_builder._make_interaction_label.bind(area, text, pos, font_size, pixel_size, outlined))
func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void: _run_build(interaction_station_builder._make_hanging_cloth.bind(pos, size, color))
func _make_wheelbarrow(pos: Vector3, yaw: float) -> void: _run_build(interaction_station_builder._make_wheelbarrow.bind(pos, yaw))
func _make_cart(pos: Vector3, include_visual: bool = true) -> void: _run_build(interaction_station_builder._make_cart.bind(pos, include_visual))
func _make_torch(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_torch.bind(pos))
func _make_village_dressing() -> void: _run_build(settlement_detail_builder._make_village_dressing.bind())
func _make_greyfen_first_impression_dressing(stage: String = "") -> void: _run_build(settlement_detail_builder._make_greyfen_first_impression_dressing.bind(stage))
func _make_quality_greyfen_overhaul() -> void: _run_build(settlement_detail_builder._make_quality_greyfen_overhaul.bind())
func _make_spawn_composition() -> void: _run_build(settlement_detail_builder._make_spawn_composition.bind())
func _make_notice_board(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_notice_board.bind(pos))
func _make_wychwood_gate_scene(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_wychwood_gate_scene.bind(pos))
func _make_route_markers() -> void: _run_build(settlement_detail_builder._make_route_markers.bind())
func _make_greyfen_road_of_crows_story_beats() -> void: _run_build(settlement_detail_builder._make_greyfen_road_of_crows_story_beats.bind())
func _make_wychwood_route_dressing() -> void: _run_build(settlement_detail_builder._make_wychwood_route_dressing.bind())
func _make_wychwood_corridor() -> void: _run_build(settlement_detail_builder._make_wychwood_corridor.bind())
func _make_wychwood_road_of_crows_story_beats() -> void: _run_build(settlement_detail_builder._make_wychwood_road_of_crows_story_beats.bind())
func _make_quality_wychwood_overhaul() -> void: _run_build(settlement_detail_builder._make_quality_wychwood_overhaul.bind())
func _make_gravestone(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_gravestone.bind(pos))
func _add_visual_100_layer(zone_id: String) -> void: _run_build(settlement_detail_builder._add_visual_100_layer.bind(zone_id))
func _install_world_prop_controller(zone_id: String) -> void: _run_build(settlement_detail_builder._install_world_prop_controller.bind(zone_id))
func _apply_first_route_materials(root: Node) -> void: _run_build(settlement_detail_builder._apply_first_route_materials.bind(root))
func _make_lantern_rhythm() -> void: _run_build(settlement_detail_builder._make_lantern_rhythm.bind())
func _make_shrine_approach() -> void: _run_build(settlement_detail_builder._make_shrine_approach.bind())
func _make_village_story_clusters() -> void: _run_build(settlement_detail_builder._make_village_story_clusters.bind())
func _make_quality_survival_cluster(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_quality_survival_cluster.bind(pos))
func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void: _run_build(settlement_detail_builder._make_lantern_post.bind(pos, shrine_style, casts_light))
func _make_firewood_stack(pos: Vector3, yaw: float) -> void: _run_build(settlement_detail_builder._make_firewood_stack.bind(pos, yaw))
func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void: _run_build(settlement_detail_builder._make_broken_fence_run.bind(pos, vertical))
func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D: return _run_build(settlement_detail_builder._make_world_prop_anchor.bind(id, kind, pos, state_key), null)
func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void: _run_build(settlement_detail_builder._make_broken_charm.bind(name, pos, yaw))
func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool: return _run_build(settlement_detail_builder._mesh_needs_visible_fallback.bind(mesh_instance), false)
func _valid_material_or_fallback(material: Material) -> Material: return _run_build(settlement_detail_builder._valid_material_or_fallback.bind(material), null)
func _make_shrine_candle(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_shrine_candle.bind(pos))
func _make_mourning_marker(pos: Vector3) -> void: _run_build(settlement_detail_builder._make_mourning_marker.bind(pos))
func _is_bad_white_material(material: Material) -> bool: return _run_build(settlement_detail_builder._is_bad_white_material.bind(material), false)
func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool: return _run_build(settlement_detail_builder._surface_has_authored_colors.bind(mesh, surface_index, material), false)
func _mat(color: Color) -> StandardMaterial3D:
	var interior_lift: bool = current_zone_id in ["record_hall", "undercroft", "old_mill"]
	var key: Variant = "flat:%s:%s" % [color.to_html(true), current_zone_id if interior_lift else "world"]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if interior_lift:
		material.emission_enabled = true
		material.emission = color.lightened(0.18)
		var lift_strength: Variant = 0.52 if current_zone_id == "record_hall" else (0.22 if current_zone_id == "old_mill" else 0.34)
		material.emission_energy_multiplier = lift_strength
	material_cache[key] = material
	return material
func _terrain_material(name: String, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var lower: Variant = name.to_lower()
		var surface: Variant = "forest_ground"
		var wetness: Variant = 0.0
		if lower.contains("mud") or lower.contains("wet") or lower.contains("cemetery"):
			surface = "wet_mud"
			wetness = 0.72
		var tint_lift: Variant = 0.34 if lower.begins_with("wychwood") or current_zone_id == "wychwood" else 0.65
		return world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), color.lightened(tint_lift), wetness, true)
	var key = "terrain:%s:%s" % [name, color.to_html()]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	if name.to_lower().contains("mud") or name.to_lower().contains("wet"):
		material.albedo_color = color.lerp(Color(0.025, 0.030, 0.026), 0.35)
		material.roughness = 0.70
	elif name.to_lower().contains("green") or name.to_lower().contains("shoulder"):
		material.albedo_color = color.lerp(Color(0.060, 0.120, 0.055), 0.24)
	material_cache[key] = material
	return material
func _road_material(paved: bool, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var road_tint: Variant = Color(0.64, 0.61, 0.56) if paved else Color(0.38, 0.31, 0.22).lerp(color, 0.15)
		return world_materials.get_material("cobblestone" if paved else "wet_mud", str(settings.settings.get("quality_preset", "balanced")), road_tint, 0.15 if paved else 0.78, true)
	var key = "road:paved" if paved else "road:mud"
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	if paved:
		material.albedo_color = color.lerp(Color(0.22, 0.20, 0.17), 0.45)
		material.roughness = 0.96
	else:
		material.albedo_color = color.lerp(Color(0.026, 0.034, 0.030), 0.55)
		material.roughness = 0.68
	material_cache[key] = material
	return material
func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
func _first_route_material(key: String) -> StandardMaterial3D:
	var cache_key = "first_route:%s" % key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var material = StandardMaterial3D.new()
	material.albedo_color = Rules.palette_color(key)
	material.roughness = 0.86
	if key == "metal":
		material.metallic = 0.35
		material.roughness = 0.52
	material_cache[cache_key] = material
	return material
func _scene_randf_range(from: float, to: float) -> float: return context.scope.rng.range_float(from, to)
func _scene_randf() -> float: return context.scope.rng.next_float()
func _performance_mode() -> bool: return settings != null and bool(settings.settings.get("potato_mode", true))
func _compatibility_budget_mode() -> bool: return settings == null or str(settings.settings.get("quality_preset", "balanced")) != "quality"
func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.has_dialogue(id):
		return dialogue.display_name(id, prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")
func _node_keyword_path(node: Node) -> String:
	var combined = ""
	var current: Node = node
	while current != null and current != zone_root:
		combined += " " + String(current.name).to_lower()
		current = current.get_parent()
	return combined
func _zone_half_extents(zone_id: String) -> Vector2: return get_zone_half_extents(zone_id)
func get_zone_half_extents(zone_id: String) -> Vector2: return SpatialSurfaceContract.zone_half_extents(zone_id)
func _zone_display_name(zone_id: String) -> String: return zone_id.replace("_", " ").capitalize()
func _is_interaction_removed(id: String) -> bool: return bool(removed_interactions.get("%s:%s" % [current_zone_id, id], false))
func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not context.scope.is_current(_epoch): return null
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.mesh = shared_box_mesh
	mesh_instance.scale = size
	mesh_instance.position = local_pos
	mesh_instance.material_override = _mat(color)
	mesh_instance.visibility_range_end = 32.0
	parent.add_child(mesh_instance)
	return mesh_instance
func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if not context.scope.is_current(_epoch): return null
	var part: Variant = MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.position = local_pos
	part.scale = scale_value
	part.rotation_degrees = rotation_degrees
	part.material_override = _mat(color)
	part.visibility_range_end = 32.0
	parent.add_child(part)
	return part
func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	if not context.scope.is_current(_epoch): return
	if _compatibility_budget_mode() and not _keep_performance_light(name):
		return
	var quality: Variant = str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	var balanced_light_cap: Variant = 4 if current_zone_id == "record_hall" else 2
	if quality == "balanced" and runtime_light_count >= balanced_light_cap:
		return
	var light = OmniLight3D.new()
	light.name = name
	light.position = pos
	light.light_color = color
	light.light_energy = energy * (1.38 if name == "BanditWarmLantern" else 1.0)
	light.omni_range = 11.0 if name == "BanditWarmLantern" else (14.0 if quality == "quality" or current_zone_id == "record_hall" or name in ["UndercroftNavigationFill", "UndercroftHalvernFill"] else 8.0)
	light.shadow_enabled = false
	zone_root.add_child(light)
	runtime_light_count += 1
func _make_pillar(pos: Vector3) -> void:
	if not context.scope.is_current(_epoch): return
	var mapped = _make_role_visual("ruins_pillar", "environment", Vector3(1.2, 1.2, 1.2))
	if mapped != null:
		mapped.position = pos
		zone_root.add_child(mapped)
		return
	var pillar = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.48
	mesh.height = 3.0
	mesh.radial_segments = 8
	pillar.mesh = mesh
	pillar.position = pos + Vector3(0, 1.5, 0)
	pillar.material_override = _mat(Color(0.27, 0.27, 0.25))
	zone_root.add_child(pillar)
func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	if not context.scope.is_current(_epoch): return
	var pool: Variant = _make_visual_box(name, pos, size, color)
	pool.set_meta("night_only_geometry", true)
func _visual_role_for_legacy_character(role_name: String) -> String: return Rules._visual_role_for_legacy_character(role_name, preload("res://scripts/story_cast_profile.gd").visual_role(role_name))
func _role_for_interactable(id: String) -> String: return Rules._role_for_interactable(id, preload("res://scripts/story_cast_profile.gd").visual_role(id))
func _world_prop_spec(id: String) -> Dictionary: return Rules._world_prop_spec(id)
func _prop_requires_collision(lower_name: String) -> bool: return Rules._prop_requires_collision(lower_name)
func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool: return Rules._is_first_route_clearance(current_zone_id, pos, radius)
func _keep_performance_light(name: String) -> bool: return Rules._keep_performance_light(name)
func _first_route_palette_key(node: Node) -> String: return Rules._first_route_palette_key(_node_keyword_path(node))

