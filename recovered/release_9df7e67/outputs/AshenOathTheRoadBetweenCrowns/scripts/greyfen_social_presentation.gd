extends RefCounted

const MESHES := {
	"common_table": preload("res://assets_external/environment/props/GreyfenSocial_common_table.res"),
	"barrel_board": preload("res://assets_external/environment/props/GreyfenSocial_barrel_board.res"),
	"mira_apothecary": preload("res://assets_external/environment/props/GreyfenSocial_mira_apothecary.res"),
}

static func apply(area: Node3D, id: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "GreyfenSocialFurniture"
	visual.mesh = MESHES[id]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	area.add_child(visual)
	area.set_meta("authored_social_furniture", true)
