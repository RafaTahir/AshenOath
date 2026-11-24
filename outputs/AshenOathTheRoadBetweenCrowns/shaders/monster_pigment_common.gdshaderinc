// Pigment changes use the retained atlas; lighting and surface detail stay native.
uniform sampler2D authored_atlas : source_color, filter_linear_mipmap, repeat_enable;
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
uniform int anatomy_detail = 0;
uniform bool atlas_regions = false;
uniform bool normal_enabled = false;
uniform sampler2D authored_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float authored_normal_scale = 1.0;
uniform float authored_roughness = 1.0;
uniform float authored_metallic = 0.0;
uniform float authored_specular = 0.5;
uniform float authored_clearcoat = 0.0;
uniform float authored_clearcoat_roughness = 0.5;
uniform bool roughness_textured = false;
uniform bool metallic_textured = false;
uniform sampler2D authored_roughness_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D authored_metallic_map : hint_default_white, filter_linear_mipmap, repeat_enable;
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
	// Warm, bright atlas islands carry ivory teeth and keratin. Keep their
	// native color separation while low-value hide receives its full pigment.
	// Compatibility grades sRGB samples; Forward+/Mobile grade linear samples.
	// Express the same ivory range in the renderer's working color space.
	float ivory_low = OUTPUT_IS_SRGB ? 0.381 : 0.12;
	float ivory_high = OUTPUT_IS_SRGB ? 0.680 : 0.42;
	float retained_warm_highlights = atlas_regions ? 1.0 - 0.85 * smoothstep(ivory_low, ivory_high, luminance) * warm_mask : 1.0;
	return mix(source, clamp(colored, vec3(0.0), vec3(1.0)),
		pigment_strength * shadow_mask * highlight_mask * retained_chroma * retained_warm_highlights);
}

// The Stalker's neck and shoulder shells mirror across V=0.4449. Each
// stroke tapers along the muscle rather than crossing an atlas boundary.
float stalker_bar(vec2 uv, vec2 start, vec2 end, float width, float bend) {
	vec2 axis = end - start;
	float along = dot(uv - start, axis) / dot(axis, axis);
	float progress = clamp(along, 0.0, 1.0);
	vec2 perpendicular = normalize(vec2(-axis.y, axis.x));
	float distance_to_fold = dot(uv - start, perpendicular) - bend * progress * (1.0 - progress);
	float taper = smoothstep(0.0, 0.14, along) * (1.0 - smoothstep(0.52, 1.0, along));
	return taper * (1.0 - smoothstep(width * (0.24 + 0.52 * taper), width, abs(distance_to_fold)));
}

vec3 stalker_hide_detail(vec3 albedo, vec2 uv) {
	vec2 shell = vec2(uv.x, 0.4449 + abs(uv.y - 0.4449));
	float dark = 0.0;
	float lichen = 0.0;
	if (shell.x > 0.08 && shell.x < 0.33 && shell.y > 0.57 && shell.y < 0.825) {
		// A broken mantle of three dark bars crosses each shoulder and runs
		// down the outer arm. A narrow pale trailing lip catches the eye.
		dark = max(stalker_bar(shell, vec2(0.104, 0.795), vec2(0.187, 0.717), 0.013, 0.040),
			stalker_bar(shell, vec2(0.152, 0.788), vec2(0.231, 0.685), 0.016, 0.050));
		dark = max(dark, stalker_bar(shell, vec2(0.209, 0.762), vec2(0.276, 0.663), 0.013, 0.028));
		dark = max(dark, stalker_bar(shell, vec2(0.251, 0.713), vec2(0.306, 0.624), 0.009, 0.018));
		lichen = max(stalker_bar(shell, vec2(0.151, 0.790), vec2(0.199, 0.744), 0.006, 0.015),
			stalker_bar(shell, vec2(0.209, 0.765), vec2(0.254, 0.711), 0.005, 0.013));
	} else {
		// These two outer cheek plates are packed at different UV offsets.
		vec2 cheek = uv.x > 0.70 ? uv - vec2(0.200, 0.202) : uv;
		if (cheek.x > 0.545 && cheek.x < 0.609 && cheek.y > 0.101 && cheek.y < 0.212) {
			dark = stalker_bar(cheek, vec2(0.566, 0.196), vec2(0.585, 0.110), 0.009, -0.015);
			lichen = stalker_bar(cheek, vec2(0.568, 0.192), vec2(0.581, 0.145), 0.0038, -0.010);
		}
	}
	albedo *= mix(vec3(1.0), vec3(0.46, 0.52, 0.52), dark);
	return albedo * mix(vec3(1.0), vec3(1.60, 1.42, 1.12), lichen);
}

