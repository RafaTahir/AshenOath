extends SceneTree

const OUTPUT := "res://assets_external/environment/village/GreyfenHouse_Authored.res"
const SURFACES := ["medieval_brick", "plaster", "timber", "roof_tiles", "glazing", "metal"]
const BASE_COLORS := {
	"medieval_brick": Color(0.52, 0.50, 0.45),
	"plaster": Color(0.65, 0.58, 0.46),
	"timber": Color(0.35, 0.23, 0.14),
	"roof_tiles": Color(0.42, 0.20, 0.15),
	"glazing": Color(0.16, 0.22, 0.24),
	"metal": Color(0.34, 0.34, 0.32),
}

var geometry: Dictionary = {}
var variant := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = int(argument.trim_prefix("--variant="))
	if variant < 0 or variant > 6:
		push_error("Unknown Greyfen house variant: %d" % variant)
		quit(1)
		return
	for surface in SURFACES:
		geometry[surface] = {"vertices": [], "normals": [], "uvs": [], "indices": []}
	if variant == 6:
		_build_village_well()
	elif variant == 5:
		_build_shrine_oathstone()
	elif variant == 4:
		_build_forge_workshop()
	else:
		_build_foundation()
		if not _build_kit_house():
			quit(1)
			return
		_build_chimney()
		_build_variant_details()
	var mesh := ArrayMesh.new()
	for surface in SURFACES:
		var part: Dictionary = geometry[surface]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(part.vertices)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(part.normals)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(part.uvs)
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(part.indices)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, surface)
		var base_material := StandardMaterial3D.new()
		base_material.resource_name = "AuthoredHouseBase_" + surface
		base_material.albedo_color = BASE_COLORS[surface]
		base_material.roughness = 0.88
		mesh.surface_set_material(mesh.get_surface_count() - 1, base_material)
	var output_path := OUTPUT if variant == 0 else OUTPUT.trim_suffix(".res") + "_%d.res" % variant
	if variant == 4:
		output_path = "res://assets_external/environment/village/GreyfenForge_Authored.res"
	elif variant == 5:
		output_path = "res://assets_external/environment/village/GreyfenShrine_Authored.res"
	elif variant == 6:
		output_path = "res://assets_external/environment/village/GreyfenWell_Authored.res"
	var result := ResourceSaver.save(mesh, output_path)
	if result != OK:
		push_error("Greyfen house bake failed: %s" % error_string(result))
		quit(1)
		return
	print("GREYFEN HOUSE BAKE: PASS variant=%d surfaces=%d vertices=%d output=%s" % [variant, mesh.get_surface_count(), mesh.get_faces().size(), output_path])
	quit(0)

func _quad(surface: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var part: Dictionary = geometry[surface]
	var base: int = part.vertices.size()
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c, d]:
		part.vertices.append(point)
		part.normals.append(normal)
		var uv := Vector2(point.x, point.y) if absf(normal.z) > 0.5 else Vector2(point.z, point.y)
		if absf(normal.y) > 0.5:
			uv = Vector2(point.x, point.z)
		part.uvs.append(uv * 0.44)
	part.indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func _triangle(surface: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var part: Dictionary = geometry[surface]
	var base: int = part.vertices.size()
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		part.vertices.append(point)
		part.normals.append(normal)
		part.uvs.append(Vector2(point.x, point.y) * 0.44)
	part.indices.append_array([base, base + 1, base + 2])

func _box(surface: String, low: Vector3, high: Vector3) -> void:
	_quad(surface, Vector3(low.x, low.y, low.z), Vector3(low.x, high.y, low.z), Vector3(high.x, high.y, low.z), Vector3(high.x, low.y, low.z))
	_quad(surface, Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z), Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z))
	_quad(surface, Vector3(high.x, low.y, low.z), Vector3(high.x, high.y, low.z), Vector3(high.x, high.y, high.z), Vector3(high.x, low.y, high.z))
	_quad(surface, Vector3(low.x, low.y, low.z), Vector3(low.x, low.y, high.z), Vector3(low.x, high.y, high.z), Vector3(low.x, high.y, low.z))
	_quad(surface, Vector3(low.x, high.y, low.z), Vector3(low.x, high.y, high.z), Vector3(high.x, high.y, high.z), Vector3(high.x, high.y, low.z))
	_quad(surface, Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, low.y, high.z), Vector3(low.x, low.y, high.z))

