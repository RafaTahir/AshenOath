extends SceneTree

const Enemy = preload("res://scripts/enemy_ai.gd")
var failures := 0
var releases := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = Enemy.new()
	var peer = Enemy.new()
	root.add_child(actor)
	root.add_child(peer)
	actor.set_physics_process(false)
	peer.set_physics_process(false)
	peer.position = Vector3(0.4, 0.0, 0.0)
	peer.add_to_group("enemies")
	check(actor._crowd_separation() == Vector3.ZERO, "Unregistered foreign actor must not enter an empty encounter")
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(2.0, 0.0, 0.0)
	actor.player = target
	check(actor._attack_lane_clear(), "Foreign actor must not reserve an unregistered encounter lane")
	actor.set_encounter_peers([actor, peer])
	check(actor._crowd_separation().x < -0.9, "Active nearby peer must affect separation")
	check(not actor._attack_lane_clear(), "Registered active peer must occupy the attack lane")
	actor.set_encounter_peers([])
	check(actor._crowd_separation() == Vector3.ZERO and actor._attack_lane_clear(), "Replacing the encounter list must discard stale peers")
	actor.set_encounter_peers([actor, peer])
	peer.set_encounter_active(false)
	check(actor._crowd_separation() == Vector3.ZERO, "Dormant peer must not affect separation")
	actor.attack_gate = func(_enemy, claim: bool) -> bool:
		if not claim:
			releases += 1
		return true
	check(actor._claim_attack_token(), "Test actor must claim a reservation")
	actor.pending_attack_time = 0.35
	actor.windup_time = 0.35
	actor.velocity = Vector3(2.0, 0.0, 0.0)
	actor.windup_marker = MeshInstance3D.new()
	actor.add_child(actor.windup_marker)
	actor.set_encounter_active(false)
	check(not actor.owns_attack_token and releases == 1, "Dormancy must release attack reservation")
	check(actor.pending_attack_time == 0.0 and actor.windup_time == 0.0, "Dormancy must cancel pending strike")
	check(actor.velocity == Vector3.ZERO, "Dormancy must clear movement")
	check(not actor.windup_marker.visible, "Dormancy must hide windup feedback")
	check(not actor.is_physics_processing(), "Dormant actor must stop physics ticks")
	actor.set_encounter_active(false)
	check(releases == 1, "Repeated dormancy must not release another actor's reservation")
	actor.free()
	peer.free()
	target.free()
	await process_frame
	print("ENEMY DORMANCY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
