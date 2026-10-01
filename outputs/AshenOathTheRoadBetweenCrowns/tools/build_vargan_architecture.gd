extends "res://tools/build_record_archive.gd"

const VILLAGE := "res://assets_external/environment/village/"
const KIT := ["Wall_UnevenBrick_Straight.obj", "Wall_UnevenBrick_Window_Thin_Round.obj", "Wall_Arch.obj", "Wall_Plaster_WoodGrid.obj", "Wall_Plaster_Straight.obj", "Roof_RoundTiles_6x10.obj", "Roof_Front_Brick6.obj", "Door_1_Flat.obj"]

func _initialize() -> void:
	for file in KIT:
		var mesh := load(VILLAGE + file) as ArrayMesh
		if mesh == null:
			push_error("Vargan source is unavailable: " + file)
			quit(1)
			return
		imported[file] = mesh
	for variant in ["gatehouse", "tower", "keep", "curtain", "stable", "cistern", "door", "forge", "record_entry"]:
		wood = SurfaceTool.new()
		books = SurfaceTool.new()
		wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		books.begin(Mesh.PRIMITIVE_TRIANGLES)
		match variant:
			"gatehouse": _gatehouse()
			"tower": _tower()
			"keep": _keep()
			"curtain": _curtain()
			"stable": _stable()
			"cistern": _cistern()
			"door": _door()
			"forge": _forge()
			"record_entry": _record_entry()
		wood.index()
		books.index()
		var result := wood.commit()
		books.commit(result)
		for part in result.get_surface_count():
			result.surface_set_name(part, "masonry" if part == 0 else "weathered_detail")
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.9
			result.surface_set_material(part, material)
		result.set_meta("source_pack", "Quaternius Medieval Village MegaKit")
		result.set_meta("license", "CC0 1.0")
		var hashes: Dictionary = {}
		for file in KIT:
			hashes[file] = FileAccess.get_sha256(VILLAGE + file)
		result.set_meta("source_sha256", hashes)
		result.set_meta("variant", variant)
		var path := "res://assets_external/environment/village/Vargan_%s_Authored.res" % variant
		var error := ResourceSaver.save(result, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Vargan bake failed: " + error_string(error))
			quit(1)
			return
		print("VARGAN BAKE: PASS variant=%s surfaces=%d triangles=%d bytes=%d" % [variant, result.get_surface_count(), result.get_faces().size() / 3, FileAccess.get_file_as_bytes(path).size()])
	quit(0)

func _stone(source_id: String, position: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	_append(wood, imported[source_id], _fit(imported[source_id], size, position, yaw), Color(0.82, 0.82, 0.79))

func _block(surface: SurfaceTool, position: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_append(surface, mesh, Transform3D(Basis.IDENTITY, position), color)

func _gatehouse() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 7.3
		for level in [0.0, 3.5]:
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(x, level, 1.52), Vector3(4.2, 3.5, 0.34))
			_stone("Wall_UnevenBrick_Straight.obj", Vector3(x, level, -1.52), Vector3(4.2, 3.5, 0.34), 180.0)
		for edge in [x - 2.1, x + 2.1]:
			_stone("Wall_UnevenBrick_Straight.obj", Vector3(edge, 0, 0), Vector3(3.1, 7.0, 0.34), 90.0)
		_block(wood, Vector3(x, 7.05, 0), Vector3(4.45, 0.25, 3.4), Color(0.78, 0.76, 0.70))
		for merlon_x in [x - 1.8, x, x + 1.8]:
			_block(wood, Vector3(merlon_x, 7.65, 1.30), Vector3(0.85, 1.05, 0.68), Color(0.82, 0.82, 0.79))
		_block(books, Vector3(x, 4.1, 1.72), Vector3(0.9, 1.9, 0.035), Color(0.34, 0.07, 0.06))
	_stone("Wall_Arch.obj", Vector3(0, 0, 1.53), Vector3(10.4, 5.2, 0.5))
	_stone("Wall_Arch.obj", Vector3(0, 0, -1.53), Vector3(10.4, 5.2, 0.5), 180.0)
	# A defended gallery spans the arch; the passage below remains open.
	for z in [-1.53, 1.53]:
		for x in [-3.45, 0.0, 3.45]:
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(x, 5.15, z), Vector3(3.45, 1.85, 0.38), 0.0 if z > 0 else 180.0)
			_block(books, Vector3(x, 6.07, z - signf(z) * 0.19), Vector3(0.80, 1.15, 0.025), Color(0.10, 0.11, 0.12))
		for x in [-4.45, -2.23, 0.0, 2.23, 4.45]:
			_block(wood, Vector3(x, 7.65, z), Vector3(0.85, 1.05, 0.68), Color(0.82, 0.82, 0.79))
		for x in [-4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5]:
			_block(wood, Vector3(x, 4.95, z), Vector3(0.30, 0.45, 0.70), Color(0.58, 0.57, 0.52))
	_block(wood, Vector3(0, 5.2, 0), Vector3(10.4, 0.22, 3.5), Color(0.65, 0.64, 0.59))
	_block(wood, Vector3(0, 7.05, 0), Vector3(10.7, 0.25, 3.5), Color(0.78, 0.76, 0.70))
	for side in [-1.0, 1.0]:
		# Open leaves belong to the gatehouse, not a small floating door in its lane.
		var door := imported["Door_1_Flat.obj"] as ArrayMesh
		_append(books, door, _fit(door, Vector3(2.8, 3.7, 0.22), Vector3(side * 4.55, 0.08, 0.0), side * 90.0), Color(0.36, 0.23, 0.13))
		for z in [-1.4, 1.4]:
			_block(wood, Vector3(side * 5.5, 1.9, z), Vector3(0.65, 3.8, 0.65), Color(0.68, 0.66, 0.60))
	for x in [-2.2, -1.1, 0.0, 1.1, 2.2]:
		_block(books, Vector3(x, 4.6, 1.33), Vector3(0.12, 1.1, 0.14), Color(0.19, 0.20, 0.20))
	_block(books, Vector3(0, 4.15, 1.33), Vector3(5.0, 0.12, 0.14), Color(0.19, 0.20, 0.20))

func _tower() -> void:
	# Canonical footprint matches the existing five-metre square collision tower.
	for side in [-1.0, 1.0]:
		for level in [0.0, 0.5]:
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(0, level, side * 2.51), Vector3(5.0, 0.5, 0.16), 0.0 if side > 0 else 180.0)
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(side * 2.51, level, 0), Vector3(5.0, 0.5, 0.16), 90.0 if side > 0 else -90.0)
	for y in [0.02, 0.5, 1.01]:
		_block(wood, Vector3(0, y, 0), Vector3(5.35, 0.035, 5.35), Color(0.78, 0.76, 0.70))
	for x in [-1.85, 0.0, 1.85]:
		for z in [-2.20, 2.20]:
			_block(wood, Vector3(x, 1.08, z), Vector3(0.8, 0.14, 0.72), Color(0.82, 0.82, 0.79))
	for z in [-0.92, 0.92]:
		for x in [-2.20, 2.20]:
			_block(wood, Vector3(x, 1.08, z), Vector3(0.72, 0.14, 0.8), Color(0.82, 0.82, 0.79))
	# Dark window recesses remain behind the cut source windows.
	for side in [-1.0, 1.0]:
		_block(books, Vector3(0, 0.70, side * 2.48), Vector3(0.36, 0.14, 0.02), Color(0.14, 0.16, 0.17))

