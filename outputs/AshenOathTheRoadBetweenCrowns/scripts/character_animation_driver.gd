extends Node

signal action_started(action_name: String)
signal action_finished(action_name: String)
signal contract_failed(reason: String)

const STATE_ALIASES := {
	"idle": ["idle", "idlesword", "idleweapon", "attackingidle"],
	"walk": ["walk", "walking"],
	"run": ["run", "running", "sprint"],
	"jump": ["jump", "jumpidle", "run"],
	"attack": ["attack", "swordslash", "punch"],
	"attack_light": ["swordslash", "attack", "punch"],
	"attack_heavy": ["swordslash", "attack", "punch"],
	"dodge": ["roll", "dodge", "run"],
	"parry": ["parry", "block", "hitreceive", "hitrecieve", "receivehit", "recievehit"],
	"beam_cast": ["interact", "cast", "attack"],
	"hit": ["hitreceive", "hitrecieve", "receivehit", "recievehit", "hitreact", "spawn"],
	"death": ["death", "die"]
}

var character_root: Node3D
var animation_player: AnimationPlayer
var animation_players: Array[AnimationPlayer] = []
var skeleton: Skeleton3D
var clip_map: Dictionary = {}
var resolved_clip_map: Dictionary = {}
var contract_errors: Array[String] = []
var current_state := ""
var action_active := false
var dead := false
var distance_suspended := false
var target_playback_scale := 1.0
var current_playback_scale := 1.0
var manual_update_interval := 0.0
var manual_update_accumulator := 0.0

func configure(root: Node3D, clips: Dictionary) -> bool:
	character_root = root
	clip_map = clips.duplicate()
	resolved_clip_map.clear()
	contract_errors.clear()
	animation_players.clear()
	_collect_animation_players(root)
	animation_player = animation_players[0] if not animation_players.is_empty() else null
	skeleton = _find_type(root, "Skeleton3D") as Skeleton3D
	if animation_player == null or skeleton == null or skeleton.get_bone_count() == 0:
		contract_errors.append("missing AnimationPlayer or Skeleton3D")
		contract_failed.emit(contract_errors[0])
		return false
	for state in clip_map:
		var resolved := _resolve_clip(str(state), str(clip_map[state]))
		if resolved != StringName():
			resolved_clip_map[state] = resolved
	if not resolved_clip_map.has("idle"):
		contract_errors.append("required idle clip is missing")
		contract_failed.emit(contract_errors[0])
		return false
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	set_process(true)
	_play_state("idle", 0.0)
	return true

func _process(delta: float) -> void:
	if animation_player == null or distance_suspended:
		return
	if manual_update_interval > 0.0:
		manual_update_accumulator += delta
		if manual_update_accumulator < manual_update_interval:
			return
		delta = manual_update_accumulator
		manual_update_accumulator = 0.0
		for player in animation_players:
			player.advance(delta)
	current_playback_scale = lerpf(current_playback_scale, target_playback_scale, 1.0 - exp(-10.0 * delta))
	for player in animation_players:
		player.speed_scale = current_playback_scale

func set_update_rate_hz(rate_hz: float) -> void:
	manual_update_interval = 0.0 if rate_hz <= 0.0 else 1.0 / maxf(rate_hz, 1.0)
	manual_update_accumulator = 0.0
	for player in animation_players:
		player.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			if manual_update_interval <= 0.0
			else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)

func is_valid() -> bool:
	return animation_player != null and skeleton != null and skeleton.get_bone_count() > 0

func set_distance_suspended(suspended: bool) -> void:
	if distance_suspended == suspended:
		return
	distance_suspended = suspended
	process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
	for player in animation_players:
		player.active = not suspended
	if not suspended and not dead:
		_play_state(current_state if current_state != "" else "idle", 0.0)

