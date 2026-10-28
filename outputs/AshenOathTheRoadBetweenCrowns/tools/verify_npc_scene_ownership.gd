extends SceneTree
## Ambient scene interruption must preserve an escort's control and save checkpoint.
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Story = preload("res://scripts/story_state.gd")
const Audio = preload("res://scripts/audio_manager.gd")

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class Player extends Node3D:
	var can_control := true
	var attack_anim_time := 0.0
	var beam_cast_state := ""
	var sword_sheathed := true
	var bow_aiming := false

class Driver extends Node:
	var activity := "working"
	var clears := 0
	func get_visible_forward() -> Vector3: return Vector3.FORWARD
	func clear_life_activity() -> void:
		activity = ""
		clears += 1
	func set_carried_activity(_value: String) -> void: pass
	func set_life_workstation(_value: Dictionary) -> void: pass
	func stop_story_gesture() -> void: clears += 1
	func set_dialogue_pose(_active: bool) -> void: clears += 1

class Face extends Node:
	var focus_target: Node3D
	var expression := "neutral"
	var conversation := false
	var speech := 0.0
	func set_conversation_active(value: bool) -> void: conversation = value
	func set_speech_amount(value: float) -> void: speech = value
	func set_focus_target(value: Node3D) -> void: focus_target = value
	func set_expression(value: String) -> void: expression = value

class Hud extends Node:
	var clears := 0
	func ambient_subtitle_available(_owner: int) -> bool: return true
	func clear_ambient_subtitle(_owner: int) -> void: clears += 1

class Host extends Node3D:
	var player := Player.new()
	var story_state := Story.new()
	var zone_root := Node3D.new()
	var hud := Hud.new()
	var audio := Audio.new()
	var quests: Node
	var day_night: Node
	var current_zone_id := "greyfen"
	var zone_transition_pending := false
	var story_save_pending := false
	func _ready() -> void:
		for child in [player, story_state, zone_root, hud, audio]: add_child(child)
		audio.set_process(false)
	func _story_has_active_combat() -> bool: return false

var checks := 0
var failures: Array[String] = []
var error_log := ErrorLog.new()

func _initialize() -> void: call_deferred("_run")

func _fixture() -> Dictionary:
	var host := Host.new()
	root.add_child(host)
	var life := Life.new()
	host.zone_root.add_child(life)
	life.set_process(false)
	life.host = host
	life.player = host.player
	var entries: Array[Dictionary] = []
	for id: String in ["walker_well", "walker_board"]:
		var actor := Node3D.new()
		host.zone_root.add_child(actor)
		var driver := Driver.new()
		actor.add_child(driver)
		var face := Face.new()
		actor.add_child(face)
		var entry: Dictionary = life._make_entry(id, actor, [Vector3.ZERO], 0.62, driver, false)
		entry.face = face
		life.actors.append(entry)
		entries.append(entry)
	var scene := {"id":"ownership_fixture", "zone":"greyfen", "kind":"exchange", "actors":["walker_well", "walker_board"], "turns":[["walker_well", "Keeper", "First beat."], ["walker_board", "Reader", "Second beat."]], "walk":[[0, 0, -1], [0, 0, -2]]}
	var checkpoint := {"index":1, "walk_index":1, "signature":JSON.stringify(scene.turns).sha256_text()}
	host.story_state.set_flag("world_scene_progress", {"ownership_fixture":checkpoint})
	return {"host":host, "life":life, "entries":entries, "scene":scene}

