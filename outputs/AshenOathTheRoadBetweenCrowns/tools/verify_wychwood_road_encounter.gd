extends SceneTree

## Exercises the encounter owners directly, including the regular interaction
## signal, attack commitment and saved-choice gates. Uses no filesystem saves.
const Pack = preload("res://scripts/views/wychwood_pack_encounter.gd")
const Navigation = preload("res://scripts/views/enemy_navigation_view.gd")
const Strike = preload("res://scripts/views/enemy_strike_view.gd")

class Loadout extends RefCounted:
	var drawn := false
	var transitioning := false
	func is_drawn() -> bool: return drawn
	func is_transitioning() -> bool: return transitioning

class Player extends CharacterBody3D:
	var can_control := true
	var bow_aiming := false
	var attack_anim_time := 0.0
	var beam_cast_state := ""
	var equipment_loadout = Loadout.new()
	var movement_state := "walk"

class Actor extends CharacterBody3D:
	signal damaged(enemy: Node, current: float, maximum: float)
	var enemy_id := "wychwood_raider"
	var wave := 3
	var encounter_active := true
	var can_see_player := true
	var dead := false
	var resolved_nonlethal := false
	var surrender_offer := false
	var surrender_declined := false
	var pending_attack_time := 0.0
	var attack_windup_total := 0.72
	var attack_range := 1.5
	var attack_recovery_time := 0.0
	var stagger_time := 0.0
	var perception_memory_time := 0.0
	var health_component := {"health":75.0,"max_health":75.0}
	var line_clear := true
	var animation_driver: Node
	var enemy_navigation_view: RefCounted
	var spatial_service: RefCounted = RefCounted.new()
	var home_position := Vector3.ZERO
	var heard_cue_deadline := 0
	var leash_radius := 14.0
	var ambient_state := ""
	var ambient_target := Vector3.INF
	var ambient_remaining := 0.0
	var navigation_target := Vector3.ZERO
	var navigation_refresh_time := 0.0
	var player: Node3D
	var attack_trace_end := Vector3.ZERO
	func read_presentation_tag(_node: Node, key: StringName, fallback: Variant = null) -> Variant:
		match key:
			&"wychwood_wave": return wave
			&"progression_opening_wave": return true
		return fallback
	func write_presentation_tag(node: Node, key: StringName, value: Variant) -> void: node.set_meta(key, value)
	func _has_attack_line() -> bool: return line_clear
	func _attack_contact_point() -> Vector3: return global_position

class Interaction extends Node3D:
	var enabled := false
	func set_interaction_enabled(value: bool) -> void: enabled = value

class State extends RefCounted:
	var flags := {}
	func get_flag(key: String, fallback: Variant) -> Variant: return flags.get(key, fallback)
	func set_flag(key: String, value: Variant) -> void: flags[key] = value
	func is_active(id: String) -> bool: return id == "main_road_of_crows"

