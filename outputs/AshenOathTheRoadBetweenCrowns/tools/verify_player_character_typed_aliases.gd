extends SceneTree

## Exercises the real view's dynamic actor call with strictly typed signatures.
## No game, authored assets, input, save data or render capture is involved.
const View = preload("res://scripts/views/player_character_view.gd")

class Actor extends CharacterBody3D:
	var view: RefCounted
	var visual_root: Node3D
	var skeleton: Skeleton3D
	var aliases_received: Array = []
	var beam_charge_visual: MeshInstance3D
	var beam_left_hand_glow: MeshInstance3D
	var beam_right_hand_glow: MeshInstance3D
	var beam_left_hand_socket: Node3D
	var beam_right_hand_socket: Node3D
	var beam_left_arm_ik: SkeletonIK3D
	var beam_right_arm_ik: SkeletonIK3D
	func _beam_material(_color: Color) -> StandardMaterial3D:
		return StandardMaterial3D.new()
	func _find_skeleton(_root: Node) -> Skeleton3D:
		return skeleton
	func _make_oathfire_hand(label: String, rig: Skeleton3D, aliases: Array[String], fallback: Vector3) -> MeshInstance3D:
		aliases_received.append(aliases.duplicate())
		return view._make_oathfire_hand(label, rig, aliases, fallback)
	func _find_bone_index(rig: Skeleton3D, aliases: Array[String]) -> int:
		return view._find_bone_index(rig, aliases)
	func _make_arm_pose_ik(rig: Skeleton3D, label: String, first: StringName, last: StringName) -> SkeletonIK3D:
		return view._make_arm_pose_ik(rig, label, first, last)
	func _create_equipment_space(parent: Node3D, label: String) -> Node3D:
		var space := Node3D.new()
		space.name = label
		parent.add_child(space)
		return space
	func _build_sheathed_sword() -> void: pass
	func _build_bow_visual() -> void: pass
	func _ensure_equipment_loadout() -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for with_rig in [false, true]:
		var actor := Actor.new()
		root.add_child(actor)
		actor.visual_root = Node3D.new()
		actor.add_child(actor.visual_root)
		if with_rig:
			actor.skeleton = Skeleton3D.new()
			actor.skeleton.add_bone("LeftHand")
			actor.skeleton.add_bone("RightHand")
			actor.visual_root.add_child(actor.skeleton)
		actor.view = View.new(actor)
		actor.view._add_beam_charge_visual()
		if actor.aliases_received.size() != 2:
			failures.append("Both typed alias calls must reach the actor boundary")
		else:
			if not actor.aliases_received[0].is_typed() or actor.aliases_received[0].get_typed_builtin() != TYPE_STRING:
				failures.append("Left aliases lost Array[String] element type")
			if not actor.aliases_received[1].is_typed() or actor.aliases_received[1].get_typed_builtin() != TYPE_STRING:
				failures.append("Right aliases lost Array[String] element type")
		if actor.beam_left_hand_glow == null or actor.beam_right_hand_glow == null:
			failures.append("Hand glows were not constructed")
		elif with_rig:
			if actor.beam_left_hand_socket == null or actor.beam_right_hand_socket == null:
				failures.append("Original left/right hand names failed the adjacent typed bone lookup")
		elif not actor.beam_left_hand_glow.position.is_equal_approx(Vector3(-0.28, 1.22, -0.42)) or not actor.beam_right_hand_glow.position.is_equal_approx(Vector3(0.28, 1.22, -0.42)):
			failures.append("Fallback hand offsets changed")
		actor.free()
	print(JSON.stringify({"fixture": "player_character_typed_aliases", "passed": failures.is_empty(), "failures": failures, "gameplay": false, "render_capture": false}))
	quit(0 if failures.is_empty() else 1)
