extends SceneTree
## Actual Player release -> Camera solution -> ArrowProjectile -> CombatManager.
## Geometry only, isolated inventory, no models, campaign or user-data writes.
const Player = preload("res://scripts/player_controller.gd")
const CameraRig = preload("res://scripts/camera_controller.gd")
const Projectile = preload("res://scripts/arrow_projectile.gd")
const Combat = preload("res://scripts/combat_manager.gd")
const BodyQuery = preload("res://scripts/combat_body_query.gd")
const RoleSpec = preload("res://scripts/character_role_spec.gd")
const LOW_ROLES := ["silt_maw", "millback", "glassmoth", "knell_leech", "hearthscale",
	"gallows_weaver", "reed_choir", "inkblind", "cairn_mother", "shroud_swimmer"]

class Controller extends Player:
	var fixture_origin := Vector3(0, 1.2, 0)
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func get_arrow_origin() -> Vector3:
		return global_transform * fixture_origin

class Inventory extends Node:
	var items := {"standard_arrow": 12}
	var consumed := 0
	func consume(id: String) -> void:
		items[id] -= 1
		consumed += 1

class Actor extends StaticBody3D:
	var dead := false
	var enemy_id := "release_fixture"
	var display_name := "Release fixture"
	var tag := "beast"
	var received := 0.0
	var hits := 0
	func is_encounter_active() -> bool: return true
	func apply_damage(amount: float, _source: String) -> void:
		received += amount
		hits += 1

class RangeOwner extends Node:
	func training_ready() -> bool: return true

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var checks := 0
var failures: Array[String] = []
var stage: Node3D
var player: Controller
var inventory: Inventory
var rig: Node3D
var combat: Node
var actors: Array = []
var requests: Array[Dictionary] = []
var results: Array[Dictionary] = []
var error_log := ErrorLog.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(error_log)
	stage = Node3D.new()
	root.add_child(stage)
	combat = Combat.new()
	stage.add_child(combat)
	player = Controller.new()
	stage.add_child(player)
	player.can_control = true
	player.equipment_loadout.active_weapon = "bow"
	player.equipment_loadout.bow_drawn = true
	inventory = Inventory.new()
	stage.add_child(inventory)
	player.inventory_ref = inventory
	rig = CameraRig.new()
	stage.add_child(rig)
	rig.setup(player)
	rig.set_process(false)
	rig.set_physics_process(false)
	player.camera_controller = rig
	rig.camera.global_position = Vector3(0, 2.2, 6.8)
	# Deliberately points at ground before the actor: a free crosshair solution
	# cannot accidentally satisfy the locked-body release assertions.
	rig.camera.look_at(Vector3(0, 0, -1), Vector3.UP)
	player.arrow_requested.connect(_on_arrow_requested)
	var floor_body := _box(Vector3(0, -0.15, -9), Vector3(40, 0.3, 40))
	await _sync()
	for role: String in LOW_ROLES:
		await _positive(role, false)
	await _positive("humanoid_capsule", true)
	await _wall_and_actor_cases()
	await _clearance_cases()
	await _free_and_training_cases()
	await _range_ammo_cancel_cases()
	_selector_compatibility()
	_check(floor_body.is_inside_tree(), "Tests retain actual world floor geometry")
	stage.free()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine/script errors: " + str(error_log.errors))
	for failure: String in failures: printerr(failure)
	print("LOCKED BOW RELEASE: %s checks=%d roles=%d (actual release/camera/projectile/combat, world and actor blockers, free/training, clearance/range/ammo/cancel)" % ["PASS" if failures.is_empty() else "FAIL", checks, LOW_ROLES.size() + 1])
	quit(0 if failures.is_empty() else 1)

func _sync() -> void:
	await physics_frame
	await physics_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _actor(role: String, capsule: bool, position := Vector3(0, 0, -6)) -> Actor:
	var actor := Actor.new()
	actor.enemy_id = role
	actor.collision_layer = 128
	actor.collision_mask = 0
	actor.position = position
	# Presentation bounds intentionally disagree with the real damage body.
	actor.set_meta("camera_subject_bounds", AABB(Vector3(-2, 0, -2), Vector3(4, 6, 4)))
	var collision := CollisionShape3D.new()
	if capsule:
		var shape := CapsuleShape3D.new()
		shape.height = 1.65
		shape.radius = 0.34
		collision.shape = shape
		collision.position.y = 0.9
	else:
		var spec := RoleSpec.for_role(role)
		var shape := CylinderShape3D.new()
		shape.height = float(spec.collision_height)
		shape.radius = float(spec.collision_radius)
		collision.shape = shape
		collision.position.y = shape.height * 0.5 + shape.radius * 0.18
	actor.add_child(collision)
	stage.add_child(actor)
	actors.append(actor)
	return actor

func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	stage.add_child(body)
	return body

