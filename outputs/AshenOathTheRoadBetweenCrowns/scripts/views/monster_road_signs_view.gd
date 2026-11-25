extends RefCounted
## Mounts and reads the physical signs left by creatures on the road.
const ROAD_SIGN := "wychwood_axle_ring"
const ROAD_EVIDENCE := "wychwood_road_signal"

static func mount(director: Node, root: Node3D) -> void:
	for creature: String in director.APPROACH_SIGNS:
		var sign: Dictionary = director.APPROACH_SIGNS[creature]
		if str(sign.zone) != director.zone: continue
		var position: Vector3 = sign.position
		if director.host.spatial_service != null:
			position = director.host.spatial_service.validate_position(position, 0.6, director.host.spatial_service.bank_for(position))
		director._point(root, "approach_" + creature, str(sign.prompt), position, str(sign.title), Color(0.50,0.48,0.40))
		var area := root.find_child("approach_" + creature, true, false) as Node3D
		if area != null:
			preload("res://scripts/saga_work_presentation.gd").clue_visual(director.host, area, str(sign.prompt))
	if director.zone == "wychwood":
		director._point(root, ROAD_SIGN, "Listen at the axle ring", Vector3(3.25, 0, 3.35), "THE AXLE RING", Color(0.42, 0.32, 0.22))
		var ring := root.find_child(ROAD_SIGN, true, false) as Node3D
		if ring != null:
			preload("res://scripts/views/wychwood_carter_art.gd").add_axle(ring)

static func _road_raider(game: Node) -> Node3D:
	if not game.quests.is_active("main_road_of_crows") or game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		return null
	if game.wychwood_pack_kills > 3 or bool(game.story_state.get_flag("wychwood_raider_truce_broken", false)):
		return null
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and str(enemy.enemy_id) == "wychwood_raider" and game.zone_root.is_ancestor_of(enemy):
			return enemy
	return null

static func _road_sign_in_reach(game: Node, area: Node3D) -> bool:
	return str(game.current_zone_id) == "wychwood" and is_instance_valid(game.zone_root) and is_instance_valid(area) and game.zone_root.is_ancestor_of(area) and str(area.get("interaction_id")) == ROAD_SIGN and area.is_visible_in_tree() and area.is_interaction_enabled() and is_instance_valid(game.player) and game.player.can_control and game.player.global_position.distance_to(area.global_position) <= 3.2 and not game.zone_transition_in_progress

static func _knows_token(game: Node) -> bool:
	return bool(game.story_state.get_flag("road_evidence_oren", false)) or game.quests.is_objective_done("main_road_of_crows", "oren")

static func _attach_road_knocks(content: Dictionary, axle: Vector3, bank: Vector3, listener: Vector3) -> void:
	for page: Dictionary in content.get("pages", []):
		match str(page.get("line_id", "")):
			"wychwood.ring.call":
				page["road_knocks"] = [{"id": "wychwood_road_call", "source": axle, "listener": listener}]
			"wychwood.ring.voice":
				page["road_knocks"] = [{"id": "wychwood_road_answer", "source": bank, "listener": listener}]
			"wychwood.ring.offered":
				page["road_knocks"] = [{"id": "wychwood_road_grant", "source": axle, "listener": listener},
					{"id": "wychwood_road_ack", "source": bank, "listener": listener}]
			"wychwood.ring.silence_heard":
				page["road_knocks"] = [{"id": "wychwood_road_ack", "source": bank, "listener": listener}]

static func open_road_sign(game: Node, area: Node3D) -> void:
	if not _road_sign_in_reach(game, area):
		return
	if game._story_has_active_combat():
		game.hud.toast("Steel and footfalls drown out the ring.")
		return
	var answer := str(game.story_state.get_flag("wychwood_road_answer", ""))
	var content: Dictionary
	var raider := _road_raider(game)
	var fresh: bool = answer.is_empty() and _knows_token(game) and raider != null
	if not fresh:
		var reading := "empty" if answer.is_empty() else answer
		if answer.is_empty() and raider != null:
			reading = "unread"
		content = game.dialogue.get_dialogue("wychwood_ring_remembered")
		var pages: Array = content.get("pages", [])
		var selected: Array = []
		for page: Dictionary in pages:
			if str(page.get("line_id", "")) == "wychwood.ring." + reading:
				selected.append(page)
		content["pages"] = selected
	else:
		content = game.dialogue.get_dialogue(ROAD_SIGN)
		_attach_road_knocks(content, area.global_position, raider.global_position, game.player.global_position)
		for action: Dictionary in content.get("actions", []):
			if action.get("type") == "wychwood_road_reply":
				action["road_sign_instance"] = area.get_instance_id()
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	game.hud.show_dialogue(game._prepare_dialogue_presence(content))

static func answer_road_sign(game: Node, action: Dictionary) -> void:
	var instance_id := int(action.get("road_sign_instance", 0))
	var area := instance_from_id(instance_id) as Node3D if instance_id > 0 and is_instance_id_valid(instance_id) else null
	var answer := str(action.get("answer", ""))
	if answer not in ["open_hand", "silence"] or not _road_sign_in_reach(game, area) or not _knows_token(game) or not str(game.story_state.get_flag("wychwood_road_answer", "")).is_empty():
		return
	var raider := _road_raider(game)
	if raider == null or game._story_has_active_combat():
		return
	game.story_state.begin_change()
	game.story_state.set_flag("wychwood_road_answer", answer)
	game.story_state.record_evidence(ROAD_EVIDENCE, {"zone":"wychwood", "kind":"observed"})
	game.story_state.end_change()
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	var content: Dictionary = game.dialogue.get_dialogue("wychwood_ring_" + answer)
	_attach_road_knocks(content, area.global_position, raider.global_position, game.player.global_position)
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	game.hud.show_dialogue(game._prepare_dialogue_presence(content))
