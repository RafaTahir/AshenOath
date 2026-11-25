extends SceneTree
## Source-isolated material ownership/PBR regression; no world or save access.
const Palette = preload("res://scripts/views/monster_material_view.gd")
const Bindings = preload("res://scripts/character_material_bindings.gd")
const MaterialBudget = preload("res://scripts/views/character_material_budget_view.gd")
var errors: Array[String] = []
var rows: Array[Dictionary] = []
var body_pixels: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func _run() -> void:
	_verify_universal_budget()
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Palette.PROFILE_PATH)).assets
	var known_materials: Dictionary = {}
	for asset_id: String in profiles:
		var profile: Dictionary = profiles[asset_id]
		var source := str(profile.source)
		var packed := load(source) as PackedScene
		_check(packed != null, asset_id + ": source load")
		if packed == null:
			continue
		var actor := packed.instantiate() as Node3D
		root.add_child(actor)
		var originals: Array[Dictionary] = []
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				_check(material != null, asset_id + ": original PBR")
				if material == null:
					continue
				originals.append({"mesh": mesh, "surface": surface, "material": material,
					"albedo": material.albedo_color, "atlas": material.albedo_texture, "geometry": mesh.mesh, "skin": mesh.skin,
					"transform": mesh.transform})
		_check(Palette.prepare(actor, source), asset_id + ": palette binds")
		_check(Bindings.capture(actor, source), asset_id + ": binding capture")
		var variants: Array[Material] = []
		for entry in originals:
			var mesh := entry.mesh as MeshInstance3D
			var native := entry.material as BaseMaterial3D
			if float(profile.materials[native.resource_name].strength) == 0.0:
				var retained := mesh.get_active_material(int(entry.surface))
				_check(retained == native, asset_id + ": zero-strength surface preserves the complete native material")
				_check(mesh.mesh == entry.geometry and mesh.skin == entry.skin and mesh.transform == entry.transform, asset_id + ": retained native surface geometry")
				known_materials[asset_id + "/" + native.resource_name] = true
				variants.append(retained)
				continue
			var material := mesh.get_active_material(int(entry.surface)) as ShaderMaterial
			_check(material != null, asset_id + ": shader variant " + native.resource_name)
			if material == null:
				continue
			variants.append(material)
			known_materials[asset_id + "/" + native.resource_name] = true
			_check(mesh.mesh == entry.geometry and mesh.skin == entry.skin and mesh.transform == entry.transform, asset_id + ": unchanged mesh/skin/frame")
			_check(native.albedo_color == entry.albedo, asset_id + ": immutable shared native")
			_check(native.albedo_texture == entry.atlas and material.native_material == native, asset_id + ": original atlas and native material provenance")
			var recipe: Dictionary = profile.materials[native.resource_name]
			var active_atlas := Bindings.texture_for(material)
			_check((material.get_shader_parameter("hand_painted_albedo") == true) == recipe.has("authored_albedo"), asset_id + ": authored body grade bypass")
			if recipe.has("authored_albedo"):
				_verify_body_bake(asset_id, str(recipe.authored_albedo), active_atlas, native.albedo_texture)
			else:
				_check(active_atlas == native.albedo_texture, asset_id + ": retained atlas")
			_check(material.get_shader_parameter("authored_uv_scale") == Vector2(native.uv1_scale.x, native.uv1_scale.y), asset_id + ": retained native UV scale")
			_check(material.get_shader_parameter("authored_uv_offset") == Vector2(native.uv1_offset.x, native.uv1_offset.y), asset_id + ": retained native UV offset")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_roughness")), native.roughness), asset_id + ": retained roughness factor")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_metallic")), native.metallic), asset_id + ": retained metallic factor")
			_check(material.get_shader_parameter("authored_tint") == native.albedo_color, asset_id + ": retained alpha/tint")
			_check(material.get_shader_parameter("authored_normal") == native.normal_texture, asset_id + ": retained normal texture")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_normal_scale")), native.normal_scale), asset_id + ": retained normal scale")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_specular")), native.metallic_specular), asset_id + ": retained specular/IOR response")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_clearcoat")), native.clearcoat if native.clearcoat_enabled else 0.0), asset_id + ": retained wet shell clearcoat")
			_check(is_equal_approx(float(material.get_shader_parameter("authored_clearcoat_roughness")), native.clearcoat_roughness), asset_id + ": retained clearcoat roughness")
			var expected_shader: Shader = Palette.COATED if native.clearcoat_enabled else Palette.OPAQUE
			_check(material.shader == expected_shader, asset_id + ": native transparency/clearcoat pipeline")
			if native is StandardMaterial3D:
				_check(material.get_shader_parameter("authored_roughness_map") == native.roughness_texture, asset_id + ": retained roughness map")
				_check(material.get_shader_parameter("authored_metallic_map") == native.metallic_texture, asset_id + ": retained metallic map")
			elif native is ORMMaterial3D:
				_check(material.get_shader_parameter("authored_roughness_map") == native.orm_texture, asset_id + ": retained ORM")
		_check(Palette.prepare(actor, source), asset_id + ": idempotent rebind")
		for index in originals.size():
			if index < variants.size():
				_check(originals[index].mesh.get_active_material(int(originals[index].surface)) == variants[index], asset_id + ": no repeated material allocations")
		if not originals.is_empty():
			var first: Dictionary = originals[0]
			first.mesh.material_override = null
			first.mesh.set_surface_override_material(int(first.surface), null)
			_check(Palette.prepare(actor, source), asset_id + ": revision metadata cannot hide restored native surface")
			if not variants.is_empty():
				_check(first.mesh.get_active_material(int(first.surface)) == variants[0], asset_id + ": palette reclaims restored native atlas")
			# A working native atlas remains authoritative; deliberately remove it
			# to exercise the existing owner's actual recovery path.
			var broken := StandardMaterial3D.new()
			first.mesh.material_override = broken
			_check(Bindings.restore(actor), asset_id + ": ownership restoration")
			if not variants.is_empty():
				_check(first.mesh.get_active_material(int(first.surface)) == variants[0], asset_id + ": restore pigment variant")
		rows.append({"asset": asset_id, "surfaces": originals.size(), "source": source})
		actor.free()
	_check(profiles.size() == 20 and rows.size() == 20, "all twenty native species")
	_check(known_materials.size() == 43, "all 43 authored material identities")
	_check(body_pixels.size() == 3 and body_pixels.has("M01") and body_pixels.has("M19") and body_pixels.has("M20"), "three distinct Wychwood body bakes")
	Palette.clear_material_cache()
	_check(Palette._variants.is_empty(), "streamed-zone material cache releases deferred texture references")
	var result := {"kind": "monster_material_runtime_contract", "passed": errors.is_empty(),
		"asset_count": rows.size(), "material_identities": known_materials.size(),
		"world_loaded": false, "visual_acceptance": false, "assets": rows, "errors": errors}
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)

