extends "res://tools/verify_opening_real_input_native.gd"

var contact_dir := ""
var contact_views: Array[Dictionary] = []
var contact_keys: Dictionary = {}
var contact_inputs: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--contact-output-dir=D:/Temp/AshenOath/"):
			contact_dir = argument.trim_prefix("--contact-output-dir=")
	if contact_dir.is_empty():
		_fail("A unique D:/Temp/AshenOath contact output directory is required")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(contact_dir)
	for path in ["tools/capture_campaign_contact.gd", "tools/verify_opening_real_input_native.gd", "scripts/game.gd", "scripts/camera_controller.gd", "scripts/enemy_ai.gd", "scripts/player_controller.gd", "scripts/character_animation_driver.gd", "scripts/character_role_spec.gd", "scripts/zones/campaign_wilderness_section.gd", "scripts/zones/campaign_finale_section.gd", "visual_upgrade_manifest.json"]:
		contact_inputs[path] = FileAccess.get_sha256("res://" + path)
	if get_script().resource_path == "res://tools/capture_campaign_records.gd":
		for path in ["tools/capture_campaign_records.gd", "scripts/campaign_record_presentation.gd", "tools/build_campaign_records.gd", "assets_external/environment/props/CampaignRecord_register_rook_Authored.res", "assets_external/environment/props/CampaignRecord_register_mira_Authored.res"]:
			contact_inputs[path] = FileAccess.get_sha256("res://" + path)
	await super._initialize()

func _fight_rootbound_real_input(game: Node) -> void:
	await super._fight_rootbound_real_input(game)
	if failures.is_empty():
		await _frames(35)

func _before_ashwing_attack(game: Node) -> void:
	if OS.get_cmdline_user_args().has("--observe-first-windup"):
		var boss: Node3D = game.camera_rig.get_locked_combat_target()
		if boss == null:
			_fail("Ashwing approach has no real-input locked target")
			return
		_key(KEY_Q, true)
		await _move_until(game, KEY_W, "ashwing_guarded_approach", func(p: Vector3) -> bool: return p.distance_to(boss.global_position) <= boss.attack_range, 7000)
		if not failures.is_empty():
			_key(KEY_Q, false)
			return
		var deadline := Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline and not contact_keys.has("ashwing_windup"):
			await _frames(1)
		await _frames(45)
		_key(KEY_Q, false)
		if not contact_keys.has("ashwing_windup"):
			_fail("Ashwing did not present its actual first windup before the bounded block deadline")
			return

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
		await _capture_contact()

func _capture_contact() -> void:
	var game := root.get_node_or_null("AshenOath")
	if game == null or not game.game_started or game.zone_transition_pending or paused:
		return
	var selected: Node = null
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and enemy.is_boss:
			selected = enemy
			break
	if selected == null:
		return
	var phase := _contact_phase(selected)
	var key := str(selected.enemy_id) + "_" + phase
	if phase.is_empty() or contact_keys.has(key):
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(selected) or phase != _contact_phase(selected):
		return
	var frame := root.get_texture().get_image()
	if frame == null or frame.get_size() != Vector2i(1280, 720):
		_fail("Actual encounter frame is not native 1280x720")
		return
	var path := contact_dir.path_join(key + ".png")
	if frame.save_png(path) != OK:
		_fail("Could not preserve actual encounter frame: " + path)
		return
	contact_keys[key] = true
	contact_views.append({
		"path": path, "sha256": FileAccess.get_sha256(path),
		"zone": game.current_zone_id, "enemy_id": selected.enemy_id,
		"phase": phase, "tick_usec": Time.get_ticks_usec(),
		"enemy_position": str(selected.global_position),
		"player_position": str(game.player.global_position),
		"windup": selected.pending_attack_time, "stagger": selected.stagger_time,
		"recovery": selected.attack_recovery_time,
		"animation_state": selected.animation_driver.current_state if selected.animation_driver != null else "none",
		"animation_elapsed": selected.animation_driver.action_elapsed if selected.animation_driver != null else 0.0,
		"camera_transform": str(game.camera_rig.camera.global_transform),
		"parry_key_pressed": Input.is_physical_key_pressed(KEY_Q),
	})
	print("REAL_INPUT contact_frame=%s path=%s" % [key, path])

func _contact_phase(enemy: Node) -> String:
	if enemy.dead:
		return "death" if enemy.animation_driver == null or enemy.animation_driver.action_elapsed >= 0.35 else ""
	if enemy.stagger_time > 0.0:
		return "stagger"
	if enemy.pending_attack_time > 0.0:
		return "windup"
	if enemy.attack_recovery_time > 0.0:
		return "recovery"
	return ""

func _finish() -> void:
	if not contact_dir.is_empty():
		for path in contact_inputs:
			if contact_inputs[path] != FileAccess.get_sha256("res://" + path):
				_fail("Encounter source changed during capture: " + path)
		var report := {"scope": "actual input-driven encounter frames; capture overhead invalidates FPS benchmarking; no poses, camera, actor or story state staged", "inputs": contact_inputs, "views": contact_views, "failures": failures}
		var file := FileAccess.open(contact_dir.path_join("contact_report.json"), FileAccess.WRITE)
		if file == null:
			_fail("Actual encounter report could not be saved")
		else:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	super._finish()
