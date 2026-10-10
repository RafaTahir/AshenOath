extends SceneTree

## Asset-authoring output only. This never constructs Game or drives gameplay.
const Spawn = preload("res://scripts/asset_spawn_helper.gd")
const OUTPUT := "D:/Temp/AshenOath/PLAYFIX_010_REFERENCES"
const SOURCES := [
	["BellEater_Playfix", "ghoulkin_creature", "bell"],
	["BogWretch_Playfix", "ghoulkin_creature", "bog"],
	["Ashwing_Playfix", "ashwing_boss", "drake"]
]

func _initialize() -> void:
	call_deferred("_author")

func _author() -> void:
	create_timer(180.0).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(768, 768)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.17, 0.18, 0.18)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.85, 0.88, 0.92)
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.5
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 130, 0)
	fill.light_color = Color(0.70, 0.77, 0.88)
	fill.light_energy = 0.6
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.current = true
	stage.add_child(camera)
	var helper := Spawn.new()
	stage.add_child(helper)
	var receipt: Dictionary = {"purpose": "Source-body references awaiting user approval", "gameplay_tested": false, "candidates": []}
	for entry in SOURCES:
		var body: Node3D = helper.spawn_visual_role(str(entry[1]), "enemies")
		if body == null or str(body.name).ends_with("_placeholder"):
			push_error("Required licensed reference source missing: " + str(entry[1]))
			quit(1)
			return
		stage.add_child(body)
		body.name = str(entry[0])
		_sculpt(body, str(entry[2]))
		var bounds := _bounds(body)
		body.position.y -= bounds.position.y
		bounds = _bounds(body)
		var center := bounds.get_center()
		var extent := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z))
		camera.position = center + Vector3(0.80, 0.32, -1.65).normalized() * extent * 1.8
		camera.look_at(center)
		var animations := body.find_children("*", "AnimationPlayer", true, false)
		for raw in animations:
			var player := raw as AnimationPlayer
			for clip in player.get_animation_list():
				if str(clip).to_lower().contains("idle") or str(clip).to_lower().contains("flying"):
					player.play(clip)
					player.advance(0.25)
					player.pause()
					break
		var image_path := OUTPUT.path_join(str(entry[0]) + ".png")
		if not OS.get_cmdline_user_args().has("--models-only"):
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image_error := root.get_texture().get_image().save_png(image_path)
			if image_error != OK:
				push_error("Reference image could not be written: " + error_string(image_error))
				quit(1)
				return
		# Preview poses must not become the bind rest used by shared animations.
		for player in animations:
			player.stop()
		for skeleton in body.find_children("*", "Skeleton3D", true, false):
			skeleton.reset_bone_poses()
			skeleton.force_update_all_bone_transforms()
		# Humanoid runtime bodies share UAL2; do not embed duplicate libraries.
		if str(entry[2]) != "drake":
			for player in animations:
				player.get_parent().remove_child(player)
				player.free()
		for child in body.find_children("*", "MeshInstance3D", true, false):
			if str(child.name).to_lower().contains("shadow"):
				child.get_parent().remove_child(child)
				child.free()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var export_error := document.append_from_scene(body, state)
		var model_path := OUTPUT.path_join(str(entry[0]) + ".glb")
		if export_error == OK:
			export_error = document.write_to_filesystem(state, model_path)
		if export_error != OK:
			push_error("Reference body export failed: " + error_string(export_error))
			quit(1)
			return
		receipt.candidates.append({"id": entry[0], "retained_source_role": entry[1], "license": "CC0 1.0 retained-source derivative", "image": image_path, "model": model_path, "model_sha256": FileAccess.get_sha256(model_path), "approved": false})
		stage.remove_child(body)
		body.free()
	var file := FileAccess.open(OUTPUT.path_join("reference_sources.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("ASSET AUTHORING COMPLETE: " + OUTPUT)
	stage.queue_free()
	await process_frame
	quit(0)

func _sculpt(body: Node3D, variant: String) -> void:
	for raw in body.find_children("*", "MeshInstance3D", true, false):
		var instance := raw as MeshInstance3D
		if not instance.mesh is ArrayMesh or str(instance.name).to_lower().contains("shadow"):
			continue
		var source := instance.mesh as ArrayMesh
		var authored := ArrayMesh.new()
		var skeleton: Skeleton3D = instance.get_node_or_null(instance.skeleton) as Skeleton3D if instance.skeleton != NodePath("") else null
		for surface in range(source.get_surface_count()):
			var arrays := source.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var slots: int = bones.size() / maxi(1, points.size())
			for vertex in range(points.size()):
				var original := points[vertex]
				var changed := Vector3.ZERO
				var total := 0.0
				for slot in range(slots):
					var index := vertex * slots + slot
					var bind := bones[index]
					if weights[index] <= 0 or instance.skin == null or bind >= instance.skin.get_bind_count():
						continue
					var name := str(instance.skin.get_bind_name(bind)).to_lower()
					var bone := instance.skin.get_bind_bone(bind)
					if name == "" and skeleton != null and bone >= 0 and bone < skeleton.get_bone_count():
						name = skeleton.get_bone_name(bone).to_lower()
					var center := instance.skin.get_bind_pose(bind).affine_inverse().origin
					var scale := Vector3.ONE
					if variant in ["bell", "bog"]:
						if name.contains("spine") or name.contains("chest"):
							scale = Vector3(1.36 if variant == "bell" else 1.24, 1.0, 1.22)
						elif name.contains("upperarm") or name.contains("lowerarm"):
							scale = Vector3(1.0, 1.18, 1.18)
					elif name.contains("head"):
						scale = Vector3(0.88, 0.86, 1.28)
					elif name.contains("wing"):
						scale = Vector3(1.12, 0.92, 1.0)
					changed += (center + (original - center) * scale) * weights[index]
					total += weights[index]
				if total > 0.0:
					points[vertex] = changed / total
			arrays[Mesh.ARRAY_VERTEX] = points
			authored.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			var material: Material = instance.get_surface_override_material(surface)
			if material == null:
				material = source.surface_get_material(surface)
			if material is StandardMaterial3D:
				material = material.duplicate()
				material.albedo_color *= Color(0.84, 0.81, 0.76) if variant == "bell" else (Color(0.54, 0.64, 0.51) if variant == "bog" else Color(0.43, 0.45, 0.43))
				material.roughness = 0.88
				material.emission_enabled = false
			authored.surface_set_material(surface, material)
			instance.set_surface_override_material(surface, null)
		instance.mesh = authored
	body.set_meta("playfix_reference_variant", variant)
	body.set_meta("retained_skin_and_animation_contract", true)

func _bounds(body: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for raw in body.find_children("*", "MeshInstance3D", true, false):
		var instance := raw as MeshInstance3D
		if instance.mesh == null or str(instance.name).to_lower().contains("shadow"):
			continue
		var bounds: AABB = instance.global_transform * instance.mesh.get_aabb()
		result = result.merge(bounds) if found else bounds
		found = true
	return result
