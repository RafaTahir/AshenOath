extends Node3D

## Zone-bound construction and runtime facade. Shared campaign services remain
## on the coordinator; mutable construction state belongs to this root.
var coordinator: Node
var context: ZoneBuildContext

var active_enemies: Array:
	get: return context.owned_fields["active_enemies"]
	set(value): context.owned_fields["active_enemies"] = value
var interaction_candidates: Array:
	get: return context.owned_fields["interaction_candidates"]
	set(value): context.owned_fields["interaction_candidates"] = value
var interaction_area_cache: Array[Area3D]:
	get: return context.owned_fields["interaction_area_cache"]
	set(value): context.owned_fields["interaction_area_cache"] = value
var interaction_area_cache_ready: bool:
	get: return context.owned_fields["interaction_area_cache_ready"]
	set(value): context.owned_fields["interaction_area_cache_ready"] = value
var runtime_light_count: int:
	get: return context.owned_fields["runtime_light_count"]
	set(value): context.owned_fields["runtime_light_count"] = value
var tree_batch_data: Array[Dictionary]:
	get: return context.owned_fields["tree_batch_data"]
	set(value): context.owned_fields["tree_batch_data"] = value
var deadfall_batch_data: Array[Transform3D]:
	get: return context.owned_fields["deadfall_batch_data"]
	set(value): context.owned_fields["deadfall_batch_data"] = value
var prop_batch_data: Dictionary:
	get: return context.owned_fields["prop_batch_data"]
	set(value): context.owned_fields["prop_batch_data"] = value
var visual_box_batch_data: Array[Dictionary]:
	get: return context.owned_fields["visual_box_batch_data"]
	set(value): context.owned_fields["visual_box_batch_data"] = value
var terrain_patch_batch_data: Array[Dictionary]:
	get: return context.owned_fields["terrain_patch_batch_data"]
	set(value): context.owned_fields["terrain_patch_batch_data"] = value
var house_batch_data: Dictionary:
	get: return context.owned_fields["house_batch_data"]
	set(value): context.owned_fields["house_batch_data"] = value
var house_module_batch_data: Dictionary:
	get: return context.owned_fields["house_module_batch_data"]
	set(value): context.owned_fields["house_module_batch_data"] = value
var environment_batches_flushed: bool:
	get: return context.owned_fields["environment_batches_flushed"]
	set(value): context.owned_fields["environment_batches_flushed"] = value
var world_props: WorldPropController:
	get: return context.owned_fields["world_props"]
	set(value): context.owned_fields["world_props"] = value
var world_vfx:
	get: return context.owned_fields["world_vfx"]
	set(value): context.owned_fields["world_vfx"] = value
var encounter_spatial_index:
	get: return context.owned_fields["encounter_spatial_index"]
	set(value): context.owned_fields["encounter_spatial_index"] = value
var interaction_focus_dirty: bool:
	get: return context.owned_fields["interaction_focus_dirty"]
	set(value): context.owned_fields["interaction_focus_dirty"] = value
var spatial_service: Node:
	get: return context.owned_fields["spatial_service"]
	set(value): context.owned_fields["spatial_service"] = value
var zone_root: Node3D:
	get: return context.zone_root
var current_zone_id: String:
	get: return context.zone_id
var neighbor_building: bool:
	get: return context.is_preparing()
var scene_rng: RandomNumberGenerator:
	get: return context.rng
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")
const Interactable = preload("res://scripts/interactable.gd")
const WorldPropController = preload("res://scripts/world_prop_controller.gd")
const InteractiveWorldProp = preload("res://scripts/interactive_world_prop.gd")
const ZoneSpatialService = preload("res://scripts/zone_spatial_service.gd")
const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")
const SeamlessWorldService = preload("res://scripts/seamless_world_service.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const BACKGROUND_RUNTIME_DELAY_SECONDS := 45.0
const ENVIRONMENT_ROLE_NORMALIZED_SIZE := {
	"greyfen_door_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_window_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_wall_facade": Vector3(1.281, 2.0, 0.260),
	"greyfen_roof": Vector3(2.935, 2.0, 3.498),
	"forest_tree": Vector3(10.563, 18.949, 9.203),
	"cart": Vector3(1.549393, 1.35, 0.543576),
	"castle_wall": Vector3(1.281, 2.0, 0.260),
	"castle_arch": Vector3(1.333, 2.0, 0.043),
	"castle_roof": Vector3(2.935, 2.0, 3.498),
	"castle_door": Vector3(0.639, 1.2, 0.069),
	"castle_bookcase": Vector3(0.689, 1.2, 0.202),
	"castle_chair": Vector3(0.620, 1.2, 0.586),
	"castle_bench": Vector3(4.8, 0.922, 0.924),
	"castle_table": Vector3(4.202, 1.2, 1.618),
	"castle_weapon_stand": Vector3(1.499505, 1.2, 1.063504),
	"castle_lantern": Vector3(0.321, 1.2, 1.169),
}
var GreyfenSocialPresentation: Script:
	get: return coordinator.get("GreyfenSocialPresentation")
	set(value): coordinator.set("GreyfenSocialPresentation", value)
var CemeteryEvidencePresentation: Script:
	get: return coordinator.get("CemeteryEvidencePresentation")
	set(value): coordinator.set("CemeteryEvidencePresentation", value)
var WychwoodEvidencePresentation: Script:
	get: return coordinator.get("WychwoodEvidencePresentation")
	set(value): coordinator.set("WychwoodEvidencePresentation", value)
var CampaignRecordPresentation: Script:
	get: return coordinator.get("CampaignRecordPresentation")
	set(value): coordinator.set("CampaignRecordPresentation", value)
var WychwoodTerrainPresentation: Script:
	get: return coordinator.get("WychwoodTerrainPresentation")
	set(value): coordinator.set("WychwoodTerrainPresentation", value)
var StoryWorldDirector: Script:
	get: return coordinator.get("StoryWorldDirector")
	set(value): coordinator.set("StoryWorldDirector", value)
var CovenantResolution: Script:
	get: return coordinator.get("CovenantResolution")
	set(value): coordinator.set("CovenantResolution", value)
var EnemyAI: Script:
	get: return coordinator.get("EnemyAI")
	set(value): coordinator.set("EnemyAI", value)
var NpcAmbient: Script:
	get: return coordinator.get("NpcAmbient")
	set(value): coordinator.set("NpcAmbient", value)
var CharacterPresentation: Script:
	get: return coordinator.get("CharacterPresentation")
	set(value): coordinator.set("CharacterPresentation", value)
var CharacterAnimationDriver: Script:
	get: return coordinator.get("CharacterAnimationDriver")
	set(value): coordinator.set("CharacterAnimationDriver", value)
var WorldMotionController: Script:
	get: return coordinator.get("WorldMotionController")
	set(value): coordinator.set("WorldMotionController", value)
var SurfaceFeedbackManager: Script:
	get: return coordinator.get("SurfaceFeedbackManager")
	set(value): coordinator.set("SurfaceFeedbackManager", value)
var WorldVFXController: Script:
	get: return coordinator.get("WorldVFXController")
	set(value): coordinator.set("WorldVFXController", value)
var BossEncounterScript: Script:
	get: return coordinator.get("BossEncounterScript")
	set(value): coordinator.set("BossEncounterScript", value)
var player:
	get: return coordinator.get("player")
	set(value): coordinator.set("player", value)
var quests:
	get: return coordinator.get("quests")
	set(value): coordinator.set("quests", value)
var dialogue:
	get: return coordinator.get("dialogue")
	set(value): coordinator.set("dialogue", value)
var story_state:
	get: return coordinator.get("story_state")
	set(value): coordinator.set("story_state", value)
var combat:
	get: return coordinator.get("combat")
	set(value): coordinator.set("combat", value)
var settings:
	get: return coordinator.get("settings")
	set(value): coordinator.set("settings", value)
var world_materials:
	get: return coordinator.get("world_materials")
	set(value): coordinator.set("world_materials", value)
var audio:
	get: return coordinator.get("audio")
	set(value): coordinator.set("audio", value)
var asset_helper:
	get: return coordinator.get("asset_helper")
	set(value): coordinator.set("asset_helper", value)
var zone_streaming:
	get: return coordinator.get("zone_streaming")
	set(value): coordinator.set("zone_streaming", value)
var seamless_world: SeamlessWorldService:
	get: return coordinator.get("seamless_world")
	set(value): coordinator.set("seamless_world", value)
var enemy_defs:
	get: return coordinator.get("enemy_defs")
	set(value): coordinator.set("enemy_defs", value)
var boss_defs:
	get: return coordinator.get("boss_defs")
	set(value): coordinator.set("boss_defs", value)
var boss_saved_states: Dictionary:
	get: return coordinator.get("boss_saved_states")
	set(value): coordinator.set("boss_saved_states", value)
var removed_interactions:
	get: return coordinator.get("removed_interactions")
	set(value): coordinator.set("removed_interactions", value)
var tutorial_flags:
	get: return coordinator.get("tutorial_flags")
	set(value): coordinator.set("tutorial_flags", value)
var material_cache: Dictionary:
	get: return coordinator.get("material_cache")
	set(value): coordinator.set("material_cache", value)
var shared_box_mesh: BoxMesh:
	get: return coordinator.get("shared_box_mesh")
	set(value): coordinator.set("shared_box_mesh", value)
var opening_well_mesh: ArrayMesh:
	get: return coordinator.get("opening_well_mesh")
	set(value): coordinator.set("opening_well_mesh", value)

func bind(host: Node, scope: ZoneBuildContext) -> void:
	coordinator = host.coordinator if host.has_method("retire_construction_host") else host
	context = scope
	name = "ZoneConstructionHost"
	process_mode = Node.PROCESS_MODE_DISABLED

func retire_construction_host() -> void:
	context.cancel()
	queue_free()

func _get(property: StringName) -> Variant:
	return coordinator.get(property) if is_instance_valid(coordinator) else null

func _set(property: StringName, value: Variant) -> bool:
	if not is_instance_valid(coordinator):
		return false
	for descriptor: Dictionary in coordinator.get_property_list():
		if descriptor.name == property:
			coordinator.set(property, value)
			return true
	return false

func _connect_interactable(area) -> void:
	coordinator._connect_interactable(area, zone_root, interaction_area_cache)

func _sync_camera_enemy_cache() -> void:
	if coordinator.zone_root == zone_root:
		coordinator._sync_camera_enemy_cache()


func _make_ground(pos: Vector3, size: Vector3, color: Color, collision_enabled: bool = true) -> void:
	var parent: Node3D = zone_root
	if collision_enabled:
		var body := StaticBody3D.new()
		body.position = pos
		zone_root.add_child(body)
		var shape := CollisionShape3D.new()
		var box := preload("res://scripts/immutable_collision_shapes.gd").box(size)
		shape.shape = box
		body.add_child(shape)
		parent = body
	var mesh := MeshInstance3D.new()
	mesh.mesh = world_materials.make_tiled_box(size, pos)
	mesh.position = Vector3.ZERO if collision_enabled else pos
	mesh.material_override = _terrain_material("CampaignGround", color)
	mesh.set_meta("split_ground_size", size)
	mesh.set_meta("split_ground_origin", pos)
	parent.add_child(mesh)


func _make_split_ground(width: float, depth: float, river_z: float, river_span: float, color: Color, bridge_width: float = 0.0, bridge_length: float = 0.0, bridge_approach_length: float = 0.0) -> void:
	var south_edge := river_z + river_span * 0.5
	var north_edge := river_z - river_span * 0.5
	var north_depth := north_edge + depth * 0.5
	var south_depth := depth * 0.5 - south_edge
	if bridge_width > 0.0 and bridge_length > 0.0 and bridge_approach_length > 0.0:
		var side_width := maxf((width - bridge_width) * 0.5, 0.1)
		var side_center := bridge_width * 0.5 + side_width * 0.5
		_make_ground(Vector3(-side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_make_ground(Vector3(side_center,-0.08,-depth*0.5+north_depth*0.5),Vector3(side_width,0.16,north_depth),color)
		_make_ground(Vector3(-side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		_make_ground(Vector3(side_center,-0.08,south_edge+south_depth*0.5),Vector3(side_width,0.16,south_depth),color)
		# The center lane is split into bank approaches and one short bridge
		# surface. Keeping these extents finite prevents a stale zone-wide box
		# from owning the bank/bridge seam and lets the visual ramp meet one
		# authoritative collision surface.
		var support_half_length := bridge_length * 0.5 + bridge_approach_length
		var north_corridor_end := river_z - support_half_length
		var north_corridor_depth := maxf(north_corridor_end + depth * 0.5, 0.0)
		if north_corridor_depth > 0.05:
			# Keep the center-lane mesh visual-only. One continuous collision slab
			# below removes the exposed vertical face at the bank/bridge seam.
			_make_ground(Vector3(0.0,-0.08,-depth*0.5+north_corridor_depth*0.5), Vector3(bridge_width,0.16,north_corridor_depth), color, false)
		var south_corridor_start := river_z + support_half_length
		var south_corridor_depth := maxf(depth * 0.5 - south_corridor_start, 0.0)
		if south_corridor_depth > 0.05:
			_make_ground(Vector3(0.0,-0.08,south_corridor_start+south_corridor_depth*0.5), Vector3(bridge_width,0.16,south_corridor_depth), color, false)
		_make_bridge_corridor_collision(bridge_width, river_z, bridge_length, bridge_approach_length, depth)
		return
	_make_ground(Vector3(0,-0.08,-depth*0.5+north_depth*0.5),Vector3(width,0.16,north_depth),color)
	_make_ground(Vector3(0,-0.08,south_edge+south_depth*0.5),Vector3(width,0.16,south_depth),color)


func _make_play_area_bounds(width: float, depth: float, color: Color) -> void:
	var half_w = width * 0.5
	var half_d = depth * 0.5
	_make_boundary_edge("north", width, depth, color)
	_make_boundary_edge("south", width, depth, color)
	_make_boundary_edge("west", width, depth, color)
	_make_boundary_edge("east", width, depth, color)


func _make_road(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "PavedRoad" if current_zone_id == "greyfen" else "MudRoad"
	var geometry_owner := "greyfen" if current_zone_id in ["greyfen", "cemetery"] else "wychwood" if current_zone_id in ["wychwood", "ruins"] else "campaign"
	mesh.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("%s_road_%s" % [geometry_owner, preload("res://scripts/prepared_zone_geometry.gd").geometry_key(size, pos)])
	mesh.position = pos
	mesh.material_override = _road_material(current_zone_id == "greyfen", color)
	zone_root.add_child(mesh)


func _make_terrain_patch(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var river_z := _river_center()
	var river_min := river_z - BridgeSurfaceContract.RIVER_HALF_SPAN
	var river_max := river_z + BridgeSurfaceContract.RIVER_HALF_SPAN
	var patch_min := pos.z - size.z * 0.5
	var patch_max := pos.z + size.z * 0.5
	if river_z < SpatialSurfaceContract.NO_RIVER and patch_min < river_max and patch_max > river_min:
		if patch_min < river_min:
			var north_size := river_min - patch_min
			_make_terrain_patch_raw("%s_NorthBank" % name, Vector3(pos.x,pos.y,patch_min+north_size*0.5), Vector3(size.x,size.y,north_size), color)
		if patch_max > river_max:
			var south_size := patch_max - river_max
			_make_terrain_patch_raw("%s_SouthBank" % name, Vector3(pos.x,pos.y,river_max+south_size*0.5), Vector3(size.x,size.y,south_size), color)
		return
	_make_terrain_patch_raw(name,pos,size,color)


func _make_grass_tufts(points: Array, color: Color) -> void:
	var safe_points: Array = []
	for point in points:
		if not _is_river_excluded(point,0.25) and (spatial_service == null or not spatial_service.is_reserved(point, 0.25)):
			safe_points.append(point)
	if safe_points.is_empty():
		return
	if _performance_mode() and int(settings.settings.get("foliage_density", 0)) <= 0:
		return
	var batch = MultiMeshInstance3D.new()
	batch.name = "GrassBatch"
	var blade_mesh = QuadMesh.new()
	blade_mesh.size = Vector2(0.82, 1.0)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = safe_points.size() * 3
	var instance_index = 0
	for raw_pos in safe_points:
		var pos: Vector3 = raw_pos
		for i: int in range(3):
			var height: float = _scene_randf_range(0.34, 0.72)
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, float(i) * PI / 3.0 + _scene_randf_range(-0.12, 0.12))
			basis = basis.scaled(Vector3(_scene_randf_range(0.82, 1.16), height, 1.0))
			var offset = Vector3(_scene_randf_range(-0.16, 0.16), height * 0.5, _scene_randf_range(-0.16, 0.16))
			multimesh.set_instance_transform(instance_index, Transform3D(basis, pos + offset))
			instance_index += 1
	batch.multimesh = multimesh
	batch.material_override = world_materials.get_grass_material(str(settings.settings.get("quality_preset", "balanced")))
	batch.visibility_range_end = 30.0
	zone_root.add_child(batch)


func _make_path_stone(pos: Vector3, scale_value: float) -> void:
	_make_terrain_patch("PathStone", pos + Vector3(0, 0.03, 0), Vector3(scale_value, 0.06, scale_value * 0.75), Color(0.18, 0.17, 0.15))


func _make_world_wheel(id: String, pos: Vector3, radius: float, depth: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = id
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = radius
	wheel_mesh.bottom_radius = radius
	wheel_mesh.height = depth
	wheel_mesh.radial_segments = 16
	wheel.mesh = wheel_mesh
	wheel.position = pos
	wheel.rotation_degrees = rotation_degrees
	wheel.material_override = world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), color, 0.0, true)
	wheel.set_meta("world_prop_kind", "mill_wheel")
	zone_root.add_child(wheel)
	var hub := MeshInstance3D.new()
	hub.name = "%sHub" % id
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.17
	hub_mesh.bottom_radius = radius * 0.17
	hub_mesh.height = depth * 1.18
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.position = pos
	hub.rotation_degrees = rotation_degrees
	hub.material_override = world_materials.get_material("metal", str(settings.settings.get("quality_preset", "balanced")), Color(0.20, 0.18, 0.14), 0.0, false)
	zone_root.add_child(hub)


func _make_water_patch(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var water := MeshInstance3D.new()
	water.name = id
	var water_mesh := BoxMesh.new()
	water_mesh.size = size
	water.mesh = water_mesh
	water.position = pos
	var material: StandardMaterial3D = world_materials.get_material("water", str(settings.settings.get("quality_preset", "balanced")), color, 1.0, true).duplicate() as StandardMaterial3D
	material.roughness = 0.24
	material.metallic = 0.08
	material.emission_enabled = true
	material.emission = color.lightened(0.12)
	material.emission_energy_multiplier = 0.16
	water.material_override = material
	water.set_meta("world_prop_kind", "marsh_water")
	water.set_meta("non_walkable_visual_only", true)
	zone_root.add_child(water)


func _make_fog_sheet(pos: Vector3, scale_value: Vector3, color: Color) -> void:
	if settings != null and str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	if _performance_mode() and current_zone_id == "greyfen":
		return
	if _performance_mode() and _scene_randf() < 0.45:
		return
	var fog = MeshInstance3D.new()
	fog.mesh = PlaneMesh.new()
	fog.position = pos
	fog.scale = scale_value
	fog.rotation_degrees.x = 90
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog.material_override = material
	zone_root.add_child(fog)


func _make_light(name: String, pos: Vector3, color: Color, energy: float) -> void:
	if _compatibility_budget_mode() and not _keep_performance_light(name):
		return
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	# Two authored local pools preserve route landmarks without multiplying
	# Compatibility-renderer lighting work across the entire outdoor frame.
	var balanced_light_cap := 4 if current_zone_id == "record_hall" else 2
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


func _make_torch(pos: Vector3) -> void:
	_make_prop_box("TorchPost", pos + Vector3(0, 0.85, 0), Vector3(0.13, 1.7, 0.13), Color(0.10, 0.06, 0.035))
	var flame = MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.10, 0.18, 0.10)
	flame.position = pos + Vector3(0, 1.75, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.45, 0.14), 1.4)
	flame.set_meta("world_prop_kind", "flame")
	flame.set_meta("world_prop_id", "torch_flame")
	zone_root.add_child(flame)
	_make_light("BanditWarmLantern" if current_zone_id == "bandit_road" else "TorchLight", pos + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.16), 1.45)


func _make_tree_cluster(points: Array) -> void:
	for pos in points:
		_make_tree(pos)


func _make_tree(pos: Vector3) -> void:
	# Gate and bridge corridors are reserved before scenery is authored. Keep the
	# original request out of those volumes instead of nudging it back into the
	# player route with _route_safe_position().
	# Greyfen's cemetery is a composed investigation site. The boundary wall
	# and village cluster otherwise place full tree crowns over its bell and
	# chapel, despite their trunks sitting outside the walkable court.
	if current_zone_id == "greyfen" and pos.x > 10.0 and pos.z > 7.5 and pos.z < 18.0:
		return
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
	if _is_river_excluded(pos,1.5):
		return
	pos = _route_safe_position(pos, 4.9)
	if spatial_service != null and spatial_service.is_reserved(pos, 1.35):
		return
	if _is_first_route_clearance(pos, 1.55):
		return
	if current_zone_id == "greyfen":
		for house in get_tree().get_nodes_in_group("greyfen_house"):
			if not zone_root.is_ancestor_of(house):
				continue
			var house_position: Vector3 = zone_root.to_local((house as Node3D).global_position)
			if Vector2(pos.x, pos.z).distance_to(Vector2(house_position.x, house_position.z)) < 5.5:
				return
	var radius := _scene_randf_range(1.0, 1.35)
	pos = WorldSectorManifest.clear_connector_position(current_zone_id,pos,1.35)
	if spatial_service != null:
		spatial_service.add_presence_landmark("shelter", pos, 0.7)
	var height := _scene_randf_range(2.0, 2.7)
	var yaw := _scene_randf_range(0.0, TAU)
	var tree_role := "forest_tree"
	# Keep most trees on the primary source, but reserve a small deterministic
	# share for a second silhouette so the forest reads as varied rather than
	# as one repeated wall. Both roles use the same licensed nature pack.
	var variant_selector := int(absf(pos.x * 17.0 + pos.z * 31.0))
	if variant_selector % 4 == 0:
		tree_role = "forest_tree_variant"
	elif current_zone_id == "wychwood":
		tree_role = "forest_tree_secondary"
	tree_batch_data.append({
		"trunk": Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.9, 0)),
		"crown": Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(radius, height, radius)), pos + Vector3(0, 2.35, 0)),
		"asset_position": pos,
		"asset_scale": Vector3(radius * 0.88, height * 0.38, radius * 0.88),
		"asset_yaw": yaw,
		"asset_role": tree_role,
		"color": Color(0.055, 0.18, 0.085).lerp(Color(0.13, 0.24, 0.11), _scene_randf())
	})
	var tree_body := ZoneBuildContext.collision_batch(zone_root, "BatchedTreeCollisions")
	var shape := CollisionShape3D.new()
	var box := preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(0.58, 3.6, 0.58))
	shape.shape = box
	shape.position = pos + Vector3(0, 2.1, 0)
	tree_body.add_child(shape)


func _make_tree_wall(axis_extent: float, fixed_pos: float, count: int, along_x: bool) -> void:
	for i in range(count):
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var offset: float = lerp(-axis_extent, axis_extent, t)
		var pos = Vector3(offset, 0, fixed_pos) if along_x else Vector3(fixed_pos, 0, offset)
		_make_tree(pos + Vector3(_scene_randf_range(-0.8, 0.8), 0, _scene_randf_range(-0.5, 0.5)))


func _make_pillar(pos: Vector3) -> void:
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


