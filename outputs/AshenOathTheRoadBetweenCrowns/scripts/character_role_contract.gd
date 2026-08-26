extends RefCounted

## Runtime contract for one-pass character normalization and bone equipment.
## The contract is intentionally data-first: it never creates facial or clothing
## primitives to disguise an incomplete source model.

const FOUNDATION_PATH := "res://soul_character_foundation.json"
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

static func inspect(root: Node, role_id: String) -> Dictionary:
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var skinned := 0
	var materials := 0
	for mesh in meshes:
		if mesh.skin != null or mesh.skeleton != NodePath(""):
			skinned += 1
		if mesh.mesh != null:
			materials += mesh.mesh.get_surface_count()
	var skeleton_profile := ""
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		skeleton_profile = _profile_for_skeleton(skeleton)
	var spec := CharacterRoleSpec.for_role(role_id)
	var bounds := _visible_bounds(root)
	var has_bounds := bounds.size != Vector3.ZERO
	var rendered_height := bounds.size.y if has_bounds else 0.0
	var grounded := has_bounds and absf(bounds.position.y - CharacterRoleSpec.ground_offset(role_id)) <= 0.12
	var target_height := float(spec.get("height", 1.72))
	var height_tolerance := float(spec.get("height_tolerance", 0.08))
	var height_valid := has_bounds and absf(rendered_height - target_height) <= height_tolerance
	var sockets := _socket_report(skeletons, spec.get("equipment_sockets", {}))
	var required_socket_names := CharacterRoleSpec.required_sockets(role_id)
	var sockets_valid := true
	for socket_name in required_socket_names:
		if not bool(sockets.get(socket_name, false)):
			sockets_valid = false
	var report := {
		"role": role_id,
		"valid": skeletons.size() == 1 and skinned > 0 and materials > 0 and not meshes.is_empty() and has_bounds and height_valid and grounded and sockets_valid and bool(root.get_meta("character_normalized", false)),
		"skeleton_count": skeletons.size(),
		"mesh_count": meshes.size(),
		"skinned_mesh_count": skinned,
		"material_surface_count": materials,
		"skeleton_profile": skeleton_profile,
		"target_height": target_height,
		"rendered_height": rendered_height,
		"height_tolerance": height_tolerance,
		"grounded": grounded,
		"normalized_once": bool(root.get_meta("character_normalized", false)),
		"normalization_passes": int(root.get_meta("character_normalization_passes", 0)),
		"role_scale_applied_once": bool(root.get_meta("character_role_scale_applied", false)),
		"skeleton_profile_expected": str(spec.get("skeleton_profile", "unclassified")),
		"animation_profile": str(spec.get("animation_profile", "")),
		"equipment_sockets": sockets,
	}
	return report

static func mark_normalized(root: Node3D, source_bounds: AABB, target_height: float, scale_factor: float) -> void:
	if root == null:
		return
	if int(root.get_meta("character_normalization_passes", 0)) > 0:
		root.set_meta("character_normalization_violation", true)
		root.set_meta("character_normalization_passes", int(root.get_meta("character_normalization_passes", 1)) + 1)
		return
	root.set_meta("character_normalized", true)
	root.set_meta("character_source_bounds", source_bounds)
	root.set_meta("character_source_height", source_bounds.size.y)
	root.set_meta("character_source_ground", source_bounds.position.y)
	root.set_meta("character_target_height", target_height)
	root.set_meta("character_normalization_scale", scale_factor)
	root.set_meta("character_normalization_passes", 1)
	root.set_meta("character_normalization_violation", false)
	root.set_meta("character_normalization_contract", "CHAR-005-one-pass")

static func has_socket(root: Node, aliases: Array[String]) -> bool:
	var skeletons: Array = []
	if root is Skeleton3D:
		skeletons.append(root)
	else:
		skeletons = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return false
	var skeleton := skeletons[0] as Skeleton3D
	for bone_index in range(skeleton.get_bone_count()):
		var normalized := _normalize_name(str(skeleton.get_bone_name(bone_index)))
		for alias in aliases:
			var wanted := _normalize_name(alias)
			if normalized == wanted or normalized.ends_with(wanted):
				return true
	return false

static func _socket_report(skeletons: Array, socket_specs: Dictionary = {}) -> Dictionary:
	var result := {}
	for socket_name in socket_specs.keys():
		result[str(socket_name)] = false
	if skeletons.is_empty():
		return result
	var skeleton := skeletons[0] as Skeleton3D
	for socket_name in socket_specs.keys():
		var aliases: Array[String] = []
		for alias in socket_specs.get(socket_name, []):
			aliases.append(str(alias))
		result[str(socket_name)] = has_socket(skeleton, aliases)
	return result

static func _profile_for_skeleton(skeleton: Skeleton3D) -> String:
	var names: Array[String] = []
	for bone_index in range(skeleton.get_bone_count()):
		names.append(_normalize_name(str(skeleton.get_bone_name(bone_index))))
	if names.has("handr") and names.has("handl") and names.has("head"):
		return "QuaterniusUniversalHumanoid"
	# The selected compact Quaternius examples use Fist/Weapon sockets and a
	# 32-bone hierarchy. They are complete skinned bodies, not proxy layers.
	if names.has("root") and names.has("hips") and (names.has("fistr") or names.has("weaponr")) and (names.has("head") or names.has("head2")):
		return "QuaterniusAnimatedHumanoid32"
	return "unclassified"

static func _normalize_name(value: String) -> String:
	return value.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")

static func _visible_bounds(root: Node) -> AABB:
	var state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_accumulate_bounds(root, Transform3D.IDENTITY, state)
	return state.get("bounds", AABB()) if bool(state.get("has_bounds", false)) else AABB()

static func _accumulate_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current := parent_transform
	if node is Node3D:
		current = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var bounds: AABB = current * mesh_instance.mesh.get_aabb()
			if bool(state.get("has_bounds", false)):
				state["bounds"] = (state["bounds"] as AABB).merge(bounds)
			else:
				state["bounds"] = bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_accumulate_bounds(child, current, state)
