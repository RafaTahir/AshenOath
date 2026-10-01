extends RefCounted

const Frontier = preload("res://scripts/bandit_frontier.gd")
const LANDSCAPES := {
	"deep_wood": preload("res://assets_external/environment/forest/Campaign_deep_wood_Landscape.res"),
	"burned_farmstead": preload("res://assets_external/environment/forest/Campaign_burned_farmstead_Landscape.res"),
	"marsh_crossing": preload("res://assets_external/environment/forest/Campaign_marsh_crossing_Landscape.res"),
	"bandit_road": preload("res://assets_external/environment/forest/Campaign_bandit_road_Landscape.res"),
}
const RUINS := {
	"West": preload("res://assets_external/environment/village/FarmsteadWest_Authored.res"),
	"East": preload("res://assets_external/environment/village/FarmsteadEast_Authored.res"),
}
const CHECKPOINT := preload("res://assets_external/environment/village/RoadCheckpoint_Authored.res")

static func landscape(context: ZoneBuildContext) -> void:
	_publish(context, LANDSCAPES[context.zone_id], "CampaignAuthoredLandscape")

static func adjoining_frontier(context: ZoneBuildContext) -> void:
	Frontier.build(context)
	var layer := context.zone_root.get_node_or_null("BanditAuthoredFrontier") as Node3D
	if layer == null:
		push_error("Campaign wilds requires its authored adjoining terrain and forest")
		return
	layer.name = "CampaignAuthoredFrontier"

static func checkpoint(context: ZoneBuildContext) -> void:
	_publish(context, CHECKPOINT, "BanditAuthoredCheckpoint")

static func _publish(context: ZoneBuildContext, mesh: ArrayMesh, id: String) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in node.mesh.get_surface_count():
		var surface_id: String = node.mesh.surface_get_name(surface)
		var material := context.make_world_material(surface_id).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = true
		if surface_id == "water":
			material.roughness = 0.24
			material.metallic = 0.08
			material.emission_enabled = true
			material.emission = Color(0.07, 0.23, 0.20)
			material.emission_energy_multiplier = 0.16
		elif surface_id == "plaster":
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.set_surface_override_material(surface, material)
	context.add_node(node)

static func burned_home(context: ZoneBuildContext, origin: Vector3, suffix: String) -> void:
	var node := MeshInstance3D.new()
	node.name = suffix + "FarmsteadAuthoredRuins"
	node.mesh = RUINS[suffix]
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in node.mesh.get_surface_count():
		var material := context.make_world_material(node.mesh.surface_get_name(surface)).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = true
		node.set_surface_override_material(surface, material)
	context.add_node(node)
