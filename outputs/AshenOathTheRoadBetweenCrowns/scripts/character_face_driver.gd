extends Node

const StoryHeadModifier = preload("res://scripts/story_head_modifier.gd")

## Attention and emotional delivery on declared, imported facial controls.
## Unrigged actors retain head attention without claiming eyelid animation.

var character_root: Node3D
var role_id := ""
var eye_meshes: Array[MeshInstance3D] = []
var brow_meshes: Array[MeshInstance3D] = []
var base_eye_scales: Dictionary = {}
var base_eye_positions: Dictionary = {}
var native_face_surface_count := 0
var update_accumulator := 0.0
var blink_remaining := 0.0
var next_blink := 2.4
var focus_target: Node3D
var attention_mode := "auto"
var focus_point := Vector3.ZERO
var attention_generation := 0
var look_offset := 0.0
var valid := false
var update_timer: Timer
var update_interval := 0.12
var distance_suspended := false
var focus_refresh_remaining := 0.0
var expression := "neutral"
var head_modifier: StoryHeadModifier
var base_brow_rotations: Dictionary = {}
var conversation_active := false
var attention_elapsed := 0.0
var screen_refresh_remaining := 0.0
var screen_interval := 1.0 / 15.0
var face_on_screen := true
var motion_driver: Node
var terminal_dead := false
var face_tick_eligible := false
var face_pose_eligible := false
var expression_dirty := true

func _ready() -> void:
	_refresh_screen_budget(0.0)

func bind_motion(motion: Node) -> void:
	if motion_driver != motion:
		if is_instance_valid(motion_driver) and motion_driver.is_connected("terminal_state_changed", _on_terminal_state_changed):
			motion_driver.disconnect("terminal_state_changed", _on_terminal_state_changed)
		motion_driver = motion
	if is_instance_valid(motion_driver) and motion_driver.has_signal("terminal_state_changed"):
		if not motion_driver.is_connected("terminal_state_changed", _on_terminal_state_changed):
			motion_driver.connect("terminal_state_changed", _on_terminal_state_changed)
		terminal_dead = bool(motion_driver.get("dead"))
	_reconcile_face_eligibility()

func _bind_skeleton_motion() -> void:
	if not is_instance_valid(head_modifier):
		return
	var owner_skeleton := head_modifier.get_parent()
	if not owner_skeleton.has_meta("character_motion_owner"):
		return
	var reference: WeakRef = owner_skeleton.get_meta("character_motion_owner")
	if reference != null and is_instance_valid(reference.get_ref()):
		bind_motion(reference.get_ref())

func _on_terminal_state_changed(dead: bool) -> void:
	attention_generation += 1
	terminal_dead = dead
	if dead and is_instance_valid(head_modifier):
		# Disable additive ownership without touching the sampled death pose.
		head_modifier.speech_amount = 0.0
		head_modifier.gesture_time = 0.0
	if not dead:
		_reset_transient_face_state()
		_refresh_screen_budget(0.0)
		return
	_reconcile_face_eligibility()

func _reset_transient_face_state() -> void:
	# A cached face survives journey restore. Clear delivery from the previous
	# session without writing bones or replacing the authored expression recipe.
	conversation_active = false
	focus_target = null
	attention_mode = "auto"
	focus_point = Vector3.ZERO
	focus_refresh_remaining = 0.0
	screen_refresh_remaining = 0.0
	update_accumulator = 0.0
	attention_elapsed = 0.0
	look_offset = 0.0
	blink_remaining = 0.0
	next_blink = 1.8 + float(absi(role_id.hash()) % 180) / 100.0
	if is_instance_valid(head_modifier):
		head_modifier.set_expression(expression)
		head_modifier.look_yaw = 0.0
		head_modifier.look_pitch = 0.0
		head_modifier.attention_pitch = 0.0
		head_modifier.current_yaw = 0.0
		head_modifier.current_pitch = head_modifier.emotion_pitch
		head_modifier.current_roll = head_modifier.emotion_roll
		head_modifier.blink_closure = 0.0
		head_modifier.speech_amount = 0.0
		head_modifier.current_speech = 0.0
		head_modifier.gesture_time = 0.0
		head_modifier.gesture_kind = ""

