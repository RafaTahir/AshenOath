extends "res://tools/verify_opening_real_input_native.gd"

func _meet_anwen_and_inspect_graves(game: Node) -> void:
	# Finish only the genuine first chapter; no downstream success is claimed.
	if not game.quests.is_completed("main_road_of_crows") or game.wychwood_pack_kills != 5:
		_fail("First chapter did not retain the five actual kills/report")
		return
	await _save_campaign_checkpoint(game)
	if failures.is_empty():
		print("REAL_INPUT wychwood_combat_scope=PASS new_game=true kills=5 report=true no_bypass=true")
