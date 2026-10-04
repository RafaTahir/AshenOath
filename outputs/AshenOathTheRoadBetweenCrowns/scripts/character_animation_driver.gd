extends Node

signal action_started(action_name: String)
signal action_finished(action_name: String)
signal contract_failed(reason: String)
signal locomotion_step(side: StringName)

const STATE_ALIASES := {
	"idle": ["idle", "idlesword", "idleweapon", "attackingidle"],
	"walk": ["walk", "walking"],
	"walk_back": ["walkback", "backwalk", "walk", "walking"],
	"strafe": ["strafe", "walk", "walking"],
	"strafe_left": ["walkleft", "strafeleft", "runleft", "strafe", "walk"],
	"strafe_right": ["walkright", "straferight", "runright", "strafe", "walk"],
	"run": ["run", "running", "sprint"],
	"run_back": ["runback", "backrun", "run", "running", "sprint"],
	"jump": ["jump", "jumpidle", "run"],
	"work": ["work", "interact", "idle", "idlesword"],
	"dialogue": ["dialogue", "talk", "interact", "idle", "idlesword"],
	"story_offer": ["interact", "talk", "dialogue"],
	"story_explain": ["talk", "dialogue", "interact"],
	"story_listen": ["idle", "idlesword", "idleweapon"],
	"windup": ["windup", "attack", "punch"],
	"attack": ["attack", "swordslash", "punch"],
	"attack_light": ["swordslash", "attack", "punch"],
	"attack_heavy": ["swordslash", "attack", "punch"],
	"dodge": ["roll", "dodge", "run"],
	"parry": ["parry", "block", "hitreceive", "hitrecieve", "receivehit", "recievehit"],
	"draw": ["sworddraw", "draw", "interact", "idle"],
	"sheath": ["swordsheath", "sheath", "interact", "idle"],
	"beam_cast": ["interact", "cast", "attack"],
	"hit": ["hitreceive", "hitrecieve", "receivehit", "recievehit", "hitreact", "spawn"],
	"death": ["death", "die"]
}

const ACTION_PRIORITY := {
	"jump": 1,
	"dialogue": 1,
	"work": 1,
	"story_offer": 1,
	"story_explain": 1,
	"dodge": 2,
	"attack": 3,
	"attack_light": 3,
	"attack_heavy": 3,
	"beam_cast": 3,
	"parry": 4,
	"hit": 5,
	"death": 100,
}
const LOOPING_ACTIONS := {"beam_cast": true}
const LOCOMOTION_STATES := ["walk", "walk_back", "strafe", "strafe_left", "strafe_right", "run", "run_back"]
# Per full left/right cycle at the reference adult height. These are explicit
# authoring calibrations, not claims of measured root motion: the supplied
# in-place library does not carry travel distance. Roles can tune either value.
const REFERENCE_HEIGHT_M := 1.72
const WALK_CYCLE_DISTANCE_M := 1.45
const RUN_CYCLE_DISTANCE_M := 3.20

var character_root: Node3D
var animation_player: AnimationPlayer
var animation_players: Array[AnimationPlayer] = []
var skeleton: Skeleton3D
var clip_map: Dictionary = {}
var resolved_clip_map: Dictionary = {}
var authored_directional_clips: Dictionary = {}
var contract_errors: Array[String] = []
var current_state := ""
var action_active := false
var dead := false
var distance_suspended := false
var target_playback_scale := 1.0
var current_playback_scale := 1.0
var manual_update_interval := 0.0
var manual_update_accumulator := 0.0
var externally_ticked := false
var manual_tick_timer: Timer
var current_direction := Vector3.ZERO
var current_local_direction := Vector3.ZERO
var requested_speed_ratio := 0.0
var current_speed_mps := 0.0
var physical_motion_available := false
var locomotion_height_scale := 1.0
var grounded := true
var locomotion_state := "idle"
var presentation_state := ""
var action_elapsed := 0.0
var action_looping := false
var active_action_clip := StringName()
var root_motion_disabled := true
var last_locomotion_clip := StringName()
var last_locomotion_state := StringName()
var last_locomotion_phase := -1.0
var locomotion_phase_distance := 0.0
var locomotion_step_index := 0
var story_gesture_remaining := 0.0
var story_dialogue_active := false

