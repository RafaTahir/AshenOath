extends SceneTree

const EnemyAI = preload("res://scripts/enemy_ai.gd")

var failures := 0

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://monster_family_manifest.json"))
	check(typeof(manifest) == TYPE_DICTIONARY, "Monster family manifest is invalid")
	var families: Dictionary = manifest.get("families", {}) if typeof(manifest) == TYPE_DICTIONARY else {}
	check(families.size() == 4, "Four released Wychwood profiles are required")
	var visual_roles: Dictionary = {}
	var target := Node3D.new()
	root.add_child(target)
	await process_frame
	for enemy_id in families:
		var enemy = EnemyAI.new()
		root.add_child(enemy)
		enemy.setup(enemy_id, {
			"name": enemy_id, "health": 50, "damage": 10, "speed": 2.0,
			"attack_range": 1.5, "sense_range": 10.0, "color": "#596451"
		}, target)
		await process_frame
		var mapped = enemy.visual_root.get_child(0) if enemy.visual_root != null and enemy.visual_root.get_child_count() > 0 else null
		check(mapped != null, "%s has no rendered body" % enemy_id)
		if mapped != null:
			var role := str(mapped.get_meta("monster_family_role", ""))
			check(role == str(families[enemy_id].visual_role), "%s uses the wrong family mesh" % enemy_id)
			visual_roles[role] = true
			check(mapped.find_children("*", "Skeleton3D", true, false).size() > 0, "%s has no skeleton" % enemy_id)
			check(mapped.find_children("*", "AnimationPlayer", true, false).size() > 0, "%s has no animations" % enemy_id)
			check(not _has_proxy_anatomy(mapped), "%s still uses proxy anatomy" % enemy_id)
		check(enemy.behavior_profile == str(families[enemy_id].profile), "%s behavior identity does not match its visual family" % enemy_id)
		enemy.queue_free()
		await process_frame
	check(visual_roles.size() == 3, "The pack must use three visibly distinct monster bodies")
	print("MON-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _has_proxy_anatomy(node: Node) -> bool:
	for child in node.find_children("*", "", true, false):
		var label := str(child.name).to_lower()
		if "faceplane" in label or "proxy" in label or "longarm" in label or "clawleft" in label:
			return true
	return false

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
