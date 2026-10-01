extends SceneTree

func _initialize() -> void:
	var enemy = load("res://scripts/enemy_ai.gd").new()
	root.add_child(enemy)
	enemy.setup("halvern_boss", {"boss": true, "health": 230}, null)
	await process_frame
	var socket := enemy.find_child("HalvernSwordSocket", true, false) as BoneAttachment3D
	var sword := enemy.find_child("HalvernAuthoredSword", true, false) as Node3D
	var failed := socket == null or sword == null
	if not failed:
		var driver = enemy.animation_driver
		driver.set_external_tick(true)
		var idle_hand := Vector3.ZERO
		for state in ["idle", "attack"]:
			if state == "attack":
				driver.trigger_action("attack", 1.0, 0.0, true)
			driver.advance_external(0.20)
			driver.get_skeleton().force_update_all_bone_transforms()
			await process_frame
			var meshes := sword.find_children("*", "MeshInstance3D", true, false)
			if state == "idle":
				idle_hand = socket.global_position
			else:
				failed = failed or idle_hand.distance_to(socket.global_position) < 0.1
			failed = failed or sword.global_position.distance_to(socket.global_position) > 0.25
			for raw_mesh in meshes:
				var mesh := raw_mesh as MeshInstance3D
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				failed = failed or bounds.size.length() < 0.4 or bounds.size.length() > 2.0
				failed = failed or not mesh.is_visible_in_tree() or mesh.material_override == null
			failed = failed or meshes.is_empty() or not socket.is_ancestor_of(sword)
	if enemy.asset_helper != null:
		enemy.asset_helper.clear_runtime_caches()
	enemy.queue_free()
	for frame in range(8):
		await process_frame
	print("HALVERN EQUIPMENT: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
