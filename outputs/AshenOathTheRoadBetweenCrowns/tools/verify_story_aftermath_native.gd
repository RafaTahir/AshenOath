extends "res://tools/verify_story_alternative_native.gd"

func _fight_senn_guard(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--actor-presence-only"):
		await _check_reloaded_choice(game, "senn_fate", _presence_outcome("senn"), "main_soldier_without_banner", "main_blood_under_stone")
	else:
		await super._fight_senn_guard(game)
	await _check_departed_actor(game, "captain_senn", "senn_fate")

func _resolve_halvern_witness(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--actor-presence-only"):
		await _check_reloaded_choice(game, "halvern_fate", _presence_outcome("halvern"), "main_last_witness", "main_crowns_without_mercy")
	else:
		await super._resolve_halvern_witness(game)
	await _check_departed_actor(game, "halvern", "halvern_fate")

func _presence_outcome(group: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s-" % group):
			return argument.trim_prefix("--%s-" % group)
	return ""

func _check_departed_actor(game: Node, actor_id: String, flag: String) -> void:
	if not failures.is_empty():
		return
	await _resume_saved_route(game)
	await _frames(3)
	var actor: Node = game.zone_root.find_child(actor_id, true, false)
	var expect_present := OS.get_cmdline_user_args().has("--expect-present")
	if expect_present and (actor == null or not actor is Node3D or not actor.is_visible_in_tree() or actor.find_children("*", "Skeleton3D", true, false).is_empty()):
		_fail("Retained %s witness lost its visible skeletal body" % actor_id)
		return
	if not expect_present and (actor != null or (is_instance_valid(game.active_interactable) and game.active_interactable.interaction_id == actor_id)):
		_fail("Resolved %s remained alive/focusable after its actual choice or Continue" % actor_id)
		return
	var camera := game.get_viewport().get_camera_3d()
	var target: Vector3 = Vector3(8.7, 0, -1.2) if actor_id == "captain_senn" else Vector3(0, 0, -9)
	var direction: Vector3 = target - game.player.global_position
	direction.y = 0.0
	var desired_yaw := atan2(-direction.x, -direction.z)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(wrapf(float(game.camera_rig.yaw) - desired_yaw, -PI, PI) / float(game.camera_rig.sensitivity), 0.0)
	Input.parse_input_event(motion)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://aftermath_%s_%s.png" % [actor_id, str(game.story_state.get_flag(flag, ""))]
	if camera == null or image == null or image.get_size() != Vector2i(1280, 720) or image.save_png(path) != OK:
		_fail("Actual gameplay-camera aftermath evidence could not be saved")
	else:
		print("REAL_INPUT actor_presence=PASS id=%s outcome=%s present=%s capture=%s actual_gameplay_camera=true" % [actor_id, game.story_state.get_flag(flag, ""), expect_present, ProjectSettings.globalize_path(path)])
