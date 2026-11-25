extends SceneTree

const Life = preload("res://scripts/everyday_life.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")
const Catalog = preload("res://scripts/prepared_actor_catalog.gd")
const Response = preload("res://scripts/models/ecology_response.gd")
const Interactable = preload("res://scripts/interactable.gd")

class Observer extends Node3D:
	var velocity := Vector3.ZERO
	var can_control := true
	func is_on_floor() -> bool: return true

class Habitat extends Node3D:
	var player := Observer.new()
	var zone_root := Node3D.new()
	var game_started := true
	var zone_transition_pending := false
	var day_night: Node
	var combat := false
	func _story_has_active_combat() -> bool: return combat

var failures: Array[String] = []
var checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
	for sighting: Dictionary in data.sightings:
		_exercise(sighting, catalog.assets[sighting.design].path)
	if checked != 10: failures.append("Expected ten live sighting actors")
	print("ECOLOGY RESPONSE %s | %d prepared actors | %s" % ["PASS" if failures.is_empty() else "FAILED", checked, failures])
	quit(0 if failures.is_empty() else 1)

func _exercise(sighting: Dictionary, source: String) -> void:
	var habitat := Habitat.new()
	root.add_child(habitat)
	habitat.add_child(habitat.zone_root)
	habitat.add_child(habitat.player)
	var activities := Node.new()
	habitat.zone_root.add_child(activities)
	var owner := Life.new()
	owner.host = habitat
	activities.add_child(owner)
	owner.set_physics_process(false)
	var area := Interactable.new()
	area.setup("design_ecology:" + str(sighting.role), "story_activity", str(sighting.title))
	area.build_collision(1.45)
	area.set_meta("design_ecology", sighting)
	habitat.zone_root.add_child(area)
	area.rotation.y = deg_to_rad(float(sighting.yaw))
	var marker := area.global_transform
	var shape := area.get_child(0) as CollisionShape3D
	var collision_transform := shape.global_transform
	var prepared: Dictionary = Catalog.entry(sighting.role, source)
	var scene := load(str(prepared.path)) as PackedScene
	var visual := scene.instantiate() as Node3D
	area.add_child(visual)
	var offset: Array = sighting.get("visual_offset", [0, 0, 0])
	visual.position += Vector3(float(offset[0]), float(sighting.position[1]) + float(offset[1]), float(offset[2]))
	var home := visual.transform
	var driver := Driver.new()
	driver.name = "CharacterAnimationDriver"
	visual.add_child(driver)
	_check(driver.configure(visual, {"idle":sighting.clip, "walk":"Walking", "run":"Running", "hit":"HitReact", "death":"Death"}), sighting.role + " prepared rig binds")
	driver.set_external_tick(true)
	owner.register_ecology(area)
	var entry: Dictionary = owner.ecology[0]
	var motion: Response = entry.motion
	var profile: Dictionary = sighting.response
	habitat.player.global_position = area.to_global(home.origin + Vector3(8, 0, 0))
	_step(owner, driver, 0.35)
	_check(_playing(driver, str(sighting.ambient_clips[0])), sighting.role + " authored ambient clip")
	habitat.player.global_position = area.to_global(home.origin + Vector3(0.8, 0, 0))
	if profile.has("step_speed"):
		_step(owner, driver, 0.3)
		_check(motion.state != Response.State.ALERT, sighting.role + " ignores a silent observer")
	habitat.player.velocity = Vector3(1.7, 0, 0)
	_step(owner, driver, float(profile.commit) * 0.8)
	_check(motion.state == Response.State.ALERT and _playing(driver, str(profile.alert_clip)), sighting.role + " native alert response")
	_check(not visual.transform.is_equal_approx(home), sighting.role + " visible posture or displacement")
	_check(visual.position.distance_to(home.origin) <= 0.7, sighting.role + " remains in habitat")
	_check(area.global_transform == marker and area.interaction_enabled, sighting.role + " retains observation anchor")
	_check(shape.global_transform == collision_transform and is_equal_approx(shape.shape.radius, 1.45), sighting.role + " retains interaction collision")
	_step(owner, driver, float(profile.alert) - motion.elapsed + 0.3)
	_check(motion.state == Response.State.RETURN and _playing(driver, str(profile.return_clip)), sighting.role + " visible recovery")
	_step(owner, driver, float(profile.settle) + 0.2)
	_check(motion.state == Response.State.FIRST_ACTIVITY and visual.transform == home, sighting.role + " settles exactly once")
	habitat.player.global_position = area.to_global(home.origin + Vector3(18, 0, 0))
	_step(owner, driver, 0.1)
	_check(driver.distance_suspended and driver.observation_clip.is_empty(), sighting.role + " suspends at distance")
	habitat.player.global_position = area.to_global(home.origin + Vector3(-0.8, 0, 0))
	_step(owner, driver, 0.4)
	_check(motion.state == Response.State.ALERT and motion.side > 0.0, sighting.role + " resumes and reacts away from other side")
	habitat.combat = true
	_step(owner, driver, 1.0 / 60.0)
	_check(visual.transform == home and driver.observation_clip.is_empty(), sighting.role + " drops ambient on first combat frame")
	habitat.free()
	checked += 1

func _playing(driver: Node, name: String) -> bool:
	var sample: Dictionary = driver.observation_motion_sample()
	return str(sample.get("clip", "")).get_file().to_lower() == name.to_lower()

func _step(owner: Node, driver: Node, seconds: float) -> void:
	for frame in maxi(1, ceili(seconds * 60.0)):
		owner._physics_process(1.0 / 60.0)
		driver.advance_external(1.0 / 60.0)

func _check(ok: bool, description: String) -> void:
	if not ok: failures.append(description)
