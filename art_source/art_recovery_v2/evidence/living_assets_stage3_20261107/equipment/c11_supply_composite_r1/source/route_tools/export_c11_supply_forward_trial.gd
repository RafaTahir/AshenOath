extends "export_c11_activity_goal_trial.gd"

const SupplyForwardTrial = preload("c11_supply_route_reveal_trial_modifier.gd")

func _inputs(source: String, prepared: String) -> Dictionary:
	var inputs := super._inputs(source, prepared)
	if inputs.is_empty(): return inputs
	var previous: Node = driver.life_modifier
	var skeleton: Skeleton3D = driver.skeleton
	var owner_name := previous.name
	driver.life_modifier = null
	previous.free()
	var trial := SupplyForwardTrial.new()
	trial.name = owner_name
	trial.active = false
	skeleton.add_child(trial)
	trial.configure(driver.character_root, driver)
	driver.life_modifier = trial
	var directory: String = str(get_script().resource_path).get_base_dir()
	for name: String in ["export_c11_activity_goal_trial.gd", "c11_supply_forward_trial_modifier.gd", "c11_supply_route_paired_modifier.gd", "c11_supply_route_paired_mode.gd", "c11_supply_route_reveal_trial_modifier.gd", "c11_supply_route_reveal_fixture_grip.gd"]:
		var path := directory.path_join(name)
		if not FileAccess.file_exists(path): return {}
		inputs[path] = FileAccess.get_sha256(path)
	return inputs