func _keep() -> void:
	for level in [0.0, 4.4]:
		for x in [-3.3, 0.0, 3.3]:
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(x, level, 2.05), Vector3(3.65, 4.4, 0.34))
			_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(x, level, -2.05), Vector3(3.65, 4.4, 0.34), 180.0)
	for side in [-1.0, 1.0]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(side * 5.5, 0, 0), Vector3(4.1, 8.8, 0.34), side * 90.0)
	_block(wood, Vector3(0, 8.9, 0), Vector3(12.4, 0.30, 4.5), Color(0.78, 0.76, 0.70))
	for x in [-4.4, -2.2, 0.0, 2.2, 4.4]:
		_block(wood, Vector3(x, 9.55, 2.1), Vector3(0.9, 1.0, 0.75), Color(0.82, 0.82, 0.79))
	_block(books, Vector3(0, 2.2, 2.08), Vector3(2.1, 4.0, 0.035), Color(0.19, 0.14, 0.11))

func _curtain() -> void:
	for x in [-4.35, -1.45, 1.45, 4.35]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(x, 0, 0), Vector3(2.9, 6.0, 1.1))
	# Footing and engaged piers articulate the same collision envelope.
	_block(wood, Vector3(0, 0.3, 0), Vector3(11.6, 0.6, 1.4), Color(0.60, 0.58, 0.53))
	for x in [-5.4, 0.0, 5.4]:
		_block(wood, Vector3(x, 2.9, 0), Vector3(0.62, 5.8, 1.4), Color(0.72, 0.70, 0.64))
	_block(wood, Vector3(0, 6.1, 0), Vector3(11.8, 0.25, 1.65), Color(0.78, 0.76, 0.70))
	for x in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		_block(wood, Vector3(x, 6.65, 0), Vector3(0.9, 0.9, 1.1), Color(0.82, 0.82, 0.79))
	_block(books, Vector3(0, 3.8, 0.73), Vector3(0.95, 1.8, 0.025), Color(0.29, 0.06, 0.05))

