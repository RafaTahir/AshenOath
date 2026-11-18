extends SceneTree
## Real physics, EnemyAI capsule and ZoneSpatialService. No retained models,
## game campaign, renderer capture or filesystem save data are involved.
const Enemy = preload("res://scripts/enemy_ai.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")

class PlayerProbe extends CharacterBody3D:
	func take_damage(_amount: float) -> bool:
		return false

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING: errors.append("%s:%d %s %s" % [file,line,code,rationale])

var failures: Array[String] = []
var checks := 0
var error_log := ErrorLog.new()

func _initialize() -> void:
	OS.add_logger(error_log)
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(44,1,34)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var spatial := Spatial.new()
	world.add_child(spatial)
	spatial.configure("wychwood",0.0,Vector2(22,17))
	var player := PlayerProbe.new()
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.32
	player_capsule.height = 1.65
	player_shape.shape = player_capsule
	player_shape.position.y = 0.825
	player.add_child(player_shape)
	world.add_child(player)
	player.position = Vector3(-1,0,-5.5)
	spatial.set_player_body(player)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var enemy := Enemy.new(false)
	world.add_child(enemy)
	enemy.position = Vector3(-1,-0.072,-7.3)
	enemy.setup("wychwood_brute",definitions.wychwood_brute,player)
	enemy.set_physics_process(false)
	enemy.setup_navigation(spatial)
	enemy.can_see_player = true
	enemy.attack_cooldown = 0.0
	enemy.attack_recovery_time = 0.0
	await physics_frame
	await physics_frame
	var goal: Vector3 = enemy._engagement_target()
	_check(enemy.collision_layer==1,"Fixture uses the actual live default enemy collision layer")
	_check(spatial.is_position_occupied(goal,0.62*0.52,1.65),"Historical route endpoint overlaps its own actual enemy capsule")
	_check(not spatial._is_position_occupied_with_ignore(goal,0.62*0.52,1.65,enemy),"Ignoring only the caller removes self-occupancy")
	var unignored: Vector3 = spatial.validate_position(goal,0.62,spatial.bank_for(goal))
	var ignored: Vector3 = spatial.validate_position(goal,0.62,spatial.bank_for(goal),enemy)
	_check(unignored.distance_to(goal)>0.5,"Historical endpoint is projected away from the requested strike goal")
	_check(ignored.is_equal_approx(goal),"Actor-aware endpoint preserves the exact authored goal")
	var legacy_route: Array[Vector3] = spatial.build_route(enemy.global_position,goal,0.62)
	var actor_route: Array[Vector3] = spatial.build_route(enemy.global_position,goal,0.62,enemy)
	_check(not legacy_route.is_empty() and legacy_route.back().distance_to(goal)>0.5,"Default legacy caller behavior is retained")
	_check(not actor_route.is_empty() and actor_route.back().is_equal_approx(goal),"Actor route reaches its intended endpoint")
	_check(enemy._navigation_direction(goal,true).dot((goal-enemy.global_position).normalized())>0.95,"Actual enemy navigation points toward its strike goal")
	# A distinct live world obstacle must remain a blocker after self exclusion.
	var obstruction := StaticBody3D.new()
	var obstruction_shape := CollisionShape3D.new()
	var obstruction_box := BoxShape3D.new()
	obstruction_box.size = Vector3(0.3,2.0,0.3)
	obstruction_shape.shape = obstruction_box
	obstruction.add_child(obstruction_shape)
	obstruction.position = goal+Vector3.UP
	world.add_child(obstruction)
	await physics_frame
	await physics_frame
	_check(spatial._is_position_occupied_with_ignore(goal,0.62*0.52,1.65,enemy),"Other actual colliders are still obstacles")
	_check(spatial.validate_position(goal,0.62,spatial.bank_for(goal),enemy).distance_to(goal)>0.5,"Actor-aware validation does not pass through a real obstacle")
	obstruction.free()
	await physics_frame
	await physics_frame
	# Exercise normal EnemyAI fixed-tick pursuit with the real physics service.
	# Stop on windup: this fixture verifies navigation, not unrendered hand hits.
	enemy.position = Vector3(-1,-0.072,-10)
	enemy.home_position = enemy.global_position
	enemy.navigation_route.clear()
	enemy.navigation_refresh_time = 0.0
	enemy.navigation_target = Vector3.INF
	enemy.perception_refresh_time = 0.0
	enemy.set_physics_process(true)
	var first_tick := Engine.get_physics_frames()
	var hard_wall := Time.get_ticks_msec()+20000
	while enemy.pending_attack_time<=0.0 and Engine.get_physics_frames()-first_tick<240 and Time.get_ticks_msec()<hard_wall:
		await physics_frame
	enemy.set_physics_process(false)
	var physics_steps := Engine.get_physics_frames()-first_tick
	_check(enemy.pending_attack_time>0.0,"Actual straight Brute reaches windup without route oscillation")
	_check(enemy.player_contact_distance()<=enemy.attack_range*0.85,"Actual windup respects the retained decision radius")
	var evidence := {"goal":_v(goal),"legacy_projected_goal":_v(unignored),"actor_aware_goal":_v(ignored),
		"physics_steps_to_windup":physics_steps,"reached_distance":enemy.player_contact_distance()}
	world.free()
	await process_frame
	_check(error_log.errors.is_empty(),"No actual engine errors")
	print(JSON.stringify({"fixture":"enemy_route_self_occupancy","passed":failures.is_empty(),"checks":checks,
		"failures":failures,"engine_errors":error_log.errors,"evidence":evidence,
		"actual_physics":true,"actual_enemy_ai":true,"actual_spatial_service":true,
		"retained_visuals":false,"gameplay_acceptance":false,"save_data":false}))
	quit(0 if failures.is_empty() else 1)

func _v(point: Vector3) -> Array:
	return [point.x,point.y,point.z]
