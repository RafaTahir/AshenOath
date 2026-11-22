extends "res://tools/build_record_archive.gd"

const WILD_ROOT := "res://assets_external/environment/forest/"
const VILLAGE_ROOT := "res://assets_external/environment/village/"
const RUIN_KIT := ["Wall_UnevenBrick_Window_Thin_Round.obj", "Wall_Plaster_WoodGrid.obj", "Roof_RoundTiles_6x10.obj", "Door_1_Flat.obj"]
var surfaces: Dictionary = {}
var failed := false

func _initialize() -> void:
	var bandit_only := OS.get_cmdline_user_args().has("--bandit-only")
	var marsh_only := OS.get_cmdline_user_args().has("--marsh-only")
	for zone in (["marsh_crossing"] if marsh_only else (["bandit_road"] if bandit_only else ["deep_wood", "burned_farmstead", "marsh_crossing", "bandit_road"])):
		surfaces.clear()
		var terrain := _surface("forest_ground")
		_bank(terrain, 19.5 if zone == "bandit_road" else 16.5)
		if zone == "bandit_road":
			_bandit_path(_surface("wet_mud"))
			_bandit_ridges(terrain)
		else:
			_path(_surface("wet_mud"), 3.35, 28.0)
		if zone == "deep_wood":
			_patch(terrain, Vector3(0, 0.036, -9), Vector2(6.1, 5.7), Color(0.52, 0.66, 0.48))
		elif zone == "burned_farmstead":
			for origin in [Vector3(-8, 0.037, -5), Vector3(7, 0.037, 2)]:
				_patch(_surface("ash"), origin, Vector2(4.3, 3.2), Color(0.27, 0.24, 0.20))
			for origin in [Vector3(-3.2, 0.036, 6.5), Vector3(0, 0.036, 7.1), Vector3(3, 0.036, 6.2)]:
				_patch(_surface("ash"), origin, Vector2(0.7, 0.36), Color(0.30, 0.26, 0.20))
			_patch(_surface("ash"), Vector3(0, 0.036, 4.3), Vector2(2.4, 0.16), Color(0.31, 0.26, 0.20))
		elif zone == "marsh_crossing":
			for pool in [[Vector3(-8, 0.036, -6), Vector2(4, 3.5)], [Vector3(8, 0.036, 2), Vector2(4.5, 4)], [Vector3(-9, 0.036, 9), Vector2(3.5, 2.5)]]:
				_patch(terrain, pool[0] - Vector3.UP * 0.004, pool[1] * 1.14, Color(0.26, 0.39, 0.29))
				_pool(pool[0], pool[1])
			for position in [Vector3(-5, 0, -9), Vector3(6, 0, -6), Vector3(-7, 0, 1), Vector3(7, 0, 8), Vector3(-5, 0, 11)]:
				_reeds(_surface("foliage"), position)
			# Flush boards follow the actual floor: they do not invent a raised deck
			# that would require the controller to jump over a decorative threshold.
			for index in range(48):
				var z := -13.8 + index * 0.58
				var point := Vector3(sin(z * 0.4) * 0.05, 0.048, z)
				_box(_surface("timber"), point, Vector3(3.3, 0.025, 0.53), Color(0.53 + float(index % 3) * 0.025, 0.40, 0.29))
		_save_surfaces(WILD_ROOT + "Campaign_%s_Landscape.res" % zone, "Original Ashen Oath landscape, pools, reeds and boardwalk geometry")
	if marsh_only:
		quit(1 if failed else 0)
		return
	if bandit_only:
		_build_road_post()
		quit(1 if failed else 0)
		return
	for file in RUIN_KIT:
		var mesh := load(VILLAGE_ROOT + file) as ArrayMesh
		if mesh == null:
			push_error("Missing farmstead source: " + file)
			quit(1)
			return
		imported[file] = mesh
	for side in [-1.0, 1.0]:
		_build_ruin(side)
	_build_road_post()
	quit(1 if failed else 0)

