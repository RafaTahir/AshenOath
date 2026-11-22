extends Node

const ROOT := "res://assets_external/textures/runtime/"

const SURFACES := {
	"forest_ground": {"stem": "forest_ground", "scale": 0.28, "roughness": 0.88},
	"wet_mud": {"stem": "wet_mud", "scale": 0.26, "roughness": 0.82},
	"cobblestone": {"stem": "cobblestone", "scale": 0.34, "roughness": 0.84},
	"plaster": {"stem": "plaster", "scale": 0.42, "roughness": 0.91},
	"timber": {"stem": "timber", "scale": 0.55, "roughness": 0.86},
	"roof_tiles": {"stem": "roof_tiles", "scale": 0.62, "roughness": 0.82},
	"medieval_brick": {"stem": "medieval_brick", "scale": 0.48, "roughness": 0.89},
	# These roles reuse the compact PBR set where it is useful and otherwise
	# intentionally use authored procedural surface materials. They must never
	# silently resolve to a ground surface.
	"water": {"stem": "wet_mud", "scale": 0.18, "roughness": 0.38, "kind": "water", "wetness": 1.0},
	"foliage": {"stem": "forest_ground", "scale": 0.42, "roughness": 0.86, "kind": "foliage"},
	"metal": {"stem": "", "scale": 1.0, "roughness": 0.34, "kind": "procedural"},
	"blood": {"stem": "", "scale": 1.0, "roughness": 0.48, "kind": "procedural"},
	"ash": {"stem": "forest_ground", "scale": 0.32, "roughness": 0.95, "kind": "ash"},
	"emissive_window": {"stem": "", "scale": 1.0, "roughness": 0.30, "kind": "emissive"},
}

const PBR_SURFACE_IDS := ["forest_ground", "wet_mud", "cobblestone", "plaster", "timber", "roof_tiles", "medieval_brick"]

var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var fallback_material: StandardMaterial3D
var pending_textures: Dictionary = {}
var prewarm_failed := false

func prewarm_surfaces(surface_ids: Array, quality: String) -> void:
	for surface_id in surface_ids:
		var stem := str(surface_profile(str(surface_id)).get("stem", ""))
		if stem == "":
			continue
		var channels := ["albedo", "normal", "orm"] if quality == "quality" else ["albedo"]
		for channel in channels:
			var file_name := "%s_%s.jpg" % [stem, channel]
			if texture_cache.has(file_name) or pending_textures.has(file_name):
				continue
			var error := ResourceLoader.load_threaded_request(ROOT + file_name)
			if error != OK:
				prewarm_failed = true
				push_error("Material prewarm failed: " + file_name)
			else:
				pending_textures[file_name] = true

func poll_prewarm() -> Error:
	for file_name in pending_textures.keys():
		var path: String = ROOT + file_name
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			texture_cache[file_name] = texture
			prewarm_failed = prewarm_failed or texture == null
			pending_textures.erase(file_name)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			prewarm_failed = true
			pending_textures.erase(file_name)
	if prewarm_failed:
		return ERR_CANT_OPEN
	return OK if pending_textures.is_empty() else ERR_BUSY

