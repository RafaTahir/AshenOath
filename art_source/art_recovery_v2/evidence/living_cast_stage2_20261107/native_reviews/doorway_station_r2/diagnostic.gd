extends SceneTree

const DOOR := "res://assets_external/environment/village/Door_1_Flat.obj"
const HOUSE := "res://assets_external/environment/village/GreyfenHouse_Authored"
const RAW_POINT := Vector3(0.514247, 1.313862, 0.031246)
const OFFSET := Vector3(-0.42, 0.35, -1.91)
const DOOR_SCALE := Vector3(0.83, 0.85, 0.90)

func _initialize() -> void:
	var door := load(DOOR) as ArrayMesh
	if door == null:
		push_error("No retained door resource")
		quit(1)
		return
	var point := RAW_POINT * DOOR_SCALE + OFFSET
	var transformed: Dictionary = {}
	var door_report: Dictionary = {}
	for index in door.get_surface_count():
		var vertices: PackedVector3Array = door.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
		var name := door.surface_get_name(index)
		door_report[name] = _nearest(vertices, RAW_POINT)
		if "wood" in name.to_lower():
			for vertex: Vector3 in vertices:
				var location := vertex * DOOR_SCALE + OFFSET
				transformed[_cell(location)] = location
	var houses: Array[Dictionary] = []
	for variant in 4:
		var path := HOUSE + ("" if variant == 0 else "_%d" % variant) + ".res"
		var mesh := load(path) as ArrayMesh
		if mesh == null:
			push_error("No authored house resource: " + path)
			quit(1)
			return
		var surfaces: Dictionary = {}
		for index in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
			var row := _nearest(vertices, point)
			if mesh.surface_get_name(index) == "timber":
				var common := 0
				var nearest_point := Vector3.INF
				var nearest := INF
				for vertex: Vector3 in vertices:
					var cell := _cell(vertex)
					if not transformed.has(cell) or vertex.distance_squared_to(transformed[cell]) > 0.000001:
						continue
					common += 1
					var distance := vertex.distance_squared_to(point)
					if distance < nearest:
						nearest = distance
						nearest_point = vertex
				row["matched_door_vertex_count"] = common
				row["nearest_matched_door_point"] = str(nearest_point)
				row["nearest_matched_door_distance_m"] = sqrt(nearest) if is_finite(nearest) else null
			surfaces[mesh.surface_get_name(index)] = row
		houses.append({"variant":variant, "path":path, "surfaces":surfaces})
	print("DOORWAY_SOURCE " + JSON.stringify({"raw_point":str(RAW_POINT), "expected":str(point), "retained_obj":door_report, "houses":houses}))
	quit(0)

func _cell(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))

func _nearest(vertices: PackedVector3Array, point: Vector3) -> Dictionary:
	var distance := INF
	var nearest := Vector3.INF
	for vertex: Vector3 in vertices:
		var candidate := vertex.distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			nearest = vertex
	return {"vertices":vertices.size(), "nearest":str(nearest), "distance_m":sqrt(distance) if is_finite(distance) else null}