func _build_road_post() -> void:
	surfaces.clear()
	var table_path := "res://assets_external/environment/props/Table_Large.obj"
	var table := load(table_path) as ArrayMesh
	var banner := load("res://assets_external/environment/props/Banner_1_Cloth.obj") as ArrayMesh
	var fence := load(VILLAGE_ROOT + "Prop_WoodenFence_Extension1.obj") as ArrayMesh
	var brick_wall := load(VILLAGE_ROOT + "Wall_UnevenBrick_Window_Thin_Round.obj") as ArrayMesh
	var timber_wall := load(VILLAGE_ROOT + "Wall_Plaster_WoodGrid.obj") as ArrayMesh
	if table == null or banner == null or fence == null or brick_wall == null or timber_wall == null:
		failed = true
		push_error("Required road checkpoint source is missing")
		return
	_watchpost(-7.5, true, brick_wall)
	_watchpost(7.5, false, brick_wall)
	_box(_surface("timber"), Vector3(0, 3.1, -6), Vector3(12.8, 0.30, 0.35), Color(0.28, 0.19, 0.12))
	for side in [-1.0, 1.0]:
		_box(_surface("timber"), Vector3(side * 6.4, 2.65, -6.0), Vector3(0.23, 1.08, 0.32), Color(0.31, 0.21, 0.14))
		_beam_between(_surface("timber"), Vector3(side * 6.4, 2.28, -6.0), Vector3(side * 5.45, 3.0, -6.0), 0.18, Color(0.36, 0.26, 0.17))
	for x in [-3.65, 3.65]:
		_append(_surface("plaster"), banner, _fit(banner, Vector3(0.9, 0.92, 0.12), Vector3(x, 2.0, -5.75), 0), Color(0.34, 0.10, 0.11))
	for x in [-11.5, 11.5]:
		_append(_surface("timber"), fence, _fit(fence, Vector3(2.4, 1.25, 0.25), Vector3(x, 0, -5), 0), Color(0.34, 0.25, 0.16))
	_append(_surface("timber"), table, _fit(table, Vector3(2.6, 1.1, 1.4), Vector3(9.5, 0, -2.3), 0), Color(0.52, 0.38, 0.24))
	var masonry := _surface("medieval_brick")
	var timber := _surface("timber")
	var roof := _surface("roof_tiles")
	var origin := Vector3(12, 0, -8)
	_box(masonry, origin + Vector3(0, 0.15, 0), Vector3(6.2, 0.30, 5.0), Color(0.40, 0.38, 0.34))
	for z in [-2.35, 2.35]:
		_box(masonry, origin + Vector3(0, 0.57, z), Vector3(6.0, 0.72, 0.30), Color(0.51, 0.50, 0.46))
		_append(timber, timber_wall, _fit(timber_wall, Vector3(6.0, 2.0, 0.24), origin + Vector3(0, 0.26, z), 0), Color(0.44, 0.35, 0.29))
	for x in [-2.88, 2.88]:
		_append(masonry, brick_wall, _fit(brick_wall, Vector3(4.55, 2.0, 0.25), origin + Vector3(x, 0.26, 0), 90), Color(0.40, 0.38, 0.34))
	_pitched_roof(roof, origin + Vector3(0, 2.18, 0), 6.5, 5.3, 1.4)
	for offset in [Vector3(-1.8, 0.3, 3.4), Vector3(1.7, 0.25, 3.1)]:
		_box(_surface("timber"), origin + offset, Vector3(0.65, 0.5, 0.7), Color(0.36, 0.26, 0.16))
	_save_surfaces(VILLAGE_ROOT + "RoadCheckpoint_Authored.res", "Quaternius village-kit checkpoint, authored pitched roofs and Fantasy Props CC0 table")