static func make_tiled_box(size: Vector3, origin: Vector3, orientation: Basis = Basis.IDENTITY) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	# World-metre UVs keep neighboring horizontal surfaces aligned without
	# triplanar fragment sampling or per-instance material copies.
	for index in vertices.size():
		var point := orientation * vertices[index] + origin
		var normal := (orientation * normals[index]).abs()
		if normal.y > 0.5:
			uvs[index] = Vector2(point.x, point.z)
		elif normal.x > 0.5:
			uvs[index] = Vector2(point.z, -point.y)
		else:
			uvs[index] = Vector2(point.x, -point.y)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func make_organic_ground_patch(size: Vector3, origin: Vector3, orientation: Basis = Basis.IDENTITY) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(0, size.y * 0.5, 0)])
	var normals := PackedVector3Array([Vector3.UP])
	var uvs := PackedVector2Array([Vector2(origin.x, origin.z)])
	var indices := PackedInt32Array()
	const POINTS := 24
	for i in POINTS:
		var angle := TAU * i / POINTS
		var irregularity := 0.86 + 0.08 * sin(i * 2.37 + origin.x * 0.27 + origin.z * 0.33)
		var point := Vector3(cos(angle) * size.x * 0.5 * irregularity, size.y * 0.5, sin(angle) * size.z * 0.5 * irregularity)
		var world := orientation * point + origin
		vertices.append(point)
		normals.append(Vector3.UP)
		uvs.append(Vector2(world.x, world.z))
		indices.append_array(PackedInt32Array([0, 1 + i, 1 + (i + 1) % POINTS]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func make_forest_berm(size: Vector3, origin: Vector3) -> ArrayMesh:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	var sections := clampi(ceili(length / 1.4), 2, 28)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in sections:
		var rings: Array[PackedVector3Array] = []
		for slice in [index, index + 1]:
			var axis := length * (float(slice) / sections - 0.5)
			var height := size.y * (0.68 + 0.11 * sin(axis * 1.13 + origin.x + origin.z))
			var cross_section := PackedVector3Array([
				Vector3(axis, -size.y * 0.5, -depth * 0.5),
				Vector3(axis, height - size.y * 0.5, -depth * 0.12),
				Vector3(axis, height - size.y * 0.5, depth * 0.12),
				Vector3(axis, -size.y * 0.5, depth * 0.5),
			])
			if not along_x:
				for point in cross_section.size():
					var original := cross_section[point]
					cross_section[point] = Vector3(original.z, original.y, original.x)
			rings.append(cross_section)
		for side in 3:
			var hint := Vector3.UP if side == 1 else Vector3(0, 0.4, -1 if side == 0 else 1)
			if not along_x:
				hint = Vector3(hint.z, hint.y, hint.x)
			_berm_triangle(tool, rings[0][side], rings[1][side], rings[1][side + 1], origin, hint)
			_berm_triangle(tool, rings[0][side], rings[1][side + 1], rings[0][side + 1], origin, hint)
		if index == 0 or index == sections - 1:
			var ring := rings[0] if index == 0 else rings[1]
			var hint := Vector3(-1 if index == 0 else 1, 0, 0) if along_x else Vector3(0, 0, -1 if index == 0 else 1)
			_berm_triangle(tool, ring[0], ring[1], ring[2], origin, hint)
			_berm_triangle(tool, ring[0], ring[2], ring[3], origin, hint)
	return tool.commit()

static func _berm_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, origin: Vector3, hint: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.dot(hint) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a, b, c]:
		var world: Vector3 = point + origin
		tool.set_normal(normal)
		tool.set_uv(Vector2(world.x, world.z) if absf(normal.y) > 0.5 else Vector2(world.x if absf(normal.z) > 0.5 else world.z, -world.y))
		tool.add_vertex(point)

static func make_tiled_ground_patch(size: Vector3, origin: Vector3, orientation: Basis = Basis.IDENTITY) -> ArrayMesh:
	var columns := clampi(ceili(size.x / 1.6), 3, 28)
	var rows := clampi(ceili(size.z / 1.6), 3, 28)
	var edge_x := minf(0.38, size.x * 0.07)
	var edge_z := minf(0.38, size.z * 0.07)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rows + 1):
		var z := size.z * (float(row) / float(rows) - 0.5)
		for column in range(columns + 1):
			var x := size.x * (float(column) / float(columns) - 0.5)
			var phase := origin.x * 0.37 + origin.z * 0.23 + float(row) * 1.91 + float(column) * 2.43
			if column == 0:
				x += edge_x * (0.45 + 0.5 * sin(phase))
			elif column == columns:
				x -= edge_x * (0.45 + 0.5 * sin(phase))
			if row == 0:
				z += edge_z * (0.45 + 0.5 * cos(phase))
			elif row == rows:
				z -= edge_z * (0.45 + 0.5 * cos(phase))
			var point := Vector3(x, size.y * 0.5, z)
			var world_point := orientation * point + origin
			vertices.append(point)
			normals.append(Vector3.UP)
			uvs.append(Vector2(world_point.x, world_point.z))
	for row in range(rows):
		for column in range(columns):
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func get_fallback_material() -> StandardMaterial3D:
	if fallback_material != null:
		return fallback_material
	fallback_material = StandardMaterial3D.new()
	fallback_material.resource_name = "WorldMaterialFallback"
	fallback_material.albedo_color = Color(0.27, 0.25, 0.22)
	fallback_material.roughness = 0.92
	fallback_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return fallback_material

func get_material(surface_id: String, quality: String = "balanced", tint: Color = Color.WHITE, wetness: float = 0.0, triplanar: bool = true) -> StandardMaterial3D:
	var normalized := surface_id if SURFACES.has(surface_id) else "forest_ground"
	var normalized_quality := _normalize_quality(quality)
	var normalized_wetness := snappedf(clamp(wetness, 0.0, 1.0), 0.05)
	var key := "%s:%s:%s:%.2f:%s" % [normalized, normalized_quality, tint.to_html(), normalized_wetness, str(triplanar)]
	if material_cache.has(key):
		return material_cache[key]
	var profile: Dictionary = SURFACES[normalized]
	var stem := str(profile.stem)
	var kind := str(profile.get("kind", "pbr"))
	var material := StandardMaterial3D.new()
	material.resource_name = "World_%s_%s" % [normalized, normalized_quality]
	material.albedo_texture = _texture(stem, "albedo") if stem != "" else null
	# Intel/ANGLE pays a disproportionate fragment cost for triplanar normal and
	# packed ORM sampling. Balanced keeps the authored albedo at native 720p;
	# Quality retains the full PBR stack for stronger hardware.
	material.normal_enabled = normalized_quality == "quality" and stem != ""
	material.normal_texture = _texture(stem, "normal") if material.normal_enabled else null
	material.normal_scale = 0.78 if normalized_quality == "quality" else 0.55
	var orm := _texture(stem, "orm") if normalized_quality == "quality" and stem != "" else null
	material.roughness_texture = orm
	# An unused channel still changes Godot's generated shader key. Retain the
	# default for scalar roughness so flat and textured surfaces share variants.
	if orm != null:
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = normalized_quality == "quality"
	material.ao_texture = orm if material.ao_enabled else null
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = tint
	material.roughness = lerp(float(profile.roughness), 0.40, normalized_wetness)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if normalized_quality != "potato" else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var use_triplanar := triplanar and normalized_quality == "quality"
	material.uv1_triplanar = use_triplanar and kind != "procedural" and kind != "emissive"
	material.uv1_world_triplanar = material.uv1_triplanar
	material.uv1_scale = Vector3.ONE * float(profile.scale)
	_apply_surface_flags(material, kind, normalized, normalized_quality)
	material_cache[key] = material
	return material

