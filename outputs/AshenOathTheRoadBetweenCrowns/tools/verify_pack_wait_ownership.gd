extends SceneTree

const Packs = preload("res://scripts/runtime_pack_manager.gd")
const JourneyLoad = preload("res://scripts/journey_load_runtime.gd")

class PackProbe extends Node:
	var content_ready := false
	var failed := false
	var ready_checks := 0
	var failure_checks := 0
	var last_extras: Array[String] = []
	func zone_packs_ready(_zone: String, extras: Array[String] = []) -> bool:
		ready_checks += 1
		last_extras = extras.duplicate()
		return content_ready
	func zone_pack_failures(_zone: String, _extras: Array[String] = []) -> Array[String]:
		failure_checks += 1
		var result: Array[String] = []
		if failed: result.append("fixture download failed")
		return result
	func zone_pack_progress(_zone: String, _extras: Array[String] = []) -> float:
		return 0.5

class PlayerProbe extends CharacterBody3D:
	var transition_locked := true
	func set_transition_locked(value: bool) -> void:
		transition_locked = value

class HudProbe extends Node:
	var unsuccessful_ends := 0
	var menu_returns := 0
	func update_journey_load_progress(_zone: String, _progress: float, _detail: String = "") -> void:
		pass
	func end_journey_load(successful: bool) -> void:
		if not successful: unsuccessful_ends += 1
	func hide_loading() -> void:
		pass
	func post_notice(_reason: String, _kind: String, _seconds: float, _key: String) -> void:
		pass
	func show_main_menu() -> void:
		menu_returns += 1

class AudioProbe extends Node:
	var game_paused := true
	func set_game_paused(value: bool) -> void:
		game_paused = value

class TestGame extends "res://scripts/game.gd":
	var activations := 0
	var recoveries := 0
	func _ready() -> void:
		set_process(false)

class ClockLifecycle extends "res://scripts/systems/zone_lifecycle_service.gd":
	var now_msec := 1000
	func _pack_wait_now_msec() -> int:
		return now_msec
	func _load_zone(_zone: String, _position: Vector3 = Vector3.ZERO) -> void:
		_host.set("activations", int(_host.get("activations")) + 1)
	func _recover_failed_pack_load(reason: String = "The destination could not load. Please retry.") -> void:
		_host.set("recoveries", int(_host.get("recoveries")) + 1)
		super._recover_failed_pack_load(reason)

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Packs.PREPARATION_TIMEOUT_MSEC == 120000, "shared preparation deadline must be 120 seconds")
	_check(JourneyLoad.PREPARATION_TIMEOUT_MSEC == Packs.PREPARATION_TIMEOUT_MSEC, "restore and travel must share the deadline")
	for opening in [false, true]:
		await _slow_success(opening)
		await _expiry(opening)
		await _ready_at_deadline(opening)
		await _stale_or_cancelled(opening, true)
		await _stale_or_cancelled(opening, false)
		await _explicit_failure(opening)
		await _missing_player_recovery(opening)
	for failure in failures:
		push_error(failure)
	print("PACK WAIT OWNERSHIP: ", "PASS" if failures.is_empty() else "FAIL", "; monotonic 30-second success, 120-second expiry, frame independence, deadline readiness, stale/cancelled ownership, explicit failure and resident source recovery")
	quit(0 if failures.is_empty() else 1)

func _case(opening: bool) -> Dictionary:
	var game := TestGame.new()
	root.add_child(game)
	game.add_child(game.zone_residency)
	var packs := PackProbe.new()
	game.add_child(packs)
	game.runtime_packs = packs
	game.hud = HudProbe.new()
	game.add_child(game.hud)
	game.audio = AudioProbe.new()
	game.add_child(game.audio)
	var source := Node3D.new()
	game.add_child(source)
	game.zone_root = source
	var actor := PlayerProbe.new()
	game.add_child(actor)
	actor.position = Vector3(3, 1, -2)
	actor.velocity = Vector3(2, 0, 0)
	game.player = actor
	game.game_started = true
	game.pending_player_restore = {"health": {"health": 47.0}}
	game.zone_pack_request_serial = 2
	game.opening_pack_waiting = opening
	game.campaign_pack_waiting = not opening
	game.neighbor_crossing_pending = true
	game.neighbor_crossing_was_paused = false
	var waiter := ClockLifecycle.new()
	waiter.configure(game, game._state, game._systems)
	game.add_child(waiter)
	var context := {"game": game, "packs": packs, "waiter": waiter, "source": source, "actor": actor, "opening": opening, "done": false}
	_watch(context)
	return context

func _watch(context: Dictionary) -> void:
	if context.opening:
		var extras: Array[String] = ["monsters"]
		await context.waiter._wait_for_opening_pack("greyfen", Vector3.ZERO, 2, extras)
	else:
		await context.waiter._wait_for_campaign_pack("hart_glade", Vector3.ZERO, 2)
	context.done = true

