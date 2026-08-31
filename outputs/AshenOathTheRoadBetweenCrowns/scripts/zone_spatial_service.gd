extends Node3D

const RIVER_HALF_SPAN := 2.25
const DEFAULT_BRIDGE_HALF_WIDTH := 2.35

var zone_id := ""
var river_center := 999.0
var half_extents := Vector2(20.0, 16.0)
var reserved_corridors: Array[Dictionary] = []
var exclusions: Array[Dictionary] = []
var safe_spawns: Array[Vector3] = []
var recovery_anchors: Array[Vector3] = []
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
	recovery_anchors.clear()
	bridges.clear()
	gates.clear()
	_register_zone_defaults()

func register_bridge(id: String, bank_a: Vector3, bank_b: Vector3, half_width: float) -> void:
	var centre_z := (bank_a.z + bank_b.z) * 0.5
	var half_length := maxf(absf(bank_b.z - bank_a.z) * 0.5 - 0.15, RIVER_HALF_SPAN)
	bridges[id] = {
		"id": id,
		"bank_a": bank_a,
		"bank_b": bank_b,
		"center_z": centre_z,
		"half_length": half_length,
		"half_width": half_width,
	}

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

func add_recovery_anchor(position: Vector3) -> void:
	var anchor := _clamp_to_bounds(position, 0.9)
	if is_river_excluded(anchor, 0.9):
		anchor.z = river_center + float(bank_for(position)) * (RIVER_HALF_SPAN + 0.9)
	recovery_anchors.append(anchor)

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
	# Do not bake one rectangle over the whole zone: that silently gives agents a
	# straight-line path through the river. The generated mesh is deliberately
	# simple and deterministic, but has separate bank polygons plus an explicit
	# bridge lane. Player/AI route validation remains the final authority for
	# props and authored exclusions.
	_add_walkable_navigation_polygons(vertices, polygons)
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

func is_on_bridge(position: Vector3, clearance: float = 0.0) -> bool:
	if river_center >= 900.0:
		return false
	for bridge in bridges.values():
		# The bridge query uses the actor root footprint. A point below the
		# waterline is still invalid and must be recovered even if its X/Z is
		# aligned with a legal deck.
		if position.y < -0.25:
			continue
		var width_limit := float(bridge.half_width) - minf(clearance, 0.35)
		var length_limit := float(bridge.half_length) + clearance
		if absf(position.x) <= width_limit and absf(position.z - float(bridge.center_z)) <= length_limit:
			return true
	return false

func is_river_excluded(position: Vector3, margin: float = 0.0) -> bool:
	if river_center >= 900.0 or absf(position.z - river_center) >= RIVER_HALF_SPAN + margin:
		return false
	return not is_on_bridge(position, margin)

func is_walkable_position(position: Vector3, clearance: float = 0.8, preferred_bank: int = 0) -> bool:
	var validated := validate_position(position, clearance, preferred_bank)
	if validated.distance_squared_to(position) > maxf(clearance * clearance, 0.04):
		return false
	return not is_river_excluded(position, clearance) \
		and not _inside_entries(position, exclusions, clearance) \
		and not is_position_occupied(position, clearance * 0.52, 1.65)

func bank_for(position: Vector3) -> int:
	if river_center >= 900.0:
		return 0
	return -1 if position.z < river_center else 1