func _beam(surface: String, start: Vector3, end: Vector3, width: float, depth: float) -> void:
	var direction := (end - start).normalized()
	var across := direction.cross(Vector3.FORWARD).normalized() * width * 0.5
	var outward := across.cross(direction).normalized() * depth * 0.5
	var a := start - across - outward
	var b := start + across - outward
	var c := start + across + outward
	var d := start - across + outward
	var e := end - across - outward
	var f := end + across - outward
	var g := end + across + outward
	var h := end - across + outward
	_quad(surface, a, b, f, e)
	_quad(surface, b, c, g, f)
	_quad(surface, c, d, h, g)
	_quad(surface, d, a, e, h)
	_quad(surface, a, d, c, b)
	_quad(surface, e, f, g, h)

func _wall(surface: String, start: float, end: float, fixed: float, side: bool, openings: Array[Rect2]) -> void:
	var horizontal: Array[float] = [start, end]
	var vertical: Array[float] = [0.36, 2.20]
	for opening in openings:
		horizontal.append(opening.position.x)
		horizontal.append(opening.end.x)
		vertical.append(opening.position.y)
		vertical.append(opening.end.y)
	horizontal.sort()
	vertical.sort()
	for h in range(horizontal.size() - 1):
		for v in range(vertical.size() - 1):
			var lo: float = horizontal[h]
			var hi: float = horizontal[h + 1]
			var bottom: float = vertical[v]
			var top: float = vertical[v + 1]
			if hi - lo < 0.001 or top - bottom < 0.001:
				continue
			var center := Vector2((lo + hi) * 0.5, (bottom + top) * 0.5)
			var opening_cell := false
			for opening in openings:
				if opening.has_point(center):
					opening_cell = true
					break
			if opening_cell:
				continue
			if side:
				_box(surface, Vector3(fixed - 0.09, bottom, lo), Vector3(fixed + 0.09, top, hi))
			else:
				_box(surface, Vector3(lo, bottom, fixed - 0.09), Vector3(hi, top, fixed + 0.09))

func _build_foundation() -> void:
	_box("medieval_brick", Vector3(-2.26, 0.02, -1.81), Vector3(2.26, 0.38, 1.81))
	_box("medieval_brick", Vector3(-0.62, 0.04, -2.16), Vector3(0.62, 0.19, -1.73))

