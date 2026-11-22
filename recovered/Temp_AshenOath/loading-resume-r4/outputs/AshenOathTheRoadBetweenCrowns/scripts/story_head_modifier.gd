extends SkeletonModifier3D

## Small additive motion on the native head, evaluated after the rig animation.
## No replacement face geometry, root translation or combat hitbox changes.
var head_index := -1
var jaw_index := -1
var speech_amount := 0.0
var current_speech := 0.0
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
var blink_closure := 0.0
var look_pitch := 0.0
var facial_bones: Dictionary = {}
var facial_rest: Dictionary = {}
var expression_weights := Vector4.ZERO
var wanted_expression := Vector4.ZERO

const FACE_CONTROLS := ["Eye_L", "Eye_R", "LidUpper_L", "LidUpper_R", "LidLower_L", "LidLower_R", "Brow_L", "Brow_R", "Mouth_L", "Mouth_R", "Jaw"]

func configure(skeleton: Skeleton3D) -> void:
	facial_bones.clear()
	facial_rest.clear()
	for control: String in FACE_CONTROLS:
		var bone := skeleton.find_bone("Face_" + control)
		if bone >= 0:
			facial_bones[control] = bone
			facial_rest[control] = skeleton.get_bone_rest(bone)
	for alias in ["Jaw", "jaw", "jaw_01", "DEF-jaw"]:
		jaw_index = skeleton.find_bone(alias)
		if jaw_index >= 0: break
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
	# Brow lift, brow tension, mouth warmth, mouth tension. Existing emotion
	# aliases preserve authored dialogue while sharing one compact face rig.
	wanted_expression = {
		"neutral": Vector4.ZERO, "warmth": Vector4(0.12, 0, 0.65, 0),
		"wry": Vector4(0.15, 0.12, 0.30, 0), "concern": Vector4(0.45, 0.30, -0.25, 0.20),
		"concerned": Vector4(0.45, 0.30, -0.25, 0.20),
		"suspicion": Vector4(-0.10, 0.65, -0.10, 0.35), "guarded": Vector4(0, 0.35, 0, 0.25),
		"fear": Vector4(0.85, 0.30, -0.30, 0.45), "anger": Vector4(-0.45, 0.85, -0.25, 0.65),
		"stern": Vector4(-0.20, 0.55, -0.10, 0.35), "grief": Vector4(0.35, 0.50, -0.65, 0.25),
		"grieving": Vector4(0.35, 0.50, -0.65, 0.25),
		"relief": Vector4(0.20, 0, 0.35, 0), "relieved": Vector4(0.20, 0, 0.35, 0),
		"resolute": Vector4(0, 0.20, 0.10, 0.15),
	}.get(value, Vector4.ZERO)

func has_living_face() -> bool:
	return facial_bones.size() == FACE_CONTROLS.size()

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
	current_speech = lerpf(current_speech, speech_amount, 1.0 - exp(-18.0 * delta))
	current_pitch = lerpf(current_pitch, emotion_pitch + nod + current_speech * 0.012, weight)
	current_roll = lerpf(current_roll, emotion_roll, weight)
	var base := skeleton.get_bone_pose_rotation(head_index)
	var target_rotation := base * Quaternion.from_euler(Vector3(current_pitch, current_yaw, current_roll))
	if base != target_rotation:
		skeleton.set_bone_pose_rotation(head_index, target_rotation)
	if jaw_index >= 0:
		var jaw_base := skeleton.get_bone_pose_rotation(jaw_index)
		var jaw_rotation := jaw_base * Quaternion(Vector3.RIGHT, current_speech * 0.10)
		if jaw_base != jaw_rotation:
			skeleton.set_bone_pose_rotation(jaw_index, jaw_rotation)
	if not has_living_face():
		return
	expression_weights = expression_weights.lerp(wanted_expression, weight)
	var brow_raise := expression_weights.x * 0.005
	var brow_tension := expression_weights.y * 0.08
	for side: String in ["L", "R"]:
		var sign_value := 1.0 if side == "L" else -1.0
		_face_pose(skeleton, "Eye_" + side, Vector3.ZERO, Vector3(clampf(look_pitch, -0.15, 0.15), clampf(-look_yaw * 0.9, -0.18, 0.18), 0))
		_face_pose(skeleton, "LidUpper_" + side, Vector3(0, -0.018 * blink_closure, 0.004 * blink_closure))
		_face_pose(skeleton, "LidLower_" + side, Vector3(0, 0.010 * blink_closure, 0.003 * blink_closure))
		_face_pose(skeleton, "Brow_" + side, Vector3(0, brow_raise, 0), Vector3(0, 0, brow_tension * sign_value))
		var warmth := expression_weights.z * (0.7 if emotion == "wry" and side == "R" else 1.0)
		_face_pose(skeleton, "Mouth_" + side, Vector3(sign_value * expression_weights.w * 0.0015, warmth * 0.004, 0))
	_face_pose(skeleton, "Jaw", Vector3(0, -current_speech * 0.003, 0), Vector3(current_speech * 0.08, 0, 0))

func _face_pose(skeleton: Skeleton3D, control: String, offset: Vector3, angles := Vector3.ZERO) -> void:
	var bone: int = facial_bones[control]
	var rest: Transform3D = facial_rest[control]
	var position := rest.origin + rest.basis * offset
	var rotation := (rest.basis * Basis.from_euler(angles)).get_rotation_quaternion()
	if not skeleton.get_bone_pose_position(bone).is_equal_approx(position):
		skeleton.set_bone_pose_position(bone, position)
	if not skeleton.get_bone_pose_rotation(bone).is_equal_approx(rotation):
		skeleton.set_bone_pose_rotation(bone, rotation)