func _ready() -> void:
	# Imported actors are configured before their visual root is parented. Defer
	# timer startup until this driver actually belongs to the SceneTree.
	_start_manual_tick(true)

func configure(root: Node3D, clips: Dictionary) -> bool:
	character_root = root
	clip_map = clips.duplicate()
	resolved_clip_map.clear()
	authored_directional_clips.clear()
	contract_errors.clear()
	animation_players.clear()
	current_state = ""
	action_active = false
	dead = false
	presentation_state = ""
	current_direction = Vector3.ZERO
	current_local_direction = Vector3.ZERO
	requested_speed_ratio = 0.0
	current_speed_mps = 0.0
	physical_motion_available = false
	var role_spec: Dictionary = root.get_meta("character_role_spec", {})
	locomotion_height_scale = clampf(float(role_spec.get("height", REFERENCE_HEIGHT_M)) / REFERENCE_HEIGHT_M, 0.65, 1.80)
	grounded = true
	locomotion_state = "idle"
	action_elapsed = 0.0
	action_looping = false
	active_action_clip = StringName()
	last_locomotion_clip = StringName()
	last_locomotion_state = StringName()
	last_locomotion_phase = -1.0
	locomotion_phase_distance = 0.0
	locomotion_step_index = 0
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
	if externally_ticked:
		return
	_advance_animation(delta)

func set_external_tick(enabled: bool) -> void:
	# The owning physics/simulation loop can drive throttled animation without
	# waking this node on every rendered frame.
	externally_ticked = enabled
	if manual_tick_timer != null and is_instance_valid(manual_tick_timer):
		if enabled:
			manual_tick_timer.stop()
		elif manual_update_interval > 0.0 and not distance_suspended:
			_start_manual_tick()
	set_process(not enabled and manual_update_interval <= 0.0)

func _on_manual_tick() -> void:
	if externally_ticked or distance_suspended or manual_update_interval <= 0.0:
		return
	var elapsed := manual_tick_timer.wait_time
	# Timer.start(first_delay) also replaces its repeating period. Restore the
	# requested rate after that first staggered tick and account for its real span.
	if not is_equal_approx(elapsed, manual_update_interval):
		_start_manual_tick()
	_advance_animation(elapsed)

func advance_external(delta: float) -> void:
	if not externally_ticked:
		return
	_advance_animation(delta)

func _advance_animation(delta: float) -> void:
	if animation_player == null or distance_suspended:
		return
	if story_gesture_remaining > 0.0:
		story_gesture_remaining = maxf(story_gesture_remaining - delta, 0.0)
		if story_gesture_remaining <= 0.0 and story_dialogue_active:
			stop_action()
			set_dialogue_pose(true)
	if manual_update_interval > 0.0:
		manual_update_accumulator += delta
		if manual_update_accumulator < manual_update_interval:
			return
		delta = manual_update_accumulator
		manual_update_accumulator = 0.0
		# Manual NPC animation is deliberately advanced only at its requested
		# rate. Keeping imported AnimationPlayers active between these ticks
		# still makes the Compatibility renderer evaluate every skeleton every
		# rendered frame, defeating the distance/quality budget.
		current_playback_scale = lerpf(current_playback_scale, target_playback_scale, 1.0 - exp(-10.0 * delta))
		var manual_playback_direction := _playback_direction_for_state(current_state)
		for player in animation_players:
			player.speed_scale = current_playback_scale * manual_playback_direction
			player.advance(delta)
		if action_active:
			action_elapsed += delta
		_emit_locomotion_step_events()
		return
	current_playback_scale = lerpf(current_playback_scale, target_playback_scale, 1.0 - exp(-10.0 * delta))
	var playback_direction := _playback_direction_for_state(current_state)
	for player in animation_players:
		player.speed_scale = current_playback_scale * playback_direction
	if action_active:
		action_elapsed += delta
	_emit_locomotion_step_events()

