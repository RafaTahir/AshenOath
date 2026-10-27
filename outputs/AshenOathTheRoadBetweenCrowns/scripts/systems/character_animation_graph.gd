extends RefCounted

## Graph/pose ownership only. The existing driver retains action arbitration,
## physical motion, contact events, timers and externally owned combat clocks.
const GAITS := ["locomotion", "locomotion_back", "locomotion_left", "locomotion_right"]
const REPEATABLE := ["attack", "attack_light", "attack_heavy", "block", "parry", "hurt", "windup", "greet"]
var tree: AnimationTree
var machine: AnimationNodeStateMachine
var playback: AnimationNodeStateMachinePlayback
var source: AnimationPlayer
var owner: Node
var nodes: Dictionary = {}
var transitions: Dictionary = {}
var strides: Dictionary = {}
var requested := "locomotion"
var active_state := ""
var walk_speed := 1.45
var run_speed := 3.20
var walk_distance := 1.45
var run_distance := 3.20
var speed := 0.0
var gait_rate := 1.0
var gait_rates: Dictionary = {}
var gait_phase := 0.0
var proportion := 1.0

func configure(host: Node, player: AnimationPlayer, clips: Dictionary, directions: Dictionary, height_scale: float) -> bool:
	owner = host
	source = player
	proportion = height_scale
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		return false
	walk_distance *= height_scale
	run_distance *= height_scale
	walk_speed = walk_distance
	run_speed = run_distance
	machine = AnimationNodeStateMachine.new()
	for gait: String in GAITS:
		var walk := str(clips.get("walk", clips.idle))
		var run := str(clips.get("run", walk))
		var backward := false
		if gait == "locomotion_back":
			walk = str(clips.get("walk_back", walk))
			run = str(clips.get("run_back", walk))
			backward = not bool(directions.get("walk_back", false))
		elif gait in ["locomotion_left", "locomotion_right"]:
			var key := "strafe_left" if gait == "locomotion_left" else "strafe_right"
			walk = str(clips.get(key, clips.get("strafe", walk)))
			run = walk
		var space := AnimationNodeBlendSpace1D.new()
		space.min_space = 0.0
		space.max_space = run_speed
		space.value_label = "Ground speed (m/s)"
		space.sync = true
		space.add_blend_point(_clip(str(clips.idle), true), 0.0)
		space.add_blend_point(_clip(walk, true, true, backward), walk_speed)
		var reverse_run := gait == "locomotion_back" and not bool(directions.get("run_back", false))
		space.add_blend_point(_clip(run, true, true, reverse_run), run_speed)
		strides[gait] = Vector2(_distance(walk, walk_distance), _distance(run, walk_distance if run == walk else run_distance))
		_add(gait, space)
	for logical: String in clips:
		var state := state_for(logical)
		if state in GAITS or nodes.has(state) or str(clips[logical]).is_empty():
			continue
		var looped := state in ["dialogue", "story_listen", "work", "beam_cast"]
		_add(state, _clip(str(clips[logical]), looped))
		if state in REPEATABLE:
			_add(state + "_repeat", _clip(str(clips[logical]), looped))
	tree = AnimationTree.new()
	tree.name = "CharacterAnimationTree"
	tree.active = false
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	owner.add_child(tree)
	tree.tree_root = machine
	tree.anim_player = tree.get_path_to(source)
	tree.root_node = tree.get_path_to(root)
	return true

func _distance(clip: String, fallback: float) -> float:
	var running := clip.to_lower().contains("run") or clip.to_lower().contains("sprint")
	var key := "run_cycle_distance_m" if running else "walk_cycle_distance_m"
	var authored := float(source.get_animation(clip).get_meta("cycle_distance_m", fallback / proportion))
	return maxf(float(owner.character_root.get_meta(key, authored)) * proportion, 0.2)

