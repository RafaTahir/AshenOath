extends Node

var wind_time := 0.0
var wind_strength := 1.0
var tracked: Array[Node3D] = []
var scene_root: Node3D
var player: Node3D
var wildlife: Dictionary = {}
var update_accumulator := 0.0
const UPDATE_INTERVAL := 1.0 / 12.0

func configure(root: Node3D, quality: String, active_player: Node3D = null) -> void:
	tracked.clear()
	wildlife.clear()
	scene_root = root
	player = active_player
	wind_strength = 0.55 if quality == "potato" else (1.25 if quality == "quality" else 0.9)
	_collect(root)

func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < UPDATE_INTERVAL:
		return
	delta = update_accumulator
	update_accumulator = 0.0
	wind_time += delta
	var hound: Node3D = scene_root.get_node_or_null("Bracken") if is_instance_valid(scene_root) else null
	for node in tracked:
		if not is_instance_valid(node):
			continue
		var base: Vector3 = node.get_meta("motion_base", node.rotation_degrees)
		var phase := float(node.get_meta("motion_phase", 0.0))
		var kind := str(node.get_meta("motion_type", "wind"))
		var wave := sin(wind_time * (2.2 if kind == "flame" else 0.75) + phase)
		if kind == "bird":
			if bool(node.get_meta("wildlife_reactive", false)):
				_update_wildlife(node, hound, delta, phase)
				continue
			node.position.y += sin(wind_time * 2.0 + phase) * 0.002
			node.rotation_degrees.z = base.z + wave * 18.0
		elif kind == "wheel":
			node.rotation_degrees.x = base.x + wind_time * 22.0
		elif kind == "flame":
			node.scale.y = 1.0 + wave * 0.12
			node.rotation_degrees.z = base.z + wave * 4.0
		else:
			node.rotation_degrees.z = base.z + wave * wind_strength * float(node.get_meta("motion_amount", 3.0))

func _collect(root: Node) -> void:
	if root is Node3D and root.has_meta("motion_type"):
		var node := root as Node3D
		node.set_meta("motion_base", node.rotation_degrees)
		tracked.append(node)
		if bool(node.get_meta("wildlife_reactive", false)):
			wildlife[node.get_instance_id()] = {"home": node.position, "away": Vector3.ZERO, "flight": 0.0, "quiet": 0.0}
	for child in root.get_children():
		_collect(child)

func _update_wildlife(bird: Node3D, hound: Node3D, delta: float, phase: float) -> void:
	var state: Dictionary = wildlife.get(bird.get_instance_id(), {})
	if state.is_empty() or not is_instance_valid(player):
		return
	var home: Vector3 = state.home
	var home_world: Vector3 = bird.get_parent().to_global(home)
	var disturbance := Vector3.INF
	var speed: float = player.velocity.length()
	var loud: bool = float(player.attack_anim_time) > 0.0 or str(player.beam_cast_state) != "" or bool(player.bow_aiming)
	var reported := bool(scene_root.get_meta("living_road_reported", false))
	var disturbed := str(scene_root.get_meta("living_road_shrine", "")) == "disturbed"
	var radius := 9.0 if loud else (6.5 if speed > 3.8 else 2.8)
	if disturbed:
		radius += 1.5
	if Vector2(home_world.x - player.global_position.x, home_world.z - player.global_position.z).length() < radius:
		disturbance = player.global_position
	if is_instance_valid(hound) and hound.is_visible_in_tree() and Vector2(home_world.x - hound.global_position.x, home_world.z - hound.global_position.z).length() < 4.2:
		disturbance = hound.global_position
	if disturbance != Vector3.INF:
		state.quiet = 0.0
		if float(state.flight) <= 0.01:
			var away := home_world - disturbance
			away.y = 0.0
			away = away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
			state.away = bird.get_parent().global_basis.inverse() * away * 7.0
		state.flight = minf(1.0, float(state.flight) + delta * 0.75)
	else:
		state.quiet = float(state.quiet) + delta
		if float(state.quiet) > (9.0 if disturbed else 3.5 if reported else 5.0):
			state.flight = maxf(0.0, float(state.flight) - delta * 0.20)
	var flight: float = smoothstep(0.0, 1.0, float(state.flight))
	bird.position = home + Vector3(state.away) * flight + Vector3.UP * (flight * 2.2 + sin(wind_time * 2.0 + phase) * 0.02)
	var base: Vector3 = bird.get_meta("motion_base", Vector3.ZERO)
	bird.rotation_degrees.z = base.z + sin(wind_time * 2.0 + phase) * (7.0 + flight * 9.0)
	var left := bird.get_node_or_null("CrowWingLeft") as Node3D
	var right := bird.get_node_or_null("CrowWingRight") as Node3D
	var flap := sin(wind_time * (8.0 + flight * 5.0) + phase) * (0.12 + flight * 0.34)
	if left != null:
		left.rotation.z = -0.31 - flap
	if right != null:
		right.rotation.z = 0.31 + flap
