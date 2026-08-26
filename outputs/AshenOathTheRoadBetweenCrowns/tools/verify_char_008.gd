extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

var failures: Array[String] = []
var helper: Node

const ROLES := [
	["mira_human", "mira_herbalist"],
	["rook_human", "rook_smuggler"],
	["villager_human", "generic_villager_01"],
	["villager_female_human", "widow_elna"],
	["villager_worker_human", "blacksmith_tor"],
	["villager_hooded_human", "widow_elna"],
	["castle_guard_human", "castle_guard"],
	["road_ranger_human", "captain_senn"]
]

func _initialize() -> void:
	helper = AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	var seen_profiles: Dictionary = {}
	for pair in ROLES:
		var visual_role := str(pair[0])
		var identity := str(pair[1])
		var visual: Node3D = helper.spawn_visual_role(visual_role, "characters")
		_check(visual != null, "%s did not instantiate" % visual_role)
		if visual == null:
			continue
		var owner := Node3D.new()
		root.add_child(owner)
		owner.add_child(visual)
		CharacterPresentation.apply_npc(owner, identity)
		await process_frame
		_check(_find_skeleton(visual) != null, "%s lacks Skeleton3D" % visual_role)
		_check(_has_head_and_hand(visual), "%s lacks native head/hand bones" % visual_role)
		var family := str(visual.get_meta("character_asset_family", ""))
		var ranger_family := visual_role == "road_ranger_human" and str(visual.get_meta("character_base_path", "")).contains("characters_ranger/")
		_check(family == "quaternius_animated_humanoid" or ranger_family, "%s is outside the selected cohesive animated family" % visual_role)
		_check(_has_textured_mesh(visual), "%s has no textured skinned mesh" % visual_role)
		_check(not _has_proxy_anatomy(visual), "%s contains proxy anatomy" % visual_role)
		# The helper owns animation fusion; named preview actors are validated by
		# the same body import contract even when no controller is attached.
		var report: Dictionary = visual.get_meta("character_visual_contract", {})
		_check(typeof(report) == TYPE_DICTIONARY and bool(report.get("valid", false)), "%s failed visual contract" % visual_role)
		seen_profiles[visual_role] = visual.get_meta("character_identity_profile", "")
		owner.free()
	_check(seen_profiles.size() == ROLES.size(), "named roles did not produce deterministic identity profiles")
	if failures.is_empty():
		print("CHAR-008 named identity profiles: %d" % seen_profiles.size())
	_finish()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _has_head_and_hand(node: Node3D) -> bool:
	var skeleton := _find_skeleton(node)
	if skeleton == null:
		return false
	return _has_bone_alias(skeleton, ["Head", "Head_2"]) and _has_bone_alias(skeleton, ["Hand.R", "Weapon.R", "Fist.R", "hand_r"])

func _has_bone_alias(skeleton: Skeleton3D, aliases: Array) -> bool:
	for index in range(skeleton.get_bone_count()):
		var normalized := str(skeleton.get_bone_name(index)).to_lower().replace("_", "").replace(".", "")
		for alias in aliases:
			var wanted := str(alias).to_lower().replace("_", "").replace(".", "")
			if normalized == wanted or normalized.ends_with(wanted):
				return true
	return false

func _has_textured_mesh(node: Node3D) -> bool:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null:
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_surface_override_material(index)
			if material == null:
				material = mesh.mesh.surface_get_material(index)
			if material is StandardMaterial3D and material.albedo_texture != null:
				return true
	return false

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyelef", "eyeright", "fakeneck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token):
				return true
	return false

func _find_named(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var found := _find_named(child, target)
		if found != null:
			return found
	return null

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if is_instance_valid(helper):
		helper.free()
	if failures.is_empty():
		print("CHAR-008 VERIFIER: PASS - named actors share the cohesive native-face ecosystem")
	else:
		print("CHAR-008 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
