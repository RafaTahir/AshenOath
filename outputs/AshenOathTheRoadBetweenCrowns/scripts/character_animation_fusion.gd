extends RefCounted

## Attaches the neutral shared AnimationLibrary to the matching Quaternius
## Universal Base Character skeleton. Both sources use Armature/Skeleton3D and
## the same bone names, so physics remains authoritative and root-motion clips
## are deliberately never selected by the role maps.

const ANIMATION_LIBRARY_PATH := "res://assets_external/animations/AnimationLibrary_Godot_Standard.glb"

static func attach_shared_library(root: Node3D) -> AnimationPlayer:
	if root == null:
		return null
	# Keep the shared clip library out of the engine boot dependency graph. The
	# first visible character pays this cost during scene construction, while
	# the menu and browser boot shell remain free to become interactive.
	var source_library_scene := ResourceLoader.load(ANIMATION_LIBRARY_PATH) as PackedScene
	var source_scene := source_library_scene.instantiate() as Node3D if source_library_scene != null else null
	if source_scene == null:
		return _find_animation_player(root)
	var source_player := _find_animation_player(source_scene)
	if source_player == null:
		source_scene.free()
		return _find_animation_player(root)
	var source_library := source_player.get_animation_library("")
	if source_library == null:
		source_scene.free()
		return _find_animation_player(root)
	var targets: Array[Node3D] = []
	for skeleton in root.find_children("*", "Skeleton3D", true, false):
		var armature := skeleton.get_parent() as Node3D
		var rig_root := armature.get_parent() as Node3D if armature != null else null
		if rig_root != null and not targets.has(rig_root):
			targets.append(rig_root)
	if targets.is_empty():
		targets.append(root)
	var first_target: AnimationPlayer = null
	for rig_root in targets:
		var target := _find_animation_player(rig_root)
		var target_skeleton := _find_skeleton(rig_root)
		if target == null or target.get_animation_list().is_empty():
			if target == null:
				target = AnimationPlayer.new()
				target.name = "AnimationPlayer"
				rig_root.add_child(target)
			if target.has_animation_library(""):
				target.remove_animation_library("")
			var retargeted_library := source_library.duplicate(true) as AnimationLibrary
			_retarget_library(retargeted_library, rig_root, target_skeleton)
			target.add_animation_library("", retargeted_library)
		if first_target == null:
			first_target = target
	source_scene.free()
	return first_target

static func is_shared_body(path: String) -> bool:
	var normalized := path.replace("\\", "/").to_lower()
	return (normalized.contains("assets_external/characters_universal/") or normalized.contains("assets_external/characters_ranger/")) and normalized.ends_with(".gltf")

static func _retarget_library(library: AnimationLibrary, target_root: Node3D, target_skeleton: Skeleton3D) -> void:
	if library == null or target_root == null or target_skeleton == null:
		return
	var skeleton_path := _relative_path(target_root, target_skeleton)
	for animation_name in library.get_animation_list():
		var animation := library.get_animation(animation_name)
		if animation == null:
			continue
		_retarget_animation(animation, skeleton_path)

static func _retarget_animation(animation: Animation, skeleton_path: String) -> void:
	var remove_tracks: Array[int] = []
	for track_index in range(animation.get_track_count()):
		var track_path := str(animation.track_get_path(track_index))
		var separator := track_path.find(":")
		if separator < 0:
			continue
		var source_bone := track_path.substr(separator + 1)
		if source_bone.to_lower() == "root":
			# Physics owns actor translation. Root motion from the source library
			# would reintroduce sliding and double movement.
			remove_tracks.append(track_index)
			continue
		var target_bone := _target_bone_name(source_bone)
		if target_bone == "":
			remove_tracks.append(track_index)
			continue
		animation.track_set_path(track_index, NodePath("%s:%s" % [skeleton_path, target_bone]))
	for index in range(remove_tracks.size() - 1, -1, -1):
		animation.remove_track(remove_tracks[index])

static func _target_bone_name(source_bone: String) -> String:
	var key := source_bone.to_lower()
	var direct := {
		"def-hips": "pelvis", "def-spine.002": "spine_01", "def-spine.003": "spine_02",
		"def-spine.004": "spine_03", "def-neck": "neck_01", "def-head": "Head",
		"def-shoulder.l": "clavicle_l", "def-upper_arm.l": "upperarm_l", "def-forearm.l": "lowerarm_l", "def-hand.l": "hand_l",
		"def-shoulder.r": "clavicle_r", "def-upper_arm.r": "upperarm_r", "def-forearm.r": "lowerarm_r", "def-hand.r": "hand_r",
		"def-thigh.l": "thigh_l", "def-shin.l": "calf_l", "def-foot.l": "foot_l", "def-toe.l": "ball_l",
		"def-thigh.r": "thigh_r", "def-shin.r": "calf_r", "def-foot.r": "foot_r", "def-toe.r": "ball_r",
	}
	if direct.has(key):
		return str(direct[key])
	var finger_match := RegEx.new()
	finger_match.compile("def-f_(index|middle|pinky|ring|thumb)\\.(0[1-4])\\.([lr])")
	var match := finger_match.search(key)
	if match != null:
		var finger_number := match.get_string(2)
		return "%s_04_leaf_%s" % [match.get_string(1), match.get_string(3)] if finger_number == "04" else "%s_%s_%s" % [match.get_string(1), finger_number, match.get_string(3)]
	return ""

static func _relative_path(root: Node, target: Node) -> String:
	var parts: Array[String] = []
	var cursor: Node = target
	while cursor != null and cursor != root:
		parts.push_front(str(cursor.name))
		cursor = cursor.get_parent()
	return "/".join(parts)

static func _instantiate_scene(path: String) -> Node3D:
	var packed := ResourceLoader.load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null

static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