func _build_kit_house() -> bool:
	var village := "res://assets_external/environment/village/"
	var front := ["Wall_Plaster_Window_Wide_Flat.obj", "Wall_Plaster_Door_Flat.obj", "Wall_Plaster_Window_Wide_Flat.obj"]
	var rear := ["Wall_Plaster_Window_Wide_Flat.obj", "Wall_Plaster_Straight_Base.obj", "Wall_Plaster_Window_Wide_Flat.obj"]
	for index in range(3):
		var x := float(index - 1) * 1.42
		if not _append_kit_part(village + front[index], Transform3D(Basis.from_euler(Vector3.ZERO).scaled(Vector3(0.71, 0.60, 0.55)), Vector3(x, 0.33, -1.70))):
			return false
		if not _append_kit_part(village + rear[index], Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3(0.71, 0.60, 0.55)), Vector3(-x, 0.33, 1.70))):
			return false
	for side in [-1.0, 1.0]:
		for index in range(2):
			var z := (float(index) - 0.5) * 1.70
			var side_yaw := -PI * 0.5 if side < 0.0 else PI * 0.5
			if not _append_kit_part(village + "Wall_Plaster_Straight_Base.obj", Transform3D(Basis.from_euler(Vector3(0.0, side_yaw, 0.0)).scaled(Vector3(0.85, 0.60, 0.55)), Vector3(side * 2.13, 0.33, z))):
				return false
	var roof_transform := Transform3D(Basis.from_euler(Vector3.ZERO).scaled(Vector3(0.89, 0.32, 0.72)), Vector3(0.0, 2.25, 0.0))
	if not _append_kit_part(village + "Roof_RoundTiles_4x4.obj", roof_transform):
		return false
	if not _append_kit_part(village + "Door_1_Flat.obj", Transform3D(Basis.from_euler(Vector3.ZERO).scaled(Vector3(0.83, 0.85, 0.90)), Vector3(-0.42, 0.35, -1.91))):
		return false
	_triangle("plaster", Vector3(-2.13, 2.18, -1.73), Vector3(0.0, 3.25, -1.73), Vector3(2.13, 2.18, -1.73))
	_triangle("plaster", Vector3(2.13, 2.18, 1.73), Vector3(0.0, 3.25, 1.73), Vector3(-2.13, 2.18, 1.73))
	for z in [-1.77, 1.77]:
		_beam("timber", Vector3(-2.13, 2.18, z), Vector3(0.0, 3.25, z), 0.10, 0.10)
		_beam("timber", Vector3(0.0, 3.25, z), Vector3(2.13, 2.18, z), 0.10, 0.10)
		_beam("timber", Vector3(0.0, 2.19, z), Vector3(0.0, 3.23, z), 0.08, 0.08)
	for x in [-1.42, 1.42]:
		if not _append_kit_part(village + "Window_Wide_Flat1.obj", Transform3D(Basis.from_euler(Vector3.ZERO).scaled(Vector3(0.71, 0.60, 0.55)), Vector3(x, 0.33, -1.89))):
			return false
		if not _append_kit_part(village + "Window_Wide_Flat1.obj", Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3(0.71, 0.60, 0.55)), Vector3(-x, 0.33, 1.89))):
			return false
	return true

func _append_kit_part(path: String, transform: Transform3D) -> bool:
	var source := load(path) as ArrayMesh
	if source == null:
		push_error("Required Greyfen village kit part is missing: " + path)
		return false
	var normal_basis := transform.basis.inverse().transposed()
	for surface_index in source.get_surface_count():
		var group := source.surface_get_name(surface_index).to_lower()
		var material_group := ""
		if group.contains("plaster"):
			material_group = "plaster"
		elif group.contains("roundtiles"):
			material_group = "roof_tiles"
		elif group.contains("wood"):
			material_group = "timber"
		elif group.contains("brick") or group.contains("rock"):
			material_group = "medieval_brick"
		elif group.contains("glass"):
			material_group = "glazing"
		elif group.contains("metal"):
			material_group = "metal"
		if material_group == "":
			push_error("Unknown Greyfen kit material group: %s in %s" % [group, path])
			return false
		var source_arrays := source.surface_get_arrays(surface_index)
		var positions: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
		var part: Dictionary = geometry[material_group]
		var base: int = part.vertices.size()
		for vertex_index in positions.size():
			part.vertices.append(transform * positions[vertex_index])
			part.normals.append((normal_basis * normals[vertex_index]).normalized() if vertex_index < normals.size() else Vector3.UP)
			part.uvs.append(uvs[vertex_index] if vertex_index < uvs.size() else Vector2.ZERO)
		if indices.is_empty():
			for vertex_index in positions.size():
				part.indices.append(base + vertex_index)
		else:
			for vertex_index in indices:
				part.indices.append(base + vertex_index)
	return true

