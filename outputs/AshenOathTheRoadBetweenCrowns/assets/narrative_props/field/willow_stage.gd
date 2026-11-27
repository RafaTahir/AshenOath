extends Node3D
## Only the scene owner advances these poses. Work may be interrupted at any time.
const BANK_SHIFT := Vector3(-0.9, 0.0, 2.0)
const FOUND := Vector3(1.40, 0.077, -3.18)
const LOADED := Vector3(0.73, 0.112, -3.14)
var beat := -1

func set_beat(index: int) -> void:
	if beat == index:
		return
	beat = index
	$Bank.visible = index in [0,1]
	$Bank.position = BANK_SHIFT if index == 1 else Vector3.ZERO
	$Bank/WaitingFrame.visible = index == 1
	$Bank/CoveredOren/LiftingFold.visible = index == 1
	$Rest.visible = index == 2
	$Porch.visible = index == 3
	$Graves.visible = index == 4
	$SetDown.visible = index in [2,3]
	$SetDown.position = Vector3(0, 0.294 if index == 3 else 0.261, -1.02)
	for marker in $Actors.get_children():
		$Actors.remove_child(marker)
		marker.queue_free()
	match index:
		0:
			var mira := _actor("Mira", "mira", "mira_human", "work", Vector3(-1.10,0,-0.18), -1.68)
			_hand(mira, "RightHand", Vector3(-.73,.57,-.18))
		1:
			var mira := _actor("Mira", "mira", "mira_human", "kneel", Vector3(1.13,0,-3.15)+BANK_SHIFT, -2.80)
			_hand(mira, "LeftHand", Vector3(1.48,.31,-2.62)+BANK_SHIFT)
			_hand(mira, "RightHand", Vector3(1.27,.29,-2.65)+BANK_SHIFT)
		4:
			_actor("Anwen", "sister_anwen", "sister_anwen_human", "watch", Vector3(1.52,0,-.34), 1.26)
	set_work(0.0)

func set_work(progress: float) -> void:
	if beat not in [0,1]:
		return
	var t := clampf(progress,0,1)
	var line_set := beat == 1 or t > 0.58
	$Bank/LooseLine.visible = not line_set
	$Bank/TiedLine.visible = line_set
	var lift := smoothstep(0.20, 0.89, t) if beat == 1 else 0.0
	$Bank/CoveredOren.position = FOUND.lerp(LOADED,lift) + Vector3.UP * sin(PI * lift) * .29
	$Bank/CoveredOren.rotation.y = lerpf(-.16,0.0,lift)
	# Lift the shoulders first; the far heel skims the bank and frame.
	$Bank/CoveredOren.rotation.x = .153 * sin(PI * lift)
	if beat == 1:
		var mira := $Actors/Mira as Marker3D
		var effort := sin(PI * lift)
		mira.set_meta("kneel_height", .36 + .16 * effort)
		mira.set_meta("lean_degrees", 49.0 - 20.0 * effort)
		mira.position = Vector3(1.27,0,-3.30).lerp(Vector3(.68,0,-3.24),lift) + BANK_SHIFT - Vector3.BACK * (.07 * effort)
		var cloth_frame: Transform3D = $Bank.transform * $Bank/CoveredOren.transform
		mira.get_node("LeftHand").position = mira.transform.affine_inverse() * (cloth_frame * Vector3(.128,.32,.29))
		mira.get_node("RightHand").position = mira.transform.affine_inverse() * (cloth_frame * Vector3(-.128,.32,.29))

func _actor(label: String, identity: String, role: String, pose: String, foot: Vector3, yaw: float) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = foot
	marker.rotation.y = yaw
	marker.set_meta("identity",identity)
	marker.set_meta("role",role)
	marker.set_meta("pose",pose)
	$Actors.add_child(marker)
	return marker

func _hand(marker: Marker3D, label: String, local_to_stage: Vector3) -> void:
	var hand := Marker3D.new()
	hand.name = label
	hand.position = marker.transform.affine_inverse() * local_to_stage
	marker.add_child(hand)