func _stable() -> void:
	for x in [-3.45, 3.45]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(x, 0, 0), Vector3(10.0, 0.42, 0.24), 90.0)
	for z in [-5.0, 5.0]:
		_stone("Wall_Plaster_Straight.obj", Vector3(0, 0.40, z), Vector3(7.0, 2.6, 0.28))
		_append(books, imported["Wall_Plaster_WoodGrid.obj"], _fit(imported["Wall_Plaster_WoodGrid.obj"], Vector3(7.0, 2.6, 0.12), Vector3(0, 0.40, z + signf(z) * 0.18), 0), Color(0.34, 0.23, 0.14))
		_stone("Roof_Front_Brick6.obj", Vector3(0, 3.0, z), Vector3(7.0, 2.3, 0.24))
	for x in [-3.5, 3.5]:
		_stone("Wall_Plaster_Straight.obj", Vector3(x, 0.40, 0), Vector3(10.0, 2.6, 0.28), 90.0)
		_append(books, imported["Wall_Plaster_WoodGrid.obj"], _fit(imported["Wall_Plaster_WoodGrid.obj"], Vector3(10.0, 2.6, 0.12), Vector3(x + signf(x) * 0.18, 0.40, 0), 90), Color(0.34, 0.23, 0.14))
	_append(books, imported["Roof_RoundTiles_6x10.obj"], _fit(imported["Roof_RoundTiles_6x10.obj"], Vector3(7.8, 2.6, 10.8), Vector3(0, 2.9, 0), 0), Color(0.40, 0.22, 0.17))
	_block(books, Vector3(0, 1.4, -5.18), Vector3(2.1, 2.2, 0.08), Color(0.20, 0.13, 0.08))
	for x in [-1.0, 1.0]:
		_block(books, Vector3(x, 1.4, -5.24), Vector3(0.12, 2.25, 0.06), Color(0.32, 0.23, 0.15))

func _cistern() -> void:
	for side in [-1.0, 1.0]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(0, 0, side * 1.86), Vector3(4.0, 1.05, 0.28))
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(side * 1.86, 0, 0), Vector3(3.5, 1.05, 0.28), 90.0)
		_block(wood, Vector3(0, 1.16, side * 1.86), Vector3(4.22, 0.22, 0.44), Color(0.90, 0.88, 0.80))
		_block(wood, Vector3(side * 1.86, 1.16, 0), Vector3(0.44, 0.22, 3.36), Color(0.90, 0.88, 0.80))
	_block(books, Vector3(0.0, 0.72, -2.02), Vector3(0.28, 0.30, 0.035), Color(0.14, 0.15, 0.13))

func _door() -> void:
	for x in [-1.04, 1.04]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(x, 0, 0), Vector3(0.42, 2.65, 0.24))
	_stone("Wall_UnevenBrick_Straight.obj", Vector3(0, 2.65, 0), Vector3(2.5, 0.35, 0.24))
	_append(books, imported["Door_1_Flat.obj"], _fit(imported["Door_1_Flat.obj"], Vector3(1.65, 2.45, 0.12), Vector3(0, 0.05, -0.15), 0), Color(0.37, 0.25, 0.15))

func _record_entry() -> void:
	# The archive door is supported by a vaulted vestibule beneath the gate gallery.
	_door()
	for side in [-1.0, 1.0]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(side * 2.5, 0, -0.15), Vector3(2.5, 3.4, 0.55))
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(side * 3.75, 0, -1.3), Vector3(2.8, 3.4, 0.40), 90.0)
		_block(wood, Vector3(side * 3.6, 1.7, 0.12), Vector3(0.55, 3.4, 0.75), Color(0.65, 0.64, 0.59))
	_stone("Wall_UnevenBrick_Straight.obj", Vector3(0, 3.0, -0.15), Vector3(7.8, 0.60, 0.55))
	_stone("Roof_Front_Brick6.obj", Vector3(0, 3.4, -0.15), Vector3(7.8, 1.8, 0.32))
	_append(books, imported["Roof_RoundTiles_6x10.obj"], _fit(imported["Roof_RoundTiles_6x10.obj"], Vector3(8.2, 1.9, 3.3), Vector3(0, 3.35, -1.3), 0), Color(0.32, 0.23, 0.18))
	_block(books, Vector3(0, 3.68, 0.035), Vector3(0.85, 0.60, 0.08), Color(0.26, 0.08, 0.06))

func _forge() -> void:
	_stone("Wall_UnevenBrick_Window_Thin_Round.obj", Vector3(0, 0, 1.5), Vector3(5.8, 2.9, 0.4))
	for side in [-1.0, 1.0]:
		_stone("Wall_UnevenBrick_Straight.obj", Vector3(side * 2.8, 0, 0.9), Vector3(1.6, 2.9, 0.24), 90)
		_block(books, Vector3(side * 2.8, 1.5, -1.7), Vector3(0.18, 3.0, 0.18), Color(0.32, 0.22, 0.13))
	_append(books, imported["Roof_RoundTiles_6x10.obj"], _fit(imported["Roof_RoundTiles_6x10.obj"], Vector3(6.4, 1.7, 4.0), Vector3(0, 2.9, -0.5), 0), Color(0.40, 0.22, 0.17))
	_stone("Wall_UnevenBrick_Straight.obj", Vector3(2.1, 0, 0.5), Vector3(0.80, 4.8, 0.8))
	_block(wood, Vector3(2.1, 4.85, 0.5), Vector3(1.0, 0.20, 1.0), Color(0.82, 0.79, 0.71))
	_block(books, Vector3(0, 0.74, 2.0), Vector3(2.7, 0.18, 0.72), Color(0.34, 0.23, 0.14))
	for x in [-1.1, 1.1]:
		_block(books, Vector3(x, 0.32, 2.0), Vector3(0.12, 0.65, 0.6), Color(0.28, 0.19, 0.12))
