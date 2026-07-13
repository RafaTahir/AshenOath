extends RefCounted

const RiverSection = preload("res://scripts/zones/river_section.gd")

func build(host: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "AuthoredWychwoodSection"
	root.set_meta("ticket", "WORLD-002")
	root.set_meta("main_route_half_width", 2.6)
	host.zone_root.add_child(root)

	host.call("_make_split_ground", 44.0, 34.0, 0.0, 3.4, Color(0.065, 0.105, 0.07))
	var river: Dictionary = RiverSection.new().build(host.zone_root, {
		"host": host, "center_z": 0.0, "width": 44.0, "span": 3.4,
	})
	host.call("_make_wychwood_terrain_layers")
	host.call("_make_play_area_bounds", 44, 34, Color(0.04, 0.075, 0.045))
	host.call("_make_road", Vector3(0, 0.018, 3), Vector3(4.0, 0.04, 27.0), Color(0.065, 0.075, 0.052))
	host.call("_make_road", Vector3(6, 0.019, -8), Vector3(10.0, 0.04, 3.0), Color(0.055, 0.065, 0.05))
	host.call("_make_wychwood_path_edges")

	_build_light_composition(host)
	_build_gate_threshold(host)
	_build_forest_frame(host)
	_build_investigation_route(host)
	_build_combat_clearing(host)
	host.call("_make_quality_wychwood_overhaul")
	return {"root": root, "river": river}

func _build_light_composition(host: Node) -> void:
	host.call("_make_light", "Moon Shaft", Vector3(0, 6.6, -7), Color(0.48, 0.58, 0.78), 4.2)
	host.call("_make_light", "Sick Green Bounce", Vector3(9, 3.2, -9), Color(0.25, 0.42, 0.28), 1.7)
	host.call("_make_light", "Trail Threat", Vector3(0, 2.4, -2.8), Color(0.42, 0.68, 0.62), 1.4)
	host.call("_make_fog_sheet", Vector3(0, 1.0, -6), Vector3(24, 1, 8), Color(0.24, 0.30, 0.28, 0.20))
	host.call("_make_fog_sheet", Vector3(-10, 0.8, 5), Vector3(14, 1, 5), Color(0.16, 0.24, 0.18, 0.16))

func _build_gate_threshold(host: Node) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodGateThreshold"
	marker.set_meta("clear_half_width", 3.4)
	host.zone_root.add_child(marker)
	for x in [-3.7, 3.7]:
		host.call("_make_torch", Vector3(x, 0, 13.4))
		host.call("_make_tree", Vector3(x * 2.15, 0, 13.8))
	host.call("_make_visual_box", "WychwoodThresholdBrokenSign", Vector3(-4.2, 0.82, 12.8), Vector3(1.05, 0.12, 0.42), Color(0.10, 0.055, 0.028))

func _build_forest_frame(host: Node) -> void:
	# Keep the third-person boom out of boundary canopies at the entrance and arena end.
	for x in [-20.0, -16.0, -12.0, -8.0, 8.0, 12.0, 16.0, 20.0]:
		host.call("_make_tree", Vector3(x, 0, 15.2))
		host.call("_make_tree", Vector3(x, 0, -15.2))
	host.call("_make_tree_wall", 16.0, -20.0, 7, false)
	host.call("_make_tree_wall", 16.0, 20.0, 7, false)
	host.call("_make_tree_cluster", [
		Vector3(-18,0,-12), Vector3(-15,0,-6), Vector3(-16,0,7), Vector3(-13,0,13),
		Vector3(16,0,-12), Vector3(18,0,-5), Vector3(17,0,5), Vector3(14,0,13),
		Vector3(-8,0,-14), Vector3(8,0,14), Vector3(-4,0,15), Vector3(5,0,-15),
	])
	for tree in [
		[Vector3(-13.0,0,10.0), 0.74, -12.0], [Vector3(12.5,0,9.2), 0.66, 17.0],
		[Vector3(-12.6,0,5.7), 0.64, 24.0], [Vector3(13.2,0,4.9), 0.76, -16.0],
		[Vector3(-12.8,0,-4.0), 0.72, 9.0], [Vector3(12.4,0,-3.8), 0.68, -22.0],
		[Vector3(-11.4,0,-11.0), 0.78, -6.0], [Vector3(11.8,0,-11.4), 0.74, 19.0],
	]:
		# Landmark placement is authored, while the repeated geometry is batched.
		# This keeps the forest silhouette without multiplying imported-model draw calls.
		host.call("_make_tree", tree[0])
		var marker := Node3D.new()
		marker.name = "WychwoodLandmarkTree"
		marker.position = tree[0]
		marker.set_meta("authored_scale", float(tree[1]))
		marker.set_meta("authored_yaw", float(tree[2]))
		marker.add_to_group("wychwood_landmark_tree")
		host.zone_root.add_child(marker)

func _build_investigation_route(host: Node) -> void:
	var marker := Node3D.new()
	marker.name = "WychwoodInvestigationRoute"
	marker.set_meta("clue_laybys", 3)
	host.zone_root.add_child(marker)
	host.call("_make_wychwood_route_dressing")
	host.call("_make_wychwood_corridor")
	host.call("_make_wychwood_road_of_crows_story_beats")
	for pos in [Vector3(-8,0,-3), Vector3(6.7,0,-9.2), Vector3(9.8,0,-12.0), Vector3(-5,0,9.8)]:
		host.call("_make_deadfall", pos)
	for bush in [Vector3(-6.6,0,8.0), Vector3(6.2,0,6.2), Vector3(-6.7,0,3.2), Vector3(6.8,0,-2.4)]:
		host.call("_make_visual_box", "WychwoodRouteBush", bush + Vector3(0, 0.42, 0), Vector3(1.15, 0.72, 0.62), Color(0.08, 0.20, 0.09))
		var bush_marker := Node3D.new()
		bush_marker.name = "WychwoodRouteBushMarker"
		bush_marker.position = bush
		bush_marker.add_to_group("wychwood_route_bush")
		host.zone_root.add_child(bush_marker)

func _build_combat_clearing(host: Node) -> void:
	var marker := Node3D.new()
	marker.name = "AuthoredWychwoodCombatArena"
	marker.set_meta("safe_half_extents", Vector2(5.2, 4.2))
	host.zone_root.add_child(marker)
	host.call("_make_monster_clearing", Vector3(0, 0, -6.5))
	for pos in [Vector3(6.8,0,-10.2), Vector3(8.5,0,-11.6), Vector3(10.0,0,-9.8), Vector3(8.5,0,-8.1)]:
		host.call("_make_ritual_stone", pos)