func set_update_rate_hz(rate_hz: float) -> void:
	manual_update_interval = 0.0 if rate_hz <= 0.0 else 1.0 / maxf(rate_hz, 1.0)
	# Manual NPC animation is timer-driven. The previous implementation still
	# entered _process on every rendered frame and only returned after checking
	# its accumulator, which kept every ambient rig in the Web script budget.
	if manual_update_interval > 0.0:
		if manual_tick_timer == null or not is_instance_valid(manual_tick_timer):
			manual_tick_timer = Timer.new()
			manual_tick_timer.name = "ManualAnimationTick"
			manual_tick_timer.one_shot = false
			manual_tick_timer.process_callback = Timer.TIMER_PROCESS_IDLE
			manual_tick_timer.timeout.connect(_on_manual_tick)
			add_child(manual_tick_timer)
		manual_tick_timer.wait_time = manual_update_interval
		manual_update_accumulator = 0.0
		if not externally_ticked and not distance_suspended:
			_start_manual_tick(true)
	else:
		manual_update_accumulator = 0.0
		if manual_tick_timer != null and is_instance_valid(manual_tick_timer):
			manual_tick_timer.stop()
	for player in animation_players:
		player.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			if manual_update_interval <= 0.0
			else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)
		# MANUAL disables automatic evaluation; inactive also disables advance().
		player.active = not distance_suspended
	set_process(not externally_ticked and manual_update_interval <= 0.0)

func is_valid() -> bool:
	return animation_player != null and skeleton != null and skeleton.get_bone_count() > 0 \
		and contract_errors.is_empty() and resolved_clip_map.has("idle")

func is_evaluation_scheduled() -> bool:
	# Manual mixers stay active but evaluate only explicit scheduled advances.
	# Distance suspension disables both the schedule and mixer.
	return is_valid() and not distance_suspended and (externally_ticked or manual_update_interval > 0.0 or animation_player.active)

func set_distance_suspended(suspended: bool) -> void:
	if distance_suspended == suspended:
		return
	distance_suspended = suspended
	process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
	if manual_tick_timer != null and is_instance_valid(manual_tick_timer):
		if suspended or externally_ticked or manual_update_interval <= 0.0:
			manual_tick_timer.stop()
		else:
			_start_manual_tick()
	for player in animation_players:
		player.active = not suspended
	if not suspended and not dead:
		_play_state(current_state if current_state != "" else "idle", 0.0)

func _start_manual_tick(stagger_first_tick := false) -> void:
	if manual_tick_timer == null or not is_instance_valid(manual_tick_timer):
		return
	if not is_inside_tree() or externally_ticked or distance_suspended or manual_update_interval <= 0.0:
		return
	var delay := manual_update_interval
	if stagger_first_tick:
		var phase_slot := int(character_root.get_instance_id() % 17) if character_root != null else 0
		delay *= 1.0 - float(phase_slot) / 17.0
	manual_tick_timer.start(maxf(delay, 0.02))

func set_locomotion(speed_ratio: float, _direction: Vector3, grounded: bool) -> void:
	# Compatibility for role controllers which still supply a normalized ratio.
	# Do not guess metres/second from the magnitude of their direction argument:
	# legacy callers use both unit directions and velocities here.
	physical_motion_available = false
	current_speed_mps = 0.0
	_update_locomotion(speed_ratio, _direction, grounded)

func set_locomotion_motion(world_velocity: Vector3, grounded: bool, reference_speed: float = 5.3) -> void:
	# The owner supplies achieved travel after collision/path movement. Animation
	# never moves the actor and does not keep stepping into a blocked wall.
	var horizontal_velocity := Vector3(world_velocity.x, 0.0, world_velocity.z)
	physical_motion_available = true
	current_speed_mps = horizontal_velocity.length()
	_update_locomotion(current_speed_mps / maxf(reference_speed, 0.1), horizontal_velocity, grounded)

