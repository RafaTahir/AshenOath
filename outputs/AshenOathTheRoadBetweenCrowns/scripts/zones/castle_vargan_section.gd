extends RefCounted

const CastlePatrol = preload("res://scripts/castle_patrol.gd")
const WorldMaterialLibrary = preload("res://scripts/world_material_library.gd")
const RecordArchive = preload("res://assets_external/environment/props/RecordArchive_Authored.res")
const VarganGatehouse = preload("res://assets_external/environment/village/Vargan_gatehouse_Authored.res")
const VarganTower = preload("res://assets_external/environment/village/Vargan_tower_Authored.res")
const VarganKeep = preload("res://assets_external/environment/village/Vargan_keep_Authored.res")
const VarganCurtain = preload("res://assets_external/environment/village/Vargan_curtain_Authored.res")
const VarganStable = preload("res://assets_external/environment/village/Vargan_stable_Authored.res")
const VarganCistern = preload("res://assets_external/environment/village/Vargan_cistern_Authored.res")
const VarganDoor = preload("res://assets_external/environment/village/Vargan_door_Authored.res")
const VarganForge = preload("res://assets_external/environment/village/Vargan_forge_Authored.res")
const VarganRecordEntry = preload("res://assets_external/environment/village/Vargan_record_entry_Authored.res")
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

func _make_castle_route_surface(context: ZoneBuildContext, zone_id: String) -> void:
	var width := 5.2 if zone_id == "vargan_approach" else 8.0
	var road := MeshInstance3D.new()
	road.name = "VarganStoneRoad"
	road.mesh = WorldMaterialLibrary.make_tiled_box(Vector3(width, 0.012, 32), Vector3(0, 0.054, 0))
	road.position.y = 0.054
	road.material_override = context.make_world_material("cobblestone", Color(0.62, 0.67, 0.67))
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(road)

