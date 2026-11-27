extends "res://tools/verify_community_world_input.gd"

## Source candidate, real viewport, ordinary menu actions, walking and Use.
func _initialize() -> void:
	output = OS.get_environment("ASHEN_NOVEL_EVIDENCE")
	case_id = "novel_opening"
	start_ms = Time.get_ticks_msec()
	if output.is_empty() or DisplayServer.get_name().to_lower()=="headless":
		push_error("A rendered viewport and isolated evidence directory are required.")
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(output)
	topology = load("res://scripts/world_sector_manifest.gd")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
	await _frames(8)
	var deadline := Time.get_ticks_msec()+420000
	var sample := 0
	while Time.get_ticks_msec() < deadline:
		var main_visible := false
		for control: Button in root.find_children("*","Button",true,false):
			if control.is_visible_in_tree() and not control.disabled and control.text.begins_with("New Game"):
				main_visible = true
				break
		if main_visible: break
		if Time.get_ticks_msec() > sample:
			sample = Time.get_ticks_msec()+15000
			print("NOVEL_OPENING preparation ",game.hud.active_menu," ready=",game.new_game_start_pending," failed=",game.startup_prepare_failed)
			if game.startup_prepare_failed: break
		await process_frame
	await _button("New Game")
	await _button("Turn the crow")
	await _capture("sella_brass")
	await _button("Tie Sella")
	await _button("Wrap the crow")
	await _capture("sella_gate")
	await _button("Lift the latch")
	if failures.is_empty():
		_check(game.story_state.get_flag("novel_prologue_presentation","")=="witnessed","Sella’s complete memory reached the gate.")
		_check(not game.story_state.has_evidence("novel:cart_purse"),"The prologue granted Kael no road evidence.")
	region = "greyfen"
	await _ready(region)
	await _interact("novel_gate_hub_0")
	await _wait_step(1)
	await _interact("novel_gate_hub_1")
	await _wait_step(2)
	await _capture("greyfen_repaired_hub")
	await _finish()

func _wait_step(expected: int) -> void:
	if not failures.is_empty(): return
	var deadline := Time.get_ticks_msec()+12000
	while int(game.story_state.get_flag("novel_step_gate_hub",0)) < expected and Time.get_ticks_msec()<deadline:
		await process_frame
	_check(int(game.story_state.get_flag("novel_step_gate_hub",0)) == expected,"Hub work reached step "+str(expected))

func _capture(id: String) -> void:
	if not failures.is_empty(): return
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	_check(shot != null and shot.save_png(output.path_join(id+".png")) == OK, "Captured "+id)
