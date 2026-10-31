extends SceneTree

# Art-only inspection of the game's genuinely prepared Greyfen. Never invokes
# New Game/Continue, loads a journey, makes a choice, or writes a gameplay save.
const Fusion = preload("res://scripts/character_animation_fusion.gd")
var output := "D:/Temp/AshenOath/art_recovery_v2/anwen_godot"
var asset_path := "res://art_review/anwen/anwen_review.glb"
var staff_path := ""
var roster_path := ""
var selected_ids: PackedStringArray = []

func _initialize() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	if not isolated.ends_with("/AshenOath_Anwen_ArtReview_20261030"):
		push_error("Art review refused to use the normal journey data directory")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): asset_path = arg.trim_prefix("--asset=")
		if arg.begins_with("--staff="): staff_path = arg.trim_prefix("--staff=")
		if arg.begins_with("--roster="): roster_path = arg.trim_prefix("--roster=")
		if arg.begins_with("--ids="): selected_ids = arg.trim_prefix("--ids=").split(",", false)
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
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
	if not roster_path.is_empty():
		await capture_roster(game, zone, view)
		return
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
	var model: Node3D = load(asset_path).instantiate()
	model.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.add_child(model)
	model.global_transform = transform
	var bindings := preload("res://scripts/character_material_bindings.gd")
	if not bindings.capture(model, "res://assets_external/design_pack_v1/humans/C01_Anwen.glb"):
		push_error("Level review body fails authored material ownership: %s" % str(model.get_meta("character_material_errors", [])))
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	model.set_meta("character_prebaked_identity", true)
	model.set_meta("character_authored_silhouette", true)
	model.set_meta("character_asset_family", "quaternius_animated_humanoid")
	var identity := preload("res://scripts/character_identity_profile.gd").apply(model, "sister_anwen", "sister_anwen")
	if not bool(identity.get("valid", true)):
		push_error("Level review body could not retain its authored identity")
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	var model_skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if preload("res://scripts/character_presentation.gd").uses_fitted_anwen_staff(model_skeleton, model):
		model.set_meta("source_forward_positive_z", true)
	Fusion.attach_shared_library(model)
	preload("res://scripts/character_presentation.gd")._add_anwen_staff(model)
	var review_script: Script = load(get_script().resource_path.get_base_dir().path_join("review_scene.gd"))
	if not review_script.replace_review_staff(model, staff_path):
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	var driver: Node = preload("res://scripts/character_animation_driver.gd").new()
	model.add_child(driver)
	if not driver.configure(model, {"idle":"Idle", "walk":"Walk", "run":"Sprint"}):
		push_error("Review model did not acquire its existing animation owner")
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	driver.set_external_tick(true)
	driver.set_locomotion(0.0, Vector3.ZERO, true)
	driver.advance_external(0.35)
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.visible = false
	game.get_viewport().disable_3d = false
	var cam: Camera3D = game.camera_rig.find_children("*", "Camera3D", true, false)[0]
	cam.make_current()
	var front := model.global_basis.z.normalized()
	for label: String in ["greyfen_game_camera", "greyfen_portrait"]:
		var target := actor.global_position + Vector3.UP * (1.43 if label == "greyfen_portrait" else 0.96)
		cam.global_position = target + front * (1.25 if label == "greyfen_portrait" else 3.2)
		cam.look_at(target)
		for frame in 5:
			driver.advance_external(1.0/30.0)
			await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(output.path_join(label + ".png"))
	FileAccess.open(output.path_join("level_review.json"), FileAccess.WRITE).store_string(JSON.stringify({"asset":asset_path,"asset_sha256":FileAccess.get_sha256(asset_path),"authored_material_contract":bool(model.get_meta("character_material_bindings_valid", false)),"identity":identity,"staff":staff_path,"staff_sha256":FileAccess.get_sha256(staff_path) if not staff_path.is_empty() else "","user_directory":OS.get_user_data_dir(),"shader_disk_cache_enabled":bool(ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled", true)),"journey_started":game.game_started,"scope":"Prepared Greyfen lighting and camera; isolated input; no journey/save action; not gameplay/performance acceptance","accepted":false},"\t"))
	print("ART REVIEW: prepared Greyfen, actual lighting/camera, journey never started; NOT gameplay acceptance")
	await preload("res://tools/runtime_fixture.gd").shutdown(game)
	quit()

func capture_roster(game: Node, zone: Node3D, view: SubViewport) -> void:
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(roster_path))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	var anwen := zone.find_child("sister_anwen", true, false) as Node3D
	if anwen == null:
		push_error("Private level art staging requires the prepared Anwen anchor")
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		quit(1)
		return
	for mesh: MeshInstance3D in anwen.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	game.get_viewport().disable_3d = false
	var camera: Camera3D = game.camera_rig.find_children("*", "Camera3D", true, false)[0]
	camera.make_current()
	var captures: Array[Dictionary] = []
	for row: Dictionary in ledger.assets:
		if not selected_ids.is_empty() and str(row.id) not in selected_ids:
			continue
		var prepared := ""
		for entry: Dictionary in catalog.values():
			if str(entry.source) == str(row.destination_resource):
				prepared = str(entry.path)
				break
		if prepared.is_empty():
			push_error("Private art roster has no compiled actor: " + str(row.id))
			await preload("res://tools/runtime_fixture.gd").shutdown(game)
			quit(1)
			return
		var stand := Node3D.new()
		zone.add_child(stand)
		stand.global_position = anwen.global_position + Vector3(0, 0, -2.5)
		var model := (load(prepared) as PackedScene).instantiate() as Node3D
		stand.add_child(model)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if player.has_animation("Idle"):
				player.play("Idle")
				player.advance(0.2)
		var source: Transform3D = model.get_meta("authored_bind_source_transform", Transform3D.IDENTITY)
		var bounds: AABB = model.transform * source.affine_inverse() * (model.get_meta("prepared_source_bounds") as AABB)
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var folder := output.path_join(str(row.id))
		DirAccess.make_dir_recursive_absolute(folder)
		for label: String in ["quarter", "rear"]:
			# A fixed clear street camera and an explicitly staged turntable,
			# not a claim about normal NPC placement or dialogue framing.
			stand.rotation.y = deg_to_rad(30.0 if label == "quarter" else 180.0)
			var center := stand.global_transform * bounds.get_center()
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.global_position = center + Vector3(0, 0.08, -1) * maxf(2.8, extent * 1.8)
			camera.look_at(center)
			await process_frame
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png(folder.path_join("level_" + label + ".png"))
		captures.append({"id":row.id,"source":row.destination_resource,"source_sha256":FileAccess.get_sha256(str(row.destination_resource)),"prepared":prepared,"prepared_sha256":FileAccess.get_sha256(prepared),"journey_started":game.game_started,"accepted":false})
		stand.queue_free()
		await process_frame
	FileAccess.open(output.path_join("level_roster.json"), FileAccess.WRITE).store_string(JSON.stringify({"scope":"Prepared art turntable in actual Greyfen lighting, fixed street camera; NOT actual NPC placement, encounter or dialogue framing acceptance","user_directory":OS.get_user_data_dir(),"journey_started":game.game_started,"assets":captures,"accepted":false},"\t"))
	print("ART REVIEW: ", captures.size(), " prepared candidates staged in Greyfen; no journey/save action")
	await preload("res://tools/runtime_fixture.gd").shutdown(game)
	quit(0)