// UV landmarks sampled on the skinned Ghoulkin source in bind pose. The
// left and right chest islands have different widths and slopes.
vec3 ghoulkin_hide_detail(vec3 albedo, vec2 uv) {
	if (uv.y > 0.486 && uv.y < 0.641 && uv.x > 0.047 && uv.x < 0.225) {
		bool left = uv.x > 0.135;
		float across = left ? (uv.x - 0.15) / 0.068 : (0.117 - uv.x) / 0.066;
		float arc = across * (left ? 0.036 : 0.043)
			+ 0.003 * sin(3.14159 * across);
		float height = uv.y - arc;
		float collar = height - (left ? 0.597 : 0.599);
		float ribs = abs(height - (left ? 0.544 : 0.546));
		ribs = min(ribs, abs(height - (left ? 0.520 : 0.522)));
		ribs = min(ribs, abs(height - (left ? 0.500 : 0.502)));
		float taper = smoothstep(-0.02, 0.22, across)
			* (1.0 - smoothstep(0.70, 1.00, across));
		float aa = min(fwidth(height), 0.004);
		float rib = 1.0 - smoothstep(0.0015, 0.007 + aa, ribs);
		float clavicle = 1.0 - smoothstep(0.002, 0.007 + aa, abs(collar));
		float hollow = 1.0 - smoothstep(0.001, 0.006 + aa, abs(collar + 0.008));
		albedo *= 1.0 - 0.28 * taper * hollow;
		albedo *= vec3(1.0) + taper * (0.40 * rib + 0.60 * clavicle) * vec3(0.95, 0.85, 0.56);
	} else if (uv.x > 0.211 && uv.x < 0.295 && uv.y > 0.206 && uv.y < 0.271) {
		// The healed cut breaks at the cheekbone and tapers toward the jaw.
		float along = clamp((uv.x - 0.2173) / 0.0728, 0.0, 1.0);
		float cut_y = mix(0.2630, 0.2131, along)
			- 0.0075 * (1.0 - abs(2.0 * along - 1.0));
		float taper = smoothstep(0.0, 0.14, along) * (1.0 - smoothstep(0.83, 1.0, along));
		float width = 0.0028 + min(fwidth(uv.y), 0.003);
		float cut = taper * (1.0 - smoothstep(width, width + 0.005, abs(uv.y - cut_y)));
		float lip = taper * (1.0 - smoothstep(0.0015, width + 0.0025, abs(uv.y - cut_y - 0.0045)));
		albedo *= mix(vec3(1.0), vec3(0.79, 0.50, 0.46), cut);
		albedo *= vec3(1.0) + vec3(0.69, 0.48, 0.36) * lip;
	}
	return albedo;
}

// The Raider's wrist cord has a toroidal unwrap: U crosses the strand and V
// follows the loop. Bind the opposing twists to it through every pose.
vec3 raider_cord(vec3 base, vec2 uv) {
	float crossing = uv.y * 8.0 + uv.x * 2.0;
	float opposite = uv.y * 8.0 - uv.x * 2.0;
	float visibility = 1.0 - smoothstep(0.15, 0.5, fwidth(crossing) + fwidth(opposite));
	float over = 0.5 + 0.5 * cos(TAU * crossing);
	float under = 0.5 + 0.5 * cos(TAU * opposite);
	float twist = mix(under * 0.55, over, smoothstep(0.28, 0.72, over));
	return base * mix(vec3(1.0), mix(vec3(0.62, 0.50, 0.38), vec3(1.29, 1.16, 0.94), twist), visibility);
}

