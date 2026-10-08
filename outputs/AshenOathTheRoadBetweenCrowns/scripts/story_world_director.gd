extends RefCounted

## Small, event-driven chapter compositions. These props are visual projections
## of committed decisions, never a second authority for quest or moral state.
const InteractableScript = preload("res://scripts/interactable.gd")
const CompanionController = preload("res://scripts/companion_controller.gd")
const LAYER_NAME := "StoryWorldLayer"
const TIMBER := Color(0.24, 0.15, 0.08)
const IRON := Color(0.18, 0.20, 0.21)
const PAPER := Color(0.76, 0.67, 0.45)
const LINEN := Color(0.57, 0.50, 0.33)
const GREEN := Color(0.28, 0.42, 0.24)
const RED := Color(0.48, 0.16, 0.10)
const STONE := Color(0.35, 0.36, 0.32)
const WATCHED_FLAGS := [
	"cart_helped", "road_repaired", "evidence_report", "names_policy",
	"renewal_announced", "renewal_stopped", "kael_confessed", "mill_operation",
	"mill_fate", "mira_treatment", "mira_truth", "iron_fate", "rook_disclosure",
	"rook_map_fate", "guardian_plan", "confession_method", "assembly_relief_ready",
	"witness_consent_rook", "witness_consent_anwen", "witness_consent_edric", "witness_consent_mira",
	"final_covenant", "final_choice_completed", "rootbound_colossus_defeated",
	"ashwing_defeated", "halvern_fate", "senn_fate", "mill_ventilation_open",
	"mill_workers_rescued", "mill_records_saved", "mill_smoke_exposure",
	"mill_damage_state", "root_landscape_released", "root_testimony_protected", "root_testimony_damaged", "aftermath_names_returned", "aftermath_work_promised"
]

static var _unit_box: BoxMesh
static var _unit_sack: CylinderMesh

static func decorate(game, root: Node3D, zone_id: String) -> void:
	if root == null or not is_instance_valid(root) or game.story_state == null:
		return
	load("res://scripts/story_activity_director.gd").install(game, root, zone_id)
	load("res://scripts/journey_flow_director.gd").install(game, root, zone_id)
	CompanionController.install(game, root, zone_id)
	if zone_id in ["assembly", "hart_glade"] and root == game.zone_root:
		_sync_willing_witnesses(game, root, zone_id)
	var layer := root.get_node_or_null(LAYER_NAME) as Node3D
	if layer == null:
		layer = Node3D.new()
		layer.name = LAYER_NAME
		root.add_child(layer)
		var interactions := Node3D.new()
		interactions.name = "Interactions"
		layer.add_child(interactions)
		_install_interactions(game, interactions, zone_id)
	var signature := _signature(game, zone_id)
	if str(layer.get_meta("state_signature", "")) == signature:
		return
	var old := layer.get_node_or_null("Presentation")
	if old != null:
		layer.remove_child(old)
		old.queue_free()
	var presentation := Node3D.new()
	presentation.name = "Presentation"
	layer.add_child(presentation)
	match zone_id:
		"greyfen": _greyfen(game, presentation)
		"wychwood": _wychwood(game, presentation)
		"deep_wood": _deep_wood(game, presentation)
		"old_mill": _mill(game, presentation)
		"burned_farmstead": _farmstead(game, presentation)
		"marsh_crossing": _marsh(game, presentation)
		"bandit_road": _bandit_road(game, presentation)
		"vargan_approach", "vargan_court", "record_hall": _vargan(game, presentation, zone_id)
		"undercroft": _undercroft(game, presentation)
		"assembly": _assembly(game, presentation)
		"hart_glade": _hart(game, presentation)
	layer.set_meta("state_signature", signature)
	layer.set_meta("story_world_zone", zone_id)
	_update_prompts(game, layer)

static func refresh(game) -> void:
	if game == null or not is_instance_valid(game):
		return
	decorate(game, game.zone_root, str(game.current_zone_id))

