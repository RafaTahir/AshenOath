extends RefCounted

const RiverSection = preload("res://scripts/zones/river_section.gd")
const CemeterySection = preload("res://scripts/zones/cemetery_section.gd")

func build(host: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "AuthoredGreyfenSection"
	root.set_meta("ticket", "WORLD-001")
	root.set_meta("main_route_half_width", 2.8)
	host.zone_root.add_child(root)

	host.call("_make_split_ground", 42.0, 34.0, 4.5, 3.4, Color(0.16, 0.18, 0.13))
	var river: Dictionary = RiverSection.new().build(host.zone_root, {
		"host": host, "center_z": 4.5, "width": 42.0, "span": 3.4,
	})
	host.call("_make_greyfen_terrain_layers")
	host.call("_make_play_area_bounds", 42, 34, Color(0.09, 0.12, 0.08))
	host.call("_make_road", Vector3(0, 0.018, 0), Vector3(4.2, 0.04, 30.0), Color(0.16, 0.13, 0.09))
	host.call("_make_road", Vector3(-5, 0.02, 9), Vector3(14.0, 0.04, 3.0), Color(0.15, 0.12, 0.085))
	host.call("_make_greyfen_path_edges")

	_build_light_composition(host)
	_build_village_silhouette(host)
	_build_boundary_dressing(host)
	_build_landmarks(host)

	host.call("_make_village_dressing")
	host.call("_make_greyfen_first_impression_dressing")
	host.call("_make_quality_greyfen_overhaul")
	host.call("_make_spawn_composition")
	host.call("_make_tree_cluster", [
		Vector3(-16,0,-12), Vector3(-14,0,12), Vector3(16,0,-11),
		Vector3(15,0,13), Vector3(0,0,15),
	])
	return {"root": root, "river": river}

func _build_light_composition(host: Node) -> void:
	host.call("_make_light", "Village Warmth", Vector3(-1.5, 5.2, 2), Color(1.0, 0.58, 0.30), 3.0)
	host.call("_make_light", "Blue Dusk Fill", Vector3(9, 6, -10), Color(0.34, 0.42, 0.58), 2.8)
	host.call("_make_light", "Shrine Beacon", Vector3(4.8, 4.8, -5.4), Color(0.70, 0.86, 0.60), 3.0)
	host.call("_make_light", "Wychwood Gate Lantern", Vector3(0, 3.2, -14.3), Color(1.0, 0.48, 0.16), 2.2)
	host.call("_make_fog_sheet", Vector3(0, 1.1, -12), Vector3(18, 1, 5), Color(0.18, 0.22, 0.22, 0.12))

func _build_village_silhouette(host: Node) -> void:
	# Each structure frames a different part of the route and uses a deterministic facade variant.
	host.call("_make_village_house_dressed", Vector3(-5,0,-3), 8.0, "DressedVillageHouse_WestLane")
	host.call("_make_village_house_dressed", Vector3(7,0,1), -18.0, "DressedVillageHouse_EastLane")
	host.call("_make_village_house_dressed", Vector3(-10,0,8), 24.0, "DressedVillageHouse_SpawnFrame")
	host.call("_make_village_house_dressed", Vector3(11.8,0,-7.8), -42.0, "DressedVillageHouse_ShrineFrame")

func _build_boundary_dressing(host: Node) -> void:
	host.call("_make_tree_wall", 20.0, 15.2, 7, true)
	host.call("_make_tree_wall", 20.0, -15.2, 7, true)
	for tree in [
		[Vector3(-16.2, 0, -10.8), 1.10, -18.0], [Vector3(-14.8, 0, -7.2), 0.92, 21.0],
		[Vector3(15.8, 0, -10.7), 1.04, 12.0], [Vector3(16.5, 0, -6.4), 0.88, -26.0],
		[Vector3(-16.0, 0, 11.6), 1.00, 8.0], [Vector3(16.2, 0, 12.0), 0.96, -11.0],
	]:
		host.call("_make_loose_role", "forest_tree", tree[0], Vector3.ONE * float(tree[1]), float(tree[2]))
	for pos in [Vector3(-5.3, 0, 3.4), Vector3(4.8, 0, -5.3), Vector3(-9.3, 0, 11.2)]:
		host.call("_make_torch", pos)
	for x in [-17, -13, -9, -5, 5, 9, 13, 17]:
		host.call("_make_fence", Vector3(x, 0.35, 14), false)
		host.call("_make_fence", Vector3(x, 0.35, -14), false)
	for z in [-10, -6, -2, 2, 6, 10]:
		host.call("_make_fence", Vector3(-19, 0.35, z), true)
		host.call("_make_fence", Vector3(19, 0.35, z), true)

func _build_landmarks(host: Node) -> void:
	host.call("_make_notice_board", Vector3(-2.0, 0, 9.4))
	host.call("_make_shrine_scene", Vector3(6.0, 0, -7.0))
	host.call("_make_blacksmith_scene", Vector3(10.5, 0, -1.2))
	CemeterySection.new().build(host.zone_root, {"host": host, "origin": Vector3(14, 0, 8.6)})
	host.call("_make_cart", Vector3(-6.2, 0, 9.0))