func _add(state: String, pose: AnimationRootNode) -> void:
	var branch := AnimationNodeBlendTree.new()
	branch.add_node("Pose", pose)
	branch.add_node("Rate", AnimationNodeTimeScale.new())
	branch.connect_node("Rate", 0, "Pose")
	branch.connect_node("output", 0, "Rate")
	machine.add_node(state, branch)
	nodes[state] = branch

func _clip(name: String, looped: bool, normalized_cycle: bool = false, backwards: bool = false) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = StringName(name)
	node.use_custom_timeline = true
	node.timeline_length = 1.0 if normalized_cycle else maxf(source.get_animation(name).length, 0.01)
	node.stretch_time_scale = normalized_cycle
	node.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	node.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD if backwards else AnimationNodeAnimation.PLAY_MODE_FORWARD
	return node

func activate(suspended: bool = false) -> void:
	if tree == null or not tree.is_inside_tree():
		return
	tree.active = not suspended
	if playback == null:
		playback = tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if playback != null:
			playback.start(requested, true)
			active_state = requested
	if not suspended:
		set_gait(speed)
		tree.advance(0.0)

func transition(logical: String, blend: float, restart: bool = false) -> void:
	var next := state_for(logical)
	if not nodes.has(next):
		next = "locomotion"
	if restart and active_state == next and nodes.has(next + "_repeat"):
		next += "_repeat"
	requested = next
	if playback == null or not tree.is_inside_tree():
		return
	var current := str(playback.get_current_node())
	if current == next and playback.is_playing():
		if restart:
			playback.start(next, true)
		return
	if not playback.is_playing() or current.is_empty():
		playback.start(next, true)
	else:
		var edge: AnimationNodeStateMachineTransition
		var key := current + ":" + next
		if transitions.has(key):
			edge = transitions[key]
		else:
			edge = AnimationNodeStateMachineTransition.new()
			machine.add_transition(current, next, edge)
			transitions[key] = edge
		edge.xfade_time = clampf(blend, 0.06, 0.14)
		edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC if current in GAITS and next in GAITS else AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		edge.reset = not (current in GAITS and next in GAITS)
		playback.travel(next)
	if next in GAITS and current not in GAITS:
		gait_phase = 0.0
	active_state = next

func set_gait(ground_speed: float) -> void:
	speed = maxf(ground_speed, 0.0)
	var weight := clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	if tree == null:
		return
	for state: String in GAITS:
		var distance: Vector2 = strides[state]
		# Normalized clips have one-second cycles: authored cycle distance is
		# their reference metres/second, not an accumulated playback multiplier.
		var reference_speed := lerpf(distance.x, distance.y, weight)
		var rate := clampf(speed / maxf(reference_speed, 0.1), 0.6, 1.6) if speed > 0.045 else 1.0
		gait_rates[state] = rate
		if state == active_state:
			gait_rate = rate
		tree.set("parameters/%s/Pose/blend_position" % state, minf(speed, run_speed))
		tree.set("parameters/%s/Rate/scale" % state, rate)

func rate_for(logical: String) -> float:
	return float(gait_rates.get(state_for(logical), 1.0))

func set_action_rate(value: float) -> void:
	if tree != null and active_state not in GAITS and nodes.has(active_state):
		tree.set("parameters/%s/Rate/scale" % active_state, maxf(value, 0.01))

func advance(delta: float) -> void:
	if tree == null or not tree.is_inside_tree() or not tree.active:
		return
	tree.advance(delta)
	if active_state in GAITS:
		gait_phase += delta * gait_rate

func scheduled() -> bool:
	return tree != null and tree.active and playback != null and playback.is_playing()

static func state_for(logical: String) -> String:
	match logical:
		"idle", "walk", "run": return "locomotion"
		"walk_back", "run_back": return "locomotion_back"
		"strafe", "strafe_left": return "locomotion_left"
		"strafe_right": return "locomotion_right"
		"hit": return "hurt"
	return logical
