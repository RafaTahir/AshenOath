extends SceneTree

const EnemyAI = preload("res://scripts/enemy_ai.gd")

var required := ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]
const WYCHWOOD_VISUAL_ROLES := {
	"ghoulkin": "ghoulkin_skeleton",
	"wychwood_stalker": "ghoulkin_skeleton",
	"wychwood_raider": "ghoulkin_skeleton",
	"wychwood_brute": "ghoulkin_skeleton",
}
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures += 1
		push_error("enemies.json is not a dictionary")
	else:
		for role in required:
			if not parsed.has(role):
				failures += 1
				push_error("missing enemy role %s" % role)
		for boss_id in ["bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]:
			if parsed.has(boss_id) and not bool(parsed[boss_id].get("boss", false)):
				failures += 1
				push_error("%s is not marked as a boss" % boss_id)
	var enemy_ai := FileAccess.get_file_as_string("res://scripts/enemy_ai.gd")
	for needle in ["bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "_add_boss_silhouette"]:
		if not enemy_ai.contains(needle):
			failures += 1
			push_error("enemy presentation missing %s" % needle)
	_verify_wychwood_family_source()
	await _verify_wychwood_family_runtime(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	await _verify_white_hart_runtime(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	await _verify_connected_family_runtime("bog_wretch", parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	await _verify_connected_family_runtime("gravebound_knight", parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	if failures == 0:
		print("PASS MON-002: released monster and boss roles have data and presentation mappings")
		quit(0)
	else:
		push_error("MON-002: %d failure(s)" % failures)
		quit(1)

func _verify_wychwood_family_source() -> void:
	var upgrade_text := FileAccess.get_file_as_string("res://visual_upgrade_manifest.json")
	var upgrade_data = JSON.parse_string(upgrade_text)
	check(typeof(upgrade_data) == TYPE_DICTIONARY, "visual upgrade manifest is not valid JSON")
	if typeof(upgrade_data) != TYPE_DICTIONARY:
		return
	var enemy_roles: Dictionary = upgrade_data.get("roles", {}).get("enemies", {})
	for enemy_id in WYCHWOOD_VISUAL_ROLES:
		var role_id := str(WYCHWOOD_VISUAL_ROLES[enemy_id])
		var family_entry: Dictionary = enemy_roles.get(role_id, {})
		check(not family_entry.is_empty(), "%s has no explicit connected family role" % enemy_id)
		var source_path := str(family_entry.get("path", ""))
		check(source_path == "res://assets_external/enemies/Skeleton.fbx", "%s is mapped to an unexpected family source" % enemy_id)
		check(ResourceLoader.exists(source_path), "%s family source is not loadable" % enemy_id)
	var legacy_entry: Dictionary = enemy_roles.get("ghoulkin_skeleton", {})
	check(str(legacy_entry.get("status", "")).contains("char_restore") or str(legacy_entry.get("status", "")).contains("legacy_quarantined"), "retained Skeleton source must have an explicit retained status")

func _verify_wychwood_family_runtime(enemy_definitions: Dictionary) -> void:
	for enemy_id in WYCHWOOD_VISUAL_ROLES:
		var definition: Dictionary = enemy_definitions.get(enemy_id, {})
		check(not definition.is_empty(), "%s has no encounter definition" % enemy_id)
		if definition.is_empty():
			continue
		var target := Node3D.new()
		target.name = "%sVerifierTarget" % enemy_id
		root.add_child(target)
		var actor := EnemyAI.new()
		actor.name = "%sVerifierActor" % enemy_id
		root.add_child(actor)
		actor.setup(enemy_id, definition, target)
		await process_frame
		check(_find_type(actor, "Skeleton3D") != null, "%s runtime has no Skeleton3D" % enemy_id)
		check(_find_type(actor, "AnimationPlayer") != null, "%s runtime has no AnimationPlayer" % enemy_id)
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "%s runtime has no valid animation driver" % enemy_id)
		check(actor.find_child("visual_root", true, false) != null, "%s runtime has no visual root" % enemy_id)
		check(actor.find_child("%s_placeholder" % enemy_id, true, false) == null, "%s fell back to a placeholder body" % enemy_id)
		var visual := actor.find_child("%s_visual" % enemy_id, true, false)
		check(visual != null, "%s runtime has no mapped visual instance" % enemy_id)
		if visual != null:
			check(str(visual.get_meta("monster_family_role", "")) == str(WYCHWOOD_VISUAL_ROLES[enemy_id]), "%s runtime selected the wrong family role" % enemy_id)
		actor.queue_free()
		target.queue_free()

func _verify_white_hart_runtime(enemy_definitions: Dictionary) -> void:
	var definition: Dictionary = enemy_definitions.get("white_hart_avatar", {})
	if definition.is_empty():
		return
	var target := Node3D.new()
	target.name = "WhiteHartVerifierTarget"
	root.add_child(target)
	var hart := EnemyAI.new()
	hart.name = "WhiteHartVerifierActor"
	root.add_child(hart)
	hart.setup("white_hart_avatar", definition, target)
	await process_frame
	var skeleton := _find_type(hart, "Skeleton3D")
	var animation_player := _find_type(hart, "AnimationPlayer")
	check(skeleton != null, "White Hart runtime has no Skeleton3D")
	check(animation_player != null, "White Hart runtime has no AnimationPlayer")
	check(hart.get_node_or_null("visual_root") != null, "White Hart runtime has no visual root")
	var antler_attachment := _find_named(hart, "WhiteHartAntlerHeadAttachment")
	check(antler_attachment != null, "White Hart antlers are not attached to the head")
	if antler_attachment != null:
		check(str(antler_attachment.bone_name) == "Bone.003", "White Hart antlers use the wrong head bone")
	check(_find_named(hart, "SpectralAntlerMain") != null, "White Hart crown has no antler geometry")
	check(_find_named(hart, "HartBody") == null, "White Hart still uses segmented primitive fallback")
	hart.queue_free()
	target.queue_free()

func _verify_connected_family_runtime(role_id: String, enemy_definitions: Dictionary) -> void:
	var definition: Dictionary = enemy_definitions.get(role_id, {})
	if definition.is_empty():
		return
	var target := Node3D.new()
	target.name = "%sVerifierTarget" % role_id
	root.add_child(target)
	var actor := EnemyAI.new()
	actor.name = "%sVerifierActor" % role_id
	root.add_child(actor)
	actor.setup(role_id, definition, target)
	await process_frame
	check(_find_type(actor, "Skeleton3D") != null, "%s runtime has no Skeleton3D" % role_id)
	check(_find_type(actor, "AnimationPlayer") != null, "%s runtime has no AnimationPlayer" % role_id)
	var driver := actor.find_child("CharacterAnimationDriver", true, false)
	check(driver != null and driver.has_method("is_valid") and driver.is_valid(), "%s runtime has no valid animation driver" % role_id)
	check(actor.find_child("visual_root", true, false) != null, "%s runtime has no visual root" % role_id)
	check(actor.find_child("EnemyWeakPointMarker", true, false) == null, "%s fell back to primitive weak-point body" % role_id)
	actor.queue_free()
	target.queue_free()

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("MON-002: %s" % message)
