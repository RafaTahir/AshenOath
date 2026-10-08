extends SkeletonModifier3D

## Native Dog head/tail chain, not added anatomy. Skeleton modifiers run after
## animation and do not accumulate rotations into the next animation frame.
var head := -1
var neck := -1
var tail := -1
var kind := ""
var elapsed := 0.0
var duration := 1.0

func configure(rig: Skeleton3D) -> void:
	for index in rig.get_bone_count():
		match str(rig.get_bone_name(index)).replace("_", "."):
			"Bone.003": head = index
			"Bone.002": neck = index
			"Bone.004": tail = index

func pose(action: String, seconds: float) -> void:
	kind = action
	elapsed = 0.0
	duration = maxf(seconds, 0.1)

func clear() -> void:
	kind = ""

func _process_modification() -> void:
	var rig := get_skeleton()
	if kind == "" or rig == null:
		return
	elapsed += get_process_delta_time()
	var blend := minf(clampf(elapsed / 0.3, 0.0, 1.0), clampf((duration - elapsed) / 0.35, 0.0, 1.0))
	if elapsed >= duration:
		clear()
		return
	var pitch := 0.10
	var tilt := 0.0
	var wag := 0.0
	match kind:
		"pet":
			tilt = sin(elapsed * 2.2) * 0.10
			wag = sin(elapsed * 8.0) * 0.22
		"feed":
			pitch = 0.22 + sin(elapsed * 7.0) * 0.035
			wag = sin(elapsed * 5.0) * 0.10
		"rest": pitch = 0.13 + sin(elapsed * 1.4) * 0.018
		"sniff": pitch = 0.25 + sin(elapsed * 5.0) * 0.025
	if head >= 0:
		rig.set_bone_pose_rotation(head, rig.get_bone_pose_rotation(head) * Quaternion.from_euler(Vector3(pitch, 0.0, tilt) * blend))
	if neck >= 0:
		rig.set_bone_pose_rotation(neck, rig.get_bone_pose_rotation(neck) * Quaternion(Vector3.RIGHT, pitch * 0.25 * blend))
	if tail >= 0:
		rig.set_bone_pose_rotation(tail, rig.get_bone_pose_rotation(tail) * Quaternion(Vector3.FORWARD, wag * blend))
