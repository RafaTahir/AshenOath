extends "c11_supply_route_paired_modifier.gd"

const Grip = preload("c11_supply_route_reveal_fixture_grip.gd")
var scoped_route := false
var reveal_after_solve := false

func configure(body: Node3D, motion: Node) -> void:
	super.configure(body, motion)
	var grips: Dictionary = body.get_meta("activity_prop_grips", {}).duplicate(true)
	grips["supply"] = Grip.record()
	body.set_meta("activity_prop_grips", grips)

func _process_modification() -> void:
	reveal_after_solve = false
	super._process_modification()
	if not reveal_after_solve or not is_equal_approx(pose_weight, 1.0) or paired_goal_witness.is_empty():
		return
	if not is_instance_valid(tool) or not tool.has_meta("measured_grip") or not driver.activity_prop_pose_ready():
		trial_failures.append("The current solved carry has no actual fitted socket")
		return
	tool.visible = true

func _update_tool(kind: String, visible_now: bool, allow_authored_prop: bool = true) -> void:
	var moving_supply := kind == "carry" and activity.is_empty() and carried_activity == "carry" and activity_prop == "supply"
	if moving_supply and not scoped_route:
		trial_failures.append("Provisional fitted socket left its measured scheduler scope")
	reveal_after_solve = moving_supply and scoped_route and visible_now
	super._update_tool(kind, visible_now and not moving_supply, allow_authored_prop)

func visible_socket_witness(placement: Node3D) -> Dictionary:
	var socket := tool as BoneAttachment3D
	if not is_instance_valid(socket) or not socket.is_visible_in_tree() or not socket.has_meta("measured_grip"):
		return {}
	var grip := socket.get_child(0) as Node3D
	var mesh := grip.get_child(0) as MeshInstance3D if grip != null else null
	var skeleton := socket.get_skeleton()
	var measured: Dictionary = socket.get_meta("measured_grip")
	if mesh == null or skeleton == null or str(socket.bone_name) != "hand_r" or str(measured.get("placement_sha256", "")) != Grip.PLACEMENT_SHA:
		return {}
	socket.on_skeleton_update()
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)
	var error := (mesh.global_transform * (measured.anchor as Vector3)).distance_to(hand * (measured.palm as Vector3))
	var local := placement.global_transform.affine_inverse() * mesh.global_transform
	return {"placement_sha256": Grip.PLACEMENT_SHA, "bone":"hand_r", "anchor_error_m":error,
		"frame": [_cells(local.basis.x), _cells(local.basis.y), _cells(local.basis.z), _cells(local.origin)]}