func _watchpost(x: float, ruined: bool, brick_wall: ArrayMesh) -> void:
	var stone := _surface("medieval_brick")
	var wood := _surface("timber")
	var roof := _surface("roof_tiles")
	var origin := Vector3(x, 0, -6)
	_box(stone, origin + Vector3(0, 0.37, 0), Vector3(2.3, 0.74, 2.3), Color(0.35, 0.36, 0.33))
	for side in [-1.0, 1.0]:
		_append(stone, brick_wall, _fit(brick_wall, Vector3(2.1, 1.55, 0.23), origin + Vector3(side * 1.0, 0.72, 0), 90), Color(0.38, 0.37, 0.33))
		for z in [-0.92, 0.92]:
			_box(wood, origin + Vector3(side * 0.91, 1.86, z), Vector3(0.17, 2.0, 0.17), Color(0.31, 0.21, 0.13))
		_box(wood, origin + Vector3(side * 0.95, 2.70, 0), Vector3(0.18, 0.20, 2.45), Color(0.34, 0.23, 0.13))
	_box(wood, origin + Vector3(0, 2.7, -0.94), Vector3(2.5, 0.19, 0.18), Color(0.34, 0.23, 0.13))
	_box(wood, origin + Vector3(0, 2.7, 0.94), Vector3(2.5, 0.19, 0.18), Color(0.34, 0.23, 0.13))
	_box(wood, origin + Vector3(0, 1.84, -1.07), Vector3(2.35, 0.13, 0.12), Color(0.26, 0.18, 0.12))
	for side in [-1.0, 1.0]:
		_beam_between(wood, origin + Vector3(side * 0.91, 2.03, 0.94), origin + Vector3(side * 0.31, 2.64, 0.94), 0.12, Color(0.38, 0.28, 0.18))
	if ruined:
		_box(wood, origin + Vector3(-0.7, 3.19, -0.72), Vector3(0.12, 1.12, 0.12), Color(0.30, 0.21, 0.13))
		_box(wood, origin + Vector3(0.83, 3.0, 0.78), Vector3(0.12, 0.74, 0.12), Color(0.30, 0.21, 0.13))
		_box(wood, origin + Vector3(-0.35, 3.72, -0.72), Vector3(0.85, 0.13, 0.12), Color(0.30, 0.21, 0.13))
	else:
		_pitched_roof(roof, origin + Vector3(0, 2.78, 0), 2.8, 2.8, 0.83)

func _pitched_roof(surface: SurfaceTool, center: Vector3, width: float, depth: float, rise: float) -> void:
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	for side in [-1.0, 1.0]:
		for row in range(12):
			var z0 := -half_depth + depth * float(row) / 12.0
			var z1 := -half_depth + depth * float(row + 1) / 12.0
			var eave0 := center + Vector3(side * half_width, 0, z0)
			var eave1 := center + Vector3(side * half_width, 0, z1)
			var ridge0 := center + Vector3(0, rise, z0)
			var ridge1 := center + Vector3(0, rise, z1)
			var tint := Color(0.34, 0.24, 0.22) if row % 3 != 0 else Color(0.30, 0.21, 0.19)
			for point in [eave0, ridge0, ridge1, eave0, ridge1, eave1]:
				_vertex(surface, point, tint)
	_box(_surface("timber"), center + Vector3(0, rise, 0), Vector3(0.15, 0.13, depth + 0.25), Color(0.26, 0.18, 0.13))


