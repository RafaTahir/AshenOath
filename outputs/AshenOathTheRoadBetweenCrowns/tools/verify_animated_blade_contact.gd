extends "res://tools/capture_anim_003.gd"

const Combat = preload("res://scripts/combat_manager.gd")
const MAX_GRIP_SEPARATION_METERS := 0.03

class Target extends Node3D:
	var dead := false
	var display_name := "Animated contact target"
	var received := 0.0
	func apply_damage(amount: float, _tag: String) -> void:
		received += amount

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	await _warm_renderer()
	var stage := _create_stage()
	var player := PlayerController.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.can_control = true
	var target := Target.new()
	target.position = Vector3(0, 0, -1.2)
	stage.add_child(target)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.7
	body.mesh = mesh
	body.position.y = 0.85
	target.add_child(body)
	var combat := Combat.new()
	stage.add_child(combat)
	player.blade_contact_requested.connect(func(contact):
		var result := combat.resolve_player_blade_contact(player, [target], contact, "")
		player.confirm_blade_contact(int(contact.attack_id), bool(result.hit))
		print("ANIMATED CONTACT ", JSON.stringify({"phase": contact.contact_phase, "hit": result.hit, "base": str(contact.base), "tip": str(contact.tip)}))
	)
	await _frames(12)
	var ap: AnimationPlayer = player.animation_driver.get_animation_player()
	for state in ["idle", "attack_light", "attack_heavy"]:
		var clip: StringName = player.animation_driver.get_clip_for_state(state)
		print("CLIP CONTRACT ", state, " clip=", clip, " seconds=", ap.get_animation(clip).length)
	print("SKELETON FRAME ", player.animation_driver.skeleton.global_transform)
	capture_camera.look_at_from_position(Vector3(3, 2, 3), Vector3(0, 1, -0.5))
	for blocked in [false, true]:
		if blocked:
			var wall := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(6, 3, 0.15)
			shape.shape = box
			wall.add_child(shape)
			wall.position = Vector3(0, 1.5, -0.5)
			stage.add_child(wall)
			await physics_frame
			await physics_frame
		for heavy in [false, true]:
			player.attack_anim_time = 0.0
			player.animation_driver.stop_action("idle", 0.0)
			for settle in range(30):
				player._animate_visuals(1.0 / 30.0, Vector3.ZERO, false)
				await process_frame
			player.attack_cooldown = 0.0
			var action := "heavy_attack" if heavy else "light_attack"
			Input.action_press(action)
			player._handle_combat_input()
			Input.action_release(action)
			var before := target.received
			var duration := 0.52 if heavy else 0.34
			for frame in range(1, int(ceil(duration * 30.0)) + 2):
				player.attack_anim_time = maxf(0.0, duration - frame / 30.0)
				player._animate_visuals(1.0 / 30.0, Vector3.ZERO, false)
				await process_frame
				player._update_blade_contact()
				if not blocked and frame in [3, 6, 9]:
					if not _verify_grip(player, action, frame):
						failures += 1
					if heavy and frame == 6:
						_print_weapon_geometry(player)
					await RenderingServer.frame_post_draw
					var path := "D:/Temp/AshenOath/blade_%s_%s_%s.png" % ["heavy" if heavy else "light", frame, int(Time.get_unix_time_from_system())]
					root.get_texture().get_image().save_png(path)
					print("BLADE FRAME ", path)
			var hit := target.received > before
			print("ANIMATED RESULT heavy=", heavy, " blocked=", blocked, " hit=", hit)
			if hit == blocked:
				failures += 1
	if player.asset_helper != null:
		player.asset_helper.clear_runtime_caches()
	stage.queue_free()
	await _frames(6)
	print("ANIMATED BLADE CONTACT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _verify_grip(player: Node, action: String, frame: int) -> bool:
	var attachment := player.sword_attachment as BoneAttachment3D
	var pivot := player.sword_equipment_pivot as Node3D
	var weapon := player.rig_sword_visual as Node3D
	var skeleton := attachment.get_parent() as Skeleton3D if attachment != null else null
	var grip_center := Vector3.ZERO
	if skeleton != null:
		grip_center = player.call("_sword_grip_center_world", skeleton)
	var hand_position := Vector3.ZERO
	if skeleton != null:
		var hand_index := skeleton.find_bone("hand_r")
		if hand_index >= 0:
			hand_position = (skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)).origin
	var separation := pivot.global_position.distance_to(grip_center) if pivot != null and skeleton != null else INF
	var result := {
		"action": action,
		"frame": frame,
		"attachment": str(attachment.global_position) if attachment != null else "missing",
		"pivot": str(pivot.global_position) if pivot != null else "missing",
		"weapon": str(weapon.global_position) if weapon != null else "missing",
		"finger_center": str(grip_center),
		"hand_bone": str(hand_position),
		"pivot_to_fingers": separation,
		"pivot_to_hand": pivot.global_position.distance_to(hand_position) if pivot != null else -1.0,
		"weapon_to_pivot": weapon.global_position.distance_to(pivot.global_position) if weapon != null and pivot != null else -1.0,
		"maximum_allowed": MAX_GRIP_SEPARATION_METERS,
		"passes": separation <= MAX_GRIP_SEPARATION_METERS,
	}
	print("GRIP DIAGNOSTIC ", JSON.stringify(result))
	if separation > MAX_GRIP_SEPARATION_METERS:
		push_error("Sword grip separated from fingers during %s frame %d: %.4f m" % [action, frame, separation])
		return false
	return true

func _print_weapon_geometry(player: Node) -> void:
	var records: Array[Dictionary] = []
	for raw_mesh in player.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var lower_name := str(mesh.name).to_lower()
		if not (lower_name.contains("oathblade") or lower_name.contains("sword") or lower_name.contains("slash")):
			continue
		records.append({
			"path": str(player.get_path_to(mesh)),
			"position": str(mesh.global_position),
			"world_bounds": str(mesh.global_transform * mesh.mesh.get_aabb()),
			"material": str(mesh.material_override.resource_name) if mesh.material_override != null else "",
		})
	print("WEAPON GEOMETRY ", JSON.stringify(records))
