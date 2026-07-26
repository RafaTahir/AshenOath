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
}

var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var fallback_material: StandardMaterial3D

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
	var material := StandardMaterial3D.new()
	material.resource_name = "World_%s_%s" % [normalized, normalized_quality]
	material.albedo_texture = _texture(stem, "albedo")
	# Intel/ANGLE pays a disproportionate fragment cost for triplanar normal and
	# packed ORM sampling. Balanced keeps the authored albedo at native 720p;
	# Quality retains the full PBR stack for stronger hardware.
	material.normal_enabled = normalized_quality == "quality"
	material.normal_texture = _texture(stem, "normal") if material.normal_enabled else null
	material.normal_scale = 0.78 if normalized_quality == "quality" else 0.55
	var orm := _texture(stem, "orm")
	material.roughness_texture = orm if normalized_quality == "quality" else null
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = normalized_quality == "quality"
	material.ao_texture = orm if material.ao_enabled else null
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = tint
	material.roughness = lerp(float(profile.roughness), 0.40, normalized_wetness)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if normalized_quality != "potato" else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var use_triplanar := triplanar and normalized_quality == "quality"
	material.uv1_triplanar = use_triplanar
	material.uv1_world_triplanar = use_triplanar
	material.uv1_scale = Vector3.ONE * float(profile.scale)
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

func has_complete_texture_set(surface_id: String) -> bool:
	if not SURFACES.has(surface_id):
		return false
	var stem := str(SURFACES[surface_id].stem)
	return _texture(stem, "albedo") != null and _texture(stem, "normal") != null and _texture(stem, "orm") != null

func clear_cache() -> void:
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