func _build_ruin(side: float) -> void:
	wood = SurfaceTool.new()
	books = SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(wood, imported[RUIN_KIT[0]], _fit(imported[RUIN_KIT[0]], Vector3(5.8, 2.1, 0.38), Vector3(0, 0.20, 1.95), 0), Color(0.40, 0.39, 0.34))
	_append(wood, imported[RUIN_KIT[0]], _fit(imported[RUIN_KIT[0]], Vector3(4.0, 2.1, 0.38), Vector3(side * 2.72, 0.20, 0), side * -90), Color(0.36, 0.36, 0.31))
	_append(books, imported[RUIN_KIT[1]], _fit(imported[RUIN_KIT[1]], Vector3(5.8, 2.1, 0.10), Vector3(0, 0.20, 2.17), 0), Color(0.21, 0.15, 0.10))
	_append(books, imported[RUIN_KIT[3]], _fit(imported[RUIN_KIT[3]], Vector3(0.88, 1.42, 0.12), Vector3(0, 0.09, -1.98), 0), Color(0.24, 0.17, 0.11))
	if side < 0:
		# Only the western foundation survives route reservation in gameplay.
		_box(wood, Vector3(0, 0.20, 0), Vector3(6.2, 0.40, 4.8), Color(0.35, 0.34, 0.29))
	# The inner wall and roof have burned away. Retain their open clue approach;
	# a complete replacement house would close a previously walkable route.
	var roof_source := imported[RUIN_KIT[2]] as ArrayMesh
	var roof_transform := _fit(roof_source, Vector3(6.2, 1.5, 4.8), Vector3(0, 2.3, 0), 0)
	var retained := SurfaceTool.new()
	retained.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := roof_source.get_faces()
	for face in range(0, faces.size(), 3):
		var center := roof_transform * ((faces[face] + faces[face + 1] + faces[face + 2]) / 3)
		if center.x * side < 0.4 or center.z < -0.8:
			continue
		for index in range(3):
			retained.add_vertex(roof_transform * faces[face + index])
	retained.generate_normals()
	retained.index()
	_append(books, retained.commit(), Transform3D.IDENTITY, Color(0.28, 0.18, 0.11))
	for x in [-2.7, 2.7]:
		_box(books, Vector3(x, 1.1, -1.9), Vector3(0.14, 2.2, 0.14), Color(0.18, 0.12, 0.08))
	_box(books, Vector3(0, 2.23, -1.9), Vector3(5.8, 0.18, 0.16), Color(0.20, 0.13, 0.085))
	wood.index()
	books.index()
	var ruins := wood.commit()
	books.commit(ruins)
	for surface in ruins.get_surface_count():
		ruins.surface_set_name(surface, "medieval_brick" if surface == 0 else "timber")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.96
		ruins.surface_set_material(surface, material)
	ruins.set_meta("source_pack", "Quaternius Medieval Village MegaKit")
	ruins.set_meta("license", "CC0 1.0")
	var hashes := {}
	for file in RUIN_KIT:
		hashes[VILLAGE_ROOT + file] = FileAccess.get_sha256(VILLAGE_ROOT + file)
	ruins.set_meta("source_sha256", hashes)
	_save_mesh(ruins, VILLAGE_ROOT + "Farmstead%s_Authored.res" % ("West" if side < 0 else "East"))

func _surface(id: String) -> SurfaceTool:
	if not surfaces.has(id):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3.UP)
		surfaces[id] = surface
	return surfaces[id]

func _vertex(surface: SurfaceTool, point: Vector3, tint: Color) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_color(tint)
	surface.set_uv(Vector2(point.x, point.z))
	surface.add_vertex(point)

func _path(surface: SurfaceTool, width: float, length: float) -> void:
	for row in range(20):
		var z0 := -length / 2 + row * length / 20
		var z1 := z0 + length / 20
		var w0 := width * 0.5 + sin(z0 * 0.39) * 0.13
		var w1 := width * 0.5 + sin(z1 * 0.39) * 0.13
		for side in [-1.0, 1.0]:
			var points := [Vector3(0, 0.039, z0), Vector3(side * w0, 0.039, z0), Vector3(side * w1, 0.039, z1), Vector3(0, 0.039, z1)]
			for index in ([0, 1, 2, 0, 2, 3] if side > 0 else [0, 2, 1, 0, 3, 2]):
				_vertex(surface, points[index], Color(0.75, 0.71, 0.59) if index in [0, 3] else Color(0.46, 0.52, 0.38))

