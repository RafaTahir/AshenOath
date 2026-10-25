extends RefCounted

const MESHES := {
	"common_table": "res://assets_external/environment/props/GreyfenSocial_common_table.res",
	"barrel_board": "res://assets_external/environment/props/GreyfenSocial_barrel_board.res",
	"mira_apothecary": "res://assets_external/environment/props/GreyfenSocial_mira_apothecary.res",
}

static func apply(area: Node3D, id: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "GreyfenSocialFurniture"
	visual.mesh = load(str(MESHES[id])) as Mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	area.add_child(visual)
	if id == "mira_apothecary":
		preload("res://scripts/camera_controller.gd").install_visual_clearance(visual)
	area.set_meta("authored_social_furniture", true)
