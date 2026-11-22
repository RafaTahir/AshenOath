extends SceneTree

const Enemy = preload("res://scripts/enemy_ai.gd")
class Defender extends CharacterBody3D:
	var contacts := 0
	func take_damage(_amount: float) -> bool:
		contacts += 1
		return true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var target := Defender.new()
	stage.add_child(target)
	target.position.z = -1.2
	var enemy := Enemy.new()
	stage.add_child(enemy)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	enemy.setup("ghoulkin", definitions.ghoulkin, target)
	enemy.set_physics_process(false)
	var driver = enemy.animation_driver
	if driver == null or not driver.is_valid():
		stage.free()
		push_error("Current Ghoulkin runtime mapping cannot supply a valid attack rig")
		quit(1)
		return
	driver.set_external_tick(true)
	driver.set_update_rate_hz(30.0)
	var ap: AnimationPlayer = driver.get_animation_player()
	print("ENEMY AVAILABLE CLIPS ", ap.get_animation_list())
	var clip: StringName = driver.get_clip_for_state("windup")
	var length := ap.get_animation(clip).length
	if "--verify-contact" in OS.get_cmdline_user_args():
		var passed := true
		for rate in [12.0, 30.0]:
			for fps in [20.0, 30.0, 60.0]:
				driver.stop_action("idle", 0.0)
				driver.set_update_rate_hz(rate)
				enemy.stagger_time = 0.0
				enemy.windup_time = enemy._windup_duration()
				enemy.pending_attack_time = enemy.windup_time
				enemy._start_attack_animation()
				enemy.attack_trace_start = enemy._attack_contact_point()
				var before := target.contacts
				for frame in range(int(ceil(enemy.windup_time * fps))):
					enemy._tick_pending_attack(1.0 / fps)
				var hit: bool = target.contacts == before + 1
				passed = passed and hit and enemy.stagger_time > 0.0 and not driver.externally_ticked
				print("ENEMY MATRIX rate=", rate, " fps=", fps, " hit=", hit)
		enemy.windup_time = enemy._windup_duration()
		enemy._start_attack_animation()
		enemy.stagger()
		passed = passed and not driver.externally_ticked
		driver.stop_action("idle", 0.0)
		enemy._start_attack_animation()
		enemy.set_encounter_active(false)
		passed = passed and not driver.externally_ticked and driver.distance_suspended and enemy.pending_attack_time == 0.0
		driver.set_distance_suspended(false)
		driver.stop_action("idle", 0.0)
		enemy.windup_time = enemy._windup_duration()
		enemy._start_attack_animation()
		enemy._on_died()
		passed = passed and not driver.externally_ticked and is_equal_approx(driver.current_playback_scale, 1.0)
		enemy.asset_helper.clear_runtime_caches()
		stage.free()
		await process_frame
		print("ACTUAL ENEMY CONTACT: ", "PASS" if passed else "FAIL")
		quit(0 if passed else 1)
		return
	var skeleton: Skeleton3D = driver.get_skeleton()
	print("ENEMY TRANSFORMS actor=", enemy.global_transform, " skeleton=", skeleton.global_transform, " bone=", skeleton.get_bone_global_pose(enemy.attack_contact_bone), " rest=", skeleton.get_bone_global_rest(enemy.attack_contact_bone))
	for node in enemy.visual_root.find_children("*", "Node3D", true, false):
		if node is Skeleton3D or node is MeshInstance3D:
			print("ENEMY NODE ", node.get_path(), " transform=", node.global_transform)
	print("ENEMY CONTRACT ", JSON.stringify({"clip": clip, "seconds": length, "windup": enemy._windup_duration(), "bone": driver.skeleton.get_bone_name(enemy.attack_contact_bone), "offset": str(enemy.attack_contact_local_offset)}))
	driver.trigger_action("windup", 1.0, 0.0)
	var closest := INF
	var closest_time := 0.0
	var previous: Vector3 = enemy._attack_contact_point()
	for frame in range(1, int(ceil(length * 30.0)) + 1):
		driver.advance_external(1.0 / 30.0)
		var point: Vector3 = enemy._attack_contact_point()
		var contact: Vector3 = Geometry3D.get_closest_point_to_segment(target.position + Vector3.UP, previous, point)
		var distance := contact.distance_to(target.position + Vector3.UP)
		if distance < closest:
			closest = distance
			closest_time = frame / 30.0
		if frame % 3 == 0:
			print("ENEMY FRAME ", JSON.stringify({"seconds": frame / 30.0, "point": str(point), "distance": distance}))
		previous = point
	print("ENEMY CLOSEST ", JSON.stringify({"distance": closest, "seconds": closest_time, "radius": enemy.contact_radius}))
	enemy.asset_helper.clear_runtime_caches()
	stage.free()
	await process_frame
	print("ENEMY TIMELINE INSPECTION COMPLETE (diagnostic, not acceptance)")
	quit(0)
