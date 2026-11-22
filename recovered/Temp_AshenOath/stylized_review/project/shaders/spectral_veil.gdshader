shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;
uniform sampler2D authored_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 spectral_color : source_color = vec4(0.57, 0.43, 0.84, 1.0);
uniform float local_amplitude = 0.006;
void vertex() {
	float tip = sin(clamp(fract(UV.y), 0.0, 1.0) * 3.14159265);
	VERTEX.x += sin(TIME * 1.3 + UV.y * 8.0) * local_amplitude * tip;
	VERTEX.z += cos(TIME * 0.9 + UV.y * 9.0) * local_amplitude * tip;
}
void fragment() {
	vec3 pigment = texture(authored_atlas, UV).rgb;
	float edge = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 0.45);
	float breath = 0.78 + 0.22 * sin(TIME * 1.6 + UV.y * 11.0);
	ALBEDO = spectral_color.rgb * pigment;
	EMISSION = spectral_color.rgb * (1.5 + breath) * pigment;
	ALPHA = edge * (0.55 + breath * 0.25);
}
