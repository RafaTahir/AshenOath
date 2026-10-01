extends "res://tools/capture_anim_003.gd"

const Enemy = preload("res://scripts/enemy_ai.gd")

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	await _warm_renderer()
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "bog_wretch", "gravebound_knight", "ashwing", "white_hart_avatar"]:
		var stage := _create_stage()
		var target := CharacterBody3D.new()
		stage.add_child(target)
		var enemy := Enemy.new()
		stage.add_child(enemy)
		var started := Time.get_ticks_usec()
		enemy.setup(id, definitions.get(id, {}), target)
		var setup_ms := (Time.get_ticks_usec() - started) / 1000.0
		enemy.set_physics_process(false)
		if enemy.animation_driver == null or not enemy.animation_driver.is_valid():
			failures += 1
		else:
			enemy.animation_driver.set_external_tick(true)
			await _frames(3)
			await RenderingServer.frame_post_draw
			var count := 0
			var difference := 0.0
			var floor_y := INF
			for node in enemy.visual_root.find_children("*", "MeshInstance3D", true, false):
				if node.skin == null:
					continue
				var baked: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
				var cpu: AABB = enemy._posed_mesh_bounds(node)
				difference = maxf(difference, cpu.position.distance_to(baked.get_aabb().position))
				difference = maxf(difference, cpu.size.distance_to(baked.get_aabb().size))
				floor_y = minf(floor_y, (node.global_transform * baked.get_aabb()).position.y)
				count += 1
			print("POSED FAMILY ", JSON.stringify({"id": id, "meshes": count, "error": difference, "floor": floor_y, "setup_ms": setup_ms}))
			if count == 0 or difference > 0.001 or absf(floor_y) > 0.06:
				failures += 1
		if enemy.asset_helper != null:
			enemy.asset_helper.clear_runtime_caches()
		stage.queue_free()
		await _frames(4)
	print("ENEMY POSED BOUNDS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
