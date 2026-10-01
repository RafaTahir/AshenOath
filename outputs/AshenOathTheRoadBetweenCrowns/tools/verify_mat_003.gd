extends SceneTree

const MaterialLibrary = preload("res://scripts/world_material_library.gd")

const EXPECTED_SURFACES := [
	"forest_ground", "wet_mud", "cobblestone", "plaster", "timber", "roof_tiles", "medieval_brick",
	"water", "foliage", "metal", "blood", "ash", "emissive_window",
]
const QUALITIES := ["potato", "balanced", "quality"]

var failures: Array[String] = []

func _verify_world_uvs() -> void:
	for origin in [Vector3.ZERO, Vector3(0, 0, 34)]:
		var size := Vector3(5.2, 0.05, 34)
		var mesh := MaterialLibrary.make_tiled_box(size, origin)
		_assert(mesh.get_aabb().size.is_equal_approx(size), "Tiled box changed visible extents")
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for index in vertices.size():
			if normals[index].y > 0.5:
				var world: Vector3 = vertices[index] + origin
				_assert(uvs[index].is_equal_approx(Vector2(world.x, world.z)), "Ground UVs stretch or lose world alignment")
		var patch := MaterialLibrary.make_tiled_ground_patch(size, origin)
		var patch_arrays := patch.surface_get_arrays(0)
		var patch_vertices: PackedVector3Array = patch_arrays[Mesh.ARRAY_VERTEX]
		var patch_uvs: PackedVector2Array = patch_arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = patch_arrays[Mesh.ARRAY_INDEX]
		_assert(indices.size() >= 3, "Ground patch has no visible triangles")
		for index in patch_vertices.size():
			_assert(is_equal_approx(patch_vertices[index].y, size.y * 0.5), "Ground patch sank below the box top")
			var world: Vector3 = patch_vertices[index] + origin
			_assert(patch_uvs[index].is_equal_approx(Vector2(world.x, world.z)), "Ground patch lost world-aligned UVs")
		if indices.size() >= 3:
			var edge_a: Vector3 = patch_vertices[indices[1]] - patch_vertices[indices[0]]
			var edge_b: Vector3 = patch_vertices[indices[2]] - patch_vertices[indices[0]]
			_assert(edge_a.cross(edge_b).y < 0.0, "Ground patch has the wrong front-face winding")