func _build_approach(context: ZoneBuildContext) -> void:
	_base(context, "Approach", Color(0.105, 0.105, 0.10), Vector2(46, 38))
	context.make_road(Vector3(0, 0.02, 1), Vector3(5.2, 0.05, 34), Color(0.16, 0.15, 0.14))
	_make_castle_route_surface(context, "vargan_approach")
	_make_authored_approach_dressing(context)
	_make_approach_dressing(context)
	for z in [-12.0, -5.0, 3.0, 10.0]:
		context.make_prop_box("RoadEdge", Vector3(-3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
		context.make_prop_box("RoadEdge", Vector3(3.0, 0.12, z), Vector3(0.7, 0.24, 5.5), Color(0.09, 0.085, 0.08))
	for p in [Vector3(-8, 0, -12), Vector3(8, 0, -12), Vector3(-9, 0, 1), Vector3(9, 0, 2)]:
		context.make_pillar(p)
	_make_gatehouse(context, Vector3(0, 0, -14))
	_make_tower(context, Vector3(-8.5, 0, -13.5), 7.5)
	_make_tower(context, Vector3(8.5, 0, -13.5), 7.5)
	_make_distant_keep(context, Vector3(0, 0, -25))
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
	_make_castle_door(context, "Enter Castle Vargan", Vector3(0, 0, -12.2), "vargan_court", Vector3(0, 1, 12))

func _build_courtyard(context: ZoneBuildContext) -> void:
	_base(context, "OuterCourtyard", Color(0.085, 0.082, 0.078), Vector2(46, 38))
	context.make_road(Vector3(0, 0.02, 0), Vector3(8, 0.05, 32), Color(0.14, 0.135, 0.125))
	_make_castle_route_surface(context, "vargan_court")
	_make_courtyard_dressing(context)
	_make_authored_courtyard_dressing(context)
	_make_curtain_walls(context)
	_make_gatehouse(context, Vector3(0, 0, 14))
	for p in [Vector3(-9, 0, -10), Vector3(9, 0, -10), Vector3(-9, 0, 10), Vector3(9, 0, 10)]:
		_make_tower(context, p, 6.0)
	# Stable, forge, cistern, training yard, and servants' stair define the class-divided court.
	context.make_reserved_collision_box("BrokenStable", Vector3(-13, 1.5, 1), Vector3(7, 3, 10))
	_make_architecture(context, "VarganAuthoredStable", VarganStable, Vector3(-13, 0, 1))
	for z in [-2.5, 0.0, 2.5]:
		context.make_prop_box("StableStall", Vector3(-10, 1, z), Vector3(0.25, 2, 2), Color(0.19, 0.13, 0.08))
	context.make_reserved_collision_box("Cistern", Vector3(8, 0.55, 3), Vector3(4, 1.1, 4))
	_make_architecture(context, "VarganAuthoredCistern", VarganCistern, Vector3(8, 0, 3))
	context.make_visual_box("CisternWater", Vector3(8, 1.13, 3), Vector3(3.25, 0.035, 3.25), Color(0.08, 0.18, 0.20))
	for i in range(4):
		context.make_prop_box("ServantStair", Vector3(-15 + i * 0.8, 0.18 + i * 0.35, -7), Vector3(1.2, 0.35, 4), Color(0.17, 0.17, 0.16))
	for p in [Vector3(-5,0,10), Vector3(5,0,10), Vector3(-6,0,-10), Vector3(6,0,-10)]:
		context.make_torch(p)
	context.make_light("CourtyardColdLight", Vector3(0, 5, 0), Color(0.44, 0.48, 0.55), 2.6)
	context.make_named_interactable("vargan_gate_guard", "dialogue", "Speak to the gate guard", Vector3(-2.7, 0, 10.5), Color(0.28, 0.30, 0.33))
	context.make_named_interactable("vargan_steward", "dialogue", "Speak to the castle steward", Vector3(2.5, 0, -4), Color(0.30, 0.25, 0.20))
	var quality := context.quality_preset()
	if quality != "potato":
		context.make_named_interactable("vargan_servant", "dialogue", "Speak to the tired servant", Vector3(-8, 0, 4), Color(0.27, 0.22, 0.18))
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
	# The gate sits outside the gatehouse's left wing. Keeping the threshold
	# clear gives the return route a straight, player-sized approach instead of
	# asking the player to walk through the solid wing collision.
	_make_castle_door(context, "Leave through the outer gate", Vector3(-10.5, 0, 16), "vargan_approach", Vector3(0, 1, -11))
	_make_castle_door(context, "Enter the record hall", Vector3(0, 0, -14), "record_hall", Vector3(0, 1, 12))

func _build_record_hall(context: ZoneBuildContext) -> void:
	# Extend the floor beyond the raised entry camera so its far box edge cannot
	# project as a dark horizontal strip across the archive aisle.
	_base(context, "RecordHall", Color(0.090, 0.077, 0.064), Vector2(34, 40))
	var aisle := MeshInstance3D.new()
	aisle.name = "RecordHallStoneAisle"
	aisle.mesh = WorldMaterialLibrary.make_tiled_box(Vector3(7, 0.012, 26), Vector3(0, 0.034, 0))
	aisle.position.y = 0.034
	aisle.material_override = context.make_world_material("medieval_brick", Color(0.54, 0.54, 0.51))
	aisle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(aisle)
	_make_record_hall_dressing(context)
	_make_record_hall_vault(context)
	_make_authored_record_hall_dressing(context)
	_make_record_witness_memorial(context)
	# The invisible play-area boundary supplies the room edge. Do not add a
	# visible side shell here: even a low plinth projects as a dark slab from
	# the entry camera and hides the archive aisle.
	# The room boundary is already protected by the invisible play-area wall.
	# Avoid a second full-width rear shell here: from the entry aisle it reads as
	# a black slab instead of architecture and hides the archive sightline.
	# Keep the archive camera-safe. Long ceiling, rear, and head-height framing
	# pieces projected as dark slabs across the aisle from the raised entry view.
	# The imported bookcases below own the visible archive stacks. The former
	# solid box shelves hid them and made the hall read as a row of brown blocks.
	context.make_prop_box("SealedLedgerTable", Vector3(0, 0.8, -8), Vector3(4.2, 1.6, 2.2), Color(0.22, 0.14, 0.075))
	for x in [-1.25, -0.82, -0.38, 0.42, 0.86, 1.24]:
		context.make_visual_box("LedgerVisiblePage", Vector3(x, 0.86, -8.02), Vector3(0.22, 0.07, 0.48), Color(0.68, 0.59, 0.39))
	var ledger_state := ""
	if bool(context.get_story_flag("vargan_ledger_taken_openly", false)):
		ledger_state = "open"
	elif bool(context.get_story_flag("vargan_ledger_hidden", false)):
		ledger_state = "hidden"
	elif bool(context.get_story_flag("vargan_ledger_left_copied", false)):
		ledger_state = "copied"
	if ledger_state == "open":
		context.make_visual_box("LedgerBrokenVarganSeal", Vector3(0, 0.89, -8.0), Vector3(0.82, 0.10, 0.42), Color(0.42, 0.16, 0.09))
	elif ledger_state == "hidden":
		context.make_visual_box("LedgerDustGap", Vector3(0, 0.86, -8.0), Vector3(0.62, 0.06, 0.28), Color(0.12, 0.08, 0.05))
	elif ledger_state == "copied":
		context.make_visual_box("LedgerCopiedSeal", Vector3(0, 0.88, -8.0), Vector3(0.70, 0.08, 0.34), Color(0.32, 0.24, 0.14))
	_make_banner(context, Vector3(-4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	_make_banner(context, Vector3(4.8, 3.0, -13.3), Color(0.27, 0.045, 0.04))
	# Reserve the small Compatibility light budget for the archive itself before
	# adding torch decoration. The old order let four torch lights consume the
	# budget, leaving the room ceiling and shelves effectively unlit.
	context.make_light("LedgerTableLight", Vector3(0, 3.5, -7), Color(0.62, 0.50, 0.34), 3.0)
	context.make_light("RecordHallNavigationFill", Vector3(0, 4.8, 4), Color(0.46, 0.52, 0.66), 3.2)
	context.make_light("RecordHallEntryFill", Vector3(0, 3.8, 10), Color(0.52, 0.42, 0.31), 2.4)
	context.make_light("RecordHallArchiveFill", Vector3(-8, 3.8, 1), Color(0.34, 0.40, 0.52), 2.0)
	for p in [Vector3(-3,0,10), Vector3(3,0,10), Vector3(-3,0,-6), Vector3(3,0,-6)]:
		context.make_torch(p)
	context.make_named_interactable("vargan_record_keeper", "dialogue", "Speak to the record keeper", Vector3(-4, 0, 9), Color(0.28, 0.24, 0.20))
	var edric_testimony_pending := bool(context.get_story_flag("castle_haunting_cleared", false)) and str(context.get_story_flag("edric_stance", "")) == ""
	if not edric_testimony_pending:
		context.make_named_interactable("edric_castle", "dialogue", "Address Lord Edric", Vector3(0, 0, -11), Color(0.32, 0.24, 0.18))
	if not bool(context.get_story_flag("vargan_ledger_choice_made", false)):
		context.make_named_interactable("vargan_ledger_choice", "dialogue", "Examine the sealed command ledger", Vector3(0, 0, -7.5), Color(0.48, 0.38, 0.20), Vector3(0.55, 0.45, 0.55))
	if bool(context.get_story_flag("vargan_ledger_choice_made", false)) and not bool(context.get_story_flag("castle_haunting_cleared", false)):
		var enemy = context.spawn_enemy("wychwood_stalker", Vector3(0, 0.8, -1), "ghoulkin_creature")
		if enemy != null:
			enemy.name = "RecordHallHaunting"
			enemy.leash_radius = 8.0
	if edric_testimony_pending:
		context.make_named_interactable("edric_campaign", "dialogue", "Demand Lord Edric's answer", Vector3(0, 0, -10.5), Color(0.34, 0.23, 0.16))
	_make_castle_door(context, "Return to the outer courtyard", Vector3(-6, 0, 13), "vargan_court", Vector3(0, 1, -11))
	if bool(context.get_story_flag("castle_haunting_cleared", false)):
		_make_castle_door(context, "Descend toward the last witness", Vector3(6, 0, -13), "undercroft", Vector3(0, 1, 12))

func _make_gatehouse(context: ZoneBuildContext, pos: Vector3) -> void:
	var landmark := Node3D.new()
	landmark.name = "VarganGatehouse"
	landmark.position = pos
	landmark.set_meta("authored_bounds", Vector3(19, 8.2, 3.6))
	context.add_node(landmark)
	# Keep the central passage physically open. A single shell plus a black
	# opening used to create a convincing-looking wall that blocked the player.
	# The old isotropic prop reservation skipped whole wings. The authored mesh
	# now owns matching collision, with its wide central arch and west return open.
	var gate := _make_architecture(context, "VarganAuthoredGatehouse", VarganGatehouse, pos)
	var body := StaticBody3D.new()
	body.name = "AuthoredMasonryCollision"
	var shape := CollisionShape3D.new()
	shape.shape = VarganGatehouse.create_trimesh_shape()
	body.add_child(shape)
	gate.add_child(body)

func _make_castle_door(context: ZoneBuildContext, prompt: String, pos: Vector3, target: String, arrival: Vector3) -> void:
	var area = context.make_zone_gate(prompt, pos, target, arrival)
	if area == null or not bool(area.get_meta("interior_door", false)):
		return
	for name in ["InteriorDoorFrame", "InteriorDoor"]:
		var old := area.get_node_or_null(name) as MeshInstance3D
		if old != null:
			old.visible = false
	if target == "vargan_court" and context.zone_id != "record_hall":
		# The open leaves are part of the gatehouse mesh; retain its interaction.
		return
	if target == "record_hall":
		_make_architecture(context, "VarganRecordHallVestibule", VarganRecordEntry, pos)
		for side in [-1.0, 1.0]:
			context.make_collision_box("RecordVestibuleWing", pos + Vector3(side * 2.5, 1.7, -0.15), Vector3(2.5, 3.4, 0.55))
			context.make_collision_box("RecordVestibuleReturn", pos + Vector3(side * 3.75, 1.7, -1.3), Vector3(0.40, 3.4, 2.8))
		return
	# Keep the existing nonblocking interaction Area and arrival state unchanged.
	_make_architecture(context, "VarganFittedDoor", VarganDoor, pos)

func _make_tower(context: ZoneBuildContext, pos: Vector3, height: float) -> void:
	context.make_reserved_collision_box("CrackedVarganTower", pos + Vector3(0, height * 0.5, 0), Vector3(5, height, 5))
	_make_architecture(context, "VarganAuthoredTower", VarganTower, pos, Vector3(1, height, 1))

func _make_distant_keep(context: ZoneBuildContext, pos: Vector3) -> void:
	# Skyline only: the keep is wholly beyond the existing physical play boundary.
	_make_architecture(context, "VarganAuthoredKeep", VarganKeep, pos)
	for side in [-1.0, 1.0]:
		_make_architecture(context, "VarganKeepFlank", VarganTower, pos + Vector3(side * 5.6, 0, 0), Vector3(0.90, 7.2, 0.90))

func _make_architecture(context: ZoneBuildContext, id: String, source: ArrayMesh, pos: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = source
	node.position = pos
	node.scale = scale_value
	var stone: StandardMaterial3D = null
	if context.zone_root.has_meta("vargan_masonry_material"):
		stone = context.zone_root.get_meta("vargan_masonry_material") as StandardMaterial3D
	if stone == null:
		stone = context.make_world_material("medieval_brick").duplicate() as StandardMaterial3D
		stone.vertex_color_use_as_albedo = true
		context.zone_root.set_meta("vargan_masonry_material", stone)
	node.set_surface_override_material(0, stone)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(node)
	return node

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
	_make_gatehouse(context, Vector3(0, 0, -16))
	_make_distant_keep(context, Vector3(0, 0, -25))
	for side in [-1.0, 1.0]:
		_make_architecture(context, "VarganNorthCurtain", VarganCurtain, Vector3(side * 15.2, 0, -16))
		context.make_collision_box("VarganNorthCurtain", Vector3(side * 15.2, 3, -16), Vector3(11.6, 6, 1.4))
		for z in [-10.6, 0.0, 10.6]:
			_make_architecture(context, "VarganSideCurtain", VarganCurtain, Vector3(side * 21, 0, z), Vector3(1, 1, 0.9)).rotation.y = PI * 0.5
		context.make_collision_box("VarganSideCurtain", Vector3(side * 21, 3, 0), Vector3(1.4, 6, 32))

func _make_banner(context: ZoneBuildContext, pos: Vector3, color: Color) -> void:
	context.make_prop_box("WornVarganBanner", pos, Vector3(1.6, 3.2, 0.08), color)
	context.make_prop_box("BannerIronBar", pos + Vector3(0, 1.8, 0), Vector3(2.1, 0.10, 0.12), Color(0.08, 0.075, 0.065))

func _make_approach_dressing(context: ZoneBuildContext) -> void:
	# The approach is a military road, not an isolated green slab. Low visual
	# bands and waystones add edge rhythm without entering the reserved gate lane.
	for z in [-10.0, -3.0, 4.0, 11.0]:
		context.make_path_stone(Vector3(-5.1, 0.035, z), 0.42)
		context.make_path_stone(Vector3(5.1, 0.035, z + 0.35), 0.36)
	for z in [-9.0, -2.0, 5.0, 12.0]:
		context.make_path_stone(Vector3(-4.2, 0.04, z), 0.72)
		context.make_path_stone(Vector3(4.2, 0.04, z + 0.45), 0.62)
	for side in [-1.0, 1.0]:
		for z in [-9.5, -3.5, 2.5, 8.5]:
			# These outer wall blocks are visual dressing around the military road.
			# Their wide footprints intersect the diagonal edge lane on both the
			# bandit-road arrival and the return trip, so the real boundary walls
			# remain authoritative while these sections stay non-blocking.
			_make_architecture(context, "ApproachCurtainWall", VarganCurtain, Vector3(side * 8.6, 0, z), Vector3(0.53, 0.72, 1.42)).rotation.y = PI * 0.5

func _make_courtyard_dressing(context: ZoneBuildContext) -> void:
	for z in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		context.make_path_stone(Vector3(-8.8, 0.035, z), 0.42)
		context.make_path_stone(Vector3(8.8, 0.035, z + 0.25), 0.36)
	for x in [-6.8, -3.4, 3.4, 6.8]:
		context.make_path_stone(Vector3(x, 0.05, -8.2), 0.70)
		context.make_path_stone(Vector3(x, 0.05, 8.2), 0.64)
	context.make_visual_box("CourtyardTrainingLine", Vector3(7.7, 0.08, -4.8), Vector3(7.4, 0.08, 0.14), Color(0.25, 0.18, 0.10))
	# Give the service court a working rhythm instead of isolated boxes.
	context.make_reserved_collision_box("ForgeBayWall", Vector3(13.0, 1.45, -1.5), Vector3(5.8, 2.9, 0.40))
	context.make_collision_box("ForgeWorktable", Vector3(13.0, 0.415, -1.0), Vector3(2.7, 0.83, 0.72))
	_make_architecture(context, "CourtyardAuthoredForge", VarganForge, Vector3(13, 0, -3))
	for side in [-1.0, 1.0]:
		context.make_collision_box("ForgePost", Vector3(13 + side * 2.8, 1.5, -4.7), Vector3(0.18, 3.0, 0.18))
		context.make_collision_box("ForgeSideWall", Vector3(13 + side * 2.8, 1.45, -2.1), Vector3(0.24, 2.9, 1.6))
	context.make_collision_box("ForgeChimney", Vector3(15.1, 2.4, -2.5), Vector3(0.8, 4.8, 0.8))
	for x in [11.7, 14.3]:
		context.make_reserved_collision_box("ForgeBarrel", Vector3(x, 0.55, 1.0), Vector3(0.78, 1.1, 0.78))
	var service := MeshInstance3D.new()
	service.name = "CourtyardAuthoredServiceGroundAndSupplies"
	service.mesh = load("res://assets_external/environment/village/CourtyardService_Authored.res") as ArrayMesh
	if service.mesh == null:
		push_error("Required courtyard service composition is unavailable")
		service.free()
	else:
		var paving := context.make_world_material("medieval_brick", Color(0.79, 0.79, 0.75)).duplicate() as StandardMaterial3D
		paving.vertex_color_use_as_albedo = true
		service.set_surface_override_material(0, paving)
		service.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		context.add_node(service)
	context.make_visual_box("CourtyardDrainageChannel", Vector3(2.2, 0.065, 5.8), Vector3(0.32, 0.03, 12.0), Color(0.055, 0.070, 0.068))
	for side in [-1.0, 1.0]:
		context.make_visual_box("DrainStoneLip", Vector3(2.2 + side * 0.24, 0.071, 5.8), Vector3(0.14, 0.018, 12.0), Color(0.32, 0.33, 0.31))
	for index in range(48):
		context.make_visual_box("DrainIronGrate", Vector3(2.2, 0.084, -0.075 + index * 0.25), Vector3(0.37, 0.018, 0.10), Color(0.28, 0.30, 0.29))

func _make_record_hall_dressing(context: ZoneBuildContext) -> void:
	# Warm wood, iron, and parchment accents break up the archive’s stone shell.
	for z in [-11.8, -6.0, 0.0, 6.0, 11.8]:
		context.make_visual_box("RecordHallFloorInset", Vector3(0, 0.041, z), Vector3(5.8, 0.008, 0.10), Color(0.22, 0.25, 0.27))
	for x in [-8.8, 8.8]:
		context.make_visual_box("RecordHallLanternGlow", Vector3(x, 3.6, 9.6), Vector3(0.28, 0.52, 0.18), Color(0.70, 0.40, 0.16))
	context.make_visual_box("RecordHallLedgerRunner", Vector3(0, 0.09, -7.0), Vector3(4.8, 0.05, 0.22), Color(0.28, 0.17, 0.08))
	for z in [-5.5, 1.0, 7.5]:
		context.make_prop_box("RecordHallReadingDesk", Vector3(0.0, 0.65, z), Vector3(3.4, 1.3, 0.86), Color(0.22, 0.13, 0.065))
		context.make_prop_box("RecordHallReadingBench", Vector3(0.0, 0.42, z + 1.25), Vector3(2.5, 0.84, 0.42), Color(0.16, 0.095, 0.045))

func _make_record_hall_vault(context: ZoneBuildContext) -> void:
	var ceiling_surface := SurfaceTool.new()
	ceiling_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_surface := SurfaceTool.new()
	wall_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width: float = 16.0
	var south: float = 18.0
	var north: float = -18.0
	for index in range(16):
		var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
		var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
		var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
		var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
		_add_record_hall_triangle(ceiling_surface, Vector3(x0, y0, north), Vector3(x1, y1, north), Vector3(x0, y0, south))
		_add_record_hall_triangle(ceiling_surface, Vector3(x1, y1, north), Vector3(x1, y1, south), Vector3(x0, y0, south))
	for side in [-1.0, 1.0]:
		var x: float = float(side) * half_width
		var a := Vector3(x, 0.0, north)
		var b := Vector3(x, 5.55, north)
		var c := Vector3(x, 0.0, south)
		var d := Vector3(x, 5.55, south)
		if side < 0.0:
			_add_record_hall_triangle(wall_surface, a, b, c)
			_add_record_hall_triangle(wall_surface, b, d, c)
		else:
			_add_record_hall_triangle(wall_surface, a, c, b)
			_add_record_hall_triangle(wall_surface, b, c, d)
	for index in range(16):
		var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
		var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
		var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
		var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
		_add_record_hall_triangle(wall_surface, Vector3(x0, 0.0, north), Vector3(x1, 0.0, north), Vector3(x0, y0, north))
		_add_record_hall_triangle(wall_surface, Vector3(x1, 0.0, north), Vector3(x1, y1, north), Vector3(x0, y0, north))
	var vault_ceiling := MeshInstance3D.new()
	vault_ceiling.name = "RecordHallVaultCeiling"
	vault_ceiling.mesh = ceiling_surface.commit()
	var ceiling_material := context.make_world_material("medieval_brick", Color(0.53, 0.49, 0.43)).duplicate() as StandardMaterial3D
	ceiling_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	vault_ceiling.material_override = ceiling_material
	vault_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(vault_ceiling)
	var vault_walls := MeshInstance3D.new()
	vault_walls.name = "RecordHallVaultWalls"
	vault_walls.mesh = wall_surface.commit()
	var wall_material := context.make_world_material("medieval_brick", Color(0.82, 0.75, 0.67)).duplicate() as StandardMaterial3D
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	vault_walls.material_override = wall_material
	vault_walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(vault_walls)
	_make_record_hall_ribs(context)
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_record_hall_triangle(floor_surface, Vector3(-16.0, 0.014, -18.0), Vector3(-16.0, 0.014, 18.0), Vector3(16.0, 0.014, -18.0))
	_add_record_hall_triangle(floor_surface, Vector3(16.0, 0.014, -18.0), Vector3(-16.0, 0.014, 18.0), Vector3(16.0, 0.014, 18.0))
	var floor_node := MeshInstance3D.new()
	floor_node.name = "RecordHallStoneFloor"
	floor_node.mesh = floor_surface.commit()
	var floor_material := context.make_world_material("medieval_brick", Color(0.54, 0.54, 0.51)).duplicate() as StandardMaterial3D
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	floor_node.material_override = floor_material
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(floor_node)

func _make_record_hall_ribs(context: ZoneBuildContext) -> void:
	var rib_surface := SurfaceTool.new()
	rib_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := 16.0
	for z in [-15.0, -9.0, -3.0, 3.0, 9.0]:
		for index in range(16):
			var x0 := lerpf(-half_width, half_width, float(index) / 16.0)
			var x1 := lerpf(-half_width, half_width, float(index + 1) / 16.0)
			var y0 := 5.55 + 1.65 * (1.0 - pow(x0 / half_width, 2.0))
			var y1 := 5.55 + 1.65 * (1.0 - pow(x1 / half_width, 2.0))
			var a := Vector3(x0, y0 - 0.20, z - 0.18)
			var b := Vector3(x1, y1 - 0.20, z - 0.18)
			var c := Vector3(x0, y0 - 0.20, z + 0.18)
			var d := Vector3(x1, y1 - 0.20, z + 0.18)
			_add_record_hall_triangle(rib_surface, a, b, c)
			_add_record_hall_triangle(rib_surface, b, d, c)
			_add_record_hall_triangle(rib_surface, a, Vector3(x0, y0 + 0.03, z - 0.18), b)
			_add_record_hall_triangle(rib_surface, b, Vector3(x0, y0 + 0.03, z - 0.18), Vector3(x1, y1 + 0.03, z - 0.18))
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 15.82
			_add_record_hall_triangle(rib_surface, Vector3(x, 0.0, z - 0.18), Vector3(x, 5.50, z - 0.18), Vector3(x, 0.0, z + 0.18))
			_add_record_hall_triangle(rib_surface, Vector3(x, 5.50, z - 0.18), Vector3(x, 5.50, z + 0.18), Vector3(x, 0.0, z + 0.18))
	var ribs := MeshInstance3D.new()
	ribs.name = "RecordHallVaultRibs"
	ribs.mesh = rib_surface.commit()
	var rib_material := context.make_world_material("medieval_brick", Color(0.70, 0.66, 0.60)).duplicate() as StandardMaterial3D
	rib_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribs.material_override = rib_material
	ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(ribs)

func _add_record_hall_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		if absf(normal.x) > 0.5:
			surface.set_uv(Vector2(point.z, point.y))
		elif absf(normal.y) > 0.5:
			surface.set_uv(Vector2(point.x, point.z))
		else:
			surface.set_uv(Vector2(point.x, point.y))
		surface.add_vertex(point)

func _make_authored_approach_dressing(context: ZoneBuildContext) -> void:
	# Use the actual medieval kit as architectural punctuation while keeping the
	# existing collision shell and gate coordinates stable.
	for x in [-10.8, 10.8]:
		context.make_fitted_environment_role("castle_wall", Vector3(x, 0, -8.5), Vector3(3.6, 3.6, 0.50), 0.0)
		context.make_fitted_environment_role("castle_wall", Vector3(x, 0, 1.5), Vector3(3.6, 3.6, 0.50), 0.0)

func _make_authored_courtyard_dressing(context: ZoneBuildContext) -> void:
	for pos in [Vector3(-16.0, 0.7, -7.0), Vector3(-16.0, 0.7, 4.0), Vector3(14.8, 0.7, -6.5)]:
		context.make_fitted_environment_role("castle_wall", Vector3(pos.x, 0, pos.z), Vector3(2.5, 2.5, 0.40), 90.0)
	for pos in [Vector3(7.0, 0.0, -5.4), Vector3(10.0, 0.0, -5.4), Vector3(13.0, 0.0, -5.4)]:
		context.make_fitted_environment_role("castle_weapon_stand", pos, Vector3(1.75, 1.65, 0.65), 0.0)

func _make_authored_record_hall_dressing(context: ZoneBuildContext) -> void:
	# The same twenty cabinets and reading furniture are baked offline with their
	# contents. Two surfaces replace individual imported props and empty shelves.
	var archive := MeshInstance3D.new()
	archive.name = "RecordHallAuthoredArchive"
	archive.mesh = RecordArchive
	archive.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var timber := context.make_world_material("timber").duplicate() as StandardMaterial3D
	timber.vertex_color_use_as_albedo = true
	archive.set_surface_override_material(0, timber)
	context.add_node(archive)
	for pos in [Vector3(-12.7, 2.7, -7.0), Vector3(12.7, 2.7, -7.0), Vector3(-12.7, 2.7, 7.0), Vector3(12.7, 2.7, 7.0)]:
		context.make_fitted_environment_role("castle_lantern", pos, Vector3(0.28, 0.55, 0.24), 0.0)

func _make_record_witness_memorial(context: ZoneBuildContext) -> void:
	# The carved testimony owns the far wall as one room-scale focal surface.
	# Its shallow frame stays behind Edric, the ledger and the combat aisle.
	var texture_path := "res://assets_external/environment/props/record_witness_relief.jpg"
	var relief := load(texture_path) as Texture2D
	if relief == null:
		push_error("Required Record Hall witness relief is missing: " + texture_path)
		return
	var material := StandardMaterial3D.new()
	material.resource_name = "RecordHallWitnessRelief"
	material.albedo_texture = relief
	material.albedo_color = Color(0.84, 0.82, 0.78)
	material.roughness = 0.94
	material.emission_enabled = true
	material.emission_texture = relief
	material.emission = Color(0.16, 0.20, 0.22) if not bool(context.get_story_flag("castle_haunting_cleared", false)) else Color(0.10, 0.08, 0.06)
	material.emission_energy_multiplier = 0.18
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var slab := MeshInstance3D.new()
	slab.name = "RecordHallWitnessMemorial"
	var quad := QuadMesh.new()
	quad.size = Vector2(12.4, 5.2)
	slab.mesh = quad
	slab.position = Vector3(0, 3.1, -17.82)
	slab.material_override = material
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context.add_node(slab)
	var stone := Color(0.25, 0.22, 0.18)
	for side in [-1.0, 1.0]:
		context.make_visual_box("WitnessMemorialJamb", Vector3(side * 6.38, 3.1, -17.62), Vector3(0.38, 5.65, 0.42), stone)
	context.make_visual_box("WitnessMemorialLintel", Vector3(0, 5.86, -17.62), Vector3(13.1, 0.34, 0.42), stone)
	context.make_visual_box("WitnessMemorialSill", Vector3(0, 0.35, -17.62), Vector3(13.1, 0.28, 0.42), stone)
