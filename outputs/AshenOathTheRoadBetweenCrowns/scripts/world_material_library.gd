extends Node

const ROOT := "res://assets_external/textures/runtime/"

const SURFACES := {
	"forest_ground": "forest_ground",
	"wet_mud": "wet_mud",
	"cobblestone": "cobblestone",
	"plaster": "plaster",
	"timber": "timber",
	"roof_tiles": "roof_tiles",
	"medieval_brick": "medieval_brick",
}

var material_cache: Dictionary = {}

func get_material(surface_id: String, quality: String = "balanced", tint: Color = Color.WHITE, wetness: float = 0.0, triplanar: bool = true) -> StandardMaterial3D:
	var normalized := surface_id if SURFACES.has(surface_id) else "forest_ground"
	var key := "%s:%s:%s:%.2f:%s" % [normalized, quality, tint.to_html(), wetness, str(triplanar)]
	if material_cache.has(key):
		return material_cache[key]
	var stem: String = SURFACES[normalized]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ROOT + stem + "_albedo.jpg") as Texture2D
	material.normal_enabled = quality == "quality"
	material.normal_texture = load(ROOT + stem + "_normal.jpg") as Texture2D
	material.normal_scale = 0.72 if quality != "potato" else 0.42
	var orm := load(ROOT + stem + "_orm.jpg") as Texture2D
	material.roughness_texture = orm if quality == "quality" else null
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = quality == "quality"
	material.ao_texture = orm
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = tint
	material.roughness = lerp(0.90, 0.42, clamp(wetness, 0.0, 1.0))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var use_triplanar := triplanar and quality == "quality"
	material.uv1_triplanar = use_triplanar
	material.uv1_world_triplanar = use_triplanar
	material.uv1_scale = Vector3.ONE * _surface_scale(normalized)
	material_cache[key] = material
	return material

func get_grass_material(quality: String = "balanced") -> StandardMaterial3D:
	var key := "grass:%s" % quality
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ROOT + "grass_tuft.png") as Texture2D
	material.albedo_color = Color(0.72, 0.80, 0.67)
	material.roughness = 0.88
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material_cache[key] = material
	return material

func _surface_scale(surface_id: String) -> float:
	match surface_id:
		"plaster": return 0.42
		"timber": return 0.55
		"roof_tiles": return 0.62
		"medieval_brick": return 0.48
		"cobblestone": return 0.34
		_: return 0.28