func _make_prop_box(name: String, pos: Vector3, size: Vector3, color: Color, render_geometry: bool = true, prepared: Dictionary = {}) -> void:
	var authored_prop_ids: Array = zone_root.get_meta("authored_prop_ids", [])
	if name not in authored_prop_ids:
		authored_prop_ids.append(name)
		zone_root.set_meta("authored_prop_ids", authored_prop_ids)
	# Authored cemetery landmarks are deliberately fitted against the chapel
	# shell. Do not run them through actor recovery: nearby chapel geometry would
	# relocate the prop and the reserved-route check would then discard it.
	var preserve_authored_position := name in ["OssuarySealedDoor", "CemeteryCrowShrine", "GreyfenRiverShoreStone"]
	if name not in ["NorthBerm","SouthBerm","WestBerm","EastBerm"] and not preserve_authored_position:
		pos = river_safe_position(pos,size.z*0.5+0.15)
	# Solid scenery must yield to registered route and gate clearances. This is
	# deliberately applied before the shared collision batch receives a shape.
	# Decorative gate landmarks can be rebuilt around the opening by their caller.
	if spatial_service != null and spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
		return
	var lower := name.to_lower()
	var separate_body := name in ["NorthBerm","SouthBerm","WestBerm","EastBerm"]
	if spatial_service != null and (lower.contains("crate") or lower.contains("barrel") or lower.contains("camp")):
		spatial_service.add_presence_landmark("camp", Vector3(pos.x, 0, pos.z), maxf(size.x, size.z) * 0.5)
	# Thin seams, ledges, trim, and surface dressing are visual detail rather
	# than walkable blockers. Avoid creating hundreds of tiny physics shapes for
	# them; major walls, buildings, fences, and route props retain authoritative
	# collision below the detail threshold.
	# Torch and lantern posts are visual route dressing. Their tiny collision
	# footprints create disproportionate capsule snags at diagonal approaches,
	# especially where a player is following a validated sector edge lane.
	var decorative_only := name == "GreyfenRiverShoreStone" \
		or (size.y <= 0.28 and not _prop_requires_collision(lower)) \
		or lower.contains("torch") or lower.contains("lantern")
	var body: StaticBody3D = null
	if not decorative_only and separate_body:
		body = StaticBody3D.new()
		body.name = name
		body.position = pos
		zone_root.add_child(body)
	elif not decorative_only:
		body = ZoneBuildContext.collision_batch(zone_root, "BatchedPropCollisions")
	if not decorative_only:
		var shape := CollisionShape3D.new()
		shape.name = "%sCollision" % name
		var box := preload("res://scripts/immutable_collision_shapes.gd").box(size)
		shape.shape = box
		if not separate_body:
			shape.position = pos
		body.add_child(shape)
	if not render_geometry:
		return
	if current_zone_id in ["greyfen", "wychwood", "deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "assembly", "hart_glade"] and separate_body and body != null:
		var bank := MeshInstance3D.new()
		bank.name = "WeatheredLandscapeBoundary"
		bank.mesh = world_materials.make_forest_berm(size, pos)
		bank.material_override = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), color.lightened(0.22), 0.0, false)
		body.add_child(bank)
		return
	if lower.contains("glow") or lower.contains("window") or lower.contains("coal") or lower.contains("candle"):
		var mesh := MeshInstance3D.new()
		mesh.mesh = shared_box_mesh
		mesh.scale = size
		mesh.material_override = _emissive_mat(color, 0.65)
		if separate_body and body != null:
			body.add_child(mesh)
		else:
			mesh.position = pos
			zone_root.add_child(mesh)
	else:
		var surface := "plaster"
		if lower.contains("roof"):
			surface = "roof_tiles"
		elif lower.contains("wood") or lower.contains("door") or lower.contains("fence") or lower.contains("rail") or lower.contains("post") or lower.contains("board") or lower.contains("cart") or lower.contains("crate") or lower.contains("barrel"):
			surface = "timber"
		elif lower.contains("stone") or lower.contains("wall") or lower.contains("grave") or lower.contains("foundation") or lower.contains("chimney") or lower.contains("rubble"):
			surface = "medieval_brick"
		elif lower.contains("berm") or lower.contains("moss"):
			surface = "forest_ground"
		# Preserve authored colour language when props are batched. The old
		# surface-only key reused one pale material for every wall, roof, and
		# timber piece, making Castle interiors read as blank white blocks. Keep
		# the shared surface textures, but quantize the tint into a small number of
		# cache-friendly variants so repeated geometry still batches efficiently.
		var surface_base := Color(0.72, 0.70, 0.66)
		var surface_tint := surface_base.lerp(color, 0.58)
		var tint_key := "%d_%d_%d" % [int(surface_tint.r * 8.0), int(surface_tint.g * 8.0), int(surface_tint.b * 8.0)]
		var batch_key := "%s_%s" % [surface, tint_key]
		var material = world_materials.get_material(surface, str(settings.settings.get("quality_preset", "balanced")), surface_tint, 0.15 if surface == "wet_mud" else 0.0, true)
		if not prop_batch_data.has(batch_key):
			prop_batch_data[batch_key] = {"material": material, "transforms": []}
		prop_batch_data[batch_key].transforms.append(prepared if not prepared.is_empty() and pos == prepared.position else Transform3D(Basis.IDENTITY.scaled(size), pos))


func _make_visual_box(name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	# Long interior trim spans most of a room. Passing its half-depth through the
	# outdoor occupancy clamp can move authored pilasters and rafters into the
	# central aisle, where they become camera-blocking slabs. Interior zones have
	# no river crossing to protect, so retain their authored placement.
	var preserve_interior_position: bool = current_zone_id in ["record_hall", "undercroft"]
	if not preserve_interior_position:
		pos = river_safe_position(pos, size.z * 0.5 + 0.18)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	mesh_instance.set_meta("visual_name", name)
	mesh_instance.position = pos
	mesh_instance.visibility_range_end = 32.0
	zone_root.add_child(mesh_instance)
	if environment_batches_flushed:
		mesh_instance.mesh = shared_box_mesh
		mesh_instance.scale = size
		mesh_instance.material_override = _mat(color)
	else:
		# A pending marker carries only a transform, not visible geometry. Binding
		# a unit cube here creates disposable renderer work and can flash a wrong
		# shape before the batch is published. Terrain markers follow this rule too.
		visual_box_batch_data.append({"node":mesh_instance,"size":size,"color":color})
	return mesh_instance


func _append_prepared_detail(id: String) -> void:
	var entry := preload("res://scripts/prepared_static_batches.gd").entry(id)
	if entry.is_empty():
		return
	if environment_batches_flushed:
		_make_visual_box(entry.name, entry.position, entry.size, entry.color)
		return
	var pos: Vector3 = entry.position
	if current_zone_id not in ["record_hall", "undercroft"]:
		pos = river_safe_position(pos, entry.size.z * 0.5 + 0.18)
	var record: Dictionary = entry
	if pos != entry.position:
		record = preload("res://scripts/static_multimesh_upload.gd").prepare_record(Transform3D(entry.transform.basis, pos), entry.color)
	visual_box_batch_data.append({"prepared": record, "color": entry.color})


func _make_prepared_prop(id: String) -> void:
	var entry := preload("res://scripts/prepared_static_batches.gd").entry(id)
	if not entry.is_empty():
		_make_prop_box(entry.name, entry.position, entry.size, entry.color, true, entry)


func _make_loose_role(role_name: String, pos: Vector3, scale_value: Vector3, yaw: float) -> Node3D:
	var key = role_name.to_lower()
	if key in ["forest_tree", "forest_tree_variant"]:
		# Loose authored trees used to bypass the environment batch and leave a
		# full imported mesh in the active scene. Queue them through the same
		# route-safe batch path as tree walls so the visual remains intact while
		# draw/triangle cost stays bounded.
		var before_count := tree_batch_data.size()
		_make_tree(pos)
		if tree_batch_data.size() > before_count:
			var item: Dictionary = tree_batch_data[tree_batch_data.size() - 1]
			item["asset_role"] = key
			item["asset_scale"] = scale_value
			item["asset_yaw"] = deg_to_rad(yaw)
			tree_batch_data[tree_batch_data.size() - 1] = item
		return null
	if key == "forest_rock":
		if _is_river_excluded(pos, 0.75) or _is_first_route_clearance(pos, 0.55):
			return null
		var rock := _make_role_visual("forest_rock", "environment", scale_value)
		if rock != null:
			var safe_rock_position := river_safe_position(pos, 0.75)
			# `nearest_safe()` is an actor-recovery API. It can legitimately return
			# an authored spawn anchor when a scenery source point overlaps a wall or
			# another prop, but a visual rock must never be teleported across the
			# zone into a player route. Omit the obstructed decoration instead.
			if safe_rock_position.distance_to(pos) > 1.6:
				rock.free()
				return null
			rock.position = safe_rock_position
			rock.rotation_degrees.y = yaw
			zone_root.add_child(rock)
			if current_zone_id == "old_mill":
				# Arena stones are visual dressing, not player obstacles. Their
				# rendered bounds still need to keep the combat camera out of cover.
				var rock_meshes := rock.find_children("*", "MeshInstance3D", true, false)
				if rock is MeshInstance3D:
					rock_meshes.append(rock)
				for raw_mesh in rock_meshes:
					var mesh := raw_mesh as MeshInstance3D
					if mesh.mesh == null:
						continue
					var bounds := mesh.mesh.get_aabb()
					var clearance := StaticBody3D.new()
					clearance.name = "RockCameraClearance"
					clearance.collision_layer = 1 << 6
					clearance.collision_mask = 0
					var collision := CollisionShape3D.new()
					var shape := preload("res://scripts/immutable_collision_shapes.gd").box(bounds.size)
					collision.shape = shape
					collision.position = bounds.get_center()
					clearance.add_child(collision)
					mesh.add_child(clearance)
			return rock
		_make_rubble(pos)
		return null
	if key == "crate":
		_make_prop_box("RouteCrate", pos + Vector3(0, 0.32 * scale_value.y, 0), Vector3(0.72, 0.64, 0.72) * scale_value, Color(0.20, 0.12, 0.065))
		return null
	if key == "barrel":
		_make_prop_box("RouteBarrel", pos + Vector3(0, 0.36 * scale_value.y, 0), Vector3(0.58, 0.72, 0.58) * scale_value, Color(0.17, 0.09, 0.045))
		return null
	if key == "fence":
		var fence_size = Vector3(1.9, 0.32, 0.18) * scale_value
		if abs(fposmod(yaw, 180.0) - 90.0) < 2.0:
			fence_size = Vector3(0.18, 0.32, 1.9) * scale_value
		_make_prop_box("RouteFence", pos + Vector3(0, 0.46, 0), fence_size, Color(0.15, 0.085, 0.045))
		return null
	var node = _make_role_visual(role_name, "environment", scale_value)
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees.y = yaw
	zone_root.add_child(node)
	return node


func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	if role_name == "" or asset_helper == null:
		return null
	if _compatibility_budget_mode() and category == "environment":
		# Balanced keeps only scale-safe, high-signal environment assets. Potato
		# remains primitive-light; larger source meshes stay Quality-only until
		# their imported bounds have an explicit normalization contract.
		var balanced_environment_roles := [
			"greyfen_door_facade", "greyfen_window_facade", "greyfen_chimney",
			"greyfen_roof", "cart",
			"forest_tree", "forest_tree_variant", "forest_tree_secondary", "forest_rock", "forest_bush",
			"castle_wall", "castle_arch", "castle_roof", "castle_door",
			"castle_bookcase", "castle_chair", "castle_bench", "castle_table",
			"castle_weapon_stand", "castle_lantern",
		]
		if str(settings.settings.get("quality_preset", "balanced")) == "potato" or role_name not in balanced_environment_roles:
			return null
	var node: Node3D
	if category == "characters":
		var visual_role = _visual_role_for_legacy_character(role_name)
		if visual_role != "" and asset_helper.has_method("spawn_visual_role") and asset_helper.has_method("has_visual_role") and asset_helper.has_visual_role(visual_role):
			node = asset_helper.spawn_visual_role(visual_role, "characters", role_name)
			if node != null and not node.name.ends_with("_placeholder"):
				return node
			if node != null:
				node.queue_free()
		node = asset_helper.spawn_character(role_name)
	elif category == "enemies":
		# Boss and creature display roles have richer visual mappings than the
		# legacy enemy-definitions table. Prefer those when available, while
		# retaining the combat mapping as a compatibility fallback.
		if asset_helper.has_method("spawn_visual_role") and asset_helper.has_method("has_visual_role") and asset_helper.has_visual_role(role_name):
			node = asset_helper.spawn_visual_role(role_name, "enemies")
		else:
			node = asset_helper.spawn_enemy(role_name)
	else:
		node = asset_helper.spawn_environment(role_name)
	if node == null or node.name.ends_with("_placeholder"):
		if node != null:
			node.queue_free()
		return null
	if category == "enemies":
		asset_helper.apply_normalized_scale(node, scale_value.y)
	elif category == "characters":
		pass
	else:
		node.scale = scale_value
	return node


func _environment_role_scale(role_name: String, target_size: Vector3) -> Vector3:
	var normalized_size: Vector3 = ENVIRONMENT_ROLE_NORMALIZED_SIZE.get(role_name, Vector3.ZERO)
	if normalized_size == Vector3.ZERO:
		push_error("No fitted environment bounds registered for role '%s'" % role_name)
		return Vector3.ONE
	return Vector3(
		target_size.x / maxf(normalized_size.x, 0.001),
		target_size.y / maxf(normalized_size.y, 0.001),
		target_size.z / maxf(normalized_size.z, 0.001)
	)


func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color):
	var area = _make_named_interactable(id, "clue", prompt, pos, color, Vector3(0.55, 0.25, 0.55))
	if area == null:
		return null
	area.quest_id = quest_id
	area.objective_id = objective_id
	if spatial_service != null and id in ["corpse", "bandit_camp"]:
		spatial_service.add_presence_landmark("scavenge" if id == "corpse" else "camp", area.position, 0.6)
	return area


func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE):
	if _is_interaction_removed(id):
		return null
	pos = river_safe_position(pos,0.8)
	var area = Interactable.new()
	area.setup(id, type, prompt)
	area.position = pos
	area.build_collision(2.8 if type == "zone" else 1.45)
	zone_root.add_child(area)
	var prop_spec := _world_prop_spec(id)
	if not prop_spec.is_empty():
		area.set_meta("world_prop_id", id)
		var prop_component := InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", story_state)
	var role = _role_for_interactable(id)
	var presentation_id: String = {"witness_-7": "mira", "witness_-3": "rook", "witness_3": "sister_anwen"}.get(id, id)
	if id in ["notice_board", "side_contracts"]:
		# The supported notice-board assembly owns both visible notices. These
		# areas own dialogue/focus, not a second capsule-shaped prop.
		area.set_meta("external_world_prop", "notice_board")
	elif id == "white_hart":
		# Legacy encounter callbacks can also publish this interaction. They must
		# supply the same stag, never an invisible speaker anchor.
		var witness: Node3D = zone_root.find_child("WhiteHartWitnessDisplay", true, false)
		if witness == null:
			witness = CharacterPresentation.make_hart_witness(asset_helper, pos)
			if witness == null:
				CharacterAnimationDriver.record_configuration(zone_root, id, null)
				area.queue_free()
				return null
			zone_root.add_child(witness)
		CharacterAnimationDriver.record_configuration(zone_root, "white_hart_witness", witness.find_child("HartWitnessAnimation", true, false))
		area.set_meta("external_character_visual", "WhiteHartWitnessDisplay")
	elif id.begins_with("covenant_"):
		area.set_meta("external_story_visual", "covenant_record")
	elif id in ["crow_shrine_choice", "rootbound_challenge"]:
		area.set_meta("external_story_visual", "authored_shrine")
	elif id in ["oren_token", "retain_evidence"]:
		_make_token_interaction_visual(area, Vector3.ONE * 0.65)
	elif type == "clue" and current_zone_id == "wychwood" and WychwoodEvidencePresentation.apply(area, id):
		pass
	elif type == "clue" and CemeteryEvidencePresentation.apply(area, id):
		pass
	elif CampaignRecordPresentation.apply(area, id):
		pass
	elif should_defer_character_role(role, id):
		var marker := Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % id
		marker.set_meta("deferred_visual_role", role)
		marker.set_meta("deferred_visual_category", "characters")
		marker.set_meta("deferred_visual_actor_id", presentation_id)
		marker.set_meta("deferred_visual_scale", Vector3.ONE)
		area.add_child(marker)
		area.set_meta("character_variant_seed", presentation_id)
	else:
		var mapped = _make_role_visual(role, "characters", Vector3.ONE)
		if mapped != null:
			area.add_child(mapped)
			area.set_meta("character_variant_seed", presentation_id)
			if not _configure_npc_animation(mapped, presentation_id):
				area.queue_free()
				return null
		elif str(role) != "":
			CharacterAnimationDriver.record_configuration(zone_root, presentation_id, null)
			area.queue_free()
			return null
		elif id in ["assembly_choice", "witness_7"]:
			_make_ledger_interaction_visual(area, Vector3.ONE)
			var book := area.get_node("SealedCommandLedgerVisual") as Node3D
			book.position.y = 0.83
		elif id == "vargan_ledger_choice":
			_make_ledger_interaction_visual(area, scale_override)
		elif id == "post_victory_token":
			_make_token_interaction_visual(area, scale_override)
		elif type == "zone" or type == "blocked_zone":
			_make_gate_marker(area, color, scale_override)
		else:
			var mesh = MeshInstance3D.new()
			mesh.mesh = CapsuleMesh.new()
			mesh.scale = Vector3(0.45, 0.85, 0.45) * scale_override
			mesh.position.y = 0.85 * scale_override.y
			mesh.material_override = _mat(color)
			area.add_child(mesh)
	var has_character_role: bool = str(role) != ""
	if has_character_role:
		preload("res://scripts/story_cast_profile.gd").register_actor(zone_root, area, presentation_id)
	if type == "dialogue" and id not in ["notice_board", "white_hart"] and has_character_role and not should_defer_character_role(role, id):
		CharacterPresentation.apply_npc(area, presentation_id)
	if current_zone_id == "assembly" and id in ["witness_-7", "witness_-3", "witness_3"]:
		# Testimony is focal staging, not a distant crowd LOD. The normal camera
		# can sit beyond the generic villager cutoff even inside this small court.
		for witness_mesh in area.find_children("*", "MeshInstance3D", true, false):
			witness_mesh.visibility_range_end = maxf(witness_mesh.visibility_range_end, 32.0)
	if type != "clue" and type != "herb" and id != "notice_board":
		var label = Label3D.new()
		label.name = "InteractionWorldLabel"
		label.text = _label_for_interactable(id, prompt)
		label.position = Vector3(0, 2.15 * max(scale_override.y, 0.75), 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 14 if type == "zone" else 16
		label.pixel_size = 0.0038 if type == "zone" else 0.0048
		label.modulate = Color(0.84, 0.78, 0.62)
		label.outline_size = 3
		label.outline_modulate = Color(0.02, 0.018, 0.015)
		label.visibility_range_begin = 1.5
		label.visibility_range_end = 6.0
		label.visible = false
		area.add_child(label)
	if type == "dialogue" and id != "notice_board" and has_character_role:
		var ambient = NpcAmbient.new()
		ambient.setup(presentation_id, player, self)
		area.add_child(ambient)
	_connect_interactable(area)
	return area


func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color):
	pos = river_safe_position(pos,maxf(size.z*0.5,0.8))
	var area = Interactable.new()
	area.setup(id,type,prompt)
	area.position = pos
	area.build_collision(1.35)
	zone_root.add_child(area)
	var prop_spec := _world_prop_spec(id)
	if not prop_spec.is_empty():
		area.set_meta("world_prop_id", id)
		var prop_component := InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", story_state)
	var table: MeshInstance3D = null
	var mesh: BoxMesh = null
	if id in ["forge_corner", "tor_forge"]:
		# The authored workshop is the visible prop for both interactions.
		pass
	elif id in ["common_table", "barrel_board", "mira_apothecary"]:
		GreyfenSocialPresentation.apply(area, id)
		if type == "minigame":
			_make_board_game_staging(area, id, size)
			if not _make_board_game_solidity(area, size):
				area.free()
				return null
	else:
		table = MeshInstance3D.new()
		table.name = "%s_VisibleProp" % id
		mesh = BoxMesh.new()
	if table == null:
		pass
	elif id == "village_well":
		table.position.y = 0.0
	elif id == "shrine_prayer":
		mesh.size = Vector3(size.x, 0.12, size.z)
		table.position.y = 0.48
		table.material_override = _mat(color.lightened(0.12))
		var supports := _make_multimesh_batch("ShrineBenchSupports", shared_box_mesh, 2, _mat(color.darkened(0.12)))
		supports.reparent(area, false)
		for index in range(2):
			var x := -size.x * 0.38 if index == 0 else size.x * 0.38
			supports.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 0.42, size.z * 0.75)), Vector3(x, 0.21, 0.0)))
	elif type == "minigame":
		# A board-game table has visible legs, a thin worn top, two seats, and an
		# opponent. It should read as a social place before the overlay opens.
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _mat(color.darkened(0.10))
		var legs := _make_multimesh_batch("%s_TableLegs" % id, shared_box_mesh, 4, _mat(color.darkened(0.20)))
		legs.reparent(area, false)
		legs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var leg_index := 0
		for x in [-size.x * 0.38, size.x * 0.38]:
			for z in [-size.z * 0.34, size.z * 0.34]:
				legs.multimesh.set_instance_transform(leg_index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, size.y * 0.92, 0.14)), Vector3(x, size.y * 0.46, z)))
				leg_index += 1
		_make_board_game_staging(area, id, size)
	elif type == "vendor":
		# A shop needs to read as a place before the prompt appears: counter,
		# canopy, stock crates, and a warm local light. The transaction remains
		# owned by VendorService so the dressing cannot change save state.
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _mat(color.darkened(0.12))
		var canopy := MeshInstance3D.new()
		canopy.name = "%s_Canopy" % id
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(size.x + 0.32, 0.12, size.z + 0.28)
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0.0, size.y + 1.55, 0.0)
		canopy.material_override = _mat(color.lightened(0.12))
		area.add_child(canopy)
		var posts := _make_multimesh_batch("%s_CanopyPosts" % id, shared_box_mesh, 2, _mat(color.darkened(0.25)))
		posts.reparent(area, false)
		posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var crates := _make_multimesh_batch("%s_StockCrates" % id, shared_box_mesh, 2, _mat(color.darkened(0.28)))
		crates.reparent(area, false)
		crates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for index in range(2):
			var side := -1.0 if index == 0 else 1.0
			posts.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.10, 1.55, 0.10)), Vector3(side * size.x * 0.42, size.y * 0.78, 0.0)))
			crates.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.36, 0.30, 0.36)), Vector3(side * size.x * 0.30, 0.18, size.z * 0.58)))
		_make_light("%s_ShopGlow" % id, pos + Vector3(0, 1.25, 0), color.lightened(0.18), 0.7)
	else:
		mesh.size = size
		table.position.y = size.y * 0.5
		table.material_override = _mat(color)
	if table != null:
		table.mesh = mesh
		area.add_child(table)
	if id == "village_well":
		_apply_greyfen_well_visual(table, pos)
	var label := Label3D.new()
	label.name = "InteractionWorldLabel"
	label.text = prompt
	label.position = Vector3(0,size.y+0.62,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 14
	label.pixel_size = 0.0048
	label.modulate = Color(0.84,0.78,0.62)
	label.visibility_range_begin = 1.5
	label.visibility_range_end = 6.0
	label.visible = false
	area.add_child(label)
	_connect_interactable(area)
	return area


func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3):
	var homeward: bool = bool(story_state.get_flag("final_choice_completed", false)) and ((current_zone_id == "hart_glade" and zone_target == "assembly") or (current_zone_id == "assembly" and zone_target == "undercroft"))
	if homeward:
		zone_target = "greyfen"
		spawn_pos = Vector3(0, 1, 9.8)
		prompt = "Walk the road home to Greyfen"
	var area = _make_named_interactable("gate_%s" % zone_target, "zone", prompt, pos, Color(0.18, 0.22, 0.28), Vector3(1.0, 1.2, 1.0))
	if area == null:
		return null
	area.zone_target = zone_target
	area.set_meta("spawn_pos", spawn_pos)
	# The trigger remains owned by Interactable; only its old marker geometry is
	# replaced so route logic and save compatibility stay unchanged.
	for child in area.get_children():
		if child is MeshInstance3D:
			child.visible = false
	if (current_zone_id == "greyfen" and zone_target == "assembly") or (current_zone_id == "assembly" and zone_target == "greyfen"):
		area.set_meta("civic_phase",true)
		return area
	if homeward:
		area.set_meta("homecoming_route", true)
		return area
	if seamless_world != null and seamless_world.should_suppress_exterior_gate(current_zone_id, zone_target):
		# Exterior travel is now driven by the sector boundary, not an in-world
		# portal. Keep the Area3D as a named migration marker for old saves, but
		# remove its focus/collision path so it cannot steal interaction priority.
		area.set_meta("seamless_exterior_gate", true)
		if not WorldSectorManifest.is_exterior(current_zone_id) or not WorldSectorManifest.is_exterior(zone_target):
			area.set_meta("interior_door",true)
		area.monitoring = false
		area.monitorable = false
		return area
	if seamless_world != null and seamless_world.should_use_physical_door(current_zone_id, zone_target):
		area.set_meta("interior_door", true)
		_add_physical_door_visual(area, zone_target)
		return area
	var portal := OathGatePortal.new()
	portal.name = "OathGatePortal"
	portal.configure(zone_target, "gate_%s" % zone_target)
	if portal.has_method("bind_audio"):
		portal.bind_audio(audio)
	area.add_child(portal)
	if zone_streaming != null and portal.has_method("bind_streaming"):
		portal.bind_streaming(zone_streaming)
		if zone_streaming.has_method("is_embedded_destination") and zone_streaming.is_embedded_destination(zone_target):
			portal.set_ready()
	else:
		portal.set_state(OathGatePortal.PortalState.READY)
	return area


