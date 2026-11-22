extends RefCounted

const FAR_TERRAIN := preload("res://assets/landscape/far_terrain.res")
const NODE_NAME := "AuthoredFarTerrain"

static func build(context: ZoneBuildContext, half_extent: Vector2, height_scale: float, base_y: float, tint: Color = Color(0.75, 0.82, 0.72)) -> MeshInstance3D:
	var existing := context.zone_root.get_node_or_null(NODE_NAME) as MeshInstance3D
	if existing != null:
		return existing
	var terrain := MeshInstance3D.new()
	terrain.name = NODE_NAME
	terrain.mesh = FAR_TERRAIN
	terrain.scale = Vector3(half_extent.x, height_scale, half_extent.y)
	terrain.position.y = base_y
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := context.make_world_material("forest_ground", tint).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	# Normalized mesh coordinates retain metre-scale UVs after scene fitting.
	material.uv1_scale *= Vector3(half_extent.x, half_extent.y, 1.0)
	terrain.material_override = material
	context.add_node(terrain)
	return terrain
