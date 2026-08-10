extends RefCounted

const CastlePatrol = preload("res://scripts/castle_patrol.gd")
const CASTLE_ZONES := ["vargan_approach", "vargan_court", "record_hall"]

func build(context: ZoneBuildContext) -> void:
	var zone_id := context.zone_id
	match zone_id:
		"vargan_approach": _build_approach(context)
		"vargan_court": _build_courtyard(context)
		"record_hall": _build_record_hall(context)

func _base(context: ZoneBuildContext, zone_id: String, ground_color: Color, size := Vector2(44, 34)) -> void:
	context.make_ground(Vector3(0, -0.08, 0), Vector3(size.x, 0.16, size.y), ground_color)
	context.make_play_area_bounds(size.x, size.y, ground_color.darkened(0.38))
	var marker := Node3D.new()
	marker.name = "CastleVargan_%s" % zone_id
	context.add_node(marker)

func _build_approach(context: ZoneBuildContext) -> void:
	_base(context, "Approach", Color(0.105, 0.105, 0.10), Vector2(46, 38))
	context.make_road(Vector3(0, 0.02, 1), Vector3(5.2, 0.05, 34), Color(0.16, 0.15, 0.14))
	for z in [-12.0, -5.0, 3.0, 10.0]:
		context.make_prop_box("RoadEdge", Vector3(-3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
		context.make_prop_box("RoadEdge", Vector3(3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
	for p in [Vector3(-8, 0, -12), Vector3(8, 0, -12), Vector3(-9, 0, 1), Vector3(9, 0, 2)]:
		context.make_pillar(p)
	_make_gatehouse(context, Vector3(0, 0, -14))
	_make_tower(context, Vector3(-8.5, 0, -13.5), 7.5)
	_make_tower(context, Vector3(8.5, 0, -13.5), 7.5)
	_make_distant_keep(context, Vector3(0, 0, -19))
	context.make_loose_role("cart", Vector3(7, 0, 1), Vector3.ONE * 0.72, -18.0)
	context.make_prop_box("BattlefieldRemnant", Vector3(-7, 0.4, 3), Vector3(3.5, 0.8, 1.2), Color(0.16, 0.11, 0.075))
	_make_banner(context, Vector3(-5.5, 3.2, -13.0), Color(0.30, 0.055, 0.045))
	_make_banner(context, Vector3(5.5, 3.2, -13.0), Color(0.30, 0.055, 0.045))
	for p in [Vector3(-4,0,-10.5), Vector3(4,0,-10.5), Vector3(-3.5,0,6), Vector3(3.5,0,6)]:
		context.make_torch(p)
	context.make_light("CastleGateLight", Vector3(0, 4.5, -10), Color(0.58, 0.55, 0.48), 3.0)
	context.make_clue("vargan_mile_marker", "Inspect the worn Vargan marker", Vector3(-3.8, 0, 7), "main_blood_under_stone", "evidence_mile_marker", Color(0.34, 0.33, 0.30))
	context.make_clue("vargan_supply_cart", "Inspect the broken military cart", Vector3(7, 0, 1), "main_blood_under_stone", "evidence_supply_cart", Color(0.32, 0.23, 0.14))
	context.make_zone_gate("Return to the bandit road", Vector3(-7, 0, 16), "bandit_road", Vector3(0, 1, -12))
	context.make_zone_gate("Enter Castle Vargan", Vector3(0, 0, -12.2), "vargan_court", Vector3(0, 1, 12))

func _build_courtyard(context: ZoneBuildContext) -> void:
	_base(context, "OuterCourtyard", Color(0.085, 0.082, 0.078), Vector2(46, 38))
	context.make_road(Vector3(0, 0.02, 0), Vector3(8, 0.05, 32), Color(0.14, 0.135, 0.125))
	_make_curtain_walls(context)
	_make_gatehouse(context, Vector3(0, 0, 14))
	for p in [Vector3(-9, 0, -10), Vector3(9, 0, -10), Vector3(-9, 0, 10), Vector3(9, 0, 10)]:
		_make_tower(context, p, 6.0)
	# Stable, forge, cistern, training yard, and servants' stair define the class-divided court.
	context.make_prop_box("BrokenStable", Vector3(-13, 1.5, 1), Vector3(7, 3, 10), Color(0.16, 0.12, 0.085))
	for z in [-2.5, 0.0, 2.5]:
		context.make_prop_box("StableStall", Vector3(-10, 1, z), Vector3(0.25, 2, 2), Color(0.19, 0.13, 0.08))
	context.make_prop_box("Cistern", Vector3(8, 0.55, 3), Vector3(4, 1.1, 4), Color(0.19, 0.19, 0.18))
	for x in [7.0, 10.0, 13.0]:
		context.make_prop_box("WeaponRack", Vector3(x, 1.2, -5), Vector3(0.3, 2.4, 3), Color(0.20, 0.13, 0.075))
	for i in range(4):
		context.make_prop_box("ServantStair", Vector3(-15 + i * 0.8, 0.18 + i * 0.35, -7), Vector3(1.2, 0.35, 4), Color(0.17, 0.17, 0.16))
	for p in [Vector3(-5,0,10), Vector3(5,0,10), Vector3(-6,0,-10), Vector3(6,0,-10)]:
		context.make_torch(p)
	context.make_light("CourtyardColdLight", Vector3(0, 5, 0), Color(0.44, 0.48, 0.55), 2.6)
	context.make_named_interactable("vargan_gate_guard", "dialogue", "Speak to the gate guard", Vector3(-2.7, 0, 10.5), Color(0.28, 0.30, 0.33))
	context.make_named_interactable("vargan_steward", "dialogue", "Speak to the castle steward", Vector3(2.5, 0, -4), Color(0.30, 0.25, 0.20))
	var quality := context.quality_preset()
	if quality != "potato":
		context.make_named_interactable("vargan_servant", "dialogue", "Speak to the tired servant", Vector3(-10, 0, 4), Color(0.27, 0.22, 0.18))
		var patrol = context.make_named_interactable("vargan_patrol", "dialogue", "Hail the patrolling guard", Vector3(9, 0, -2), Color(0.25, 0.27, 0.30))
		if patrol != null:
			var routine := CastlePatrol.new()
			routine.name = "CastleGuardPatrolRoutine"
			patrol.add_child(routine)
			routine.configure(patrol)
	if quality == "quality":
		_make_banner(context, Vector3(-20.2, 3.5, -6), Color(0.25, 0.04, 0.035))
		_make_banner(context, Vector3(20.2, 3.5, -6), Color(0.25, 0.04, 0.035))
		context.make_fog_sheet(Vector3(0, 0.7, -3), Vector3(28, 1, 11), Color(0.10, 0.11, 0.12, 0.12))
	context.make_clue("vargan_gate_notice", "Read the gatehouse closure notice", Vector3(3.8, 0, 10), "main_blood_under_stone", "evidence_gate_notice", Color(0.36, 0.31, 0.23))
	context.make_clue("vargan_iron_binding", "Inspect the blackened binding wire", Vector3(-4, 0, -6), "main_blood_under_stone", "evidence_iron_binding", Color(0.22, 0.20, 0.18))
	context.make_zone_gate("Leave through the outer gate", Vector3(-7, 0, 16), "vargan_approach", Vector3(0, 1, -11))
	context.make_zone_gate("Enter the record hall", Vector3(0, 0, -14), "record_hall", Vector3(0, 1, 12))

func _build_record_hall(context: ZoneBuildContext) -> void:
	_base(context, "RecordHall", Color(0.072, 0.065, 0.058), Vector2(34, 30))
	context.make_road(Vector3(0, 0.02, 0), Vector3(7, 0.05, 26), Color(0.12, 0.105, 0.09))
	for x in [-14.0, 14.0]:
		context.make_prop_box("RecordHallWall", Vector3(x, 3, 0), Vector3(1, 6, 30), Color(0.13, 0.125, 0.12))
	for z in [-14.0, 14.0]:
		context.make_prop_box("RecordHallWall", Vector3(0, 3, z), Vector3(28, 6, 1), Color(0.13, 0.125, 0.12))
	# The archive is enclosed rather than opening onto the outdoor sky. Rafters,
	# a dark ceiling, and a warm ledger pool make the room read as architecture.
	context.make_visual_box("RecordHallCeiling", Vector3(0, 6.35, 0), Vector3(28, 0.28, 30), Color(0.035, 0.032, 0.030))
	for x in [-10.5, -3.5, 3.5, 10.5]:
		context.make_visual_box("RecordHallRafter", Vector3(x, 6.05, 0), Vector3(0.24, 0.34, 28), Color(0.16, 0.10, 0.055))
	for z in [-11.0, 11.0]:
		for x in [-9.0, 0.0, 9.0]:
			context.make_visual_box("RecordHallWallBand", Vector3(x, 4.8, z), Vector3(4.6, 0.16, 0.10), Color(0.28, 0.22, 0.15))
	for x in [-9.0, -5.5, 5.5, 9.0]:
		for z in [-7.0, -2.0, 3.0, 8.0]:
			context.make_prop_box("LedgerShelf", Vector3(x, 1.5, z), Vector3(1.0, 3.0, 3.6), Color(0.18, 0.115, 0.065))
	for p in [Vector3(-3, 0, -4), Vector3(3, 0, -4), Vector3(-3, 0, 5), Vector3(3, 0, 5)]:
		context.make_pillar(p)
	context.make_prop_box("SealedLedgerTable", Vector3(0, 0.8, -8), Vector3(4.2, 1.6, 2.2), Color(0.22, 0.14, 0.075))
	_make_banner(context, Vector3(-4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	_make_banner(context, Vector3(4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	for p in [Vector3(-3,0,10), Vector3(3,0,10), Vector3(-3,0,-6), Vector3(3,0,-6)]:
		context.make_torch(p)
	context.make_light("LedgerTableLight", Vector3(0, 3.5, -7), Color(0.62, 0.50, 0.34), 3.0)
	context.make_light("RecordHallNavigationFill", Vector3(0, 4.5, 4), Color(0.40, 0.46, 0.58), 2.2)
	context.make_named_interactable("vargan_record_keeper", "dialogue", "Speak to the record keeper", Vector3(-4, 0, 9), Color(0.28, 0.24, 0.20))
	context.make_named_interactable("edric_castle", "dialogue", "Address Lord Edric", Vector3(0, 0, -11), Color(0.32, 0.24, 0.18))
	if not bool(context.get_story_flag("vargan_ledger_choice_made", false)):
		context.make_named_interactable("vargan_ledger_choice", "dialogue", "Examine the sealed command ledger", Vector3(0, 0, -7.5), Color(0.48, 0.38, 0.20), Vector3(0.55, 0.45, 0.55))
	if bool(context.get_story_flag("vargan_ledger_choice_made", false)) and not bool(context.get_story_flag("castle_haunting_cleared", false)):
		var enemy = context.spawn_enemy("wychwood_stalker", Vector3(0, 0.8, -1))
		if enemy != null:
			enemy.name = "RecordHallHaunting"
			enemy.leash_radius = 8.0
	if bool(context.get_story_flag("castle_haunting_cleared", false)) and str(context.get_story_flag("edric_stance", "")) == "":
		context.make_named_interactable("edric_campaign", "dialogue", "Demand Lord Edric's answer", Vector3(0, 0, -10.5), Color(0.34, 0.23, 0.16))
	context.make_zone_gate("Return to the outer courtyard", Vector3(-6, 0, 13), "vargan_court", Vector3(0, 1, -11))
	if bool(context.get_story_flag("castle_haunting_cleared", false)):
		context.make_zone_gate("Descend toward the last witness", Vector3(6, 0, -13), "undercroft", Vector3(0, 1, 12))

func _make_gatehouse(context: ZoneBuildContext, pos: Vector3) -> void:
	var landmark := Node3D.new()
	landmark.name = "VarganGatehouse"
	landmark.position = pos
	landmark.set_meta("authored_bounds", Vector3(17, 7, 3))
	context.add_node(landmark)
	# Keep the central passage physically open. A single shell plus a black
	# opening used to create a convincing-looking wall that blocked the player.
	context.make_prop_box("VarganGatehouseLeft", pos + Vector3(-5.8, 3.5, 0), Vector3(5.4, 7, 3), Color(0.145, 0.145, 0.15))
	context.make_prop_box("VarganGatehouseRight", pos + Vector3(5.8, 3.5, 0), Vector3(5.4, 7, 3), Color(0.145, 0.145, 0.15))
	context.make_prop_box("VarganGatehouseLintel", pos + Vector3(0, 6.0, 0), Vector3(5.8, 2.0, 3), Color(0.145, 0.145, 0.15))
	for x in [-2.2, -1.1, 0.0, 1.1, 2.2]:
		# Raised bars are presentation only; the gate Area3D owns travel.
		context.make_visual_box("RaisedPortcullis", pos + Vector3(x, 5.0, 1.2), Vector3(0.16, 2.0, 0.18), Color(0.10, 0.09, 0.075))

func _make_tower(context: ZoneBuildContext, pos: Vector3, height: float) -> void:
	var stone := Color(0.14, 0.14, 0.145)
	context.make_prop_box("CrackedVarganTower", pos + Vector3(0, height * 0.5, 0), Vector3(5, height, 5), stone)
	_make_visual_cylinder(context, "RoundVarganTower", pos + Vector3(0, height * 0.5, 0), 3.25, height * 0.96, stone.lightened(0.035))
	_make_visual_cylinder(context, "TowerStoneBand", pos + Vector3(0, height * 0.72, 0), 3.30, 0.18, Color(0.20, 0.19, 0.18))
	_make_visual_cylinder(context, "TowerCrown", pos + Vector3(0, height + 0.08, 0), 3.45, 0.18, Color(0.105, 0.105, 0.11))
	for x in [-1.8, 0.0, 1.8]:
		context.make_visual_box("TowerMerlon", pos + Vector3(x, height + 0.6, 0), Vector3(0.82, 1.1, 0.78), Color(0.13, 0.13, 0.135))
	for z in [-2.58, 2.58]:
		context.make_visual_box("TowerArrowSlit", pos + Vector3(0, height * 0.56, z), Vector3(0.30, 1.18, 0.06), Color(0.025, 0.022, 0.020))

func _make_distant_keep(context: ZoneBuildContext, pos: Vector3) -> void:
	var stone := Color(0.115, 0.115, 0.12)
	context.make_prop_box("CastleKeepCore", pos + Vector3(0, 4.4, 0), Vector3(11.0, 8.8, 4.0), stone)
	_make_visual_cylinder(context, "CastleKeepLeftTower", pos + Vector3(-5.6, 3.6, 0), 2.35, 7.2, stone.lightened(0.025))
	_make_visual_cylinder(context, "CastleKeepRightTower", pos + Vector3(5.6, 3.6, 0), 2.35, 7.2, stone.lightened(0.025))
	context.make_visual_box("CastleKeepRoofline", pos + Vector3(0, 8.9, 0), Vector3(12.4, 0.35, 4.5), Color(0.075, 0.068, 0.065))
	for x in [-4.4, -2.2, 0.0, 2.2, 4.4]:
		context.make_visual_box("KeepMerlon", pos + Vector3(x, 9.7, 0), Vector3(0.78, 1.0, 0.82), Color(0.095, 0.092, 0.09))
	context.make_visual_box("KeepGateShadow", pos + Vector3(0, 2.2, -2.04), Vector3(2.1, 4.0, 0.06), Color(0.025, 0.022, 0.020))

func _make_visual_cylinder(context: ZoneBuildContext, node_name: String, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 2
	node.mesh = mesh
	node.position = pos
	node.material_override = context.make_material(color)
	context.add_node(node)

func _make_curtain_walls(context: ZoneBuildContext) -> void:
	context.make_prop_box("VarganNorthWall", Vector3(0, 3, -16), Vector3(44, 6, 1.4), Color(0.135, 0.135, 0.14))
	context.make_prop_box("VarganWestWall", Vector3(-21, 3, 0), Vector3(1.4, 6, 32), Color(0.13, 0.13, 0.135))
	context.make_prop_box("VarganEastWall", Vector3(21, 3, 0), Vector3(1.4, 6, 32), Color(0.13, 0.13, 0.135))

func _make_banner(context: ZoneBuildContext, pos: Vector3, color: Color) -> void:
	context.make_prop_box("WornVarganBanner", pos, Vector3(1.6, 3.2, 0.08), color)
	context.make_prop_box("BannerIronBar", pos + Vector3(0, 1.8, 0), Vector3(2.1, 0.10, 0.12), Color(0.08, 0.075, 0.065))
