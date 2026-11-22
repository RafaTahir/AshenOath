extends "res://tools/verify_opening_real_input_native.gd"

var carried_choices: Dictionary = {}
const CHOICE_FLAGS := [
	"anwen_response", "evidence_report", "crow_shrine_state", "bog_core_fate",
	"names_policy", "mill_fate", "senn_fate", "vargan_ledger_hidden",
	"vargan_ledger_left_copied", "vargan_ledger_taken_openly", "edric_stance",
	"halvern_fate", "confession_method",
]

func _travel_to_castle_approach(game: Node) -> void:
	for flag in CHOICE_FLAGS:
		var value: Variant = game.story_state.get_flag(flag, null)
		if value != null:
			carried_choices[flag] = value
	await super._travel_to_castle_approach(game)
	await _run_castle_from(game, 0)

func _run_castle_from(game: Node, first_leg: int) -> void:
	_check_carried_choices(game)
	var legs: Array[Callable] = [
		_collect_castle_evidence, _enter_record_hall, _resolve_record_ledger,
		_fight_record_haunting, _confront_edric, _enter_undercroft,
		_break_halvern_guard, _resolve_halvern_witness, _travel_to_assembly,
		_hear_assembly_witnesses, _choose_assembly_testimony, _travel_to_hart_glade,
	]
	for leg in legs.slice(first_leg):
		if not failures.is_empty():
			return
		await _resume_saved_route(game)
		await leg.call(game)
		_check_carried_choices(game)
	if not failures.is_empty():
		return
	await _resume_saved_route(game)
	if OS.get_cmdline_user_args().has("--ending-ash"):
		await _resolve_hart_witness(game, 3, "ash", "kill")
	else:
		await _resolve_hart_witness(game, 1, "mercy", "free")
	_check_carried_choices(game)
	if failures.is_empty():
		print("REAL_INPUT combined_story=PASS single_process=true start_leg=%d end=actual_ending choices=%s" % [first_leg, carried_choices])

func _check_carried_choices(game: Node) -> void:
	for flag in carried_choices:
		if game.story_state.get_flag(flag, null) != carried_choices[flag]:
			_fail("Combined route silently changed previously chosen %s" % flag)
			return
	for flag in CHOICE_FLAGS:
		var value: Variant = game.story_state.get_flag(flag, null)
		if value != null:
			carried_choices[flag] = value
