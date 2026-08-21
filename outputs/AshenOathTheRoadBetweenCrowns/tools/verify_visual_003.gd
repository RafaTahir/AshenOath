extends SceneTree

const WorldMaterialLibrary = preload("res://scripts/world_material_library.gd")
const REQUIRED_SURFACES := [
	"forest_ground", "wet_mud", "cobblestone", "plaster",
	"timber", "roof_tiles", "medieval_brick"
]
const FORBIDDEN_ARTIFACTS := [
	"PlayerFacePlane", "PlayerCloakSilhouette", "PlayerHarness",
	"PlayerScabbard", "PlayerLeftBoot", "PlayerRightBoot",
	"SisterAnwenGoldStole", "VillagerLayeredCloth"
]

var failures: Array[String] = []

func _initialize() -> void:
	_verify_texture_library()
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene failed to load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	await _frames(5)
	_verify_native_quality(game)
	_verify_day_night(game)
	_verify_greyfen(game)
	_verify_player_and_beam(game)
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(5)
	_verify_wychwood(game)
	# Print the assertion result before SceneTree teardown. Godot's dummy
	# renderer can report cleanup diagnostics while the verifier scene exits;
	# those are classified after the PASS marker by the release runner.
	_finish()

func _verify_texture_library() -> void:
	var material_library := WorldMaterialLibrary.new()
	root.add_child(material_library)
	for surface in REQUIRED_SURFACES:
		for suffix in ["albedo", "normal", "orm"]:
			var path := "res://assets_external/textures/runtime/%s_%s.jpg" % [surface, suffix]
			_check(ResourceLoader.exists(path), "missing runtime PBR map: %s" % path)
		var quality_material: StandardMaterial3D = material_library.get_material(surface, "quality")
		_check(
			quality_material.albedo_texture != null and quality_material.normal_enabled and quality_material.normal_texture != null,
			"Quality material does not enable the complete authored PBR stack: %s" % surface
		)
	_check(ResourceLoader.exists("res://assets_external/textures/runtime/grass_tuft.png"), "grass atlas is missing")
	for skin in ["ghoulkin_skin.jpg", "stalker_skin.jpg", "brute_skin.jpg"]:
		_check(ResourceLoader.exists("res://assets_external/textures/runtime/" + skin), "monster skin is missing: %s" % skin)

func _verify_native_quality(game: Node) -> void:
	var settings = game.settings
	settings.set_quality_preset("balanced")
	_check(is_equal_approx(float(settings.settings.resolution_scale), 1.0), "Balanced is not native 720p")
	_check(not bool(settings.settings.potato_mode), "Balanced incorrectly enables Potato Mode")
	settings.set_quality_preset("quality")
	_check(is_equal_approx(float(settings.settings.resolution_scale), 1.0), "Quality is not native 1.0 render scale")
	settings.set_quality_preset("potato")
	_check(is_equal_approx(float(settings.settings.resolution_scale), 1.0), "Potato invokes the broken viewport scaler")
	settings.set_quality_preset("balanced")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width", 0) == 1280, "Gameplay viewport width is not 1280")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height", 0) == 720, "Gameplay viewport height is not 720")

func _verify_day_night(game: Node) -> void:
	var clock = game.day_night
	var director = game.visual_director
	_check(clock != null, "DayNightController is missing")
	_check(director != null, "VisualDirector is missing")
	_check(director.star_field != null and director.star_field.multimesh.instance_count == 96, "procedural star batch is missing")
	_check(director.sun_halo != null and director.moon_halo != null, "sun or moon halo is missing")
	_check(is_equal_approx(float(clock.CYCLE_SECONDS), 2160.0), "day/night cycle is not 36 real minutes")
	clock.set_time(360.0, 2)
	_check(clock.current_phase == "dawn", "dawn phase boundary failed")
	clock.set_time(720.0, 2)
	_check(clock.current_phase == "day", "day phase boundary failed")
	_check(director.sun_disc.visible and not director.star_field.visible, "day sky visibility is incorrect")
	_check(director.sky_backdrop.visible and bool(director.sky_backdrop.get_sky_state().get("clouds_visible", false)), "authored day clouds are hidden")
	clock.set_time(1140.0, 2)
	_check(clock.current_phase == "dusk", "dusk phase boundary failed")
	clock.set_time(60.0, 3)
	_check(clock.current_phase == "night", "night phase boundary failed")
	_check(director.moon_disc.visible and director.star_field.visible, "moon or stars are hidden at night")
	_check(director.current_environment.ambient_light_energy >= 0.80, "night ambient energy is below the readability floor")
	_check(director.moon.light_energy >= 0.60, "moonlight is below the readability floor")
	_check(director.star_field.multimesh.visible_instance_count == 62, "Balanced star density is incorrect")
	var saved: Dictionary = clock.save_state()
	clock.set_time(800.0, 0)
	clock.load_state(saved)
	_check(is_equal_approx(clock.get_time(), 60.0) and clock.day_count == 3, "world time save/load roundtrip failed")
	clock.set_time(990.0, 0)

