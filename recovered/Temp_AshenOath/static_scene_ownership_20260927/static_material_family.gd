extends RefCounted

var shaders: Dictionary = {}
var materials: Dictionary = {}
var failures: Array[String] = []
var connections: Dictionary = {}

func convert(source: Material) -> Material:
	if source == null:
		return null
	if materials.has(source):
		return materials[source]
	if source is ShaderMaterial and source in materials.values():
		return source
	if not source is StandardMaterial3D:
		failures.append("Nonstandard source: " + source.resource_name)
		return source
	var original := source as StandardMaterial3D
	# Reject features outside this frozen static-scene diagnostic, never drop them.
	for feature in ["normal_enabled", "bent_normal_enabled", "ao_enabled", "anisotropy_enabled", "clearcoat_enabled", "detail_enabled", "heightmap_enabled", "refraction_enabled", "rim_enabled", "subsurf_scatter_enabled", "backlight_enabled", "uv1_triplanar", "uv2_triplanar", "vertex_color_is_srgb", "disable_fog", "disable_ambient_light", "disable_receive_shadows", "grow_enabled", "proximity_fade_enabled"]:
		if original.get(feature) == true:
			failures.append("Unsupported active feature: " + feature)
	for texture in [original.normal_texture, original.emission_texture, original.roughness_texture, original.metallic_texture]:
		if texture != null:
			failures.append("Unsupported non-albedo texture: " + original.resource_name)
	if original.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or original.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or original.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or original.next_pass != null or original.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		failures.append("Unsupported render state: " + original.resource_name)
	if original.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] or original.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC] or not original.texture_repeat:
		failures.append("Unsupported filter/alpha state: " + original.resource_name)
	if not failures.is_empty():
		return source
	var key := "%d:%d:%d" % [original.cull_mode, original.texture_filter, original.transparency]
	if not shaders.has(key):
		var shader := Shader.new()
		var cull := "cull_disabled" if original.cull_mode == BaseMaterial3D.CULL_DISABLED else "cull_back"
		var filter := "filter_linear_mipmap_anisotropic" if original.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC else "filter_linear_mipmap"
		var alpha := "ALPHA = albedo.a * tex.a; ALPHA_SCISSOR_THRESHOLD = cutout;" if original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else ""
		shader.code = """shader_type spatial;
render_mode depth_draw_opaque, %s, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white, %s, repeat_enable;
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy = 1.0;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform bool use_vertex_color = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float cutout = 0.5;
void fragment() {
 vec4 tex = texture(texture_albedo, UV * uv_scale.xy + uv_offset.xy);
 if (use_vertex_color) { tex *= COLOR; }
 ALBEDO = albedo.rgb * tex.rgb;
 METALLIC = metallic; ROUGHNESS = roughness; SPECULAR = specular;
 EMISSION = emission.rgb * emission_energy;
 %s
}
""" % [cull, filter, alpha]
		shaders[key] = shader
	var result := ShaderMaterial.new()
	result.shader = shaders[key]
	result.render_priority = original.render_priority
	result.set_shader_parameter("albedo", original.albedo_color)
	result.set_shader_parameter("texture_albedo", original.albedo_texture)
	result.set_shader_parameter("roughness", original.roughness)
	result.set_shader_parameter("metallic", original.metallic)
	result.set_shader_parameter("specular", original.metallic_specular)
	result.set_shader_parameter("emission", original.emission if original.emission_enabled else Color.BLACK)
	result.set_shader_parameter("emission_energy", original.emission_energy_multiplier)
	result.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
	result.set_shader_parameter("uv_scale", original.uv1_scale)
	result.set_shader_parameter("uv_offset", original.uv1_offset)
	result.set_shader_parameter("cutout", original.alpha_scissor_threshold)
	materials[source] = result
	var update := _sync.bind(original, result)
	original.changed.connect(update)
	connections[original] = update
	return result

func _sync(original: StandardMaterial3D, result: ShaderMaterial) -> void:
	result.set_shader_parameter("albedo", original.albedo_color)
	result.set_shader_parameter("texture_albedo", original.albedo_texture)
	result.set_shader_parameter("roughness", original.roughness)
	result.set_shader_parameter("metallic", original.metallic)
	result.set_shader_parameter("specular", original.metallic_specular)
	result.set_shader_parameter("emission", original.emission if original.emission_enabled else Color.BLACK)
	result.set_shader_parameter("emission_energy", original.emission_energy_multiplier)
	result.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
	result.set_shader_parameter("uv_scale", original.uv1_scale)
	result.set_shader_parameter("uv_offset", original.uv1_offset)
	result.set_shader_parameter("cutout", original.alpha_scissor_threshold)

func clear() -> void:
	for source in connections:
		if source.changed.is_connected(connections[source]):
			source.changed.disconnect(connections[source])
	connections.clear()
	materials.clear()
	shaders.clear()
