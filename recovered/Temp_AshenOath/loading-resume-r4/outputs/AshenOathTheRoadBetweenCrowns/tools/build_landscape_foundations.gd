extends SceneTree

const OUTPUT := "res://assets/landscape"
const ROCK_SOURCE := "res://assets_external/environment/forest/Rock_Medium_1.obj"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [1.0, 1.14, 1.42, 1.90, 2.70]
	for ring in range(radii.size() - 1):
		for segment in range(64):
			var angle0 := TAU * float(segment) / 64.0
			var angle1 := TAU * float(segment + 1) / 64.0
			var a := _terrain_point(angle0, radii[ring], ring)
			var b := _terrain_point(angle1, radii[ring], ring)
			var c := _terrain_point(angle0, radii[ring + 1], ring + 1)
			var d := _terrain_point(angle1, radii[ring + 1], ring + 1)
			for point in [a, c, b, b, c, d]:
				terrain.set_uv(Vector2(point.x, point.z))
				terrain.set_color(Color(0.31, 0.48, 0.30).lerp(Color(0.37, 0.42, 0.32), clampf(point.y / 12.0, 0.0, 1.0)))
				terrain.add_vertex(point)
	terrain.generate_normals()
	terrain.index()
	_save(terrain.commit(), "far_terrain.res")
	var rock := load(ROCK_SOURCE) as ArrayMesh
	if rock == null:
		push_error("Approved forest rock source is unavailable")
		quit(1)
		return
	var bounds := rock.get_aabb()
	var pier := SurfaceTool.new()
	pier.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(4):
		for column in range(2):
			var cross_course := layer % 2 == 1
			var offset := Vector3(0, float(layer) * 0.43, 0)
			if cross_course:
				offset.z = (float(column) - 0.5) * 0.46
			else:
				offset.x = (float(column) - 0.5) * 0.52
			for point in rock.get_faces():
				var normalized := (point - bounds.position) / bounds.size
				var fitted := Vector3((normalized.x - 0.5) * 0.51, normalized.y * 0.426, (normalized.z - 0.5) * 0.91)
				if cross_course:
					fitted = Vector3(fitted.z * 1.13, fitted.y, -fitted.x * 0.88)
				fitted += offset
				pier.set_uv(Vector2(fitted.x + fitted.z, -fitted.y))
				pier.set_color(Color(0.62, 0.67, 0.61).darkened(float((layer + column) % 3) * 0.045))
				pier.add_vertex(fitted)
	pier.generate_normals()
	pier.index()
	_save(pier.commit(), "bridge_stone_pier.res")
	quit()

func _terrain_point(angle: float, radius: float, ring: int) -> Vector3:
	var direction := Vector2(cos(angle), sin(angle))
	direction /= maxf(absf(direction.x), absf(direction.y))
	var height := 0.0
	if ring > 0:
		var ridge := 0.70 + 0.18 * sin(angle * 3.0 + 0.7) + 0.12 * cos(angle * 5.0 - 0.4)
		var valley := 1.0 - 0.30 * pow(absf(cos(angle * 2.0)), 8.0)
		height = [0.0, 0.25, 4.0, 8.0, 6.0][ring] * ridge * valley
	return Vector3(direction.x * radius, height, direction.y * radius)

func _save(mesh: ArrayMesh, filename: String) -> void:
	var path := OUTPUT.path_join(filename)
	if ResourceSaver.save(mesh, path) != OK:
		push_error("Cannot save " + path)
		quit(1)
		return
	print("LANDSCAPE BAKE %s vertices=%d triangles=%d bytes=%d sha256=%s bounds=%s" % [filename, mesh.surface_get_array_len(0), mesh.surface_get_array_index_len(0) / 3, FileAccess.open(path, FileAccess.READ).get_length(), FileAccess.get_sha256(path), mesh.get_aabb()])