func _verify_body_bake(id: String, path: String, texture: Texture2D, native: Texture2D) -> void:
	if texture == null or texture == native or texture.resource_path != path or texture != load(path):
		_check(false, id + ": wrong active authored body texture: " + path)
		return
	if body_pixels.has(id): return
	var image := texture.get_image()
	if image == null or image.is_empty() or (image.is_compressed() and image.decompress() != OK):
		_check(false, id + ": cannot decode authored body pixels")
		return
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	for prior: String in body_pixels:
		_check(body_pixels[prior] != pixels, id + ": decoded body pixels duplicate " + prior)
	body_pixels[id] = pixels

func _verify_universal_budget() -> void:
	var native := StandardMaterial3D.new()
	native.normal_enabled = true
	native.normal_texture = GradientTexture2D.new()
	native.albedo_texture = GradientTexture2D.new()
	native.albedo_color = Color(0.7, 0.5, 0.3)
	var geometry := CylinderMesh.new()
	geometry.material = native
	var mesh := MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.skin = Skin.new()
	var original_skin := mesh.skin
	var bounds := geometry.get_aabb()
	var changed := MaterialBudget.collapse_normals([mesh])
	var replacement := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_check(changed == [mesh], "retained Universal budget reports its changed mesh")
	_check(replacement != native and not replacement.normal_enabled and replacement.normal_texture == null, "retained Universal budget removes only redundant normals")
	_check(native.normal_enabled and native.normal_texture != null, "retained Universal source remains immutable")
	_check(replacement.albedo_texture == native.albedo_texture and replacement.albedo_color == native.albedo_color, "retained Universal atlas/tint")
	_check(mesh.skin == original_skin and mesh.mesh.get_aabb() == bounds, "retained Universal skin/geometry bounds")
	mesh.free()
