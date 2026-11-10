extends "export_living_activity_pose_inputs.gd"

## One disposable actor and one measured style, with all other clips retained.
const TrialModifier = preload("actor_wrist_goal_trial_modifier.gd")
var trial_asset := ""
var trial_style := ""

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 4 or arguments[0] != "--asset" or arguments[2] != "--style":
		_fail("Select the exact isolated --asset and --style trial")
		return
	trial_asset = arguments[1]
	trial_style = arguments[3]
	if not TrialModifier.OFFSETS.has(trial_asset) or not TrialModifier.OFFSETS[trial_asset].has(trial_style):
		_fail("Only this frozen measured actor/style trial is available")
		return
	super._run()

func _inputs(source: String, prepared: String) -> Dictionary:
	if not source.contains("/" + trial_asset + "_") or not is_instance_valid(driver.life_modifier):
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
	trial.trial_asset = trial_asset
	trial.trial_style = trial_style
	skeleton.add_child(trial)
	trial.configure(driver.character_root, driver)
	driver.life_modifier = trial
	var inputs := super._inputs(source, prepared)
	if inputs.is_empty():
		return inputs
	var directory: String = str(get_script().resource_path).get_base_dir()
	for name: String in ["export_living_activity_pose_inputs.gd", "actor_wrist_goal_trial_modifier.gd"]:
		var path: String = directory.path_join(name)
		if not FileAccess.file_exists(path):
			return {}
		inputs[path] = FileAccess.get_sha256(path)
	# Different styles must never collide at the base exporter's signature path.
	# The path is the same real trial source under a style-specific existing alias.
	var style_source: String = "D:/Temp/AO_LivingCast_Stages234/art_source/art_recovery_v2/tools/actor_wrist_goal_trial_bread.json"
	if not FileAccess.file_exists(style_source):
		return {}
	inputs[style_source] = FileAccess.get_sha256(style_source)
	var measurement_source: String = "D:/Temp/AO_LivingCast_Stages234/.verification/motion/vale_bread_direction_selection_r2.json"
	if FileAccess.get_sha256(measurement_source) != "a0d92abf5fcad045f1ff39bbd49bb17322070b04a082f83732a6bfa8549ec421":
		return {}
	inputs[measurement_source] = FileAccess.get_sha256(measurement_source)
	return inputs

func _bake(recipe: Dictionary, skeleton_path: String, identity: String) -> Animation:
	var trial: Node = driver.life_modifier
	trial.trial_applications = 0
	trial.trial_failures.clear()
	trial.maximum_goal_error_m = 0.0
	var clip := super._bake(recipe, skeleton_path, identity)
	if clip == null:
		return null
	var selected := str(recipe.style) == trial_style
	var applications: int = trial.trial_applications
	var frames: int = int(records[-1].frames)
	if (selected and applications < frames) or (not selected and applications != 0) or not trial.trial_failures.is_empty():
		failures.append("Actor wrist trial ownership failed: " + str(trial.trial_failures))
		return null
	var offset: Vector2 = TrialModifier.OFFSETS[trial_asset][trial_style]
	records[-1]["goal_trial"] = {"selected": selected, "applications": applications, "hand": "hand_r",
		"forward_m": offset.x if selected else 0.0, "outward_m": offset.y if selected else 0.0,
		"maximum_goal_error_m": float(trial.maximum_goal_error_m), "opposite_hand_preserved": true,
		"right_translation_and_scale_preserved": true}
	return clip