func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	if _boss_is_resolved(id):
		return null
	if active_enemies.filter(func(actor): return is_instance_valid(actor) and not actor.dead).size() >= 5:
		return null
	pos = river_safe_position(pos,1.2)
	# Enemy roots use the same floor-origin contract as the player. Only
	# explicitly airborne roles retain an authored vertical spawn offset.
	if not CharacterRoleSpec.is_airborne(id):
		pos.y = 0.0
	var enemy = EnemyAI.new()
	enemy.set_meta("progression_reward_id", "%s:%.2f:%.2f" % [id, pos.x, pos.z])
	enemy.set_meta("progression_zone", current_zone_id)
	enemy.visual_role_override = visual_role
	# Keep the actor hidden while imported surfaces are normalized and receive
	# their validated overrides. Grounding still needs an in-tree transform.
	enemy.visible = false
	zone_root.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(id, enemy_defs.get(id, {}), player)
	if not CharacterAnimationDriver.record_configuration(zone_root, "%s:%s" % [id, enemy.get_instance_id()], enemy.animation_driver):
		enemy.queue_free()
		return null
	enemy.visible = true
	enemy.encounter_slot = active_enemies.size()
	enemy.setup_navigation(spatial_service)
	enemy.listen_to_world(audio)
	if current_zone_id == "wychwood" and id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		enemy.set_meta("progression_opening_wave", not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"))
		enemy.set_encounter_active(false)
	enemy.attack_gate = coordinator._enemy_attack_token
	if id == "ghoulkin":
		enemy.rotation_degrees.y = 180.0
		if not neighbor_building and audio != null and current_zone_id == "wychwood" and not bool(tutorial_flags.get("ghoulkin_spawn_audio", false)):
			tutorial_flags["ghoulkin_spawn_audio"] = true
			audio.play_event("ghoulkin_idle", 0.025)
	enemy.died.connect(coordinator._on_enemy_died)
	enemy.damaged.connect(coordinator._on_enemy_damaged)
	enemy.windup_started.connect(coordinator._on_enemy_windup_started)
	enemy.attack_resolved.connect(coordinator._on_enemy_attack_resolved)
	if enemy.has_signal("special_attack_resolved"):
		enemy.special_attack_resolved.connect(coordinator._on_boss_special_attack)
	if enemy.has_signal("parry_window_opened"):
		enemy.parry_window_opened.connect(coordinator._on_enemy_parry_window_opened)
	enemy.boss_phase_changed.connect(coordinator._on_boss_phase_changed)
	if bool(enemy_defs.get(id, {}).get("boss", false)):
		var boss_controller: Node = Node.new()
		boss_controller.set_script(BossEncounterScript)
		boss_controller.name = "BossEncounterController"
		enemy.add_child(boss_controller)
		var boss_definition: Dictionary = enemy_defs.get(id, {}).duplicate(true)
		if boss_defs.has(id) and typeof(boss_defs[id]) == TYPE_DICTIONARY:
			boss_definition.merge(boss_defs[id], true)
		boss_controller.call("configure", id, boss_definition, enemy, self)
		if boss_saved_states.has(id) and typeof(boss_saved_states[id]) == TYPE_DICTIONARY:
			boss_controller.call("load_state", boss_saved_states[id])
		if boss_controller.has_signal("phase_changed"):
			boss_controller.connect("phase_changed", Callable(coordinator, "_on_boss_controller_phase_changed"))
		if boss_controller.has_signal("resolved"):
			boss_controller.connect("resolved", Callable(coordinator, "_on_boss_resolved"))
	active_enemies.append(enemy)
	preload("res://scripts/story_encounter_director.gd").apply(self, enemy)
	_sync_camera_enemy_cache()
	return enemy


func _mat(color: Color) -> StandardMaterial3D:
	var interior_lift: bool = current_zone_id in ["record_hall", "undercroft", "old_mill"]
	var key := "flat:%s:%s" % [color.to_html(true), current_zone_id if interior_lift else "world"]
	if material_cache.has(key):
		return material_cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if interior_lift:
		# Compatibility can leave upward-facing procedural archive surfaces
		# unlit. A restrained self-lit lift preserves their authored color without
		# turning the room into a flat white box.
		material.emission_enabled = true
		material.emission = color.lightened(0.18)
		var lift_strength := 0.52 if current_zone_id == "record_hall" else (0.22 if current_zone_id == "old_mill" else 0.34)
		material.emission_energy_multiplier = lift_strength
	material_cache[key] = material
	return material


func _make_greyfen_terrain_layers() -> void:
	_finish_greyfen_ground_surfaces()
	_finish_greyfen_paved_roads()
	_make_terrain_patch("GreyfenCemeterySoil", Vector3(14.0, 0.028, 8.6), Vector3(8.0, 0.045, 5.0), Color(0.095, 0.090, 0.078))
	_make_grass_tufts([
		Vector3(-3.4, 0, -11.5), Vector3(3.1, 0, -10.7), Vector3(-3.6, 0, -7.5), Vector3(3.3, 0, -5.6),
		Vector3(-3.8, 0, -1.4), Vector3(3.6, 0, 1.8), Vector3(-3.0, 0, 5.6), Vector3(3.7, 0, 7.9),
		Vector3(-3.2, 0, -9.5), Vector3(3.0, 0, -8.1), Vector3(-3.0, 0, -5.0), Vector3(3.2, 0, -3.0),
		Vector3(-3.1, 0, 8.4), Vector3(3.2, 0, 9.0), Vector3(-3.3, 0, 11.2), Vector3(3.4, 0, 11.5),
		Vector3(-3.5, 0, 13.6), Vector3(3.1, 0, 13.4), Vector3(5.2, 0, -8.8), Vector3(7.4, 0, -4.9),
		Vector3(11.9, 0, 7.4), Vector3(14.8, 0, 6.2)
	], Color(0.070, 0.145, 0.070))


func _make_wychwood_terrain_layers() -> void:
	if not WychwoodTerrainPresentation.integrate(zone_root):
		push_error("Wychwood walkable terrain could not be integrated")
		return
	_make_grass_tufts([
		Vector3(-2.8, 0, 11.8), Vector3(2.6, 0, 10.5), Vector3(-3.1, 0, 7.2), Vector3(3.3, 0, 5.6),
		Vector3(-3.4, 0, 2.0), Vector3(3.5, 0, -0.2), Vector3(-3.7, 0, -4.2), Vector3(3.4, 0, -6.1),
		Vector3(-5.0, 0, -8.4), Vector3(5.3, 0, -9.0)
	], Color(0.045, 0.115, 0.065))


func _make_greyfen_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [-12, -4, 4, 12]:
		_make_path_stone(Vector3(-2.35 + _scene_randf_range(-0.12, 0.12), 0, z + _scene_randf_range(-0.35, 0.35)), 0.35)
		_make_path_stone(Vector3(2.35 + _scene_randf_range(-0.12, 0.12), 0, z + _scene_randf_range(-0.35, 0.35)), 0.32)


func _make_wychwood_path_edges() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodPathEdgeComposition"
	zone_root.add_child(marker)
	for z in [12, 9, 6, 3, 0, -3, -6, -9]:
		_make_low_berm(Vector3(-4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))
		_make_low_berm(Vector3(4.25, 0, z), Vector3(1.4, 0.48, 2.2), Color(0.030, 0.060, 0.038))


func _make_village_dressing() -> void:
	for item in [
		["barrel", Vector3(-4.0, 0, 3.4), 0.56, -8.0],
		["barrel", Vector3(-4.8, 0, 4.1), 0.48, 15.0],
		["crate", Vector3(-7.3, 0, 4.9), 0.64, 25.0],
		["crate", Vector3(11.1, 0, -2.7), 0.72, -18.0],
		["barrel", Vector3(10.7, 0, 2.9), 0.58, 18.0],
		# Keep the return-to-Castle sightline clear. This rock used to sit on the
		# diagonal from the Wychwood arrival to Greyfen's east exit and its imported
		# collider stopped the player before the gate became focusable.
		["forest_rock", Vector3(8.6, 0, -11.7), 0.55, 0.0],
		["forest_rock", Vector3(-4.8, 0, -12.4), 0.52, 0.0],
		["crate", Vector3(5.5, 0, -6.9), 0.46, -12.0],
		["barrel", Vector3(7.2, 0, -6.4), 0.46, 10.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	for pos in [Vector3(-3.8, 0, -6.0), Vector3(3.9, 0, -9.2), Vector3(-4.4, 0, -13.0)]:
		_make_rubble(pos)


func _make_greyfen_first_impression_dressing(stage: String = "") -> void:
	var stages := ["ruts", "lanterns", "shrine", "story", "crows"]
	if stage != "" and stage not in stages:
		push_error("Unknown Greyfen first-impression stage: " + stage)
		return
	var marker := zone_root.find_child("GreyfenFirstImpressionDressing", true, false)
	if marker == null:
		marker = Node3D.new()
		marker.name = "GreyfenFirstImpressionDressing"
		zone_root.add_child(marker)
	for part in stages:
		if (stage != "" and stage != part) or bool(marker.get_meta("built_" + part, false)):
			continue
		match part:
			"ruts": _make_road_ruts()
			"lanterns": _make_lantern_rhythm()
			"shrine": _make_shrine_approach()
			"story": _make_village_story_clusters()
			"crows": _make_crow_silhouettes()
		marker.set_meta("built_" + part, true)
	for part in stages:
		if not bool(marker.get_meta("built_" + part, false)):
			return
	marker.set_meta("first_impression_complete", true)


func _make_quality_greyfen_overhaul() -> void:
	if str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityGreyfenVisualOverhaul"
	zone_root.add_child(marker)
	for z in [-13.0, -10.5, -8.0, -5.5, -3.0, -0.5, 2.0, 4.5, 7.0, 9.5, 12.0]:
		_make_visual_box("QualityWetRoadSheen", Vector3(_scene_randf_range(-0.45, 0.45), 0.058, z), Vector3(_scene_randf_range(0.55, 1.35), 0.012, _scene_randf_range(0.42, 1.15)), Color(0.045, 0.037, 0.030))
		_make_visual_box("QualityRoadLeafLitter", Vector3(_scene_randf_range(-1.9, 1.9), 0.066, z + _scene_randf_range(-0.75, 0.75)), Vector3(_scene_randf_range(0.18, 0.55), 0.012, _scene_randf_range(0.08, 0.20)), Color(0.12, 0.060, 0.030))
	for pos in [Vector3(-5.8,0,2.5), Vector3(-7.0,0,-3.2), Vector3(7.2,0,-0.2), Vector3(9.8,0,1.8), Vector3(-10.0,0,8.8), Vector3(11.2,0,-7.4)]:
		_make_quality_survival_cluster(pos)
	for pos in [Vector3(4.0,0,-6.0), Vector3(5.2,0,-4.5), Vector3(7.5,0,-7.2), Vector3(6.8,0,-5.8)]:
		_make_fake_light_pool("QualityShrineCandlePool", pos + Vector3(0, 0.038, 0), Vector3(1.05, 0.016, 0.64), Color(0.34, 0.19, 0.07))
	for pos in [Vector3(-3.2,0,-12.5), Vector3(3.4,0,-11.6), Vector3(-3.6,0,-9.2), Vector3(3.2,0,-7.8), Vector3(-3.1,0,-4.8), Vector3(3.5,0,-2.0)]:
		_make_visual_box("QualityRoadEdgeWeeds", pos + Vector3(0, 0.15, 0), Vector3(0.12, _scene_randf_range(0.26, 0.46), 0.08), Color(0.060, 0.120, 0.055))
	_make_light("QualityShrineWarmth", Vector3(5.5, 2.7, -5.9), Color(1.0, 0.50, 0.20), 1.2)
	_make_light("QualityVillageColdEdge", Vector3(-10.0, 3.8, -8.0), Color(0.22, 0.32, 0.46), 1.1)


func _make_spawn_composition() -> void:
	var marker = Node3D.new()
	marker.name = "GreyfenSpawnComposition"
	marker.position = Vector3(0, 0, 7)
	zone_root.add_child(marker)
	_make_light("SpawnWarmRead", Vector3(-2.6, 2.8, 5.7), Color(1.0, 0.42, 0.16), 1.0)
	_make_light("SpawnCoolBackplate", Vector3(1.8, 3.5, 0.4), Color(0.30, 0.36, 0.50), 1.4)
	_make_fog_sheet(Vector3(0, 0.8, 0.8), Vector3(10.0, 0.7, 3.2), Color(0.13, 0.15, 0.16, 0.07))
	_make_fake_light_pool("SpawnLanternPool", Vector3(-2.55, 0.035, 5.6), Vector3(1.9, 0.025, 1.25), Color(0.42, 0.20, 0.075))
	for pos in [Vector3(-3.1, 0, 4.2), Vector3(3.0, 0, 3.4), Vector3(-2.9, 0, 0.2), Vector3(2.9, 0, -1.5)]:
		_make_path_stone(pos, 0.22)
	_make_lantern_post(Vector3(-2.8, 0, 5.7), false, true)
	_make_lantern_post(Vector3(2.65, 0, 1.5), false, false)
	_make_firewood_stack(Vector3(-5.1, 0, 5.2), 18.0)
	_make_broken_fence_run(Vector3(4.7, 0, 5.8), false)


func _make_village_house_dressed(pos: Vector3, yaw: float, node_name: String) -> void:
	var house_variant := 0
	match node_name:
		"DressedVillageHouse_WestLane": house_variant = 1
		"DressedVillageHouse_EastLane": house_variant = 2
		"DressedVillageHouse_ShrineFrame": house_variant = 3
	var mesh_path := "res://assets_external/environment/village/GreyfenHouse_Authored.res" if house_variant == 0 else "res://assets_external/environment/village/GreyfenHouse_Authored_%d.res" % house_variant
	var authored_mesh := load(mesh_path) as ArrayMesh
	if authored_mesh == null or authored_mesh.get_surface_count() != 6:
		push_error("Required Greyfen house mesh is unavailable: " + node_name)
		return
	var root = Node3D.new()
	root.name = node_name
	root.add_to_group("first_route_house")
	root.add_to_group("greyfen_house")
	root.set_meta("visible_house", true)
	root.set_meta("house_variant", house_variant)
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_make_house_collision(root)
	var house_visual := MeshInstance3D.new()
	house_visual.name = "AuthoredHouse"
	house_visual.mesh = authored_mesh
	root.add_child(house_visual)
	var authored_tints := {
		"medieval_brick": Color(0.67, 0.65, 0.59),
		"plaster": [Color(0.76, 0.70, 0.58), Color(0.65, 0.68, 0.62), Color(0.78, 0.64, 0.48), Color(0.71, 0.72, 0.68)][house_variant],
		"timber": [Color(0.72, 0.57, 0.40), Color(0.62, 0.53, 0.43), Color(0.78, 0.54, 0.34), Color(0.53, 0.49, 0.43)][house_variant],
		"roof_tiles": [Color(0.76, 0.47, 0.37), Color(0.63, 0.51, 0.46), Color(0.82, 0.52, 0.39), Color(0.60, 0.59, 0.57)][house_variant],
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.34, 0.34, 0.32),
	}
	var house_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in authored_mesh.get_surface_count():
		var surface_name := authored_mesh.surface_get_name(surface_index)
		if not authored_tints.has(surface_name):
			push_error("Unknown authored Greyfen house surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var surface_material: StandardMaterial3D = _mat(authored_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, house_quality, authored_tints[surface_name], 0.0, false)
		house_visual.set_surface_override_material(surface_index, surface_material)
	root.set_meta("roof_treatment", "authored_mesh")
	return


func _make_fence(pos: Vector3, vertical: bool) -> void:
	_make_prop_box("FencePost", pos + Vector3(0, 0.2, 0), Vector3(0.16, 0.8, 0.16), Color(0.15, 0.09, 0.055))
	var rail_size = Vector3(2.5, 0.12, 0.12)
	if vertical:
		rail_size = Vector3(0.12, 0.12, 2.5)
	_make_prop_box("FenceRail", pos + Vector3(0, 0.52, 0), rail_size, Color(0.17, 0.105, 0.06))


func _make_notice_board(pos: Vector3) -> void:
	_make_prop_box("NoticePost", pos + Vector3(-0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticePost", pos + Vector3(0.55, 0.7, 0), Vector3(0.16, 1.4, 0.16), Color(0.14, 0.08, 0.045))
	_make_prop_box("NoticeBoard", pos + Vector3(0, 1.25, 0), Vector3(1.55, 0.9, 0.12), Color(0.28, 0.16, 0.08))
	_make_world_prop_anchor("notice_board", "notice_board", pos, "evidence_report")


func _make_shrine_scene(pos: Vector3) -> void:
	var shrine_mesh := load("res://assets_external/environment/village/GreyfenShrine_Authored.res") as ArrayMesh
	if shrine_mesh == null or shrine_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen shrine is unavailable")
		return
	var shrine := MeshInstance3D.new()
	shrine.name = "GreyfenAuthoredOathstone"
	shrine.position = pos
	shrine.mesh = shrine_mesh
	zone_root.add_child(shrine)
	preload("res://scripts/camera_controller.gd").install_visual_clearance(shrine)
	var shrine_tints := {
		"medieval_brick": Color(0.68, 0.68, 0.62),
		"plaster": Color(0.70, 0.71, 0.66),
		"timber": Color(0.37, 0.27, 0.19),
		"roof_tiles": Color(0.39, 0.18, 0.17),
		"glazing": Color(0.29, 0.56, 0.50),
		"metal": Color(0.20, 0.28, 0.26),
	}
	var shrine_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in shrine_mesh.get_surface_count():
		var surface_name := shrine_mesh.surface_get_name(surface_index)
		if not shrine_tints.has(surface_name):
			push_error("Unknown authored Greyfen shrine surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = _mat(shrine_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, shrine_quality, shrine_tints[surface_name], 0.0, false)
		shrine.set_surface_override_material(surface_index, material)
	_make_collision_box("ShrinePlinth", pos + Vector3(0, 0.18, 0), Vector3(2.36, 0.36, 1.64))
	_make_collision_box("ShrineOathstone", pos + Vector3(0, 0.96, 0), Vector3(0.88, 1.10, 0.62))
	_make_loose_role("crate", pos + Vector3(-1.15, 0, -0.65), Vector3.ONE * 0.48, -12.0)
	# Keep shrine dressing off the diagonal Greyfen-to-Castle approach. This
	# barrel used to sit directly on the player-sized route after returning from
	# Wychwood, making the Castle gateway fail its real capsule sweep.
	_make_loose_role("barrel", pos + Vector3(1.2, 0, 1.40), Vector3.ONE * 0.42, 16.0)
	_make_light("ShrineGlow", pos + Vector3(0, 1.7, -0.3), Color(0.56, 0.78, 0.62), 1.6)
	_make_world_prop_anchor("shrine", "shrine", pos, "crow_shrine_state")


func _make_blacksmith_scene(pos: Vector3) -> void:
	var forge_mesh := load("res://assets_external/environment/village/GreyfenForge_Authored.res") as ArrayMesh
	if forge_mesh == null or forge_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen forge is unavailable")
		return
	var shop := Node3D.new()
	shop.name = "GreyfenBlacksmithStoneShop"
	shop.position = pos
	zone_root.add_child(shop)
	var workshop := MeshInstance3D.new()
	workshop.name = "BlacksmithAuthoredForge"
	workshop.mesh = forge_mesh
	shop.add_child(workshop)
	var forge_tints := {
		"medieval_brick": Color(0.66, 0.62, 0.55),
		"plaster": Color(0.77, 0.69, 0.57),
		"timber": Color(0.42, 0.31, 0.21),
		"roof_tiles": Color(0.40, 0.26, 0.20),
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.30, 0.30, 0.29),
	}
	var forge_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in forge_mesh.get_surface_count():
		var surface_name := forge_mesh.surface_get_name(surface_index)
		if not forge_tints.has(surface_name):
			push_error("Unknown authored Greyfen forge surface: " + surface_name)
			return
		var material_role := surface_name if world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = _mat(forge_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(material_role, forge_quality, forge_tints[surface_name], 0.0, false)
		workshop.set_surface_override_material(surface_index, material)
	_make_collision_box("BlacksmithRearWall", pos + Vector3(0, 1.27, 2.33), Vector3(3.4, 1.94, 0.20))
	for side in [-1.0, 1.0]:
		_make_collision_box("BlacksmithSideWall", pos + Vector3(side * 1.69, 1.27, 1.2), Vector3(0.20, 1.94, 2.4))
	_make_collision_box("ForgeHearth", pos + Vector3(1.5, 0.30, -1.1), Vector3(0.96, 0.55, 0.88))
	_make_collision_box("ForgeCoal", pos + Vector3(1.5, 0.38, -1.1), Vector3(0.62, 0.08, 0.48))
	_make_light("ForgeLight", pos + Vector3(1.5, 1.5, -1.1), Color(1.0, 0.35, 0.12), 2.5)
	var work := MeshInstance3D.new()
	work.name = "BlacksmithFittedWork"
	work.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
	if work.mesh == null:
		push_error("Greyfen requires its fitted anvil, workbench, stock and fuel")
		work.free()
		return
	shop.add_child(work)
	_make_loose_role("barrel", pos + Vector3(2.15, 0, 0.95), Vector3.ONE * 0.55, -20.0)
	_make_torch(pos + Vector3(-1.8, 0, -1.2))
	_make_world_prop_anchor("forge", "forge", pos + Vector3(1.5, 0.55, -1.1), "iron_fate")


func _make_cart(pos: Vector3, include_visual: bool = true) -> void:
	pos = river_safe_position(pos,1.0)
	if include_visual:
		_make_prop_box("BrokenCartBed", pos + Vector3(0, 0.45, 0), Vector3(2.0, 0.28, 1.1), Color(0.17, 0.10, 0.055))
		for x in [-0.78, 0.78]:
			var wheel = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.35
			mesh.bottom_radius = 0.35
			mesh.height = 0.12
			wheel.mesh = mesh
			wheel.position = pos + Vector3(x, 0.35, -0.62)
			wheel.rotation_degrees.z = 90
			wheel.material_override = _mat(Color(0.07, 0.05, 0.035))
			wheel.set_meta("world_prop_kind", "wheel")
			wheel.set_meta("world_prop_id", "greyfen_cart_wheel")
			zone_root.add_child(wheel)
	_make_world_prop_anchor("cart", "cart", pos)


func _make_wychwood_gate_scene(pos: Vector3) -> void:
	for offset in [-2.25, 2.25]:
		_make_torch(pos + Vector3(offset, 0, 0.2))
		_make_loose_role("fence", pos + Vector3(offset * 0.82, 0, 0.65), Vector3(0.92, 0.92, 0.92), 90.0)
	for offset in [Vector3(-4.2, 0, 1.4), Vector3(4.0, 0, 1.2), Vector3(-4.0, 0, -1.1), Vector3(3.9, 0, -1.0)]:
		_make_rubble(pos + offset)
	_make_fog_sheet(pos + Vector3(0, 0.75, -0.4), Vector3(6.2, 0.9, 1.9), Color(0.20, 0.24, 0.22, 0.16))


func _make_route_markers() -> void:
	for pos in [Vector3(-0.9, 0, -4.5), Vector3(0.95, 0, -8.2), Vector3(-0.7, 0, -11.4)]:
		_make_prop_box("RoadCandle", pos + Vector3(0, 0.18, 0), Vector3(0.14, 0.36, 0.14), Color(0.20, 0.11, 0.05))
		var flame = MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radial_segments = 5
		flame_mesh.rings = 3
		flame.mesh = flame_mesh
		flame.scale = Vector3(0.12, 0.18, 0.12)
		flame.position = pos + Vector3(0, 0.48, 0)
		flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.16), 1.1)
		flame.set_meta("world_prop_kind", "candle")
		flame.set_meta("world_prop_id", "road_candle")
		zone_root.add_child(flame)
		_make_light("RoadCandleGlow", pos + Vector3(0, 0.72, 0), Color(1.0, 0.45, 0.16), 0.8)


func _make_greyfen_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsGreyfenStoryBeats"
	zone_root.add_child(marker)
	_make_black_feather_scatter("RoadCrowsNoticeBlackFeathers", Vector3(-2.8, 0.09, 9.0), 4, 0.75)
	_make_broken_charm("RoadCrowsNoticePrayerCharm", Vector3(-1.35, 0.10, 8.95), 0.0)
	_make_black_feather_scatter("RoadCrowsShrineBlackFeathers", Vector3(5.25, 0.10, -6.25), 5, 0.65)
	_make_broken_charm("RoadCrowsShrineSnappedToken", Vector3(5.65, 0.12, -6.75), -22.0)
	_append_prepared_detail("RoadCrowsExtinguishedCandle_17d04e45b8")
	CemeteryEvidencePresentation.add_disturbed_soil(zone_root, Vector3(13.65, 0.057, 9.45), world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), Color(0.43, 0.38, 0.31), 0.0, false))
	_make_broken_charm("RoadCrowsGraveyardHalfBuriedCharm", Vector3(13.18, 0.13, 9.15), 14.0)
	_make_black_feather_scatter("RoadCrowsGateThresholdFeathers", Vector3(-1.25, 0.10, -13.65), 5, 0.9)
	_make_dark_track("RoadCrowsGateMudTrail", Vector3(0.0, 0.071, -13.15), Vector3(0.42, 0.022, 2.15), Color(0.040, 0.027, 0.020))
	_append_prepared_detail("RoadCrowsGateBrokenSign_70d5d38f95")
	_make_claw_marks("RoadCrowsGateClawedPost", Vector3(2.35, 0.95, -13.85), true)


func _make_wychwood_route_dressing() -> void:
	for item in [
		["forest_rock", Vector3(-4.6, 0, 9.0), 0.46, 8.0],
		["forest_rock", Vector3(4.7, 0, 7.8), 0.40, -16.0],
		["forest_rock", Vector3(-4.8, 0, 1.6), 0.52, 22.0],
		["forest_rock", Vector3(4.9, 0, -1.7), 0.44, 0.0],
		["barrel", Vector3(-5.2, 0, 8.2), 0.48, 0.0],
		["crate", Vector3(-5.8, 0, 7.6), 0.56, 11.0]
	]:
		_make_loose_role(str(item[0]), item[1], Vector3.ONE * float(item[2]), float(item[3]))
	# Keep fallen trunks beyond the player/camera corridor. The previous east
	# trunk at (4.6, 10.5) sat directly in the standard clue-route framing.
	for pos in [Vector3(-7.0, 0, 11.5), Vector3(7.1, 0, 3.0), Vector3(-7.0, 0, -2.0), Vector3(7.1, 0, -4.8)]:
		_make_deadfall(pos)
	for pos in [Vector3(-8.4, 0, 12.5), Vector3(8.3, 0, 11.8), Vector3(-8.6, 0, 4.8), Vector3(8.5, 0, 1.2), Vector3(-8.8, 0, -5.4), Vector3(8.7, 0, -7.2)]:
		_make_tree(pos)


func _make_wychwood_corridor() -> void:
	var marker = Node3D.new()
	marker.name = "WychwoodCorridorComposition"
	marker.position = Vector3(0, 0, 4)
	zone_root.add_child(marker)
	for z in [11.0, 7.5, 4.0, 0.5, -3.0]:
		_make_tree(Vector3(-9.2 + _scene_randf_range(-0.25, 0.25), 0, z))
		_make_tree(Vector3(9.2 + _scene_randf_range(-0.25, 0.25), 0, z + _scene_randf_range(-0.25, 0.25)))
		_make_fog_sheet(Vector3(0, 0.75, z - 0.8), Vector3(7.5, 0.72, 1.5), Color(0.12, 0.18, 0.16, 0.11))


func _make_wychwood_road_of_crows_story_beats() -> void:
	var marker = Node3D.new()
	marker.name = "RoadOfCrowsWychwoodStoryBeats"
	zone_root.add_child(marker)
	_make_cart(Vector3(-5.35, 0, 6.6))
	_append_prepared_detail("RoadCrowsBrokenCartSupplySack_978fae0e15")
	_make_dark_track("RoadCrowsDraggedTrackA", Vector3(-1.05, 0.073, 6.4), Vector3(0.32, 0.018, 2.6), Color(0.050, 0.027, 0.020))
	_make_dark_track("RoadCrowsDraggedTrackB", Vector3(0.75, 0.074, 5.1), Vector3(0.26, 0.018, 2.0), Color(0.055, 0.030, 0.022))
	_make_claw_marks("RoadCrowsCartClawMarks", Vector3(2.7, 0.22, 4.65), false)
	_append_prepared_detail("RoadCrowsTornRedCloth_696592259f")
	_make_broken_charm("RoadCrowsBrokenPrayerToken", Vector3(-3.18, 0.13, 2.25), -12.0)
	_make_black_feather_scatter("RoadCrowsOldRoadBlackFeathers", Vector3(-3.95, 0.10, 1.75), 6, 0.75)
	_make_dark_track("RoadCrowsClearingDraggedMarks", Vector3(0.0, 0.074, -5.65), Vector3(0.46, 0.020, 3.1), Color(0.060, 0.022, 0.016))
	_append_prepared_detail("RoadCrowsClearingOldBloodMud_3184405d5b")
	_make_broken_charm("RoadCrowsClearingSnappedCharm", Vector3(1.35, 0.13, -6.9), 24.0)
	_make_black_feather_scatter("RoadCrowsClearingFeathers", Vector3(1.55, 0.10, -7.25), 5, 0.72)


func _make_narrative_aftermath(zone_id: String) -> void:
	if zone_root == null:
		return
	if zone_id == "wychwood":
		if quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") or bool(story_state.get_flag("wychwood_pack_cleared", false)):
			_make_post_ghoulkin_story_clue()
			_append_prepared_detail("WychwoodPackAshResidue_b4fd8b7b91")
			_append_prepared_detail("WychwoodPackBrokenBinding_c070cc1a73")
		if bool(story_state.get_flag("all_road_evidence", false)) and not quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			_make_all_evidence_safe_edge()
		for evidence in [
			["bram", Vector3(-2.0, 0.10, 7.4), Color(0.30, 0.18, 0.12)],
			["sella", Vector3(-4.0, 0.10, 4.0), Color(0.24, 0.035, 0.03)],
			["oren", Vector3(3.8, 0.10, 2.2), Color(0.48, 0.36, 0.18)],
			["vargan_wire", Vector3(2.5, 0.10, 4.8), Color(0.14, 0.14, 0.13)],
			["drag_marks", Vector3(0.0, 0.09, -4.2), Color(0.09, 0.055, 0.035)]
		]:
			if quests.is_objective_done("main_road_of_crows", str(evidence[0])) or bool(story_state.get_flag("road_evidence_%s" % evidence[0], false)):
				var marker := _make_visual_box("ExaminedEvidence_%s" % evidence[0], evidence[1], Vector3(0.34, 0.025, 0.34), evidence[2])
				marker.set_meta("narrative_state", "examined")
	elif zone_id == "greyfen":
		var report_method := str(story_state.get_flag("evidence_report", ""))
		if report_method != "":
			var report_colors := {
				"private": Color(0.58, 0.50, 0.34),
				"public": Color(0.62, 0.18, 0.12),
				"retained": Color(0.25, 0.22, 0.18)
			}
			_make_visual_box("GreyfenReportedNotice", Vector3(-1.98, 1.18, 9.34), Vector3(0.46, 0.58, 0.025), report_colors.get(report_method, Color(0.5, 0.45, 0.34)))
			_append_prepared_detail("GreyfenWitnessCandle_2eae43d10b")
		if bool(story_state.get_flag("cemetery_ambush_cleared", false)):
			_append_prepared_detail("CemeterySettledEarth_8df2d0e6f7")
			_append_prepared_detail("CemeteryAftermathLantern_4116c2053a")


func _make_deadfall(pos: Vector3) -> void:
	if _is_river_excluded(pos,1.8):
		return
	if spatial_service != null:
		spatial_service.add_presence_landmark("scavenge", pos, 1.0)
	var rotation := Vector3(deg_to_rad(88.0), deg_to_rad(_scene_randf_range(-20.0, 20.0)), deg_to_rad(_scene_randf_range(-8.0, 8.0)))
	deadfall_batch_data.append(Transform3D(Basis.from_euler(rotation), pos + Vector3(0, 0.35, 0)))


func _make_monster_clearing(pos: Vector3) -> void:
	var marker = Node3D.new()
	marker.name = "FirstCombatReadabilityDressing"
	marker.position = pos
	zone_root.add_child(marker)
	_make_light("ClearingColdSpot", pos + Vector3(0, 2.8, -0.4), Color(0.35, 0.48, 0.58), 2.4)
	_make_light("ClearingRimLantern", pos + Vector3(-3.2, 1.9, 1.8), Color(0.9, 0.38, 0.14), 1.2)
	_make_fog_sheet(pos + Vector3(0, 0.55, 0), Vector3(8, 1, 4.5), Color(0.18, 0.25, 0.22, 0.22))
	_make_fog_sheet(pos + Vector3(0, 1.15, -1.8), Vector3(9.2, 1, 3.0), Color(0.16, 0.20, 0.19, 0.16))
	for offset in [Vector3(-5.2,0,-2.9), Vector3(5.2,0,-2.4), Vector3(-5.0,0,2.8), Vector3(5.0,0,3.0)]:
		_make_deadfall(pos + offset)
	for offset in [Vector3(-6.2,0,-3.4), Vector3(6.2,0,-3.2), Vector3(-6.4,0,3.4), Vector3(6.3,0,3.3)]:
		_make_tree(pos + offset)
	for offset in [Vector3(-2.0,0,-1.1), Vector3(1.7,0,-1.4), Vector3(-0.6,0,1.4)]:
		_make_prop_box("BonePile", pos + offset + Vector3(0, 0.09, 0), Vector3(0.9, 0.18, 0.36), Color(0.46, 0.42, 0.35))
	for offset in [Vector3(-1.2,0,0.8), Vector3(1.1,0,0.6), Vector3(0.2,0,-1.9)]:
		_make_prop_box("BlackFeatherScatter", pos + offset + Vector3(0, 0.035, 0), Vector3(0.55, 0.04, 0.10), Color(0.015, 0.014, 0.016))
	for offset in [Vector3(-4.2,0,0.1), Vector3(4.2,0,0.0), Vector3(0,0,-3.2)]:
		_make_rubble(pos + offset)
	_make_loose_role("crate", pos + Vector3(-4.2, 0, 2.1), Vector3.ONE * 0.48, 18.0)
	_make_loose_role("barrel", pos + Vector3(-4.9, 0, 1.4), Vector3.ONE * 0.42, -8.0)
	_make_torch(pos + Vector3(-4.2, 0, 2.1))


func _make_ritual_stone(pos: Vector3) -> void:
	_make_prop_box("RitualStone", pos + Vector3(0, 0.8, 0), Vector3(0.6, 1.6, 0.35), Color(0.32, 0.34, 0.32))
	var rune = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.42, 0.02)
	rune.mesh = mesh
	rune.position = pos + Vector3(0, 0.95, -0.19)
	rune.material_override = _emissive_mat(Color(0.64, 0.85, 0.72), 0.55)
	zone_root.add_child(rune)


func _make_quality_wychwood_overhaul() -> void:
	if str(settings.settings.get("quality_preset", "balanced")) != "quality":
		return
	var marker = Node3D.new()
	marker.name = "QualityWychwoodVisualOverhaul"
	zone_root.add_child(marker)
	for z in [12.0, 9.5, 7.0, 4.5, 2.0, -0.5, -3.0, -5.5, -8.0]:
		_make_visual_box("QualityWychwoodWetMud", Vector3(_scene_randf_range(-0.55, 0.55), 0.060, z), Vector3(_scene_randf_range(0.70, 1.55), 0.012, _scene_randf_range(0.42, 1.05)), Color(0.018, 0.027, 0.024))
		_make_visual_box("QualityWychwoodRootCrossing", Vector3(_scene_randf_range(-2.3, 2.3), 0.145, z + _scene_randf_range(-0.6, 0.6)), Vector3(_scene_randf_range(0.95, 1.8), 0.11, 0.13), Color(0.070, 0.038, 0.022))
	for z in [10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5]:
		_make_deadfall(Vector3(-5.8 + _scene_randf_range(-0.4, 0.2), 0, z))
		_make_deadfall(Vector3(5.8 + _scene_randf_range(-0.2, 0.4), 0, z + _scene_randf_range(-0.3, 0.3)))
		_make_tree(Vector3(-10.4, 0, z + _scene_randf_range(-0.5, 0.5)))
		_make_tree(Vector3(10.4, 0, z + _scene_randf_range(-0.5, 0.5)))
	for pos in [Vector3(-2.2,0,6.7), Vector3(2.6,0,4.6), Vector3(-2.8,0,1.2), Vector3(2.9,0,-1.8)]:
		_make_visual_box("QualityClueGroundDarkening", pos + Vector3(0, 0.065, 0), Vector3(1.15, 0.014, 0.56), Color(0.027, 0.022, 0.018))
	for pos in [Vector3(-4.8,0,-5.8), Vector3(4.6,0,-6.4), Vector3(-2.6,0,-8.8), Vector3(2.8,0,-8.3), Vector3(0.0,0,-6.2)]:
		_make_visual_box("QualityClearingBloodMud", pos + Vector3(0, 0.070, 0), Vector3(1.15, 0.014, 0.46), Color(0.070, 0.018, 0.012))
	for pos in [Vector3(-7.0,0,-10.4), Vector3(7.2,0,-10.0), Vector3(-6.8,0,-4.8), Vector3(6.7,0,-4.2)]:
		_make_fog_sheet(pos + Vector3(0, 0.85, 0), Vector3(4.4, 0.72, 1.45), Color(0.10, 0.18, 0.16, 0.18))
	for pos in [Vector3(-8.2,0,13.0), Vector3(8.0,0,12.8), Vector3(-6.5,0,8.8)]:
		_make_visual_box("QualityBrokenForestSign", pos + Vector3(0, 0.85, 0), Vector3(0.95, 0.12, 0.40), Color(0.11, 0.065, 0.034))
	_make_light("QualityForestBlueRim", Vector3(0, 3.6, -6.5), Color(0.22, 0.42, 0.58), 1.4)
	_make_light("QualityGateLastWarmth", Vector3(0, 2.6, 11.6), Color(1.0, 0.42, 0.14), 1.0)


func _make_gravestone(pos: Vector3) -> void:
	_make_prop_box("Gravestone", pos + Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.18), Color(0.31, 0.31, 0.30))
	_make_prop_box("GraveBase", pos + Vector3(0, 0.09, 0.34), Vector3(0.75, 0.16, 1.0), Color(0.11, 0.10, 0.09))
	_make_prop_box("GraveMoss", pos + Vector3(0.08, 0.72, -0.095), Vector3(0.18, 0.20, 0.025), Color(0.09, 0.18, 0.08))