func _build_walls() -> void:
	var front: Array[Rect2] = [Rect2(-0.48, 0.36, 0.96, 1.40)]
	for x in [-1.45, 1.45]:
		front.append(Rect2(x - 0.40, 0.96, 0.80, 0.68))
	_wall("plaster", -2.15, 2.15, -1.70, false, front)
	var rear: Array[Rect2] = []
	for x in [-1.45, 1.45]:
		rear.append(Rect2(x - 0.40, 0.96, 0.80, 0.68))
	_wall("plaster", -2.15, 2.15, 1.70, false, rear)
	for x in [-2.15, 2.15]:
		_wall("plaster", -1.70, 1.70, x, true, [Rect2(-0.40, 1.00, 0.80, 0.66)])
	for z in [-1.70, 1.70]:
		var front_gable: bool = z < 0.0
		var a := Vector3(-2.15, 2.20, z)
		var b := Vector3(2.15, 2.20, z)
		var peak := Vector3(0.0, 3.24, z)
		if front_gable:
			_triangle("plaster", a, peak, b)
		else:
			_triangle("plaster", b, peak, a)

func _build_roof() -> void:
	_quad("roof_tiles", Vector3(-2.46, 2.18, -2.02), Vector3(-2.46, 2.18, 2.02), Vector3(0.0, 3.29, 2.02), Vector3(0.0, 3.29, -2.02))
	_quad("roof_tiles", Vector3(0.0, 3.29, -2.02), Vector3(0.0, 3.29, 2.02), Vector3(2.46, 2.18, 2.02), Vector3(2.46, 2.18, -2.02))
	_box("roof_tiles", Vector3(-0.11, 3.23, -2.10), Vector3(0.11, 3.36, 2.10))
	for side in [-1.0, 1.0]:
		for course in range(1, 7):
			var outer_x := 2.46 * float(course) / 7.0
			var inner_x := outer_x - 0.09
			var outer_y := 3.29 - outer_x * 1.11 / 2.46 + 0.025
			var inner_y := 3.29 - inner_x * 1.11 / 2.46 + 0.025
			var near_z := -2.025
			var far_z := 2.025
			if side < 0.0:
				_quad("roof_tiles", Vector3(-outer_x, outer_y, near_z), Vector3(-outer_x, outer_y, far_z), Vector3(-inner_x, inner_y, far_z), Vector3(-inner_x, inner_y, near_z))
			else:
				_quad("roof_tiles", Vector3(inner_x, inner_y, near_z), Vector3(inner_x, inner_y, far_z), Vector3(outer_x, outer_y, far_z), Vector3(outer_x, outer_y, near_z))

func _build_framing() -> void:
	for z in [-1.82, 1.82]:
		for x in [-2.12, 2.12]:
			_box("timber", Vector3(x - 0.09, 0.38, z - 0.09), Vector3(x + 0.09, 2.22, z + 0.09))
		_box("timber", Vector3(-2.20, 2.08, z - 0.10), Vector3(2.20, 2.23, z + 0.10))
		_beam("timber", Vector3(-2.18, 2.20, z), Vector3(0.0, 3.27, z), 0.12, 0.13)
		_beam("timber", Vector3(0.0, 3.27, z), Vector3(2.18, 2.20, z), 0.12, 0.13)
		_beam("timber", Vector3(0.0, 2.20, z), Vector3(0.0, 3.27, z), 0.12, 0.13)
		for side in [-1.0, 1.0]:
			_beam("timber", Vector3(side * 1.72, 2.23, z), Vector3(side * 0.90, 2.83, z), 0.09, 0.10)
	for x in [-2.25, 2.25]:
		_box("timber", Vector3(x - 0.08, 2.08, -1.86), Vector3(x + 0.08, 2.24, 1.86))
	for x in [-0.93, 0.93]:
		_box("timber", Vector3(x - 0.065, 0.38, -1.87), Vector3(x + 0.065, 2.15, -1.76))
	for span in [Vector2(-2.12, -0.57), Vector2(0.57, 2.12)]:
		_box("timber", Vector3(span.x, 0.82, -1.88), Vector3(span.y, 0.91, -1.76))
	for z in [-2.03, 2.03]:
		_box("timber", Vector3(-2.47, 2.12, z - 0.08), Vector3(2.47, 2.24, z + 0.08))

