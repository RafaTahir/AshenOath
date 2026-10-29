extends SceneTree

# Art-only inspection of the game's genuinely prepared Greyfen. Never invokes
# New Game/Continue, loads a journey, makes a choice, or writes a gameplay save.
const Fusion = preload("res://scripts/character_animation_fusion.gd")
var output := "D:/Temp/AshenOath/art_recovery_v2/anwen_godot"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	var deadline := Time.get_ticks_msec() + 180000
	while not game.route_zone_cache.has("greyfen"):
		if game.game_started or Time.get_ticks_msec() > deadline:
			push_error("Art capture could not reach prepared Greyfen without starting a journey")
			await preload("res://tools/runtime_fixture.gd").shutdown(game)
			quit(1)
			return
		await process_frame
	var zone: Node3D = game.route_zone_cache.greyfen
	if not zone.is_inside_tree(): game.add_child(zone)
	zone.visible = true
	var actor: Node3D = zone.find_child("sister_anwen", true, false)
	if actor == null:
		push_error("Prepared Greyfen has no Anwen")
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var original := skeleton.get_parent().get_parent() as Node3D
	var transform := original.global_transform
	for mesh in actor.find_children("*", "MeshInstance3D", true, false): mesh.visible = false
	var model: Node3D = load("res://art_review/anwen/anwen_review.glb").instantiate()
	actor.add_child(model)
	model.global_transform = transform
	var player: AnimationPlayer = Fusion.attach_shared_library(model)
	preload("res://scripts/character_presentation.gd")._add_anwen_staff(model)
	if player != null:
		for clip: String in player.get_animation_list():
			if clip.to_lower().contains("idle"):
				player.play(clip)
				player.advance(0.35)
				player.pause()
				break
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.visible = false
	game.get_viewport().disable_3d = false
	var cam: Camera3D = game.camera_rig.find_children("*", "Camera3D", true, false)[0]
	cam.make_current()
	var front := model.global_basis.z.normalized()
	for label: String in ["greyfen_game_camera", "greyfen_portrait"]:
		var target := actor.global_position + Vector3.UP * (1.43 if label == "greyfen_portrait" else 0.96)
		cam.global_position = target + front * (1.25 if label == "greyfen_portrait" else 3.2)
		cam.look_at(target)
		await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("ART REVIEW: prepared Greyfen, actual lighting/camera, journey never started; NOT gameplay acceptance")
	await preload("res://tools/runtime_fixture.gd").shutdown(game)
	quit()
