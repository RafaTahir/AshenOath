extends "res://tools/verify_opening_real_input_native.gd"

func _use_south_bank_clue(game: Node, interaction_id: String, objective_id: String, keycode: Key, target_x: float, target_z: float) -> void:
	await super._use_south_bank_clue(game, interaction_id, objective_id, keycode, target_x, target_z)
	if not failures.is_empty() or not "--opening-text-proof" in OS.get_cmdline_user_args():
		return
	var prefix: String = {"black_feathers": "Sella's red thread.", "claw_marks": "Vargan binding wire."}.get(interaction_id, "")
	if prefix.is_empty():
		return
	if not game.hud.toast_label.visible or not game.hud.toast_label.text.begins_with(prefix):
		_fail("Personal clue observation was overwritten: " + game.hud.toast_label.text)
		return
	await RenderingServer.frame_post_draw
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")
	var path := "res://Development_Gallery/screenshots/OPENING_PRESENCE_%s_%s.png" % [interaction_id, stamp]
	if root.get_texture().get_image().save_png(path) != OK:
		_fail("Could not capture actual clue text: " + path)
	print("REAL_INPUT personal_clue=PASS id=%s screenshot=%s" % [interaction_id, ProjectSettings.globalize_path(path)])

func _fight_wychwood_pack(game: Node) -> void:
	if not "--spatial-contact-audio" in OS.get_cmdline_user_args():
		await super._fight_wychwood_pack(game)
		return
	var observed := {"contact": {}, "hits": 0}
	var contact_observer := func(result: Dictionary) -> void: observed.contact = result
	var audio_observer := func(_sample: Dictionary) -> void:
		var result: Dictionary = observed.contact
		observed.contact = {}
		if not bool(result.get("hit", false)):
			return
		observed.hits += 1
		var point: Vector3 = result.contact_point
		var cue: Node = game.audio.active_cue_order.back() if not game.audio.active_cue_order.is_empty() else null
		if not cue is AudioStreamPlayer3D or not cue.playing or cue.global_position.distance_to(point) > 0.02:
			_fail("Sword contact did not start its spatial sound at the resolved blade contact")
	game.combat.contact_resolved.connect(contact_observer)
	game.player.blade_contact_requested.connect(audio_observer)
	await super._fight_wychwood_pack(game)
	game.combat.contact_resolved.disconnect(contact_observer)
	game.player.blade_contact_requested.disconnect(audio_observer)
	if observed.hits == 0:
		_fail("No actual sword contact observed for spatial sound verification")
	print("REAL_INPUT spatial_contact_audio hits=%d failures=%d" % [observed.hits, failures.size()])

func _meet_anwen_and_inspect_graves(game: Node) -> void:
	# Finish only the genuine first chapter; no downstream success is claimed.
	if not game.quests.is_completed("main_road_of_crows") or game.wychwood_pack_kills != 5:
		_fail("First chapter did not retain the five actual kills/report")
		return
	await _save_campaign_checkpoint(game)
	if failures.is_empty():
		print("REAL_INPUT wychwood_combat_scope=PASS new_game=true kills=5 report=true no_bypass=true")
