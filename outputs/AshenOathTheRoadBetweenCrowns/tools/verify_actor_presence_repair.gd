extends SceneTree

const Game = preload("res://scripts/game.gd")
const Enemy = preload("res://scripts/enemy_ai.gd")
const Catalog = preload("res://scripts/saga_catalog.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const OUTPUT := "D:/Temp/AshenOath/actor-presence-repair"
var failures: Array[String] = []
var checked := 0
var game
var camera: Camera3D

class Fixture extends Game:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
	func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
		var actor := Enemy.new()
		actor.visual_role_override = visual_role
		zone_root.add_child(actor)
		actor.position = Vector3(pos.x, 0, pos.z)
		actor.setup(id, enemy_defs.get(id, {}), player)
		actor.set_physics_process(false)
		active_enemies.append(actor)
		return actor

class Settings extends Node:
	var settings := {"quality_preset":"balanced"}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	game = Fixture.new()
	root.add_child(game)
	game.shared_box_mesh = BoxMesh.new()
	game.asset_helper = load("res://scripts/asset_spawn_helper.gd").new()
	game.add_child(game.asset_helper)
	game.story_state = load("res://scripts/story_state.gd").new()
	game.add_child(game.story_state)
	game.settings = Settings.new()
	game.add_child(game.settings)
	game.quests = load("res://scripts/quest_manager.gd").new()
	game.add_child(game.quests)
	game.quests.load_quests("res://data/quests.json")
	game.quests.start_quest("main_road_of_crows")
	game.interaction_focus = load("res://scripts/interaction_focus_service.gd").new()
	game.add_child(game.interaction_focus)
	game.player = CharacterBody3D.new()
	game.add_child(game.player)
	game.player.position = Vector3(0, 0, 6)
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	game.enemy_defs = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("253d3d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	game.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	game.add_child(light)
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	var named := ["sister_anwen", "mira", "rook", "widow_elna", "blacksmith_tor", "farmer_toma", "returned_soldier", "edric", "vargan_gate_guard", "vargan_record_keeper", "vargan_steward", "vargan_servant", "vargan_patrol", "edric_castle", "edric_campaign", "captain_senn", "halvern", "witness_-7", "witness_-3", "witness_3"]
	for id: String in named:
		game.current_zone_id = "record_hall" if id.begins_with("vargan") or id.begins_with("edric_") else "greyfen"
		var actor: Node3D = game._make_named_interactable(id, "dialogue", "Speak with " + id, Vector3.ZERO, Color.WHITE)
		await _inspect(actor, id, true)
		if actor != null: actor.free()
	var saga = load("res://scripts/saga_activities.gd").new()
	saga.host = game
	game.add_child(saga)
	for id: String in Catalog.PEOPLE:
		var person: Dictionary = Catalog.PEOPLE[id]
		# Dain is the retained mill worker, checked through that same role below.
		if bool(person.get("alias", false)): continue
		game.current_zone_id = str(person.zone)
		var area = load("res://scripts/interactable.gd").new()
		game.zone_root.add_child(area)
		area.setup(id, "story_activity", "Speak with " + str(person.name))
		area.build_collision()
		saga._add_person(area, person, id)
		game._connect_interactable(area)
		await _inspect(area, id, true)
		area.free()
	for role: String in ["player_human", "villager_human", "villager_female_human", "villager_worker_human", "villager_hooded_human", "castle_guard_human", "road_ranger_human"]:
		var actor: Node3D = game.asset_helper.spawn_visual_role(role, "characters")
		if actor != null: game.zone_root.add_child(actor)
		await _inspect(actor, role, false)
		if actor != null: actor.free()
	game.current_zone_id = "wychwood"
	var section = load("res://scripts/zones/wychwood_section.gd").new()
	section._build_gameplay_content(ZoneBuildContext.new(game, "wychwood"))
	_check(game.active_enemies.size() == 5, "Fresh Wychwood must construct all five encounter members")
	for actor in game.active_enemies:
		var wave := int(actor.get_meta("wychwood_wave", -1))
		_check(actor.visible == (wave == 0), "Only the earned current wave must be visible on arrival")
		actor.set_encounter_active(true)
		actor.set_physics_process(false)
		actor.position = Vector3.ZERO
		await _inspect(actor, str(actor.enemy_id), false)
		actor.visible = false
	for actor in game.active_enemies: actor.free()
	game.active_enemies.clear()
	for area in game.zone_root.get_children(): area.free()
	game.interaction_area_cache.clear()
	for id: String in ["bog_wretch", "bell_eater", "rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"]:
		var actor := Enemy.new()
		game.zone_root.add_child(actor)
		actor.setup(id, game.enemy_defs[id], game.player)
		actor.set_physics_process(false)
		await _inspect(actor, id, false)
		_check(actor.animation_driver != null and actor.animation_driver.is_valid(), id + " animation failed")
		actor.asset_helper.clear_runtime_caches()
		actor.free()
	game.current_zone_id = "hart_glade"
	var witness: Node3D = Presentation.make_hart_witness(game.asset_helper, Vector3.ZERO)
	if witness != null: game.zone_root.add_child(witness)
	var interaction: Node3D = game._make_named_interactable("white_hart", "dialogue", "Stand before the White Hart", Vector3.ZERO, Color.WHITE)
	await _inspect(witness, "WhiteHartWitnessDisplay", false)
	_check(interaction != null and interaction.is_interaction_enabled(), "Hart dialogue anchor must be available")
	_check(game.zone_root.find_children("WhiteHartWitnessDisplay", "Node3D", true, false).size() == 1, "Hart interaction must not duplicate the stag")
	game.asset_helper.clear_runtime_caches()
	game.game_started = false
	game.queue_free()
	for index in 8: await process_frame
	print("ACTOR PRESENCE REPAIR: %s checked=%d failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checked, failures])
	quit(0 if failures.is_empty() else 1)

func _inspect(actor: Node3D, id: String, interaction: bool) -> void:
	checked += 1
	_check(actor != null, id + " did not instantiate")
	if actor == null: return
	actor.position = Vector3.ZERO
	camera.position = Vector3(4, 2.7, -6)
	camera.look_at(Vector3(0, 1.45, 0))
	if interaction:
		game.player.position = Vector3(0, 0, -2)
		_check(actor.is_interaction_enabled(), id + " interaction disabled")
		_check(not actor.find_children("*", "CollisionShape3D", true, false).is_empty(), id + " has no interaction shape")
		_check(actor in game.interaction_focus.nearby(game.player.position, game.zone_root), id + " absent from interaction index")
	var bodies := 0
	var bounds := AABB()
	var initialized := false
	for raw_mesh in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		# Ranger's duplicate hood and role-specific held equipment intentionally
		# remain hidden. Require a visible complete body, not every optional mesh.
		if mesh.skin == null or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		bodies += 1
		_check(mesh.get_node_or_null(mesh.skeleton) is Skeleton3D, id + " skin has no live skeleton")
		for surface in mesh.mesh.get_surface_count():
			_check(mesh.get_active_material(surface) != null, id + " missing surface material")
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if not initialized else bounds.merge(box)
		initialized = true
	_check(bodies > 0 and bounds.size.y > 0.9, id + " missing complete body")
	_check(not bool(actor.get_meta("enemy_visual_failure", false)), id + " failed enemy visual")
	for index in 3: await process_frame
	await RenderingServer.frame_post_draw
	if id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "white_hart_avatar", "WhiteHartWitnessDisplay"]:
		root.get_texture().get_image().save_png(OUTPUT.path_join(id + ".png"))
	print("ACTOR_PRESENCE ", JSON.stringify({"id":id, "bodies":bodies, "bounds":str(bounds), "interaction":interaction}))

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
