class_name JourneyContinuityCoordinator
extends RefCounted

## Transient handoff bookkeeping only. SaveManager selects and accepts the
## source; root owns pack readiness, world mutation and the playable boundary.
## No file I/O, scene references, timers, quest mutation or saved state lives here.
var _generation: int = 0
var _restore: Dictionary = {}
var _arrival: Dictionary = {}

func stage_restore(prepared: Dictionary, origin: Dictionary) -> int:
	var data_value: Variant = prepared.get("data", null)
	var request_id: String = str(prepared.get("request_id", ""))
	if not bool(prepared.get("ok", false)) or request_id == "" or not data_value is Dictionary:
		return 0
	# Save validation belongs to the prepared ticket, not this helper. These are
	# only the fields needed to match an asynchronous destination handoff.
	var data: Dictionary = data_value
	var target_zone: String = _zone(str(data.get("world_sector", data.get("zone", "greyfen"))))
	if target_zone == "":
		return 0
	_generation += 1
	_arrival.clear()
	_restore = {
		"generation":_generation, "request_id":request_id,
		"target_zone":target_zone, "phase":"preparing",
		"prepared":prepared.duplicate(true), "origin":origin.duplicate(true)
	}
	return _generation

func restore_request() -> Dictionary:
	if _restore.is_empty():
		return {}
	return {
		"generation":int(_restore.get("generation", 0)),
		"request_id":str(_restore.get("request_id", "")),
		"target_zone":str(_restore.get("target_zone", "")),
		"phase":str(_restore.get("phase", "")),
		"origin":(_restore.get("origin", {}) as Dictionary).duplicate(true),
		"can_cancel":str(_restore.get("phase", "")) == "preparing"
	}

func claim_restore(generation: int) -> Dictionary:
	if not _matches_restore(generation) or str(_restore.get("phase", "")) != "preparing":
		return {}
	# Root calls this only after all required packs are ready and SaveManager's
	# accept_prepared_load succeeds. A callback cannot claim the payload twice.
	_restore["phase"] = "applying"
	var prepared: Dictionary = _restore.get("prepared", {})
	var result: Dictionary = prepared.duplicate(true)
	result["generation"] = generation
	result["target_zone"] = str(_restore.get("target_zone", ""))
	result["phase"] = "applying"
	result["origin"] = (_restore.get("origin", {}) as Dictionary).duplicate(true)
	return result

func cancel_restore(generation: int, reason: String = "") -> Dictionary:
	if not _matches_restore(generation):
		return {}
	var origin: Dictionary = (_restore.get("origin", {}) as Dictionary).duplicate(true)
	var prepared: Dictionary = _restore.get("prepared", {})
	var result := {
		"ok":true, "cancelled":true, "generation":generation,
		"request_id":str(_restore.get("request_id", "")),
		"target_zone":str(_restore.get("target_zone", "")),
		"phase":str(_restore.get("phase", "")), "reason":reason,
		"origin":origin, "context":origin.duplicate(true),
		"previous_paused":bool(origin.get("previous_paused", false)),
		"previous_menu":str(origin.get("previous_menu", "")),
		"previous_input_context":str(origin.get("previous_input_context", "")),
		"source":_dictionary_copy(prepared.get("source", {})),
		"summary":_dictionary_copy(prepared.get("summary", {}))
	}
	# Cancellation after claiming is bookkeeping for a failed/shutdown handoff,
	# not a claim that this helper can roll back already-applied engine state.
	_generation += 1
	_restore.clear()
	_arrival.clear()
	return result

func finish_restore(generation: int) -> Dictionary:
	if not _matches_restore(generation) or str(_restore.get("phase", "")) != "applying":
		return {}
	# Root reaches this after the player is restored and SaveManager has
	# published the accepted identity and History. Pack readiness alone is not it.
	var prepared: Dictionary = _restore.get("prepared", {})
	var data: Dictionary = prepared.get("data", {})
	var summary: Dictionary = _dictionary_copy(prepared.get("summary", {}))
	var source: Dictionary = _dictionary_copy(prepared.get("source", {}))
	var origin: Dictionary = (_restore.get("origin", {}) as Dictionary).duplicate(true)
	var context: Dictionary = origin.duplicate(true)
	var target_zone: String = str(_restore.get("target_zone", ""))
	var request_id: String = str(_restore.get("request_id", ""))
	context["source"] = source.duplicate(true)
	context["source_label"] = _first_text([source.get("label", ""), source.get("title", ""), origin.get("source_label", ""), summary.get("title", "")])
	context["journey_id"] = str(summary.get("journey_id", data.get("journey_id", origin.get("journey_id", ""))))
	context["replay"] = bool(summary.get("replay", data.get("replay_session", false)))
	context["recovered_backup"] = bool(source.get("recovered_backup", source.get("backup", origin.get("recovered_backup", false))))
	context["restored"] = true
	context["request_id"] = request_id
	var reason: String = _first_text([origin.get("reason", ""), source.get("reason", ""), "restore"])
	_arrival = {"generation":generation, "target_zone":target_zone, "reason":reason, "context":context}
	_restore.clear()
	return {
		"ok":true, "request_id":request_id, "generation":generation,
		"arrival_generation":generation, "target_zone":target_zone,
		"phase":"ready", "reason":reason, "source":source,
		"summary":summary, "origin":origin, "context":context.duplicate(true)
	}