func validate_position(position: Vector3, clearance: float = 0.8, preferred_bank: int = 0) -> Vector3:
	var result := _clamp_to_bounds(position, clearance)
	var requested_bank := preferred_bank if preferred_bank != 0 else bank_for(position)
	if is_river_excluded(result, clearance):
		result.z = river_center + float(requested_bank) * (RIVER_HALF_SPAN + clearance)
	if _inside_entries(result, exclusions, clearance) or is_position_occupied(result, clearance * 0.52, 1.65):
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
		# Join the authored bridge lane before approaching its bank anchor. A
		# diagonal shortcut can satisfy river math while cutting through roadside
		# clues, deadfalls, or bridge furniture that are not exclusion volumes.
		var source_lane := Vector3(source_anchor.x, source.y, source.z)
		var target_lane := Vector3(target_anchor.x, target.y, target.z)
		if not validate_segment(source, source_lane, clearance) or not validate_segment(source_lane, source_anchor, clearance):
			return []
		if source.distance_squared_to(source_lane) > 0.16:
			result.append(source_lane)
		result.append(source_anchor)
		result.append(Vector3((source_anchor.x + target_anchor.x) * 0.5, maxf(source.y, target.y), river_center))
		result.append(target_anchor)
		if target_anchor.distance_squared_to(target_lane) > 0.16:
			result.append(target_lane)
		if not validate_segment(target_anchor, target_lane, clearance) or not validate_segment(target_lane, target, clearance):
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
	# Keep a valid requested point stable. This function is also used when a
	# zone is entered with an authored arrival, so falling through to a distant
	# recovery anchor for every valid point can place the actor on a route edge
	# and make the first movement look blocked by the ground slab itself.
	var requested := _clamp_to_bounds(position, 1.0)
	requested.y = 0.0
	# A low point in the channel is a failed bridge/bed entry even when its X
	# coordinate happens to be inside the legal bridge lane. Emergency recovery
	# must choose the requested bank, never preserve that invalid centre point.
	var low_channel_entry := river_center < 900.0 and absf(position.z - river_center) < RIVER_HALF_SPAN and position.y < 0.2
	if wanted_bank != 0 and (is_river_excluded(requested, 0.8) or low_channel_entry):
		requested.z = river_center + float(wanted_bank) * (RIVER_HALF_SPAN + 1.0)
	if not _inside_entries(requested, exclusions, 0.6) and not is_position_occupied(requested, 0.42, 1.65):
		return requested
	# Recovery must prefer authored road anchors. Searching around the failed
	# coordinate can select a roof, yard, or prop when the failure occurred
	# beside a building or scenery wall.
	var ordered_anchors := recovery_anchors.duplicate()
	ordered_anchors.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(position) < b.distance_squared_to(position)
	)
	for anchor in ordered_anchors:
		if wanted_bank != 0 and bank_for(anchor) != wanted_bank:
			continue
		if is_river_excluded(anchor, 0.8) or _inside_entries(anchor, exclusions, 0.6):
			continue
		if not is_position_occupied(anchor, 0.42, 1.65):
			return anchor
	var base := requested
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
	if wanted_bank != 0 and not recovery_anchors.is_empty():
		for anchor in recovery_anchors:
			if bank_for(anchor) == wanted_bank and not is_river_excluded(anchor, 0.8):
				return anchor
	return _nearest_spawn(position, wanted_bank)

func is_position_occupied(position: Vector3, radius: float, height: float) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# `position` is an actor/root ground point, while CapsuleShape3D's transform
	# is its center. Keep the probe a small, explicit distance above the floor;
	# placing its lower hemisphere on the ground slab makes the physics server
	# report every location as occupied and collapses all props to a fallback
	# recovery anchor during zone construction.
	var floor_clearance := 0.14
	# Godot's capsule height includes the cylindrical portion in some imported
	# physics paths, so account for the hemispheres explicitly when positioning
	# the query center. This keeps the actual lower extent above the floor too,
	# rather than only the nominal `height` value.
	query.transform = Transform3D(Basis.IDENTITY, Vector3(position.x, maxf(position.y, 0.0) + floor_clearance + shape.height * 0.5 + radius, position.z))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for actor in get_tree().get_nodes_in_group("player"):
		var player_body := actor as CollisionObject3D
		if player_body != null:
			query.exclude.append(player_body.get_rid())
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

