extends SceneTree
## Geometry-only production combat queries: no models, campaign or user saves.
const Combat = preload("res://scripts/combat_manager.gd")
const BodyQuery = preload("res://scripts/combat_body_query.gd")
const Player = preload("res://scripts/player_controller.gd")
const RoleSpec = preload("res://scripts/character_role_spec.gd")
const LOW_ROLES := ["silt_maw", "millback", "glassmoth", "knell_leech", "hearthscale",
	"gallows_weaver", "reed_choir", "inkblind", "cairn_mother", "shroud_swimmer"]

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class Controller extends Player:
	func _ready() -> void:
		set_physics_process(false)
		set_process(false)

class Target extends StaticBody3D:
	var dead := false
	var display_name := "Cylinder fixture"
	var enemy_id := ""
	var tag := "beast"
	var received := 0.0
	var hits := 0
	func apply_damage(amount: float, _source: String) -> void:
		received += amount
		hits += 1

var failures: Array[String] = []
var checks := 0
var attack_id := 0
var stage: Node3D
var player: Controller
var combat: Node
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
	player.equipment_loadout.set_sword_drawn(true)
	player.blade_base_marker = Marker3D.new()
	player.blade_tip_marker = Marker3D.new()
	player.add_child(player.blade_base_marker)
	player.add_child(player.blade_tip_marker)
	await physics_frame
	for id: String in LOW_ROLES:
		_verify_role(id)
	_verify_transformed_body()
	_verify_capsule_compatibility()
	await _verify_occlusion_and_single_hit()
	stage.free()
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine or script errors during geometry verification")
	print("CYLINDER COMBAT: %s checks=%d roles=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, LOW_ROLES.size()])
	quit(0 if failures.is_empty() else 1)

func _target(id: String) -> Target:
	var actor := Target.new()
	actor.enemy_id = id
	actor.collision_layer = 2
	actor.collision_mask = 0
	var definition := RoleSpec.for_role(id)
	var shape := CylinderShape3D.new()
	shape.height = float(definition.collision_height)
	shape.radius = float(definition.collision_radius)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5 + shape.radius * 0.18
	actor.add_child(collider)
	stage.add_child(actor)
	actor.position = Vector3(0, 0, -4)
	return actor

func _shot(actor: Node3D, y: float, x: float = 0.0, width: float = 0.34, endpoint_z: float = -8.0) -> Dictionary:
	return combat.resolve_arrow_shot([actor], {"origin": Vector3(x, y, 0), "endpoint": Vector3(x, y, endpoint_z),
		"direction": Vector3.FORWARD, "width": width, "damage": 10.0, "report_miss": false})

func _beam(actor: Node3D, y: float, x: float = 0.0, width: float = 0.25, endpoint_z: float = -8.0) -> Array:
	return combat.resolve_oathfire_cast([actor], {"origin": Vector3(x, y, 0), "endpoint": Vector3(x, y, endpoint_z),
		"direction": Vector3.FORWARD, "width": width, "damage": 10.0})

func _contact(y: float) -> Dictionary:
	attack_id += 1
	return {"attack_id": attack_id, "blade_id": "steel", "damage": 10.0, "reach": 2.0,
		"base": Vector3(0.4, y, -0.9), "tip": Vector3(0.4, y, -2.0),
		"previous_base": Vector3(-0.4, y, -0.9), "previous_tip": Vector3(-0.4, y, -2.0)}

func _verify_role(id: String) -> void:
	var actor := _target(id)
	var collider := BodyQuery.cylinder_for(actor)
	var shape: CylinderShape3D = collider.shape
	_check(shape.height < 2.0 * shape.radius, id + ": fixture uses the low-body policy")
	var center := collider.global_position
	_check(Player.locked_bow_aim_point(actor).is_equal_approx(center), id + ": bow aims at actual cylinder center")
	_check(bool(_shot(actor, center.y).hit), id + ": body-height arrow hits")
	_check(not bool(_shot(actor, center.y + shape.height * 0.5 + 0.39).hit), id + ": arrow above finite cap plus width misses")
	_check(_beam(actor, center.y).size() == 1, id + ": body-height beam hits once")
	_check(_beam(actor, center.y + shape.height * 0.5 + 0.30).is_empty(), id + ": beam above finite cap plus width misses")
	_check(_beam(actor, center.y, shape.radius + 0.24).size() == 1, id + ": existing beam width reaches beside body")
	_check(_beam(actor, center.y, shape.radius + 0.26).is_empty(), id + ": beam does not exceed its width")
	_check(not bool(_shot(actor, center.y, 0.0, 0.34, -2.0).hit), id + ": arrow cannot extend past an occluded endpoint")
	_check(_beam(actor, center.y, 0.0, 0.25, -2.0).is_empty(), id + ": beam cannot extend past an occluded endpoint")
	actor.position.z = -1.5
	var body_hit: Dictionary = combat.resolve_player_blade_contact(player, [actor], _contact(center.y), "")
	_check(bool(body_hit.hit), id + ": swept blade hits actual finite body")
	var overhead: Dictionary = combat.resolve_player_blade_contact(player, [actor], _contact(center.y + shape.height * 0.5 + 0.71), "")
	_check(not bool(overhead.hit), id + ": melee does not invent humanoid-height body samples")
	actor.free()

func _verify_transformed_body() -> void:
	var actor := _target("shroud_swimmer")
	var collider := BodyQuery.cylinder_for(actor)
	collider.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.45, -0.15)) * Basis.from_scale(Vector3(1.7, 0.8, 0.6)), Vector3(0.3, 1.2, -0.4))
	var shape: CylinderShape3D = collider.shape
	var t := collider.global_transform
	_check(not BodyQuery.segment_hit(collider, t * Vector3(0, 0, 3), t * Vector3(0, 0, -3), 0.0).is_empty(), "Rotated nonuniform global basis hits actual body")
	_check(BodyQuery.segment_hit(collider, t * Vector3(0, shape.height * 0.5 + 0.01, 3), t * Vector3(0, shape.height * 0.5 + 0.01, -3), 0.0).is_empty(), "Rotated finite cap stays finite")
	var above := shape.height * 0.5 + 0.20 / 0.8 + 0.01
	_check(BodyQuery.segment_hit(collider, t * Vector3(0, above, 3), t * Vector3(0, above, -3), 0.20).is_empty(), "Global Y scale converts only the attack width")
	var within := shape.radius + 0.20 / 1.7 - 0.01
	_check(not BodyQuery.segment_hit(collider, t * Vector3(within, 0, 3), t * Vector3(within, 0, -3), 0.20).is_empty(), "Nonuniform basis retains a true world-width radial graze")
	var outside := shape.radius + 0.20 / 1.7 + 0.01
	_check(BodyQuery.segment_hit(collider, t * Vector3(outside, 0, 3), t * Vector3(outside, 0, -3), 0.20).is_empty(), "Nonuniform basis cannot exceed the true world attack width")
	_check(Player.locked_bow_aim_point(actor).is_equal_approx(collider.global_position), "Bow aim follows translated/rotated collider")
	collider.disabled = true
	_check(BodyQuery.cylinder_for(actor) == null, "Disabled cylinders are excluded from body queries")
	actor.free()