func _build_windows_and_door() -> void:
	_box("timber", Vector3(-0.44, 0.38, -1.85), Vector3(0.44, 1.73, -1.76))
	for plank in [-0.27, -0.09, 0.09, 0.27]:
		_box("timber", Vector3(plank - 0.016, 0.42, -1.89), Vector3(plank + 0.016, 1.69, -1.84))
	for x in [-0.52, 0.52]:
		_box("timber", Vector3(x - 0.07, 0.37, -1.92), Vector3(x + 0.07, 1.82, -1.76))
	_box("timber", Vector3(-0.59, 1.75, -1.92), Vector3(0.59, 1.88, -1.76))
	_box("metal", Vector3(0.27, 1.01, -1.95), Vector3(0.35, 1.12, -1.87))
	for height in [0.55, 1.52]:
		_box("timber", Vector3(-0.41, height, -1.94), Vector3(0.41, height + 0.045, -1.89))
	for z in [-1.70, 1.70]:
		var face_z: float = z - 0.12 if z < 0.0 else z + 0.12
		for x in [-1.45, 1.45]:
			_box("glazing", Vector3(x - 0.34, 1.02, face_z - 0.02), Vector3(x + 0.34, 1.59, face_z + 0.02))
			for side in [-1.0, 1.0]:
				var shutter_x: float = float(x) + float(side) * 0.58
				_box("timber", Vector3(shutter_x - 0.16, 0.99, face_z - 0.055), Vector3(shutter_x + 0.16, 1.68, face_z + 0.055))
				for height in [1.12, 1.52]:
					_box("timber", Vector3(shutter_x - 0.14, height, face_z - 0.071), Vector3(shutter_x + 0.14, height + 0.025, face_z + 0.071))
			_box("timber", Vector3(x - 0.45, 0.91, face_z - 0.05), Vector3(x + 0.45, 1.01, face_z + 0.06))
			for edge in [x - 0.39, x + 0.39]:
				_box("timber", Vector3(edge - 0.035, 0.94, face_z - 0.05), Vector3(edge + 0.035, 1.70, face_z + 0.06))
			_box("timber", Vector3(x - 0.43, 1.63, face_z - 0.05), Vector3(x + 0.43, 1.72, face_z + 0.06))
			_box("timber", Vector3(x - 0.035, 0.98, face_z - 0.07), Vector3(x + 0.035, 1.67, face_z + 0.07))
	for x in [-2.15, 2.15]:
		var face_x: float = x - 0.12 if x < 0.0 else x + 0.12
		_box("glazing", Vector3(face_x - 0.02, 1.04, -0.33), Vector3(face_x + 0.02, 1.60, 0.33))
		for edge in [-0.41, 0.41]:
			_box("timber", Vector3(face_x - 0.06, 0.98, edge - 0.035), Vector3(face_x + 0.06, 1.70, edge + 0.035))
		_box("timber", Vector3(face_x - 0.06, 1.62, -0.44), Vector3(face_x + 0.06, 1.72, 0.44))
		_box("timber", Vector3(face_x - 0.06, 0.94, -0.44), Vector3(face_x + 0.06, 1.04, 0.44))
		_box("timber", Vector3(face_x - 0.07, 1.0, -0.035), Vector3(face_x + 0.07, 1.67, 0.035))

func _build_chimney() -> void:
	var chimney_x := 1.35 if variant in [1, 3] else -1.35
	_box("medieval_brick", Vector3(chimney_x - 0.27, 2.10, 0.35), Vector3(chimney_x + 0.23, 3.56, 0.86))
	_box("medieval_brick", Vector3(chimney_x - 0.35, 3.48, 0.28), Vector3(chimney_x + 0.31, 3.64, 0.93))
	_box("metal", Vector3(chimney_x - 0.18, 3.64, 0.44), Vector3(chimney_x + 0.14, 3.67, 0.77))

