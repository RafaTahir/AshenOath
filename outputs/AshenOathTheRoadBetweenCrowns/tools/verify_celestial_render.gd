extends SceneTree

const Director = preload("res://scripts/visual_director.gd")
const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var director := Director.new()
	root.add_child(director)
	director.set_time(0.0, "night")
	director.cloud_layer.visible = false
	director.moon_disc.visible = false
	var field: MultiMeshInstance3D = director.star_field
	field.visible = false
	await settle()
	var baseline := root.get_texture().get_image()
	field.visible = true
	await settle()
	var mesh_material_image := root.get_texture().get_image()
	mesh_material_image.save_png("D:/Temp/AshenOath/star_mesh_material.png")
	var validator := Game.new()
	validator._validate_zone_render_resources(director)
	validator._validate_zone_render_resources(director)
	await settle()
	var validated_image := root.get_texture().get_image()
	var material_preserved := field.material_override == null
	validator.material_cache.clear()
	validator.free()
	field.material_override = field.multimesh.mesh.material
	await settle()
	var override_image := root.get_texture().get_image()
	override_image.save_png("D:/Temp/AshenOath/star_override_material.png")
	var results := {"mesh_material": differences(baseline, mesh_material_image), "override_material": differences(baseline, override_image), "after_validation": differences(baseline, validated_image), "validation_changed_pixels": differences(mesh_material_image, validated_image)}
	print("CELESTIAL_RENDER ", JSON.stringify(results))
	var passed: bool = material_preserved and results.after_validation.bright > 20 and results.after_validation.dark < 20 and results.validation_changed_pixels.bright == 0 and results.validation_changed_pixels.dark == 0
	director.clear_runtime_caches()
	director.queue_free()
	camera.queue_free()
	await settle()
	print("CELESTIAL RENDER: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func settle() -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw

func differences(before: Image, after: Image) -> Dictionary:
	var result := {"bright": 0, "dark": 0}
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := (b.r + b.g + b.b - a.r - a.g - a.b) / 3.0
			if delta > 0.04:
				result.bright += 1
			elif delta < -0.04:
				result.dark += 1
	return result