func _make_rubble(pos: Vector3) -> void:
	# Gate and bridge corridors are registered before scenery is authored. Rubble
	# must honor those reservations before _route_safe_position() can move it into
	# the lane, otherwise a decorative source point can become a hard blocker.
	if spatial_service != null and spatial_service.is_reserved(pos, 0.95):
		return
	pos = _route_safe_position(pos, 3.8)
	if spatial_service != null and spatial_service.is_reserved(pos, 0.95):
		return
	if _is_first_route_clearance(pos, 0.95):
		return
	for i in range(2):
		var offset = Vector3(_scene_randf_range(-0.18, 0.18), 0, _scene_randf_range(-0.16, 0.16))
		_make_prop_box("Rubble", pos + offset + Vector3(0, 0.16, 0), Vector3(_scene_randf_range(0.45, 0.95), _scene_randf_range(0.20, 0.42), _scene_randf_range(0.35, 0.82)), Color(0.18, 0.18, 0.165).lerp(Color(0.08, 0.13, 0.08), _scene_randf() * 0.35))


func _make_herb(id: String, pos: Vector3, color: Color):
	return _make_named_interactable(id, "herb", "Gather %s" % id.capitalize(), pos, color, Vector3(0.35, 0.35, 0.35))


func _add_visual_100_layer(zone_id: String) -> void:
	var quality := str(settings.settings.get("quality_preset", "balanced")) if settings != null else "balanced"
	var visual_root := Node3D.new()
	visual_root.name = "AuthoredVisualLayer_%s" % zone_id.capitalize()
	visual_root.set_meta("synthetic_visual_100_removed", true)
	zone_root.add_child(visual_root)
	var motion = WorldMotionController.new()
	motion.name = "WorldMotionController"
	zone_root.add_child(motion)
	motion.configure(zone_root, quality, player)
	var surface = SurfaceFeedbackManager.new()
	surface.name = "SurfaceFeedbackManager"
	zone_root.add_child(surface)
	surface.configure(player, quality)
	world_vfx = WorldVFXController.new()
	world_vfx.name = "WorldVFXController"
	zone_root.add_child(world_vfx)
	world_vfx.configure(zone_id, quality)


func _install_world_prop_controller(zone_id: String) -> void:
	StoryWorldDirector.decorate(self, zone_root, zone_id)
	if not neighbor_building: CovenantResolution.restore(self)
	if zone_root == null or not is_instance_valid(zone_root):
		world_props = null
		return
	var existing := zone_root.find_child("WorldPropController", true, false) as WorldPropController
	if existing != null:
		world_props = existing
		return
	world_props = WorldPropController.new()
	world_props.name = "WorldPropController"
	zone_root.add_child(world_props)
	world_props.configure(zone_root, zone_id, str(settings.settings.get("quality_preset", "balanced")), story_state, audio)


func _flush_environment_batches() -> void:
	for phase in range(7):
		flush_environment_batch_step(phase)

func flush_environment_batch_step(phase: int) -> void:
	if context.zone_root == null:
		return
	match phase:
		0: _publish_environment_0()
		1: _publish_environment_1()
		2: _publish_environment_2()
		3: _publish_environment_3()
		4: _publish_environment_4()
		5: _publish_environment_5()
		6: _publish_environment_6()
	if phase == 6:
		environment_batches_flushed = true

func _publish_environment_0() -> void:
	preload("res://scripts/connected_route_geometry.gd").install(ZoneBuildContext.new(self,current_zone_id))
	var terrain_groups: Dictionary = {}
	for item in terrain_patch_batch_data:
		var terrain_key := str(item.material.get_instance_id())
		if not terrain_groups.has(terrain_key):
			terrain_groups[terrain_key] = {"material":item.material,"items":[]}
		terrain_groups[terrain_key].items.append(item)
	for terrain_key in terrain_groups:
		var terrain_group: Dictionary = terrain_groups[terrain_key]
		var terrain_items: Array = terrain_group.items
		var terrain_batch := MeshInstance3D.new()
		terrain_batch.name = "TerrainPatchBatch_%s" % terrain_key
		var surface := SurfaceTool.new()
		for i in range(terrain_items.size()):
			var marker: Node3D = terrain_items[i].node
			var patch_size: Vector3 = terrain_items[i].size
			var patch_mesh: ArrayMesh = world_materials.make_organic_ground_patch(patch_size, marker.position, marker.basis) if current_zone_id == "wychwood" else world_materials.make_tiled_ground_patch(patch_size, marker.position, marker.basis)
			surface.append_from(patch_mesh, 0, marker.transform)
			# This node is a build-only transform carrier; the merged mesh now owns
			# its geometry. Defer removal until the current scene-tree
			# notification finishes so RenderingServer can unregister the instance
			# without leaving a detached renderer allocation.
			marker.queue_free()
		terrain_batch.mesh = surface.commit()
		terrain_batch.material_override = terrain_group.material
		zone_root.add_child(terrain_batch)

func _publish_environment_1() -> void:
	var visual_groups: Dictionary = {}
	var separate_alpha := preload("res://scripts/performance_comparison_options.gd").enabled("alpha_batches")
	for item in visual_box_batch_data:
		var color: Color = item.color
		var use_instance_colors: bool = current_zone_id != "record_hall"
		var visual_key := "instance_colors" if use_instance_colors else color.to_html(true)
		var transparent := separate_alpha and color.a < 0.999
		if transparent:
			visual_key = "alpha_" + visual_key
		var night_only: bool = item.node.get_meta("night_only_geometry", false) if item.has("node") else false
		if night_only:
			visual_key = "night_" + visual_key
		if not visual_groups.has(visual_key):
			var material: StandardMaterial3D
			if use_instance_colors:
				if not material_cache.has("detail_instance_colors"):
					var shared_material := StandardMaterial3D.new()
					shared_material.roughness = 0.9
					shared_material.vertex_color_use_as_albedo = true
					material_cache["detail_instance_colors"] = shared_material
				material = material_cache["detail_instance_colors"]
			else:
				material = _mat(color)
			if transparent:
				material = material.duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			visual_groups[visual_key] = {"material": material, "colors": use_instance_colors, "night_only": night_only, "items": []}
		visual_groups[visual_key].items.append(item)
	for visual_key in visual_groups:
		var group: Dictionary = visual_groups[visual_key]
		var items: Array = group.items
		var detail_batch := _make_multimesh_batch("AuthoredDetailBatch_%s" % visual_key, shared_box_mesh, items.size(), group.material, group.colors)
		if group.night_only:
			detail_batch.set_meta("night_only_geometry", true)
		var detail_transforms: Array = []
		var detail_colors: Array = []
		for i in range(items.size()):
			if items[i].has("prepared"):
				detail_transforms.append(items[i].prepared)
				if group.colors:
					detail_colors.append(items[i].color)
				continue
			var marker: Node3D = items[i].node
			var detail_size: Vector3 = items[i].size
			detail_transforms.append(Transform3D(marker.basis.scaled(detail_size), marker.position))
			if group.colors:
				detail_colors.append(items[i].color)
			# Like terrain markers, these nodes have no runtime purpose after the
			# batched transform has been copied. Defer removal for the same
			# scene-tree/renderer ownership reason as terrain markers.
			marker.queue_free()
		_upload_static_batch(detail_batch, detail_transforms, detail_colors)

