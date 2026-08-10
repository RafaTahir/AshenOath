extends Node3D

const RIVER_HALF_SPAN := 2.25
const DEFAULT_BRIDGE_HALF_WIDTH := 2.35

var zone_id := ""
var river_center := 999.0
var half_extents := Vector2(20.0, 16.0)
var reserved_corridors: Array[Dictionary] = []
var exclusions: Array[Dictionary] = []
var safe_spawns: Array[Vector3] = []
var bridges: Dictionary = {}
var gates: Dictionary = {}
var navigation_region: NavigationRegion3D
var navigation_map: RID

func _exit_tree() -> void:
	if navigation_map.is_valid():
		NavigationServer3D.free_rid(navigation_map)
		navigation_map = RID()

func configure(id: String, river_z: float, extents: Vector2) -> void:
	zone_id = id
	river_center = river_z
	half_extents = extents
	reserved_corridors.clear()
	exclusions.clear()
	safe_spawns.clear()
	bridges.clear()
	gates.clear()
	_register_zone_defaults()

func register_bridge(id: String, bank_a: Vector3, bank_b: Vector3, half_width: float) -> void:
	bridges[id] = {"bank_a": bank_a, "bank_b": bank_b, "half_width": half_width}

func register_gate(id: String, center: Vector3, arrival: Vector3, half_size: Vector2) -> void:
	gates[id] = {"center": center, "arrival": arrival, "half_size": half_size}
	reserve_corridor(id, center, half_size)
	add_safe_spawn(arrival)

func reserve_exclusion(id: String, center: Vector3, half_size: Vector2) -> void:
	exclusions.append({"id": id, "center": center, "half_size": half_size})

func reserve_corridor(id: String, center: Vector3, half_size: Vector2) -> void:
	reserved_corridors.append({"id": id, "center": center, "half_size": half_size})

func add_safe_spawn(position: Vector3) -> void:
	var safe := _clamp_to_bounds(position, 0.8)
	if is_river_excluded(safe, 0.8):
		safe.z = river_center + float(bank_for(position)) * (RIVER_HALF_SPAN + 0.8)
	safe_spawns.append(safe)

func build_navigation(parent: Node3D) -> NavigationRegion3D:
	var previous := parent.find_child("DeterministicNavigationRegion", false, false)
	if previous is NavigationRegion3D and previous.navigation_mesh != null:
		navigation_region = previous
		if not navigation_map.is_valid():
			navigation_map = NavigationServer3D.map_create()
			NavigationServer3D.map_set_active(navigation_map, true)
		navigation_region.set_navigation_map(navigation_map)
		return navigation_region
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "DeterministicNavigationRegion"
	# Each zone owns one contiguous authored polygon; cross-zone travel uses gates.
	# Edge connection rasterization is unnecessary and produced Web warnings.
	navigation_region.use_edge_connections = false
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.38
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.35
	nav_mesh.agent_max_slope = 46.0
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	# Route segments remain authoritative for river and bridge safety. A single
	# deterministic navigation polygon avoids overlapping raster edges in Web.
	_add_rect(vertices, polygons, -half_extents.x, -half_extents.y, half_extents.x, half_extents.y)
	nav_mesh.vertices = vertices
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = nav_mesh
	parent.add_child(navigation_region)
	if not navigation_map.is_valid():
		navigation_map = NavigationServer3D.map_create()
		NavigationServer3D.map_set_active(navigation_map, true)
	navigation_region.set_navigation_map(navigation_map)
	return navigation_region

func get_navigation_map() -> RID:
	return navigation_map

func is_reserved(position: Vector3, margin: float = 0.0) -> bool:
	return _inside_entries(position, reserved_corridors, margin)

func is_river_excluded(position: Vector3, margin: float = 0.0) -> bool:
	if river_center >= 900.0 or absf(position.z - river_center) >= RIVER_HALF_SPAN + margin:
		return false
	for bridge in bridges.values():
		if absf(position.x) <= float(bridge.half_width) - minf(margin, 0.35):
			return false
	return true

func bank_for(position: Vector3) -> int:
	if river_center >= 900.0:
		return 0
	return -1 if position.z < river_center else 1

func validate_position(position: Vector3, clearance: float = 0.8, preferred_bank: int = 0) -> Vector3:
	var result := _clamp_to_bounds(position, clearance)
	var requested_bank := preferred_bank if preferred_bank != 0 else bank_for(position)
	if is_river_excluded(result, clearance):
		result.z = river_center + float(requested_bank) * (RIVER_HALF_SPAN + clearance)
	if _inside_entries(result, exclusions, clearance):
		return nearest_safe(result, requested_bank)
	result.y = maxf(result.y, 0.0)
	return result