// Both tusks run from V=1 at the gum to V=0 at the worn tip.
vec3 brute_tusk(vec3 base, vec2 uv) {
	float root_stain = smoothstep(0.28, 0.93, uv.y);
	vec3 ivory = base * mix(vec3(1.19, 1.14, 1.06), vec3(0.79, 0.61, 0.43), root_stain);
	float along = uv.y * 5.0 + 0.13 * cos(TAU * uv.x);
	float ring = smoothstep(0.65, 0.96, cos(TAU * along));
	float resolved = 1.0 - smoothstep(0.12, 0.48, fwidth(along));
	return ivory * (1.0 - 0.17 * root_stain * resolved * ring);
}

// A finger-dragged woad mark on the Raider's forward shoulder. Both
// tapered fingers follow the chest UV island and stop before its seam.
vec3 raider_woad_detail(vec3 albedo, vec2 uv) {
	if (uv.x < 0.045 || uv.x > 0.103 || uv.y < 0.581 || uv.y > 0.637) {
		return albedo;
	}
	float t = clamp((0.631 - uv.y) / 0.047, 0.0, 1.0);
	float stroke_x = mix(0.0542, 0.0927, t) + 0.0018 * sin(3.14159 * t);
	float dx = uv.x - stroke_x;
	float aa = min(fwidth(dx), 0.0025);
	float edge = 0.0057 * (1.0 - t * 0.60);
	float finger = 1.0 - smoothstep(edge, edge + 0.0018 + aa, abs(dx));
	float second = 1.0 - smoothstep(edge * 0.65, edge + aa, abs(dx - 0.009 + t * 0.002));
	second *= 1.0 - smoothstep(0.60, 0.84, t);
	float taper = smoothstep(0.0, 0.09, t) * (1.0 - smoothstep(0.79, 1.0, t));
	float paint = max(finger, second) * taper;
	float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	return mix(albedo, lum * vec3(0.38, 0.86, 1.20), 0.88 * paint);
}

float brute_cut_distance(vec2 uv, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(uv - a - ab * clamp(dot(uv - a, ab) / dot(ab, ab), 0.0, 1.0));
}

// An old forked wound follows the Brute's left pectoral, with a second
// broken line above the brow. Each island is mapped independently.
vec3 brute_scar_detail(vec3 albedo, vec2 uv) {
	float distance_to_cut;
	if (uv.x > 0.139 && uv.x < 0.207 && uv.y > 0.556 && uv.y < 0.612) {
		float upper = brute_cut_distance(uv, vec2(0.2027, 0.6059), vec2(0.1712, 0.5893));
		float middle = brute_cut_distance(uv, vec2(0.1712, 0.5893), vec2(0.1552, 0.5770));
		float lower = brute_cut_distance(uv, vec2(0.1552, 0.5770), vec2(0.1439, 0.5621));
		float fork = brute_cut_distance(uv, vec2(0.1695, 0.5885), vec2(0.1714, 0.5789));
		distance_to_cut = min(min(upper, middle), min(lower, fork + 0.0010));
	} else if (uv.x > 0.118 && uv.x < 0.174 && uv.y > 0.067 && uv.y < 0.143) {
		float brow = brute_cut_distance(uv, vec2(0.1249, 0.0743), vec2(0.1479, 0.1112));
		float brow_tip = brute_cut_distance(uv, vec2(0.1479, 0.1112), vec2(0.1669, 0.1364));
		distance_to_cut = min(brow, brow_tip + 0.0008);
	} else {
		return albedo;
	}
	float aa = min(max(fwidth(uv.x), fwidth(uv.y)), 0.003);
	float ridge = 1.0 - smoothstep(0.0019, 0.0046 + aa, distance_to_cut);
	float edge = 1.0 - smoothstep(0.0048, 0.0080 + aa, distance_to_cut);
	albedo *= 1.0 - 0.26 * (edge - ridge);
	return albedo * (vec3(1.0) + ridge * vec3(0.69, 0.72, 0.59));
}