func _publish_environment_2() -> void:
	for house_key in house_batch_data:
		var house_group: Dictionary = house_batch_data[house_key]
		var house_transforms: Array = house_group.transforms
		if house_transforms.is_empty():
			continue
		var house_batch := _make_multimesh_batch(
			"HouseBatch_%s" % str(house_key).replace(":", "_"),
			shared_box_mesh,
			house_transforms.size(),
			house_group.material,
			true
		)
		if str(house_key).begins_with("emissive_window:"):
			house_batch.set_meta("night_window_material", house_group.material)
			house_batch.set_meta("night_window_color", house_group.material.albedo_color)
		_upload_static_batch(house_batch, house_transforms, house_group.colors)

func _publish_environment_3() -> void:
	for batch_key in house_module_batch_data:
		var module_group: Dictionary = house_module_batch_data[batch_key]
		var module_transforms: Array = module_group.transforms
		if module_transforms.is_empty():
			continue
		var module_batch := _make_multimesh_batch(
			"HouseModuleBatch_%s" % batch_key,
			module_group.mesh,
			module_transforms.size(),
			null
		)
		# Preserve each imported material group rather than replacing the
		# entire module with the generic static-batch material.
		module_batch.material_override = null
		_upload_static_batch(module_batch, module_transforms)

func _publish_environment_4() -> void:
	for batch_key in prop_batch_data:
		var entry: Dictionary = prop_batch_data[batch_key]
		var transforms: Array = entry.get("transforms", [])
		if transforms.is_empty():
			continue
		var batch := _make_multimesh_batch("WorldPropBatch_%s" % str(batch_key), shared_box_mesh, transforms.size(), entry.get("material"))
		_upload_static_batch(batch, transforms)

func _publish_environment_5() -> void:
	if not tree_batch_data.is_empty() and not _flush_authored_tree_assets():
		var trunk_mesh := BoxMesh.new()
		trunk_mesh.size = Vector3(0.42, 1.8, 0.42)
		var trunks := _make_multimesh_batch("TreeTrunkBatch", trunk_mesh, tree_batch_data.size(), world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), Color(0.42, 0.30, 0.20), 0.0, false))
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.72
		crown_mesh.height = 1.62
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 4
		var crown_material := _mat(Color.WHITE)
		crown_material.vertex_color_use_as_albedo = true
		var crowns := _make_multimesh_batch("TreeCrownBatch", crown_mesh, tree_batch_data.size(), crown_material, true)
		var trunk_transforms: Array = []
		var crown_transforms: Array = []
		var crown_colors: Array = []
		for i in range(tree_batch_data.size()):
			trunk_transforms.append(tree_batch_data[i].trunk)
			var crown_transform: Transform3D = tree_batch_data[i].crown
			crown_transform.basis = crown_transform.basis.scaled(Vector3(1.10, 0.72, 1.10))
			crown_transforms.append(crown_transform)
			crown_colors.append(tree_batch_data[i].color)
		_upload_static_batch(trunks, trunk_transforms)
		_upload_static_batch(crowns, crown_transforms, crown_colors)

func _publish_environment_6() -> void:
	_build_design_pack_ecology()
	if not deadfall_batch_data.is_empty():
		var deadfall_mesh := CylinderMesh.new()
		deadfall_mesh.top_radius = 0.16
		deadfall_mesh.bottom_radius = 0.22
		deadfall_mesh.height = 3.4
		deadfall_mesh.radial_segments = 7
		var deadfalls := _make_multimesh_batch("DeadfallBatch", deadfall_mesh, deadfall_batch_data.size(), world_materials.get_material("timber", str(settings.settings.get("quality_preset", "balanced")), Color(0.34, 0.25, 0.17), 0.0, false))
		_upload_static_batch(deadfalls, deadfall_batch_data)

func _build_design_pack_ecology() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
	if not data is Dictionary:
		push_error("Required design-pack ecology data is unavailable")
		return
	for sighting: Dictionary in data.get("sightings", []):
		if str(sighting.zone) != current_zone_id:
			continue
		var id := "design_ecology:" + str(sighting.role)
		if zone_root.has_meta(id):
			continue
		var p: Array = sighting.position
		var area: Node3D = _make_named_interactable(id, "story_activity", "Observe " + str(sighting.name), Vector3(float(p[0]), 0, float(p[2])), Color.WHITE)
		if area == null:
			continue
		area.set_meta("design_ecology", sighting)
		area.rotation_degrees.y = float(sighting.get("yaw", 0))
		# The prompt stays on reachable ground; perched anatomy has an explicit
		# vertical offset and never supplies a false bridge or walking surface.
		for child: Node in area.get_children():
			if child is Node3D and child.has_meta("character_animation_family"):
				child.position.y += float(p[1])
				var offset: Array = sighting.get("visual_offset", [0, 0, 0])
				child.position += Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		var driver := area.find_child("CharacterAnimationDriver", true, false)
		if driver != null:
			driver.set_meta("ecology_clip", str(sighting.get("clip", "Idle")))
		zone_root.set_meta(id, true)


func _apply_first_route_materials(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		_apply_first_route_materials(child)
	if root is MeshInstance3D:
		var mesh_instance = root as MeshInstance3D
		var palette_key = _first_route_palette_key(mesh_instance)
		if palette_key == "":
			return
		if _mesh_needs_visible_fallback(mesh_instance):
			mesh_instance.material_override = _first_route_material(palette_key)


func river_safe_position(pos: Vector3, margin: float = 0.55) -> Vector3:
	if spatial_service != null:
		return spatial_service.validate_position(pos, margin)
	var validator := ZoneSpatialService.new()
	validator.configure(current_zone_id, _river_center(), _zone_half_extents(current_zone_id))
	var result: Vector3 = validator.validate_position(pos, margin, validator.bank_for(pos))
	validator.free()
	return result


func validate_walkable_position(pos: Vector3) -> Vector3:
	if spatial_service != null:
		return spatial_service.validate_position(pos, 0.90)
	var safe := river_safe_position(pos, 0.90)
	safe.x = clampf(safe.x, -18.5, 18.5)
	safe.z = clampf(safe.z, -14.5, 14.5)
	safe.y = 0.0
	return safe


func _terrain_material(name: String, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var lower := name.to_lower()
		var surface := "forest_ground"
		var wetness := 0.0
		if lower.contains("mud") or lower.contains("wet") or lower.contains("cemetery"):
			surface = "wet_mud"
			wetness = 0.72
		var tint_lift := 0.34 if lower.begins_with("wychwood") or current_zone_id == "wychwood" else 0.65
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


func _make_bridge_corridor_collision(bridge_width: float, river_z: float, bridge_length: float, approach_length: float, zone_depth: float) -> void:
	var body := StaticBody3D.new()
	body.name = "RiverBridgeContinuousSurface"
	# The visual bank meshes remain split around the water, but the center lane
	# uses one continuous surface across both joins. This prevents a CharacterBody
	# capsule from catching the coplanar vertical faces of touching floor boxes.
	body.position = Vector3(0.0, 0.0, 0.0)
	zone_root.add_child(body)
	var collision := CollisionShape3D.new()
	var support_length := maxf(zone_depth, bridge_length + approach_length * 2.0)
	var shape := preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(bridge_width, 0.20, support_length))
	collision.position = Vector3(0.0, -0.10, 0.0)
	collision.shape = shape
	body.add_child(collision)


func _make_boundary_edge(edge_id: String, width: float, depth: float, color: Color) -> void:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var open_edge: Dictionary = seamless_world.open_edges_for(current_zone_id).get(edge_id, {}) if seamless_world != null else {}
	var opening_half := float(open_edge.get("half_width", 0.0))
	var lane := float(open_edge.get("lane", 0.0))
	var openings: Array[Vector2] = []
	for edge: Dictionary in WorldSectorManifest.connections(current_zone_id):
		if str(edge.id) == edge_id: openings.append(Vector2(float(edge.lane)-float(edge.half_width),float(edge.lane)+float(edge.half_width)))
	if openings.is_empty() and not open_edge.is_empty() and opening_half > 0.0 and WorldSectorManifest.connection_between(current_zone_id,str(open_edge.get("target",""))).is_empty():
		openings.append(Vector2(lane-opening_half,lane+opening_half))
	var is_open := not openings.is_empty()
	var wall_thickness := 1.2
	var wall_height := 1.8
	var collision_thickness := 0.4
	var enclosed_zone: bool = current_zone_id in ["record_hall", "undercroft"]
	if not is_open:
		match edge_id:
			"north":
				if not enclosed_zone:
					_make_prop_box("NorthBerm", Vector3(0, 0.9, -half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, -half_d - 0.65), Vector3(width, 3.2, collision_thickness))
			"south":
				if not enclosed_zone:
					_make_prop_box("SouthBerm", Vector3(0, 0.9, half_d), Vector3(width, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(0, 1.6, half_d + 0.65), Vector3(width, 3.2, collision_thickness))
			"west":
				if not enclosed_zone:
					_make_prop_box("WestBerm", Vector3(-half_w, 0.9, 0), Vector3(wall_thickness, wall_height, depth), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, 0), Vector3(collision_thickness, 3.2, depth))
			"east":
				if not enclosed_zone:
					_make_prop_box("EastBerm", Vector3(half_w, 0.9, 0), Vector3(wall_thickness, wall_height, depth), color)
				_make_invisible_wall(Vector3(half_w + 0.65, 1.6, 0), Vector3(collision_thickness, 3.2, depth))
		return
	var line_half := half_w if edge_id in ["north", "south"] else half_d
	openings.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var segments: Array = []
	var cursor := -line_half
	for opening: Vector2 in openings:
		var start := clampf(opening.x,-line_half+0.6,line_half-0.6)
		var finish := clampf(opening.y,-line_half+0.6,line_half-0.6)
		if start > cursor: segments.append([cursor,start])
		cursor = maxf(cursor,finish)
	if cursor < line_half: segments.append([cursor,line_half])
	for segment in segments:
		var segment_start := float(segment[0])
		var segment_end := float(segment[1])
		if segment_end - segment_start < 0.35:
			continue
		var center := (segment_start + segment_end) * 0.5
		var length := segment_end - segment_start
		match edge_id:
			"north":
				if not enclosed_zone:
					_make_prop_box("NorthBerm", Vector3(center, 0.9, -half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, -half_d - 0.65), Vector3(length, 3.2, collision_thickness))
			"south":
				if not enclosed_zone:
					_make_prop_box("SouthBerm", Vector3(center, 0.9, half_d), Vector3(length, wall_height, wall_thickness), color)
				_make_invisible_wall(Vector3(center, 1.6, half_d + 0.65), Vector3(length, 3.2, collision_thickness))
			"west":
				if not enclosed_zone:
					_make_prop_box("WestBerm", Vector3(-half_w, 0.9, center), Vector3(wall_thickness, wall_height, length), color)
				_make_invisible_wall(Vector3(-half_w - 0.65, 1.6, center), Vector3(collision_thickness, 3.2, length))
			"east":
				if not enclosed_zone:
					_make_prop_box("EastBerm", Vector3(half_w, 0.9, center), Vector3(wall_thickness, wall_height, length), color)
				_make_invisible_wall(Vector3(half_w + 0.65, 1.6, center), Vector3(collision_thickness, 3.2, length))


func _road_material(paved: bool, color: Color) -> StandardMaterial3D:
	if world_materials != null:
		var road_tint := Color(0.64, 0.61, 0.56) if paved else Color(0.38, 0.31, 0.22).lerp(color, 0.15)
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


func _river_center(zone: String = current_zone_id) -> float:
	return SpatialSurfaceContract.river_center(zone)


func _make_terrain_patch_raw(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = name
	mesh.position = pos
	mesh.rotation_degrees.y = 0.0 if current_zone_id == "wychwood" else _scene_randf_range(-2.0, 2.0)
	zone_root.add_child(mesh)
	terrain_patch_batch_data.append({"node":mesh,"size":size,"color":color,"material":_terrain_material(name,color)})


func _is_river_excluded(pos: Vector3, margin: float = 0.0) -> bool:
	if spatial_service != null and spatial_service.zone_id == current_zone_id:
		return spatial_service.is_river_excluded(pos, margin)
	return SpatialSurfaceContract.is_river_excluded(current_zone_id, pos, margin)


func _performance_mode() -> bool:
	return settings != null and bool(settings.settings.get("potato_mode", true))


func _scene_randf_range(from: float, to: float) -> float:
	return scene_rng.randf_range(from,to) if scene_rng != null else randf_range(from,to)


func _scene_randf() -> float:
	return scene_rng.randf() if scene_rng != null else randf()


func _compatibility_budget_mode() -> bool:
	return settings == null or str(settings.settings.get("quality_preset", "balanced")) != "quality"


func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead", "AshMillFacadeFill", "BanditWarmLantern", "LedgerTableLight", "RecordHallNavigationFill", "RecordHallEntryFill", "RecordHallArchiveFill", "HartWitnessLight", "HartAftermathLight", "UndercroftNavigationFill", "UndercroftHalvernFill"]


func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _route_safe_position(pos: Vector3, target_x: float) -> Vector3:
	if not _is_first_route_clearance(pos, 0.0):
		return pos
	var side = -1.0 if pos.x < 0.0 else 1.0
	if abs(pos.x) < 0.2:
		side = -1.0 if _scene_randf() < 0.5 else 1.0
	pos.x = side * target_x
	return pos


func _is_first_route_clearance(pos: Vector3, radius: float = 0.0) -> bool:
	if current_zone_id == "greyfen":
		if abs(pos.x) < 2.85 + radius and pos.z > -15.8 and pos.z < 13.4:
			return true
		if pos.x > 1.2 - radius and pos.x < 7.0 + radius and pos.z > -8.8 - radius and pos.z < -3.8 + radius:
			return true
	elif current_zone_id == "wychwood":
		if abs(pos.x) < 3.15 + radius and pos.z > -13.2 and pos.z < 14.2:
			return true
		if abs(pos.x) < 4.4 + radius and pos.z > -9.8 and pos.z < -3.0:
			return true
	return false


func _prop_requires_collision(lower_name: String) -> bool:
	return lower_name.contains("wall") or lower_name.contains("fence") or lower_name.contains("rail") \
		or lower_name.contains("post") or lower_name.contains("door") or lower_name.contains("gate") \
		or lower_name.contains("tower") or lower_name.contains("stable") or lower_name.contains("house") \
		or lower_name.contains("building") or lower_name.contains("bridge") or lower_name.contains("berm")


func _visual_role_for_legacy_character(role_name: String) -> String:
	var authored_role := preload("res://scripts/story_cast_profile.gd").visual_role(role_name)
	if authored_role != "":
		return authored_role
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_female_human",
		"blacksmith_tor": "villager_worker_human",
		"generic_villager_01": "villager_human",
		"lord_edric": "castle_guard_human",
		"castle_guard": "castle_guard_human",
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"halvern_boss": "halvern_boss",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))


func _is_interaction_removed(id: String) -> bool:
	return bool(removed_interactions.get("%s:%s" % [current_zone_id, id], false))


func _world_prop_spec(id: String) -> Dictionary:
	return {
		"notice_board": {"kind": "notice_board", "state_key": "greyfen_prop:notice_board"},
		"village_well": {"kind": "well", "state_key": "greyfen_well_state"},
		"forge_corner": {"kind": "forge", "state_key": "greyfen_prop:forge_corner"},
		"shrine_prayer": {"kind": "shrine", "state_key": "shrine_prayer_state"},
		"common_table": {"kind": "table", "state_key": "common_table_state"},
		"barrel_board": {"kind": "table", "state_key": "barrel_board_state"},
		"vargan_ledger_choice": {"kind": "ledger", "state_key": "vargan_ledger_state"},
	}.get(id, {})


func _role_for_interactable(id: String) -> String:
	if id.begins_with("design_ecology:"):
		return id.trim_prefix("design_ecology:")
	var authored_role := preload("res://scripts/story_cast_profile.gd").visual_role(id)
	if authored_role != "":
		return authored_role
	var roles = {
		"sister_anwen": "sister_anwen",
		"mira": "mira_herbalist",
		"rook": "rook_smuggler",
		"widow_elna": "widow_elna",
		"blacksmith_tor": "blacksmith_tor",
		"farmer_toma": "generic_villager_01",
		"returned_soldier": "returned_soldier",
		"edric": "castle_guard",
		"vargan_gate_guard": "castle_guard",
		"vargan_record_keeper": "castle_guard",
		"vargan_steward": "vargan_steward",
		"vargan_servant": "vargan_servant",
		"vargan_patrol": "vargan_patrol",
		"edric_castle": "edric_castle",
		"edric_campaign": "edric_campaign",
		"captain_senn": "road_ranger",
		"halvern": "halvern_boss",
		"white_hart": "white_hart_avatar",
		"witness_-7": "mira_herbalist",
		"witness_-3": "rook_smuggler",
		"witness_3": "sister_anwen"
	}
	return str(roles.get(id, ""))


func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var token_root := Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	var token := MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	var token_mesh := BoxMesh.new()
	token_mesh.size = Vector3(0.28, 0.07, 0.38)
	token.mesh = token_mesh
	token.position = Vector3(-0.12, 0.12, 0.0)
	token.rotation_degrees = Vector3(0.0, -24.0, 8.0)
	token.material_override = _mat(Color(0.48, 0.30, 0.12))
	token_root.add_child(token)
	var wire := MeshInstance3D.new()
	wire.name = "VarganBindingWire"
	var wire_mesh := TorusMesh.new()
	wire_mesh.inner_radius = 0.07
	wire_mesh.outer_radius = 0.09
	wire_mesh.rings = 8
	wire_mesh.ring_segments = 6
	wire.mesh = wire_mesh
	wire.position = Vector3(0.12, 0.15, 0.05)
	wire.rotation_degrees = Vector3(78.0, 12.0, 14.0)
	var wire_material := _mat(Color(0.13, 0.13, 0.12))
	wire_material.metallic = 0.55
	wire_material.roughness = 0.48
	wire.material_override = wire_material
	token_root.add_child(wire)


func should_defer_character_role(_role: String, _actor_id: String) -> bool:
	# Destination packs already gate construction. Required people must have a
	# body before their interaction is published, not a delayed visual marker.
	return false


