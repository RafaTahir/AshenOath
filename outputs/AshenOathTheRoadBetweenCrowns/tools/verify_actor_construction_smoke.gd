extends SceneTree

## Actual ready/setup construction, sequentially, without a game or rendering.
## This catches dynamic typed-argument failures across the complete attachment
## path, rather than exercising only a controller forwarding stub.
const Player = preload("res://scripts/player_controller.gd")
const Enemy = preload("res://scripts/enemy_ai.gd")
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func _run() -> void:
	var world := Node3D.new()
	world.name = "ActorConstructionSmoke"
	root.add_child(world)
	var player = Player.new()
	player.set_physics_process(false)
	world.add_child(player) # Runs the real PlayerController._ready -> _build_body.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_check(player.health_component != null and player.stamina_component != null, "Player ready creates its real components")
	_check(player.body_visual != null and player.animation_driver != null and player.animation_driver.is_valid(), "Player ready constructs and binds its real retained body")
	_check(player.beam_left_hand_glow != null and player.beam_right_hand_glow != null, "Both Oathfire hands survive the full attachment path")
	_check(player.beam_left_hand_socket != null and player.beam_right_hand_socket != null, "Oathfire hands resolve actual retained skeleton aliases")
	_check(player.sheathed_sword_visual != null and not player.blade_scabbards.is_empty(), "Back swords construct through the typed spine alias boundary")
	_check(player.bow_visual != null and player.bow_attachment != null and player.bow_quiver_attachment != null, "Bow and quiver resolve actual typed hand/spine aliases")
	_check(player.bow_quiver_visual != null and player.equipment_loadout != null, "Player equipment construction reaches completion")
	_check(is_equal_approx(player.floor_snap_length, 0.34), "Player ready completes after body construction")
	rows.append({"identity": "player_kael", "ready_path": true, "body": player.body_visual != null,
		"hands": player.beam_left_hand_glow != null and player.beam_right_hand_glow != null,
		"back_sword": player.sheathed_sword_visual != null, "bow": player.bow_visual != null})
	print("ACTOR_CONSTRUCTION player attachment path complete")
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for identity: String in definitions:
		var actor = Enemy.new()
		actor.set_physics_process(false)
		world.add_child(actor)
		actor.setup(identity, definitions[identity], player) # Real setup/body/rig/equipment.
		actor.set_physics_process(false)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		_check(actor.body_visual != null, identity + ": real body constructed")
		_check(not bool(actor.visual_root.get_meta("enemy_visual_failure", false)), identity + ": no visual fallback failure")
		_check(actor.animation_driver != null and actor.animation_driver.is_valid(), identity + ": real animation graph configured")
		if actor.animation_driver != null:
			var visual_contract: Dictionary = actor.animation_driver.character_root.get_meta("character_visual_contract", {})
			_check(bool(visual_contract.get("valid", false)), identity + ": imported visual passed its declared bounds/skin contract")
		_check(actor.health_component != null and is_equal_approx(actor.health_component.max_health, float(definitions[identity].health)), identity + ": unchanged authored health")
		_check(is_equal_approx(actor.damage, float(definitions[identity].damage)) and is_equal_approx(actor.move_speed, float(definitions[identity].speed)), identity + ": unchanged authored damage and speed")
		if identity == "bandit":
			var spec: Dictionary = preload("res://scripts/character_role_spec.gd").for_role(identity)
			_check(is_equal_approx(float(spec.height), 1.72), "bandit: explicit existing default presentation height")
			_check(is_equal_approx(float(spec.collision_height), 1.65) and is_equal_approx(float(spec.collision_radius), 0.32), "bandit: default collision dimensions unchanged")
			_check(is_equal_approx(float(spec.lod), 14.0) and is_equal_approx(float(spec.visual_forward_degrees), 0.0), "bandit: default LOD and facing unchanged")
			var normalized_height: float = float(actor.animation_driver.character_root.get_meta("normalized_target_height", 0.0))
			_check(is_equal_approx(normalized_height, 1.72), "bandit: source no longer takes the 1.2m prop fallback")
			var body_shapes: Array[Node] = actor.find_children("*", "CollisionShape3D", true, false)
			_check(body_shapes.size() == 1, "bandit: one unchanged body collider")
			if body_shapes.size() == 1:
				var body: CollisionShape3D = body_shapes[0] as CollisionShape3D
				var capsule: CapsuleShape3D = body.shape as CapsuleShape3D
				_check(capsule != null and is_equal_approx(capsule.height, 1.65) and is_equal_approx(capsule.radius, 0.32), "bandit: actual installed capsule dimensions unchanged")
				_check(is_equal_approx(body.position.y, 0.8826), "bandit: actual collider centre/floor clearance unchanged")
		var native: bool = actor.animation_driver != null and str(actor.animation_driver.character_root.get_meta("character_animation_family", "")) == "design_pack_native"
		if native: _check(not actor.native_attack_profile.is_empty(), identity + ": existing native strike profile binds")
		rows.append({"identity": identity, "actual_setup": true, "body": actor.body_visual != null,
			"animation_valid": actor.animation_driver != null and actor.animation_driver.is_valid(),
			"native": native, "native_profile": not actor.native_attack_profile.is_empty()})
		print("ACTOR_CONSTRUCTION enemy=", identity, " body=", actor.body_visual != null)
		if actor.asset_helper != null: actor.asset_helper.clear_runtime_caches()
		actor.free()
	if player.asset_helper != null: player.asset_helper.clear_runtime_caches()
	world.free()
	await process_frame
	print(JSON.stringify({"fixture": "actor_construction_smoke", "passed": failures.is_empty(), "failures": failures,
		"actors": rows, "live_enemy_profiles": definitions.size(), "actual_player_ready": true,
		"gameplay": false, "render_capture": false, "save_data": false}))
	quit(0 if failures.is_empty() else 1)
