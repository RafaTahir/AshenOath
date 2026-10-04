extends Node

## Short, saved work in the places the story changes. Progress is in StoryState;
## a cached sector can be discarded without losing a carried sack or a promise.
const Interactable = preload("res://scripts/interactable.gd")
const LAYER := "StoryActivities"
const WAYPOINTS := {
	"greyfen": ["Greyfen common kitchen", Vector3(-1, 1, 7)],
	"deep_wood": ["Deep Wood waystone", Vector3(0, 1, 11)],
	"old_mill": ["The mill south yard", Vector3(0, 1, 10)],
	"bandit_road": ["The old checkpoint", Vector3(0, 1, 11)],
	"vargan_approach": ["Vargan's outer road", Vector3(0, 1, 11)]
}
var host
var zone := ""
var worker_group: Node3D
var escort_target := Vector3(-1.5, 0, 8.0)
var escort_tick := 0.0
var worker_drivers: Array[Node] = []
var worker_bodies: Array[Node3D] = []
var escort_speed := 0.0
var escort_waiting_for_player := false

static func install(game, root: Node3D, zone_id: String) -> void:
	if root == null or root != game.zone_root:
		return
	var director = root.get_node_or_null(LAYER)
	if director == null:
		director = load("res://scripts/story_activity_director.gd").new()
		director.name = LAYER
		director.host = game
		director.zone = zone_id
		root.add_child(director)
		director._build(root)
	director.refresh()
	if zone_id == "greyfen":
		preload("res://scripts/opening_care_scene.gd").install(game, root)

static func handle(game, area) -> void:
	if str(area.interaction_id).begins_with("opening_"):
		var opening: Node = game.zone_root.get_node_or_null("OpeningCareScene")
		if opening != null:
			opening.activate(str(area.interaction_id))
		return
	if area.has_meta("story_encounter_owner"):
		var actor = instance_from_id(int(area.get_meta("story_encounter_owner")))
		if actor != null and is_instance_valid(actor):
			var encounter = actor.get_node_or_null("StoryEncounterPreparation")
			if encounter != null:
				encounter.interact(str(area.interaction_id))
		return
	var director = game.zone_root.get_node_or_null(LAYER)
	if director != null:
		director.activate(str(area.interaction_id))

static func travel(game, action: Dictionary) -> void:
	var destination := str(action.get("destination", ""))
	if not WAYPOINTS.has(destination) or not bool(game.story_state.get_flag("waypost_" + destination, false)):
		game.hud.toast("Walk this road once before using its waypost.")
		return
	var unavailable_reason: String = _travel_unavailable_reason(game)
	if unavailable_reason != "":
		game.hud.toast(unavailable_reason)
		return
	game.get_tree().paused = false
	game.audio.set_game_paused(false)
	game.hud.hide_menus()
	game.active_interactable = null
	game._load_zone_after_runtime_pack(destination, WAYPOINTS[destination][1])
	game.story_save_pending = true