func _build_variant_details() -> void:
	if variant == 1:
		# A weathered porch gives the western home a sheltered work entry.
		_quad("roof_tiles", Vector3(-1.04, 1.96, -1.90), Vector3(1.04, 1.96, -1.90), Vector3(1.04, 1.72, -2.40), Vector3(-1.04, 1.72, -2.40))
		for x in [-0.98, 0.98]:
			_box("timber", Vector3(x - 0.06, 0.15, -2.42), Vector3(x + 0.06, 1.75, -2.30))
		_box("timber", Vector3(-1.10, 1.68, -2.45), Vector3(1.10, 1.78, -2.33))
	elif variant == 2:
		# The trader's shallow eave changes the frontage without enlarging its footprint.
		_quad("roof_tiles", Vector3(-1.95, 1.91, -1.89), Vector3(1.95, 1.91, -1.89), Vector3(1.95, 1.74, -2.19), Vector3(-1.95, 1.74, -2.19))
		_box("timber", Vector3(-2.04, 1.70, -2.22), Vector3(2.04, 1.79, -2.11))
	elif variant == 3:
		# The shrine-quarter attic light sits within the front gable.
		_box("glazing", Vector3(-0.27, 2.47, -1.84), Vector3(0.27, 2.79, -1.79))
		for x in [-0.31, 0.31]:
			_box("timber", Vector3(x - 0.04, 2.43, -1.88), Vector3(x + 0.04, 2.85, -1.78))
		_box("timber", Vector3(-0.35, 2.80, -1.88), Vector3(0.35, 2.88, -1.78))
		_box("timber", Vector3(-0.35, 2.39, -1.88), Vector3(0.35, 2.47, -1.78))

func _build_forge_workshop() -> void:
	# The street-facing side is a real open work bay, not a painted doorway on a box.
	_box("medieval_brick", Vector3(-1.72, 0.02, -0.08), Vector3(1.72, 0.30, 2.44))
	_box("plaster", Vector3(-1.69, 0.30, 2.24), Vector3(1.69, 2.24, 2.43))
	for x in [-1.69, 1.69]:
		_box("plaster", Vector3(x - 0.10, 0.30, 0.04), Vector3(x + 0.10, 2.24, 2.32))
		_box("timber", Vector3(x - 0.15, 0.28, -0.10), Vector3(x + 0.15, 2.27, 0.16))
	_box("timber", Vector3(-1.86, 2.12, -0.12), Vector3(1.86, 2.32, 0.16))
	_box("timber", Vector3(-1.84, 2.13, 2.30), Vector3(1.84, 2.31, 2.50))
	for z in [0.03, 2.34]:
		_beam("timber", Vector3(-1.73, 2.25, z), Vector3(0.0, 2.99, z), 0.13, 0.16)
		_beam("timber", Vector3(0.0, 2.99, z), Vector3(1.73, 2.25, z), 0.13, 0.16)
	_triangle("plaster", Vector3(-1.70, 2.24, -0.02), Vector3(0.0, 2.99, -0.02), Vector3(1.70, 2.24, -0.02))
	_triangle("plaster", Vector3(1.70, 2.24, 2.43), Vector3(0.0, 2.99, 2.43), Vector3(-1.70, 2.24, 2.43))
	for x in [-1.64, 1.64]:
		_box("timber", Vector3(x - 0.09, 0.30, 2.38), Vector3(x + 0.09, 2.28, 2.51))
	_box("timber", Vector3(-1.72, 2.18, 2.39), Vector3(1.72, 2.33, 2.52))
	_quad("roof_tiles", Vector3(-1.96, 2.22, -0.35), Vector3(-1.96, 2.22, 2.68), Vector3(0.0, 3.06, 2.68), Vector3(0.0, 3.06, -0.35))
	_quad("roof_tiles", Vector3(0.0, 3.06, -0.35), Vector3(0.0, 3.06, 2.68), Vector3(1.96, 2.22, 2.68), Vector3(1.96, 2.22, -0.35))
	_box("roof_tiles", Vector3(-0.10, 3.00, -0.40), Vector3(0.10, 3.12, 2.72))
	_box("medieval_brick", Vector3(0.90, 1.85, 1.45), Vector3(1.43, 3.72, 2.05))
	_box("medieval_brick", Vector3(0.80, 3.62, 1.36), Vector3(1.53, 3.80, 2.13))
	_box("metal", Vector3(0.96, 3.80, 1.52), Vector3(1.37, 3.85, 1.97))
	# A barred high window and a tool rail give the rear wall a working identity.
	_box("glazing", Vector3(-1.23, 1.39, 2.43), Vector3(-0.52, 1.90, 2.47))
	for x in [-1.25, -0.51]:
		_box("timber", Vector3(x - 0.055, 1.34, 2.39), Vector3(x + 0.055, 1.97, 2.51))
	_box("timber", Vector3(-1.30, 1.87, 2.39), Vector3(-0.46, 1.98, 2.51))
	_box("timber", Vector3(-1.30, 0.94, 2.39), Vector3(-0.46, 1.05, 2.51))
	_box("timber", Vector3(-1.42, 0.86, 1.55), Vector3(-0.30, 0.97, 2.15))
	for x in [-1.36, -0.36]:
		_box("timber", Vector3(x - 0.05, 0.30, 1.59), Vector3(x + 0.05, 0.88, 2.08))
	_box("metal", Vector3(-0.95, 1.56, 2.42), Vector3(-0.27, 1.64, 2.52))
	for x in [-0.78, -0.47]:
		_box("metal", Vector3(x - 0.025, 1.13, 2.48), Vector3(x + 0.025, 1.60, 2.55))
	# Low stone firebed leaves Tor and the player a clear view into the work bay.
	_box("medieval_brick", Vector3(1.02, 0.03, -1.54), Vector3(1.98, 0.25, -0.66))
	_box("medieval_brick", Vector3(1.02, 0.25, -1.54), Vector3(1.18, 0.54, -0.66))
	_box("medieval_brick", Vector3(1.82, 0.25, -1.54), Vector3(1.98, 0.54, -0.66))
	_box("medieval_brick", Vector3(1.18, 0.25, -0.82), Vector3(1.82, 0.54, -0.66))
	_box("metal", Vector3(1.18, 0.26, -1.37), Vector3(1.82, 0.30, -0.86))

