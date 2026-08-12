extends SceneTree

const ROLE_PATHS := {
	"male": "res://assets_external/characters_universal/Superhero_Male_FullBody.gltf",
	"female": "res://assets_external/characters_universal/Superhero_Female_FullBody.gltf",
}
const ANIMATION_PATH := "res://assets_external/animations/soul_universal_animation_library_2.glb"
const FORBIDDEN := ["faceplane", "eyeleft", "eyeright", "fake_neck", "hunchedback", "proxy"]

var failures: Array[String] = []

func _initialize() -> void:
	_check(ResourceLoader.exists(ANIMATION_PATH), "Universal Animation Library 2 is not imported")
	var animation_scene := _instantiate(ANIMATION_PATH)
	var animation_player := animation_scene.find_child("AnimationPlayer", true, false) if animation_scene != null else null
	_check(animation_player != null, "Universal Animation Library 2 has no AnimationPlayer")
	if animation_player != null:
		var clips: PackedStringArray = animation_player.get_animation_list()
		_check(clips.size() >= 20, "Universal animation library exposes too few clips: %d" % clips.size())
		print("CHAR-005 animation clips: %d" % clips.size())
	for role_id in ROLE_PATHS:
		var actor := _instantiate(ROLE_PATHS[role_id])
		_check(actor != null, "%s base body failed to instantiate" % role_id)
		if actor == null:
			continue
		# Imported GLTF nodes do not have global transforms until they are in a tree.
		# Attach the temporary inspection instance so bounds checks do not emit
		# renderer errors or accidentally pass on an invalid transform.
		get_root().add_child(actor)
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		_check(skeletons.size() == 1, "%s must use exactly one shared skeleton" % role_id)
		_check(meshes.size() > 0, "%s has no visible skinned mesh" % role_id)
		if skeletons.size() == 1:
			var skeleton := skeletons[0] as Skeleton3D
			_check(_has_bone(skeleton, "head"), "%s lacks a head bone" % role_id)
			_check(_has_bone(skeleton, "hand_r"), "%s lacks a right-hand equipment bone" % role_id)
			_check(_has_bone(skeleton, "hand_l"), "%s lacks a left-hand equipment bone" % role_id)
		_check(not _has_forbidden(actor), "%s contains detached/proxy anatomy" % role_id)
		var bounds := _mesh_bounds(actor)
		_check(bounds.size.y >= 1.4 and bounds.size.x >= 0.25, "%s base body bounds are incomplete: %s" % [role_id, str(bounds)])
		actor.free()
	if animation_scene != null:
		animation_scene.free()
	if failures.is_empty():
		print("CHAR-005 VERIFIER: PASS - shared CC0 humanoid foundation is importable")
	else:
		for failure in failures:
			push_error(failure)
		print("CHAR-005 VERIFIER: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _instantiate(path: String) -> Node3D:
	var packed := ResourceLoader.load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null

func _has_bone(skeleton: Skeleton3D, token: String) -> bool:
	var wanted := token.to_lower().replace("_", "")
	for index in range(skeleton.get_bone_count()):
		var name := str(skeleton.get_bone_name(index)).to_lower().replace("_", "")
		if name == wanted or name.ends_with(wanted):
			return true
	return false

func _has_forbidden(root: Node) -> bool:
	for child in root.find_children("*", "", true, false):
		var name := str(child.name).to_lower().replace("_", "")
		for token in FORBIDDEN:
			if name.contains(token.replace("_", "")):
				return true
	return false

func _mesh_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var bounds: AABB = _relative_mesh_transform(root, mesh) * mesh.mesh.get_aabb()
		result = result.merge(bounds) if initialized else bounds
		initialized = true
	return result if initialized else AABB()

func _relative_mesh_transform(root: Node3D, mesh: MeshInstance3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = mesh
	while cursor != null and cursor != root:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