func validate_segment(start: Vector3, destination: Vector3, clearance: float = 0.9) -> bool:
	var distance := start.distance_to(destination)
	var samples := maxi(2, ceili(distance / 0.45))
	for index in range(samples + 1):
		var point := start.lerp(destination, float(index) / float(samples))
		if is_river_excluded(point, clearance) or _inside_entries(point, exclusions, clearance):
			return false
	return true

func build_route(start: Vector3, destination: Vector3, clearance: float = 0.9) -> Array[Vector3]:
	var source := validate_position(start, clearance, bank_for(start))
	var target := validate_position(destination, clearance, bank_for(destination))
	var result: Array[Vector3] = [source]
	if bank_for(source) != 0 and bank_for(target) != 0 and bank_for(source) != bank_for(target):
		var bridge := _nearest_bridge(source, target)
		if bridge.is_empty():
			return []
		var source_anchor: Vector3 = bridge.bank_a if bank_for(bridge.bank_a) == bank_for(source) else bridge.bank_b
		var target_anchor: Vector3 = bridge.bank_b if source_anchor == bridge.bank_a else bridge.bank_a
		if not validate_segment(source, source_anchor, clearance):
			return []
		result.append(source_anchor)
		result.append(Vector3((source_anchor.x + target_anchor.x) * 0.5, maxf(source.y, target.y), river_center))
		result.append(target_anchor)
		if not validate_segment(target_anchor, target, clearance):
			return []
	elif not validate_segment(source, target, clearance):
		return []
	result.append(target)
	return _deduplicate(result)

func validate_path(points: Array, clearance: float = 0.9) -> Array:
	var result: Array = []
	for raw_point in points:
		var point: Vector3 = raw_point
		if result.is_empty():
			result.append(validate_position(point, clearance, bank_for(point)))
			continue
		var segment := build_route(result.back(), point, clearance)
		if segment.is_empty():
			continue
		for index in range(1, segment.size()):
			result.append(segment[index])
	return result

func nearest_safe(position: Vector3, preferred_bank: int = 0) -> Vector3:
	var wanted_bank := preferred_bank if preferred_bank != 0 else bank_for(position)
	var base := _clamp_to_bounds(position, 1.0)
	if wanted_bank != 0 and river_center < 900.0:
		base.z = river_center + float(wanted_bank) * maxf(absf(base.z - river_center), RIVER_HALF_SPAN + 1.0)
	var candidates: Array[Vector3] = [base]
	for radius in [1.25, 2.25, 3.5, 5.0]:
		for angle_index in range(8):
			var angle := TAU * float(angle_index) / 8.0
			candidates.append(_clamp_to_bounds(base + Vector3(cos(angle), 0.0, sin(angle)) * radius, 1.0))
	for candidate in candidates:
		if wanted_bank != 0 and bank_for(candidate) != wanted_bank:
			continue
		if is_river_excluded(candidate, 0.8) or _inside_entries(candidate, exclusions, 0.6):
			continue
		if not is_position_occupied(candidate, 0.42, 1.65):
			return candidate
	return _nearest_spawn(position, wanted_bank)

func is_position_occupied(position: Vector3, radius: float, height: float) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * (height * 0.5 + 0.08))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _nearest_spawn(position: Vector3, preferred_bank: int = 0) -> Vector3:
	var valid := safe_spawns.filter(func(spawn): return preferred_bank == 0 or bank_for(spawn) == preferred_bank)
	if valid.is_empty():
		valid = safe_spawns
	if valid.is_empty():
		return _clamp_to_bounds(position, 1.0)
	var best: Vector3 = valid[0]
	var best_distance := position.distance_squared_to(best)
	for spawn in valid:
		var distance := position.distance_squared_to(spawn)
		if distance < best_distance:
			best = spawn
			best_distance = distance
	return best

