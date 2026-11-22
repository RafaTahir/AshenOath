extends RefCounted

const PREPARATION_TIMEOUT_MSEC := 120000
const Journal = preload("res://scripts/story_journal.gd")
const Continuity = preload("res://scripts/journey_continuity_coordinator.gd")

func pending(game) -> bool:
	return not game.journey_continuity.restore_request().is_empty()

func request(game, prepared: Dictionary) -> void:
	if not bool(prepared.get("ok", false)) or game.resource_shutdown_prepared:
		return
	if pending(game):
		if str(game.journey_continuity.restore_request().get("phase", "")) == "applying":
			return
		cancel(game, "", false)
	var request_id: String = str(prepared.get("request_id", ""))
	if game.zone_transition_pending or game.zone_load_request_pending or game.opening_pack_waiting or game.campaign_pack_waiting:
		game.save_manager.finish_load(game, request_id, false, "Finish the current crossing before opening another journey.")
		return
	var source: Dictionary = prepared.get("source", {})
	var summary: Dictionary = prepared.get("summary", {})
	var reason: String = "replay" if bool(summary.get("replay", false)) else "restore"
	if str(source.get("slot_id", "")) == "checkpoint":
		reason = "checkpoint"
	var origin: Dictionary = {
		"reason": reason, "source_zone": str(game.current_zone_id),
		"source_label": str(source.get("label", summary.get("title", "Saved journey"))),
		"journey_id": str(summary.get("journey_id", "")),
		"replay": bool(summary.get("replay", false)),
		"recovered_backup": bool(source.get("recovered_backup", str(source.get("source", "")) == "backup")),
		"previous_menu": game.hud.preparation_screen_key(),
		"previous_paused": game.get_tree().paused,
		"previous_input_context": game.input_router.get_context()
	}
	var generation: int = game.journey_continuity.stage_restore(prepared, origin)
	var staged: Dictionary = game.journey_continuity.restore_request()
	if staged.is_empty():
		game.save_manager.finish_load(game, request_id, false, "The selected journey could not be prepared.")
		return
	game.new_game_start_pending = false
	game._begin_gameplay_handoff("prepare_journey")
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	if is_instance_valid(game.player):
		game.player.set_transition_locked(true)
	game.hud.begin_journey_load(prepared)
	var target: String = str(staged.get("target_zone", "greyfen"))
	if OS.has_feature("web"):
		if game.runtime_packs == null:
			cancel(game, "The destination's content is unavailable. Your current session remains in place.")
			return
		game.runtime_packs.quality_preset = str(game.settings.settings.get("quality_preset", "balanced"))
		if not game.runtime_packs.zone_packs_ready(target):
			var queued: bool = game.runtime_packs.request_zone_packs(target)
			if not queued:
				cancel(game, "The destination could not be downloaded. Your current session remains in place; select the journey to retry.")
				return
			var deadline: int = Time.get_ticks_msec() + PREPARATION_TIMEOUT_MSEC
			while Time.get_ticks_msec() < deadline:
				await game.get_tree().process_frame
				if not _is_current(game, generation):
					return
				if game.runtime_packs.zone_packs_ready(target):
					break
				if not game.runtime_packs.zone_pack_failures(target).is_empty():
					cancel(game, "The destination download stopped. Your current session remains in place; select the journey to retry.")
					return
			if not game.runtime_packs.zone_packs_ready(target):
				cancel(game, "The destination took too long to prepare. Your current session remains in place; select the journey to retry.")
				return
	if not _is_current(game, generation):
		return
	if not bool(source.get("direct_data", false)):
		var accepted: Dictionary = game.save_manager.accept_prepared_load(request_id)
		if not bool(accepted.get("ok", false)):
			cancel(game, str(accepted.get("reason", accepted.get("message", "The journey could not be opened."))))
			return
	var claimed: Dictionary = game.journey_continuity.claim_restore(generation)
	if claimed.is_empty():
		return
	game.hud.set_journey_load_applying()
	game.hud.clear_journey_transients(true)
	game._apply_loaded_journey(claimed.get("data", {}))
	try_finish(game)