func begin_arrival(reason: String, target_zone: String, context: Dictionary = {}) -> int:
	# Technical zone activation during an applying restore must not replace its
	# logical arrival. The prepared journey owns that generation until finished.
	if not _restore.is_empty():
		return 0
	var target: String = _zone(target_zone)
	if target == "":
		return 0
	_generation += 1
	_arrival = {
		"generation":_generation, "target_zone":target,
		"reason":reason.strip_edges().to_lower(), "context":context.duplicate(true)
	}
	return _generation

func take_arrival(generation: int, actual_zone: String, objective_view: Dictionary, recap: Dictionary) -> Dictionary:
	if not _restore.is_empty() or _arrival.is_empty() or generation != _generation:
		return {}
	if int(_arrival.get("generation", 0)) != generation:
		return {}
	var zone_id: String = _zone(actual_zone)
	if zone_id == "" or zone_id != str(_arrival.get("target_zone", "")):
		return {}
	var presentation_zone: String = _zone(str(objective_view.get("zone_id", "")))
	if presentation_zone != "" and presentation_zone != zone_id:
		return {}
	var context: Dictionary = _arrival.get("context", {})
	var reason: String = str(_arrival.get("reason", "travel"))
	var restored: bool = bool(context.get("restored", false))
	var replay: bool = bool(context.get("replay", false))
	var recovered: bool = bool(context.get("recovered_backup", false))
	var zone_name: String = _first_text([objective_view.get("zone_name", ""), zone_id.replace("_", " ").capitalize()])
	var next_action: String = _first_text([objective_view.get("next_action", ""), objective_view.get("contextual_text", ""), objective_view.get("objective_text", ""), recap.get("next_action", "")])
	var destination_name: String = _first_text([objective_view.get("destination_name", ""), recap.get("destination_name", "")])
	var signature: String = promise_signature(objective_view)
	var before_signature: String = str(context.get("promise_signature", ""))
	var source_zone: String = _zone(str(context.get("source_zone", "")))
	var announce: bool = _should_announce(reason, restored, source_zone, zone_id, before_signature, signature, next_action)
	var title: String = zone_name
	if restored:
		title = "Chapter replay" if replay else "Recovery copy restored" if recovered else "Saved moment restored"
	elif reason in ["new_journey", "new_game"]:
		title = "The road begins"
	elif reason in ["aftermath", "ending_return"]:
		title = "The road home"
	var body_parts: Array[String] = []
	if restored:
		var source_label: String = str(context.get("source_label", "")).strip_edges()
		if source_label != "":
			body_parts.append("Recorded source: " + source_label)
		body_parts.append("This moment's recorded story state has been restored.")
	var promise: String = str(recap.get("promise", "")).strip_edges()
	if promise != "":
		body_parts.append(promise)
	if restored:
		var last_commitment: String = str(recap.get("last_commitment", "")).strip_edges()
		if last_commitment != "":
			body_parts.append("Last commitment: " + last_commitment)
	if next_action != "":
		body_parts.append("Next: %s%s" % [next_action, " (" + destination_name + ")" if destination_name != "" else ""])
	var journey_id: String = str(context.get("journey_id", "session"))
	var context_id: String = "journey:%s:arrival:%d" % [journey_id, generation]
	var model := {
		"id":context_id, "context_id":context_id, "generation":generation,
		"reason":reason, "title":title, "body":"\n\n".join(body_parts),
		"zone_name":zone_name, "zone_id":zone_id,
		"next_action":next_action, "destination_name":destination_name,
		"journal_section":"return", "announce":announce,
		"promise_signature":signature, "restored":restored,
		"replay":replay, "recovered_backup":recovered
	}
	_arrival.clear()
	return model

static func promise_signature(view: Dictionary) -> String:
	var quest_id: String = str(view.get("quest_id", ""))
	var objective_id: String = str(view.get("objective_id", ""))
	if quest_id == "" and objective_id == "":
		return ""
	return "%s|%s|%s|%s" % [quest_id, objective_id, str(view.get("destination_zone", "")), str(view.get("guidance_scope", ""))]

func _matches_restore(generation: int) -> bool:
	return not _restore.is_empty() and generation == _generation and int(_restore.get("generation", 0)) == generation

static func _should_announce(reason: String, restored: bool, source_zone: String, zone_id: String, before: String, current: String, next_action: String) -> bool:
	if restored:
		return true
	if reason in ["refresh", "zone_refresh", "settings", "visual_preset"]:
		return false
	if reason in ["new_journey", "new_game", "aftermath", "ending_return"]:
		return true
	# Travel never invents a return recap from an unknown starting context.
	# Navigation still updates its quiet place/next-step region on every arrival.
	return source_zone != "" and source_zone != zone_id and before != "" and current != "" and before != current and next_action != ""

static func _zone(value: String) -> String:
	return value.strip_edges().to_lower()

static func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

static func _first_text(values: Array) -> String:
	for value in values:
		if value == null:
			continue
		var text_value: String = str(value).strip_edges()
		if text_value != "":
			return text_value
	return ""
