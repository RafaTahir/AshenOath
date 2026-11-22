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
	var report := {
		"role": role_id,
		"valid": not skeletons.is_empty() and skinned > 0 and not meshes.is_empty(),
		"skeleton_count": skeletons.size(),
		"mesh_count": meshes.size(),
		"skinned_mesh_count": skinned,
		"material_surface_count": materials,
		"skeleton_profile": skeleton_profile,
		"target_height": float(spec.get("height", 1.72)),
		"normalized_once": bool(root.get_meta("character_normalized", false)),
		"equipment_sockets": _socket_report(skeletons),
	}
	return report

static func mark_normalized(root: Node3D, source_bounds: AABB, target_height: float, scale_factor: float) -> void:
	if root == null:
		return
	root.set_meta("character_normalized", true)
	root.set_meta("character_source_bounds", source_bounds)
	root.set_meta("character_target_height", target_height)
	root.set_meta("character_normalization_scale", scale_factor)
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

static func _socket_report(skeletons: Array) -> Dictionary:
	if skeletons.is_empty():
		return {"head": false, "hand_r": false, "hand_l": false}
	var skeleton := skeletons[0] as Skeleton3D
	return {
		"head": has_socket(skeleton, ["head"]),
		"hand_r": has_socket(skeleton, ["hand_r", "handr", "r_hand"]),
		"hand_l": has_socket(skeleton, ["hand_l", "handl", "l_hand"]),
	}

static func _profile_for_skeleton(skeleton: Skeleton3D) -> String:
	var names: Array[String] = []
	for bone_index in range(skeleton.get_bone_count()):
		names.append(_normalize_name(str(skeleton.get_bone_name(bone_index))))
	if names.has("handr") and names.has("handl") and names.has("head"):
		return "QuaterniusUniversalHumanoid"
	return "unclassified"

static func _normalize_name(value: String) -> String:
	return value.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
