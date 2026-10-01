extends SceneTree

const EnemyAI = preload("res://scripts/enemy_ai.gd")

var required := ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]
const WYCHWOOD_VISUAL_ROLES := {
	"ghoulkin": {"role": "ghoulkin_creature", "path": "res://assets_external/characters_universal/runtime/Ghoulkin_Authored_Atlas.gltf"},
	"wychwood_stalker": {"role": "wychwood_stalker_creature", "path": "res://assets_external/enemies/ultimate_monsters/Demon.gltf"},
	"wychwood_raider": {"role": "wychwood_raider_creature", "path": "res://assets_external/enemies/ultimate_monsters/Orc.gltf"},
	"wychwood_brute": {"role": "wychwood_brute_creature", "path": "res://assets_external/enemies/ultimate_monsters/BlueDemon.gltf"},
}
var failures := 0
var ghoulkin_only := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ghoulkin_only = OS.get_cmdline_user_args().has("--ghoulkin-only")
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
	if not ghoulkin_only:
		await _verify_white_hart_runtime(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
		await _verify_connected_family_runtime("bog_wretch", parsed if typeof(parsed) == TYPE_DICTIONARY else {})
		await _verify_connected_family_runtime("gravebound_knight", parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	if failures == 0:
		print("PASS MON-002: %s" % ("affected grounded Ghoulkin runtime contract" if ghoulkin_only else "released monster and boss roles have data and presentation mappings"))
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
		if ghoulkin_only and enemy_id != "ghoulkin":
			continue
		var expected: Dictionary = WYCHWOOD_VISUAL_ROLES[enemy_id]
		var role_id := str(expected.get("role", ""))
		var family_entry: Dictionary = enemy_roles.get(role_id, {})
		check(not family_entry.is_empty(), "%s has no explicit connected family role" % enemy_id)
		var source_path := str(family_entry.get("path", ""))
		check(source_path == str(expected.get("path", "")), "%s is mapped to an unexpected family source" % enemy_id)
		check(ResourceLoader.exists(source_path), "%s family source is not loadable" % enemy_id)
	var selected_paths: Dictionary = {}
	for enemy_id in WYCHWOOD_VISUAL_ROLES:
		var selected_path := str(WYCHWOOD_VISUAL_ROLES[enemy_id].get("path", ""))
		check(not selected_paths.has(selected_path), "%s duplicates another Wychwood body" % enemy_id)
		selected_paths[selected_path] = enemy_id

func _verify_wychwood_family_runtime(enemy_definitions: Dictionary) -> void:
	for enemy_id in WYCHWOOD_VISUAL_ROLES:
		if ghoulkin_only and enemy_id != "ghoulkin":
			continue
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
		if driver != null and driver.has_method("get_contract_report"):
			var animation_report: Dictionary = driver.get_contract_report()
			check(bool(animation_report.get("valid", false)), "%s runtime animation contract is unresolved: %s" % [enemy_id, animation_report.get("errors", [])])
			if enemy_id == "ghoulkin":
				var skeleton := _find_type(actor, "Skeleton3D") as Skeleton3D
				check(skeleton != null and skeleton.get_bone_count() == 65, "grounded Ghoulkin must retain the complete Universal rig")
				for state in ["idle", "walk", "run", "attack", "hit", "death"]:
					check(driver.resolved_clip_map.has(state), "grounded Ghoulkin lacks %s" % state)
				for mesh_node in actor.find_children("*", "MeshInstance3D", true, false):
					var mesh := mesh_node as MeshInstance3D
					if mesh.skin == null:
						continue
					check(mesh.mesh != null and mesh.mesh.get_surface_count() == 1, "Ghoulkin body must be a single skinned authored surface")
					if mesh.mesh != null:
						check(mesh.get_active_material(0) != null, "Ghoulkin body has a null material")
				for state in ["walk", "attack", "hit", "death"]:
					if driver.resolved_clip_map.has(state):
						driver.animation_player.play(driver.resolved_clip_map[state])
						driver.animation_player.advance(0.22)
						await process_frame
		check(actor.find_child("visual_root", true, false) != null, "%s runtime has no visual root" % enemy_id)
		check(actor.find_child("%s_placeholder" % enemy_id, true, false) == null, "%s fell back to a placeholder body" % enemy_id)
		var visual := actor.find_child("%s_visual" % enemy_id, true, false)
		check(visual != null, "%s runtime has no mapped visual instance" % enemy_id)
		if visual != null:
			check(str(visual.get_meta("monster_family_role", "")) == str(WYCHWOOD_VISUAL_ROLES[enemy_id].get("role", "")), "%s runtime selected the wrong family role" % enemy_id)
		await _retire_actor(actor, target)

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
	check(_find_named(hart, "WhiteHartAntlerHeadAttachment") == null, "White Hart must not use proxy antlers")
	check(_find_named(hart, "SpectralAntlerMain") == null, "White Hart must use its native antler mesh")
	check(_find_named(hart, "HartBody") == null, "White Hart still uses segmented primitive fallback")
	await _retire_actor(hart, target)

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
	if driver != null and driver.has_method("get_contract_report"):
		var animation_report: Dictionary = driver.get_contract_report()
		check(bool(animation_report.get("valid", false)), "%s runtime animation contract is unresolved: %s" % [role_id, animation_report.get("errors", [])])
	check(actor.find_child("visual_root", true, false) != null, "%s runtime has no visual root" % role_id)
	check(actor.find_child("EnemyWeakPointMarker", true, false) == null, "%s fell back to primitive weak-point body" % role_id)
	await _retire_actor(actor, target)

func _retire_actor(actor: Node, target: Node) -> void:
	# Imported FBX materials and animation resources are renderer-owned. Retire
	# the actor while it is still in the tree, let queued children and skeleton
	# updates settle, then release the target and force a render sync. Immediate
	# queue_free here was producing a false active material error after a green
	# MON-002 result.
	if actor != null and is_instance_valid(actor):
		if actor.has_method("set_encounter_active"):
			actor.set_encounter_active(false)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.visible = false
		actor.queue_free()
	if target != null and is_instance_valid(target):
		target.process_mode = Node.PROCESS_MODE_DISABLED
		target.queue_free()
	await process_frame
	await process_frame
	RenderingServer.force_sync()
	await process_frame
	RenderingServer.force_sync()

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