static func get_started_work(state, zone_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null:
		return result
	if zone_id == "greyfen":
		if bool(state.get_flag("opening_cup_carried", false)) and not bool(state.get_flag("opening_cup_delivered", false)):
			result.append({"id":"opening_water", "title":"Water for the injured traveler", "action":"Leave the cup on the linen-covered tray beside Anwen's privacy screen", "target_ids":["opening_cup_deliver"], "destination_zone":"greyfen"})
		if bool(state.get_flag("cart_sack_carried", false)) and not bool(state.get_flag("cart_helped", false)):
			result.append({"id":"cart_flour", "title":"Carry the flour to the common kitchen", "action":"Set Rook's flour on the kitchen table beside the well", "target_ids":["cart_kitchen_delivery"], "destination_zone":"greyfen"})
		if bool(state.get_flag("relief_shares_carried", false)) and not bool(state.get_flag("relief_deliveries_completed", false)):
			var households: Array[String] = []
			var targets: Array[String] = []
			if not bool(state.get_flag("relief_west_delivered", false)):
				households.append("western")
				targets.append("relief_house_west")
			if not bool(state.get_flag("relief_east_delivered", false)):
				households.append("eastern")
				targets.append("relief_house_east")
			if not targets.is_empty():
				result.append({"id":"household_shares", "title":"Deliver the waiting household shares", "action":"Leave shares at the %s linen baskets" % " and ".join(households), "target_ids":targets, "destination_zone":"greyfen"})
		if bool(state.get_flag("road_tools_taken", false)) and not bool(state.get_flag("road_repaired", false)):
			result.append({"id":"road_drain", "title":"Clear the drain with Tor's spade", "action":"Clear the blocked drain beside the loose road boards", "target_ids":["road_drain_work"], "destination_zone":"greyfen"})
	elif zone_id == "old_mill" and not bool(state.get_flag("mill_workers_rescued", false)):
		if bool(state.get_flag("mill_escort_started", false)):
			result.append({"id":"mill_workers", "title":"Stay with the workers to the south yard", "action":"Keep within a few paces so the workers can follow the escape channel", "target_ids":[], "destination_zone":"old_mill"})
		elif bool(state.get_flag("mill_escape_route_open", false)):
			result.append({"id":"mill_workers", "title":"Call the workers to the open channel", "action":"Return to the waiting workers and lead them to clean air", "target_ids":["mill_workers"], "destination_zone":"old_mill"})
	return result

static func get_waypost_model(game) -> Dictionary:
	var routes: Array[Dictionary] = []
	if game == null or game.story_state == null:
		return {"current_zone":"", "routes":routes, "available":false, "reason":"The road is still settling."}
	var current_zone: String = str(game.current_zone_id)
	var reason: String = _travel_unavailable_reason(game)
	var has_return := false
	for raw_destination in WAYPOINTS:
		var destination: String = str(raw_destination)
		if not bool(game.story_state.get_flag("waypost_" + destination, false)):
			continue
		var here: bool = destination == current_zone
		var work: Array[Dictionary] = get_started_work(game.story_state, destination)
		var available: bool = not here and reason == ""
		if not here:
			has_return = true
		routes.append({"destination":destination, "name":str(WAYPOINTS[destination][0]), "current":here, "available":available, "reason":"You are here" if here else reason, "work_count":work.size(), "status":"Here" if here else "Available" if available else "Remembered"})
	if reason == "" and not has_return:
		reason = "No other waypost is marked yet. Read the signs on the roads you visit."
	return {"current_zone":current_zone, "routes":routes, "available":reason == "" and has_return, "reason":reason}

static func _travel_unavailable_reason(game) -> String:
	if game.player == null or game.zone_transition_in_progress:
		return "The road is still settling. Finish arriving before travelling."
	if str(game.pending_ending) != "":
		return "Carry out the chosen covenant before leaving the glade."
	if not _travel_open(game):
		return "Safe return routes open after the Deep Wood account is settled. Your marked wayposts are kept."
	if _danger_near(game):
		return "Finish the nearby encounter before travelling. Your marked roads are kept."
	return ""

static func _travel_open(game) -> bool:
	return bool(game.story_state.get_flag("rootbound_colossus_defeated", false)) or str(game.story_state.get_flag("names_policy", "")) != "" or bool(game.story_state.get_flag("final_choice_completed", false))

static func _danger_near(game) -> bool:
	if game.player == null or game.pending_ending != "" or game.zone_transition_in_progress:
		return true
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.encounter_active and not bool(enemy.get_meta("story_surrender_protected", false)) and enemy.global_position.distance_to(game.player.global_position) < 13.0:
			return true
	return false

func _build(root: Node3D) -> void:
	if WAYPOINTS.has(zone):
		_point(root, "story_waypost", "Read the waypost: discovered roads", WAYPOINTS[zone][1] + Vector3(-1.8, -1, 0), "ROADS ALREADY WALKED", Color(0.48, 0.40, 0.24))
	match zone:
		"greyfen":
			_point(root, "cart_kitchen_delivery", "Set Rook's flour in the common kitchen", Vector3(-4.6, 0, 1.8), "COMMON KITCHEN", Color(0.62, 0.54, 0.35))
			_point(root, "road_drain_work", "Clear the roadside drain with Tor's spade", Vector3(3.4, 0, 6.5), "ROAD DRAIN", Color(0.38, 0.44, 0.37))
			_point(root, "relief_house_west", "Leave a share for the western households", Vector3(-9.0, 0, 3.5), "WAITING HOUSEHOLDS", Color(0.62, 0.54, 0.35))
			_point(root, "relief_house_east", "Leave a share for the eastern households", Vector3(7.3, 0, 3.5), "WAITING HOUSEHOLDS", Color(0.62, 0.54, 0.35))
			_point(root, "aftermath_names", "Return to the names with Anwen", Vector3(6.9, 0, -4.2), "WHAT THE NAMES REQUIRE", Color(0.67, 0.65, 0.46))
			_point(root, "aftermath_work", "Help Tor and Rook make tomorrow possible", Vector3(6.2, 0, 1.0), "THE NEXT DAY'S WORK", Color(0.44, 0.50, 0.38))
			_point(root, "aftermath_road", "Meet the road beyond the kitchen", Vector3(-1.5, 0, 7.0), "THE ROAD GOES ON", Color(0.65, 0.60, 0.44))
		"old_mill":
			_point(root, "mill_sluice", "Open the mill's escape channel", Vector3(-1.8, 0, -0.4), "SLUICE / WORKERS' EXIT", Color(0.30, 0.51, 0.55))
			_point(root, "mill_workers", "Call the trapped mill workers to the channel", Vector3(-4.4, 0, -2.1), "WORKERS WAITING", Color(0.68, 0.58, 0.35))
			_point(root, "mill_record_chest", "Move the wage records above the waterline", Vector3(-2.8, 0, -4.0), "WAGES AND HOUSEHOLD SHARES", Color(0.71, 0.65, 0.46))
			_point(root, "mill_ground_perch", "Drop the rotten perch with its hauling rope", Vector3(8.0, 0, -1.4), "PERCH HAULING ROPE", Color(0.54, 0.37, 0.23))
			_build_workers(root)
		"deep_wood":
			_point(root, "root_testimony", "Lift the name-board out of the roots", Vector3(-2.6, 0, -6.7), "THE NAME-BOARD", Color(0.65, 0.58, 0.36))
		"vargan_approach":
			_point(root, "vargan_service_shortcut", "Follow the documented service passage", Vector3(-6.0, 0, -5.0), "RECORD KEEPERS' PASSAGE", Color(0.52, 0.48, 0.40))
		"bandit_road":
			_point(root, "senn_guard_stand_down", "Offer Senn's abandoned soldiers a way to stand down", Vector3(2.0, 0, 4.5), "THE SOLDIERS AT THE ROAD", Color(0.58, 0.52, 0.36))

func refresh() -> void:
	if host == null or host.zone_root == null or zone != str(host.current_zone_id):
		return
	for area in get_tree().get_nodes_in_group("story_activity"):
		if not host.zone_root.is_ancestor_of(area):
			continue
		var id := str(area.interaction_id)
		var enabled := true
		match id:
			"cart_kitchen_delivery": enabled = _flag("cart_sack_carried") and not _flag("cart_helped")
			"road_drain_work": enabled = _flag("road_tools_taken") and not _flag("road_repaired")
			"relief_house_west": enabled = _flag("relief_shares_carried") and not _flag("relief_west_delivered")
			"relief_house_east": enabled = _flag("relief_shares_carried") and not _flag("relief_east_delivered")
			"aftermath_names": enabled = _flag("final_choice_completed") and not _flag("aftermath_names_returned")
			"aftermath_work": enabled = _flag("aftermath_names_returned") and not _flag("aftermath_work_promised")
			"aftermath_road": enabled = _flag("aftermath_work_promised")
			"mill_workers": enabled = not _flag("mill_workers_rescued") and not _flag("mill_escort_started")
			"mill_sluice": enabled = not _flag("mill_ventilation_open")
			"mill_record_chest": enabled = not _flag("mill_records_saved")
			"mill_ground_perch": enabled = not _flag("ashwing_perch_grounded") and not _flag("ashwing_defeated")
			"root_testimony": enabled = not _flag("root_testimony_protected") and not _flag("root_testimony_recovered")
			"senn_guard_stand_down": enabled = not _flag("senn_guards_stood_down") and host.quests.is_active("main_soldier_without_banner") and not host.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation")
		area.visible = enabled
		area.set_interaction_enabled(enabled)
		if not enabled:
			host._remove_interaction_candidate(area)
	if worker_group != null:
		worker_group.visible = not _flag("mill_workers_rescued")
	host.interaction_focus_dirty = true

func activate(id: String) -> void:
	match id:
		"story_waypost":
			if not _flag("waypost_" + zone):
				_commit({"waypost_" + zone: true}, "This waypost is remembered. The sign now lists the roads you have marked.")
			_open_waypost()
		"greyfen_cart_work":
			if _flag("cart_helped"):
				_scene("work_cart_return")
			elif not _flag("cart_sack_carried"):
				_commit({"cart_sack_carried": true}, "Rook braces the wheel. Carry the flour to the common kitchen beside the well.")
			else:
				host.hud.set_guidance_hint("Set the flour on the common kitchen table near the well.", 7.0)
		"cart_kitchen_delivery":
			if _flag("cart_sack_carried") and not _flag("cart_helped"):
				_commit({"cart_helped": true, "cart_sack_carried": false}, "Flour reaches the kitchen. Rook can lift the empty cart; three households will eat tonight.")
				_scene("work_cart_finish")
		"greyfen_road_work":
			if _flag("road_repaired"):
				_scene("work_road_return")
			else:
				_commit({"road_tools_taken": true}, "Take Tor's spade to the blocked drain beside the loose boards.")
		"road_drain_work":
			if _flag("road_tools_taken") and not _flag("road_repaired"):
				_commit({"road_repaired": true, "road_tools_taken": false}, "Mud drains away. Kael seats the boards while Tor drives the last peg. The kitchen cart has a road.")
				_scene("work_road_finish")
		"greyfen_relief_board":
			if _flag("relief_deliveries_completed"):
				_scene("work_relief_return")
			elif _flag("cart_helped") or str(host.story_state.get_flag("mill_operation", "")) != "":
				_commit({"relief_shares_carried": true}, "Two household shares are ready. Deliver them to the west and east doorsteps marked by linen baskets.")
			else:
				host.hud.toast("The kitchen needs flour. Help Rook with the cart or settle the mill's food supply.")
		"relief_house_west", "relief_house_east":
			if _flag("relief_shares_carried"):
				var key := "relief_west_delivered" if id.ends_with("west") else "relief_east_delivered"
				if not _flag(key):
					_commit({key: true}, "A door opens. A share is weighed without asking for an oath.")
				if _flag("relief_west_delivered") and _flag("relief_east_delivered"):
					_commit({"assembly_relief_ready": true, "relief_deliveries_completed": true, "relief_shares_carried": false}, "Both household shares are delivered. The assembly can meet without using supper as a threat.")
					_scene("work_relief_finish")
		"mill_sluice":
			_commit({"mill_ventilation_open": true, "mill_escape_route_open": true}, "The sluice opens. Water strips the dust from the channel. Call the workers out and stay near them until they reach the south yard.")
		"mill_workers":
			if not _flag("mill_escape_route_open"):
				host.hud.toast("The exit is choked with dust. Open the marked sluice first.")
			elif not _flag("mill_workers_rescued"):
				_commit({"mill_escort_started": true}, "The workers follow the channel. Stay within a few paces; they stop if you leave them behind.")
		"mill_record_chest":
			_commit({"mill_records_saved": true}, "The wage chest is above the floodline. Whatever happens to the mill, the workers' shares can be proved.")
		"mill_ground_perch":
			_commit({"ashwing_perch_grounded": true}, "The hauling rope brings the rotten beam down. Ashwing loses its perch and is forced to recover on the ground.")
			for enemy in host.active_enemies:
				if is_instance_valid(enemy) and enemy.enemy_id == "ashwing" and not enemy.dead:
					enemy.interrupt_boss_windup("perch_grounded")
					enemy.stagger(4.0)
					enemy.attack_cooldown = maxf(enemy.attack_cooldown, 4.5)
		"root_testimony":
			if _flag("root_testimony_damaged"):
				_commit({"root_testimony_recovered": true}, "The broken board yields several names. These fragments can be kept, though its complete account was lost in the fight.")
				host.story_state.record_evidence("fragmented_name_board", {"kind": "fact", "zone": zone, "title": "Fragments of the damaged name-board"})
			else:
				_commit({"root_testimony_protected": true}, "The name-board is lifted into dry cloth. Redirect the marked roots to expose the heart without sacrificing this testimony.")
				host.story_state.record_evidence("protected_name_board", {"kind": "fact", "zone": zone, "title": "A name-board lifted out of the binding"})
		"vargan_service_shortcut":
			if not host.story_state.has_evidence("vargan_ledger") and not _flag("command_proof_recovered") and not host.quests.is_objective_done("main_blood_under_stone", "recover_ledger"):
				host.hud.toast("The passage lock bears the record keeper's seal. Find the command ledger inside Vargan first.")
			elif not _danger_near(host):
				_commit({"vargan_service_passage_known": true}, "The documented service passage leads directly to the record hall.")
				host._load_zone_after_runtime_pack("record_hall", Vector3(0, 1, 11))
		"senn_guard_stand_down":
			var knows_deserters: bool = host.story_state.has_evidence("deserters_muster") or bool(host.quests.evidence_history.get("side_soldiers_debt:find_deserters", false))
			if not knows_deserters and not _flag("relief_deliveries_completed"):
				host.hud.toast("They do not trust another promise. Read their hidden muster roll nearby, or bring proof that Greyfen is feeding households without demanding obedience.")
			elif not host.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation"):
				_commit({"senn_guards_stood_down": true, "senn_ready_to_testify": true}, "The soldiers lower their weapons. They surrender the road; what they did here still has to be answered.")
				for enemy in host.active_enemies:
					if is_instance_valid(enemy) and bool(enemy.get_meta("senn_guard", false)) and not enemy.dead:
						enemy.set_meta("story_surrender_protected", true)
						enemy.stagger(0.5)
						enemy.velocity = Vector3.ZERO
						enemy._hide_windup_marker()
				host.quests.complete_objective("main_soldier_without_banner", "senn_confrontation")
				_scene("soldiers_stand_down")
		"aftermath_names":
			if _flag("final_choice_completed"):
				_commit({"aftermath_names_returned": true}, "The account returns to the village that must live with it.")
				_scene("aftermath_names_" + str(host.story_state.get_flag("final_covenant", "witness")))
		"aftermath_work":
			if _flag("aftermath_names_returned"):
				_commit({"aftermath_work_promised": true}, "Kael takes a place at the workbench. A promise becomes an ordinary task.")
				_scene("aftermath_work_" + str(host.story_state.get_flag("final_covenant", "witness")))
		"aftermath_road":
			if _flag("aftermath_work_promised"):
				_commit({"aftermath_walk_completed": true, "aftermath_epilogue_pending": true}, "The road remains open. You can keep visiting Greyfen and the places you changed.")
				_scene("aftermath_road_" + str(host.story_state.get_flag("final_covenant", "witness")))
	refresh()

func _open_waypost() -> void:
	var model: Dictionary = get_waypost_model(host)
	var actions: Array = []
	var lines: Array[String] = ["The roads already marked:"]
	for route in model.get("routes", []):
		var destination: String = str(route.get("destination", ""))
		var label: String = str(route.get("name", ""))
		var work_count: int = int(route.get("work_count", 0))
		var work_note: String = " | %d unfinished task%s" % [work_count, "" if work_count == 1 else "s"] if work_count > 0 else ""
		lines.append("%s: %s%s" % [str(route.get("status", "Remembered")), label, work_note])
		if bool(route.get("available", false)):
			var preview := "Follow a road you have already walked. Your choices and unfinished work are kept."
			if work_count > 0:
				preview += " %d task%s you began wait here." % [work_count, "" if work_count == 1 else "s"]
			actions.append({"type":"story_travel", "label":"Return to " + label, "destination":destination, "preview":preview})
	var reason: String = str(model.get("reason", ""))
	lines.append(reason if reason != "" else "Choose a remembered road. There is no need to retrace every empty mile.")
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":"The roads already walked", "pages":[{"speaker":"The waypost", "speaker_id":"narrator", "text":"\n\n".join(lines)}], "actions":actions})

func _scene(id: String) -> void:
	var content: Dictionary = host.dialogue.get_dialogue(id)
	var actor_id := "sister_anwen" if id.begins_with("aftermath_names_") else "blacksmith_tor" if id.begins_with("aftermath_work_") or id.begins_with("work_road_") else "mira" if id.begins_with("work_relief_") else "captain_senn" if id == "soldiers_stand_down" else "rook"
	var scene_actor = host.zone_root.find_child(actor_id, true, false)
	if scene_actor != null:
		host._stage_dialogue_moment(scene_actor)
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue(content)

func _commit(flags: Dictionary, cue: String) -> void:
	host.story_state.begin_change()
	for key in flags:
		host.story_state.set_flag(str(key), flags[key])
	host.story_state.end_change()
	host.hud.toast(cue)
	host.hud.set_guidance_hint(cue, 8.0)
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")
	preload("res://scripts/story_world_director.gd").refresh(host)

func _flag(id: String) -> bool:
	return bool(host.story_state.get_flag(id, false))

func _physics_process(delta: float) -> void:
	if host == null or host.current_zone_id != zone or host.player == null:
		return
	escort_tick += delta
	if escort_tick >= 0.1:
		escort_tick = 0.0
		_refresh_carried_bundle()
	if zone != "old_mill" or worker_group == null or not _flag("mill_escort_started") or _flag("mill_workers_rescued"):
		escort_speed = 0.0
		_worker_motion(Vector3.ZERO, delta)
		return
	var player_distance: float = worker_group.global_position.distance_to(host.player.global_position)
	if player_distance > 6.5:
		escort_waiting_for_player = true
	elif player_distance < 5.5:
		escort_waiting_for_player = false
	var offset: Vector3 = escort_target - worker_group.position
	offset.y = 0.0
	var distance: float = offset.length()
	var desired_speed: float = 0.0 if escort_waiting_for_player else minf(1.55, sqrt(2.0 * 3.6 * maxf(distance - 0.10, 0.0)))
	escort_speed = move_toward(escort_speed, desired_speed, (3.6 if desired_speed < escort_speed else 2.8) * delta)
	var before: Vector3 = worker_group.global_position
	worker_group.position += offset.normalized() * minf(escort_speed * delta, distance)
	_worker_motion((worker_group.global_position - before) / maxf(delta, 0.001), delta)
	if worker_group.position.distance_to(escort_target) <= 0.2:
		_commit({"mill_workers_rescued": true, "mill_escort_started": false, "mill_escort_progress": 1.0}, "Both workers reach clean air. They will bring their own wage accounts to Greyfen.")
		host.story_state.record_evidence("mill_worker_account", {"kind":"testimony", "zone":zone, "title":"The mill workers reached the south yard alive"})
		refresh()
		escort_speed = 0.0
		_worker_motion(Vector3.ZERO, delta)
	else:
		# Lightweight progress for ordinary autosaves; no disk write every frame.
		var progress := clampf(1.0 - worker_group.position.distance_to(escort_target) / 10.5, 0.0, 0.98)
		host.story_state.flags["mill_escort_progress"] = progress

func _build_workers(root: Node3D) -> void:
	worker_group = Node3D.new()
	worker_group.name = "MillWorkersOnTheEscapeRoute"
	root.add_child(worker_group)
	var start := Vector3(-4.4, 0, -2.1)
	worker_group.position = start.lerp(escort_target, clampf(float(host.story_state.get_flag("mill_escort_progress", 0.0)), 0.0, 1.0))
	for index in range(2):
		var worker = host._make_role_visual("generic_villager_01" if index == 0 else "vargan_servant", "characters", Vector3.ONE)
		if worker != null:
			# Actor facing belongs to a wrapper. Keep the imported body's grounding
			# and source-forward correction intact beneath it.
			var body := Node3D.new()
			body.name = "MillWorkerBody%d" % index
			body.position = Vector3(float(index) * 0.7, 0, 0)
			var route_direction: Vector3 = (escort_target - start).normalized()
			body.rotation.y = atan2(-route_direction.x, -route_direction.z)
			body.set_meta("locomotion_owner", "mill_escort")
			worker.set_meta("locomotion_owner", "mill_escort")
			worker_group.add_child(body)
			body.add_child(worker)
			worker_bodies.append(body)
			host._configure_npc_animation(worker, "mill_worker_%d" % index)
			var driver = worker.get_node_or_null("CharacterAnimationDriver")
			if driver != null:
				driver.set_update_rate_hz(30.0)
				worker_drivers.append(driver)
			continue
		var torso := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.21
		shape.height = 1.10
		torso.mesh = shape
		torso.position = Vector3(float(index) * 0.7, 0.78, 0)
		torso.material_override = host._mat(Color(0.46, 0.36, 0.23) if index == 0 else Color(0.31, 0.38, 0.34))
		worker_group.add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.15
		head_mesh.height = 0.30
		head.mesh = head_mesh
		head.position = Vector3(float(index) * 0.7, 1.48, 0)
		head.material_override = host._mat(Color(0.56, 0.43, 0.32))
		worker_group.add_child(head)
	_label(worker_group, "MILL WORKERS\nStay nearby to lead them to clean air", Vector3(0.35, 2.05, 0))

func _worker_motion(world_velocity: Vector3, delta: float = 0.016667) -> void:
	if world_velocity.length_squared() > 0.001:
		var wanted_yaw: float = atan2(-world_velocity.x, -world_velocity.z)
		for body: Node3D in worker_bodies:
			if is_instance_valid(body):
				body.global_rotation.y = lerp_angle(body.global_rotation.y, wanted_yaw, 1.0 - exp(-7.0 * delta))
	for driver in worker_drivers:
		if is_instance_valid(driver):
			driver.set_distance_suspended(_flag("mill_workers_rescued"))
			driver.set_locomotion_motion(world_velocity, true)

func _refresh_carried_bundle() -> void:
	var carried := _flag("cart_sack_carried") or _flag("relief_shares_carried")
	var bundle = host.player.get_node_or_null("StoryWorkBundle")
	if not carried:
		if bundle != null:
			bundle.queue_free()
		return
	if bundle != null:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = "StoryWorkBundle"
	var sack := CylinderMesh.new()
	sack.top_radius = 0.13
	sack.bottom_radius = 0.25
	sack.height = 0.52
	sack.radial_segments = 8
	mesh.mesh = sack
	mesh.position = Vector3(-0.30, 0.90, 0.24)
	mesh.rotation_degrees.z = -14.0
	mesh.material_override = host._mat(Color(0.57, 0.47, 0.29))
	host.player.add_child(mesh)

func _point(root: Node3D, id: String, prompt: String, pos: Vector3, title: String, color: Color) -> void:
	if root.find_child(id, true, false) != null:
		return
	var area = Interactable.new()
	area.setup(id, "story_activity", prompt)
	area.position = pos
	area.build_collision(1.1)
	root.add_child(area)
	area.add_to_group("story_activity")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.40, 0.40)
	mesh.mesh = box
	mesh.position.y = 0.20
	mesh.material_override = host._mat(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(mesh)
	_label(area, title, Vector3(0, 1.25, 0))
	host._connect_interactable(area)

func _label(parent: Node3D, words: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.004
	label.outline_size = 5
	label.modulate = Color(0.91, 0.85, 0.66)
	label.visibility_range_end = 14.0
	parent.add_child(label)