func _verify_greyfen(game: Node) -> void:
	var layer: Node = game.zone_root.find_child("AuthoredVisualLayer_Greyfen", true, false)
	_check(layer != null and bool(layer.get_meta("synthetic_visual_100_removed", false)), "synthetic visual layer was not replaced")
	_check(not _has_feature_marker(game.zone_root), "released Greyfen still contains Visual100 marker geometry")
	var house := _find_group_member(game.zone_root, "greyfen_house")
	_check(house != null, "Greyfen has no authored house")
	if house != null:
		for detail in ["StoneFoundation", "StoneChimney", "WindowShutter", "DoorStep"]:
			_check(house.find_child(detail, true, false) != null, "house detail missing: %s" % detail)
	var grass := game.zone_root.find_child("GrassBatch", true, false) as MultiMeshInstance3D
	_check(grass != null and grass.multimesh != null and grass.multimesh.mesh is QuadMesh, "grass is not a crossed-card MultiMesh batch")
	if grass != null:
		var material := grass.material_override as StandardMaterial3D
		_check(material != null and material.albedo_texture != null, "grass batch has no alpha texture")
	_check(_has_authored_surface(game.zone_root, false), "Greyfen contains no authored textured surface in Balanced mode")

func _verify_player_and_beam(game: Node) -> void:
	var player = game.player
	_check(_find_type(player, "Skeleton3D") != null, "Kael is not a skeletal character")
	for artifact in FORBIDDEN_ARTIFACTS:
		_check(player.find_child(artifact, true, false) == null, "floating character artifact remains: %s" % artifact)
	var anwen: Node = game.zone_root.find_child("sister_anwen", true, false)
	_check(anwen != null and _find_type(anwen, "Skeleton3D") != null, "Sister Anwen is not skeletal")
	if anwen != null:
		for artifact in FORBIDDEN_ARTIFACTS:
			_check(anwen.find_child(artifact, true, false) == null, "Anwen artifact remains: %s" % artifact)
	player.rotation = Vector3(0, 0.62, 0)
	var locked: Vector3 = player.call("_lock_beam_direction")
	player.rotation = Vector3(0, -1.20, 0)
	_check(locked.is_equal_approx(player.call("get_beam_locked_direction")), "Oathfire direction changes after camera/player rotation")
	player.call("cancel_beam_charge")
	_check((player.call("get_beam_locked_direction") as Vector3).is_zero_approx(), "Oathfire direction does not reset on cancellation")

func _verify_wychwood(game: Node) -> void:
	_check(game.active_enemies.size() == 5, "Wychwood does not contain the five-member encounter")
	for enemy in game.active_enemies:
		_check(_find_type(enemy, "Skeleton3D") != null, "%s is not skeletal" % enemy.enemy_id)
		_check(enemy.find_child("EnemyVariantSilhouette", true, false) == null, "%s still has box silhouette anatomy" % enemy.enemy_id)
		_check(_has_textured_mesh(enemy), "%s has no textured horror material" % enemy.enemy_id)
	_check(_has_authored_surface(game.zone_root, false), "Wychwood contains no authored textured surface in Balanced mode")
	_check(not _has_feature_marker(game.zone_root), "released Wychwood still contains Visual100 marker geometry")

func _has_feature_marker(node: Node) -> bool:
	if node.has_meta("feature_id") or str(node.name).begins_with("Visual100Feature"):
		return true
	for child in node.get_children():
		if _has_feature_marker(child): return true
	return false

func _has_authored_surface(node: Node, require_normal: bool) -> bool:
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and material.albedo_texture != null and (not require_normal or material.normal_texture != null):
			return true
	for child in node.get_children():
		if _has_authored_surface(child, require_normal): return true
	return false

func _has_textured_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and material.albedo_texture != null:
			return true
	for child in node.get_children():
		if _has_textured_mesh(child): return true
	return false

func _find_group_member(node: Node, group_name: String) -> Node:
	if node.is_in_group(group_name): return node
	for child in node.get_children():
		var found := _find_group_member(child, group_name)
		if found != null: return found
	return null

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null: return found
	return null

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if not failures.is_empty():
		print("VISUAL-003 VERIFIER: FAIL (%d)" % failures.size())
		quit(1)
		return
	print("VISUAL-003 VERIFIER: PASS")
	quit()