func _update_locomotion(speed_ratio: float, world_direction: Vector3, on_ground: bool) -> void:
	requested_speed_ratio = clampf(speed_ratio, 0.0, 1.35)
	grounded = on_ground
	current_direction = Vector3(world_direction.x, 0.0, world_direction.z)
	current_direction = current_direction.normalized() if current_direction.length_squared() > 0.0001 else Vector3.ZERO
	var visible_forward := get_visible_forward()
	if visible_forward.length_squared() > 0.5 and current_direction != Vector3.ZERO:
		# Construct a horizontal, unit-length facing frame. Imported scale, root
		# pitch/roll and the source +Z convention cannot alter direction thresholds.
		var visible_right := visible_forward.cross(Vector3.UP).normalized()
		current_local_direction = Vector3(current_direction.dot(visible_right), 0.0, -current_direction.dot(visible_forward))
	else:
		current_local_direction = Vector3.ZERO
	if not is_valid() or dead or action_active or presentation_state != "":
		return
	var previously_moving: bool = locomotion_state in LOCOMOTION_STATES
	var is_moving: bool = current_speed_mps > (0.045 if previously_moving else 0.08) if physical_motion_available else requested_speed_ratio > (0.035 if previously_moving else 0.05)
	var was_backwards: bool = locomotion_state in ["walk_back", "run_back"]
	var moving_backwards: bool = current_local_direction.z > (0.18 if was_backwards else 0.42)
	var was_lateral: bool = locomotion_state in ["strafe", "strafe_left", "strafe_right"]
	var lateral_ratio: float = 1.05 if was_lateral else 1.30
	var moving_laterally: bool = absf(current_local_direction.x) > absf(current_local_direction.z) * lateral_ratio
	var was_running: bool = locomotion_state in ["run", "run_back"]
	var run_threshold: float = (1.80 if was_running else 2.05) * locomotion_height_scale
	var wants_running: bool = current_speed_mps > run_threshold if physical_motion_available else requested_speed_ratio > (0.66 if was_running else 0.74)
	var state := "idle"
	if not on_ground:
		state = "jump"
	elif is_moving:
		if moving_laterally:
			var lateral_state: String = "strafe_left" if current_local_direction.x < 0.0 else "strafe_right"
			state = lateral_state if _authored_directional_clip(lateral_state) != StringName() else "strafe"
		elif moving_backwards:
			# Do not turn a missing backward sprint into frantic reverse Sprint.
			# A role with an actual backward run may still use its authored gait.
			state = "run_back" if wants_running and _authored_directional_clip("run_back") != StringName() else "walk_back"
		else:
			state = "run" if wants_running and _clip_for("run") != StringName() else "walk"
	locomotion_state = state
	if physical_motion_available and state in LOCOMOTION_STATES:
		target_playback_scale = _physical_gait_playback_scale(state)
	elif state in ["walk", "strafe", "strafe_left", "strafe_right"]:
		target_playback_scale = clampf(requested_speed_ratio / 0.58, 0.30, 1.40)
	elif state == "walk_back":
		target_playback_scale = clampf(requested_speed_ratio / 0.46, 0.30, 1.40)
	elif state in ["run", "run_back"]:
		target_playback_scale = clampf(0.88 + (requested_speed_ratio - 0.72) * 0.85, 0.70, 1.45)
	else:
		target_playback_scale = 1.0
	_play_state(state, 0.16)