func try_finish(game) -> void:
	var staged: Dictionary = game.journey_continuity.restore_request()
	if str(staged.get("phase", "")) != "applying":
		return
	if not game.game_started or not is_instance_valid(game.player) or not is_instance_valid(game.zone_root):
		return
	if game.zone_transition_pending or game.zone_load_request_pending or game.opening_pack_waiting or game.campaign_pack_waiting or not game.pending_player_restore.is_empty():
		return
	if str(game.current_zone_id) != str(staged.get("target_zone", "")):
		return
	var generation: int = int(staged.get("generation", -1))
	var completed: Dictionary = game.journey_continuity.finish_restore(generation)
	if completed.is_empty():
		return
	var source: Dictionary = completed.get("source", {})
	if not bool(source.get("direct_data", false)):
		game.save_manager.finish_load(game, str(completed.get("request_id", "")), true)
	game.journey_arrival_generation = int(completed.get("arrival_generation", 0))
	game.hud.end_journey_load(true)
	game._refresh_tracker()
	game._refresh_equipment_readout()
	game._refresh_journey_models()
	game.call_deferred("_publish_journey_arrival")

func cancel(game, reason: String = "Journey loading cancelled.", present: bool = true, shutdown: bool = false) -> void:
	var staged: Dictionary = game.journey_continuity.restore_request()
	if staged.is_empty() or (str(staged.get("phase", "")) == "applying" and not shutdown):
		return
	var cancelled: Dictionary = game.journey_continuity.cancel_restore(int(staged.get("generation", -1)), reason)
	if cancelled.is_empty():
		return
	# An abandoned generation cannot claim its payload when a download finishes.
	game.zone_pack_request_serial += 1
	var source: Dictionary = cancelled.get("source", {})
	if not bool(source.get("direct_data", false)):
		game.save_manager.finish_load(game, str(cancelled.get("request_id", "")), false, "")
	if shutdown:
		return
	game.hud.end_journey_load(false, reason if present else "")
	var paused: bool = bool(cancelled.get("previous_paused", true))
	game.get_tree().paused = paused
	game.audio.set_game_paused(paused)
	if is_instance_valid(game.player):
		game.player.set_transition_locked(false)
	game.input_router.begin_context(str(cancelled.get("previous_input_context", "pause" if paused else "gameplay")))
	game._invalidate_interaction_prompt()
	game._refresh_journey_models()
	game.call_deferred("_persist_story_action")

func begin_arrival(game, reason: String, target: String) -> void:
	if pending(game):
		return
	var view: Dictionary = game.quest_presentation.get_navigation_view_model() if game.quest_presentation != null else {}
	var context: Dictionary = {
		"source_zone": str(game.current_zone_id),
		"promise_signature": Continuity.promise_signature(view)
	}
	game.journey_arrival_generation = game.journey_continuity.begin_arrival(reason, target, context)
	game.hud.clear_journey_transients(false)

func publish_arrival(game) -> void:
	if game.journey_arrival_generation <= 0 or pending(game) or game.resource_shutdown_prepared:
		return
	if not game.game_started or game.get_tree().paused or not is_instance_valid(game.player) or game.zone_transition_pending or not game.pending_player_restore.is_empty():
		return
	var view: Dictionary = game.quest_presentation.get_navigation_view_model() if game.quest_presentation != null else {}
	var recap: Dictionary = Journal.recap_model(game.quests, game.story_state, str(game.current_zone_id))
	var model: Dictionary = game.journey_continuity.take_arrival(game.journey_arrival_generation, str(game.current_zone_id), view, recap)
	if not model.is_empty():
		game.journey_arrival_generation = 0
		game.hud.present_journey_return(model)

func _is_current(game, generation: int) -> bool:
	if not is_instance_valid(game) or game.resource_shutdown_prepared:
		return false
	var request: Dictionary = game.journey_continuity.restore_request()
	return int(request.get("generation", -1)) == generation and str(request.get("phase", "")) == "preparing"
