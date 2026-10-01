extends SceneTree

const Enemy = preload("res://scripts/enemy_ai.gd")
var failures: Array[String] = []

class Defender extends CharacterBody3D:
	func take_damage(_damage: float) -> bool:
		return false

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id in ["rootbound_colossus", "ashwing", "white_hart_avatar"]:
		var player := Defender.new()
		root.add_child(player)
		var enemy := Enemy.new()
		root.add_child(enemy)
		enemy.setup(id, definitions[id], player)
		enemy.set_physics_process(false)
		if enemy.animation_driver == null or not enemy.animation_driver.is_valid():
			failures.append(id + " has no valid animation")
		else:
			enemy.animation_driver.set_external_tick(true)
			if id == "white_hart_avatar":
				var skeleton: Skeleton3D = enemy.animation_driver.get_skeleton()
				var head := skeleton.find_bone("Head")
				var head_position: Vector3 = enemy.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(head).origin) if head >= 0 else Vector3.ZERO
				print("HART HEAD FORWARD ", head_position)
				if head < 0 or head_position.z >= 0.0:
					failures.append("The retained Stag head faces away from gameplay -Z")
			var animation: AnimationPlayer = enemy.animation_driver.get_animation_player()
			var envelope := AABB()
			var initialized := false
			for state in ["idle", "windup", "attack", "hit", "death"]:
				var clip: StringName = enemy.animation_driver.get_clip_for_state(state)
				if not animation.has_animation(clip):
					failures.append(id + " is missing " + state)
					continue
				animation.play(clip)
				for sample in range(13):
					animation.seek(animation.get_animation(clip).length * sample / 12.0, true)
					animation.advance(0.0)
					var bounds_state := {"initialized": false, "bounds": AABB()}
					enemy._accumulate_visual_bounds(enemy.visual_root, Transform3D.IDENTITY, bounds_state)
					if not bounds_state.initialized:
						failures.append(id + " has no posed body bounds")
						continue
					var bounds: AABB = bounds_state.bounds
					envelope = envelope.merge(bounds) if initialized else bounds
					initialized = true
			print("ENCOUNTER ENVELOPE ", JSON.stringify({"id": id, "bounds": str(envelope), "top": envelope.end.y, "declared_height": enemy.get_meta("camera_subject_height", 0.0)}))
			var camera_bounds: AABB = enemy.get_meta("camera_subject_bounds", AABB())
			if camera_bounds.size == Vector3.ZERO or not camera_bounds.encloses(envelope):
				failures.append(id + " camera envelope excludes an authored motion pose")
			if id == "white_hart_avatar":
				enemy.position = Vector3(0, 0, -7.22)
				player.position = Vector3(0, 0, -6.05)
				await physics_frame
				await physics_frame
				enemy._physics_process(1.0 / 60.0)
				var to_player := player.position - enemy.position
				to_player.y = 0.0
				var facing := -enemy.basis.z
				if enemy.pending_attack_time <= 0.0 or facing.dot(to_player.normalized()) < 0.99:
					failures.append("Stationary close-spawn Hart begins its windup facing away from Kael")
			enemy.asset_helper.clear_runtime_caches()
		enemy.queue_free()
		player.queue_free()
		await process_frame
		await process_frame
	for failure in failures:
		push_error(failure)
	print("LARGE ENCOUNTER POSE CONTRACT: ", "PASS" if failures.is_empty() else "FAIL", " (geometry only, not graphical acceptance)")
	quit(0 if failures.is_empty() else 1)
