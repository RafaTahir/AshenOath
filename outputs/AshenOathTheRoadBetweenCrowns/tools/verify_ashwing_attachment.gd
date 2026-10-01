extends SceneTree

func _initialize() -> void:
	var enemy = load("res://scripts/enemy_ai.gd").new()
	root.add_child(enemy)
	enemy.setup("ashwing", {"boss": true, "health": 340}, null)
	await process_frame
	var socket := enemy.find_child("AshwingHarnessSocket", true, false) as BoneAttachment3D
	var harness := enemy.find_child("AshwingBurntHarness", true, false) as MeshInstance3D
	var core := enemy.find_child("AshwingAshCore", true, false) as MeshInstance3D
	var failed := socket == null or harness == null or core == null
	if not failed:
		failed = socket.bone_name != "Body" or not socket.is_ancestor_of(harness) or not socket.is_ancestor_of(core)
		var frame: Transform3D = enemy.boss_visual_root.transform
		var previous_energy := -1.0
		for phase in [1, 2, 3]:
			enemy.apply_boss_phase_visual(phase)
			failed = failed or harness.visible != (phase < 3)
			var material := core.material_override as StandardMaterial3D
			failed = failed or material == null
			if material != null:
				failed = failed or material.emission_energy_multiplier <= previous_energy
				previous_energy = material.emission_energy_multiplier
		var prior_position := core.global_position
		enemy.animation_driver.set_external_tick(true)
		enemy.animation_driver.trigger_action("attack", 1.0, 0.0, true)
		enemy.animation_driver.advance_external(0.3)
		enemy.animation_driver.get_skeleton().force_update_all_bone_transforms()
		enemy._animate_boss_identity(0.3)
		await process_frame
		failed = failed or not enemy.boss_visual_root.transform.is_equal_approx(frame)
		failed = failed or prior_position.distance_to(core.global_position) < 0.01
	if enemy.asset_helper != null:
		enemy.asset_helper.clear_runtime_caches()
	enemy.queue_free()
	for frame in range(8):
		await process_frame
	print("ASHWING ATTACHMENT: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