func _verify_capsule_compatibility() -> void:
	var actor := Target.new()
	actor.collision_layer = 2
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.35
	collider.shape = shape
	collider.position.y = 1.0
	actor.add_child(collider)
	stage.add_child(actor)
	actor.position.z = -4
	_check(BodyQuery.cylinder_for(actor) == null, "Humanoids retain capsule path")
	_check(Player.locked_bow_aim_point(actor).is_equal_approx(collider.global_position), "Capsule bow aim unchanged")
	_check(bool(_shot(actor, 1.0).hit), "Capsule arrow hit unchanged")
	_check(not bool(_shot(actor, 3.0).hit), "Capsule arrow miss unchanged")
	_check(_beam(actor, 1.0).size() == 1, "Capsule beam unchanged")
	actor.position.z = -1.5
	_check(bool(combat.resolve_player_blade_contact(player, [actor], _contact(0.72), "").hit), "Humanoid melee reach unchanged")
	actor.free()

func _verify_occlusion_and_single_hit() -> void:
	var near := _target("shroud_swimmer")
	var far := _target("shroud_swimmer")
	near.position.z = -3
	far.position.z = -5
	var y := BodyQuery.cylinder_for(near).global_position.y
	var shot: Dictionary = combat.resolve_arrow_shot([far, near], {"origin": Vector3(0, y, 0), "endpoint": Vector3(0, y, -8),
		"direction": Vector3.FORWARD, "width": 0.34, "damage": 10.0})
	_check(shot.get("enemy") == near and near.hits == 1 and far.hits == 0, "Arrow chooses one nearest cylinder despite candidate order")
	near.position.z = -1.5
	var contact := _contact(y)
	_check(bool(combat.resolve_player_blade_contact(player, [near], contact, "").hit), "Cylinder melee first contact hits")
	_check(not bool(combat.resolve_player_blade_contact(player, [near], contact, "").hit), "Cylinder melee cannot hit twice per attack")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	collider.shape = box
	wall.add_child(collider)
	stage.add_child(wall)
	wall.position = Vector3(0, 1, -0.7)
	await physics_frame
	await physics_frame
	var result: Dictionary = combat.resolve_player_blade_contact(player, [near], _contact(y), "")
	_check(result.get("enemy") != near, "Melee wall occlusion remains authoritative")
	wall.free()
	near.free()
	far.free()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
