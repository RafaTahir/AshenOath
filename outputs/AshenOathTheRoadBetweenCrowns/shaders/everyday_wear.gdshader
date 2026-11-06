shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float soil : hint_range(0.0, 1.0) = 0.0;
uniform float feet_height = 0.0;
varying float world_height;
void vertex() { world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
    float boot_mask = 1.0 - smoothstep(0.10, 0.48, world_height - feet_height);
    float fleck = smoothstep(0.18, 0.65, sin(UV.x * 117.0) * sin(UV.y * 149.0));
    ALBEDO = mix(vec3(0.24, 0.24, 0.21), vec3(0.12, 0.11, 0.08), wetness);
    ROUGHNESS = mix(0.95, 0.36, wetness);
    ALPHA = clamp(soil * boot_mask * fleck * 0.28 + wetness * 0.045, 0.0, 0.32);
}
