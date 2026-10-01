extends "res://tools/capture_campaign_contact.gd"

func _initialize() -> void:
	await super._initialize()

func _use_focused_interaction(game: Node, interaction_id: String, label: String, expected_speaker: String = "") -> void:
	if interaction_id in ["register_rook", "register_mira"]:
		if not await _await_focused_interaction(game, interaction_id, label):
			return
		var evidence: Node3D = game.active_interactable
		var direction: Vector3 = evidence.global_position - game.player.global_position
		var yaw := atan2(-direction.x, -direction.z)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(wrapf(float(game.camera_rig.yaw) - yaw, -PI, PI) / float(game.camera_rig.sensitivity), 0)
		Input.parse_input_event(motion)
		await _frames(18)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := contact_dir.path_join(interaction_id + "_focused.png")
		if image == null or image.get_size() != Vector2i(1280, 720) or image.save_png(path) != OK:
			_fail("Could not capture the actual focused register")
			return
		contact_views.append({"path": path, "sha256": FileAccess.get_sha256(path), "zone": game.current_zone_id, "interaction": interaction_id, "player_position": str(game.player.global_position), "interaction_position": str(evidence.global_position), "camera_transform": var_to_str(game.camera_rig.camera.global_transform)})
		await super._use_focused_interaction(game, interaction_id, label, expected_speaker)
		await _turn_camera_north(game)
	else:
		await super._use_focused_interaction(game, interaction_id, label, expected_speaker)

func _return_register_from_farmstead(game: Node) -> void:
	# Continue the earned checkpoint physically to the other required fragment.
	await _move_until(game, KEY_D, "register_farm_east_return_lane", func(p: Vector3) -> bool: return p.x > -2.5, 6000)
	await _move_until(game, KEY_W, "register_farm_north_road", func(p: Vector3) -> bool: return p.z < -11, 10000)
	await _move_until(game, KEY_D, "register_farm_north_gate", func(p: Vector3) -> bool: return p.x > 7, 6000)
	await _move_until(game, KEY_W, "register_farm_to_marsh", func(_p: Vector3) -> bool: return game.current_zone_id == "marsh_crossing", 9000)
	if not await _await_playable_zone(game, "marsh_crossing", "register_marsh_arrival"):
		return
	await _move_until(game, KEY_D, "register_marsh_east_lane", func(p: Vector3) -> bool: return p.x > 3, 6000)
	await _move_until(game, KEY_W, "register_mira_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "register_mira", 13000)
	await _use_focused_interaction(game, "register_mira", "register_mira")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_names_they_burned", "fragment_mira"):
		_fail("Healer's fragment did not advance through actual E")
		return
	var slot := await _save_campaign_checkpoint(game)
	var objectives: Array = slot.get("data", {}).get("quests", {}).get("active", {}).get("main_names_they_burned", {}).get("objectives", [])
	for id in ["fragment_rook", "fragment_mira", "reconstruct_register"]:
		if not objectives.any(func(objective: Dictionary) -> bool: return str(objective.get("id", "")) == id and bool(objective.get("done", false))):
			_fail("Manual save lost physically collected register beat: " + id)
	print("REAL_INPUT register_pair_save=%s zone=marsh_crossing" % ("PASS" if failures.is_empty() else "FAIL"))