func _slow_success(opening: bool) -> void:
	var context := _case(opening)
	# More than the retired 900-frame budget must not consume two minutes.
	for frame in 905:
		context.waiter.now_msec = 1001 + frame
		await process_frame
	_check(not context.done and context.game.recoveries == 0, _label(context, "fast frames must not expire a live request"))
	context.waiter.now_msec = 31000
	context.packs.content_ready = true
	await _pump()
	_check(context.done and context.game.activations == 1 and context.game.recoveries == 0, _label(context, "30-second download must activate exactly once"))
	_check(context.packs.ready_checks > 900, _label(context, "fixture must exercise more than 900 polling frames"))
	if opening:
		_check(context.packs.last_extras == ["monsters"], "opening wait must retain encounter pack requirements")
	await _dispose(context)

func _expiry(opening: bool) -> void:
	var context := _case(opening)
	context.waiter.now_msec = 120999
	await _pump()
	_check(not context.done and context.game.recoveries == 0, _label(context, "a sparse frame at 119999 ms must keep waiting"))
	context.waiter.now_msec = 121000
	await _pump()
	_check(context.done and context.game.recoveries == 1 and context.game.activations == 0, _label(context, "120000 ms must recover exactly once"))
	_check_source_preserved(context)
	await _dispose(context)

func _ready_at_deadline(opening: bool) -> void:
	var context := _case(opening)
	context.waiter.now_msec = 121000
	context.packs.content_ready = true
	context.packs.failed = true
	await _pump()
	_check(context.done and context.game.activations == 1 and context.game.recoveries == 0, _label(context, "readiness must win over failure and deadline"))
	_check(context.packs.failure_checks == 0, _label(context, "ready content must not enter failure recovery"))
	await _dispose(context)

func _stale_or_cancelled(opening: bool, stale: bool) -> void:
	var context := _case(opening)
	if stale:
		context.game.zone_pack_request_serial += 1
	else:
		context.game.opening_pack_waiting = false
		context.game.campaign_pack_waiting = false
	context.waiter.now_msec = 121000
	context.packs.content_ready = true
	context.packs.failed = true
	await _pump()
	_check(context.done and context.game.activations == 0 and context.game.recoveries == 0, _label(context, "stale/cancelled work must not activate or recover"))
	_check(context.packs.ready_checks == 0 and context.packs.failure_checks == 0, _label(context, "ownership must be checked before pack state"))
	if stale:
		_check(context.game.opening_pack_waiting if opening else context.game.campaign_pack_waiting, _label(context, "stale work must leave the newer waiting flag intact"))
	await _dispose(context)

func _explicit_failure(opening: bool) -> void:
	var context := _case(opening)
	paused = true
	context.waiter.now_msec = 2000
	context.packs.failed = true
	await _pump()
	_check(context.done and context.game.recoveries == 1 and context.game.activations == 0, _label(context, "explicit failure must recover before the deadline"))
	_check_source_preserved(context)
	await _dispose(context)

func _missing_player_recovery(opening: bool) -> void:
	var context := _case(opening)
	context.game.player = null
	context.packs.failed = true
	await _pump()
	_check(context.done and context.game.recoveries == 1 and not context.game.game_started and context.game.hud.menu_returns == 1, _label(context, "missing-player recovery must return to the menu"))
	_check(context.game.zone_root == context.source and context.source.is_inside_tree() and not context.source.is_queued_for_deletion(), _label(context, "missing-player recovery must retain the source root"))
	await _dispose(context)

func _check_source_preserved(context: Dictionary) -> void:
	var game = context.game
	_check(is_instance_valid(context.source) and game.zone_root == context.source and context.source.is_inside_tree() and not context.source.is_queued_for_deletion(), _label(context, "failed travel must keep the source zone resident"))
	_check(game.game_started and not context.actor.transition_locked and context.actor.position == Vector3(3, 1, -2) and context.actor.velocity == Vector3.ZERO, _label(context, "failed travel must restore the original player in place"))
	_check(game.pending_player_restore.is_empty() and not game.opening_pack_waiting and not game.campaign_pack_waiting and not game.neighbor_crossing_pending, _label(context, "existing recovery must clear only pending travel state"))
	_check(not game.audio.game_paused and game.hud.unsuccessful_ends == 1, _label(context, "existing recovery must end the download presentation"))

func _dispose(context: Dictionary) -> void:
	# Also retire a failed fixture's suspended coroutine before freeing its host.
	context.game.zone_pack_request_serial += 1
	context.game.opening_pack_waiting = false
	context.game.campaign_pack_waiting = false
	await _pump()
	context.game.free()
	await process_frame

func _pump() -> void:
	await process_frame
	await process_frame

func _label(context: Dictionary, message: String) -> String:
	return ("opening: " if context.opening else "campaign: ") + message

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