func _prepare(actor: Actor, locked := true) -> void:
	requests.clear()
	results.clear()
	inventory.items.standard_arrow = 12
	inventory.consumed = 0
	player.training_range = null
	player.fixture_origin = Vector3(0, 1.2, 0)
	player.bow_aiming = true
	player.equipment_loadout.bow_aiming = true
	player.bow_pose_aim = 1.0
	player.bow_draw_time = player.get_bow_draw_duration()
	player.bow_recovery = 0.0
	rig.clear_target_lock()
	rig.set_enemy_candidates(actors)
	if locked: rig._set_locked_combat_target(actor)

func _on_arrow_requested(request: Dictionary) -> void:
	requests.append(request.duplicate(true))
	var projectile := Projectile.new()
	projectile.shot = request.duplicate(true)
	projectile.shot.damage = 28.0
	projectile.direction = request.direction
	projectile.remaining = float(request.range)
	projectile.position = request.origin
	projectile.combat = weakref(combat)
	projectile.excluded = [player.get_rid()]
	for actor: Actor in actors: projectile.enemies.append(weakref(actor))
	projectile.completed = func(result: Dictionary) -> void: results.append(result.duplicate())
	stage.add_child(projectile)

func _release_and_wait() -> void:
	player._release_bow()
	for _index in 100:
		if not results.is_empty() or requests.is_empty(): break
		await physics_frame

func _clean_actors() -> void:
	rig.clear_target_lock()
	for actor: Actor in actors: actor.free()
	actors.clear()
	await _sync()

func _positive(role: String, capsule: bool) -> void:
	var actor := _actor(role, capsule)
	await _sync()
	_prepare(actor)
	var point := BodyQuery.aim_point_for(actor)
	var origin := player.get_arrow_origin()
	var solution: Dictionary = rig.bow_aim_solution(origin, player.BOW_RANGE)
	_check(rig.get_locked_combat_target() == actor, role + " actual lock selected")
	_check(solution.direction.dot(origin.direction_to(point)) > 0.99999, role + " production solution aims at actual body centre")
	_check(solution.point.distance_to(point) < 0.0001 and not solution.blocked and not solution.obstructed, role + " intended target is not a near-face obstruction")
	_check(Player.locked_bow_aim_point(actor).is_equal_approx(point), role + " compatibility wrapper shares production selector")
	await _release_and_wait()
	_check(requests.size() == 1 and inventory.consumed == 1 and inventory.items.standard_arrow == 11, role + " actual release consumes exactly one arrow")
	_check(requests.size() == 1 and requests[0].direction.dot(origin.direction_to(point)) > 0.99999, role + " emitted trajectory uses locked body centre")
	_check(actor.hits == 1 and actor.received == 28.0 and not results.is_empty() and results[0].get("enemy") == actor, role + " actual projectile and resolver hit exactly once")
	_check(requests.size() == 1 and requests[0].range == player.BOW_RANGE and requests[0].width == 0.34, role + " range and attack width preserved")
	await _clean_actors()

func _wall_and_actor_cases() -> void:
	var actor := _actor("shroud_swimmer", false)
	var wall := _box(Vector3(0, 1.2, -3), Vector3(1.8, 3, 0.2))
	await _sync()
	# Acquire before the wall is inserted conceptually; real locks retain their
	# obstruction grace, so exercise that retained selected target directly.
	_prepare(actor, false)
	rig._locked_combat_target = actor
	await _release_and_wait()
	_check(requests.size() == 1 and inventory.consumed == 1, "Distant wall still permits an ordinary shot")
	_check(actor.hits == 0 and not results.is_empty() and results[0].get("kind") == "scenery", "Actual projectile stops at world wall before low body")
	wall.free()
	await _clean_actors()
	actor = _actor("humanoid_capsule", true)
	var intervening := _actor("intervening", true, Vector3(0, 0, -3))
	await _sync()
	_prepare(actor, false)
	rig._locked_combat_target = actor
	await _release_and_wait()
	_check(actor.hits == 0 and intervening.hits == 1, "Other actors remain occluders and receive the projectile first")
	_check(not results.is_empty() and results[0].get("enemy") == intervening, "Actual resolver selects intervening actor")
	await _clean_actors()

