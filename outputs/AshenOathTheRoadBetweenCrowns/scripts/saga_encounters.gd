extends RefCounted

const Catalog = preload("res://scripts/saga_catalog.gd")
const BOG_CENTER := Vector3(0, 0, -9.0)

static func refresh(game, owner) -> void:
	if str(game.current_zone_id) == "wychwood" and game.quests.is_active("main_teeth_in_rain") and game.quests.is_objective_done("main_teeth_in_rain", "name_the_dead"):
		if not game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
			if not game._has_living_enemy("bog_wretch"):
				owner._point("saga_bog_challenge", "Enter the Bog Wretch's northern clearing", "bog", "record")
		elif not game.quests.is_objective_done("main_teeth_in_rain", "bog_core_choice") and not game._has_interactable("bog_core_choice"):
			game._make_named_interactable("bog_core_choice", "dialogue", "Choose the memory core's fate", BOG_CENTER, Color(0.35,0.58,0.52), Vector3.ONE * 0.4)
	if str(game.current_zone_id) != "bandit_road":
		return
	var pending: bool = game.quests.is_active("main_soldier_without_banner") and not game.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") and str(game.story_state.get_flag("senn_fate", "")) in ["", "unresolved"]
	var senn: Node3D = game.zone_root.find_child("captain_senn", true, false)
	var fighter: Node
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id) == "captain_senn":
			fighter = enemy
			break
	if pending and not game._has_living_enemy("captain_senn"):
		owner._point("saga_senn_challenge", "Challenge Senn, or earn the soldiers' stand-down", "command", "record")
	if fighter != null:
		if not pending:
			fighter.set_meta("story_surrender_protected", true)
			fighter.set_encounter_active(false)
			fighter.visible = false
			fighter.collision_layer = 0
			fighter.collision_mask = 0
		if senn != null:
			senn.visible = not pending
			senn.set_interaction_enabled(not pending)
			if pending:
				game._remove_interaction_candidate(senn)

static func activate(game, id: String, _area: Node3D) -> void:
	if id == "saga_bog_challenge":
		if str(game.current_zone_id) != "wychwood" or not game.quests.is_objective_done("main_teeth_in_rain", "name_the_dead") or game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch") or game._has_living_enemy("bog_wretch"):
			return
		var bog = game._spawn_enemy("bog_wretch", BOG_CENTER)
		if bog != null:
			bog.leash_radius = 5.5
			game.story_state.set_flag("saga_bog_arena_owner", "wychwood")
			game.hud.toast("The frightened memory gathers in the northern clearing. Ash, Moon Oil, heavy blows and parries still expose its core.")
	elif id == "saga_senn_challenge":
		if str(game.current_zone_id) != "bandit_road" or not game.quests.is_active("main_soldier_without_banner") or game.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or game._has_living_enemy("captain_senn"):
			return
		var senn = game._spawn_enemy("captain_senn", Vector3(7,0,-0.5))
		if senn != null:
			senn.leash_radius = 7.0
			game.hud.toast("Senn draws. Read the raised shoulder, parry his stroke or break his guard. Defeat does not decide his fate.")
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	var owner: Node = game.zone_root.get_node_or_null("StoryActivities/SixWorldStories")
	if owner != null:
		owner.refresh()

static func senn_yields(game, actor: Node) -> void:
	if not is_instance_valid(game) or not is_instance_valid(actor) or str(actor.enemy_id) != "captain_senn":
		return
	actor.set_meta("story_surrender_protected", true)
	actor.set_encounter_active(false)
	actor.velocity = Vector3.ZERO
	actor.pending_attack_time = 0
	game.story_state.begin_change()
	game.quests.begin_change()
	game.story_state.set_flag("saga_senn_guard_broken", true)
	game.story_state.set_flag("senn_ready_to_testify", true)
	game.quests.complete_objective("main_soldier_without_banner", "senn_confrontation")
	for guard in game.active_enemies:
		if is_instance_valid(guard) and bool(guard.get_meta("senn_guard", false)) and not guard.dead:
			guard.set_meta("story_surrender_protected", true)
			guard.set_encounter_active(false)
			guard.velocity = Vector3.ZERO
	game.story_state.end_change()
	game.quests.end_change()
	var controller := actor.get_node_or_null("BossEncounterController")
	if controller != null:
		controller.resolve_peaceful("guard_broken")
	game.hud.toast("Senn yields, alive. Speak to him at the command table: custody, exile and execution remain your existing choices.")
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	var owner: Node = game.zone_root.get_node_or_null("StoryActivities/SixWorldStories")
	if owner != null:
		owner.queue_refresh()
