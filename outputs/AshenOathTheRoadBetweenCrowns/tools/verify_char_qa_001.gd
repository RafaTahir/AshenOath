extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")

const ROLES := [
	["player_human", "kael", 1.45, 2.05],
	["sister_anwen_human", "sister_anwen", 1.40, 1.95],
	["villager_human", "generic_villager_01", 1.40, 2.05],
	["villager_female_human", "widow_elna", 1.40, 2.05],
	["villager_worker_human", "blacksmith_tor", 1.40, 2.05],
	["villager_hooded_human", "widow_elna", 1.40, 2.05],
	["castle_guard_human", "castle_guard", 1.45, 2.05],
	["road_ranger_human", "captain_senn", 1.45, 2.05],
]

var failures: Array[String] = []
var helper: Node

func _initialize() -> void:
	helper = AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	for spec in ROLES:
		await _verify_role(str(spec[0]), str(spec[1]), float(spec[2]), float(spec[3]))
	var connected := Input.get_connected_joypads()
	print("CHAR-QA-001 physical controllers detected: %d" % connected.size())
	_finish()

func _verify_role(role: String, identity: String, minimum_height: float, maximum_height: float) -> void:
	var owner := Node3D.new()
	root.add_child(owner)
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	_check(visual != null, "%s did not instantiate" % role)
	if visual == null:
		owner.free()
		return
	owner.add_child(visual)
	if role == "player_human":
		CharacterPresentation.apply_player(owner, owner)
	else:
		CharacterPresentation.apply_npc(owner, identity)
	await process_frame
	_check(bool(visual.get_meta("character_composite", false)), "%s is not a shared humanoid composite" % role)
	_check(_has_named_layer(visual, "superhero") or _has_named_layer(visual, "eyebrows"), "%s lacks its native modeled head" % role)
	_check(_has_named_layer(visual, "peasant"), "%s lacks its complete outfit body" % role)
	_check(_has_named_layer(visual, "hair"), "%s lacks bone-driven native hair" % role)
	_check(_count_type(visual, "Skeleton3D") == 1, "%s must use one consolidated skeleton" % role)
	_check(_count_type(visual, "AnimationPlayer") == 1, "%s must use one consolidated animation player" % role)
	_check(int(visual.get_meta("character_rig_layer_count", 0)) == 1, "%s rig consolidation metadata is invalid" % role)
	_check(not _has_proxy_anatomy(visual), "%s contains forbidden proxy anatomy" % role)
	var report: Dictionary = visual.get_meta("character_visual_contract", {})
	_check(bool(report.get("valid", false)), "%s failed the rendered character contract" % role)
	var bounds: AABB = report.get("bounds", AABB())
	_check(bounds.size.y >= minimum_height and bounds.size.y <= maximum_height,
		"%s rendered height %.2f is outside %.2f-%.2f m" % [role, bounds.size.y, minimum_height, maximum_height])
	var base_path := str(visual.get_meta("character_base_path", ""))
	_check(base_path.ends_with("_Head.gltf"), "%s still loads a full duplicate base body" % role)
	owner.free()

func _has_named_layer(node: Node, token: String) -> bool:
	for child in node.find_children("*", "", true, false):
		if str(child.name).to_lower().contains(token):
			return true
	return false

func _count_type(node: Node, type_name: String) -> int:
	return node.find_children("*", type_name, true, false).size()

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var lowered := str(child.name).to_lower().replace("_", "")
		for token in ["faceplane", "eyebox", "fakeneck", "proxy", "hunchedback", "motionarm", "motionleg"]:
			if lowered.contains(token):
				return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if is_instance_valid(helper):
		helper.free()
	if failures.is_empty():
		print("CHAR-QA-001 VERIFIER: PASS - cohesive rigged humanoids and controller contract accepted")
	else:
		print("CHAR-QA-001 VERIFIER: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