func _configure_npc_animation(mapped: Node3D, id: String) -> bool:
	var existing := mapped.get_node_or_null("CharacterAnimationDriver")
	if existing != null:
		return CharacterAnimationDriver.record_configuration(zone_root, id, existing)
	var clips := {
		"idle": "Idle", "walk": "Walk", "walk_back": "Walk",
		"strafe": "Walk", "run": "Sprint", "work": "Interact",
		"dialogue": "Idle_Talking", "hit": "Hit_Chest", "death": "Death01"
	}
	var family := str(mapped.get_meta("character_animation_family", "")).to_lower()
	if family == "design_pack_native":
		clips = {"idle":"Idle", "walk":"Walking", "walk_back":"Walking", "strafe":"Walking", "run":"Running", "work":"Interact", "dialogue":"Interact", "hit":"HitReact", "death":"Death"}
		if id.begins_with("design_ecology:"):
			var ecology_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
			if ecology_data is Dictionary:
				for entry: Dictionary in ecology_data.get("sightings", []):
					if str(entry.role) == id.trim_prefix("design_ecology:"):
						clips["idle"] = str(entry.get("clip", "Idle"))
	elif family.contains("warrior"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("cleric"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("rogue"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("monk"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	if id == "sister_anwen":
		clips["idle"] = "Idle_Talking"
		# The shared female base does not ship a death clip. Anwen is a protected
		# story NPC, so keep the real hit reaction as the safe non-lethal fallback
		# instead of claiming an unavailable death animation in the contract.
		clips["hit"] = "Hit_Chest"
		clips.erase("death")
	elif id == "injured_traveler":
		clips["idle"] = "Sitting_Idle"
		clips["dialogue"] = "Sitting_Talking"
		clips["work"] = "Sitting_Idle"
	elif id == "rook":
		clips["idle"] = "Idle_Talking"
		clips["hit"] = "Hit_Head"
	elif id in ["board_rook", "board_tor"]:
		clips["idle"] = "Sitting_Idle"
		clips["dialogue"] = "Sitting_Talking"
		clips["work"] = "Sitting_Talking"
		mapped.set_meta("cast_activity_override", "")
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	if not driver.configure(mapped, clips):
		CharacterAnimationDriver.record_configuration(zone_root, id, driver)
		return false
	CharacterAnimationDriver.record_configuration(zone_root, id, driver)
	if id not in ["board_rook", "board_tor"] and family != "design_pack_native":
		load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	# Non-player rigs do not own physics or combat timing. Drive them through a
	# phase-staggered manual clock so imported skin evaluation cannot wake every
	# skeleton on every rendered frame. The player and active enemies retain
	# their explicit gameplay rates. Eight Hz is still frequent enough for an
	# idle or conversation pose at the camera distances used by these actors,
	# while removing the synchronized 20 Hz/idle-callback spikes measured in the
	# Castle and Record Hall performance samples.
	var npc_animation_rate := 8.0
	driver.set_update_rate_hz(npc_animation_rate)
	return true


func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var ledger_root := Node3D.new()
	ledger_root.name = "SealedCommandLedgerVisual"
	ledger_root.scale = scale_override
	area.add_child(ledger_root)
	var cover := MeshInstance3D.new()
	cover.name = "LedgerLeatherCover"
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(0.82, 0.11, 0.56)
	cover.mesh = cover_mesh
	cover.position = Vector3(0.0, 0.17, 0.0)
	cover.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	cover.material_override = _mat(Color(0.16, 0.075, 0.040))
	ledger_root.add_child(cover)
	var pages := MeshInstance3D.new()
	pages.name = "LedgerPages"
	var pages_mesh := BoxMesh.new()
	pages_mesh.size = Vector3(0.68, 0.065, 0.46)
	pages.mesh = pages_mesh
	pages.position = Vector3(0.0, 0.232, 0.0)
	pages.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	pages.material_override = _mat(Color(0.58, 0.48, 0.31))
	ledger_root.add_child(pages)
	var seal := MeshInstance3D.new()
	seal.name = "LedgerWaxSeal"
	var seal_mesh := CylinderMesh.new()
	seal_mesh.top_radius = 0.075
	seal_mesh.bottom_radius = 0.075
	seal_mesh.height = 0.025
	seal_mesh.radial_segments = 10
	seal.mesh = seal_mesh
	seal.position = Vector3(0.18, 0.285, -0.04)
	seal.rotation_degrees = Vector3(90.0, 0.0, -7.0)
	seal.material_override = _mat(Color(0.43, 0.075, 0.045))
	ledger_root.add_child(seal)


func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	var pillar_material := _mat(color.lightened(0.10))
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.30, 1.72, 0.26)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 0.86 * scale_override.x, 0.86 * scale_override.y, 0)
		pillar.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
		pillar.material_override = pillar_material
		parent.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(2.05, 0.24, 0.28)
	lintel.mesh = lintel_mesh
	lintel.position.y = 1.72 * scale_override.y
	lintel.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
	lintel.material_override = _mat(color.lightened(0.18))
	parent.add_child(lintel)


func _label_for_interactable(id: String, prompt: String) -> String:
	if dialogue != null and dialogue.has_dialogue(id):
		return dialogue.display_name(id, prompt)
	if id.begins_with("gate_"):
		return prompt
	return prompt.replace("Inspect ", "").replace("Gather ", "").replace("Take ", "")


func _make_board_game_solidity(area: Node3D, size: Vector3) -> bool:
	var visual := area.get_node_or_null("GreyfenSocialFurniture") as MeshInstance3D
	if visual == null or visual.mesh == null:
		push_error("Required solid board furniture is missing: " + str(area.name))
		return false
	# Exact static table/chair geometry leaves legroom and approach gaps intact;
	# the presentation helper itself remains visual-only.
	var fitted := visual.mesh.create_trimesh_shape()
	if fitted == null:
		push_error("Cannot build solid board furniture: " + str(area.name))
		return false
	fitted.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "SolidFurniture"
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("walkable_support", false)
	area.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "FittedTableAndChairs"
	shape.shape = fitted
	shape.transform = visual.transform
	body.add_child(shape)
	area.set_meta("interaction_anchor", Vector3(0, size.y + 0.18, 0))
	var arrival := Marker3D.new()
	arrival.name = "BoardGameOpponentApproach"
	arrival.position = Vector3((1.0 if str(area.name) == "common_table" else -1.0) * (size.x * 0.5 + 1.0), 0, 0)
	area.add_child(arrival)
	var corner := Marker3D.new()
	corner.name = "BoardGameOpponentCorner"
	# Rook clears the north chair. Tor uses the reserved northern road instead
	# of the care area or the too-narrow strip between the house and river.
	corner.position = Vector3(arrival.position.x, 0, -size.z * 0.90 - 1.1) if str(area.name) == "common_table" else Vector3(0.0, area.position.y, -10.0) - area.position
	area.add_child(corner)
	return true


func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void:
	var board_size := Vector2(size.x * 0.70, size.z * 0.68)
	var board_back := MeshInstance3D.new()
	board_back.name = "%s_CarvedBoard" % id
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(board_size.x + 0.18, 0.055, board_size.y + 0.18)
	board_back.mesh = board_mesh
	board_back.position = Vector3(0.0, size.y + 0.10, 0.0)
	board_back.material_override = _mat(Color(0.20, 0.11, 0.055))
	area.add_child(board_back)
	var columns := 3 if id == "common_table" else 6
	var rows := columns
	var square_size := Vector3(board_size.x / columns - 0.018, 0.018, board_size.y / rows - 0.018)
	var square_batches: Array[MultiMeshInstance3D] = []
	for parity in range(2):
		var count := (columns * rows + 1) / 2 if parity == 0 else columns * rows / 2
		var material := _mat(Color(0.38, 0.24, 0.12) if parity == 0 else Color(0.16, 0.095, 0.045))
		var batch := _make_multimesh_batch("%s_BoardSquares_%d" % [id, parity], shared_box_mesh, int(count), material)
		batch.reparent(area, false)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		square_batches.append(batch)
	var square_indices := [0, 0]
	for row in range(rows):
		for column in range(columns):
			var x := -board_size.x * 0.5 + board_size.x * (float(column) + 0.5) / float(columns)
			var z := -board_size.y * 0.5 + board_size.y * (float(row) + 0.5) / float(rows)
			var parity := (row + column) % 2
			square_batches[parity].multimesh.set_instance_transform(square_indices[parity], Transform3D(Basis.IDENTITY.scaled(square_size), Vector3(x, size.y + 0.14, z)))
			square_indices[parity] += 1
			if id == "common_table" and (row + column) % 2 == 1 and row != 1:
				var mark := MeshInstance3D.new()
				mark.name = "%s_CarvedMark_%d_%d" % [id, row, column]
				var mark_mesh := CylinderMesh.new()
				mark_mesh.top_radius = 0.075
				mark_mesh.bottom_radius = 0.075
				mark_mesh.height = 0.035
				mark_mesh.radial_segments = 10
				mark.mesh = mark_mesh
				mark.position = Vector3(x, size.y + 0.18, z)
				mark.material_override = _mat(Color(0.72, 0.48, 0.20) if row < 2 else Color(0.72, 0.68, 0.48))
				area.add_child(mark)
	var chair_batch: MultiMeshInstance3D = null
	if not bool(area.get_meta("authored_social_furniture", false)):
		chair_batch = _make_multimesh_batch("%s_ChairParts" % id, shared_box_mesh, 4, _mat(Color(0.20, 0.12, 0.065)))
		chair_batch.reparent(area, false)
		chair_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_make_board_game_chair(area, Vector3(0.0, 0.0, size.z * 0.90), PI, chair_batch, 0)
	_make_board_game_chair(area, Vector3(0.0, 0.0, -size.z * 0.90), 0.0, chair_batch, 2)
	# The actual villager visits through GreyfenLifeController; no table-body copy.


func _make_multimesh_batch(node_name: String, mesh: Mesh, count: int, material: Material, use_colors: bool = false) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	# These batches are authored static geometry. Disable transform
	# interpolation so their build-time instance transforms do not trigger
	# physics-interpolation writes outside the physics tick.
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = use_colors
	var base_mesh := mesh if mesh != null else shared_box_mesh
	_ensure_mesh_surface_materials(base_mesh, _valid_material_or_fallback(null))
	batch.mesh = base_mesh
	batch.instance_count = count
	instance.multimesh = batch
	instance.material_override = null if material == null and base_mesh.get_surface_count() > 1 else _valid_material_or_fallback(material)
	instance.visibility_range_end = 58.0
	if _compatibility_budget_mode():
		# Static environment batches do not need individual shadow maps on the
		# Compatibility/ANGLE target. The authored directional light and contact
		# materials still ground the route while this removes repeated shadow
		# submissions from Greyfen and forest dressing.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(instance)
	return instance


func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void:
	var well_mesh := opening_well_mesh if opening_well_mesh != null else load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if well_mesh == null or well_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen well is unavailable")
		return
	visual.mesh = well_mesh
	var well_tints := {
		"medieval_brick": Color(0.69, 0.67, 0.61),
		"plaster": Color(0.72, 0.72, 0.67),
		"timber": Color(0.44, 0.33, 0.22),
		"roof_tiles": Color(0.42, 0.24, 0.16),
		"glazing": Color(0.10, 0.25, 0.29),
		"metal": Color(0.24, 0.27, 0.27),
	}
	var well_quality := str(settings.settings.get("quality_preset", "balanced"))
	for surface_index in well_mesh.get_surface_count():
		var surface_name := well_mesh.surface_get_name(surface_index)
		if not well_tints.has(surface_name):
			push_error("Unknown authored Greyfen well surface: " + surface_name)
			return
		var material: StandardMaterial3D = _mat(well_tints[surface_name]) if surface_name == "glazing" else world_materials.get_material(surface_name, well_quality, well_tints[surface_name], 0.0, false)
		visual.set_surface_override_material(surface_index, material)
	var body := StaticBody3D.new()
	body.name = "GreyfenWellBody"
	body.position = pos + Vector3(0, 0.42, 0)
	zone_root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "GreyfenWellCollision"
	var cylinder := preload("res://scripts/immutable_collision_shapes.gd").cylinder(0.87, 0.84)
	collision.shape = cylinder
	body.add_child(collision)


func _add_physical_door_visual(area: Node3D, zone_target: String) -> void:
	var frame_material := _mat(Color(0.16, 0.13, 0.10))
	var door_material := _mat(Color(0.08, 0.055, 0.040))
	var frame := MeshInstance3D.new()
	frame.name = "InteriorDoorFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(2.5, 3.0, 0.24)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.5, 0)
	frame.material_override = frame_material
	area.add_child(frame)
	var door := MeshInstance3D.new()
	door.name = "InteriorDoor"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.65, 2.45, 0.12)
	door.mesh = door_mesh
	door.position = Vector3(0, 1.25, -0.15)
	door.material_override = door_material
	area.add_child(door)
	var label := Label3D.new()
	label.name = "InteriorDoorDestination"
	label.text = _zone_display_name(zone_target)
	label.position = Vector3(0, 2.2, -0.24)
	label.font_size = 22
	label.modulate = Color(0.82, 0.72, 0.53, 0.85)
	label.visible = false
	area.add_child(label)


func _boss_is_resolved(id: String) -> bool:
	if id == "bell_eater" and bool(story_state.get_flag("bell_eater_legacy_retired", false)):
		return true
	if id == "bog_wretch" and quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
		return true
	if id == "captain_senn" and (quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or str(story_state.get_flag("senn_fate", "")) not in ["", "unresolved"]):
		return true
	if not bool(enemy_defs.get(id, {}).get("boss", false)):
		return false
	var story_resolved: String = str({
		"bell_eater": "bell_eater_defeated",
		"rootbound_colossus": "rootbound_colossus_defeated",
		"ashwing": "ashwing_defeated",
	}.get(id, ""))
	if story_resolved != "" and bool(story_state.get_flag(story_resolved, false)):
		return true
	if id == "white_hart_avatar" and bool(story_state.get_flag("final_choice_completed", false)):
		return true
	var saved: Variant = boss_saved_states.get(id, {})
	if typeof(saved) == TYPE_DICTIONARY:
		var saved_outcome := str(saved.get("outcome", ""))
		return saved_outcome in ["defeated", "release", "testimony", "witness", "mercy", "duty", "ash"]
	return false


func _finish_greyfen_ground_surfaces() -> void:
	if zone_root.find_child("GreyfenGroundMerged", true, false) != null:
		return
	var prepared := preload("res://scripts/prepared_zone_geometry.gd").mesh("greyfen_ground")
	if prepared == null:
		return
	var source_surfaces: Array[MeshInstance3D] = []
	for ground_name in ["GroundNorthWest", "GroundNorthEast", "GroundSouthWest", "GroundSouthEast", "GroundCenterNorthVisual", "GroundCenterSouthVisual"]:
		var ground := zone_root.find_child(ground_name, true, false)
		if ground == null:
			continue
		var surface := ground as MeshInstance3D if ground is MeshInstance3D else ground.get_node_or_null("Surface") as MeshInstance3D
		if surface != null:
			source_surfaces.append(surface)
	if source_surfaces.size() != 6:
		push_error("Greyfen authored ground is incomplete: %d/6 surfaces" % source_surfaces.size())
		return
	var ground_visual := MeshInstance3D.new()
	ground_visual.name = "GreyfenGroundMerged"
	ground_visual.mesh = prepared
	var ground_material := world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color.WHITE, 0.0, false).duplicate() as StandardMaterial3D
	ground_material.resource_name = "GreyfenGroundBlended"
	ground_material.vertex_color_use_as_albedo = true
	ground_visual.material_override = ground_material
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_root.add_child(ground_visual)
	for surface in source_surfaces:
		surface.visible = false
		surface.queue_free()




func _finish_greyfen_paved_roads() -> void:
	for road_name in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road := zone_root.find_child(road_name, true, false) as MeshInstance3D
		if road == null:
			continue
		road.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("greyfen_" + road_name)
		road.scale = Vector3.ONE
		var road_material := _road_material(true, Color(0.16, 0.13, 0.09)).duplicate() as StandardMaterial3D
		road_material.vertex_color_use_as_albedo = true
		road.material_override = road_material



func _make_low_berm(pos: Vector3, size: Vector3, color: Color) -> void:
	if _is_river_excluded(pos,size.z*0.5):
		return
	if spatial_service != null and spatial_service.is_reserved(pos, maxf(size.x, size.z) * 0.5 + 0.35):
		return
	var body = StaticBody3D.new()
	body.name = "LowBerm"
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(size)
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	mesh.name = "RoundedEarthBerm"
	mesh.mesh = preload("res://scripts/prepared_zone_geometry.gd").mesh("wychwood_berm_" + preload("res://scripts/prepared_zone_geometry.gd").geometry_key(size, pos))
	mesh.material_override = _terrain_material("WychwoodEarthBerm", color)
	body.add_child(mesh)


func _make_road_ruts() -> void:
	# The base road already contains the authored wear pass. These repeated
	# raised strips read as tiled blocks at gameplay distance and add no route
	# or narrative value, so keep the dressing hook without spawning them.
	return


func _make_lantern_rhythm() -> void:
	var points = [
		[Vector3(-2.85, 0, 6.4), true],
		[Vector3(2.95, 0, 2.2), false],
		[Vector3(-2.75, 0, -2.5), false],
		[Vector3(2.85, 0, -6.8), false],
		[Vector3(-2.55, 0, -10.8), false]
	]
	for item in points:
		_make_lantern_post(item[0], false, bool(item[1]))
		_make_fake_light_pool("RoadLanternPool", item[0] + Vector3(0, 0.035, 0.25), Vector3(1.55, 0.022, 1.05), Color(0.32, 0.135, 0.045))


func _make_shrine_approach() -> void:
	_append_prepared_detail("ShrinePathWarmEdge_30f036e1cc")
	_append_prepared_detail("ShrinePathWarmEdge_fb53d619f3")
	_make_lantern_post(Vector3(3.4, 0, -4.25), true, true)
	_make_lantern_post(Vector3(7.65, 0, -6.1), true, false)
	for offset in [Vector3(-1.25, 0, 0.75), Vector3(1.18, 0, 0.82), Vector3(-1.55, 0, -0.25), Vector3(1.5, 0, -0.3)]:
		_make_shrine_candle(Vector3(6.0, 0, -7.0) + offset)
	_make_hanging_cloth(Vector3(4.85, 1.25, -7.95), Vector3(0.55, 0.72, 0.035), Color(0.34, 0.035, 0.030))
	_make_hanging_cloth(Vector3(7.05, 1.20, -7.92), Vector3(0.48, 0.62, 0.035), Color(0.12, 0.16, 0.13))


func _make_village_story_clusters() -> void:
	_make_firewood_stack(Vector3(-6.8, 0, -0.8), -12.0)
	_make_firewood_stack(Vector3(8.2, 0, -1.2), 24.0)
	_make_broken_fence_run(Vector3(-4.8, 0, -7.0), true)
	_make_broken_fence_run(Vector3(4.9, 0, -10.4), true)
	_make_wheelbarrow(Vector3(-7.9, 0, 6.6), -22.0)
	_make_wheelbarrow(Vector3(11.7, 0, -10.2), 35.0)
	for pos in [Vector3(-10.7, 0, 10.5), Vector3(12.4, 0, 6.3), Vector3(15.6, 0, 7.7)]:
		_make_mourning_marker(pos)
	for pos in [Vector3(-12.7, 0, -5.8), Vector3(-11.8, 0, -4.3), Vector3(13.2, 0, -5.4), Vector3(14.2, 0, -4.0)]:
		_make_fake_fog_bank(pos)


func _make_crow_silhouettes() -> void:
	# These sub-metre silhouettes share geometry; default spheres spend thousands
	# of triangles on each wing despite occupying only a few gameplay pixels.
	var silhouette_mesh := SphereMesh.new()
	silhouette_mesh.radial_segments = 12
	silhouette_mesh.rings = 7
	var index := 0
	for item in [
		[Vector3(-8.5, 5.8, -11.5), -14.0],
		[Vector3(10.2, 5.5, -10.6), 18.0]
	]:
		var root := Node3D.new()
		root.name = "CrowSilhouette"
		root.position = item[0]
		root.rotation_degrees.y = float(item[1])
		root.set_meta("motion_type", "bird")
		root.set_meta("wildlife_reactive", true)
		root.set_meta("motion_phase", float(index) * 1.7)
		root.set_meta("motion_amount", 4.0)
		zone_root.add_child(root)
		_add_crow_part(root, "CrowBody", silhouette_mesh, Vector3(0, 0, 0), Vector3(0.18, 0.12, 0.30), Color(0.010, 0.010, 0.012))
		_add_crow_part(root, "CrowHead", silhouette_mesh, Vector3(0, 0.04, -0.13), Vector3(0.12, 0.11, 0.13), Color(0.016, 0.016, 0.018))
		var beak_mesh := CylinderMesh.new()
		beak_mesh.top_radius = 0.0
		beak_mesh.bottom_radius = 0.055
		beak_mesh.height = 0.16
		beak_mesh.radial_segments = 8
		_add_crow_part(root, "CrowBeak", beak_mesh, Vector3(0, 0.04, -0.22), Vector3(0.72, 0.72, 1.0), Color(0.15, 0.12, 0.08), Vector3(-90, 0, 0))
		_add_crow_part(root, "CrowWingLeft", silhouette_mesh, Vector3(-0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, -18))
		_add_crow_part(root, "CrowWingRight", silhouette_mesh, Vector3(0.18, 0.0, -0.01), Vector3(0.30, 0.035, 0.13), Color(0.008, 0.008, 0.010), Vector3(0, 0, 18))
		_add_crow_part(root, "CrowTail", silhouette_mesh, Vector3(0, -0.02, 0.24), Vector3(0.12, 0.04, 0.24), Color(0.008, 0.008, 0.010), Vector3(18, 0, 0))
		index += 1


func _make_quality_survival_cluster(pos: Vector3) -> void:
	_make_visual_box("QualityMudSack", pos + Vector3(0.0, 0.16, 0.0), Vector3(0.58, 0.32, 0.36), Color(0.17, 0.115, 0.065))
	_make_visual_box("QualityBrokenBoard", pos + Vector3(0.62, 0.13, -0.14), Vector3(0.88, 0.08, 0.18), Color(0.13, 0.075, 0.038))
	_make_visual_box("QualityBucket", pos + Vector3(-0.52, 0.24, 0.18), Vector3(0.32, 0.48, 0.32), Color(0.10, 0.085, 0.065))
	_make_visual_box("QualityClothScrap", pos + Vector3(0.1, 0.045, 0.5), Vector3(0.82, 0.018, 0.32), Color(0.23, 0.055, 0.044))