func _add_walkable_navigation_polygons(vertices: PackedVector3Array, polygons: Array[PackedInt32Array]) -> void:
	var x0 := -half_extents.x
	var x1 := half_extents.x
	var z0 := -half_extents.y
	var z1 := half_extents.y
	if river_center >= 900.0:
		_add_rect(vertices, polygons, x0, z0, x1, z1)
		return
	var river_min := river_center - RIVER_HALF_SPAN
	var river_max := river_center + RIVER_HALF_SPAN
	_add_rect(vertices, polygons, x0, z0, x1, river_min)
	_add_rect(vertices, polygons, x0, river_max, x1, z1)
	# A bridge lane is the only connector between the bank polygons. The small
	# overlap at each bank edge prevents an agent from seeing a one-voxel gap.
	for bridge in bridges.values():
		var half_width := float(bridge.get("half_width", DEFAULT_BRIDGE_HALF_WIDTH))
		var half_length := float(bridge.get("half_length", RIVER_HALF_SPAN))
		_add_rect(vertices, polygons, -half_width, float(bridge.center_z) - half_length, half_width, float(bridge.center_z) + half_length)

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
		# The gate is approached from the central road, so reserve the complete
		# westward lane before any low berms, fences, trees, or props are dressed.
		reserve_corridor("long_road_approach", Vector3(-10.0, 0, -10.0), Vector2(8.5, 3.6))
		reserve_corridor("spawn", Vector3(0, 0, 13.0), Vector2(3.2, 2.4))
		add_safe_spawn(Vector3(0, 0.9, 12.5))
		# Keep recovery on authored road approaches rather than the dense river-side
		# dressing. These anchors are also valid camera staging points.
		add_recovery_anchor(Vector3(0, 0.0, -12.5))
		add_recovery_anchor(Vector3(0, 0.0, 12.5))
	elif zone_id == "wychwood":
		register_bridge("wychwood_bridge", Vector3(0, 0.55, river_center - 3.2), Vector3(0, 0.55, river_center + 3.2), DEFAULT_BRIDGE_HALF_WIDTH)
		register_gate("greyfen_gate", Vector3(0, 0, 15.0), Vector3(0, 0.9, 12.5), Vector2(3.4, 2.3))
		reserve_corridor("main_road", Vector3(0, 0, 1.5), Vector2(2.6, 13.5))
		reserve_corridor("combat_clearing", Vector3(0, 0, -7.0), Vector2(5.2, 4.2))
		add_safe_spawn(Vector3(0, 0.9, -2.5))
		add_recovery_anchor(Vector3(0, 0.0, -12.5))
		add_recovery_anchor(Vector3(0, 0.0, 12.5))
	else:
		register_gate("campaign_return", Vector3(-7, 0, 13.5), Vector3(0, 0.9, 12.0), Vector2(3.2, 2.4))
		register_gate("campaign_forward", Vector3(7, 0, -13.5), Vector3(0, 0.9, -12.0), Vector2(3.2, 2.4))
		if zone_id == "vargan_approach":
			# The west edge arrives from the bandit road at (-16, 0). Keep the
			# authored route to the central gate clear before Castle walls and
			# roadside dressing are generated.
			reserve_corridor("castle_west_arrival", Vector3(-11.0, 0.0, 0.0), Vector2(6.5, 5.0))
		if zone_id == "vargan_approach":
			register_gate("castle_approach_return", Vector3(-7, 0, 16), Vector3(0, 0.9, -12), Vector2(3.6, 2.5))
			register_gate("castle_approach_forward", Vector3(0, 0, -12.2), Vector3(0, 0.9, 12), Vector2(3.8, 2.8))
		elif zone_id == "vargan_court":
			register_gate("castle_court_return", Vector3(-10.5, 0, 16), Vector3(0, 0.9, -11), Vector2(3.6, 2.5))
			register_gate("castle_court_forward", Vector3(0, 0, -14), Vector3(0, 0.9, 12), Vector2(4.0, 2.8))
		elif zone_id == "record_hall":
			register_gate("record_hall_return", Vector3(-6, 0, 13), Vector3(0, 0.9, -11), Vector2(3.6, 2.5))
			register_gate("record_hall_forward", Vector3(6, 0, -13), Vector3(0, 0.9, 12), Vector2(3.8, 2.6))
		if zone_id == "bandit_road":
			# The manifest's east boundary is the physical road into Vargan. The
			# arrival from the marsh starts near (0, 13), so reserve a stepped
			# diagonal corridor to (22, -12) before ditches, trees, camp props, or
			# rubble are authored. A direct endpoint-only clearance check cannot
			# protect this route from axis-aligned scenery colliders.
			for approach in [
				Vector3(4.0, 0.0, 8.4), Vector3(8.0, 0.0, 3.8),
				Vector3(12.0, 0.0, -0.8), Vector3(16.0, 0.0, -5.4),
				Vector3(20.0, 0.0, -10.0)
			]:
				reserve_corridor("vargan_boundary_approach", approach, Vector2(2.4, 2.4))
		reserve_corridor("campaign_route", Vector3(0, 0, 0), Vector2(4.0, 15.0))
		add_safe_spawn(Vector3(0, 0.9, 12.0))
		add_safe_spawn(Vector3(0, 0.9, -12.0))