func set_locomotion(speed_ratio: float, _direction: Vector3, grounded: bool) -> void:
	if not is_valid() or dead or action_active:
		return
	var state := "idle"
	if not grounded:
		state = "jump"
	elif speed_ratio > 0.72:
		state = "run"
	elif speed_ratio > 0.05:
		state = "walk"
	if state == "walk":
		target_playback_scale = clampf(speed_ratio / 0.58, 0.68, 1.22)
	elif state == "run":
		target_playback_scale = clampf(0.88 + (speed_ratio - 0.72) * 0.85, 0.88, 1.20)
	else:
		target_playback_scale = 1.0
	_play_state(state, 0.14)

func trigger_action(action_name: String, playback_scale: float = 1.0, blend_time: float = 0.10) -> bool:
	if not is_valid() or dead:
		return false
	if action_active and current_state == action_name and animation_player.is_playing():
		return false
	var clip := _clip_for(action_name)
	if clip == StringName():
		return false
	action_active = true
	current_state = action_name
	target_playback_scale = clampf(playback_scale, 0.55, 1.45)
	current_playback_scale = target_playback_scale
	for player in animation_players:
		player.speed_scale = current_playback_scale
	_play_clip_all(clip, clampf(blend_time, 0.0, 0.25))
	action_started.emit(action_name)
	return true

func set_dead() -> void:
	if dead:
		return
	dead = true
	action_active = true
	var clip := _clip_for("death")
	if clip != StringName():
		_play_clip_all(clip, 0.08)

func get_skeleton() -> Skeleton3D:
	return skeleton

func get_animation_player() -> AnimationPlayer:
	return animation_player

func get_clip_for_state(state: String) -> StringName:
	return _clip_for(state)

func get_contract_report() -> Dictionary:
	return {
		"valid": is_valid() and contract_errors.is_empty() and resolved_clip_map.has("idle"),
		"states": resolved_clip_map.duplicate(),
		"errors": contract_errors.duplicate(),
		"current_state": current_state,
		"playback_scale": current_playback_scale
	}

func _play_state(state: String, blend: float) -> void:
	if current_state == state and animation_player.is_playing():
		return
	var clip := _clip_for(state)
	if clip == StringName():
		clip = _clip_for("idle")
	if clip == StringName():
		return
	current_state = state
	_play_clip_all(clip, blend)

func _clip_for(state: String) -> StringName:
	if resolved_clip_map.has(state):
		return StringName(resolved_clip_map[state])
	return _resolve_clip(state, str(clip_map.get(state, "")))

func _resolve_clip(state: String, requested: String) -> StringName:
	if animation_player == null:
		return StringName()
	var keys: Array[String] = []
	var wanted_key := _clip_key(requested)
	if not wanted_key.is_empty():
		keys.append(wanted_key)
	for alias in STATE_ALIASES.get(state, []):
		var alias_key := _clip_key(str(alias))
		if not keys.has(alias_key):
			keys.append(alias_key)
	for key in keys:
		for candidate in animation_player.get_animation_list():
			var candidate_key := _clip_key(str(candidate))
			if candidate_key == key or candidate_key.ends_with(key) or candidate_key.contains(key):
				return candidate
	return StringName()

func _clip_key(value: String) -> String:
	return value.to_lower().replace("characterarmature", "").replace("humanarmature", "").replace("human armature", "").replace("|", "").replace("_", "").replace("-", "").replace(" ", "")

func _on_animation_finished(_animation: StringName) -> void:
	if dead:
		return
	var finished_state := current_state
	action_active = false
	current_state = ""
	action_finished.emit(finished_state)
	_play_state("idle", 0.10)

func _find_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func _collect_animation_players(root: Node) -> void:
	if root is AnimationPlayer:
		animation_players.append(root as AnimationPlayer)
	for child in root.get_children():
		_collect_animation_players(child)

func _play_clip_all(clip: StringName, blend: float) -> void:
	for player in animation_players:
		if player.has_animation(clip):
			player.play(clip, blend)
