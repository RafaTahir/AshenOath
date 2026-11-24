vec2 authored_uv = UV * authored_uv_scale + authored_uv_offset;
vec4 texel = texture(authored_atlas, authored_uv) * authored_tint;
if (vertex_color_enabled) {
	texel *= COLOR;
}
ALBEDO = monster_pigment(texel.rgb);
if (anatomy_detail != 0 && pigment_strength > 0.0) {
	vec2 detail_uv = fract(authored_uv);
	if (anatomy_detail == 1) {
		ALBEDO = ghoulkin_hide_detail(ALBEDO, detail_uv);
	} else if (anatomy_detail == 2) {
		ALBEDO = stalker_hide_detail(ALBEDO, detail_uv);
	} else if (anatomy_detail == 3) {
		ALBEDO = raider_cord(ALBEDO, authored_uv);
	} else if (anatomy_detail == 4) {
		ALBEDO = brute_tusk(ALBEDO, authored_uv);
	} else if (anatomy_detail == 5) {
		ALBEDO = raider_woad_detail(ALBEDO, detail_uv);
	} else if (anatomy_detail == 6) {
		ALBEDO = brute_scar_detail(ALBEDO, detail_uv);
	}
}
ROUGHNESS = authored_roughness;
METALLIC = authored_metallic;
SPECULAR = authored_specular;
if (roughness_textured) {
	ROUGHNESS *= dot(texture(authored_roughness_map, authored_uv), roughness_channel);
}
if (metallic_textured) {
	METALLIC *= dot(texture(authored_metallic_map, authored_uv), metallic_channel);
}
if (!FRONT_FACING) {
	NORMAL = -NORMAL;
}
NORMAL_MAP = vec3(0.5, 0.5, 1.0);
NORMAL_MAP_DEPTH = 1.0;
if (normal_enabled) {
	NORMAL_MAP = texture(authored_normal, authored_uv).rgb;
	NORMAL_MAP_DEPTH = authored_normal_scale;
}