func _run() -> void:
	OS.add_logger(error_log)
	_verify_start_guard()
	_verify_takeover()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "no engine or script errors")
	for error: String in error_log.errors: print("NPC SCENE OWNERSHIP ENGINE ERROR: " + error)
	print("NPC SCENE OWNERSHIP: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _verify_start_guard() -> void:
	var f := _fixture()
	var owned: Dictionary = f.entries[1]
	owned.node.set_meta("locomotion_owner", "scripted_escort")
	_check(not f.life._social_actor_available(owned), "foreign motion owner is unavailable for social exchange")
	f.life._start_world_scene(f.scene, f.entries)
	_check(f.life.social_scene.is_empty(), "world scene refuses an actor already controlled by an escort")
	for entry: Dictionary in f.entries:
		_check(not entry.node.has_meta("cast_social_owner") and entry.driver.clears == 0, "failed cast preflight leaves every participant unclaimed and unchanged")
	_check(not f.host.story_save_pending, "refused start does not request a save")
	f.host.free()

func _verify_takeover() -> void:
	var f := _fixture()
	var before: Dictionary = f.host.story_state.flags.duplicate(true)
	f.life._start_world_scene(f.scene, f.entries)
	_check(not f.life.social_scene.is_empty() and f.life.social_scene.index == 1 and f.life.social_scene.walk_index == 1, "scene resumes its existing completed-beat checkpoint")
	var entry: Dictionary = f.entries[0]
	entry.node.set_meta("locomotion_owner", "scripted_escort")
	entry.node.position = Vector3(2, 0, -1)
	entry.node.rotation.y = 0.7
	entry.driver.activity = "escort_handoff"
	entry.driver.clears = 0
	entry.face.conversation = true
	entry.face.speech = 0.6
	entry.face.expression = "determined"
	entry.face.focus_target = f.host.player
	var voice := AudioStreamPlayer3D.new()
	f.host.audio.add_child(voice)
	voice.stream = AudioStreamWAV.new()
	f.host.audio.nearby_voice_player = voice
	f.host.audio.nearby_voice_actor = weakref(entry.node)
	f.host.audio.nearby_voice_face = entry.face
	f.host.audio.nearby_voice_entry = {"duration_seconds":3.0}
	entry.route = [Vector3(0, 0, -4)]
	entry.motion_speed = 0.6
	f.life._tick_world_scene(0.05)
	_check(f.life.social_scene.is_empty(), "mid-scene escort takeover cancels ambient performance")
	_check(entry.node.position == Vector3(2, 0, -1) and is_equal_approx(entry.node.rotation.y, 0.7), "cancellation does not translate or rotate the escort actor")
	_check(entry.driver.activity == "escort_handoff" and entry.driver.clears == 0, "cancellation leaves the escort's animation untouched")
	_check(entry.face.conversation and entry.face.speech == 0.6 and entry.face.expression == "determined" and entry.face.focus_target == f.host.player, "cancellation preserves the new owner's face and focus")
	_check(f.host.audio.nearby_voice_player == null and f.host.audio.nearby_voice_actor == null and f.host.audio.nearby_voice_face == null and f.host.audio.nearby_voice_entry.is_empty() and voice.stream == null, "interrupted ambient voice releases audio and face references")
	_check(entry.node.get_meta("locomotion_owner") == "scripted_escort" and not entry.node.has_meta("cast_social_owner"), "only this controller's social claim is released")
	_check(entry.route.is_empty() and entry.motion_speed == 0.0 and entry.social_time == 0.0, "cancelled ambient motion bookkeeping is released")
	_check(f.host.story_state.flags == before and not f.host.story_save_pending, "interruption neither advances the scene checkpoint nor marks it heard")
	_check(f.entries[1].driver.activity == "" and not f.entries[1].node.has_meta("cast_social_owner") and f.host.hud.clears == 1, "unowned participant and ambient subtitle are cleaned up")
	entry.node.set_meta("locomotion_owner", "greyfen_life")
	f.life._start_world_scene(f.scene, f.entries)
	_check(f.life.social_scene.index == 1 and f.life.social_scene.walk_index == 1, "returning actor resumes the same completed beat and walk step")
	f.life._end_social_exchange()
	entry.face.speech = 0.6
	f.host.audio.nearby_voice_actor = weakref(entry.node)
	f.host.audio.nearby_voice_face = entry.face
	f.host.audio.stop_nearby_speech(entry.node)
	_check(entry.face.speech == 0.0, "ordinary nearby speech stop retains its default face reset")
	f.host.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("NPC SCENE OWNERSHIP FAILURE: " + label)