func _physical_gait_playback_scale(state: String) -> float:
	var clip: StringName = _clip_for(state)
	if clip == StringName() or not animation_player.has_animation(clip):
		return 1.0
	var animation: Animation = animation_player.get_animation(clip)
	var key := _clip_key(str(clip))
	var running_clip: bool = key.contains("run") or key.contains("sprint") or key.contains("jog")
	var cycle_distance: float = RUN_CYCLE_DISTANCE_M if running_clip else WALK_CYCLE_DISTANCE_M
	var calibration_key: String = "run_cycle_distance_m" if running_clip else "walk_cycle_distance_m"
	cycle_distance = float(character_root.get_meta(calibration_key, cycle_distance)) * locomotion_height_scale
	var playback: float = current_speed_mps * maxf(animation.length, 0.01) / maxf(cycle_distance, 0.20)
	# Slow villagers can use genuinely slow cadence. Upper limits protect a
	# missing directional gait from extreme leg cycling; physical travel stays
	# with the controller. Retreat is deliberately a smaller, bounded walk.
	return clampf(playback, 0.12, 1.50 if state == "walk_back" else 1.65)

func trigger_action(action_name: String, playback_scale: float = 1.0, blend_time: float = 0.10, force: bool = false, duration: float = 0.0) -> bool:
	if not is_valid() or dead:
		return false
	if action_active:
		var active_priority: int = int(ACTION_PRIORITY.get(current_state, 0))
		var requested_priority: int = int(ACTION_PRIORITY.get(action_name, 0))
		if not force and requested_priority < active_priority:
			return false
		if not force and current_state == action_name and animation_player.is_playing():
			return false
	var clip := _clip_for(action_name)
	if clip == StringName():
		return false
	presentation_state = ""
	action_active = true
	current_state = action_name
	action_elapsed = 0.0
	action_looping = bool(LOOPING_ACTIONS.get(action_name, false))
	active_action_clip = clip
	# Timed combat must finish its clip within the controller's damage/recovery
	# clock. The general locomotion/action speed clamp cannot express that rate.
	target_playback_scale = animation_player.get_animation(clip).length / duration if duration > 0.0 else clampf(playback_scale, 0.55, 1.45)
	current_playback_scale = target_playback_scale
	for player in animation_players:
		player.speed_scale = current_playback_scale
	_play_clip_all(clip, clampf(blend_time, 0.0, 0.25))
	action_started.emit(action_name)
	return true

func stop_action(recover_state: String = "idle", blend_time: float = 0.10) -> void:
	if not action_active and presentation_state == "":
		return
	action_active = false
	action_looping = false
	active_action_clip = StringName()
	action_elapsed = 0.0
	if dead:
		return
	current_state = ""
	_play_state(recover_state, clampf(blend_time, 0.0, 0.25))

func set_dialogue_pose(active: bool) -> void:
	story_dialogue_active = active
	if dead or not is_valid():
		return
	if active:
		if presentation_state == "dialogue":
			return
		action_active = false
		presentation_state = "dialogue"
		current_state = ""
		target_playback_scale = 1.0
		_play_state("dialogue", 0.14)
	else:
		if presentation_state == "dialogue":
			presentation_state = ""
			current_state = ""
			_play_state("idle", 0.12)

func play_story_gesture(kind: String, pace: float = 0.9) -> void:
	if not story_dialogue_active or dead or kind not in ["offer", "explain"]:
		return
	if trigger_action("story_" + kind, pace, 0.18):
		# A shared Interact clip may be looping. A bounded gesture returns to
		# attentive stillness rather than repeatedly handing over an empty object.
		story_gesture_remaining = 1.8 / maxf(pace, 0.5)

func stop_story_gesture() -> void:
	story_dialogue_active = false
	story_gesture_remaining = 0.0
	stop_action()
	presentation_state = ""
	current_state = ""
	_play_state("idle", 0.18)

func set_story_listening(listening: bool) -> void:
	if dead or not story_dialogue_active:
		return
	story_gesture_remaining = 0.0
	stop_action()
	if listening:
		presentation_state = "story_listen"
		current_state = ""
		_play_state("story_listen", 0.20)
	else:
		presentation_state = ""
		set_dialogue_pose(true)

