extends RefCounted

const Api = preload("res://scripts/core/zone_construction_api.gd")

static func make_shrine(host: Api, root: Node3D, pos: Vector3) -> void:
	var shrine_mesh: Variant = load("res://assets_external/environment/village/GreyfenShrine_Authored.res") as ArrayMesh
	if shrine_mesh == null or shrine_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen shrine is unavailable")
		return
	var shrine: Variant = MeshInstance3D.new()
	shrine.name = "GreyfenAuthoredOathstone"
	shrine.position = pos
	shrine.mesh = shrine_mesh
	root.add_child(shrine)
	preload("res://scripts/camera_controller.gd").install_visual_clearance(shrine)
	var shrine_tints: Variant = {
		"medieval_brick": Color(0.68, 0.68, 0.62),
		"plaster": Color(0.70, 0.71, 0.66),
		"timber": Color(0.37, 0.27, 0.19),
		"roof_tiles": Color(0.39, 0.18, 0.17),
		"glazing": Color(0.29, 0.56, 0.50),
		"metal": Color(0.20, 0.28, 0.26),
	}
	var shrine_quality: Variant = str(host.settings.settings.get("quality_preset", "balanced"))
	for surface_index in shrine_mesh.get_surface_count():
		var surface_name: Variant = shrine_mesh.surface_get_name(surface_index)
		if not shrine_tints.has(surface_name):
			push_error("Unknown authored Greyfen shrine surface: " + surface_name)
			return
		var material_role: Variant = surface_name if host.world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = host._mat(shrine_tints[surface_name]) if surface_name == "glazing" else host.world_materials.get_material(material_role, shrine_quality, shrine_tints[surface_name], 0.0, false)
		shrine.set_surface_override_material(surface_index, material)
	host._make_collision_box("ShrinePlinth", pos + Vector3(0, 0.18, 0), Vector3(2.36, 0.36, 1.64))
	host._make_collision_box("ShrineOathstone", pos + Vector3(0, 0.96, 0), Vector3(0.88, 1.10, 0.62))
	host._make_loose_role("crate", pos + Vector3(-1.15, 0, -0.65), Vector3.ONE * 0.48, -12.0)
	host._make_loose_role("barrel", pos + Vector3(1.2, 0, 1.40), Vector3.ONE * 0.42, 16.0)
	host._make_light("ShrineGlow", pos + Vector3(0, 1.7, -0.3), Color(0.56, 0.78, 0.62), 1.6)
	host._make_world_prop_anchor("shrine", "shrine", pos, "crow_shrine_state")
	preload("res://scripts/living_cast_stations.gd").add_care_table(root)

static func make_blacksmith(host: Api, root: Node3D, pos: Vector3) -> void:
	var forge_mesh: Variant = load("res://assets_external/environment/village/GreyfenForge_Authored.res") as ArrayMesh
	if forge_mesh == null or forge_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen forge is unavailable")
		return
	var shop: Variant = Node3D.new()
	shop.name = "GreyfenBlacksmithStoneShop"
	shop.position = pos
	root.add_child(shop)
	var workshop: Variant = MeshInstance3D.new()
	workshop.name = "BlacksmithAuthoredForge"
	workshop.mesh = forge_mesh
	shop.add_child(workshop)
	var forge_tints: Variant = {
		"medieval_brick": Color(0.66, 0.62, 0.55),
		"plaster": Color(0.77, 0.69, 0.57),
		"timber": Color(0.42, 0.31, 0.21),
		"roof_tiles": Color(0.40, 0.26, 0.20),
		"glazing": Color(0.16, 0.22, 0.24),
		"metal": Color(0.30, 0.30, 0.29),
	}
	var forge_quality: Variant = str(host.settings.settings.get("quality_preset", "balanced"))
	for surface_index in forge_mesh.get_surface_count():
		var surface_name: Variant = forge_mesh.surface_get_name(surface_index)
		if not forge_tints.has(surface_name):
			push_error("Unknown authored Greyfen forge surface: " + surface_name)
			return
		var material_role: Variant = surface_name if host.world_materials.SURFACES.has(surface_name) else "metal"
		var material: StandardMaterial3D = host._mat(forge_tints[surface_name]) if surface_name == "glazing" else host.world_materials.get_material(material_role, forge_quality, forge_tints[surface_name], 0.0, false)
		workshop.set_surface_override_material(surface_index, material)
	host._make_collision_box("BlacksmithRearWall", pos + Vector3(0, 1.27, 2.33), Vector3(3.4, 1.94, 0.20))
	for side in [-1.0, 1.0]:
		host._make_collision_box("BlacksmithSideWall", pos + Vector3(side * 1.69, 1.27, 1.2), Vector3(0.20, 1.94, 2.4))
	host._make_collision_box("ForgeHearth", pos + Vector3(1.5, 0.30, -1.1), Vector3(0.96, 0.55, 0.88))
	host._make_collision_box("ForgeCoal", pos + Vector3(1.5, 0.38, -1.1), Vector3(0.62, 0.08, 0.48))
	host._make_light("ForgeLight", pos + Vector3(1.5, 1.5, -1.1), Color(1.0, 0.35, 0.12), 2.5)
	var work: Variant = MeshInstance3D.new()
	work.name = "BlacksmithFittedWork"
	work.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
	if work.mesh == null:
		push_error("Greyfen requires its fitted anvil, workbench, stock and fuel")
		work.free()
		return
	shop.add_child(work)
	host._make_loose_role("barrel", pos + Vector3(2.15, 0, 0.95), Vector3.ONE * 0.55, -20.0)
	host._make_torch(pos + Vector3(-1.8, 0, -1.2))
	host._make_world_prop_anchor("forge", "forge", pos + Vector3(1.5, 0.55, -1.1), "iron_fate")
