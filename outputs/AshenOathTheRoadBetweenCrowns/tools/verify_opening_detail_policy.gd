extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/game.gd")
	if script == null or not script.can_instantiate():
		push_error("Opening runtime does not parse")
		quit(1)
		return
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var stage := source.get_slice("func _run_opening_detail_stage", 1).get_slice("func _complete_ending", 0)
	var failures: Array[String] = []
	if "_opening_route_is_active()" in stage:
		failures.append("Landmarks are withheld for the active opening quest")
	if "OPENING_DETAIL_MIN_PLAYER_DISTANCE" in stage:
		failures.append("Spawn excludes settlement detail")
	if not "generation != opening_detail_generation" in stage or not "player.velocity.length_squared()" in stage:
		failures.append("Cancellation or movement safeguards missing")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("OPENING DETAIL POLICY: PASS (source/parser only; rendered acceptance pending)")
	quit(0 if failures.is_empty() else 1)