func _reconcile_face_eligibility() -> void:
	face_tick_eligible = valid and is_inside_tree() and is_instance_valid(character_root) and character_root.is_visible_in_tree() \
		and not terminal_dead and not distance_suspended
	face_pose_eligible = face_tick_eligible and (face_on_screen or conversation_active) and not _combat_owns_pose()
	if is_instance_valid(head_modifier):
		head_modifier.active = face_pose_eligible
		if face_pose_eligible and expression_dirty:
			_apply_expression()
	if update_timer != null:
		# Offscreen living actors still poll visibility; pausing that timer would
		# leave them unable to notice their return to the camera frustum.
		update_timer.paused = not face_tick_eligible
		update_timer.wait_time = _tick_interval()
		if face_tick_eligible and is_inside_tree() and update_timer.is_stopped():
			update_timer.start()

func _on_root_visibility_changed() -> void:
	screen_refresh_remaining = 0.0
	_refresh_screen_budget(0.0)

func set_conversation_active(value: bool) -> void:
	conversation_active = value
	screen_refresh_remaining = 0.0
	_refresh_screen_budget(0.0)

func _tick_interval() -> float:
	return 1.0 / 30.0 if conversation_active else maxf(screen_interval, 1.0 / 30.0)

func _refresh_screen_budget(step: float) -> void:
	if not is_instance_valid(character_root) or not character_root.is_inside_tree():
		_reconcile_face_eligibility()
		return
	screen_refresh_remaining -= step
	if screen_refresh_remaining > 0.0 and not conversation_active:
		return
	screen_refresh_remaining = 0.25
	var camera := character_root.get_viewport().get_camera_3d()
	face_on_screen = conversation_active or camera == null
	var distance := 0.0
	if camera != null:
		var eye := character_root.global_position + Vector3.UP * float(character_root.get_meta("cast_eye_height", 1.55))
		face_on_screen = conversation_active or camera.is_position_in_frustum(eye)
		distance = camera.global_position.distance_to(eye)
	screen_interval = 0.25 if not face_on_screen else (1.0 / 30.0 if distance < 4.0 else (1.0 / 15.0 if distance < 8.0 else 0.125))
	_reconcile_face_eligibility()

func set_speech_amount(value: float) -> void:
	_reconcile_face_eligibility()
	if head_modifier != null:
		head_modifier.speech_amount = clampf(value, 0.0, 1.0) if face_pose_eligible and attention_mode != "sleep" and is_finite(value) else 0.0

func _combat_owns_pose() -> bool:
	return is_instance_valid(motion_driver) and motion_driver.has_active_action() and not bool(motion_driver.story_dialogue_active)

const NATIVE_MONSTER_ROLES := [
	"ghoulkin",
	"wychwood_stalker",
	"wychwood_raider",
	"wychwood_brute",
	"bog_wretch",
	"gravebound_knight",
	"bell_eater",
	"rootbound_colossus",
	"ashwing",
	"halvern_boss",
	"white_hart_avatar",
]

