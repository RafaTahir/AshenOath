extends "res://tools/verify_opening_real_input_native.gd"

func _confront_edric(game: Node) -> void:
	var expected := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else "compelled"
	if str(game.story_state.get_flag("edric_stance", "")) != expected or not game.quests.is_completed("main_blood_under_stone") or not game.quests.is_active("main_last_witness"):
		_fail("Normal Continue did not preserve Edric stance and quest progression")
		return
	var slot := await _save_campaign_checkpoint(game)
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("edric_stance", "")) != expected:
		_fail("Normal pause-menu save did not preserve reloaded Edric choice")
	else:
		print("REAL_INPUT edric_reload=PASS stance=%s normal_continue_and_manual_save=true" % expected)