func _build_shrine_oathstone() -> void:
	# Stepped burial stone and a tapered witness marker, facing the village road.
	_box("medieval_brick", Vector3(-1.18, 0.02, -0.82), Vector3(1.18, 0.18, 0.82))
	_box("medieval_brick", Vector3(-0.92, 0.18, -0.62), Vector3(0.92, 0.34, 0.62))
	_box("medieval_brick", Vector3(-0.50, 0.34, -0.37), Vector3(0.50, 0.45, 0.34))
	var bottom_y := 0.44
	var shoulder_y := 1.53
	var crown_y := 1.83
	for side in [-1.0, 1.0]:
		if side < 0.0:
			_quad("medieval_brick", Vector3(side * 0.44, bottom_y, -0.30), Vector3(side * 0.44, bottom_y, 0.30), Vector3(side * 0.30, shoulder_y, 0.23), Vector3(side * 0.30, shoulder_y, -0.23))
		else:
			_quad("medieval_brick", Vector3(side * 0.44, bottom_y, 0.30), Vector3(side * 0.44, bottom_y, -0.30), Vector3(side * 0.30, shoulder_y, -0.23), Vector3(side * 0.30, shoulder_y, 0.23))
	_quad("plaster", Vector3(-0.44, bottom_y, -0.31), Vector3(-0.30, shoulder_y, -0.24), Vector3(0.30, shoulder_y, -0.24), Vector3(0.44, bottom_y, -0.31))
	_quad("medieval_brick", Vector3(0.44, bottom_y, 0.31), Vector3(0.30, shoulder_y, 0.24), Vector3(-0.30, shoulder_y, 0.24), Vector3(-0.44, bottom_y, 0.31))
	for z in [-0.24, 0.24]:
		if z < 0.0:
			_triangle("medieval_brick", Vector3(-0.30, shoulder_y, z), Vector3(0.0, crown_y, z), Vector3(0.30, shoulder_y, z))
		else:
			_triangle("medieval_brick", Vector3(0.30, shoulder_y, z), Vector3(0.0, crown_y, z), Vector3(-0.30, shoulder_y, z))
	_quad("medieval_brick", Vector3(-0.30, shoulder_y, -0.24), Vector3(-0.30, shoulder_y, 0.24), Vector3(0.0, crown_y, 0.24), Vector3(0.0, crown_y, -0.24))
	_quad("medieval_brick", Vector3(0.0, crown_y, -0.24), Vector3(0.0, crown_y, 0.24), Vector3(0.30, shoulder_y, 0.24), Vector3(0.30, shoulder_y, -0.24))
	# Three angular metal inlays form an original crow-and-oath mark.
	_triangle("metal", Vector3(-0.27, 1.23, -0.263), Vector3(-0.04, 1.08, -0.263), Vector3(0.0, 0.93, -0.263))
	_triangle("metal", Vector3(0.27, 1.23, -0.263), Vector3(0.0, 0.93, -0.263), Vector3(0.04, 1.08, -0.263))
	_triangle("metal", Vector3(-0.09, 0.88, -0.265), Vector3(0.09, 0.88, -0.265), Vector3(0.0, 0.67, -0.265))
	_box("glazing", Vector3(-0.045, 1.29, -0.27), Vector3(0.045, 1.37, -0.25))
	# Offering board and worn red votive tile sit below the standing stone.
	_box("timber", Vector3(-0.98, 0.36, -0.70), Vector3(-0.47, 0.43, -0.35))
	_box("roof_tiles", Vector3(0.48, 0.36, -0.68), Vector3(0.98, 0.39, -0.38))
	for x in [-0.68, 0.68]:
		_box("plaster", Vector3(x - 0.045, 0.38, -0.56), Vector3(x + 0.045, 0.61, -0.47))

