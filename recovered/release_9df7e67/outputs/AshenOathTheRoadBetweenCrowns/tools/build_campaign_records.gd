extends "res://tools/build_record_archive.gd"

const RECORD_SOURCES := ["BookStand.obj", "Book_7.obj", "Book_5.obj", "Scroll_1.obj", "Scroll_2.obj", "Crate_Wooden.obj"]
const RECORD_OUTPUT := "res://assets_external/environment/props/CampaignRecord_%s_Authored.res"

func _initialize() -> void:
	for file in RECORD_SOURCES:
		var source := load(ROOT + file) as ArrayMesh
		if source == null or source.get_surface_count() == 0:
			push_error("Missing licensed record prop: " + file)
			quit(1)
			return
		imported[file] = source
	for identity in ["register_rook", "register_mira", "mill_pending", "mill_preserved", "mill_burned", "mill_exposed"]:
		wood = SurfaceTool.new()
		books = SurfaceTool.new()
		wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		books.begin(Mesh.PRIMITIVE_TRIANGLES)
		var support_height := 1.05
		var ground := 0.48 if identity.begins_with("mill_") else (0.40 if identity == "register_rook" else 0.045)
		if identity == "register_mira":
			support_height = 0.64
			_record_part(wood, "Crate_Wooden.obj", Vector3(0.80, support_height, 0.66), Vector3(0, ground, 0), 0, Color(0.32, 0.28, 0.20))
		else:
			_record_part(wood, "BookStand.obj", Vector3(0.90, support_height, 0.72), Vector3(0, ground, 0), 180, Color(0.18, 0.12, 0.075) if identity == "register_rook" else Color(0.40, 0.25, 0.12))
		var top := ground + support_height
		var burned: bool = identity in ["register_rook", "mill_burned"]
		var cover := Color(0.09, 0.055, 0.035) if burned else Color(0.30, 0.16, 0.08)
		_record_part(books, "Book_7.obj", Vector3(0.62, 0.105, 0.43), Vector3(-0.04, top, 0.06), 8, cover)
		if identity == "mill_preserved":
			_record_part(books, "Book_5.obj", Vector3(0.56, 0.07, 0.37), Vector3(0, top + 0.105, 0.03), -6, Color(0.29, 0.35, 0.29))
		else:
			var paper := Color(0.18, 0.12, 0.07) if burned else Color(0.74, 0.66, 0.47)
			if identity == "register_rook":
				paper = Color(0.53, 0.45, 0.30)
			_record_part(books, "Scroll_1.obj", Vector3(0.59, 0.07, 0.44), Vector3(0.08, top + 0.115, -0.01), -12, paper)
		if identity == "mill_exposed":
			# Copies rest on a wider clerk's tray, not an unsupported wall rectangle.
			_record_part(wood, "Crate_Wooden.obj", Vector3(0.66, 0.59, 0.58), Vector3(0.79, ground, 0.02), -7, Color(0.37, 0.25, 0.13))
			_record_part(books, "Scroll_2.obj", Vector3(0.56, 0.09, 0.41), Vector3(0.79, ground + 0.59, 0.02), 16, Color(0.79, 0.71, 0.53))
			_record_part(books, "Scroll_1.obj", Vector3(0.46, 0.08, 0.36), Vector3(0.69, ground + 0.68, 0.01), -22, Color(0.64, 0.59, 0.43))
		wood.index()
		books.index()
		var result := wood.commit()
		books.commit(result)
		for surface in result.get_surface_count():
			result.surface_set_name(surface, "supported_timber" if surface == 0 else "testimony_pages")
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.roughness = 0.91
			result.surface_set_material(surface, material)
		result.set_meta("source_pack", "Quaternius Fantasy Props MegaKit")
		result.set_meta("license", "CC0 1.0")
		result.set_meta("record_identity", identity)
		result.set_meta("ground_offset", ground)
		var hashes := {}
		for source in RECORD_SOURCES:
			hashes[ROOT + source] = FileAccess.get_sha256(ROOT + source)
		result.set_meta("source_sha256", hashes)
		var output := RECORD_OUTPUT % identity
		if ResourceSaver.save(result, output, ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Failed to bake record: " + identity)
			quit(1)
			return
		print("CAMPAIGN RECORD BAKE: %s triangles=%d bytes=%d" % [identity, result.get_faces().size() / 3, FileAccess.get_file_as_bytes(output).size()])
	quit(0)

func _record_part(surface: SurfaceTool, file: String, size: Vector3, position: Vector3, yaw: float, color: Color) -> void:
	_append(surface, imported[file], _fit(imported[file], size, position, yaw), color)
