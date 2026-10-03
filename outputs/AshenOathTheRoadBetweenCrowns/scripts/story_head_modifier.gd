extends SkeletonModifier3D

## Small additive motion on the native head, evaluated after the rig animation.
## No replacement face geometry, root translation or combat hitbox changes.
var head_index := -1
var look_yaw := 0.0
var emotion_pitch := 0.0
var emotion_roll := 0.0
var current_yaw := 0.0
var current_pitch := 0.0
var current_roll := 0.0
var gesture_time := 0.0
var gesture_kind := ""
var emotion := "neutral"
var enabled := true

func configure(skeleton: Skeleton3D) -> void:
	for alias in ["Head", "head", "head_01", "DEF-head"]:
		head_index = skeleton.find_bone(alias)
		if head_index >= 0:
			break

func set_expression(value: String) -> void:
	emotion = value
	var angles: Vector2 = {
		"neutral":Vector2.ZERO, "guarded":Vector2(-0.025, 0.01),
		"concerned":Vector2(0.035, -0.025), "wry":Vector2(-0.015, 0.045),
		"grieving":Vector2(0.10, -0.015), "stern":Vector2(-0.045, 0.0),
		"resolute":Vector2(-0.015, 0.0), "relieved":Vector2(0.025, 0.015),
	}.get(value, Vector2.ZERO)
	emotion_pitch = angles.x
	emotion_roll = angles.y

func gesture(kind: String) -> void:
	gesture_kind = kind
	gesture_time = 0.001

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not enabled or skeleton == null or head_index < 0:
		return
	var delta := minf(get_process_delta_time(), 0.10)
	var nod := 0.0
	if gesture_time > 0.0:
		gesture_time += delta
		var length := 1.2 if gesture_kind == "remember" else 0.75
		if gesture_time >= length:
			gesture_time = 0.0
		else:
			nod = sin(gesture_time / length * PI) * (0.10 if gesture_kind == "remember" else 0.065)
	var weight := 1.0 - exp(-5.0 * delta)
	current_yaw = lerpf(current_yaw, clampf(look_yaw, -0.30, 0.30), weight)
	current_pitch = lerpf(current_pitch, emotion_pitch + nod, weight)
	current_roll = lerpf(current_roll, emotion_roll, weight)
	var base := skeleton.get_bone_pose_rotation(head_index)
	skeleton.set_bone_pose_rotation(head_index, base * Quaternion.from_euler(Vector3(current_pitch, current_yaw, current_roll)))
