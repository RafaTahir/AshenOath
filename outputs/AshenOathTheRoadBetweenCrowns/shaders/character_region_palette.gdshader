shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D authored_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 authored_tint : source_color = vec4(1.0);
uniform vec4 regional_cloth : source_color = vec4(0.3, 0.35, 0.3, 1.0);

void fragment() {
	vec4 texel = texture(authored_atlas, UV) * authored_tint;
	// The retained Universal atlas gives clothing the first 512 px tile only.
	// Face, hair, eyes and other tiles remain byte-for-byte authored textures.
	if (UV.x < 0.25 && UV.y < 0.5) {
		float lightness = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 tone = regional_cloth.rgb / max(max(regional_cloth.r, regional_cloth.g), max(regional_cloth.b, 0.01));
		texel.rgb = tone * lightness;
	}
	ALBEDO = texel.rgb;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
