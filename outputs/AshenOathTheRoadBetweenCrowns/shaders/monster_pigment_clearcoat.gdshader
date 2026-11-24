shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/monster_pigment_common.gdshaderinc"

void fragment() {
	#include "res://shaders/monster_pigment_surface.gdshaderinc"
	CLEARCOAT = authored_clearcoat;
	CLEARCOAT_ROUGHNESS = authored_clearcoat_roughness;
}