func _clearance_cases() -> void:
	var actor := _actor("humanoid_capsule", true)
	# Keep this wall off the camera ray but within 0.55 m of the actual
	# off-shoulder muzzle ray, so it exercises the existing short-block check.
	var wall := _box(Vector3(0.65, 1.2, -0.25), Vector3(0.25, 1, 0.1))
	await _sync()
	_prepare(actor, false)
	rig._locked_combat_target = actor
	player.fixture_origin = Vector3(0.7, 1.2, 0)
	await _release_and_wait()
	_check(requests.is_empty() and inventory.consumed == 0, "Very short world muzzle block suppresses release and ammo use")
	wall.free()
	await _sync()
	_prepare(actor, false)
	rig._locked_combat_target = actor
	wall = _box(Vector3(0, 1.6, 2), Vector3(1, 3, 0.2))
	await _sync()
	await _release_and_wait()
	_check(requests.is_empty() and inventory.consumed == 0, "World camera clipping behind the muzzle retains the front-direction guard")
	wall.free()
	await _sync()
	_prepare(actor)
	player.fixture_origin = Vector3(0.7, 1.2, 0)
	wall = _box(Vector3(0.35, 1.45, 0), Vector3(0.10, 0.9, 0.5))
	await _sync()
	await _release_and_wait()
	_check(requests.is_empty() and inventory.consumed == 0, "Eye-to-muzzle world clearance remains mandatory")
	wall.free()
	# A large intended body can cross eye-to-muzzle while its centre is still
	# in front. It must be excluded from aiming rays, not this clearance ray.
	actor.position = Vector3(0.9, 0, -0.4)
	actor.collision_layer = 1
	var collider: CollisionShape3D = actor.get_child(0)
	var large := CapsuleShape3D.new()
	large.height = 2.0
	large.radius = 0.9
	collider.shape = large
	collider.position.y = 1.0
	await _sync()
	_prepare(actor)
	player.fixture_origin = Vector3(0.7, 1.2, 0)
	await _release_and_wait()
	_check(requests.is_empty() and inventory.consumed == 0, "Intended target exclusion never leaks into eye-to-muzzle clearance")
	await _clean_actors()

func _free_and_training_cases() -> void:
	var actor := _actor("shroud_swimmer", false)
	await _sync()
	_prepare(actor, false)
	var origin := player.get_arrow_origin()
	var free: Dictionary = rig.bow_aim_solution(origin, player.BOW_RANGE)
	var explicit_free: Dictionary = rig.bow_aim_solution(origin, player.BOW_RANGE, false)
	_check(free.direction.is_equal_approx(explicit_free.direction) and free.point.is_equal_approx(explicit_free.point), "Existing two-argument free aim remains identical")
	await _release_and_wait()
	_check(requests.size() == 1 and requests[0].direction.is_equal_approx(free.direction) and actor.hits == 0, "Actual unlocked release retains crosshair aim rather than auto-targeting")
	_prepare(actor)
	var owner := RangeOwner.new()
	stage.add_child(owner)
	player.training_range = weakref(owner)
	_check(rig.bow_aim_solution(origin, player.BOW_RANGE).direction.is_equal_approx(explicit_free.direction), "Actual active training bypasses locked-target assistance")
	_check(rig.training_aim_direction(origin).is_equal_approx(explicit_free.direction), "Training wrapper retains free aim")
	await _release_and_wait()
	_check(requests.size() == 1 and requests[0].training and inventory.consumed == 0 and actor.hits == 0, "Actual training release preserves ammo and free trajectory")
	player.training_range = null
	owner.free()
	await _clean_actors()

func _selector_compatibility() -> void:
	var actor := Node3D.new()
	actor.position = Vector3(2, 3, -4)
	actor.rotation.y = 0.4
	actor.scale = Vector3(1.2, 0.8, 1.4)
	actor.set_meta("camera_subject_bounds", AABB(Vector3(-1, 0, -1), Vector3(2, 3, 2)))
	stage.add_child(actor)
	var expected: Vector3 = actor.global_transform * Vector3(0, 1.5, 0)
	_check(BodyQuery.aim_point_for(actor).is_equal_approx(expected), "Bounds fallback retains actual global transform")
	var disabled := CollisionShape3D.new()
	disabled.shape = CylinderShape3D.new()
	disabled.position.y = 9
	disabled.disabled = true
	actor.add_child(disabled)
	var enabled := CollisionShape3D.new()
	enabled.shape = CapsuleShape3D.new()
	enabled.position.y = 0.75
	actor.add_child(enabled)
	_check(BodyQuery.aim_point_for(actor).is_equal_approx(enabled.global_position), "Disabled design helpers never replace the enabled body centre")
	actor.free()

func _range_ammo_cancel_cases() -> void:
	var actor := _actor("humanoid_capsule", true)
	await _sync()
	_prepare(actor)
	var solution: Dictionary = rig.bow_aim_solution(player.get_arrow_origin(), 2.0)
	_check(solution.point.distance_to(player.get_arrow_origin()) <= 2.0001, "Locked solution retains caller range clamp")
	inventory.items.standard_arrow = 0
	await _release_and_wait()
	_check(requests.is_empty() and inventory.consumed == 0, "Empty inventory never emits a projectile")
	_prepare(actor)
	player._cancel_bow()
	_check(not player.bow_aiming and player.bow_draw_time == 0.0 and requests.is_empty() and inventory.consumed == 0, "Cancel clears draw without consuming or releasing")
	await _clean_actors()