func set_working(active: bool) -> void:
	if dead or not is_valid():
		return
	if active:
		if presentation_state == "work":
			return
		action_active = false
		presentation_state = "work"
		current_state = ""
		target_playback_scale = 1.0
		_play_state("work", 0.14)
	else:
		if presentation_state == "work":
			presentation_state = ""
			current_state = ""
			_play_state("idle", 0.12)

func set_dead() -> void:
	if dead:
		return
	dead = true
	current_state = "death"
	action_active = true
	presentation_state = ""
	action_looping = false
	action_elapsed = 0.0
	target_playback_scale = 1.0
	current_playback_scale = 1.0
	var clip := _clip_for("death")
	if clip != StringName():
		_play_clip_all(clip, 0.08)

func get_skeleton() -> Skeleton3D:
	return skeleton

func get_animation_player() -> AnimationPlayer:
	return animation_player

func get_playback_direction_for_state(state: String) -> float:
	# Expose the resolved direction to focused motion tests. A reverse gait may
	# use an authored reverse clip or a forward clip played backwards; callers
	# should not infer that distinction from the clip name alone.
	return _playback_direction_for_state(state)

func get_clip_for_state(state: String) -> StringName:
	return _clip_for(state)

func get_contract_report() -> Dictionary:
	return {
		"valid": is_valid() and contract_errors.is_empty() and resolved_clip_map.has("idle"),
		"states": resolved_clip_map.duplicate(),
		"errors": contract_errors.duplicate(),
		"current_state": current_state,
		"playback_scale": current_playback_scale,
		"locomotion_state": locomotion_state,
		"presentation_state": presentation_state,
		"requested_speed_ratio": requested_speed_ratio,
		"speed_mps": current_speed_mps,
		"physical_motion_available": physical_motion_available,
		"locomotion_height_scale": locomotion_height_scale,
		"grounded": grounded,
		"current_direction": current_direction,
		"current_local_direction": current_local_direction,
		"action_active": action_active,
		"action_elapsed": action_elapsed,
		"root_motion_disabled": root_motion_disabled
	}

func get_locomotion_state() -> String:
	return locomotion_state

func get_visible_forward() -> Vector3:
	if character_root == null:
		return Vector3.ZERO
	var forward := character_root.global_transform.basis.z if bool(character_root.get_meta("source_forward_positive_z", false)) else -character_root.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.002 else Vector3.ZERO

func has_active_action() -> bool:
	return action_active

func get_action_progress() -> float:
	if not action_active or active_action_clip == StringName() or animation_player == null:
		return 0.0
	var animation := animation_player.get_animation(active_action_clip)
	if animation == null or animation.length <= 0.0:
		return 0.0
	return clampf(animation_player.current_animation_position / animation.length, 0.0, 1.0)

func _play_state(state: String, blend: float) -> void:
	if current_state == state and animation_player.is_playing():
		return
	var clip := _clip_for(state)
	if clip == StringName():
		clip = _clip_for("idle")
	if clip == StringName():
		return
	var previous_state: String = current_state
	var previous_clip: StringName = StringName(animation_player.current_animation)
	var preserve_phase: bool = previous_state in LOCOMOTION_STATES and state in LOCOMOTION_STATES and animation_player.is_playing()
	var normalized_phase := -1.0
	if preserve_phase and animation_player.has_animation(previous_clip):
		var previous_animation: Animation = animation_player.get_animation(previous_clip)
		if previous_animation.length > 0.0:
			normalized_phase = fposmod(animation_player.current_animation_position / previous_animation.length, 1.0)
			if previous_clip != clip:
				# Preserve cycle frequency while the new physical cadence settles.
				current_playback_scale *= animation_player.get_animation(clip).length / previous_animation.length
	current_state = state
	var playback_direction: float = _playback_direction_for_state(state)
	if preserve_phase and previous_clip == clip:
		# Walk, lateral fallback and backstep can share one authored clip. Keep
		# its exact pose, including on a playback-direction reversal. Calling
		# play()/seek(0) here caused a repeated foot snap during turns.
		for player in animation_players:
			player.speed_scale = current_playback_scale * playback_direction
	else:
		if state in LOCOMOTION_STATES and not preserve_phase:
			current_playback_scale = target_playback_scale
		_play_clip_all(clip, blend, playback_direction, normalized_phase)
	if preserve_phase and normalized_phase >= 0.0:
		last_locomotion_clip = clip
		last_locomotion_state = StringName(state)
		last_locomotion_phase = normalized_phase
	else:
		last_locomotion_clip = StringName()
		last_locomotion_state = StringName()
		last_locomotion_phase = -1.0
		locomotion_phase_distance = 0.0

