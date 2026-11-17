// Pigment changes use the retained atlas; lighting and surface detail stay native.
uniform sampler2D authored_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 authored_tint : source_color = vec4(1.0);
uniform bool vertex_color_enabled = false;
uniform vec2 authored_uv_scale = vec2(1.0);
uniform vec2 authored_uv_offset = vec2(0.0);
uniform vec4 neutral_color : source_color = vec4(0.4, 0.5, 0.3, 1.0);
uniform vec4 warm_color : source_color = vec4(0.5, 0.3, 0.2, 1.0);
uniform vec4 cool_color : source_color = vec4(0.2, 0.3, 0.4, 1.0);
uniform float pigment_strength : hint_range(0.0, 1.0) = 0.8;
uniform float chroma_preservation : hint_range(0.0, 1.0) = 0.6;
uniform float highlight_preservation : hint_range(0.0, 1.0) = 0.85;
uniform float value_gain : hint_range(0.5, 1.5) = 1.0;
uniform bool atlas_regions = false;
uniform bool normal_enabled = false;
uniform sampler2D authored_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float authored_normal_scale = 1.0;
uniform float authored_roughness = 1.0;
uniform float authored_metallic = 0.0;
uniform float authored_specular = 0.5;
uniform float authored_clearcoat = 0.0;
uniform float authored_clearcoat_roughness = 0.5;
uniform bool roughness_textured = false;
uniform bool metallic_textured = false;
uniform sampler2D authored_roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D authored_metallic_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);

vec3 monster_pigment(vec3 source) {
	float peak = max(max(source.r, source.g), source.b);
	float low = min(min(source.r, source.g), source.b);
	float chroma = (peak - low) / max(peak, 0.0001);
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	// Warm keratin/bone and cool atlas islands keep independent pigments.
	float warm_mask = smoothstep(-0.035, 0.055, source.r - source.b);
	vec3 accent = mix(cool_color.rgb, warm_color.rgb, warm_mask);
	float neutral_mask = 1.0 - smoothstep(chroma_preservation * 0.55,
		min(chroma_preservation + 0.25, 1.0), chroma);
	vec3 pigment = mix(accent, neutral_color.rgb, neutral_mask);
	if (!atlas_regions) {
		// Named skin, metal, eye and tooth surfaces already have semantic owners.
		pigment = mix(neutral_color.rgb, accent, (1.0 - neutral_mask) * 0.25);
	}
	float pigment_luminance = max(dot(pigment, vec3(0.2126, 0.7152, 0.0722)), 0.02);
	vec3 colored = pigment * (luminance * value_gain / pigment_luminance);
	// Keep mouth recesses dark and preserve near-white atlas highlights.
	float shadow_mask = smoothstep(0.003, 0.025, luminance);
	float highlight_mask = 1.0 - smoothstep(highlight_preservation, 1.0, peak);
	float retained_chroma = atlas_regions ? 1.0 - smoothstep(0.65, 0.98, chroma) * 0.7 : 1.0;
	return mix(source, clamp(colored, vec3(0.0), vec3(1.0)),
		pigment_strength * shadow_mask * highlight_mask * retained_chroma);
}
