extends SceneTree

func _initialize() -> void:
	var enemy = load("res://scripts/enemy_ai.gd").new()
	root.add_child(enemy)
	enemy.setup("bell_eater", {"boss": true, "health": 300}, null)
	await process_frame
	var socket := enemy.find_child("BellEaterHarnessSocket", true, false) as BoneAttachment3D
	var bell := enemy.find_child("BellEaterChestBell", true, false) as MeshInstance3D
	var links := enemy.find_child("BellEaterHarnessLinks", true, false) as MultiMeshInstance3D
	var clapper := enemy.find_child("BellEaterClapper", true, false) as MeshInstance3D
	var failed := socket == null or bell == null or links == null or clapper == null
	for forbidden in ["BellEaterEyeLeft", "BellEaterEyeRight", "BellEaterJaw", "BellEaterTooth_0", "BellEaterHornLeft", "BellEaterHornRight"]:
		failed = failed or enemy.find_child(forbidden, true, false) != null
	if not failed:
		failed = failed or not socket.is_ancestor_of(bell) or socket.bone_name != "Torso"
		failed = failed or not bell.mesh is ArrayMesh or bell.mesh.surface_get_material(0) == null
		var bounds: AABB = bell.global_transform * bell.get_aabb()
		failed = failed or bounds.size.length() < 1.0 or bounds.size.length() > 2.0
		for phase in [1, 2, 3]:
			enemy.apply_boss_phase_visual(phase)
			failed = failed or links.multimesh.visible_instance_count != [12, 6, 0][phase - 1]
			failed = failed or clapper.visible != (phase < 3)
			failed = failed or bell.material_override == null
		enemy.animation_driver.set_external_tick(true)
		var before: Transform3D = bell.transform
		enemy.animation_driver.trigger_action("attack", 1.0, 0.0, true)
		enemy.animation_driver.advance_external(0.3)
		enemy.animation_driver.get_skeleton().force_update_all_bone_transforms()
		enemy._animate_boss_identity(0.3)
		await process_frame
		failed = failed or not bell.transform.is_equal_approx(before)
	if enemy.asset_helper != null:
		enemy.asset_helper.clear_runtime_caches()
	enemy.queue_free()
	for frame in range(8):
		await process_frame
	print("BELL HARNESS: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