func _clip_for(state: String) -> StringName:
	if resolved_clip_map.has(state):
		return StringName(resolved_clip_map[state])
	var clip: StringName = _resolve_clip(state, str(clip_map.get(state, "")))
	resolved_clip_map[state] = clip
	return clip

func _resolve_clip(state: String, requested: String) -> StringName:
	if animation_player == null:
		return StringName()
	if state in ["walk_back", "run_back", "strafe_left", "strafe_right"]:
		var directional_clip: StringName = _authored_directional_clip(state)
		if directional_clip != StringName():
			return directional_clip
	var keys: Array[String] = []
	var wanted_key := _clip_key(requested)
	if not wanted_key.is_empty():
		keys.append(wanted_key)
	for alias in STATE_ALIASES.get(state, []):
		var alias_key := _clip_key(str(alias))
		if not keys.has(alias_key):
			keys.append(alias_key)
	var candidates := animation_player.get_animation_list()
	# Resolve exact names first. The old contains-only pass could select a
	# zombie/carry clip for a normal walk simply because it appeared earlier in
	# an imported library.
	for key in keys:
		for candidate in candidates:
			var candidate_key := _clip_key(str(candidate))
			if candidate_key == key and _locomotion_candidate_allowed(state, candidate_key):
				return candidate
	for key in keys:
		for candidate in candidates:
			var candidate_key := _clip_key(str(candidate))
			if not _locomotion_candidate_allowed(state, candidate_key):
				continue
			if candidate_key.ends_with(key) or candidate_key.contains(key):
				return candidate
	return StringName()

func _locomotion_candidate_allowed(state: String, candidate_key: String) -> bool:
	if state not in LOCOMOTION_STATES:
		return true
	# These clips are useful for special enemies or carried-object animation,
	# but they visibly collapse a human gait when used as general locomotion.
	for banned in ["zombie", "carry", "limp", "crawl", "stagger", "attack", "sword", "hit"]:
		if candidate_key.contains(banned):
			return false
	if state in ["walk", "run"]:
		for directional_word in ["back", "reverse", "strafe", "left", "right"]:
			if candidate_key.contains(directional_word):
				return false
	return true

func _authored_directional_clip(state: String) -> StringName:
	if authored_directional_clips.has(state):
		return StringName(authored_directional_clips[state])
	if animation_player == null:
		return StringName()
	var direction_keys: Array[String] = []
	match state:
		"walk_back":
			direction_keys.assign(["walkback", "backwalk", "backwardwalk", "walkreverse", "runback", "backrun"])
		"run_back":
			direction_keys.assign(["runback", "backrun", "backwardrun", "runreverse"])
		"strafe_left":
			direction_keys.assign(["walkleft", "strafeleft", "leftstrafe", "runleft"])
		"strafe_right":
			direction_keys.assign(["walkright", "straferight", "rightstrafe", "runright"])
	for direction_key in direction_keys:
		for candidate in animation_player.get_animation_list():
			var candidate_key: String = _clip_key(str(candidate))
			if candidate_key.contains(direction_key) and _locomotion_candidate_allowed(state, candidate_key):
				authored_directional_clips[state] = candidate
				return candidate
	authored_directional_clips[state] = StringName()
	return StringName()