func cache_stats() -> Dictionary:
	return {
		"materials": material_cache.size(),
		"textures": texture_cache.size(),
		"has_fallback": fallback_material != null,
	}

func get_grass_material(quality: String = "balanced") -> StandardMaterial3D:
	var normalized_quality := _normalize_quality(quality)
	var key := "grass:%s" % normalized_quality
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.resource_name = "World_grass_%s" % normalized_quality
	material.albedo_texture = _texture_file("grass_tuft.png")
	material.albedo_color = Color(0.72, 0.80, 0.67)
	material.roughness = 0.88
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if normalized_quality != "potato" else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material_cache[key] = material
	return material

func surface_ids() -> Array[String]:
	var result: Array[String] = []
	for surface_id in SURFACES:
		result.append(str(surface_id))
	result.sort()
	return result

func pbr_surface_ids() -> Array[String]:
	var result: Array[String] = []
	for surface_id in PBR_SURFACE_IDS:
		result.append(str(surface_id))
	return result

func surface_profile(surface_id: String) -> Dictionary:
	var normalized := surface_id if SURFACES.has(surface_id) else "forest_ground"
	return SURFACES[normalized].duplicate(true)

func has_surface(surface_id: String) -> bool:
	return SURFACES.has(surface_id)

func is_procedural_surface(surface_id: String) -> bool:
	return str(surface_profile(surface_id).get("kind", "pbr")) in ["procedural", "emissive"]

func material_contract(surface_id: String, quality: String = "balanced") -> Dictionary:
	var normalized := surface_id if SURFACES.has(surface_id) else "forest_ground"
	var profile := surface_profile(normalized)
	var stem := str(profile.get("stem", ""))
	return {
		"id": normalized,
		"kind": str(profile.get("kind", "pbr")),
		"source_stem": stem,
		"quality": _normalize_quality(quality),
		"has_albedo": stem != "" and _texture(stem, "albedo") != null,
		"has_normal": stem != "" and _texture(stem, "normal") != null,
		"has_orm": stem != "" and _texture(stem, "orm") != null,
		"cache_key_count": _count_material_keys(normalized),
	}

func has_complete_texture_set(surface_id: String) -> bool:
	if not SURFACES.has(surface_id):
		return false
	var stem := str(SURFACES[surface_id].get("stem", ""))
	if stem == "":
		return false
	return _texture(stem, "albedo") != null and _texture(stem, "normal") != null and _texture(stem, "orm") != null

func clear_cache() -> void:
	# Threaded requests retain loader state until consumed, even when already
	# complete. Cache retirement must also cover shutdown before the first poll.
	for file_name in pending_textures:
		ResourceLoader.load_threaded_get(ROOT + file_name)
	pending_textures.clear()
	prewarm_failed = false
	material_cache.clear()
	texture_cache.clear()
	fallback_material = null

func _normalize_quality(quality: String) -> String:
	var normalized := quality.to_lower()
	return normalized if normalized in ["potato", "balanced", "quality"] else "balanced"

func _texture(stem: String, channel: String) -> Texture2D:
	return _texture_file("%s_%s.jpg" % [stem, channel])

func _texture_file(file_name: String) -> Texture2D:
	if texture_cache.has(file_name):
		return texture_cache[file_name]
	var path := ROOT + file_name
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
	texture_cache[file_name] = texture
	return texture

func _apply_surface_flags(material: StandardMaterial3D, kind: String, surface_id: String, quality: String) -> void:
	if kind == "water":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_set_alpha(material, 0.82 if quality != "potato" else 0.90)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	elif kind == "foliage":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.38
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif kind == "procedural":
		var procedural_colors := {
			"metal": Color("6c736d"),
			"blood": Color("5a1717"),
		}
		material.albedo_color = procedural_colors.get(surface_id, Color("504a43"))
		material.metallic = 0.72 if surface_id == "metal" else 0.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	elif kind == "emissive":
		material.albedo_color = Color("f0ad58")
		material.emission_enabled = true
		material.emission = Color("ff9e3b")
		material.emission_energy_multiplier = 0.85
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_set_alpha(material, 0.94)

func _count_material_keys(surface_id: String) -> int:
	var count := 0
	for key in material_cache:
		if str(key).begins_with(surface_id + ":"):
			count += 1
	return count

func _set_alpha(material: StandardMaterial3D, alpha: float) -> void:
	var color := material.albedo_color
	color.a = alpha
	material.albedo_color = color
