extends Node

signal action_started(action_name: String)
signal action_finished(action_name: String)

var character_root: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var clip_map: Dictionary = {}
var current_state := ""
var action_active := false
var dead := false

func configure(root: Node3D, clips: Dictionary) -> bool:
	character_root = root
	clip_map = clips.duplicate()
	animation_player = _find_type(root, "AnimationPlayer") as AnimationPlayer
	skeleton = _find_type(root, "Skeleton3D") as Skeleton3D
	if animation_player == null or skeleton == null or skeleton.get_bone_count() == 0:
		return false
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_play_state("idle", 0.0)
	return true

func is_valid() -> bool:
	return animation_player != null and skeleton != null and skeleton.get_bone_count() > 0

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
	_play_state(state, 0.14)

func trigger_action(action_name: String) -> bool:
	if not is_valid() or dead:
		return false
	var clip := _clip_for(action_name)
	if clip == StringName():
		return false
	action_active = true
	current_state = action_name
	animation_player.play(clip, 0.10)
	action_started.emit(action_name)
	return true

func set_dead() -> void:
	if dead:
		return
	dead = true
	action_active = true
	var clip := _clip_for("death")
	if clip != StringName():
		animation_player.play(clip, 0.08)

func get_skeleton() -> Skeleton3D:
	return skeleton

func get_animation_player() -> AnimationPlayer:
	return animation_player

func _play_state(state: String, blend: float) -> void:
	if current_state == state and animation_player.is_playing():
		return
	var clip := _clip_for(state)
	if clip == StringName():
		clip = _clip_for("idle")
	if clip == StringName():
		return
	current_state = state
	animation_player.play(clip, blend)

func _clip_for(state: String) -> StringName:
	var wanted := StringName(str(clip_map.get(state, "")))
	if wanted != StringName() and animation_player.has_animation(wanted):
		return wanted
	return StringName()

func _on_animation_finished(_animation: StringName) -> void:
	if dead:
		return
	var finished_state := current_state
	action_active = false
	current_state = ""
	action_finished.emit(finished_state)

func _find_type(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null
