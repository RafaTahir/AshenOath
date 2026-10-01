extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterRoleContract = preload("res://scripts/character_role_contract.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")

const ROLES := ["bandit_deserter", "bandit_tracker", "road_ranger_human"]

var failures: Array[String] = []
var output_dir := "D:/Temp/AshenOath/bandit_assembly_render"

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		failures.append("A graphical renderer is required")
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	var stage := _make_stage()
	var actors: Array[Node3D] = []
	var report := {"scope": "role assembly rendering only; not Bandit Road travel or combat", "roles": []}
	for index in range(ROLES.size()):
		var role: String = ROLES[index]
		var actor := Node3D.new()
		actor.name = role
		actor.position = Vector3(float(index - 1) * 2.0, 0.0, 0.0)
		stage.add_child(actor)
		var visual: Node3D = helper.spawn_enemy(role) if role.begins_with("bandit") else helper.spawn_visual_role(role, "characters")
		if visual == null:
			failures.append("Missing runtime visual for " + role)
			continue
		actor.add_child(visual)
		actors.append(actor)
		var contract: Dictionary = CharacterRoleContract.inspect(visual, role)
		var target_height := CharacterRoleSpec.target_height(role, 1.75)
		_check(int(contract.get("skeleton_count", 0)) == 1, role + " needs one skeleton")
		_check(int(contract.get("skinned_mesh_count", 0)) > 0, role + " needs skinned geometry")
		_check(int(contract.get("material_surface_count", 0)) > 0, role + " needs a material")
		_check(bool(contract.get("grounded", false)), role + " is not grounded")
		_check(absf(float(contract.get("rendered_height", 0.0)) - target_height) <= 0.08, role + " is outside height tolerance")
		var animation := _find_animation(visual)
		_check(animation != null and animation.has_animation("Idle"), role + " lacks shared idle animation")
		if animation != null and animation.has_animation("Idle"):
			animation.play("Idle")
		report.roles.append({
			"role": role,
			"source": str(visual.get_meta("runtime_asset_path", "")),
			"contract": contract,
		})
	await _frames(20)
	await _capture("lineup", stage.get_node("Camera3D"), report)
	for actor in actors:
		var camera: Camera3D = stage.get_node("Camera3D")
		camera.position = actor.position + Vector3(0.0, 1.4, -3.2)
		camera.look_at(actor.position + Vector3(0.0, 0.95, 0.0))
		await _frames(4)
		await _capture(actor.name + "_close", camera, report)
	var camera: Camera3D = stage.get_node("Camera3D")
	camera.position = Vector3(0.0, 1.42, -8.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	for actor in actors:
		var animation := _find_animation(actor)
		_check(animation != null and animation.has_animation("Walk"), actor.name + " lacks shared walk animation")
		if animation != null and animation.has_animation("Walk"):
			animation.play("Walk")
	await _frames(15)
	await _capture("lineup_walk", camera, report)
	var report_file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report_file == null:
		failures.append("Cannot write render report")
	else:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	stage.queue_free()
	helper.queue_free()
	await _frames(3)
	_finish()

func _make_stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151a1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bcb4a6")
	environment.ambient_light_energy = 1.05
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -26, 0)
	light.light_color = Color("ffe0bd")
	light.light_energy = 1.7
	stage.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 8)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("393229")
	ground.material_override = ground_material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.42, -8.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0))
	camera.fov = 42.0
	camera.current = true
	stage.add_child(camera)
	return stage

func _find_animation(node: Node) -> AnimationPlayer:
	for child in node.find_children("*", "AnimationPlayer", true, false):
		if child is AnimationPlayer and child.has_animation("Idle"):
			return child as AnimationPlayer
	return null

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _capture(label: String, camera: Camera3D, report: Dictionary) -> void:
	camera.make_current()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720):
		failures.append("Invalid " + label + " frame")
		return
	var path := output_dir.path_join(label + ".png")
	if image.save_png(path) != OK:
		failures.append("Cannot save " + label)
		return
	report[label] = {"path": path, "sha256": FileAccess.get_sha256(path)}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	print("BANDIT ASSEMBLY RENDER: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
