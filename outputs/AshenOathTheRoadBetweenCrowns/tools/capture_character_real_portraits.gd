extends SceneTree

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
const CharacterIdentityProfile = preload("res://scripts/character_identity_profile.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

const ROLES := {
	"kael":"player_human",
	"sister_anwen":"sister_anwen_human",
	"villager_male":"villager_human",
	"villager_female":"villager_female_human",
	"castle_guard":"castle_guard_human",
	"road_ranger":"road_ranger_human",
	"ghoul_gaunt":"ghoulkin_creature",
	"ghoul_stalker":"ghoul_stalker_real",
	"ghoul_brute":"ghoul_brute_real",
	"ashwing":"ashwing_creature"
}

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055,0.065,0.072)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55,0.60,0.68)
	environment.ambient_light_energy = 0.72
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38,-32,0)
	key.light_color = Color(1.0,0.83,0.68)
	key.light_energy = 1.35
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.18,3.4)
	camera.look_at_from_position(camera.position,Vector3(0,1.03,0),Vector3.UP)
	camera.fov = 34.0
	camera.current = true
	stage.add_child(camera)
	var gallery := "res://Development_Gallery/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(gallery))
	var helper := AssetSpawnHelper.new()
	helper.name = "PortraitAssetSpawnHelper"
	stage.add_child(helper)
	await process_frame
	for role in ROLES:
		var visual_role: String = str(ROLES[role])
		var category := "enemies" if visual_role in ["ghoulkin_creature", "ghoul_stalker_real", "ghoul_brute_real", "ashwing_creature"] else "characters"
		var character := helper.spawn_visual_role(visual_role, category)
		if character == null:
			push_error("Unable to spawn runtime portrait role: %s" % visual_role)
			continue
		character.name = "CHARACTER_REAL_%s" % role
		stage.add_child(character)
		await process_frame
		if category == "characters":
			# Runtime third-person characters face gameplay -Z; the portrait camera
			# looks from +Z, so rotate the composed actor for a front-facing proof.
			character.rotate_y(PI)
		if role == "ashwing":
			camera.position = Vector3(0.0, 1.80, 8.0)
			camera.look_at_from_position(camera.position, Vector3(0.0, 1.55, 0.0), Vector3.UP)
		else:
			camera.position = Vector3(0.0, 1.18, 3.4)
			camera.look_at_from_position(camera.position, Vector3(0.0, 1.03, 0.0), Vector3.UP)
		CharacterVisualContract.remove_proxy_anatomy(character)
		CharacterIdentityProfile.apply(character, _identity_role(role))
		await process_frame
		_normalize_character(character)
		var skeleton := character.find_child("Skeleton3D", true, false) as Skeleton3D
		var animation_players := character.find_children("*", "AnimationPlayer", true, false)
		print("PORTRAIT_ROLE ", role, " skeleton_bones=", skeleton.get_bone_count() if skeleton != null else 0, " animation_players=", animation_players.size())
		for animation_player in animation_players:
			print("PORTRAIT_ANIMATIONS ", role, " ", (animation_player as AnimationPlayer).get_animation_list())
		_play_idle(character)
		await _frames(8)
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			push_error("Character portrait capture requires a graphical renderer; no viewport texture is available in headless mode.")
			quit(2)
			return
		var image := viewport_texture.get_image()
		var path := "%s/CHARACTER_REAL_001_%s.png" % [gallery,role]
		image.save_png(path)
		print("CAPTURED ",path)
		character.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	quit(0)

func _identity_role(capture_role: String) -> String:
	return {
		"kael": "player_kael",
		"sister_anwen": "sister_anwen",
		"villager_male": "villager_male",
		"villager_female": "villager_female",
		"castle_guard": "castle_guard",
		"road_ranger": "road_ranger",
		"ghoul_gaunt": "ghoulkin",
		"ghoul_stalker": "wychwood_stalker",
		"ghoul_brute": "wychwood_brute"
	}.get(capture_role, capture_role)

func _play_idle(character: Node) -> void:
	var player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	# The Ghoul family has a second authored idle on the Stalker and Brute
	# rigs; prefer it so portrait evidence does not freeze every variant in the
	# same arms-out presentation. Human and dragon roles fall through cleanly.
	var candidates := ["idle2", "idle", "flying", "standing", "rest", "skeletonidle"]
	var selected := StringName()
	for animation_name in player.get_animation_list():
		var key := str(animation_name).to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("|", "")
		for candidate in candidates:
			if key.contains(candidate):
				selected = animation_name
				break
		if selected != StringName():
			break
	if selected != StringName():
		player.play(selected)
	else:
		push_warning("No idle-compatible clip for portrait role; animation list=%s" % [player.get_animation_list()])

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _normalize_character(character: Node3D) -> void:
	var bounds := AABB()
	var has_bounds := false
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var local_box: AABB = mesh.get_aabb()
		for corner_index in range(8):
			var corner := Vector3(
				local_box.position.x + (local_box.size.x if corner_index & 1 else 0.0),
				local_box.position.y + (local_box.size.y if corner_index & 2 else 0.0),
				local_box.position.z + (local_box.size.z if corner_index & 4 else 0.0)
			)
			var point := character.to_local(mesh.to_global(corner))
			if not has_bounds:
				bounds = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	if not has_bounds or bounds.size.y <= 0.01:
		return
	var uniform := 1.82 / bounds.size.y
	character.scale = Vector3.ONE * uniform
	var center := bounds.get_center()
	character.position = Vector3(-center.x * uniform, -bounds.position.y * uniform, -center.z * uniform)
