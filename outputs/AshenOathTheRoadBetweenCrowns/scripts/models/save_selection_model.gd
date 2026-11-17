extends RefCounted

const Fields = preload("res://scripts/models/save_payload_fields.gd")

static func _slot_label(slot_id: String) -> String:
	if slot_id.begins_with("manual_"):
		return "Manual save " + slot_id.trim_prefix("manual_")
	return str({"quick": "Quick save", "auto": "Autosave", "checkpoint": "Checkpoint", "decision": "Before the last decision", "covenant": "Before the final covenant", "completed": "Completed campaign", "replay": "Replay autosave", "replay_quick": "Replay quick save", "replay_checkpoint": "Replay checkpoint", "replay_decision": "Before the replay decision", "replay_covenant": "Before the replay covenant"}.get(slot_id, "Saved journey"))

static func _empty_model(status: String, reason: String, summary: Dictionary = {}) -> Dictionary:
	return {"available": false, "selection": {}, "summary": summary, "source_label": "", "status": status, "reason": reason, "backup_available": false, "recovery": []}

static func _reason_text(reason: String) -> String:
	return str({"missing": "This save copy is missing. Choose a recorded recovery copy or another journey.", "unreadable": "This save copy could not be opened. Your current journey remains in place.", "invalid_json": "This save copy is damaged or incomplete. A readable backup may still be available.", "invalid_save": "This file does not contain a readable Ashen Oath journey.", "invalid_location": "This save names a destination that this release cannot restore. Your current journey remains in place.", "invalid_version": "This save has an unreadable version record. Its files have been preserved.", "future_version": "This save needs a newer game version. Its files have been preserved.", "changed": "This save changed after it was displayed. Read the refreshed journey card before loading it.", "invalid_selection": "This saved journey is no longer available. Choose it again from Saved Journeys."}.get(reason, "The saved journey could not be prepared. Your current session remains in place."))

static func _matches_journey(summary: Dictionary, identity: String, replay: bool) -> bool:
	return identity != "" and str(summary.get("journey_id", "")) == identity and bool(summary.get("replay", false)) == replay

static func remembered_continue(identity: Dictionary, model: Dictionary, snapshot: Dictionary = {}) -> Dictionary:
	var same_state: bool = str(identity.get("state_token", "")) == "" or str(identity.get("state_token", "")) == str(model.get("state_token", "")) or str(identity.get("state_token", "")) == str(model.get("legacy_state_token", ""))
	var same: bool = bool(model.get("available", false)) and same_state and _matches_journey(model.get("summary", {}), str(identity.get("journey_id", "")), bool(identity.get("replay", false)))
	if same:
		return model
	# Automatic slots advance within one journey. Manual/backup selections
	# remain exact, and a slot containing another journey is never substituted.
	var follows_automatic: bool = str(identity.get("source", "")) == "primary" and str(identity.get("slot_id", "")) in ["quick", "auto", "checkpoint", "replay", "replay_quick", "replay_checkpoint"]
	var same_journey: bool = bool(model.get("available", false)) and _matches_journey(model.get("summary", {}), str(identity.get("journey_id", "")), bool(identity.get("replay", false)))
	var remembered_time: String = str(identity.get("summary", {}).get("saved_at", ""))
	var recorded_time: String = str(model.get("summary", {}).get("saved_at", ""))
	if follows_automatic and same_journey and remembered_time != "" \
			and Fields._timestamp_value(recorded_time) >= Fields._timestamp_value(remembered_time) \
			and (recorded_time != remembered_time or not identity.has("payload")):
		model["reason"] = "Continue follows the updated %s of this same journey." % str(model.get("source_label", "record"))
		return model
	# New Continue records contain their exact selected state in the same
	# atomic JSON file. Do not substitute a slot belonging to another journey.
	if str(model.get("status", "")) != "newer_version" and (same_journey or not bool(model.get("available", false))):
		if snapshot.is_empty():
			return {"read_snapshot": true}
		if bool(snapshot.get("available", false)):
			snapshot["reason"] = "Loads the exact recorded Continue state; the separate slot write was interrupted."
			return snapshot
	var reason: String = str(model.get("reason", ""))
	if bool(model.get("available", false)):
		reason = "The remembered slot now holds a different recorded state. Choose that copy or a recovery explicitly in Saved Journeys."
	var unavailable: Dictionary = _empty_model(str(model.get("status", "unavailable")) if not bool(model.get("available", false)) else "unavailable", reason, identity.get("summary", {}))
	unavailable["source_label"] = ("Previous copy of " if str(identity.get("source", "")) == "backup" else "") + _slot_label(str(identity.get("slot_id", "")))
	unavailable["read_recovery"] = true
	return unavailable

static func fallback_continue(candidates: Array[Dictionary], newer_found: bool) -> Dictionary:
	Fields._sort_recorded_time(candidates)
	if newer_found:
		var blocked: Dictionary = _empty_model("newer_version", "A saved journey needs a newer game version. Choose an available copy explicitly in Saved Journeys.")
		blocked["recovery"] = candidates.slice(0, 3)
		return blocked
	if candidates.is_empty():
		return _empty_model("empty", "No readable campaign journey is saved on this device. Begin a journey or open Saved Journeys to import one.")
	var selected: Dictionary = candidates[0]
	selected["reason"] = "Continue uses the most recent recorded save time." if bool(selected.get("summary", {}).get("saved_at_known", false)) else "Save time was not recorded. This available copy is selected in quick save, autosave, checkpoint and manual-slot order."
	return selected

static func card(slot_id: String, source: String, result: Dictionary, summary: Dictionary, state_token: String) -> Dictionary:
	var backup: bool = source == "backup"
	var source_label: String = ("Previous copy of " if backup else "") + _slot_label(slot_id)
	if source == "resume":
		source_label = "Recorded Continue copy of " + _slot_label(slot_id)
	if bool(summary.get("replay", false)) and not source_label.to_lower().contains("replay"):
		source_label += " (replay)"
	return {"available": true, "selection": {"slot_id": slot_id, "source": source, "token": str(result.get("token", ""))}, "state_token": state_token, "legacy_state_token": str(result.get("legacy_state_token", "")), "summary": summary, "source_label": source_label, "status": "recoverable" if backup else "ready", "reason": "Loads the previous recorded copy, including its story state." if backup else "", "recovery": []}