class Story extends Node:
	var zone_root := Node3D.new()
	var current_zone_id := "wychwood"
	var wychwood_pack_kills := 3
	var story_state := State.new()
	var quests := State.new()
	var player := Player.new()
	var active_enemies: Array = []
	var hud: Variant
	var audio: Variant
	var combat: Variant
	var progression: Variant
	var spatial_service: RefCounted
	var cleared := 0
	var awards := 0
	var saved := 0
	var audio_steps := 0
	var surrender_targets: Array[Dictionary] = []
	var host: Node
	var area: Interaction
	func point_action(id: String, _prompt: String, pos: Vector3) -> Node:
		assert(id == "road_call")
		area = Interaction.new()
		zone_root.add_child(area)
		area.global_position = pos
		return area
	func persist() -> void: saved += 1
	func toast(_text: String) -> void: pass
	func hide_enemy() -> void: pass
	func _record_encounter_knowledge(_enemy: Node) -> void: story_state.set_flag("known", true)
	func award_encounter(key: String, zone: String, _label: String) -> void:
		assert(key == "opening_wave:3" and zone == "wychwood")
		awards += 1
	func _collect_progression_rewards() -> void: pass
	func _activate_wychwood_wave(ids: Array, _cue: String) -> void:
		assert(ids == ["wychwood_brute"])
		cleared += 1
	func foot_surface(_player: Node3D, value: String) -> String: return value
	func play_footstep(_zone: String, _road: bool, _surface: String) -> void: audio_steps += 1

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := Story.new()
	root.add_child(game)
	game.host = game
	game.progression = game
	game.hud = game
	game.combat = game
	game.audio = game
	game.add_child(game.zone_root)
	game.zone_root.add_child(game.player)
	var actor := Actor.new()
	game.zone_root.add_child(actor)
	game.active_enemies.append(actor)
	actor.player = game.player
	actor.position = Vector3(0, 0, -2)
	var nav := Navigation.new(actor)
	actor.enemy_navigation_view = nav
	Pack.install_targets(game)
	check(game.area.get_parent() == actor and not game.area.enabled, "action attached to the moving Raider and initially unavailable")
	for answer: String in ["", "silence"]:
		game.story_state.set_flag(Pack.ANSWER, answer)
		Pack.tick_targets(game)
		check(not actor.surrender_offer and not game.area.enabled, "absent or silent response keeps the ordinary encounter")
	actor.damaged.emit(actor, 70.0, 75.0)
	check(game.story_state.get_flag(Pack.BROKEN, false) and game.saved == 1, "earlier violence survives a later bridge choice")
	game.story_state.set_flag(Pack.ANSWER, "open_hand")
	Pack.tick_targets(game)
	check(not actor.surrender_offer, "broken trust survives restoring the wave")
	game.story_state.flags.erase(Pack.BROKEN)
	actor.can_see_player = false
	Pack.tick_targets(game)
	check(not actor.surrender_offer, "no greeting through cover")
	actor.can_see_player = true
	actor.pending_attack_time = 0.2
	Pack.tick_targets(game)
	check(not actor.surrender_offer, "an active telegraph retains ownership")
	actor.pending_attack_time = 0.0
	game.player.equipment_loadout.drawn = true
	Pack.tick_targets(game)
	check(actor.surrender_offer and not game.area.enabled and not Pack.answer(game, game.area), "the Raider waits while Kael is armed")
	game.player.equipment_loadout.drawn = false
	game.player.equipment_loadout.transitioning = true
	check(not Pack.answer(game, game.area), "sheathing must finish")
	game.player.equipment_loadout.transitioning = false
	Pack.tick_targets(game)
	check(game.area.enabled, "empty hands reveal the ordinary interact action")
	actor.position.z = -3
	check(not Pack.answer(game, game.area), "no remote interaction")
	actor.position.z = -2
	actor.line_clear = false
	check(not Pack.answer(game, game.area), "a blocker denies the offer")
	actor.line_clear = true
	game.wychwood_pack_kills = 2
	check(not Pack.answer(game, game.area), "neighboring waves cannot claim the truce")
	game.wychwood_pack_kills = 3
	check(Pack.answer(game, game.area), "explicit empty-hand answer succeeds")
	check(not actor.dead and actor.resolved_nonlethal and not actor.encounter_active and not game.area.enabled, "Raider lives and leaves combat")
	check(game.wychwood_pack_kills == 4 and game.cleared == 1 and game.awards == 1 and game.story_state.get_flag(Pack.SPARED, false), "saved cursor, reward and Brute advance agree")
	check(game.story_state.get_flag("known", false), "close encounter records a bestiary observation")
	check(not Pack.answer(game, game.area) and game.awards == 1, "repeat input cannot advance twice")

	actor.enemy_id = "ghoulkin"
	actor.resolved_nonlethal = false
	actor.encounter_active = true
	actor.can_see_player = false
	Pack.footfall(game)
	check(actor.ambient_target == Vector3.INF, "walking behind cover makes no running trail")
	game.player.movement_state = "run"
	Pack.footfall(game)
	check(actor.ambient_target == game.player.global_position and not actor.can_see_player and actor.perception_memory_time == 0.0, "a running footfall gives a position without granting sight")
	actor.ambient_target = Vector3.INF
	actor.heard_cue_deadline = 0
	actor.encounter_active = false
	Pack.footfall(game)
	check(actor.ambient_target == Vector3.INF, "dormant wave does not hear Kael")
	actor.encounter_active = true
	actor.enemy_id = "wychwood_stalker"
	actor.can_see_player = true
	nav._observe_stalker(0.03, 2.0)
	check(nav._stalker_circling, "Stalker approaches the flank when watched")
	nav._observe_stalker(1.2, 2.0)
	check(not nav._stalker_circling, "a steady gaze cannot hold the Stalker forever")
	actor.can_see_player = false
	nav._observe_stalker(0.03, 2.0)
	actor.can_see_player = true
	game.player.rotation.y = PI
	nav._observe_stalker(0.03, 2.0)
	check(not nav._stalker_circling, "a turned back opens the line immediately")
	actor.position = Vector3.ZERO
	game.player.position = Vector3(0.8, 0, -1.3)
	actor.rotation.y = 0.0
	actor.pending_attack_time = 0.70
	actor.enemy_id = "wychwood_brute"
	var strike := Strike.new(actor)
	strike._tick_pending_attack(0.1)
	check(is_zero_approx(actor.rotation.y) and is_equal_approx(actor.pending_attack_time, 0.60), "Brute holds its planted heading and original contact clock")
	actor.enemy_id = "ghoulkin"
	strike._tick_pending_attack(0.1)
	check(not is_zero_approx(actor.rotation.y), "other species retain early windup tracking")
	game.free()
	print(JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
