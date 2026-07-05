extends RefCounted

const CastlePatrol = preload("res://scripts/castle_patrol.gd")
const CASTLE_ZONES := ["vargan_approach", "vargan_court", "record_hall"]

func build(host: Node, zone_id: String) -> void:
	match zone_id:
		"vargan_approach": _build_approach(host)
		"vargan_court": _build_courtyard(host)
		"record_hall": _build_record_hall(host)

func _base(host: Node, zone_id: String, ground_color: Color, size := Vector2(44, 34)) -> void:
	host.call("_make_ground", Vector3(0, -0.08, 0), Vector3(size.x, 0.16, size.y), ground_color)
	host.call("_make_play_area_bounds", size.x, size.y, ground_color.darkened(0.38))
	var marker := Node3D.new()
	marker.name = "CastleVargan_%s" % zone_id
	host.zone_root.add_child(marker)

func _build_approach(host: Node) -> void:
	_base(host, "Approach", Color(0.105, 0.105, 0.10), Vector2(46, 38))
	host.call("_make_road", Vector3(0, 0.02, 1), Vector3(5.2, 0.05, 34), Color(0.16, 0.15, 0.14))
	for z in [-12.0, -5.0, 3.0, 10.0]:
		host.call("_make_prop_box", "RoadEdge", Vector3(-3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
		host.call("_make_prop_box", "RoadEdge", Vector3(3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
	for p in [Vector3(-8, 0, -12), Vector3(8, 0, -12), Vector3(-9, 0, 1), Vector3(9, 0, 2)]:
		host.call("_make_pillar", p)
	_make_gatehouse(host, Vector3(0, 0, -14))
	_make_tower(host, Vector3(-8.5, 0, -13.5), 7.5)
	_make_tower(host, Vector3(8.5, 0, -13.5), 7.5)
	host.call("_make_prop_box", "CastleDistantKeep", Vector3(0, 8, -19), Vector3(15, 16, 5), Color(0.115, 0.115, 0.12))
	host.call("_make_loose_role", "cart", Vector3(7, 0, 1), Vector3.ONE * 0.72, -18.0)
	host.call("_make_prop_box", "BattlefieldRemnant", Vector3(-7, 0.4, 3), Vector3(3.5, 0.8, 1.2), Color(0.16, 0.11, 0.075))
	_make_banner(host, Vector3(-5.5, 3.2, -13.0), Color(0.30, 0.055, 0.045))
	_make_banner(host, Vector3(5.5, 3.2, -13.0), Color(0.30, 0.055, 0.045))
	for p in [Vector3(-4,0,-10.5), Vector3(4,0,-10.5), Vector3(-3.5,0,6), Vector3(3.5,0,6)]: host.call("_make_torch", p)
	host.call("_make_light", "CastleGateLight", Vector3(0, 4.5, -10), Color(0.58, 0.55, 0.48), 3.0)
	host.call("_make_clue", "vargan_mile_marker", "Inspect the worn Vargan marker", Vector3(-3.8, 0, 7), "main_blood_under_stone", "evidence_mile_marker", Color(0.34, 0.33, 0.30))
	host.call("_make_clue", "vargan_supply_cart", "Inspect the broken military cart", Vector3(7, 0, 1), "main_blood_under_stone", "evidence_supply_cart", Color(0.32, 0.23, 0.14))
	host.call("_make_zone_gate", "Return to the bandit road", Vector3(-7, 0, 16), "bandit_road", Vector3(0, 1, -12))
	host.call("_make_zone_gate", "Enter Castle Vargan", Vector3(0, 0, -12.2), "vargan_court", Vector3(0, 1, 12))

func _build_courtyard(host: Node) -> void:
	_base(host, "OuterCourtyard", Color(0.085, 0.082, 0.078), Vector2(46, 38))
	host.call("_make_road", Vector3(0, 0.02, 0), Vector3(8, 0.05, 32), Color(0.14, 0.135, 0.125))
	_make_curtain_walls(host)
	_make_gatehouse(host, Vector3(0, 0, 14))
	for p in [Vector3(-9, 0, -10), Vector3(9, 0, -10), Vector3(-9, 0, 10), Vector3(9, 0, 10)]:
		_make_tower(host, p, 6.0)
	# Stable, forge, cistern, training yard, and servants' stair define the class-divided court.
	host.call("_make_prop_box", "BrokenStable", Vector3(-13, 1.5, 1), Vector3(7, 3, 10), Color(0.16, 0.12, 0.085))
	for z in [-2.5, 0.0, 2.5]: host.call("_make_prop_box", "StableStall", Vector3(-10, 1, z), Vector3(0.25, 2, 2), Color(0.19, 0.13, 0.08))
	host.call("_make_prop_box", "Cistern", Vector3(8, 0.55, 3), Vector3(4, 1.1, 4), Color(0.19, 0.19, 0.18))
	for x in [7.0, 10.0, 13.0]: host.call("_make_prop_box", "WeaponRack", Vector3(x, 1.2, -5), Vector3(0.3, 2.4, 3), Color(0.20, 0.13, 0.075))
	for i in range(4): host.call("_make_prop_box", "ServantStair", Vector3(-15 + i * 0.8, 0.18 + i * 0.35, -7), Vector3(1.2, 0.35, 4), Color(0.17, 0.17, 0.16))
	for p in [Vector3(-5,0,10), Vector3(5,0,10), Vector3(-6,0,-10), Vector3(6,0,-10)]: host.call("_make_torch", p)
	host.call("_make_light", "CourtyardColdLight", Vector3(0, 5, 0), Color(0.44, 0.48, 0.55), 2.6)
	host.call("_make_named_interactable", "vargan_gate_guard", "dialogue", "Speak to the gate guard", Vector3(-2.7, 0, 10.5), Color(0.28, 0.30, 0.33))
	host.call("_make_named_interactable", "vargan_steward", "dialogue", "Speak to the castle steward", Vector3(2.5, 0, -4), Color(0.30, 0.25, 0.20))
	var quality := str(host.settings.settings.get("quality_preset", "balanced"))
	if quality != "potato":
		host.call("_make_named_interactable", "vargan_servant", "dialogue", "Speak to the tired servant", Vector3(-10, 0, 4), Color(0.27, 0.22, 0.18))
		var patrol = host.call("_make_named_interactable", "vargan_patrol", "dialogue", "Hail the patrolling guard", Vector3(9, 0, -2), Color(0.25, 0.27, 0.30))
		if patrol != null:
			var routine := CastlePatrol.new()
			routine.name = "CastleGuardPatrolRoutine"
			patrol.add_child(routine)
			routine.configure(patrol)
	if quality == "quality":
		_make_banner(host, Vector3(-20.2, 3.5, -6), Color(0.25, 0.04, 0.035))
		_make_banner(host, Vector3(20.2, 3.5, -6), Color(0.25, 0.04, 0.035))
		host.call("_make_fog_sheet", Vector3(0, 0.7, -3), Vector3(28, 1, 11), Color(0.10, 0.11, 0.12, 0.12))
	host.call("_make_clue", "vargan_gate_notice", "Read the gatehouse closure notice", Vector3(3.8, 0, 10), "main_blood_under_stone", "evidence_gate_notice", Color(0.36, 0.31, 0.23))
	host.call("_make_clue", "vargan_iron_binding", "Inspect the blackened binding wire", Vector3(-4, 0, -6), "main_blood_under_stone", "evidence_iron_binding", Color(0.22, 0.20, 0.18))
	host.call("_make_zone_gate", "Leave through the outer gate", Vector3(-7, 0, 16), "vargan_approach", Vector3(0, 1, -11))
	host.call("_make_zone_gate", "Enter the record hall", Vector3(0, 0, -14), "record_hall", Vector3(0, 1, 12))

func _build_record_hall(host: Node) -> void:
	_base(host, "RecordHall", Color(0.072, 0.065, 0.058), Vector2(34, 30))
	host.call("_make_road", Vector3(0, 0.02, 0), Vector3(7, 0.05, 26), Color(0.12, 0.105, 0.09))
	for x in [-14.0, 14.0]: host.call("_make_prop_box", "RecordHallWall", Vector3(x, 3, 0), Vector3(1, 6, 30), Color(0.13, 0.125, 0.12))
	for z in [-14.0, 14.0]: host.call("_make_prop_box", "RecordHallWall", Vector3(0, 3, z), Vector3(28, 6, 1), Color(0.13, 0.125, 0.12))
	for x in [-9.0, -5.5, 5.5, 9.0]:
		for z in [-7.0, -2.0, 3.0, 8.0]: host.call("_make_prop_box", "LedgerShelf", Vector3(x, 1.5, z), Vector3(1.0, 3.0, 3.6), Color(0.18, 0.115, 0.065))
	for p in [Vector3(-3, 0, -4), Vector3(3, 0, -4), Vector3(-3, 0, 5), Vector3(3, 0, 5)]: host.call("_make_pillar", p)
	host.call("_make_prop_box", "SealedLedgerTable", Vector3(0, 0.8, -8), Vector3(4.2, 1.6, 2.2), Color(0.22, 0.14, 0.075))
	_make_banner(host, Vector3(-4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	_make_banner(host, Vector3(4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	for p in [Vector3(-3,0,10), Vector3(3,0,10), Vector3(-3,0,-6), Vector3(3,0,-6)]: host.call("_make_torch", p)
	host.call("_make_light", "LedgerTableLight", Vector3(0, 3.5, -7), Color(0.62, 0.50, 0.34), 3.0)
	host.call("_make_named_interactable", "vargan_record_keeper", "dialogue", "Speak to the record keeper", Vector3(-4, 0, 9), Color(0.28, 0.24, 0.20))
	host.call("_make_named_interactable", "edric_castle", "dialogue", "Address Lord Edric", Vector3(0, 0, -11), Color(0.32, 0.24, 0.18))
	if not bool(host.story_state.get_flag("vargan_ledger_choice_made", false)):
		host.call("_make_named_interactable", "vargan_ledger_choice", "dialogue", "Examine the sealed command ledger", Vector3(0, 0, -7.5), Color(0.48, 0.38, 0.20), Vector3(0.55, 0.45, 0.55))
	if bool(host.story_state.get_flag("vargan_ledger_choice_made", false)) and not bool(host.story_state.get_flag("castle_haunting_cleared", false)):
		var enemy = host.call("_spawn_enemy", "wychwood_stalker", Vector3(0, 0.8, -1))
		if enemy != null:
			enemy.name = "RecordHallHaunting"
			enemy.leash_radius = 8.0
	host.call("_make_zone_gate", "Return to the outer courtyard", Vector3(-6, 0, 13), "vargan_court", Vector3(0, 1, -11))
	if bool(host.story_state.get_flag("castle_haunting_cleared", false)):
		host.call("_make_zone_gate", "Descend toward the last witness", Vector3(6, 0, -13), "undercroft", Vector3(0, 1, 12))

func _make_gatehouse(host: Node, pos: Vector3) -> void:
	host.call("_make_prop_box", "VarganGatehouse", pos + Vector3(0, 3.5, 0), Vector3(17, 7, 3), Color(0.145, 0.145, 0.15))
	host.call("_make_prop_box", "GateOpening", pos + Vector3(0, 2.2, 1.6), Vector3(5, 4.4, 0.5), Color(0.035, 0.032, 0.03))
	for x in [-2.2, -1.1, 0.0, 1.1, 2.2]: host.call("_make_prop_box", "Portcullis", pos + Vector3(x, 2.2, 1.2), Vector3(0.16, 4.4, 0.18), Color(0.10, 0.09, 0.075))

func _make_tower(host: Node, pos: Vector3, height: float) -> void:
	host.call("_make_prop_box", "CrackedVarganTower", pos + Vector3(0, height * 0.5, 0), Vector3(5, height, 5), Color(0.14, 0.14, 0.145))
	for x in [-1.8, 0.0, 1.8]: host.call("_make_prop_box", "TowerMerlon", pos + Vector3(x, height + 0.6, 0), Vector3(1.0, 1.2, 5), Color(0.13, 0.13, 0.135))

func _make_curtain_walls(host: Node) -> void:
	host.call("_make_prop_box", "VarganNorthWall", Vector3(0, 3, -16), Vector3(44, 6, 1.4), Color(0.135, 0.135, 0.14))
	host.call("_make_prop_box", "VarganWestWall", Vector3(-21, 3, 0), Vector3(1.4, 6, 32), Color(0.13, 0.13, 0.135))
	host.call("_make_prop_box", "VarganEastWall", Vector3(21, 3, 0), Vector3(1.4, 6, 32), Color(0.13, 0.13, 0.135))

func _make_banner(host: Node, pos: Vector3, color: Color) -> void:
	host.call("_make_prop_box", "WornVarganBanner", pos, Vector3(1.6, 3.2, 0.08), color)
	host.call("_make_prop_box", "BannerIronBar", pos + Vector3(0, 1.8, 0), Vector3(2.1, 0.10, 0.12), Color(0.08, 0.075, 0.065))