static func _signature(game, zone_id: String) -> String:
	var values: Array = [zone_id]
	for flag in WATCHED_FLAGS:
		values.append(game.story_state.get_flag(flag, null))
	return str(hash(values))

static func _flag(game, id: String, fallback: Variant = "") -> Variant:
	return game.story_state.get_flag(id, fallback)

static func _install_interactions(game, parent: Node3D, zone: String) -> void:
	match zone:
		"greyfen":
			_interaction(game, parent, "greyfen_cart_work", "Help Rook lift the food cart", Vector3(-4.9, 0, 8.9))
			_interaction(game, parent, "greyfen_road_work", "Use Tor's tools on the washed-out road", Vector3(3.1, 0, 7.3))
			_interaction(game, parent, "edric_proclamation", "Read Edric's renewal proclamation", Vector3(5.3, 0, 10.7))
			_interaction(game, parent, "greyfen_relief_board", "Read the kitchen and relief ledger", Vector3(-4.4, 0, 0.9))
		"old_mill":
			_interaction(game, parent, "mill_distribution", "Read the mill's food distribution ledger", Vector3(-2.0, 0, 2.5))
		"assembly":
			_interaction(game, parent, "renewal_record", "Read the prepared renewal document", Vector3(2.7, 0, -6.4))
		"record_hall":
			_interaction(game, parent, "renewal_record", "Read the renewal order beside the witness record", Vector3(-3.0, 0, 4.0))

static func _interaction(game, parent: Node3D, id: String, prompt: String, pos: Vector3) -> void:
	var area = InteractableScript.new()
	area.setup(id, "story_activity" if id in ["greyfen_cart_work", "greyfen_road_work", "greyfen_relief_board"] else "dialogue", prompt)
	area.position = pos
	area.build_collision(1.05)
	area.set_meta("story_world_interaction", true)
	parent.add_child(area)
	var label := Label3D.new()
	label.name = "InteractionWorldLabel"
	label.text = prompt
	label.position = Vector3(0, 1.45, 0)
	label.font_size = 20
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = PAPER
	label.outline_size = 4
	label.visible = false
	area.add_child(label)
	game._connect_interactable(area)
	game.interaction_focus_dirty = true

static func _update_prompts(game, layer: Node3D) -> void:
	var cart = layer.get_node_or_null("Interactions/greyfen_cart_work")
	if cart != null:
		cart.state_label = "Food cart secured" if bool(_flag(game, "cart_helped", false)) else "Help Rook"
	var road = layer.get_node_or_null("Interactions/greyfen_road_work")
	if road != null:
		road.state_label = "Road made safe" if bool(_flag(game, "road_repaired", false)) else "Repair the road"

static func _sync_willing_witnesses(game, root: Node3D, zone: String) -> void:
	var cast := [
		["witness_-7", "mira", Vector3(-8.0, 0, -3.5) if zone == "assembly" else Vector3(-8.0, 0, 4.5)],
		["witness_-3", "rook", Vector3(-4.0, 0, -3.5) if zone == "assembly" else Vector3(-6.0, 0, 4.5)],
		["witness_3", "anwen", Vector3(4.0, 0, -3.5) if zone == "assembly" else Vector3(6.0, 0, 4.5)]
	]
	for entry in cast:
		var id := str(entry[0])
		var actor := str(entry[1])
		var voluntary := str(_flag(game, "witness_consent_" + actor)) == "voluntary"
		var existing := root.find_child(id, true, false)
		if existing != null and not voluntary:
			game._remove_interaction_candidate(existing)
			if game.active_interactable == existing:
				game.active_interactable = null
			existing.get_parent().remove_child(existing)
			existing.queue_free()
		elif existing == null and voluntary:
			var area = game._make_named_interactable(id, "dialogue", "Hear %s's willing testimony" % actor.capitalize(), entry[2], Color(0.27, 0.25, 0.22))
			if area != null:
				area.set_meta("story_willing_witness", actor)
	game.interaction_focus_dirty = true

