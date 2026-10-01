extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var game_script := load("res://scripts/game.gd") as Script
	_check(game_script != null and game_script.can_instantiate(), "game script failed to load")
	if game_script == null or not game_script.can_instantiate():
		_finish()
		return
	var game: Node = game_script.new() as Node
	root.add_child(game)
	var world_root := Node3D.new()
	world_root.name = "BootMaterialFixture"
	game.add_child(world_root)
	var original_material := StandardMaterial3D.new()
	original_material.albedo_color = Color(0.31, 0.47, 0.63, 0.8)
	original_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	original_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var geometry := MeshInstance3D.new()
	geometry.mesh = BoxMesh.new()
	geometry.material_override = original_material
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	world_root.add_child(geometry)

	game.call("_apply_web_opening_boot_material_budget", world_root, null, true)
	_check(game.opening_boot_material_restore_queue.size() == 1, "boot budget did not record exactly one visible geometry instance")
	_check(bool(world_root.get_meta("opening_boot_material_budget", false)), "boot budget metadata was not published")
	_check(int(world_root.get_meta("opening_boot_material_count", -1)) == 1, "boot material count metadata is incorrect")
	var boot_material := geometry.material_override as StandardMaterial3D
	_check(boot_material != null and boot_material != original_material, "temporary material override was not installed")
	if boot_material != null:
		_check(boot_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "temporary material is not unshaded")
		var expected_color := original_material.albedo_color
		expected_color.a = 1.0
		_check(boot_material.albedo_color.is_equal_approx(expected_color), "temporary material did not preserve opaque albedo")
		_check(boot_material.albedo_texture == null, "temporary material retained a texture shader feature")
		_check(boot_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "temporary material retained transparency")
		_check(boot_material.cull_mode == BaseMaterial3D.CULL_BACK, "temporary material retained a culling variant")
		_check(not boot_material.vertex_color_use_as_albedo, "temporary material retained a vertex-color variant")
	_check(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "temporary budget did not disable shadows")

	if not game.opening_boot_material_restore_queue.is_empty():
		var entry: Dictionary = game.opening_boot_material_restore_queue.pop_front()
		game.call("_restore_opening_boot_material_entry", entry)
	_check(geometry.material_override == original_material, "material override was not restored by identity")
	_check(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "shadow mode was not restored")

	world_root.queue_free()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("OPENING BOOT MATERIAL BUDGET: PASS")
	else:
		print("OPENING BOOT MATERIAL BUDGET: FAIL")
		for failure in failures:
			push_error(failure)
	_finish(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _finish(code := 1) -> void:
	quit(code)