func _initialize() -> void:
	_verify_world_uvs()
	_verify_lightweight_dependencies()
	_verify_world_mipmaps()
	if DisplayServer.get_name().to_lower() != "headless":
		await _verify_scalar_roughness_pixels()
	var library = MaterialLibrary.new()
	root.add_child(library)
	await process_frame

	for surface_id in EXPECTED_SURFACES:
		_assert(library.has_surface(surface_id), "%s is not registered" % surface_id)
		var profile: Dictionary = library.surface_profile(surface_id)
		var kind := str(profile.get("kind", "pbr"))
		_assert(float(profile.get("scale", 0.0)) > 0.0, "%s has no valid UV scale" % surface_id)
		if kind == "pbr":
			_assert(library.has_complete_texture_set(surface_id), "%s lacks a complete PBR texture set" % surface_id)
		else:
			_assert(str(profile.get("stem", "")) != "" or kind in ["procedural", "emissive"], "%s has no source or procedural contract" % surface_id)
		for quality in QUALITIES:
			var material: StandardMaterial3D = library.get_material(surface_id, quality)
			_assert(material != null, "%s/%s did not create a material" % [surface_id, quality])
			if material == null:
				continue
			if quality != "quality":
				_assert(material.roughness_texture == null, "Lightweight material unexpectedly uses ORM")
				_assert(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED, "Scalar roughness creates an unnecessary shader variant")
			elif str(profile.get("stem", "")) != "":
				_assert(material.roughness_texture != null and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN, "Quality lost packed roughness")
			var contract: Dictionary = library.material_contract(surface_id, quality)
			_assert(str(contract.get("id", "")) == surface_id, "%s contract normalized incorrectly" % surface_id)
			if kind == "pbr":
				_assert(bool(contract.get("has_albedo", false)), "%s/%s contract has no albedo" % [surface_id, quality])
				_assert(bool(contract.get("has_normal", false)), "%s/%s contract has no normal" % [surface_id, quality])
				_assert(bool(contract.get("has_orm", false)), "%s/%s contract has no ORM" % [surface_id, quality])
			_assert(material.albedo_color != Color.WHITE or material.albedo_texture != null, "%s/%s resolved to a blank material" % [surface_id, quality])

	var water := library.get_material("water", "balanced")
	_assert(water.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Water is not alpha blended")
	_assert(water.cull_mode == BaseMaterial3D.CULL_DISABLED, "Water is single-sided")
	var foliage := library.get_material("foliage", "balanced")
	_assert(foliage.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "Foliage is not alpha-scissored")
	var window := library.get_material("emissive_window", "balanced")
	_assert(window.emission_enabled, "Window role has no emission")
	_assert(window.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Window emission is not lightweight")
	var metal := library.get_material("metal", "balanced")
	_assert(metal.metallic > 0.5, "Metal role is not metallic")
	var blood := library.get_material("blood", "balanced")
	_assert(blood.albedo_color != library.get_material("forest_ground", "balanced").albedo_color, "Blood reused ground color")
	var fallback := library.get_material("unknown_surface", "invalid")
	_assert(fallback == library.get_material("forest_ground", "balanced"), "Unknown surface fallback is unstable")
	var before: int = int(library.cache_stats().materials)
	for surface_id in EXPECTED_SURFACES:
		for quality in QUALITIES:
			library.get_material(surface_id, quality)
	_assert(library.cache_stats().materials == before, "Material cache grew on repeated lookup")
	_assert(library.cache_stats().materials >= EXPECTED_SURFACES.size() * QUALITIES.size(), "Material cache is incomplete")

	if is_instance_valid(library):
		library.free()
	if failures.is_empty():
		print("MAT-003 VERIFIER: PASS - unified PBR and procedural surface contract")
		quit(0)
		return
	print("MAT-003 VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		print("- %s" % failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _verify_lightweight_dependencies() -> void:
	var library = MaterialLibrary.new()
	for quality in ["balanced", "potato"]:
		for surface_id in EXPECTED_SURFACES:
			library.get_material(surface_id, quality)
	for path in library.texture_cache:
		_assert(not str(path).contains("_orm") and not str(path).contains("_normal"), "Lightweight tier loaded unused PBR texture: %s" % path)
	library.free()

func _verify_world_mipmaps() -> void:
	for surface_id in MaterialLibrary.PBR_SURFACE_IDS:
		for channel in ["albedo", "normal", "orm"]:
			var path := "%s%s_%s.jpg" % [MaterialLibrary.ROOT, surface_id, channel]
			var texture := load(path) as Texture2D
			_assert(texture != null, "Missing world texture: " + path)
			if texture == null:
				continue
			var image := texture.get_image()
			_assert(image != null and image.has_mipmaps(), "World texture lacks imported mip chain: " + path)
			var source := Image.new()
			_assert(source.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "World texture source cannot decode: " + path)
			var settings := ConfigFile.new()
			_assert(settings.load(path + ".import") == OK, "World texture import policy is missing: " + path)
			var limit := int(settings.get_value("params", "process/size_limit", 0))
			var expected := source.get_size()
			if limit > 0 and maxi(expected.x, expected.y) > limit:
				expected = Vector2i(Vector2(expected) * float(limit) / maxi(expected.x, expected.y))
			_assert(Vector2i(texture.get_size()) == expected, "World texture dimensions differ from its authored import policy: " + path)

func _verify_scalar_roughness_pixels() -> void:
	var library = MaterialLibrary.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 2)
	viewport.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -30, 0)
	viewport.add_child(light)
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	viewport.add_child(sphere)
	var optimized: StandardMaterial3D = library.get_material("plaster", "balanced", Color(0.7, 0.6, 0.5))
	var previous := optimized.duplicate() as StandardMaterial3D
	previous.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	sphere.material_override = previous
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	sphere.material_override = optimized
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	_assert(before.get_data() == after.get_data(), "Scalar roughness channel change altered rendered pixels")
	_assert(after.get_pixel(64, 64) != after.get_pixel(0, 0), "Material comparison rendered no visible sphere")
	print("MAT-003 SCALAR ROUGHNESS PIXELS: compared 128x128 before/after (not world visual approval)")
	viewport.queue_free()
	library.free()
	await process_frame