static func _box(game, parent: Node3D, id: String, pos: Vector3, size: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = _unit_box
	node.position = pos
	node.scale = size
	node.rotation_degrees.y = yaw
	node.material_override = game._mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func _sack(game, parent: Node3D, pos: Vector3, color := LINEN) -> void:
	if _unit_sack == null:
		_unit_sack = CylinderMesh.new()
		_unit_sack.top_radius = 0.16
		_unit_sack.bottom_radius = 0.28
		_unit_sack.height = 0.58
		_unit_sack.radial_segments = 8
	var node := MeshInstance3D.new()
	node.name = "FoodSack"
	node.mesh = _unit_sack
	node.position = pos + Vector3(0, 0.29, 0)
	node.material_override = game._mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	_box(game, parent, "TiedSackNeck", pos + Vector3(0, 0.57, 0), Vector3(0.16, 0.07, 0.15), TIMBER)

static func _label(parent: Node3D, id: String, text: String, pos: Vector3, color := PAPER) -> void:
	var node := Label3D.new()
	node.name = id
	node.text = text
	node.position = pos
	node.font_size = 30
	node.pixel_size = 0.0045
	node.modulate = color
	node.outline_size = 5
	node.outline_modulate = Color(0.035, 0.028, 0.02)
	node.no_depth_test = false
	node.visibility_range_end = 14.0
	parent.add_child(node)

static func _notice(game, parent: Node3D, pos: Vector3, title: String, color := PAPER) -> void:
	_box(game, parent, "NoticeSupport", pos + Vector3(0, 0.6, 0), Vector3(0.10, 1.2, 0.12), TIMBER)
	_box(game, parent, "NoticeBacking", pos + Vector3(0, 1.20, 0), Vector3(1.45, 0.85, 0.09), TIMBER)
	_box(game, parent, "WrittenNotice", pos + Vector3(0, 1.2, 0.052), Vector3(1.30, 0.72, 0.012), color)
	_label(parent, "NoticeHeading", title, pos + Vector3(0, 1.75, 0.06), color)

static func _table(game, parent: Node3D, pos: Vector3, width := 1.7) -> void:
	_box(game, parent, "WorkTable", pos + Vector3(0, 0.76, 0), Vector3(width, 0.12, 0.78), TIMBER)
	for x in [-width * 0.40, width * 0.40]:
		_box(game, parent, "WorkTableLeg", pos + Vector3(x, 0.35, 0), Vector3(0.12, 0.7, 0.60), TIMBER)

static func _greyfen(game, parent: Node3D) -> void:
	var helped := bool(_flag(game, "cart_helped", false))
	# The existing cart and Rook are retained. Securing its load is tangible work
	# beside a living person, rather than another quest-board icon.
	for index in range(3):
		var pos := Vector3(-6.1 + float(index) * 0.35, 0.77 if helped else 0.03, 9.0 if helped else 8.0 + float(index) * 0.38)
		_sack(game, parent, pos)
	_box(game, parent, "CartBrace", Vector3(-5.35, 0.24, 9.0), Vector3(0.2, 0.45, 0.6), TIMBER, 0.0 if helped else 38.0)
	_label(parent, "CartWork", "ROOK'S FOOD CART\nLoad secured for the kitchen" if helped else "ROOK'S FOOD CART\nA wheel has sunk in the mud", Vector3(-5.65, 1.8, 9.3))
	var repaired := bool(_flag(game, "road_repaired", false))
	for index in range(5):
		_box(game, parent, "RoadDrainageBoard", Vector3(2.25 + float(index) * 0.18, 0.035, 7.1), Vector3(0.14, 0.055, 1.15), TIMBER if repaired else IRON, 0.0 if repaired else 18.0 * float(index - 2))
	_box(game, parent, "RoadToolHandle", Vector3(3.0, 0.10, 7.8), Vector3(0.07, 0.07, 0.85), TIMBER, -20.0)
	_box(game, parent, "RoadToolHead", Vector3(2.86, 0.10, 7.42), Vector3(0.33, 0.08, 0.1), IRON)
	_notice(game, parent, Vector3(5.3, 0, 10.65), "VARGAN RENEWAL\nAt the next bell", RED)
	_table(game, parent, Vector3(-4.4, 0, 0.9), 1.5)
	var relief := bool(_flag(game, "cart_helped", false)) or bool(_flag(game, "assembly_relief_ready", false))
	if relief:
		for index in range(3):
			_sack(game, parent, Vector3(-4.85 + float(index) * 0.38, 0.83, 0.9))
	else:
		_box(game, parent, "EmptyKitchenBowl", Vector3(-4.4, 0.84, 0.9), Vector3(0.4, 0.12, 0.35), STONE)
	_label(parent, "ReliefKitchen", "COMMON KITCHEN\nFood reserved for tonight" if relief else "COMMON KITCHEN\nThree households still waiting", Vector3(-4.4, 1.8, 1.0))
	_mira(game, parent)
	_greyfen_daily_consequences(game, parent)
	_tor(game, parent)
	_rook(game, parent)
	_guardian(game, parent)
	var report := str(_flag(game, "evidence_report"))
	if report == "public":
		_notice(game, parent, Vector3(3.7, 0, 10.9), "THE ROAD WAS SET\nWitnesses needed")
	elif report == "private":
		_box(game, parent, "AnwenSealedRoadEvidence", Vector3(5.5, 0.82, -6.2), Vector3(0.42, 0.09, 0.30), PAPER)
	elif report == "retained":
		_notice(game, parent, Vector3(3.7, 0, 10.9), "ROAD UNDER WATCH\nNo name published", LINEN)
	if bool(_flag(game, "renewal_stopped", false)):
		_notice(game, parent, Vector3(5.8, 0, -4.7), "RENEWAL HALTED\nThe living will be heard", GREEN)
	var names := str(_flag(game, "names_policy"))
	if names != "":
		_notice(game, parent, Vector3(7.8, 0, -4.5), "NAMES RETURNED\nBram / Sella / Oren" if names == "published" else "NAMES IN SAFE KEEPING\nHousehold visits begin")

static func _greyfen_daily_consequences(game, parent: Node3D) -> void:
	var operation := str(_flag(game, "mill_operation"))
	if operation == "closed":
		for index in range(3):
			_sack(game, parent, Vector3(-5.5, 0.03, 1.8 + float(index) * 0.45))
		_notice(game, parent, Vector3(-3.3, 0, 0.9), "RESERVE GRAIN\nHousehold measures / mill closed")
	elif operation == "supervised":
		_notice(game, parent, Vector3(-3.3, 0, 0.9), "MILL WORKING SHEET\nSupervised batches / risks recorded")
	elif operation == "restitution":
		for index in range(4):
			_box(game, parent, "CleanMillRepairTimber", Vector3(8.0, 0.12 + float(index) * 0.10, 2.9), Vector3(1.65, 0.08, 0.22), TIMBER)
		_notice(game, parent, Vector3(-3.3, 0, 0.9), "MILL REPAIR ACCOUNTS\nClean channels / restitution owed")
	if bool(_flag(game, "assembly_relief_ready", false)):
		for x in [-9.0, 7.3]:
			_box(game, parent, "ReturnedHouseholdBowl", Vector3(x, 0.18, 3.5), Vector3(0.35, 0.12, 0.32), STONE)
	if bool(_flag(game, "final_choice_completed", false)):
		var covenant := str(_flag(game, "final_covenant"))
		var headings := {"witness":"COPIES FOR EVERY HOUSEHOLD", "mercy":"NO HOUSEHOLD OWES A CHILD", "duty":"KAEL BEARS THE OATH", "ash":"THE BINDING IS ENDED"}
		_notice(game, parent, Vector3(2.6, 0, -4.6), str(headings.get(covenant, "THE NAMES REMAIN")) + "\nTomorrow's work is ours")

static func _mira(game, parent: Node3D) -> void:
	var treatment := str(_flag(game, "mira_treatment"))
	if treatment == "": return
	_table(game, parent, Vector3(-7.15, 0, -1.65), 1.2)
	var tone := GREEN if treatment != "replacement" else LINEN
	for index in range(3):
		_box(game, parent, "MiraTreatmentPot", Vector3(-7.5 + float(index) * 0.32, 0.9, -1.65), Vector3(0.16, 0.2, 0.16), tone)
	var heading: String = {"private": "MIRA'S TREATMENT\nNames kept in confidence", "consented": "MIRA'S TREATMENT\nPatients chose disclosure", "replacement": "MIRA'S NEW REMEDY\nNo sacrifice roots"}.get(treatment, "MIRA'S TREATMENT")
	_label(parent, "MiraTreatmentNotice", heading, Vector3(-7.1, 1.8, -1.6), tone)

static func _tor(game, parent: Node3D) -> void:
	var fate := str(_flag(game, "iron_fate"))
	if fate == "": return
	var pos := Vector3(8.5, 0, -1.3)
	if fate == "tools":
		for index in range(3):
			_box(game, parent, "RestitutionTool", pos + Vector3(float(index) * 0.25, 0.92, 0), Vector3(0.05, 0.05, 0.65), TIMBER)
			_box(game, parent, "RestitutionToolHead", pos + Vector3(float(index) * 0.25, 0.96, -0.3), Vector3(0.22, 0.08, 0.12), IRON)
		_label(parent, "TorRestitution", "TOR'S REPAIR TOOLS\nIron returned to village work", pos + Vector3(0.3, 1.8, 0))
	elif fate == "surrendered":
		_box(game, parent, "SurrenderedIronCrate", pos + Vector3(0, 0.25, 0), Vector3(0.85, 0.5, 0.55), TIMBER)
		_box(game, parent, "SurrenderedIronSeal", pos + Vector3(0, 0.52, 0), Vector3(0.7, 0.03, 0.14), PAPER)
		_label(parent, "TorRestitution", "IRON HELD FOR RESTITUTION\nTor keeps no weapon", pos + Vector3(0, 1.8, 0))
	else:
		_box(game, parent, "IronMemorial", pos + Vector3(0, 0.45, 0), Vector3(0.16, 0.9, 0.16), IRON)
		_label(parent, "TorRestitution", "TOR'S MEMORIAL\nWork begins with the names", pos + Vector3(0, 1.8, 0))

static func _rook(game, parent: Node3D) -> void:
	var disclosure := str(_flag(game, "rook_disclosure"))
	if disclosure == "": return
	var text: String = {"protected": "ROOK'S SHELTERED ROUTE\nNo names on the public map", "public": "ROOK'S PUBLIC ROUTE\nWalked with his permission", "erased": "ROOK'S MAP WITHDRAWN\nThe false road is closed"}.get(disclosure, "ROOK'S ROUTE")
	_notice(game, parent, Vector3(-9.0, 0, 7.0), text, GREEN if disclosure == "protected" else PAPER)

static func _guardian(game, parent: Node3D) -> void:
	var plan := str(_flag(game, "guardian_plan"))
	if plan == "": return
	var pos := Vector3(13.9, 0, -10.0)
	if plan == "killed":
		_box(game, parent, "GuardianGrave", pos + Vector3(0, 0.09, 0), Vector3(1.0, 0.18, 1.4), STONE)
		_label(parent, "GuardianMarker", "THE GUARDIAN IS GONE\nThe fold must be watched", pos + Vector3(0, 1.5, 0))
	else:
		_box(game, parent, "GuardianWaterBowl", pos + Vector3(0, 0.10, 0), Vector3(0.5, 0.16, 0.5), STONE)
		_notice(game, parent, pos + Vector3(0.8, 0, 0), "GUARDIAN RELOCATED\nToma tends the forest edge" if plan == "relocated" else "WATCHED SHEEPFOLD\nToma takes the night watch", GREEN)

static func _wychwood(game, parent: Node3D) -> void:
	_notice(game, parent, Vector3(6.7, 0, -6.2), "A HUNTER'S COUNTERPLAY\nRead the drag line before closing\nKeep the bridge at your back")
	for index in range(3):
		_box(game, parent, "CutBindingWire", Vector3(-1.0 + float(index) * 0.25, 0.09, 5.6), Vector3(0.04, 0.06, 0.55), IRON, float(index) * 20.0)
	if str(_flag(game, "mira_treatment")) == "replacement":
		_box(game, parent, "RetiredSacrificeBed", Vector3(9.7, 0.08, -9.2), Vector3(1.5, 0.13, 0.8), STONE)
		_label(parent, "SacrificeBedNotice", "HARVEST STOPPED\nMira prepares a replacement", Vector3(9.7, 1.6, -9.2))

static func _deep_wood(game, parent: Node3D) -> void:
	var disclosure := str(_flag(game, "rook_disclosure"))
	if disclosure in ["protected", "public"]:
		for z in [7.4, 5.8, 4.2]:
			_box(game, parent, "RookSafeRoadMarker", Vector3(3.6, 0.15, z), Vector3(0.24, 0.3, 0.18), GREEN)
		_label(parent, "RookRoadPromise", "A ROAD FOR THE LIVING\nRook's marked return", Vector3(3.6, 1.7, 7.4), GREEN)
	if bool(_flag(game, "rootbound_colossus_defeated", false)):
		_notice(game, parent, Vector3(-5.5, 0, -8.0), "THE MEMORY IS STILL\nThe road can be walked")
		for index in range(5):
			var released := bool(_flag(game, "root_landscape_released", false))
			_box(game, parent, "ReleasedRootGrowth", Vector3(-2.0 + float(index), 0.08, -8.0), Vector3(0.16, 0.20 if released else 0.07, 0.18), GREEN if released else TIMBER)
		_label(parent, "NameBoardAftermath", "THE NAME-BOARD IS KEPT WHOLE" if bool(_flag(game, "root_testimony_protected", false)) else "FRAGMENTS REMAIN / THE COPIED REGISTER SURVIVES", Vector3(-2.6, 1.2, -6.7))

static func _mill(game, parent: Node3D) -> void:
	var operation := str(_flag(game, "mill_operation"))
	if bool(_flag(game, "mill_ventilation_open", false)):
		for index in range(6):
			_box(game, parent, "OpenedMillEscapeChannel", Vector3(-1.65, 0.038, -0.8 + float(index) * 1.1), Vector3(0.5, 0.028, 0.92), Color(0.21, 0.37, 0.40))
		_box(game, parent, "RaisedSluiceGate", Vector3(-1.8, 1.0, -0.4), Vector3(0.7, 0.45, 0.10), TIMBER)
	if bool(_flag(game, "mill_records_saved", false)):
		_box(game, parent, "SavedWageChest", Vector3(-2.8, 0.65, -4.0), Vector3(0.62, 0.44, 0.42), TIMBER)
		_box(game, parent, "ProtectedWagePages", Vector3(-2.8, 0.89, -4.0), Vector3(0.45, 0.03, 0.32), PAPER)
	if bool(_flag(game, "mill_workers_rescued", false)):
		_notice(game, parent, Vector3(-3.5, 0, 7.5), "WORKERS REACHED CLEAN AIR\n" + ("Mira treats the smoke in their lungs" if int(_flag(game, "mill_smoke_exposure", 0)) >= 3 else "Their wage accounts travel to Greyfen"), GREEN)
	if str(_flag(game, "mill_damage_state")) == "scorched":
		for index in range(4):
			_box(game, parent, "BurnedMillRoofFragment", Vector3(3.2 + float(index) * 0.55, 0.08, -3.0), Vector3(0.34, 0.12, 0.86), Color(0.12, 0.09, 0.075), float(index) * 18.0)
	elif str(_flag(game, "mill_damage_state")) == "contained":
		_notice(game, parent, Vector3(2.7, 0, 2.3), "CHANNEL KEPT CLEAR\nLower mill stores survived", GREEN)
	_table(game, parent, Vector3(-2.0, 0, 2.5))
	if operation in ["supervised", "restitution"]:
		for index in range(4):
			_sack(game, parent, Vector3(-2.6 + float(index) * 0.38, 0.83, 2.5))
		_notice(game, parent, Vector3(-5.7, 0, 2.5), "SUPERVISED MILL\nWitnesses weigh every sack" if operation == "supervised" else "RESTITUTION STORE\nFood belongs to harmed households", GREEN)
	elif operation == "closed":
		_box(game, parent, "MillClosedCrossbar", Vector3(-5.2, 1.25, -2.6), Vector3(2.4, 0.18, 0.10), RED, 0.0)
		_notice(game, parent, Vector3(-5.7, 0, 2.5), "MILL CLOSED\nGreyfen's kitchen carries the cost", RED)
	else:
		_notice(game, parent, Vector3(-5.7, 0, 2.5), "FLOUR HELD HERE\nThe evidence must be settled")

static func _farmstead(game, parent: Node3D) -> void:
	_notice(game, parent, Vector3(-4.0, 0, 5.7), "BRAM / SELLA / OREN\nThree places at an empty table")
	_table(game, parent, Vector3(-4.0, 0, 6.7), 1.5)
	for index in range(3):
		_box(game, parent, "EmptyHouseholdBowl", Vector3(-4.45 + float(index) * 0.44, 0.85, 6.7), Vector3(0.25, 0.08, 0.25), STONE)

static func _marsh(game, parent: Node3D) -> void:
	_notice(game, parent, Vector3(4.9, 0, 7.0), "HEALER'S RETURN ROUTE\nNo patient carried alone", GREEN)
	_box(game, parent, "AbandonedStretcher", Vector3(5.0, 0.13, 5.7), Vector3(0.85, 0.15, 1.8), LINEN)
	for x in [4.5, 5.5]:
		_box(game, parent, "StretcherHandle", Vector3(x, 0.16, 5.7), Vector3(0.07, 0.07, 2.6), TIMBER)

static func _bandit_road(game, parent: Node3D) -> void:
	var fate := str(_flag(game, "senn_fate"))
	if fate == "": return
	_notice(game, parent, Vector3(-5.7, 0, 6.0), "SENN'S ROAD\n" + {"exile": "The captain has left; the orders remain", "punished": "The command has fallen; testimony costs blood", "heard": "The captain's account travels with Kael", "spared": "A soldier remains to answer"}.get(fate, "The command has been answered"))

static func _vargan(game, parent: Node3D, zone: String) -> void:
	if zone == "record_hall":
		_table(game, parent, Vector3(-3.0, 0, 4.0), 1.5)
		_box(game, parent, "RenewalOrder", Vector3(-3.0, 0.85, 4.0), Vector3(1.05, 0.025, 0.57), PAPER)
		_label(parent, "RenewalOrderTitle", "RENEWAL ORDER\nA living household must pledge", Vector3(-3.0, 1.8, 4.0), RED)
	else:
		_notice(game, parent, Vector3(-5.2, 0, 8.0), "HOUSE VARGAN\nThe renewal is still commanded", RED)
	if str(_flag(game, "witness_consent_edric")) == "compelled":
		_notice(game, parent, Vector3(5.2, 0, 6.0), "EDRIC'S COMPELLED ACCOUNT\nEvidence, not voluntary testimony")

static func _undercroft(game, parent: Node3D) -> void:
	if bool(_flag(game, "kael_confessed", false)):
		_notice(game, parent, Vector3(-4.2, 0, 8.0), "KAEL'S ACCOUNT\nThe hunter names his own debt")
	var fate := str(_flag(game, "halvern_fate"))
	if fate != "":
		_notice(game, parent, Vector3(4.2, 0, 8.0), "HALVERN'S PLACE\n" + {"witness": "The bounded memory preserves his refusal", "released": "Released after the refusal was copied", "destroyed": "The command survives; the surrounding memory is lost"}.get(fate, "His answer is recorded"))

static func _assembly(game, parent: Node3D) -> void:
	var stopped := bool(_flag(game, "renewal_stopped", false))
	_table(game, parent, Vector3(2.7, 0, -6.4), 1.3)
	_box(game, parent, "RenewalSignaturePage", Vector3(2.7, 0.85, -6.4), Vector3(0.9, 0.02, 0.52), PAPER)
	if stopped:
		_box(game, parent, "BrokenRenewalSeal", Vector3(2.3, 0.90, -6.4), Vector3(0.18, 0.07, 0.18), RED)
		_label(parent, "RenewalAssemblyState", "NO RENEWAL TONIGHT\nGreyfen answers for the living", Vector3(0, 2.8, -8.2), GREEN)
	else:
		_box(game, parent, "RenewalSeal", Vector3(2.7, 0.9, -6.4), Vector3(0.25, 0.07, 0.25), RED)
		_label(parent, "RenewalAssemblyState", "THE RENEWAL IS PREPARED\nA household has not yet signed", Vector3(0, 2.8, -8.2), RED)
	for pair in [["rook", -4.0], ["anwen", 4.0], ["edric", 8.0]]:
		var consent := str(_flag(game, "witness_consent_" + str(pair[0])))
		var heading := str(pair[0]).capitalize() + " / " + ("CHOSE TO SPEAK" if consent == "voluntary" else "A COMPELLED ACCOUNT" if consent == "compelled" else "A PLACE LEFT OPEN")
		_label(parent, "Consent_" + str(pair[0]), heading, Vector3(float(pair[1]), 1.8, -2.8), GREEN if consent == "voluntary" else PAPER)
	if bool(_flag(game, "assembly_relief_ready", false)):
		for index in range(3):
			_sack(game, parent, Vector3(-10.0 + float(index) * 0.45, 0.02, 6.0))
		_label(parent, "AssemblyRelief", "RELIEF BEFORE THE BELL\nTonight's food is accounted for", Vector3(-9.5, 1.6, 6.0), GREEN)

static func _hart(game, parent: Node3D) -> void:
	# Ritual anchors and ending_return are owned by CovenantResolution.
	var resolved := bool(_flag(game, "final_choice_completed", false))
	if not resolved: return
	var covenant := str(_flag(game, "final_covenant"))
	var headings := {"witness": "THE NAMES BELONG TO EVERYONE", "mercy": "NO HOUSEHOLD OWES A CHILD", "duty": "KAEL BEARS THE OATH", "ash": "THE COVENANT IS GONE"}
	_label(parent, "EndingReturnPromise", str(headings.get(covenant, "THE ROAD REMEMBERS")), Vector3(0, 2.4, 5.8), GREEN if covenant == "mercy" else PAPER)
	for index in range(3):
		var pos := Vector3(-4.0 + float(index) * 0.65, 0.02, 6.0)
		if covenant == "ash":
			_box(game, parent, "SpentOathStone", pos + Vector3(0, 0.08, 0), Vector3(0.38, 0.16, 0.46), RED)
		elif covenant == "duty":
			_box(game, parent, "AcceptedOathStone", pos + Vector3(0, 0.28, 0), Vector3(0.22, 0.56, 0.32), GREEN)
		else:
			_box(game, parent, "ReturnedNamePage", pos + Vector3(0, 0.05, 0), Vector3(0.42, 0.025, 0.3), PAPER)
