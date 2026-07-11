extends Node

var zone_id := ""
var river_center := 999.0
var half_extents := Vector2(20.0, 16.0)
var reserved_corridors: Array[Dictionary] = []
var safe_spawns: Array[Vector3] = []

func configure(id: String, river_z: float, extents: Vector2) -> void:
	zone_id = id
	river_center = river_z
	half_extents = extents
	reserved_corridors.clear()
	safe_spawns.clear()
	_register_zone_defaults()

func reserve_corridor(id: String, center: Vector3, half_size: Vector2) -> void:
	reserved_corridors.append({"id": id, "center": center, "half_size": half_size})

func add_safe_spawn(position: Vector3) -> void:
	safe_spawns.append(validate_position(position, 0.8))

func is_reserved(position: Vector3, margin: float = 0.0) -> bool:
	for corridor in reserved_corridors:
		var center: Vector3 = corridor.center
		var half_size: Vector2 = corridor.half_size
		if absf(position.x - center.x) <= half_size.x + margin and absf(position.z - center.z) <= half_size.y + margin:
			return true
	return false

func is_river_excluded(position: Vector3, margin: float = 0.0) -> bool:
	return river_center < 900.0 and absf(position.z - river_center) < 2.25 + margin and absf(position.x) > 2.45

func validate_position(position: Vector3, clearance: float = 0.8) -> Vector3:
	var result := position
	result.x = clampf(result.x, -half_extents.x + clearance, half_extents.x - clearance)
	result.z = clampf(result.z, -half_extents.y + clearance, half_extents.y - clearance)
	if is_river_excluded(result, clearance):
		var side := -1.0 if result.z <= river_center else 1.0
		result.z = river_center + side * (2.25 + clearance)
	result.y = maxf(result.y, 0.0)
	return result

func validate_path(points: Array, clearance: float = 0.9) -> Array:
	var result: Array = []
	for raw_point in points:
		var point := validate_position(raw_point, clearance)
		if not result.is_empty() and _crosses_river(result.back(), point):
			var side := -1.0 if result.back().z < river_center else 1.0
			result.append(Vector3(0.0, 0.55, river_center + side * (2.25 + clearance)))
			result.append(Vector3(0.0, 0.55, river_center))
			result.append(Vector3(0.0, 0.55, river_center - side * (2.25 + clearance)))
		result.append(point)
	return result

func nearest_safe(position: Vector3, same_bank: bool = true) -> Vector3:
	var candidate := validate_position(position, 1.0)
	if same_bank and river_center < 900.0:
		var side := -1.0 if position.z <= river_center else 1.0
		candidate.z = river_center + side * maxf(absf(candidate.z - river_center), 3.25)
	if is_reserved(candidate, 0.6) and not safe_spawns.is_empty():
		return _nearest_spawn(position)
	return candidate

func _nearest_spawn(position: Vector3) -> Vector3:
	var best := safe_spawns[0]
	var best_distance := position.distance_squared_to(best)
	for spawn in safe_spawns:
		var distance := position.distance_squared_to(spawn)
		if distance < best_distance:
			best = spawn
			best_distance = distance
	return best

func _crosses_river(a: Vector3, b: Vector3) -> bool:
	return river_center < 900.0 and (a.z - river_center) * (b.z - river_center) < 0.0 and (absf(a.x) > 2.45 or absf(b.x) > 2.45)

func _register_zone_defaults() -> void:
	if zone_id == "greyfen":
		reserve_corridor("spawn_to_wychwood", Vector3(0, 0, 0), Vector2(2.4, 16.0))
		reserve_corridor("wychwood_gate", Vector3(0, 0, -15.0), Vector2(3.2, 2.2))
		reserve_corridor("spawn", Vector3(0, 0, 13.0), Vector2(3.2, 2.4))
		add_safe_spawn(Vector3(0, 0.9, 12.5))
		add_safe_spawn(Vector3(0, 0.9, -12.5))
	elif zone_id == "wychwood":
		reserve_corridor("greyfen_gate", Vector3(0, 0, 15.0), Vector2(3.4, 2.3))
		reserve_corridor("main_road", Vector3(0, 0, 1.5), Vector2(2.6, 13.5))
		reserve_corridor("combat_clearing", Vector3(0, 0, -7.0), Vector2(5.2, 4.2))
		add_safe_spawn(Vector3(0, 0.9, 12.5))
		add_safe_spawn(Vector3(0, 0.9, -2.5))
