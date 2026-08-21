extends SceneTree

const AssetDatabase = preload("res://scripts/asset_database.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterRoleContract = preload("res://scripts/character_role_contract.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

const ROLES := [
	"player_human",
	"sister_anwen_human",
	"villager_human",
	"villager_female_human",
	"castle_guard_human",
	"road_ranger_human",
]

var failures: Array[String] = []
var helper: Node

func _initialize() -> void:
	var database := AssetDatabase.new()
	helper = AssetSpawnHelper.new()
	root.add_child(database)
	root.add_child(helper)
	await process_frame
	helper.setup(database)
	for role in ROLES:
		await _verify_role(role)
	if failures.is_empty():
		print("CHAR-005 ROLE CONTRACT: PASS - one-pass normalization, grounding, sockets, and role scale")
	else:
		print("CHAR-005 ROLE CONTRACT: FAIL (%d)" % failures.size())
		for failure in failures:
			push_error(failure)
	if is_instance_valid(helper):
		helper.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _verify_role(role: String) -> void:
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	_check(visual != null and not visual.name.ends_with("_placeholder"), "%s did not produce a runtime visual" % role)
	if visual == null:
		return
	root.add_child(visual)
	await process_frame
	var spec := CharacterRoleSpec.for_role(role)
	var report: Dictionary = CharacterRoleContract.inspect(visual, role)
	_check(bool(report.get("normalized_once", false)), "%s was not normalized" % role)
	_check(int(report.get("normalization_passes", 0)) == 1, "%s has more than one normalization pass" % role)
	_check(not bool(visual.get_meta("character_normalization_violation", false)), "%s recorded a normalization violation" % role)
	_check(bool(report.get("grounded", false)), "%s rendered bounds are not grounded" % role)
	_check(absf(float(report.get("rendered_height", 0.0)) - float(spec.get("height", 1.72))) <= float(spec.get("height_tolerance", 0.08)), "%s rendered height is outside its role contract: %s" % [role, report])
	_check(int(report.get("skeleton_count", 0)) == 1, "%s must expose exactly one skeleton: %s" % [role, report])
	_check(int(report.get("skinned_mesh_count", 0)) > 0, "%s has no skinned meshes: %s" % [role, report])
	_check(int(report.get("material_surface_count", 0)) > 0, "%s has no material surfaces: %s" % [role, report])
	for socket_name in CharacterRoleSpec.required_sockets(role):
		_check(bool(report.get("equipment_sockets", {}).get(socket_name, false)), "%s is missing required socket %s" % [role, socket_name])
	visual.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