func _make_fake_light_pool(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var pool := _make_visual_box(name, pos, size, color)
	pool.set_meta("night_only_geometry", true)


func _make_lantern_post(pos: Vector3, shrine_style: bool, casts_light: bool) -> void:
	_make_prop_box("LanternPost", pos + Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternArm", pos + Vector3(0.28, 1.38, 0), Vector3(0.56, 0.08, 0.08), Color(0.12, 0.070, 0.038))
	_make_visual_box("LanternCage", pos + Vector3(0.56, 1.18, 0), Vector3(0.22, 0.34, 0.22), Color(0.055, 0.040, 0.030))
	var glow_color = Color(1.0, 0.50, 0.16) if not shrine_style else Color(0.74, 0.88, 0.58)
	var glow = MeshInstance3D.new()
	glow.name = "LanternGlow"
	glow.set_meta("visual_name", "LanternGlow")
	var glow_mesh := SphereMesh.new()
	glow_mesh.radial_segments = 5
	glow_mesh.rings = 3
	glow.mesh = glow_mesh
	glow.scale = Vector3(0.16, 0.22, 0.16)
	glow.position = pos + Vector3(0.56, 1.17, 0)
	glow.material_override = _emissive_mat(glow_color, 1.25)
	glow.set_meta("world_prop_kind", "lantern")
	glow.set_meta("world_prop_id", "lantern_glow")
	zone_root.add_child(glow)
	if casts_light:
		_make_light("SpawnWarmRead" if not shrine_style else "Shrine Beacon", pos + Vector3(0.45, 1.45, 0), glow_color, 0.9)


func _make_firewood_stack(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "FirewoodStack"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	for i in range(5):
		var log_mesh = MeshInstance3D.new()
		log_mesh.name = "StackedLog"
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.085
		mesh.height = 1.05
		mesh.radial_segments = 6
		log_mesh.mesh = mesh
		log_mesh.position = Vector3(-0.34 + float(i) * 0.17, 0.18 + float(i % 2) * 0.13, 0)
		log_mesh.rotation_degrees = Vector3(90, 0, 90)
		log_mesh.material_override = _mat(Color(0.135, 0.078, 0.044))
		root.add_child(log_mesh)


func _make_broken_fence_run(pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var offset = Vector3(0, 0, float(i) * 0.85) if vertical else Vector3(float(i) * 0.85, 0, 0)
		_make_visual_box("BrokenFencePost", pos + offset + Vector3(0, 0.42 + 0.06 * float(i % 2), 0), Vector3(0.12, 0.84, 0.12), Color(0.13, 0.075, 0.040))
	var rail_size = Vector3(0.10, 0.10, 2.35) if vertical else Vector3(2.35, 0.10, 0.10)
	_make_visual_box("BrokenFenceRail", pos + Vector3(0.42 if not vertical else 0, 0.72, 0.42 if vertical else 0), rail_size, Color(0.16, 0.095, 0.050))


func _make_house_collision(parent: Node3D) -> void:
	var body = StaticBody3D.new()
	body.name = "HouseCollision"
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(4.2, 2.4, 3.4))
	shape.shape = box
	shape.position.y = 1.2
	body.add_child(shape)
	# The authored roof rises above the solid wall box. A camera-only volume
	# catches the orbit ray without widening the player's road collision.
	var camera_roof := StaticBody3D.new()
	camera_roof.name = "CameraRoofCollision"
	camera_roof.collision_layer = 1 << 6
	camera_roof.collision_mask = 0
	parent.add_child(camera_roof)
	var roof_shape := CollisionShape3D.new()
	var roof_box := preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(5.0, 1.6, 4.2))
	roof_shape.shape = roof_box
	roof_shape.position.y = 3.2
	camera_roof.add_child(roof_shape)
	if int(parent.get_meta("house_variant", 0)) == 1:
		for x in [-0.98, 0.98]:
			var post := CollisionShape3D.new()
			var post_box := preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(0.12, 1.60, 0.12))
			post.shape = post_box
			post.position = Vector3(x, 0.95, -2.36)
			body.add_child(post)


func _make_world_prop_anchor(id: String, kind: String, pos: Vector3, state_key: String = "") -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "WorldPropAnchor_%s" % id.capitalize()
	anchor.position = river_safe_position(pos, 0.42)
	anchor.set_meta("world_prop_id", id)
	anchor.set_meta("world_prop_kind", kind)
	anchor.set_meta("world_prop_state_key", state_key)
	zone_root.add_child(anchor)
	return anchor


func _make_collision_box(name: String, pos: Vector3, size: Vector3) -> void:
	# Fitted modular art and collision must not both render as overlapping shells.
	ZoneBuildContext.add_collision_box(zone_root, name, pos, size)


func _make_black_feather_scatter(base_name: String, center: Vector3, count: int, spread: float) -> void:
	for i in range(count):
		var offset = Vector3(_scene_randf_range(-spread, spread), 0.0, _scene_randf_range(-spread * 0.55, spread * 0.55))
		var feather = _make_visual_box(base_name, center + offset, Vector3(_scene_randf_range(0.24, 0.42), 0.022, 0.070), Color(0.010, 0.010, 0.012))
		feather.rotation_degrees.y = _scene_randf_range(-35.0, 35.0)


func _make_broken_charm(name: String, pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "%sBoneHalfA" % name, Vector3(-0.08, 0.0, 0.0), Vector3(0.17, 0.035, 0.24), Color(0.54, 0.50, 0.42))
	_add_visual_box_child(root, "%sBoneHalfB" % name, Vector3(0.11, 0.0, 0.04), Vector3(0.15, 0.035, 0.20), Color(0.48, 0.45, 0.38))
	_add_visual_box_child(root, "%sRedThread" % name, Vector3(0.0, 0.024, -0.12), Vector3(0.38, 0.020, 0.045), Color(0.30, 0.035, 0.028))


func _make_dark_track(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	if current_zone_id == "wychwood":
		var trace := MeshInstance3D.new()
		trace.name = name
		trace.mesh = world_materials.make_organic_ground_patch(size, pos)
		trace.position = pos
		trace.material_override = world_materials.get_material("wet_mud", str(settings.settings.get("quality_preset", "balanced")), color.lightened(0.18), 0.0, false)
		trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zone_root.add_child(trace)
		return
	var track = _make_visual_box(name, pos, size, color)
	track.rotation_degrees.y = _scene_randf_range(-8.0, 8.0)


func _make_claw_marks(name: String, pos: Vector3, vertical: bool) -> void:
	for i in range(3):
		var mark_pos = pos + (Vector3(0.0, 0.11 * float(i), 0.0) if vertical else Vector3(0.18 * float(i), 0.0, 0.0))
		var size = Vector3(0.045, 0.50, 0.035) if vertical else Vector3(0.055, 0.030, 0.62)
		var mark = _make_visual_box(name, mark_pos, size, Color(0.030, 0.018, 0.012))
		mark.rotation_degrees.z = -18.0 if vertical else 0.0


func _make_post_ghoulkin_story_clue() -> void:
	if zone_root == null or zone_root.find_child("RoadCrowsPostVictoryBootTracks", true, false) != null:
		return
	_make_dark_track("RoadCrowsPostVictoryBootTracks", Vector3(0.95, 0.087, -4.25), Vector3(0.30, 0.026, 1.9), Color(0.020, 0.018, 0.015))
	_make_dark_track("RoadCrowsPostVictoryClawTracks", Vector3(1.45, 0.088, -4.75), Vector3(0.34, 0.025, 1.55), Color(0.060, 0.022, 0.016))
	_append_prepared_detail("RoadCrowsPostVictoryCutThread_632cbbbd56")
	_make_black_feather_scatter("RoadCrowsPostVictoryFeathers", Vector3(0.35, 0.11, -3.95), 4, 0.55)
	_make_named_interactable("post_victory_token", "clue", "Examine the token in the dead creature's hand", Vector3(1.35, 0.0, -4.55), Color(0.46, 0.28, 0.12), Vector3(0.55, 0.55, 0.55))


func _make_all_evidence_safe_edge() -> void:
	if zone_root == null or zone_root.find_child("RoadCrowsEvidenceSafeEdge", true, false) != null:
		return
	var edge := _make_visual_box("RoadCrowsEvidenceSafeEdge", Vector3(-4.25, 0.085, -6.25), Vector3(1.8, 0.025, 0.42), Color(0.31, 0.27, 0.14))
	edge.set_meta("narrative_state", "safe_edge")


func _upload_static_batch(instance: MultiMeshInstance3D, transforms: Array, colors: Array = []) -> void:
	preload("res://scripts/static_multimesh_upload.gd").upload(instance.multimesh, transforms, colors, preload("res://scripts/performance_comparison_options.gd").enabled("static_bounds"))


func _flush_authored_tree_assets() -> bool:
	# Use the selected Quaternius tree mesh for Balanced/Quality. The old
	# primitive trunk+sphere fallback remains available for Potato and for
	# import failures, so the visual upgrade never removes the route.
	if asset_helper == null or settings == null:
		return false
	if str(settings.settings.get("quality_preset", "balanced")) == "potato":
		return false
	var grouped_items: Dictionary = {}
	for item in tree_batch_data:
		var role := str(item.get("asset_role", "forest_tree"))
		if not grouped_items.has(role):
			grouped_items[role] = []
		grouped_items[role].append(item)
	if grouped_items.is_empty():
		return false
	var created_batch := false
	for role in grouped_items.keys():
		var role_items: Array = grouped_items[role]
		if role_items.is_empty():
			continue
		var source: Dictionary = asset_helper.forest_tree_source(str(role))
		if source.is_empty():
			return false
		var source_mesh: Mesh = source.mesh
		var source_material: Material = source.material
		var source_bounds: AABB = source.bounds
		var source_scale: float = source.scale
		var source_normalization: Transform3D = source.normalization
		if source_material == null and source_mesh.get_surface_count() == 1:
			source_material = world_materials.get_material("forest_ground", str(settings.settings.get("quality_preset", "balanced")), Color(0.08, 0.18, 0.09), 0.0, false)
		var trees := _make_multimesh_batch("AuthoredTreeBatch_%s" % str(role).replace(":", "_"), source_mesh, role_items.size(), source_material)
		var camera_clearance := StaticBody3D.new()
		camera_clearance.name = "TreeCameraClearance_%s" % str(role).replace(":", "_")
		camera_clearance.collision_layer = 1 << 6
		camera_clearance.collision_mask = 0
		zone_root.add_child(camera_clearance)
		var tree_transforms: Array = []
		for index in range(role_items.size()):
			var item: Dictionary = role_items[index]
			var tree_position: Vector3 = item.get("asset_position", Vector3.ZERO)
			var tree_scale: Vector3 = item.get("asset_scale", Vector3.ONE)
			var tree_yaw: float = float(item.get("asset_yaw", 0.0))
			var basis := Basis.from_euler(Vector3(0.0, tree_yaw, 0.0)).scaled(tree_scale)
			var tree_transform := Transform3D(basis, tree_position) * source_normalization
			tree_transforms.append(tree_transform)
			# The orbit must stop before the rendered crown, not only its narrow
			# walking collider. This layer is shared with authored camera roofs.
			var clearance_shape := CollisionShape3D.new()
			var clearance_box := preload("res://scripts/immutable_collision_shapes.gd").box(source_bounds.size * tree_scale * source_scale)
			clearance_shape.shape = clearance_box
			clearance_shape.transform = Transform3D(Basis(Vector3.UP, tree_yaw), tree_transform * source_bounds.get_center())
			camera_clearance.add_child(clearance_shape)
		_upload_static_batch(trees, tree_transforms)
		created_batch = true
	return created_batch


func _first_route_palette_key(node: Node) -> String:
	var combined = _node_keyword_path(node)
	if combined.contains("roof"):
		return "roof"
	if combined.contains("house") or combined.contains("wall") or combined.contains("plaster"):
		return "wall"
	if combined.contains("tree") or combined.contains("trunk"):
		return "trunk"
	if combined.contains("leaf") or combined.contains("leaves") or combined.contains("crown"):
		return "leaves"
	if combined.contains("rock") or combined.contains("rubble") or combined.contains("stone") or combined.contains("pathstone"):
		return "rock"
	if combined.contains("grave"):
		return "grave"
	if combined.contains("shrine"):
		return "shrine"
	if combined.contains("fence") or combined.contains("wood") or combined.contains("cart") or combined.contains("crate") or combined.contains("barrel") or combined.contains("torch"):
		return "wood"
	if combined.contains("road") or combined.contains("mud") or combined.contains("ground") or combined.contains("berm"):
		return "ground"
	if combined.contains("cloth") or combined.contains("cloak") or combined.contains("robe"):
		return "cloth"
	if combined.contains("skin") or combined.contains("face") or combined.contains("sister") or combined.contains("npc") or combined.contains("villager"):
		return "skin"
	if combined.contains("ghoul") or combined.contains("monster") or combined.contains("enemy"):
		return "monster"
	if combined.contains("metal") or combined.contains("sword") or combined.contains("blade"):
		return "metal"
	return ""


func _mesh_needs_visible_fallback(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null:
		return true
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.get_active_material(surface_index)
		if material == null:
			return true
		if _is_bad_white_material(material) and not _surface_has_authored_colors(mesh_instance.mesh, surface_index, material):
			return true
	return mesh_instance.mesh.get_surface_count() == 0


func _first_route_material(key: String) -> StandardMaterial3D:
	var cache_key = "first_route:%s" % key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var colors = {
		"rock": Color(0.17, 0.18, 0.16),
		"trunk": Color(0.16, 0.095, 0.055),
		"leaves": Color(0.055, 0.15, 0.075),
		"roof": Color(0.13, 0.055, 0.035),
		"wall": Color(0.30, 0.22, 0.15),
		"grave": Color(0.30, 0.31, 0.30),
		"shrine": Color(0.37, 0.38, 0.35),
		"ground": Color(0.11, 0.10, 0.07),
		"wood": Color(0.16, 0.09, 0.045),
		"metal": Color(0.44, 0.44, 0.42),
		"cloth": Color(0.11, 0.12, 0.13),
		"skin": Color(0.66, 0.52, 0.40),
		"monster": Color(0.15, 0.20, 0.14)
	}
	var material = StandardMaterial3D.new()
	material.albedo_color = colors.get(key, Color(0.24, 0.24, 0.22))
	material.roughness = 0.86
	if key == "metal":
		material.metallic = 0.35
		material.roughness = 0.52
	material_cache[cache_key] = material
	return material


func _zone_half_extents(zone_id: String) -> Vector2:
	return get_zone_half_extents(zone_id)


func _make_invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = "WorldBoundary"
	body.position = pos
	zone_root.add_child(body)
	var shape = CollisionShape3D.new()
	var box = preload("res://scripts/immutable_collision_shapes.gd").box(size)
	shape.shape = box
	body.add_child(shape)


func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void:
	var chair := Node3D.new()
	chair.name = "BoardGameChair_North" if position.z < 0.0 else "BoardGameChair_South"
	chair.position = position
	chair.rotation.y = yaw
	area.add_child(chair)
	if batch == null:
		return
	var orientation := Basis(Vector3.UP, yaw)
	batch.multimesh.set_instance_transform(first_index, Transform3D(orientation.scaled(Vector3(0.90, 0.14, 0.82)), position + orientation * Vector3(0.0, 0.62, 0.0)))
	batch.multimesh.set_instance_transform(first_index + 1, Transform3D(orientation.scaled(Vector3(0.90, 0.90, 0.12)), position + orientation * Vector3(0.0, 1.02, 0.32)))


func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	if mesh == null or fallback == null:
		return 0
	var applied := 0
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) == null:
			mesh.surface_set_material(surface_index, fallback)
			applied += 1
	return applied


func _valid_material_or_fallback(material: Material) -> Material:
	if material != null:
		return material
	if world_materials != null and world_materials.has_method("get_fallback_material"):
		return world_materials.get_fallback_material()
	return _first_route_material("ground")


func _zone_display_name(zone_id: String) -> String:
	return zone_id.replace("_", " ").capitalize()


func _make_shrine_candle(pos: Vector3) -> void:
	_make_visual_box("ShrineCandle", pos + Vector3(0, 0.17, 0), Vector3(0.10, 0.34, 0.10), Color(0.72, 0.62, 0.44))
	var flame = MeshInstance3D.new()
	flame.name = "ShrineCandleFlame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radial_segments = 5
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.scale = Vector3(0.07, 0.11, 0.07)
	flame.position = pos + Vector3(0, 0.39, 0)
	flame.material_override = _emissive_mat(Color(1.0, 0.48, 0.14), 1.1)
	zone_root.add_child(flame)


func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	var columns := 5
	var rows := 3
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var v := float(row) / float(rows)
		for column in range(columns + 1):
			var u := float(column) / float(columns)
			var x := (u - 0.5) * size.x
			var hem := (0.07 + 0.04 * sin(float(column) * 2.3)) * v * v
			var y := (0.5 - v) * size.y + hem
			var z := sin(u * PI * 4.0) * 0.055 + v * v * 0.035
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3.BACK)
			uvs.append(Vector2(u, v))
	for row in range(rows):
		for column in range(columns):
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var cloth_mesh := ArrayMesh.new()
	cloth_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth := MeshInstance3D.new()
	cloth.name = "HangingClothDrape_%d" % zone_root.get_child_count()
	cloth.position = pos
	cloth.mesh = cloth_mesh
	var cloth_material := _mat(color).duplicate() as StandardMaterial3D
	cloth_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_material.roughness = 0.96
	cloth.material_override = cloth_material
	zone_root.add_child(cloth)


func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "WheelbarrowStoryProp"
	root.position = pos
	root.rotation_degrees.y = yaw
	zone_root.add_child(root)
	_add_visual_box_child(root, "WheelbarrowTray", Vector3(0, 0.38, 0), Vector3(1.0, 0.24, 0.55), Color(0.15, 0.085, 0.045))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, -0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	_add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, 0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	var wheel = MeshInstance3D.new()
	wheel.name = "WheelbarrowWheel"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.08
	mesh.radial_segments = 8
	wheel.mesh = mesh
	wheel.position = Vector3(0.53, 0.22, 0)
	wheel.rotation_degrees.z = 90
	wheel.material_override = _mat(Color(0.055, 0.040, 0.030))
	root.add_child(wheel)


func _make_mourning_marker(pos: Vector3) -> void:
	_make_visual_box("MourningMarkerPost", pos + Vector3(0, 0.38, 0), Vector3(0.09, 0.76, 0.09), Color(0.11, 0.075, 0.050))
	_make_visual_box("MourningMarkerCross", pos + Vector3(0, 0.62, 0), Vector3(0.54, 0.07, 0.07), Color(0.11, 0.075, 0.050))
	_make_hanging_cloth(pos + Vector3(0.25, 0.45, 0.01), Vector3(0.18, 0.28, 0.025), Color(0.30, 0.030, 0.025))


func _make_fake_fog_bank(pos: Vector3) -> void:
	_make_visual_box("LowColdFogBank", pos + Vector3(0, 0.07, 0), Vector3(1.6, 0.10, 0.55), Color(0.105, 0.125, 0.118))


func _add_crow_part(parent: Node3D, name: String, mesh: Mesh, local_pos: Vector3, scale_value: Vector3, color: Color, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name
	part.mesh = mesh
	part.position = local_pos
	part.scale = scale_value
	part.rotation_degrees = rotation_degrees
	part.material_override = _mat(color)
	part.visibility_range_end = 32.0
	parent.add_child(part)
	return part


func _add_visual_box_child(parent: Node3D, name: String, local_pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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


func _node_keyword_path(node: Node) -> String:
	var combined = ""
	var current: Node = node
	while current != null and current != zone_root:
		combined += " " + String(current.name).to_lower()
		current = current.get_parent()
	return combined


func _is_bad_white_material(material: Material) -> bool:
	if material == null:
		return true
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		var has_texture = standard.albedo_texture != null
		var color = standard.albedo_color
		return not has_texture and color.r > 0.85 and color.g > 0.85 and color.b > 0.85
	return false


func _surface_has_authored_colors(mesh: Mesh, surface_index: int, material: Material) -> bool:
	if not material is StandardMaterial3D or not (material as StandardMaterial3D).vertex_color_use_as_albedo:
		return false
	var arrays := mesh.surface_get_arrays(surface_index)
	if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return false
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.size() != (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		return false
	# White albedo multiplies authored vertex colors; it is not missing paint.
	for color in colors:
		if color.r <= 0.85 or color.g <= 0.85 or color.b <= 0.85:
			return true
	return false


func get_zone_half_extents(zone_id: String) -> Vector2:
	return SpatialSurfaceContract.zone_half_extents(zone_id)


func _gameplay_script(id: String) -> Script:
	return coordinator._gameplay_script(id)

func _opening_stage_required_before_control(stage: String) -> bool:
	return coordinator._opening_stage_required_before_control(stage)

func _record_opening_stage(root: Node3D, stage: String) -> void:
	coordinator._record_opening_stage(root, stage)

func _opening_presentation_present(root: Node3D) -> bool:
	return coordinator._opening_presentation_present(root)

func _prepare_opening_after_menu_render() -> void:
	coordinator._prepare_opening_after_menu_render()

func _restore_browser_session(delta: float) -> void:
	coordinator._restore_browser_session(delta)

func _on_virtual_gameplay_action(request: Dictionary) -> void:
	coordinator._on_virtual_gameplay_action(request)

func _dispatch_gameplay_action(action: String, target_instance_id: int = 0) -> void:
	coordinator._dispatch_gameplay_action(action, target_instance_id)

func _request_pause_or_back(event: InputEvent) -> void:
	coordinator._request_pause_or_back(event)

func _invalidate_interaction_prompt() -> void:
	coordinator._invalidate_interaction_prompt()

func _publish_interaction_prompt() -> void:
	coordinator._publish_interaction_prompt()

func _on_input_context_changed(_context: String) -> void:
	coordinator._on_input_context_changed(_context)

func _on_transient_input_reset(reason: String) -> void:
	coordinator._on_transient_input_reset(reason)

func _begin_gameplay_handoff(reason: String) -> void:
	coordinator._begin_gameplay_handoff(reason)

func _finish_gameplay_handoff() -> void:
	coordinator._finish_gameplay_handoff()

func _play_voice_smoke_test(voice_id: String, label: String) -> void:
	coordinator._play_voice_smoke_test(voice_id, label)

func _setup_runtime() -> void:
	coordinator._setup_runtime()

func _bind_runtime_services(services: Dictionary) -> void:
	coordinator._bind_runtime_services(services)

func _ensure_gameplay_runtime() -> void:
	coordinator._ensure_gameplay_runtime()

func _new_game() -> void:
	coordinator._new_game()

func _cancel_new_game_request() -> void:
	coordinator._cancel_new_game_request()

func _handle_quit_request() -> void:
	coordinator._handle_quit_request()

func _request_zone_load(zone_id: String, spawn_pos: Vector3) -> void:
	coordinator._request_zone_load(zone_id, spawn_pos)

func request_seamless_boundary_transition(zone_id: String, spawn_pos: Vector3, edge_id: String = "") -> bool:
	return coordinator.request_seamless_boundary_transition(zone_id, spawn_pos, edge_id)

func _perform_direct_zone_load(zone_id: String, spawn_pos: Vector3) -> void:
	coordinator._perform_direct_zone_load(zone_id, spawn_pos)

func _perform_requested_zone_load() -> void:
	coordinator._perform_requested_zone_load()

func _zone_encounter_packs(zone_id: String, recorded_journey: Dictionary = {}) -> Array[String]:
	return coordinator._zone_encounter_packs(zone_id, recorded_journey)

func _load_zone_after_runtime_pack(zone_id: String, spawn_pos: Vector3) -> void:
	coordinator._load_zone_after_runtime_pack(zone_id, spawn_pos)

func _begin_travel_download(zone_id: String, extras: Array[String] = []) -> void:
	coordinator._begin_travel_download(zone_id, extras)

func _finish_travel_download() -> void:
	coordinator._finish_travel_download()

func _wait_for_campaign_pack(zone_id: String, spawn_pos: Vector3, request_serial: int) -> void:
	coordinator._wait_for_campaign_pack(zone_id, spawn_pos, request_serial)

func _wait_for_opening_pack(zone_id: String, spawn_pos: Vector3, request_serial: int, encounter_packs: Array[String] = []) -> void:
	coordinator._wait_for_opening_pack(zone_id, spawn_pos, request_serial, encounter_packs)

func _recover_failed_pack_load(reason: String = "The destination could not load. Please retry.") -> void:
	coordinator._recover_failed_pack_load(reason)

func _zone_requires_campaign_pack(zone_id: String) -> bool:
	return coordinator._zone_requires_campaign_pack(zone_id)

func _zone_requires_opening_pack(zone_id: String) -> bool:
	return coordinator._zone_requires_opening_pack(zone_id)

func _start_new_game_world() -> void:
	coordinator._start_new_game_world()

func _request_background_runtime_packs() -> void:
	coordinator._request_background_runtime_packs()

func _opening_route_is_active() -> bool:
	return coordinator._opening_route_is_active()

func should_defer_neighbor_prewarm() -> bool:
	return coordinator.should_defer_neighbor_prewarm()

func _schedule_background_runtime_packs(delay_seconds: float = BACKGROUND_RUNTIME_DELAY_SECONDS) -> void:
	coordinator._schedule_background_runtime_packs(delay_seconds)

func _schedule_opening_save(generation: int) -> void:
	coordinator._schedule_opening_save(generation)

func load_save_state(data: Dictionary) -> void:
	coordinator.load_save_state(data)

func _apply_loaded_journey(data: Dictionary) -> void:
	coordinator._apply_loaded_journey(data)

func _journey_load_pending() -> bool:
	return coordinator._journey_load_pending()

func _on_prepared_journey_load(prepared: Dictionary) -> void:
	coordinator._on_prepared_journey_load(prepared)

func _cancel_journey_load() -> void:
	coordinator._cancel_journey_load()

func _publish_journey_arrival() -> void:
	coordinator._publish_journey_arrival()

func _queue_journey_models_refresh() -> void:
	coordinator._queue_journey_models_refresh()

func _refresh_journey_models() -> void:
	coordinator._refresh_journey_models()

func _request_journey_load(selection: Dictionary) -> void:
	coordinator._request_journey_load(selection)

func _open_journal_section(section_id: String) -> void:
	coordinator._open_journal_section(section_id)

func _apply_pending_player_restore() -> void:
	coordinator._apply_pending_player_restore()

func _spawn_player(pos: Vector3) -> void:
	coordinator._spawn_player(pos)

func _bind_spatial_player_body() -> void:
	coordinator._bind_spatial_player_body()

func _load_zone(zone_id: String, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	coordinator._load_zone(zone_id, spawn_pos)

func _advance_zone_transition() -> void:
	coordinator._advance_zone_transition()

func _apply_zone_audio(zone_id: String) -> void:
	coordinator._apply_zone_audio(zone_id)

func _schedule_deferred_zone_audio(zone_id: String, root: Node3D) -> void:
	coordinator._schedule_deferred_zone_audio(zone_id, root)

func _finish_deferred_zone_audio(zone_id: String, root: Node3D) -> void:
	coordinator._finish_deferred_zone_audio(zone_id, root)

func _activate_prewarmed_player_runtime() -> void:
	coordinator._activate_prewarmed_player_runtime()

func _start_campaign_visual_prewarm() -> void:
	coordinator._start_campaign_visual_prewarm()

func _cancel_campaign_visual_prewarm() -> void:
	coordinator._cancel_campaign_visual_prewarm()

func should_defer_visual_role(role: String, category: String) -> bool:
	return coordinator.should_defer_visual_role(role, category)

func _schedule_deferred_visual_roles(root: Node3D) -> void:
	coordinator._schedule_deferred_visual_roles(root)

func _run_deferred_visual_roles(root: Node3D) -> void:
	coordinator._run_deferred_visual_roles(root)

func _deferred_visual_markers(root: Node3D) -> Array[Node3D]:
	return coordinator._deferred_visual_markers(root)

func _run_campaign_visual_prewarm(generation: int, role_index: int) -> void:
	coordinator._run_campaign_visual_prewarm(generation, role_index)

func _schedule_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	coordinator._schedule_zone_runtime_finalize(zone_id, root, service, enemies, navigation_pending)

func _finish_zone_runtime_finalize(zone_id: String, root: Node3D, service: Node, enemies: Array, navigation_pending: bool) -> void:
	coordinator._finish_zone_runtime_finalize(zone_id, root, service, enemies, navigation_pending)

func _finish_prewarmed_greyfen_runtime() -> void:
	coordinator._finish_prewarmed_greyfen_runtime()

func _recover_failed_zone_load(previous_zone_id: String) -> void:
	coordinator._recover_failed_zone_load(previous_zone_id)

func _grounded_spawn_position(candidate: Vector3) -> Variant:
	return coordinator._grounded_spawn_position(candidate)

func _valid_cached_enemies(entries: Array) -> Array:
	return coordinator._valid_cached_enemies(entries)

func _zone_state_signature(zone_id: String = current_zone_id) -> int:
	return coordinator._zone_state_signature(zone_id)

func _begin_zone_world_reads(zone_id: String, reset: bool = true) -> void:
	coordinator._begin_zone_world_reads(zone_id, reset)

func _end_zone_world_reads() -> void:
	coordinator._end_zone_world_reads()

func _deferred_free_zone(retired_root: Node) -> void:
	coordinator._deferred_free_zone(retired_root)

func _release_zone_render_resources(root: Node) -> void:
	coordinator._release_zone_render_resources(root)

func _retire_zone_root(retired_root: Node) -> void:
	coordinator._retire_zone_root(retired_root)

func _bind_retirement_material(root: Node) -> void:
	coordinator._bind_retirement_material(root)

func _anchor_retired_materials(root: Node) -> void:
	coordinator._anchor_retired_materials(root)

func _keep_retired_material(material: Material) -> void:
	coordinator._keep_retired_material(material)

func _anchor_shared_skinned_resources(root: Node) -> void:
	coordinator._anchor_shared_skinned_resources(root)

func _skinned_resource_fingerprint(branch: Node) -> String:
	return coordinator._skinned_resource_fingerprint(branch)

func _record_loading_metrics(metrics: Dictionary) -> void:
	coordinator._record_loading_metrics(metrics)

func _record_first_control() -> void:
	coordinator._record_first_control()

func _create_owned_timer(seconds: float, ignore_time_scale: bool = false) -> Timer:
	return coordinator._create_owned_timer(seconds, ignore_time_scale)

func _cancel_owned_timers() -> void:
	coordinator._cancel_owned_timers()

func _quiesce_zone_runtime(root: Node) -> void:
	coordinator._quiesce_zone_runtime(root)

func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false, disable_collision: bool = true, disable_process: bool = true) -> void:
	coordinator._cache_route_zone(zone_id, root, enemies, signature, keep_visible, disable_collision, disable_process)

func _cache_route_spatial_service(zone_id: String, service: Node) -> void:
	coordinator._cache_route_spatial_service(zone_id, service)

func _release_route_spatial_service(zone_id: String) -> void:
	coordinator._release_route_spatial_service(zone_id)

func _release_active_spatial_service() -> void:
	coordinator._release_active_spatial_service()

func _defer_cached_zone_collision_disable(zone_id: String) -> void:
	coordinator._defer_cached_zone_collision_disable(zone_id)

func _activate_cached_zone(zone_id: String) -> Node3D:
	return coordinator._activate_cached_zone(zone_id)

func _remove_root_from_route_cache(root: Node) -> void:
	coordinator._remove_root_from_route_cache(root)

func _trim_route_zone_cache(preferred_ids: Array) -> void:
	coordinator._trim_route_zone_cache(preferred_ids)

func _set_zone_collision_enabled(node: Node, enabled: bool) -> void:
	coordinator._set_zone_collision_enabled(node, enabled)

func _collect_zone_collision_targets(root: Node) -> Array:
	return coordinator._collect_zone_collision_targets(root)

func _set_single_zone_collision_enabled(node: Node, enabled: bool) -> void:
	coordinator._set_single_zone_collision_enabled(node, enabled)

func _schedule_zone_autosave() -> void:
	coordinator._schedule_zone_autosave()

func _clear_route_zone_cache(preserve_root: Node3D = null) -> void:
	coordinator._clear_route_zone_cache(preserve_root)

func prepare_resource_shutdown() -> void:
	coordinator.prepare_resource_shutdown()

func finalize_resource_shutdown() -> void:
	coordinator.finalize_resource_shutdown()

func zone_lifecycle_snapshot() -> Dictionary:
	return coordinator.zone_lifecycle_snapshot()

func _subtree_node_count(root: Node) -> int:
	return coordinator._subtree_node_count(root)

func _install_opening_soundscape(zone_id: String) -> void:
	coordinator._install_opening_soundscape(zone_id)

func _handle_interaction(area) -> void:
	coordinator._handle_interaction(area)

func _handle_village_place(id: String) -> void:
	coordinator._handle_village_place(id)

func _on_minigame_result(game_id: String, outcome: String) -> void:
	coordinator._on_minigame_result(game_id, outcome)

func _on_minigame_state_changed() -> void:
	coordinator._on_minigame_state_changed()

func _handle_road_of_crows_clue(area) -> void:
	coordinator._handle_road_of_crows_clue(area)

func _road_evidence_count() -> int:
	return coordinator._road_evidence_count()

func _apply_campaign_arrival(zone_id: String) -> void:
	coordinator._apply_campaign_arrival(zone_id)

func _road_ready_to_report() -> bool:
	return coordinator._road_ready_to_report()

func _legacy_report_choice_required() -> bool:
	return coordinator._legacy_report_choice_required()

func _crow_shrine_choice_ready() -> bool:
	return coordinator._crow_shrine_choice_ready()

func _chapel_can_open() -> bool:
	return coordinator._chapel_can_open()

func _ensure_cemetery_ambush() -> void:
	coordinator._ensure_cemetery_ambush()

func _spawn_crow_shrine_choice() -> void:
	coordinator._spawn_crow_shrine_choice()

func _restore_greyfen_cemetery_state() -> void:
	coordinator._restore_greyfen_cemetery_state()

func _relocate_anwen_to_cemetery() -> void:
	coordinator._relocate_anwen_to_cemetery()

func _handle_dialogue_action(action: Dictionary) -> void:
	coordinator._handle_dialogue_action(action)

func _finish_story_action(action: Dictionary) -> void:
	coordinator._finish_story_action(action)

func _persist_story_action() -> void:
	coordinator._persist_story_action()

func _story_has_active_combat() -> bool:
	return coordinator._story_has_active_combat()

func _apply_dialogue_action(action: Dictionary) -> bool:
	return coordinator._apply_dialogue_action(action)

func _dialogue_action_requires_zone_rebuild(action: Dictionary) -> bool:
	return coordinator._dialogue_action_requires_zone_rebuild(action)

func _dialogue_action_available(action: Dictionary) -> bool:
	return coordinator._dialogue_action_available(action)

func _dialogue_action_unavailable_reason(action: Dictionary) -> String:
	return coordinator._dialogue_action_unavailable_reason(action)

func _quest_required_objectives_done(quest_id: String) -> bool:
	return coordinator._quest_required_objectives_done(quest_id)

func _story_choice_prerequisites_done(quest_id: String, choice_id: String) -> bool:
	return coordinator._story_choice_prerequisites_done(quest_id, choice_id)

func _on_launch_accepted() -> void:
	coordinator._on_launch_accepted()

func _on_opening_pack_progress(_pack_id: String, _progress: float) -> void:
	coordinator._on_opening_pack_progress(_pack_id, _progress)

func _on_startup_pack_ready(_pack_id: String) -> void:
	coordinator._on_startup_pack_ready(_pack_id)

func _begin_opening_prewarm_if_ready(generation: int) -> void:
	coordinator._begin_opening_prewarm_if_ready(generation)

func _wait_for_startup_packs_then_prewarm(generation: int) -> void:
	coordinator._wait_for_startup_packs_then_prewarm(generation)

func _begin_opening_prewarm() -> void:
	coordinator._begin_opening_prewarm()

func _prepare_opening_services(generation: int) -> void:
	coordinator._prepare_opening_services(generation)

func _wait_for_opening_build_slot(generation: int) -> void:
	coordinator._wait_for_opening_build_slot(generation)

func _opening_attempt_current(generation: int) -> bool:
	return coordinator._opening_attempt_current(generation)

func _prepare_opening_resources(generation: int) -> void:
	coordinator._prepare_opening_resources(generation)

func _discard_menu_opening() -> void:
	coordinator._discard_menu_opening()

func _restart_menu_opening() -> void:
	coordinator._restart_menu_opening()

func _opening_prepare_failed(message: String) -> void:
	coordinator._opening_prepare_failed(message)

func _abort_opening_prewarm(prewarm_root: Node3D, prewarm_service: Node, message: String, notify_failure: bool = true) -> void:
	coordinator._abort_opening_prewarm(prewarm_root, prewarm_service, message, notify_failure)

func _publish_web_opening_state(state: String, message: String = "", progress: float = -1.0) -> void:
	coordinator._publish_web_opening_state(state, message, progress)

func _prewarm_greyfen_after_menu_frame(generation: int = -1) -> void:
	coordinator._prewarm_greyfen_after_menu_frame(generation)

func _apply_web_opening_boot_material_budget(world_root: Node, player_root: Node, force_for_test := false) -> void:
	coordinator._apply_web_opening_boot_material_budget(world_root, player_root, force_for_test)

func _apply_opening_boot_material(geometry: GeometryInstance3D) -> void:
	coordinator._apply_opening_boot_material(geometry)

func _restore_opening_boot_material_entry(entry: Dictionary) -> void:
	coordinator._restore_opening_boot_material_entry(entry)

func _restore_opening_boot_materials(generation: int) -> void:
	coordinator._restore_opening_boot_materials(generation)

func _run_opening_detail_stage(generation: int) -> void:
	coordinator._run_opening_detail_stage(generation)

func _defer_opening_renderables(published_nodes: Array[Node]) -> void:
	coordinator._defer_opening_renderables(published_nodes)

func _complete_ending(ending: String) -> bool:
	return coordinator._complete_ending(ending)

func _show_ending_consequence(ending: String) -> void:
	coordinator._show_ending_consequence(ending)

func _show_completed_epilogue() -> void:
	coordinator._show_completed_epilogue()

func _on_player_blade_contact(contact: Dictionary) -> void:
	coordinator._on_player_blade_contact(contact)

func _on_player_arrow_unavailable() -> void:
	coordinator._on_player_arrow_unavailable()

func _on_player_arrow(request: Dictionary) -> void:
	coordinator._on_player_arrow(request)

func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void:
	coordinator._on_arrow_impact(result, arrow_id, damage, zone_instance)

func _present_surface_contact(result: Dictionary, arrow: bool) -> void:
	coordinator._present_surface_contact(result, arrow)

func _civilian_contact_candidates(position: Vector3, radius: float) -> Array:
	return coordinator._civilian_contact_candidates(position, radius)

func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	coordinator._make_arrow_trail(origin, endpoint, color)

func _on_player_beam_phase(phase: String) -> void:
	coordinator._on_player_beam_phase(phase)

func _on_player_beam(charge_ratio: float, direction: Vector3) -> void:
	coordinator._on_player_beam(charge_ratio, direction)

func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	coordinator._make_oathfire_beam(origin, endpoint, charge_ratio, rich_effect)

func _clear_oathfire_effects() -> void:
	coordinator._clear_oathfire_effects()

func _on_player_footstep() -> void:
	coordinator._on_player_footstep()

func _on_player_parried() -> void:
	coordinator._on_player_parried()

func _on_player_blocked(_amount: float) -> void:
	coordinator._on_player_blocked(_amount)

func _on_player_hurt(_amount: float) -> void:
	coordinator._on_player_hurt(_amount)

func _on_player_stamina_exhausted(_action: String) -> void:
	coordinator._on_player_stamina_exhausted(_action)

func _use_potion() -> void:
	coordinator._use_potion()

func _throw_bomb() -> void:
	coordinator._throw_bomb()

func _use_inventory_item(item_id: String) -> Dictionary:
	return coordinator._use_inventory_item(item_id)

func _preparation_item_result(item_id: String, ok: bool, message: String, operation: String = "use", consumed: int = 0) -> Dictionary:
	return coordinator._preparation_item_result(item_id, ok, message, operation, consumed)

func _update_preparation_context() -> void:
	coordinator._update_preparation_context()

func _show_preparation_menu() -> void:
	coordinator._show_preparation_menu()

func _craft_preparation_item(item_id: String) -> void:
	coordinator._craft_preparation_item(item_id)

func _use_preparation_item(item_id: String) -> void:
	coordinator._use_preparation_item(item_id)

func _set_inventory_preference(key: String, value: String) -> void:
	coordinator._set_inventory_preference(key, value)

func _learn_preparation_practice(upgrade_id: String) -> void:
	coordinator._learn_preparation_practice(upgrade_id)

func _respec_unavailable_reason() -> String:
	return coordinator._respec_unavailable_reason()

func _redistribute_practices() -> void:
	coordinator._redistribute_practices()

func _use_quick_item(item_id: String) -> void:
	coordinator._use_quick_item(item_id)

func _finish_preparation_operation(result: Dictionary, vendor_id: String = "") -> void:
	coordinator._finish_preparation_operation(result, vendor_id)

func _refresh_preparation_after_operation(result: Dictionary, vendor_id: String, screen_key: String) -> void:
	coordinator._refresh_preparation_after_operation(result, vendor_id, screen_key)

func _purchase_from_vendor(vendor_id: String, item_id: String, quantity: int = 1) -> void:
	coordinator._purchase_from_vendor(vendor_id, item_id, quantity)

func _sell_to_vendor(vendor_id: String, item_id: String, quantity: int) -> void:
	coordinator._sell_to_vendor(vendor_id, item_id, quantity)

func _on_enemy_died(enemy) -> void:
	coordinator._on_enemy_died(enemy)

func _try_complete_black_dog_investigation() -> void:
	coordinator._try_complete_black_dog_investigation()

func _try_complete_oren_thread_trace(publish_return := true) -> void:
	coordinator._try_complete_oren_thread_trace(publish_return)

func _record_encounter_knowledge(enemy) -> void:
	coordinator._record_encounter_knowledge(enemy)

func _on_enemy_damaged(enemy, current: float, maximum: float) -> void:
	coordinator._on_enemy_damaged(enemy, current, maximum)

func _on_enemy_windup_started(enemy) -> void:
	coordinator._on_enemy_windup_started(enemy)

func _on_enemy_attack_resolved(enemy, parried: bool, contact_position: Vector3) -> void:
	coordinator._on_enemy_attack_resolved(enemy, parried, contact_position)

func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void:
	coordinator._on_enemy_parry_window_opened(enemy, duration)

func _on_quest_completed(id: String) -> void:
	coordinator._on_quest_completed(id)

func _apply_progression_to_player() -> void:
	coordinator._apply_progression_to_player()

func _on_progression_changed() -> void:
	coordinator._on_progression_changed()

func _queue_progression_rewards() -> void:
	coordinator._queue_progression_rewards()

func _flush_progression_rewards() -> void:
	coordinator._flush_progression_rewards()

func _collect_progression_rewards() -> bool:
	return coordinator._collect_progression_rewards()

func _on_progression_arrival(zone_id: String) -> void:
	coordinator._on_progression_arrival(zone_id)

func _record_bog_stagger(enemy, source: String) -> void:
	coordinator._record_bog_stagger(enemy, source)

func _expose_bog_core(enemy, method: String) -> void:
	coordinator._expose_bog_core(enemy, method)

func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void:
	coordinator._on_target_lock_changed(target_actor, locked)

func _update_target_lock_hud() -> void:
	coordinator._update_target_lock_hud()

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	coordinator._on_combat_impact(pos, heavy)

func _hitstop(seconds: float) -> void:
	coordinator._hitstop(seconds)

func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
			return true
	return false

func _nearest_living_enemy(max_distance: float):
	return coordinator._nearest_living_enemy(max_distance)

func _remove_interactable(id: String) -> void:
	if zone_root == null:
		return
	for child in zone_root.get_children():
		if str(child.get("interaction_id")) == id:
			if child.has_method("set_interaction_enabled"):
				child.set_interaction_enabled(false)
			coordinator._remove_interaction_candidate(child)
			child.queue_free()

func _consume_story_choice_interactable(id: String) -> void:
	coordinator._consume_story_choice_interactable(id)

func _has_interactable(id: String) -> bool:
	if zone_root == null:
		return false
	for child in zone_root.get_children():
		if not child.is_queued_for_deletion() and (str(child.name) == id or str(child.get("interaction_id")) == id):
			return true
	return false

func _mark_interaction_removed(area) -> void:
	coordinator._mark_interaction_removed(area)

func save_world_state() -> Dictionary:
	return coordinator.save_world_state()

func load_world_state(state: Dictionary) -> void:
	coordinator.load_world_state(state)

func _on_player_died() -> void:
	coordinator._on_player_died()

func _on_dialogue_closed_audio() -> void:
	coordinator._on_dialogue_closed_audio()

func _finish_covenant_if_ready() -> void:
	coordinator._finish_covenant_if_ready()

func _on_touch_layout_unavailable(reason: String) -> void:
	coordinator._on_touch_layout_unavailable(reason)

func _pause_game() -> void:
	coordinator._pause_game()

func _show_companion_commands() -> void:
	coordinator._show_companion_commands()

func _show_touch_actions() -> void:
	coordinator._show_touch_actions()

func _on_touch_quick_action(action: String) -> void:
	coordinator._on_touch_quick_action(action)

func _resume_game() -> void:
	coordinator._resume_game()

func _handle_setting(action: String) -> void:
	coordinator._handle_setting(action)

func _apply_runtime_settings(current_settings: Dictionary) -> void:
	coordinator._apply_runtime_settings(current_settings)

func _queue_story_guidance_refresh() -> void:
	coordinator._queue_story_guidance_refresh()

func _apply_story_guidance_refresh() -> void:
	coordinator._apply_story_guidance_refresh()

func _refresh_tracker() -> void:
	coordinator._refresh_tracker()

func _show_current_objective_guidance(seconds: float = 5.0) -> void:
	coordinator._show_current_objective_guidance(seconds)

func _refresh_equipment_readout() -> void:
	coordinator._refresh_equipment_readout()

func _reconcile_preparation_objective() -> void:
	coordinator._reconcile_preparation_objective()

func _guard_tutorial_hint() -> String:
	return coordinator._guard_tutorial_hint()

func _update_tutorial_prompts() -> void:
	coordinator._update_tutorial_prompts()

func _update_compass() -> void:
	coordinator._update_compass()

func _compass_state_signature() -> String:
	return coordinator._compass_state_signature()

func _compass_needs_refresh() -> bool:
	return coordinator._compass_needs_refresh()

func _distance_to_tracked_interactable(objective_view: Dictionary) -> int:
	return coordinator._distance_to_tracked_interactable(objective_view)

func _tracked_objective_id(quest_id: String) -> String:
	return coordinator._tracked_objective_id(quest_id)

func _tracked_objective_text(quest_id: String, objective_id: String) -> String:
	return coordinator._tracked_objective_text(quest_id, objective_id)

func _keep_player_in_world() -> void:
	coordinator._keep_player_in_world()

func _safe_loaded_position(zone: String, pos: Vector3) -> Vector3:
	return coordinator._safe_loaded_position(zone, pos)

func _recover_from_river(body: Node, river_z: float, span: float) -> void:
	coordinator._recover_from_river(body, river_z, span)

func _is_river_recovery_position(zone: String, pos: Vector3) -> bool:
	return coordinator._is_river_recovery_position(zone, pos)

func river_safe_path(points: Array, margin: float = 0.90) -> Array:
	return coordinator.river_safe_path(points, margin)

func _make_wychwood_clearing_floor() -> void:
	coordinator._make_wychwood_clearing_floor()

func _make_wychwood_winding_path() -> void:
	coordinator._make_wychwood_winding_path()

func _wychwood_path_center(z: float) -> float:
	return coordinator._wychwood_path_center(z)

func _make_stylized_house(pos: Vector3) -> void:
	coordinator._make_stylized_house(pos)

func _add_house_module(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float, node_name: String) -> Node3D:
	return coordinator._add_house_module(parent, role_name, scale_value, local_pos, yaw, node_name)

func _make_house_facade_module(role_name: String, scale_value: Vector3) -> MeshInstance3D:
	return coordinator._make_house_facade_module(role_name, scale_value)

func _add_house_gables(parent: Node3D, plaster: Color, timber: Color, authored_facades: bool) -> void:
	coordinator._add_house_gables(parent, plaster, timber, authored_facades)

func _add_house_gabled_roof(parent: Node3D, color: Color) -> MeshInstance3D:
	return coordinator._add_house_gabled_roof(parent, color)

func _append_house_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	coordinator._append_house_quad(vertices, normals, uvs, indices, a, b, c, d)

func _add_house_box(parent: Node3D, node_name: String, local_pos: Vector3, size: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> Node3D:
	return coordinator._add_house_box(parent, node_name, local_pos, size, color, local_rot)

func _add_lit_window(parent: Node3D, local_pos: Vector3) -> void:
	coordinator._add_lit_window(parent, local_pos)

func _add_role_child(parent: Node3D, role_name: String, scale_value: Vector3, local_pos: Vector3, yaw: float) -> Node3D:
	return coordinator._add_role_child(parent, role_name, scale_value, local_pos, yaw)

func _make_roof(pos: Vector3, size: Vector3, color: Color) -> void:
	coordinator._make_roof(pos, size, color)

func _make_cemetery_scene(pos: Vector3) -> void:
	coordinator._make_cemetery_scene(pos)

func _make_collapsed_road(pos: Vector3) -> void:
	coordinator._make_collapsed_road(pos)

func _prepare_dialogue_presence(content: Dictionary) -> Dictionary:
	return coordinator._prepare_dialogue_presence(content)

func _stage_dialogue_moment(area) -> void:
	coordinator._stage_dialogue_moment(area)

func _on_dialogue_page_changed(_speaker: String, _speaker_id: String, _page_index: int, _total_pages: int) -> void:
	coordinator._on_dialogue_page_changed(_speaker, _speaker_id, _page_index, _total_pages)

func _on_dialogue_topic_requested(context_id: String, topic_id: String, revision_key: String) -> void:
	coordinator._on_dialogue_topic_requested(context_id, topic_id, revision_key)

func _face_npc_toward_player(npc: Node3D) -> void:
	coordinator._face_npc_toward_player(npc)

func _release_dialogue_facing() -> void:
	coordinator._release_dialogue_facing()

func _present_castle_clue(id: String, title: String) -> void:
	coordinator._present_castle_clue(id, title)

func _make_blocked_gate(prompt: String, pos: Vector3, message: String):
	return coordinator._make_blocked_gate(prompt, pos, message)

func _update_interaction_focus() -> void:
	coordinator._update_interaction_focus()

func _interaction_focus_needs_refresh() -> bool:
	return coordinator._interaction_focus_needs_refresh()

func _refresh_interaction_candidates() -> void:
	coordinator._refresh_interaction_candidates()

func _prune_invalid_interaction_candidates() -> void:
	coordinator._prune_invalid_interaction_candidates()

func _remove_interaction_candidate(area) -> void:
	coordinator._remove_interaction_candidate(area)

func _interaction_target_valid(area: Area3D) -> bool:
	return coordinator._interaction_target_valid(area)

func _set_interactable_label_visible(area: Node, visible: bool) -> void:
	coordinator._set_interactable_label_visible(area, visible)

func _ensure_bell_eater() -> void:
	coordinator._ensure_bell_eater()

func _retire_bell_eater() -> void:
	coordinator._retire_bell_eater()

func _open_rootbound_encounter() -> void:
	coordinator._open_rootbound_encounter()

func _evacuate_bell_eater_bystanders() -> void:
	coordinator._evacuate_bell_eater_bystanders()

func _restore_bell_eater_bystanders() -> void:
	coordinator._restore_bell_eater_bystanders()

func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void:
	coordinator._on_boss_controller_phase_changed(boss_id, phase)

func _on_boss_checkpoint(controller: Node) -> void:
	coordinator._on_boss_checkpoint(controller)

func _on_boss_resolved(boss_id: String, outcome: String) -> void:
	coordinator._on_boss_resolved(boss_id, outcome)

func _apply_boss_resolution_contract(boss_id: String) -> void:
	coordinator._apply_boss_resolution_contract(boss_id)

func _publish_halvern_exit() -> void:
	coordinator._publish_halvern_exit()

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	coordinator._on_boss_peaceful_resolution(boss_id, outcome, enemy)

func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	coordinator._on_boss_phase_changed(enemy, phase)

func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void:
	coordinator._on_boss_special_attack(enemy, attack_id, contact_position, radius, damage, parried)

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	coordinator._activate_wychwood_wave(ids, cue)

func _ensure_wychwood_wave() -> void:
	coordinator._ensure_wychwood_wave()

func checkpoint_return_position() -> Vector3:
	return coordinator.checkpoint_return_position()

func _has_active_encounter_enemy() -> bool:
	return coordinator._has_active_encounter_enemy()

func _enemy_attack_token(enemy: Node, claim: bool) -> bool:
	return coordinator._enemy_attack_token(enemy, claim)

func _make_hut(pos: Vector3) -> void:
	coordinator._make_hut(pos)

func _clear_environment_batch_buffers() -> void:
	coordinator._clear_environment_batch_buffers()

func _validate_zone_render_resources(root: Node) -> Dictionary:
	return coordinator._validate_zone_render_resources(root)

func _make_hit_spark(pos: Vector3, heavy: bool) -> void:
	coordinator._make_hit_spark(pos, heavy)

func _visual_role_for_interactable(id: String) -> String:
	return coordinator._visual_role_for_interactable(id)

func _role_for_prop(name: String) -> String:
	return coordinator._role_for_prop(name)

func _build_global_environment() -> void:
	coordinator._build_global_environment()

func _grass_material(color: Color) -> StandardMaterial3D:
	return coordinator._grass_material(color)

func _read_json(path: String):
	return coordinator._read_json(path)

