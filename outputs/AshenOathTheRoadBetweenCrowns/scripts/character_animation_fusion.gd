extends RefCounted

## Attaches the shared UAL2 AnimationLibrary to the matching Quaternius
## Universal Base Character skeleton. Both sources use Armature/Skeleton3D and
## the same bone names, so physics remains authoritative and root-motion clips
## are deliberately never selected by the role maps.

const ANIMATION_LIBRARY_PATH := "res://assets_external/animations/soul_universal_animation_library_2.glb"

static func attach_shared_library(root: Node3D) -> AnimationPlayer:
	if root == null:
		return null
	var source_scene := _instantiate_scene(ANIMATION_LIBRARY_PATH)
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
		if target == null or target.get_animation_list().is_empty():
			if target == null:
				target = AnimationPlayer.new()
				target.name = "AnimationPlayer"
				rig_root.add_child(target)
			if target.has_animation_library(""):
				target.remove_animation_library("")
			target.add_animation_library("", source_library.duplicate(true))
		if first_target == null:
			first_target = target
	source_scene.free()
	return first_target

static func is_shared_body(path: String) -> bool:
	var normalized := path.replace("\\", "/").to_lower()
	return (normalized.contains("assets_external/characters_universal/") or normalized.contains("assets_external/characters_ranger/")) and normalized.ends_with(".gltf")

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
