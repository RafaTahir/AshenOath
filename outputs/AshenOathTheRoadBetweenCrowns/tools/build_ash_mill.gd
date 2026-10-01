extends "res://tools/build_record_archive.gd"

const VILLAGE := "res://assets_external/environment/village/"
const KIT := ["Wall_UnevenBrick_Window_Thin_Round.obj", "Wall_Plaster_WoodGrid.obj", "Roof_Front_Brick6.obj", "Roof_RoundTiles_6x10.obj"]
const OUTPUT_MILL := "res://assets_external/environment/village/AshMill_Authored.res"

func _initialize() -> void:
	for file in KIT:
		var source := load(VILLAGE + file) as ArrayMesh
		if source == null:
			push_error("Required mill source is missing: " + file)
			quit(1)
			return
		imported[file] = source
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	books.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall(Vector3(0, 0.225, -2.60), Vector3(8.1, 2.45, 0.42), 0)
	var foundation := BoxMesh.new()
	foundation.size = Vector3(8.1, 0.225, 0.42)
	var plinth := ArrayMesh.new()
	plinth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, foundation.get_mesh_arrays())
	_append(wood, plinth, Transform3D(Basis.IDENTITY, Vector3(0, 0.1125, -2.60)), Color(0.59, 0.57, 0.51))
	for side in [-1.0, 1.0]:
		_wall(Vector3(side * 3.95, 0.225, 0), Vector3(5.2, 2.45, 0.42), side * 90)
		_append(books, imported["Wall_Plaster_WoodGrid.obj"], _fit(imported["Wall_Plaster_WoodGrid.obj"], Vector3(5.2, 2.45, 0.12), Vector3(side * 4.18, 0.225, 0), side * 90), Color(0.26, 0.18, 0.12))
		foundation.size = Vector3(0.42, 0.225, 5.2)
		var side_plinth := ArrayMesh.new()
		side_plinth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, foundation.get_mesh_arrays())
		_append(wood, side_plinth, Transform3D(Basis.IDENTITY, Vector3(side * 3.95, 0.1125, 0)), Color(0.59, 0.57, 0.51))
	_append(wood, imported["Roof_Front_Brick6.obj"], _fit(imported["Roof_Front_Brick6.obj"], Vector3(8.1, 1.45, 0.22), Vector3(0, 2.675, -2.61), 0), Color(0.66, 0.64, 0.57))
	# Only the west roof survives. The east slope is burned away, preserving the
	# existing Ashwing sightline instead of obscuring its arena with a full roof.
	_append_west_roof(imported["Roof_RoundTiles_6x10.obj"], _fit(imported["Roof_RoundTiles_6x10.obj"], Vector3(8.55, 1.65, 5.55), Vector3(0, 2.60, 0), 0))
	for x in [-3.85, 3.85]:
		_beam(Vector3(x, 1.40, 2.55), Vector3(0.20, 2.8, 0.20))
	_beam(Vector3(0, 2.8, 2.55), Vector3(8.1, 0.20, 0.20))
	for z in [-2.30, 0.0, 2.30]:
		var box := BoxMesh.new()
		box.size = Vector3(4.20, 0.16, 0.20)
		var source := ArrayMesh.new()
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
		_append(books, source, Transform3D(Basis(Vector3.FORWARD, -0.30), Vector3(2.0, 3.36, z)), Color(0.22, 0.14, 0.09))
	_make_wheel()
	wood.index()
	books.index()
	var result := wood.commit()
	books.commit(result)
	for surface in result.get_surface_count():
		result.surface_set_name(surface, "masonry" if surface == 0 else "charred_timber_and_tiles")
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.93
		result.surface_set_material(surface, material)
	result.set_meta("source_pack", "Quaternius Medieval Village MegaKit")
	result.set_meta("license", "CC0 1.0")
	result.set_meta("collision_owned_by", "campaign_wilderness_section.gd:_make_mill_shell")
	var hashes: Dictionary = {}
	for source in KIT:
		hashes[source] = FileAccess.get_sha256(VILLAGE + source)
	result.set_meta("source_sha256", hashes)
	var error := ResourceSaver.save(result, OUTPUT_MILL, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Mill bake failed: " + error_string(error))
		quit(1)
		return
	print("ASH MILL BAKE: PASS surfaces=%d triangles=%d bytes=%d" % [result.get_surface_count(), result.get_faces().size() / 3, FileAccess.get_file_as_bytes(OUTPUT_MILL).size()])
	quit(0)

func _wall(pos: Vector3, size: Vector3, yaw: float) -> void:
	_append(wood, imported["Wall_UnevenBrick_Window_Thin_Round.obj"], _fit(imported["Wall_UnevenBrick_Window_Thin_Round.obj"], size, pos, yaw), Color(0.69, 0.67, 0.60))

func _beam(pos: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	_append(books, source, Transform3D(Basis.IDENTITY, pos), Color(0.22, 0.14, 0.09))

func _append_west_roof(source: ArrayMesh, transform: Transform3D) -> void:
	var retained := SurfaceTool.new()
	retained.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := source.get_faces()
	for offset in range(0, faces.size(), 3):
		var centre := transform * ((faces[offset] + faces[offset + 1] + faces[offset + 2]) / 3.0)
		if centre.x > -0.15:
			continue
		for index in range(3):
			retained.add_vertex(transform * faces[offset + index])
	retained.generate_normals()
	retained.index()
	_append(books, retained.commit(), Transform3D.IDENTITY, Color(0.30, 0.19, 0.13))

func _make_wheel() -> void:
	# The axle is perpendicular to the west wall; the rim stays outside masonry.
	# Moving this visual only leaves all existing route and wall collision intact.
	var centre := Vector3(-4.42, 1.55, 1.80)
	var alignment := Transform3D(Basis(Vector3.UP, PI / 2), centre)
	for depth in [-0.12, 0.12]:
		var rim := TorusMesh.new()
		rim.inner_radius = 1.29
		rim.outer_radius = 1.55
		rim.rings = 20
		rim.ring_segments = 6
		var source := ArrayMesh.new()
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rim.get_mesh_arrays())
		_append(books, source, alignment * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, depth)), Color(0.35, 0.24, 0.15))
	for index in range(8):
		var angle := index * TAU / 8
		var spoke := BoxMesh.new()
		spoke.size = Vector3(1.34, 0.12, 0.22)
		var source := ArrayMesh.new()
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, spoke.get_mesh_arrays())
		_append(books, source, alignment * Transform3D(Basis(Vector3.BACK, angle), Vector3(cos(angle), sin(angle), 0) * 0.67), Color(0.41, 0.29, 0.19))
	for index in range(16):
		var angle := index * TAU / 16
		var paddle := BoxMesh.new()
		paddle.size = Vector3(0.14, 0.37, 0.44)
		var source := ArrayMesh.new()
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, paddle.get_mesh_arrays())
		_append(books, source, alignment * Transform3D(Basis(Vector3.BACK, angle), Vector3(cos(angle), sin(angle), 0) * 1.43), Color(0.32, 0.22, 0.14))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.22
	hub.bottom_radius = 0.22
	hub.height = 0.78
	hub.radial_segments = 12
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, hub.get_mesh_arrays())
	_append(books, source, alignment * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.14)), Color(0.30, 0.29, 0.26))
