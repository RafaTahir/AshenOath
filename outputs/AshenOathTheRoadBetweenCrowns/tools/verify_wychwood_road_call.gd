extends SceneTree
## The forest exchange uses real quest, story, dialogue and journal models.
const Road = preload("res://scripts/views/monster_road_signs_view.gd")
const Journal = preload("res://scripts/story_journal.gd")
const Interactable = preload("res://scripts/interactable.gd")
const QUEST := "main_road_of_crows"

class Player extends Node3D:
	var can_control := true

class Raider extends Node3D:
	var dead := false
	var enemy_id := "wychwood_raider"

class Audio extends RefCounted:
	var paused := false
	var cues: Array[String] = []
	var sources: Array[Vector3] = []
	var listeners: Array[Vector3] = []
	func set_game_paused(value: bool) -> void:
		paused = value
	func play_dialogue_page(page: Dictionary) -> void:
		for knock: Dictionary in page.get("road_knocks", []):
			if paused:
				cues.append(knock.id)
				sources.append(knock.source)
				listeners.append(knock.listener)

class Hud extends RefCounted:
	var content: Dictionary = {}
	var warning := ""
	var audio: Audio
	func show_dialogue(value: Dictionary) -> void:
		content = value
		present_page(0)
	func present_page(index: int) -> void:
		audio.play_dialogue_page(content.pages[index])
	func toast(text: String) -> void:
		warning = text

class Game extends Node3D:
	var current_zone_id := "wychwood"
	var zone_transition_in_progress := false
	var wychwood_pack_kills := 0
	var zone_root := Node3D.new()
	var active_enemies: Array = []
	var player := Player.new()
	var audio := Audio.new()
	var hud := Hud.new()
	var story_state := preload("res://scripts/story_state.gd").new()
	var quests := preload("res://scripts/quest_manager.gd").new()
	var dialogue := preload("res://scripts/dialogue_manager.gd").new()
	var danger := false
	var story_save_pending := false
	func _story_has_active_combat() -> bool: return danger
	func _prepare_dialogue_presence(content: Dictionary) -> Dictionary: return content
	func _persist_story_action() -> void: pass

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	for choice in ["open_hand", "silence"]:
		var game := Game.new()
		root.add_child(game)
		game.hud.audio = game.audio
		game.add_child(game.story_state)
		game.add_child(game.quests)
		game.add_child(game.dialogue)
		game.add_child(game.zone_root)
		game.zone_root.position = Vector3(40, 0, -80)
		game.zone_root.add_child(game.player)
		var sign := Interactable.new()
		sign.setup("wychwood_axle_ring", "story_activity", "Listen at the axle ring")
		game.zone_root.add_child(sign)
		var raider := Raider.new()
		game.zone_root.add_child(raider)
		raider.position = Vector3(4.6, 0, -5.3)
		game.active_enemies.append(raider)
		game.quests.load_quests("res://data/quests.json")
		game.quests.start_quest(QUEST)
		game.dialogue.setup(game.story_state, game.quests)
		for path in ["dialogue", "campaign_dialogue", "interaction_scenes"]:
			game.dialogue.load_dialogue("res://data/" + path + ".json")
		game.dialogue.load_conversation_topics("res://data/conversation_topics.json")
		_check(Journal.evidence_detail(Road.ROAD_EVIDENCE, game.quests, game.story_state).is_empty(), "The journal revealed an unheard call.")
		Road.open_road_sign(game, sign)
		_check(game.hud.content.get("scene_id") == "wychwood_ring_remembered" and game.hud.content.pages.size() == 1 and game.audio.cues.is_empty(), "The creature answered before Oren's token was known.")
		game.quests.complete_evidence(QUEST, "oren")
		paused = false
		game.danger = true
		Road.open_road_sign(game, sign)
		_check(not game.hud.warning.is_empty() and game.audio.cues.is_empty(), "Nearby combat must interrupt the road conversation.")
		game.danger = false
		Road.open_road_sign(game, sign)
		_check(game.hud.content.get("scene_id") == Road.ROAD_SIGN and game.hud.content.pages.size() == 3, "Indexed opening road scene was not available.")
		_check(game.audio.cues == ["wychwood_road_call"] and game.audio.sources[0] == sign.global_position, "The knock must originate on the actual axle.")
		game.hud.present_page(1)
		game.hud.present_page(2)
		_check(game.audio.cues == ["wychwood_road_call", "wychwood_road_answer"] and game.audio.sources[1] == raider.global_position, "The throat clicks must appear with the far-bank caption.")
		var reply: Dictionary
		for action: Dictionary in game.hud.content.get("actions", []):
			if action.get("answer") == choice:
				reply = action
		_check(not reply.is_empty(), "Missing authored option " + choice)
		var quest_before := game.quests.save_state().duplicate(true)
		game.player.position.x = 12
		Road.answer_road_sign(game, reply)
		game.player.position.x = 0
		game.current_zone_id = "greyfen"
		Road.answer_road_sign(game, reply)
		game.current_zone_id = "wychwood"
		game.story_state.set_flag("wychwood_raider_truce_broken", true)
		Road.answer_road_sign(game, reply)
		game.story_state.set_flag("wychwood_raider_truce_broken", false)
		raider.dead = true
		Road.answer_road_sign(game, reply)
		raider.dead = false
		_check(not game.story_state.has_evidence(Road.ROAD_EVIDENCE) and game.audio.cues.size() == 2, "An unavailable Raider or stale action committed a choice.")
		Road.answer_road_sign(game, reply)
		_check(game.story_state.get_flag("wychwood_road_answer") == choice and game.story_state.has_evidence(Road.ROAD_EVIDENCE), "Missing saved answer " + choice)
		var expected := ["wychwood_road_call", "wychwood_road_answer"]
		var positions := [sign.global_position, raider.global_position]
		if choice == "open_hand":
			expected.append("wychwood_road_grant")
			positions.append(sign.global_position)
		expected.append("wychwood_road_ack")
		positions.append(raider.global_position)
		game.hud.present_page(1)
		_check(game.hud.content.get("scene_id") == "wychwood_ring_" + choice and game.audio.cues == expected and game.audio.sources == positions, "The response must match the chosen gesture and the actual banks.")
		_check(game.audio.listeners.all(func(point): return point == game.player.global_position), "The signal used a stale listening position.")
		_check(game.quests.save_state() == quest_before and game.wychwood_pack_kills == 0, "Listening must never resolve the encounter or award a quest objective.")
		Road.answer_road_sign(game, reply)
		Road.open_road_sign(game, sign)
		_check(game.hud.content.pages.size() == 1 and game.hud.content.pages[0].line_id == "wychwood.ring." + choice and game.audio.cues == expected, "A repeated offer replayed its effects or changed the answer.")
		var snapshot := game.story_state.save_state().duplicate(true)
		game.story_state.load_state({})
		game.story_state.load_state(snapshot)
		_check(game.story_state.get_flag("wychwood_road_answer") == choice and not Journal.evidence_detail(Road.ROAD_EVIDENCE, game.quests, game.story_state).is_empty(), "Restoring the story lost the encounter or its journal record.")
		if choice == "open_hand":
			game.story_state.set_flag("wychwood_raider_spared", true)
			var texts: Array = game.dialogue.get_dialogue("report_decision").pages.map(func(page): return page.text)
			_check("Four fell. The one with the cord stepped aside and lived. Here is what I could establish on the road." in texts and "The pack is dead. Here is what I could establish on the road." not in texts, "The village reported killing a spared Raider.")
		paused = false
		game.free()
	print("WYCHWOOD ROAD CALL: ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