func _nearest_bridge(start: Vector3, destination: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for bridge in bridges.values():
		var distance: float = start.distance_squared_to(bridge.bank_a) + destination.distance_squared_to(bridge.bank_b)
		var reverse_distance: float = start.distance_squared_to(bridge.bank_b) + destination.distance_squared_to(bridge.bank_a)
		distance = minf(distance, reverse_distance)
		if distance < best_distance:
			best = bridge
			best_distance = distance
	return best

func _inside_entries(position: Vector3, entries: Array[Dictionary], margin: float) -> bool:
	for entry in entries:
		var center: Vector3 = entry.center
		var half_size: Vector2 = entry.half_size
		if absf(position.x - center.x) <= half_size.x + margin and absf(position.z - center.z) <= half_size.y + margin:
			return true
	return false

func _clamp_to_bounds(position: Vector3, clearance: float) -> Vector3:
	var result := position
	result.x = clampf(result.x, -half_extents.x + clearance, half_extents.x - clearance)
	result.z = clampf(result.z, -half_extents.y + clearance, half_extents.y - clearance)
	result.y = maxf(result.y, 0.0)
	return result

func _add_rect(vertices: PackedVector3Array, polygons: Array[PackedInt32Array], x0: float, z0: float, x1: float, z1: float) -> void:
	if x1 - x0 < 0.2 or z1 - z0 < 0.2:
		return
	var offset := vertices.size()
	vertices.append_array(PackedVector3Array([Vector3(x0, 0.05, z0), Vector3(x1, 0.05, z0), Vector3(x1, 0.05, z1), Vector3(x0, 0.05, z1)]))
	polygons.append(PackedInt32Array([offset, offset + 1, offset + 2, offset + 3]))

func _deduplicate(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in points:
		if result.is_empty() or result.back().distance_squared_to(point) > 0.01:
			result.append(point)
	return result

func _register_zone_defaults() -> void:
	if zone_id == "greyfen":
		register_bridge("greyfen_bridge", Vector3(0, 0.55, river_center - 3.2), Vector3(0, 0.55, river_center + 3.2), DEFAULT_BRIDGE_HALF_WIDTH)
		reserve_corridor("spawn_to_wychwood", Vector3(0, 0, 0), Vector2(2.4, 16.0))
		register_gate("wychwood_gate", Vector3(0, 0, -15.0), Vector3(0, 0.9, -12.5), Vector2(3.2, 2.2))
		register_gate("castle_gate", Vector3(17.0, 0, 0.0), Vector3(15.5, 0.9, 0.0), Vector2(4.3, 2.35))
		register_gate("long_road_gate", Vector3(-18.0, 0, -10.0), Vector3(-16.0, 0.9, -9.0), Vector2(3.4, 3.0))
		reserve_corridor("spawn", Vector3(0, 0, 13.0), Vector2(3.2, 2.4))
		add_safe_spawn(Vector3(0, 0.9, 12.5))
	elif zone_id == "wychwood":
		register_bridge("wychwood_bridge", Vector3(0, 0.55, river_center - 3.2), Vector3(0, 0.55, river_center + 3.2), DEFAULT_BRIDGE_HALF_WIDTH)
		register_gate("greyfen_gate", Vector3(0, 0, 15.0), Vector3(0, 0.9, 12.5), Vector2(3.4, 2.3))
		reserve_corridor("main_road", Vector3(0, 0, 1.5), Vector2(2.6, 13.5))
		reserve_corridor("combat_clearing", Vector3(0, 0, -7.0), Vector2(5.2, 4.2))
		add_safe_spawn(Vector3(0, 0.9, -2.5))
	else:
		register_gate("campaign_return", Vector3(-7, 0, 13.5), Vector3(0, 0.9, 12.0), Vector2(3.2, 2.4))
		register_gate("campaign_forward", Vector3(7, 0, -13.5), Vector3(0, 0.9, -12.0), Vector2(3.2, 2.4))
		if zone_id == "vargan_approach":
			register_gate("castle_approach_return", Vector3(-7, 0, 16), Vector3(0, 0.9, -12), Vector2(3.6, 2.5))
			register_gate("castle_approach_forward", Vector3(0, 0, -12.2), Vector3(0, 0.9, 12), Vector2(3.8, 2.8))
		elif zone_id == "vargan_court":
			register_gate("castle_court_return", Vector3(-7, 0, 16), Vector3(0, 0.9, -11), Vector2(3.6, 2.5))
			register_gate("castle_court_forward", Vector3(0, 0, -14), Vector3(0, 0.9, 12), Vector2(4.0, 2.8))
		elif zone_id == "record_hall":
			register_gate("record_hall_return", Vector3(-6, 0, 13), Vector3(0, 0.9, -11), Vector2(3.6, 2.5))
			register_gate("record_hall_forward", Vector3(6, 0, -13), Vector3(0, 0.9, 12), Vector2(3.8, 2.6))
		reserve_corridor("campaign_route", Vector3(0, 0, 0), Vector2(4.0, 15.0))
		add_safe_spawn(Vector3(0, 0.9, 12.0))
		add_safe_spawn(Vector3(0, 0.9, -12.0))
