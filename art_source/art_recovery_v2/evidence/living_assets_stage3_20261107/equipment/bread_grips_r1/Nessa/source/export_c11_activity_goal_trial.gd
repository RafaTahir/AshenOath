extends "export_living_activity_pose_inputs.gd"

## Use the retained exporter, preparation, tracks and roundtrip gates. The
## disposable C11 actor receives one source-only trial of its existing modifier.
const TrialModifier = preload("c11_activity_goal_trial_modifier.gd")

func _run() -> void:
	if OS.get_cmdline_user_args() != PackedStringArray(["--asset", "C11"]):
		_fail("This isolated trial requires exactly --asset C11")
		return
	super._run()

func _inputs(source: String, prepared: String) -> Dictionary:
	if not source.contains("/C11_") or not is_instance_valid(driver.life_modifier):
		return {}
	var original: Node = driver.life_modifier
	var skeleton: Skeleton3D = driver.skeleton
	if original.get_parent() != skeleton or str(original.get_script().resource_path) != "res://scripts/character_life_modifier.gd":
		return {}
	var owner_name := original.name
	driver.life_modifier = null
	original.free()
	var trial := TrialModifier.new()
	trial.name = owner_name
	trial.active = false
	skeleton.add_child(trial)
	trial.configure(driver.character_root, driver)
	driver.life_modifier = trial
	var inputs := super._inputs(source, prepared)
	if inputs.is_empty(): return inputs
	var tools_directory: String = str(get_script().resource_path).get_base_dir()
	for name: String in ["export_living_activity_pose_inputs.gd", "c11_activity_goal_trial_modifier.gd"]:
		var path := tools_directory.path_join(name)
		if not FileAccess.file_exists(path): return {}
		inputs[path] = FileAccess.get_sha256(path)
	return inputs

func _bake(recipe: Dictionary, skeleton_path: String, identity: String) -> Animation:
	var trial: Node = driver.life_modifier
	trial.trial_applications = 0
	trial.trial_failures.clear()
	var clip := super._bake(recipe, skeleton_path, identity)
	if clip == null: return null
	var frames: int = int(records[-1].frames)
	if int(trial.trial_applications) < frames or not trial.trial_failures.is_empty():
		failures.append("C11 trial ownership/shape failed: " + str(trial.trial_failures))
		return null
	records[-1]["goal_trial"] = {"applications":int(trial.trial_applications), "hand":"hand_r",
		"opposite_hand_preserved":true, "right_translation_and_scale_preserved":true}
	return clip
