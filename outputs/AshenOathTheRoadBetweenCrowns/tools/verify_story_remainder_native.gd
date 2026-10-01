extends "res://tools/verify_story_continuous_native.gd"

func _continue_teeth_in_rain(game: Node) -> void:
	if not bool(game.story_state.get_flag("bell_eater_defeated", false)):
		_fail("Resumed remainder requires the genuine resolved Bell checkpoint")
		return
	stabilize_route_bearing = true
	await super._continue_teeth_in_rain(game)
	if not failures.is_empty():
		return
	await _run_campaign_from(game, 2)
	if failures.is_empty():
		print("REAL_INPUT campaign_remainder=PASS new_game=false start=genuine_bell_save ending=mercy no_bypass=true")

func _confront_edric(game: Node) -> void:
	await super._confront_edric(game)
	if not failures.is_empty() or not OS.get_cmdline_user_args().has("--continue-edric"):
		return
	await _run_castle_from(game, 5)
	if failures.is_empty():
		print("REAL_INPUT campaign_remainder=PASS new_game=false start=genuine_haunting_save ending=mercy no_bypass=true")