func _bandit_path(surface: SurfaceTool) -> void:
	var length := 35.0
	for row in range(28):
		var z0 := -length * 0.5 + float(row) * length / 28.0
		var z1 := z0 + length / 28.0
		# The road joins the actual southwest/northeast exits, not an unrelated
		# north-south strip. Its surface stays flush with the proven capsule floor.
		var c0 := -z0 * 7.0 / 16.5 + sin(z0 * 0.19) * 0.18
		var c1 := -z1 * 7.0 / 16.5 + sin(z1 * 0.19) * 0.18
		for side in [-1.0, 1.0]:
			var shoulder: float = float(side) * (1.62 + sin(z0 * 0.41) * 0.08)
			var shoulder_next: float = float(side) * (1.62 + sin(z1 * 0.41) * 0.08)
			var points := [Vector3(c0, 0.042, z0), Vector3(c0 + shoulder, 0.042, z0), Vector3(c1 + shoulder_next, 0.042, z1), Vector3(c1, 0.042, z1)]
			for index in ([0, 1, 2, 0, 2, 3] if side > 0 else [0, 2, 1, 0, 3, 2]):
				_vertex(surface, points[index], Color(0.52, 0.43, 0.33) if index in [0, 3] else Color(0.42, 0.34, 0.26))
		for offset in [-1.17, 1.17]:
			var rut := [Vector3(c0 + offset - 0.24, 0.045, z0), Vector3(c0 + offset + 0.24, 0.045, z0), Vector3(c1 + offset + 0.24, 0.045, z1), Vector3(c1 + offset - 0.24, 0.045, z1)]
			for index in [0, 2, 1, 0, 3, 2]:
				_vertex(surface, rut[index], Color(0.29, 0.24, 0.19))

func _bandit_ridges(surface: SurfaceTool) -> void:
	# These are visual landforms beyond the x=22 play-area bounds. The active
	# road, guard arena, collision and river/spawn contracts remain unchanged.
	var offsets: Array[float] = [21.8, 23.0, 25.5, 28.0, 31.0]
	var heights: Array[float] = [0.02, 0.18, 1.10, 2.35, 3.05]
	for side in [-1.0, 1.0]:
		for row in range(32):
			var z0 := -19.0 + float(row) * 38.0 / 32.0
			var z1 := -19.0 + float(row + 1) * 38.0 / 32.0
			for band in range(offsets.size() - 1):
				var x0: float = side * offsets[band]
				var x1: float = side * offsets[band + 1]
				var y0: float = heights[band]
				var y1: float = heights[band + 1]
				var wave0 := sin(z0 * 0.37 + side) * 0.18 + sin(z0 * 0.14) * 0.24
				var wave1 := sin(z1 * 0.37 + side) * 0.18 + sin(z1 * 0.14) * 0.24
				var a := Vector3(x0, y0 + wave0 * float(band) / 4.0, z0)
				var b := Vector3(x1, y1 + wave0 * float(band + 1) / 4.0, z0)
				var c := Vector3(x1, y1 + wave1 * float(band + 1) / 4.0, z1)
				var d := Vector3(x0, y0 + wave1 * float(band) / 4.0, z1)
				var tint := Color(0.46, 0.48, 0.38).lerp(Color(0.37, 0.36, 0.31), float(band) / 4.0)
				var points := [a, b, c, d]
				for index in ([0, 1, 2, 0, 2, 3] if side > 0 else [0, 2, 1, 0, 3, 2]):
					_vertex(surface, points[index], tint)

func _beam_between(surface: SurfaceTool, start: Vector3, finish: Vector3, width: float, tint: Color) -> void:
	var beam := BoxMesh.new()
	beam.size = Vector3(width, start.distance_to(finish), width)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, beam.get_mesh_arrays())
	var transform := Transform3D(Basis(Quaternion(Vector3.UP, (finish - start).normalized())), (start + finish) * 0.5)
	_append(surface, mesh, transform, tint)

func _bank(surface: SurfaceTool, edge_z: float) -> void:
	for index in range(16):
		var x0 := -26.0 + index * 52.0 / 16
		var x1 := x0 + 52.0 / 16
		var front0 := Vector3(x0, -0.06, -edge_z)
		var front1 := Vector3(x1, -0.06, -edge_z)
		var back0 := Vector3(x0, 2.4 + sin(x0 * 0.27) * 0.8, -edge_z - 5)
		var back1 := Vector3(x1, 2.4 + sin(x1 * 0.27) * 0.8, -edge_z - 5)
		for point in [front0, back0, back1, front0, back1, front1]:
			_vertex(surface, point, Color(0.48, 0.61, 0.40))

func _patch(surface: SurfaceTool, origin: Vector3, radii: Vector2, tint: Color) -> void:
	for index in range(32):
		var a := index * TAU / 32
		var b := (index + 1) * TAU / 32
		_vertex(surface, origin, tint)
		for angle in [a, b]:
			var radius := 0.95 + sin(angle * 5) * 0.05
			_vertex(surface, origin + Vector3(cos(angle) * radii.x * radius, 0, sin(angle) * radii.y * radius), tint.darkened(0.14))