func _clip_key(value: String) -> String:
	return value.to_lower().replace("characterarmature", "").replace("humanarmature", "").replace("human armature", "").replace("|", "").replace("_", "").replace("-", "").replace(" ", "")

func _on_animation_finished(_animation: StringName) -> void:
	if dead:
		return
	if action_active and action_looping:
		return
	if not action_active:
		# Locomotion and presentation clips are allowed to be authored as either
		# looping or one-shot clips. Re-enter the same state when a one-shot ends
		# so a short imported clip cannot leave a character frozen.
		var sustained_state := current_state
		if sustained_state != "":
			_play_state(sustained_state, 0.06)
		return
	var finished_state := current_state
	action_active = false
	action_looping = false
	active_action_clip = StringName()
	action_elapsed = 0.0
	current_state = ""
	action_finished.emit(finished_state)
	if story_dialogue_active and finished_state.begins_with("story_"):
		story_gesture_remaining = 0.0
		set_dialogue_pose(true)
	else:
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

func _play_clip_all(clip: StringName, blend: float, playback_direction: float = 1.0, normalized_phase: float = -1.0) -> void:
	for player in animation_players:
		if player.has_animation(clip):
			player.speed_scale = current_playback_scale * playback_direction
			player.play(clip, blend, 1.0, playback_direction < 0.0)
			var clip_length: float = player.get_animation(clip).length
			var position: float = normalized_phase * clip_length if normalized_phase >= 0.0 else (clip_length if playback_direction < 0.0 else 0.0)
			player.seek(position, true)
			# Sample the first pose immediately. This is required for manual players,
			# but is also important for a newly spawned actor that can be paused for
			# dialogue or capture before its first idle callback.
			player.advance(0.0)

func _playback_direction_for_state(state: String) -> float:
	if state not in ["walk_back", "run_back"]:
		return 1.0
	var resolved_clip := _clip_for(state)
	if resolved_clip == StringName():
		return 1.0
	# An explicit walk_back:Walk mapping is still a forward fallback. Identify
	# the actual authored directional clip, not equality with a role-map alias.
	var authored_clip: StringName = _authored_directional_clip(state)
	return 1.0 if authored_clip != StringName() and resolved_clip == authored_clip else -1.0

func _emit_locomotion_step_events() -> void:
	if animation_player == null or action_active or current_state not in LOCOMOTION_STATES:
		last_locomotion_clip = StringName()
		last_locomotion_state = StringName()
		last_locomotion_phase = -1.0
		locomotion_phase_distance = 0.0
		return
	var clip := _clip_for(current_state)
	if clip == StringName() or not animation_player.has_animation(clip):
		return
	var animation := animation_player.get_animation(clip)
	if animation == null or animation.length <= 0.0:
		return
	var phase := fposmod(animation_player.current_animation_position / animation.length, 1.0)
	if last_locomotion_clip != clip or last_locomotion_state != StringName(current_state) or last_locomotion_phase < 0.0:
		last_locomotion_clip = clip
		last_locomotion_state = StringName(current_state)
		last_locomotion_phase = phase
		locomotion_phase_distance = 0.0
		return
	# Use the animation position itself as the clock. Some imported clips report
	# increasing positions even when played backwards, so signed phase tests can
	# mistake a normal reverse frame for multiple contacts. Absolute wrapped
	# phase distance stays correct for forward and reverse playback alike.
	var phase_delta := phase - last_locomotion_phase
	if phase_delta > 0.5:
		phase_delta -= 1.0
	elif phase_delta < -0.5:
		phase_delta += 1.0
	locomotion_phase_distance += absf(phase_delta)
	while locomotion_phase_distance >= 0.5:
		locomotion_phase_distance -= 0.5
		locomotion_step.emit(StringName("left") if locomotion_step_index % 2 == 0 else StringName("right"))
		locomotion_step_index += 1
	last_locomotion_phase = phase
