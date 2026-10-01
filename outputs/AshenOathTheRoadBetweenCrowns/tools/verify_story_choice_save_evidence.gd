extends SceneTree

const StoryStateScript = preload("res://scripts/story_state.gd")
const TEMP_ROOT := "D:/Temp/AshenOath/"
const USER_SUFFIX := "/AppData/Roaming/Godot/app_userdata/Ashen Oath- The Road Between Crowns/"
const GROUPS := [
	["edric", "edric_campaign", "edric_stance", ["exposed", "compelled"], "edric_exposed_v2_fixture", "ashen_oath_save.json", "story_edric_choices_20260928"],
	["mill", "miller_record", "mill_fate", ["burned", "exposed"], "ashwing_v5_fixture", "ashen_oath_autosave.json.bak", "story_main_choices_20260928"],
	["senn", "captain_senn", "senn_fate", ["exile", "punished"], "senn_fight_v3_fixture", "ashen_oath_autosave.json.bak", "story_main_choices_20260928"],
	["halvern", "halvern", "halvern_fate", ["released", "destroyed"], "halvern_choice_v1_fixture", "ashen_oath_save.json.bak", "story_main_choices_20260928"],
	["assembly", "assembly_choice", "confession_method", ["kael", "edric"], "assembly_choice_v4_fixture", "ashen_oath_save.json.bak", "story_assembly_choices_v2_20260928"],
	["shrine", "crow_shrine_choice", "crow_shrine_state", ["disturbed", "bound"], "chapel_pier_aligned", "ashen_oath_autosave.json.bak", "story_early_choices_v2_20260928"],
	["bog", "bog_core_choice", "bog_core_fate", ["preserved", "returned"], "bog_fixture", "ashen_oath_autosave.json.bak", "story_early_choices_v2_20260928"],
	["names", "names_decision", "names_policy", ["withheld"], "names_choice_fixture", "ashen_oath_autosave.json.bak", "story_early_choices_v2_20260928"],
	["ledger", "vargan_ledger_choice", "", ["hidden", "copied"], "record_ledger_v1_fixture", "ashen_oath_save.json.bak", "story_early_choices_v2_20260928"],
]

var failures: Array[String] = []

func _initialize() -> void:
	var dialogue := _read_json("res://data/campaign_dialogue.json")
	var checked := 0
	for group in GROUPS:
		var before := _read_json(TEMP_ROOT + str(group[4]) + USER_SUFFIX + str(group[5]))
		for choice in group[3]:
			var case_id := "%s-%s" % [group[0], choice]
			if group[0] == "edric":
				case_id = str(choice)
			var root_dir := TEMP_ROOT + str(group[6]) + "/"
			var actual := _read_json(root_dir + case_id + USER_SUFFIX + "ashen_oath_save.json")
			var reloaded := _read_json(root_dir + case_id + "-reload" + USER_SUFFIX + "ashen_oath_save.json")
			var selected_flag := str(group[2]) if group[0] != "ledger" else ("vargan_ledger_hidden" if choice == "hidden" else "vargan_ledger_left_copied")
			var selected_value: Variant = choice if group[0] != "ledger" else true
			var action: Dictionary = {}
			for candidate in dialogue.get(group[1], {}).get("actions", []):
				if candidate.get("sets_flags", {}).get(selected_flag) == selected_value:
					if not action.is_empty():
						_fail(case_id + " matches multiple authored actions")
					action = candidate
			if action.is_empty() or before.is_empty() or actual.is_empty() or reloaded.is_empty():
				_fail(case_id + " lacks an authored action or genuine saved evidence")
				continue
			for suffix in ["", "-reload"]:
				var log_path: String = root_dir + case_id + str(suffix)
				if not FileAccess.file_exists(log_path + ".log") or not FileAccess.file_exists(log_path + ".err"):
					_fail(case_id + suffix + " lacks native logs")
					continue
				var output := FileAccess.get_file_as_string(log_path + ".log")
				var errors := FileAccess.get_file_as_string(log_path + ".err")
				if not output.contains("OPENING REAL INPUT NATIVE: PASS") or not output.contains("VERIFIER_PHASE: SHUTDOWN") or errors.contains("ERROR:") or errors.contains("ObjectDB instances leaked"):
					_fail(case_id + suffix + " has failed or unclean native evidence")
			var expected := StoryStateScript.new()
			expected.load_state(before.get("story_state", {}))
			for flag in action.get("sets_flags", {}):
				expected.set_flag(flag, action.sets_flags[flag])
			for value in action.get("adjusts_values", {}):
				expected.adjust_value(value, int(action.adjusts_values[value]))
			for saved in [actual, reloaded]:
				var state: Dictionary = saved.get("story_state", {})
				for flag in action.get("sets_flags", {}):
					if state.get("flags", {}).get(flag) != expected.get_flag(flag):
						_fail("%s lost authored flag %s" % [case_id, flag])
				var actual_values: Dictionary = state.get("values", {})
				if actual_values.size() != expected.values.size():
					_fail(case_id + " lost or added story-value keys")
				for value_id in expected.values:
					var observed: Variant = actual_values.get(value_id)
					# JSON numbers decode as floats; compare exact numeric values, not Dictionary types.
					if typeof(observed) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(observed)) or float(observed) != float(expected.values[value_id]):
						_fail("%s value %s differs: actual=%s expected=%s" % [case_id, value_id, observed, expected.values[value_id]])
				for item in action.get("gives_items", {}):
					var expected_count := int(before.get("inventory", {}).get("items", {}).get(item, 0)) + int(action.gives_items[item])
					if int(saved.get("inventory", {}).get("items", {}).get(item, 0)) != expected_count:
						_fail("%s lost authored item reward %s" % [case_id, item])
			expected.free()
			checked += 1
	if failures.is_empty() and checked == 17:
		print("STORY CHOICE SAVE EVIDENCE: PASS (17 authored decisions and 17 reloads; offline comparison, not graphical or full-route proof)")
		quit(0)
	else:
		print("STORY CHOICE SAVE EVIDENCE: FAIL (%d assertions, %d decisions checked)" % [failures.size(), checked])
		quit(1)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing saved evidence: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		_fail("Invalid saved evidence: " + path)
		return {}
	return parsed

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