func _pool(origin: Vector3, radii: Vector2) -> void:
	var water := _surface("water")
	var shore := _surface("wet_mud")
	var rings := [0.0, 0.55, 1.0, 1.10]
	var tints := [Color(0.10, 0.28, 0.26), Color(0.20, 0.45, 0.41), Color(0.40, 0.66, 0.56), Color(0.38, 0.34, 0.24)]
	for ring in range(3):
		var surface := shore if ring == 2 else water
		for index in range(32):
			var a := float(index) * TAU / 32.0
			var b := float(index + 1) * TAU / 32.0
			var points: Array[Vector3] = []
			for entry in [[a, rings[ring]], [a, rings[ring + 1]], [b, rings[ring]], [b, rings[ring + 1]]]:
				var radius: float = (0.95 + sin(float(entry[0]) * 5.0) * 0.05) * float(entry[1])
				points.append(origin + Vector3(cos(entry[0]) * radii.x * radius, 0.003 if ring == 2 else 0.0, sin(entry[0]) * radii.y * radius))
			for corner in ([0, 1, 3] if ring == 0 else [0, 1, 2, 2, 1, 3]):
				_vertex(surface, points[corner], tints[ring + (corner % 2)])

func _box(surface: SurfaceTool, position: Vector3, size: Vector3, tint: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	for index in arrays[Mesh.ARRAY_INDEX]:
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index] + position
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		surface.set_normal(normal)
		surface.set_color(tint)
		var uv := Vector2(point.x, point.z)
		if absf(normal.y) < 0.5:
			uv = Vector2(point.x if absf(normal.z) > 0.5 else point.z, -point.y)
		surface.set_uv(uv)
		surface.add_vertex(point)

func _reeds(surface: SurfaceTool, origin: Vector3) -> void:
	for index in range(9):
		var angle := index * 2.39996
		var point := origin + Vector3(cos(angle) * 0.32, 0.03, sin(angle) * 0.32)
		var tip := point + Vector3(cos(angle) * 0.17, 0.65 + float(index % 4) * 0.16, sin(angle) * 0.17)
		var across := Vector3(cos(angle + PI / 2), 0, sin(angle + PI / 2)) * 0.028
		for vertex in [point - across, tip, point + across, point + across, tip, point - across]:
			_vertex(surface, vertex, Color(0.49, 0.65, 0.32))

func _save_surfaces(path: String, source: String) -> void:
	var mesh := ArrayMesh.new()
	for id in surfaces:
		var tool := surfaces[id] as SurfaceTool
		tool.generate_normals()
		tool.index()
		tool.commit(mesh)
		var surface := mesh.get_surface_count() - 1
		mesh.surface_set_name(surface, id)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		mesh.surface_set_material(surface, material)
	mesh.set_meta("source", source)
	mesh.set_meta("visual_only", true)
	if path.ends_with("RoadCheckpoint_Authored.res"):
		mesh.set_meta("license", "CC0 1.0")
		var hashes := {}
		for input in ["res://assets_external/environment/props/Table_Large.obj", "res://assets_external/environment/props/Banner_1_Cloth.obj", VILLAGE_ROOT + "Prop_WoodenFence_Extension1.obj", VILLAGE_ROOT + "Wall_UnevenBrick_Window_Thin_Round.obj", VILLAGE_ROOT + "Wall_Plaster_WoodGrid.obj"]:
			hashes[input] = FileAccess.get_sha256(input)
		mesh.set_meta("source_sha256", hashes)
	_save_mesh(mesh, path)

func _save_mesh(mesh: ArrayMesh, path: String) -> void:
	var error := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		failed = true
		push_error("Campaign wilds bake failed: " + error_string(error))
		return
	print("CAMPAIGN WILDS BAKE: PASS path=%s surfaces=%d triangles=%d bytes=%d" % [path, mesh.get_surface_count(), mesh.get_faces().size() / 3, FileAccess.get_file_as_bytes(path).size()])
