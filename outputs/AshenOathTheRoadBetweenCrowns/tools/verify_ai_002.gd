extends SceneTree

var failures := 0

func _initialize() -> void:
	var enemies = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://ai_family_contract.json"))
	check(typeof(enemies) == TYPE_DICTIONARY, "Enemy definitions are invalid")
	check(typeof(contract) == TYPE_DICTIONARY, "AI family contract is invalid")
	var profiles: Dictionary = contract.get("profiles", {})
	var used: Dictionary = {}
	for enemy_id in enemies:
		var definition: Dictionary = enemies[enemy_id]
		var profile := str(definition.get("behavior_profile", ""))
		check(profiles.has(profile), "%s has no registered behavior profile" % enemy_id)
		check(float(definition.get("perception_memory", 0.0)) >= 1.5, "%s has no usable perception memory" % enemy_id)
		used[profile] = true
	check(used.size() == 8, "Released enemy families do not have eight distinct behavior profiles")
	var source := FileAccess.get_file_as_string("res://scripts/enemy_ai.gd")
	for required in ["_update_perception", "_has_perception_line", "last_known_player_position", "perception_refresh_time = 0.18"]:
		check(required in source, "Missing AI perception contract: %s" % required)
	check("or not can_see_player" in source, "Enemies can still attack without visual contact")
	print("AI-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
