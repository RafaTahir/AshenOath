extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterIdentityProfile = preload("res://scripts/character_identity_profile.gd")
const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")

const GALLERY := "res://Development_Gallery/screenshots"
var stage: Node3D
var camera: Camera3D
var helper: Node
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GALLERY))
	stage = Node3D.new()
	stage.name = "CharacterRestoreGallery"
	root.add_child(stage)
	_build_lighting()
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 34.0
	stage.add_child(camera)
	_add_gallery_floor()
	helper = AssetSpawnHelper.new()
	helper.name = "CharacterRestoreAssetHelper"
	stage.add_child(helper)
	await process_frame

	await _capture_humanoid("CHAR-RESTORE-001_A1_Kael.png", "player_human", "kael", Vector3(0, 1.16, 3.55), Vector3(0, 1.02, 0.0), true)
	await _capture_humanoid("CHAR-RESTORE-001_A2_Anwen.png", "sister_anwen_human", "sister_anwen", Vector3(0, 1.16, 3.55), Vector3(0, 1.02, 0.0), false)
	await _capture_crowd()
	await _capture_humanoid("CHAR-RESTORE-001_Ranger_Senn.png", "road_ranger_human", "captain_senn", Vector3(0, 1.16, 3.55), Vector3(0, 1.02, 0.0), false)
	await _capture_monster_families()
	await _capture_gameplay_distance()

	if failures.is_empty():
		print("CHAR-RESTORE-001 CAPTURE: PASS")
	else:
		for failure in failures:
			push_error(failure)
		print("CHAR-RESTORE-001 CAPTURE: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _build_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "PortraitEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17212a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c4d0")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.name = "PortraitKey"
	key.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	key.light_color = Color("fff1d1")
	key.light_energy = 1.65
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "PortraitFill"
	fill.rotation_degrees = Vector3(-12.0, 142.0, 0.0)
	fill.light_color = Color("9ab9d8")
	fill.light_energy = 0.42
	stage.add_child(fill)

func _add_gallery_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "PortraitFloor"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(24.0, 24.0)
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3b403d")
	material.roughness = 0.92
	floor.material_override = material
	stage.add_child(floor)

func _capture_humanoid(file_name: String, visual_role: String, identity: String, camera_position: Vector3, target: Vector3, player_role: bool) -> void:
	_clear_actors()
	var visual: Node3D = helper.spawn_visual_role(visual_role, "characters")
	if visual == null:
		failures.append("Unable to spawn %s" % visual_role)
		return
	var owner := Node3D.new()
	owner.name = "GalleryOwner_%s" % identity
	owner.set_meta("character_variant_seed", identity)
	stage.add_child(owner)
	owner.add_child(visual)
	# The runtime contract calibrates Universal sources to gameplay -Z. The
	# gallery camera looks toward the actor from +Z, so turn the actor once for
	# a front-facing portrait without changing the authored runtime orientation.
	visual.rotate_y(PI)
	if player_role:
		CharacterPresentation.apply_player(owner, visual)
	else:
		CharacterPresentation.apply_npc(owner, identity)
	CharacterVisualContract.remove_proxy_anatomy(owner)
	_play_idle(owner)
	await process_frame
	_configure_camera(camera_position, target)
	await _settle_and_capture(file_name)
	owner.queue_free()
	await process_frame

func _capture_crowd() -> void:
	_clear_actors()
	var specs := [
		["villager_human", "generic_villager_01", -2.05, 0.00],
		["villager_female_human", "widow_elna", -0.68, 0.08],
		["villager_human", "blacksmith_tor", 0.68, -0.04],
		["villager_female_human", "mira_herbalist", 2.05, 0.04]
	]
	for spec in specs:
		var visual_role := str(spec[0])
		var identity := str(spec[1])
		var visual: Node3D = helper.spawn_visual_role(visual_role, "characters")
		if visual == null:
			failures.append("Unable to spawn crowd role %s" % visual_role)
			continue
		var owner := Node3D.new()
		owner.name = "GalleryCrowd_%s" % identity
		owner.position = Vector3(float(spec[2]), 0.0, float(spec[3]))
		owner.set_meta("character_variant_seed", identity)
		stage.add_child(owner)
		owner.add_child(visual)
		visual.rotate_y(PI)
		CharacterPresentation.apply_npc(owner, identity)
		CharacterVisualContract.remove_proxy_anatomy(owner)
		_play_idle(owner)
	await process_frame
	_configure_camera(Vector3(0.0, 1.36, 6.45), Vector3(0.0, 1.0, 0.0))
	await _settle_and_capture("CHAR-RESTORE-001_Crowd_Variation.png")
	_clear_actors()

func _capture_monster_families() -> void:
	_clear_actors()
	var specs := [
		["ghoulkin_skeleton", "ghoulkin", -2.60, 0.20, 1.00],
		["ghoulkin_skeleton", "wychwood_stalker", -1.30, 0.00, 0.92],
		["ghoulkin_skeleton", "wychwood_raider", 0.00, 0.12, 1.10],
		["ghoulkin_skeleton", "wychwood_brute", 1.30, 0.18, 1.22],
		["gravebound_knight_creature", "gravebound_knight", 2.60, 0.05, 1.10]
	]
	for spec in specs:
		var visual_role := str(spec[0])
		var identity := str(spec[1])
		var visual: Node3D = helper.spawn_visual_role(visual_role, "enemies")
		if visual == null:
			failures.append("Unable to spawn monster role %s" % visual_role)
			continue
		var owner := Node3D.new()
		owner.name = "GalleryMonster_%s" % identity
		owner.position = Vector3(float(spec[2]), 0.0, float(spec[3]))
		owner.scale = Vector3.ONE * float(spec[4])
		owner.set_meta("character_variant_seed", identity)
		stage.add_child(owner)
		owner.add_child(visual)
		CharacterIdentityProfile.apply(visual, identity, identity)
		CharacterVisualContract.remove_proxy_anatomy(owner)
		_play_idle(owner)
	await process_frame
	_configure_camera(Vector3(0.0, 1.42, 7.15), Vector3(0.0, 1.10, 0.0))
	await _settle_and_capture("CHAR-RESTORE-001_Monster_Families.png")
	_clear_actors()

func _capture_gameplay_distance() -> void:
	await _capture_humanoid("CHAR-RESTORE-001_Gameplay_Kael.png", "player_human", "kael", Vector3(0.0, 1.55, 7.4), Vector3(0.0, 0.92, 0.0), true)
	await _capture_humanoid("CHAR-RESTORE-001_Gameplay_Anwen.png", "sister_anwen_human", "sister_anwen", Vector3(2.25, 1.52, 6.75), Vector3(0.0, 0.92, 0.0), false)
	await _capture_humanoid("CHAR-RESTORE-001_Dialogue_Anwen.png", "sister_anwen_human", "sister_anwen", Vector3(1.55, 1.28, 4.10), Vector3(0.0, 1.02, 0.0), false)

func _configure_camera(camera_position: Vector3, target: Vector3) -> void:
	camera.position = camera_position
	camera.look_at_from_position(camera_position, target, Vector3.UP)

func _play_idle(actor: Node) -> void:
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	for raw_player in players:
		var player := raw_player as AnimationPlayer
		if player == null:
			continue
		var selected := StringName()
		# Prefer the neutral clip exactly. A loose "idle" substring can select
		# sword-idle, crouch-idle, or an authored transition and make evidence
		# look like a broken bind pose.
		for preferred in ["Idle", "Idle_Talking", "Idle_No", "SkeletonArmature|Skeleton_Idle"]:
			if player.has_animation(preferred):
				selected = StringName(preferred)
				break
		if selected == StringName():
			for animation_name in player.get_animation_list():
				var key := str(animation_name).to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("|", "")
				if key.ends_with("idle") or key.ends_with("standing") or key.ends_with("rest"):
					selected = animation_name
					break
		if selected != StringName():
			player.play(selected)
			return

func _settle_and_capture(file_name: String) -> void:
	await _frames(18)
	var texture := root.get_texture()
	if texture == null:
		failures.append("No graphical viewport texture available for %s" % file_name)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append("Blank image captured for %s" % file_name)
		return
	if image.get_width() != 1280 or image.get_height() != 720:
		failures.append("Unexpected dimensions for %s: %dx%d" % [file_name, image.get_width(), image.get_height()])
		return
	var path := "%s/%s" % [GALLERY, file_name]
	if image.save_png(path) != OK:
		failures.append("Unable to save %s" % path)
	else:
		print("CAPTURED ", path)

func _clear_actors() -> void:
	for child in stage.get_children():
		if child == camera or child.name in ["PortraitKey", "PortraitFill", "PortraitFloor", "CharacterRestoreGalleryEnvironment", "PortraitEnvironment"]:
			continue
		if child == helper:
			continue
		if child is Node3D:
			child.queue_free()
	await process_frame

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