func _build_village_well() -> void:
	var sides := 10
	var outer_radius := 0.87
	var inner_radius := 0.58
	for side in range(sides):
		var start := TAU * float(side) / float(sides)
		var finish := TAU * float(side + 1) / float(sides)
		var outer_a := Vector3(cos(start) * outer_radius, 0.0, sin(start) * outer_radius)
		var outer_b := Vector3(cos(finish) * outer_radius, 0.0, sin(finish) * outer_radius)
		var inner_a := Vector3(cos(start) * inner_radius, 0.0, sin(start) * inner_radius)
		var inner_b := Vector3(cos(finish) * inner_radius, 0.0, sin(finish) * inner_radius)
		_quad("medieval_brick", outer_a + Vector3.UP * 0.03, outer_a + Vector3.UP * 0.84, outer_b + Vector3.UP * 0.84, outer_b + Vector3.UP * 0.03)
		_quad("medieval_brick", inner_b + Vector3.UP * 0.16, inner_b + Vector3.UP * 0.84, inner_a + Vector3.UP * 0.84, inner_a + Vector3.UP * 0.16)
		_quad("plaster", outer_a + Vector3.UP * 0.84, inner_a + Vector3.UP * 0.84, inner_b + Vector3.UP * 0.84, outer_b + Vector3.UP * 0.84)
		_triangle("glazing", Vector3(0, 0.43, 0), inner_b + Vector3.UP * 0.43, inner_a + Vector3.UP * 0.43)
	for x in [-0.77, 0.77]:
		_box("timber", Vector3(x - 0.085, 0.82, -0.12), Vector3(x + 0.085, 2.02, 0.12))
	_box("timber", Vector3(-0.91, 1.79, -0.13), Vector3(0.91, 1.94, 0.13))
	_box("metal", Vector3(-0.17, 1.76, -0.15), Vector3(0.17, 1.96, 0.15))
	_box("timber", Vector3(-0.035, 0.91, -0.035), Vector3(0.035, 1.78, 0.035))
	_box("timber", Vector3(-0.19, 0.65, -0.19), Vector3(0.19, 0.91, 0.19))
	_box("metal", Vector3(-0.21, 0.91, -0.21), Vector3(0.21, 0.97, 0.21))
	_box("roof_tiles", Vector3(-0.25, 0.09, -1.02), Vector3(0.25, 0.15, -0.86))
