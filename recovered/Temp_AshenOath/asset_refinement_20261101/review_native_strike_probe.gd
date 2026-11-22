extends SceneTree
class ProbePlayer extends Node3D:
	var received := 0.0
	func take_damage(amount: float) -> bool:
		received += amount
		return false
class ProbeEnemy extends "res://scripts/enemy_ai.gd":
	func _attack_contact_point() -> Vector3:
		return player.global_position + Vector3.UP
	func _has_attack_line() -> bool:
		return true
	func _boss_attack_id() -> String:
		return ""
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var target := ProbePlayer.new()
	root.add_child(target)
	target.position = Vector3(0,0,-.5)
	var actor := ProbeEnemy.new()
	actor.enemy_id = "ghoulkin"
	actor.player = target
	actor.set_physics_process(false)
	root.add_child(actor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Head")
	actor.add_child(skeleton)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	for name: String in ["Idle","Windup","Attack"]:
		var clip := Animation.new()
		clip.length = .5416666816 if name == "Windup" else (1.8333333333 if name == "Attack" else 1.0)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Skeleton3D:Head"))
		clip.rotation_track_insert_key(track,0.0,Quaternion.IDENTITY)
		clip.rotation_track_insert_key(track,clip.length,Quaternion(Vector3.RIGHT,.6 if name == "Attack" else .1))
		library.add_animation(name,clip)
	player.add_animation_library("",library)
	var driver := preload("res://scripts/character_animation_driver.gd").new()
	actor.add_child(driver)
	assert(driver.configure(actor,{"idle":"Idle","windup":"Windup","attack":"Attack"}))
	actor.animation_driver = driver
	var actions: Array[String] = []
	driver.action_started.connect(func(action): actions.append(action))
	actor.windup_time = .46
	actor.pending_attack_time = .46
	actor.attack_windup_total = .46
	actor.attack_trace_start = Vector3(0,.9,0)
	actor._start_attack_animation()
	actor._tick_pending_attack(.46)
	var state_at_damage := driver.current_state
	driver.set_external_tick(true)
	driver.advance_external(.2)
	print("NATIVE STRIKE REVIEW ",JSON.stringify({"actions":actions,"damage":target.received,"state_at_damage":state_at_damage,"state_after_windup":driver.current_state,"configured_attack_clip":str(driver.get_clip_for_state("attack"))}))
	actor.free()
	target.free()
	quit()