func configure(root: Node3D, role: String) -> bool:
	if character_root == root and role_id == role and valid and is_instance_valid(head_modifier):
		_bind_skeleton_motion()
		_refresh_screen_budget(0.0)
		return valid
	bind_motion(null)
	if update_timer != null:
		update_timer.stop()
	if is_instance_valid(head_modifier):
		head_modifier.active = false
		head_modifier.blink_closure = 0.0
		head_modifier.speech_amount = 0.0
		var previous_skeleton := head_modifier.get_parent()
		var previous_owner: WeakRef = previous_skeleton.get_meta("character_face_owner") if previous_skeleton.has_meta("character_face_owner") else null
		if previous_owner != null and previous_owner.get_ref() == self:
			previous_skeleton.remove_meta("character_face_owner")
	if is_instance_valid(character_root) and character_root.visibility_changed.is_connected(_on_root_visibility_changed):
		character_root.visibility_changed.disconnect(_on_root_visibility_changed)
	terminal_dead = false
	attention_generation += 1
	_reset_transient_face_state()
	head_modifier = null
	character_root = root
	if not root.visibility_changed.is_connected(_on_root_visibility_changed):
		root.visibility_changed.connect(_on_root_visibility_changed)
	role_id = role
	expression_dirty = true
	eye_meshes.clear()
	brow_meshes.clear()
	base_eye_scales.clear()
	base_eye_positions.clear()
	base_brow_rotations.clear()
	native_face_surface_count = 0
	focus_refresh_remaining = 0.0
	screen_refresh_remaining = 0.0
	var approved_complete_family := (
		str(root.get_meta("character_asset_family", "")) in ["quaternius_animated_humanoid", "quaternius_ranger"]
		or role_id in NATIVE_MONSTER_ROLES
	)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var token := str(mesh.name).to_lower()
		var surface_count: int = mesh.mesh.get_surface_count()
		var material_token := ""
		for surface_index in range(surface_count):
			var material = mesh.get_surface_override_material(surface_index)
			if material == null:
				material = mesh.mesh.surface_get_material(surface_index)
			material_token += " %s" % str(material.resource_name).to_lower() if material != null else ""
		var face_token := "%s %s" % [token, material_token]
		if face_token.contains("head") or face_token.contains("face") or face_token.contains("skin") or face_token.contains("body") or face_token.contains("skull") or face_token.contains("jaw") or face_token.contains("mouth") or face_token.contains("teeth") or face_token.contains("eye") or face_token.contains("brow") or (approved_complete_family and (mesh.skin != null or mesh.skeleton != NodePath(""))) or (role_id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton"] and face_token.contains("skeleton")):
			native_face_surface_count += surface_count
		if token.contains("eye") and not token.contains("brow"):
			eye_meshes.append(mesh)
			base_eye_scales[mesh] = mesh.scale
			base_eye_positions[mesh] = mesh.position
		elif token.contains("brow"):
			brow_meshes.append(mesh)
			base_brow_rotations[mesh] = mesh.rotation
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		for candidate in root.find_children("*", "Skeleton3D", true, false):
			skeleton = candidate as Skeleton3D
			break
	if skeleton != null:
		# The face may live on a gameplay parent while motion owns its visual
		# child. Register their exact shared skeleton rather than searching peers.
		skeleton.set_meta("character_face_owner", weakref(self))
		head_modifier = skeleton.get_node_or_null("StoryHeadModifier") as StoryHeadModifier
		if head_modifier == null:
			head_modifier = StoryHeadModifier.new()
			head_modifier.name = "StoryHeadModifier"
			skeleton.add_child(head_modifier)
		head_modifier.configure(skeleton)
	valid = not eye_meshes.is_empty() or native_face_surface_count > 0
	next_blink = 1.8 + float(absi(role_id.hash()) % 180) / 100.0
	update_interval = 0.10 if role_id in ["sister_anwen", "mira", "rook"] else 0.12
	if update_timer == null:
		update_timer = Timer.new()
		update_timer.name = "CharacterFaceTick"
		update_timer.one_shot = false
		update_timer.process_callback = Timer.TIMER_PROCESS_IDLE
		update_timer.timeout.connect(_on_update_timer_timeout)
		add_child(update_timer)
	update_timer.wait_time = _tick_interval()
	_bind_skeleton_motion()
	_refresh_screen_budget(0.0)
	if valid:
		var phase_delay := float(absi((role_id + str(root.get_instance_id())).hash()) % 1000) / 1000.0 * update_interval
		if is_inside_tree():
			update_timer.start(update_interval + phase_delay)
		else:
			call_deferred("_start_update_timer", update_interval + phase_delay)
	return valid

func _start_update_timer(delay: float) -> void:
	_reconcile_face_eligibility()
	if update_timer != null and face_tick_eligible and is_inside_tree():
		update_timer.start(delay)

func _on_update_timer_timeout() -> void:
	_reconcile_face_eligibility()
	if not face_tick_eligible:
		return
	var step := update_timer.wait_time if update_timer != null else update_interval
	_refresh_screen_budget(step)
	update_timer.wait_time = _tick_interval()
	attention_elapsed += step
	if not face_pose_eligible:
		return
	if attention_mode == "sleep":
		look_offset = lerpf(look_offset, 0.0, 1.0 - exp(-5.0 * step))
		_apply_eye_look()
		if head_modifier != null:
			head_modifier.look_pitch = 0.0
			head_modifier.attention_pitch = 0.0
			head_modifier.speech_amount = 0.0
			head_modifier.current_speech = 0.0
			head_modifier.gesture_time = 0.0
			_apply_blink(move_toward(head_modifier.blink_closure, 1.0, step * 5.0))
		return
	if attention_mode == "auto" and not is_instance_valid(focus_target) and role_id not in NATIVE_MONSTER_ROLES:
		focus_refresh_remaining -= step
		if focus_refresh_remaining <= 0.0:
			focus_refresh_remaining = 0.75
			var player_node := get_tree().get_first_node_in_group("player") as Node3D
			focus_target = player_node
	var wanted_look := 0.0
	if head_modifier != null:
		head_modifier.look_pitch = 0.0
		head_modifier.attention_pitch = 0.0
	if attention_mode == "point" or attention_mode in ["auto", "actor"] and is_instance_valid(focus_target):
		var target_point := focus_point
		if attention_mode != "point":
			target_point = focus_target.global_position + Vector3.UP * float(focus_target.get_meta("cast_eye_height", 1.55))
		var own_height := float(character_root.get_meta("cast_eye_height", 1.55))
		var to_target := target_point - character_root.global_position - Vector3.UP * own_height
		if to_target.length_squared() > 0.04 and to_target.length() < 10.0:
			var local_target := character_root.global_transform.basis.inverse() * to_target.normalized()
			var front := local_target.z if bool(character_root.get_meta("source_forward_positive_z", false)) else -local_target.z
			if front > -0.15:
				wanted_look = clampf(local_target.x, -0.85, 0.85)
				if head_modifier != null:
					var pitch := -atan2(to_target.y, maxf(Vector2(to_target.x, to_target.z).length(), 0.1))
					# Explicit work/listener focus shares the angle between neck and
					# eyes. Auto attention preserves its existing eye-only pitch.
					var head_pitch := clampf(pitch * 0.65, -0.20, 0.28) if attention_mode in ["point", "actor"] else 0.0
					head_modifier.attention_pitch = head_pitch
					head_modifier.look_pitch = clampf(pitch - head_pitch, -0.15, 0.15)
	# Brief, staggered breaks in eye contact rather than a permanent player stare.
	var attention_phase := fmod(attention_elapsed + float(absi(role_id.hash()) % 37) * 0.1, 6.8)
	if attention_mode == "auto" and not conversation_active and role_id not in NATIVE_MONSTER_ROLES and attention_phase > 5.6:
		wanted_look = 0.16 * sin((attention_phase - 5.6) / 1.2 * PI)
	# One head owner supplies gentle idle scanning as well as directed gaze.
	# Conversation, greeting nods and explicit focus retain their authored view.
	if attention_mode == "auto" and not conversation_active and role_id not in NATIVE_MONSTER_ROLES and (head_modifier == null or head_modifier.gesture_time <= 0.0):
		var motion_ref: WeakRef = head_modifier.get_parent().get_meta("character_motion_owner") if head_modifier != null and head_modifier.get_parent().has_meta("character_motion_owner") else null
		var motion: Node = motion_ref.get_ref() if motion_ref != null else null
		if is_instance_valid(motion) and not motion.has_active_action() and not motion.story_dialogue_active and motion.presentation_state in ["", "life:idle", "life:rest", "life:watch", "life:lookout"] and float(motion.current_speed_mps) < 0.08:
			wanted_look += sin(attention_elapsed * 0.38 + float(absi(role_id.hash()) % 17)) * 0.24
	look_offset = lerpf(look_offset, wanted_look, 1.0 - exp(-5.0 * step))
	_apply_eye_look()
	if blink_remaining > 0.0:
		blink_remaining = maxf(blink_remaining - step, 0.0)
		var blink_progress := 1.0 - blink_remaining / 0.14
		var closure := sin(blink_progress * PI)
		_apply_blink(closure)
	else:
		next_blink -= step
		_apply_blink(0.0)
		if next_blink <= 0.0:
			blink_remaining = 0.14
			next_blink = 2.2 + float(absi((role_id + str(Time.get_ticks_msec())).hash()) % 220) / 100.0

func set_distance_suspended(suspended: bool) -> void:
	distance_suspended = suspended
	screen_refresh_remaining = 0.0
	_refresh_screen_budget(0.0)

func _apply_eye_look() -> void:
	if head_modifier != null:
		head_modifier.look_yaw = -look_offset * 0.24

func _apply_blink(closure: float) -> void:
	if head_modifier != null:
		head_modifier.blink_closure = clampf(closure, 0.0, 1.0)

func get_contract_report() -> Dictionary:
	return {
		"valid": valid,
		"role": role_id,
		"contract_kind": "monster_native_anatomy" if role_id in NATIVE_MONSTER_ROLES else "human_native_face",
		"native_face_surface_count": native_face_surface_count,
		"native_eye_mesh_count": eye_meshes.size(),
		"native_brow_mesh_count": brow_meshes.size(),
		"synthetic_geometry_created": false,
		"facial_rig": "living_face_v1" if head_modifier != null and head_modifier.has_living_face() else "head_attention_only",
		"blink_enabled": head_modifier != null and head_modifier.has_living_face(),
		"eye_focus_enabled": head_modifier != null and head_modifier.has_living_face(),
		"expression_controls": head_modifier.facial_bones.keys() if head_modifier != null else [],
		"attention_mode": attention_mode,
	}

func set_focus_target(target: Node3D) -> void:
	set_attention("actor" if is_instance_valid(target) else "auto", target)

func set_focus_point(point: Vector3) -> bool:
	return set_attention("point", null, point)

func set_sleeping(value: bool) -> void:
	set_attention("sleep" if value else "auto")

func set_attention(mode: String, target: Node3D = null, point: Vector3 = Vector3.ZERO) -> bool:
	if mode not in ["auto", "actor", "point", "neutral", "sleep"] or not point.is_finite():
		return false
	if mode == "actor" and not is_instance_valid(target):
		return false
	if attention_mode == mode and (mode != "actor" or focus_target == target) and (mode != "point" or focus_point == point):
		return true
	var waking := attention_mode == "sleep" and mode != "sleep"
	attention_mode = mode
	focus_target = target if mode == "actor" else null
	focus_point = point if mode == "point" else Vector3.ZERO
	focus_refresh_remaining = 0.0 if mode == "auto" else 0.75
	if mode == "sleep" or waking:
		blink_remaining = 0.0
		next_blink = 1.8 + float(absi(role_id.hash()) % 180) / 100.0
		if is_instance_valid(head_modifier) and not terminal_dead:
			head_modifier.speech_amount = 0.0
			head_modifier.current_speech = 0.0
			head_modifier.gesture_time = 0.0
			head_modifier.gesture_kind = ""
			if waking:
				head_modifier.blink_closure = 0.0
	return true

func capture_attention() -> Dictionary:
	var state := {"generation":attention_generation, "mode":attention_mode,
		"target":weakref(focus_target) if is_instance_valid(focus_target) else null, "point":focus_point,
		"expression":expression, "distance_suspended":distance_suspended, "conversation_active":conversation_active,
		"focus_refresh_remaining":focus_refresh_remaining, "attention_elapsed":attention_elapsed,
		"look_offset":look_offset, "update_accumulator":update_accumulator,
		"blink_remaining":blink_remaining, "next_blink":next_blink, "head":{}}
	if is_instance_valid(head_modifier):
		for key: String in ["look_yaw", "look_pitch", "attention_pitch", "current_yaw", "current_pitch", "current_roll", "blink_closure", "speech_amount", "current_speech", "gesture_time", "gesture_kind", "expression_weights"]:
			state.head[key] = head_modifier.get(key)
	return state

func restore_attention(state: Dictionary) -> bool:
	# A dialogue begun before death or journey restoration cannot revive its
	# old facial delivery. Snapshots are local presentation, never save data.
	if terminal_dead or int(state.get("generation", -1)) != attention_generation:
		return false
	var reference: Variant = state.get("target")
	var target := reference.get_ref() as Node3D if reference is WeakRef else null
	var mode := str(state.get("mode", "neutral"))
	if mode == "actor" and not is_instance_valid(target):
		mode = "neutral"
	if not set_attention(mode, target, state.get("point", Vector3.ZERO)):
		return false
	if mode == "auto":
		focus_target = target
	set_expression(str(state.get("expression", "neutral")))
	conversation_active = bool(state.get("conversation_active", false))
	distance_suspended = bool(state.get("distance_suspended", false))
	focus_refresh_remaining = float(state.get("focus_refresh_remaining", 0.0))
	attention_elapsed = float(state.get("attention_elapsed", 0.0))
	look_offset = float(state.get("look_offset", 0.0))
	update_accumulator = float(state.get("update_accumulator", 0.0))
	blink_remaining = float(state.get("blink_remaining", 0.0))
	next_blink = float(state.get("next_blink", 2.4))
	if is_instance_valid(head_modifier):
		for key: String in state.get("head", {}):
			head_modifier.set(key, state.head[key])
	screen_refresh_remaining = 0.0
	_refresh_screen_budget(0.0)
	return true

func set_expression(value: String) -> bool:
	if not StoryHeadModifier.supports_expression(value):
		return false
	value = StoryHeadModifier.normalize_expression(value)
	if expression != value or (head_modifier != null and head_modifier.emotion != value):
		expression_dirty = true
	expression = value
	_reconcile_face_eligibility()
	return true

func _apply_expression() -> void:
	expression_dirty = false
	if head_modifier != null:
		head_modifier.set_expression(expression)
	# Imported brow meshes can express a subtle attitude; connected-face rigs
	# use the native head pose above rather than synthetic replacement anatomy.
	var brow_tilt := float({"stern":0.06, "concerned":-0.045, "grieving":-0.035, "wry":0.025}.get(expression, 0.0))
	for index in range(brow_meshes.size()):
		var brow := brow_meshes[index]
		if is_instance_valid(brow):
			var base: Vector3 = base_brow_rotations.get(brow, Vector3.ZERO)
			var rotation_value := base + Vector3(0, 0, brow_tilt * (-1.0 if index % 2 == 0 else 1.0))
			if brow.rotation != rotation_value:
				brow.rotation = rotation_value

func play_story_gesture(kind: String) -> void:
	_reconcile_face_eligibility()
	if head_modifier != null and face_pose_eligible and attention_mode != "sleep":
		head_modifier.gesture(kind)
