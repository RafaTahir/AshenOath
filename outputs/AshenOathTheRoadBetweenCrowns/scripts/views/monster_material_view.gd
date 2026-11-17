extends RefCounted
## One immutable material variant per native surface. No process or extra pass.
const PROFILE_PATH := "res://data/monster_material_profiles.json"
const OPAQUE := preload("res://shaders/monster_pigment.gdshader")
const TRANSLUCENT := preload("res://shaders/monster_pigment_translucent.gdshader")
const COATED := preload("res://shaders/monster_pigment_clearcoat.gdshader")
const PigmentMaterial := preload("res://scripts/views/monster_pigment_material.gd")
static var _profiles: Dictionary = {}
static var _revision := ""
static var _loaded := false
static var _variants: Dictionary = {}

static func prepare(root: Node3D, source: String) -> bool:
	if not source.begins_with("res://assets_external/design_pack_v1/creatures/"):
		return true
	_load_profiles()
	var profile: Dictionary = _profiles.get(source, {})
	if profile.is_empty():
		push_error("Native creature has no material profile: " + source)
		return false
	var replacements: Array[Dictionary] = []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or str(mesh.name).to_lower().contains("shadow"):
			continue
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			if original is PigmentMaterial:
				original = original.native_material
			if not original is BaseMaterial3D:
				push_error("Creature palette requires a native PBR surface: " + source)
				return false
			var native := original as BaseMaterial3D
			var name := native.resource_name
			if not profile.materials.has(name) or native.albedo_texture == null:
				push_error("Creature palette has no textured surface recipe: %s [%s]" % [source, name])
				return false
			var variant := _variant(native, profile.materials[name], source)
			if variant == null:
				return false
			replacements.append({"mesh": mesh, "surface": surface, "material": variant})
	if replacements.is_empty():
		push_error("Creature palette has no native surfaces: " + source)
		return false
	for replacement in replacements:
		var mesh := replacement.mesh as MeshInstance3D
		mesh.material_override = null
		mesh.set_surface_override_material(int(replacement.surface), replacement.material)
	return true

static func clear_material_cache() -> void:
	# Live instances keep their own references. Released zones must not retain
	# every deferred creature atlas through this shared variant cache.
	_variants.clear()

static func _load_profiles() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not data is Dictionary or int(data.get("schema_version", 0)) != 1:
		push_error("Creature material profile schema is invalid")
		return
	_revision = str(data.palette_revision)
	for raw: Dictionary in data.assets.values():
		_profiles[str(raw.source)] = raw

static func _variant(native: BaseMaterial3D, recipe: Dictionary, source: String) -> ShaderMaterial:
	var key := var_to_str([native, source, recipe, _revision])
	if _variants.has(key):
		return _variants[key]
	# The audited source contract is deliberately narrow. Do not silently lose
	# new alpha/culling/UV/PBR features if future authoring changes the sources.
	if native.cull_mode != BaseMaterial3D.CULL_DISABLED or native.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA]:
		push_error("Unsupported native creature surface mode: " + native.resource_name)
		return null
	if native.ao_enabled or native.emission_enabled or native.uv1_triplanar or native.clearcoat_texture != null:
		push_error("Unsupported native creature PBR feature: " + native.resource_name)
		return null
	if native.clearcoat_enabled and native.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		push_error("Unsupported combined clearcoat/transparency: " + native.resource_name)
		return null
	var material := PigmentMaterial.new()
	material.resource_name = native.resource_name
	material.shader = TRANSLUCENT if native.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA else (COATED if native.clearcoat_enabled else OPAQUE)
	material.render_priority = native.render_priority
	material.native_material = native
	material.source_path = source
	material.palette_revision = _revision
	material.set_shader_parameter("authored_atlas", native.albedo_texture)
	material.set_shader_parameter("authored_tint", native.albedo_color)
	material.set_shader_parameter("vertex_color_enabled", native.vertex_color_use_as_albedo)
	material.set_shader_parameter("authored_uv_scale", Vector2(native.uv1_scale.x, native.uv1_scale.y))
	material.set_shader_parameter("authored_uv_offset", Vector2(native.uv1_offset.x, native.uv1_offset.y))
	for name in ["neutral_color", "warm_color", "cool_color"]:
		material.set_shader_parameter(name, Color(str(recipe[name])))
	material.set_shader_parameter("pigment_strength", float(recipe.strength))
	for name in ["chroma_preservation", "highlight_preservation", "value_gain"]:
		material.set_shader_parameter(name, float(recipe[name]))
	material.set_shader_parameter("atlas_regions", str(recipe.method) == "atlas_regions")
	material.set_shader_parameter("normal_enabled", native.normal_enabled and native.normal_texture != null)
	material.set_shader_parameter("authored_normal", native.normal_texture)
	material.set_shader_parameter("authored_normal_scale", native.normal_scale)
	material.set_shader_parameter("authored_roughness", native.roughness)
	material.set_shader_parameter("authored_metallic", native.metallic)
	material.set_shader_parameter("authored_specular", native.metallic_specular)
	material.set_shader_parameter("authored_clearcoat", native.clearcoat if native.clearcoat_enabled else 0.0)
	material.set_shader_parameter("authored_clearcoat_roughness", native.clearcoat_roughness)
	if native is ORMMaterial3D:
		material.set_shader_parameter("authored_roughness_map", native.orm_texture)
		material.set_shader_parameter("authored_metallic_map", native.orm_texture)
		material.set_shader_parameter("roughness_textured", native.orm_texture != null)
		material.set_shader_parameter("metallic_textured", native.orm_texture != null)
	elif native is StandardMaterial3D:
		material.set_shader_parameter("authored_roughness_map", native.roughness_texture)
		material.set_shader_parameter("authored_metallic_map", native.metallic_texture)
		material.set_shader_parameter("roughness_textured", native.roughness_texture != null)
		material.set_shader_parameter("metallic_textured", native.metallic_texture != null)
		material.set_shader_parameter("roughness_channel", _channel(native.roughness_texture_channel))
		material.set_shader_parameter("metallic_channel", _channel(native.metallic_texture_channel))
	_variants[key] = material
	return material

static func _channel(index: int) -> Vector4:
	match index:
		BaseMaterial3D.TEXTURE_CHANNEL_RED: return Vector4(1, 0, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN: return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE: return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: return Vector4(0, 0, 0, 1)
		_: return Vector4(0.2126, 0.7152, 0.0722, 0)
