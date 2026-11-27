extends RefCounted
## Tor's left forearm is splinted. Workstation and locomotion ownership stay with
## the normal cast routine. This view changes the equipment and hand performance.
const STIFF := &"novel_tor_stiff_wrist"
const BRACE := "res://assets/narrative_props/brace/tor_left_wrist_brace.tscn"
const SOCKET := ^"NovelTorBraceSocket"

class BraceSocket extends BoneAttachment3D:
	var hammer: WeakRef
	var was_visible := false

	func remember(node: Node3D) -> void:
		hammer = weakref(node)
		was_visible = node.visible
		node.visible = false

	func restore_hammer() -> void:
		var node := hammer.get_ref() as Node3D if hammer != null else null
		if is_instance_valid(node):
			node.visible = was_visible

static func sync(driver: Node, braced: bool, stiff: bool = false) -> void:
	var rig: Skeleton3D = driver.skeleton
	if not is_instance_valid(rig): return
	var socket := rig.get_node_or_null(SOCKET) as BraceSocket
	var protects_wrist := braced or stiff
	var changed := (socket != null) != protects_wrist
	if protects_wrist:
		if socket == null:
			var bone := rig.find_bone(&"lowerarm_l")
			if bone < 0:
				return
			socket = BraceSocket.new()
			socket.name = "NovelTorBraceSocket"
			socket.bone_idx = bone
			socket.bone_name = &"lowerarm_l"
			rig.add_child(socket)
		var splint := socket.get_node_or_null("TorLeftWristBrace")
		if braced and splint == null and ResourceLoader.exists(BRACE):
			var scene := load(BRACE) as PackedScene
			if scene != null: socket.add_child(scene.instantiate())
		elif not braced and splint != null:
			socket.remove_child(splint)
			splint.queue_free()
		driver._ensure_life_modifier()
		_stow_hammer(driver.character_root, socket)
		if is_instance_valid(driver.life_modifier) and driver.life_modifier.tool_kind == "hammer":
			driver.life_modifier.hide_activity_tool()
	elif socket != null:
		socket.restore_hammer()
		rig.remove_child(socket)
		socket.queue_free()
	if changed and not driver.dead and not driver.story_dialogue_active and not driver.has_active_action():
		# Re-evaluate a running work clip on the injury edge, even if the routine
		# still owns the same station. Repeated syncs leave its clock alone.
		if driver.presentation_state in ["life:forge", "life:repair"]:
			var kind := str(driver.life_modifier.activity)
			driver.presentation_state = ""
			driver.set_life_activity(kind)
		elif driver.presentation_state == "work":
			driver.current_state = ""
			driver._play_state("idle" if protects_wrist else "work", 0.14)

static func _stow_hammer(actor: Node3D, socket: BraceSocket) -> void:
	# Stow the actual hammer mesh beneath its existing visibility owner. A
	# conversation or the routine can continue managing the parent equipment.
	if socket.hammer != null and is_instance_valid(socket.hammer.get_ref()):
		return
	var hammer := actor.find_child("OccupationProp_blacksmith_tor", true, false) as Node3D
	if hammer == null:
		hammer = actor.find_child("OccupationProp_forge_helper", true, false) as Node3D
	if hammer != null:
		socket.remember(hammer)

static func hammer_mounted(rig: Skeleton3D, hammer: Node3D) -> void:
	# A saved injury can be bound before presentation finishes adding the
	# character's occupation equipment. The final mount supplies the exact node.
	var socket := rig.get_node_or_null(SOCKET) as BraceSocket
	if socket != null:
		socket.remember(hammer)

static func apply_pose(life: Node, rig: Skeleton3D) -> void:
	var driver: Node = life.driver
	if life.arms.size() != 2 or life.spine < 0: return
	if driver.has_active_action() and not driver.story_dialogue_active and driver.current_state != "greet": return
	var left: Dictionary = life.arms[0]
	var right: Dictionary = life.arms[1]
	var shoulder_l: Vector3 = life._world(rig, left.upper)
	var shoulder_r: Vector3 = life._world(rig, right.upper)
	var across := shoulder_r - shoulder_l
	var span := across.length()
	var forward: Vector3 = driver.get_visible_forward()
	if span < 0.02 or forward.is_zero_approx(): return
	across /= span
	var chest: Vector3 = life._world(rig, life.spine)
	var left_goal := chest + forward * span * 0.45 + across * span * 0.06 - Vector3.UP * span * 0.25
	if life.activity in ["rest", "sleep", "sit", "seated_eat"]:
		left_goal -= Vector3.UP * span * 0.18
	# After winter the left hand is free to support a joint at its actual marker.
	if driver.novel_injury != STIFF:
		life._solve_arm(rig, left, left_goal, null, -across * 0.48 - Vector3.UP)
	if driver.story_dialogue_active or driver.has_active_action() or driver.distance_suspended: return
	if not (life.activity in ["forge", "repair"] or driver.presentation_state == "work"): return
	var station: Dictionary = life.station
	if station.is_empty() or not station.has("point"): return
	if not life.viewer_near: return
	# He checks the near edge, indicates the adjustment with his uninjured
	# hand, then waits for the next worker. The hand stays above the work.
	var period := 4.8
	var phase := fposmod(float(life.elapsed), period) / period
	var indicate := smoothstep(0.18, 0.36, phase) * (1.0 - smoothstep(0.56, 0.88, phase))
	var aim: Vector3 = Vector3(station.point) + Vector3.UP * span * 0.28 - shoulder_r
	if aim.length_squared() < 0.0001: return
	var resting := shoulder_r + (forward * 0.23 - Vector3.UP * 0.78 - across * 0.10) * span
	var pointing := shoulder_r + aim.normalized() * span * 1.08
	life._solve_arm(rig, right, resting.lerp(pointing, indicate), null, across * 0.40 - Vector3.UP)
