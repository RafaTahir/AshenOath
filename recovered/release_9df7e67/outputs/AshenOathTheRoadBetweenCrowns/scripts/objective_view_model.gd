class_name ObjectiveViewModel
extends RefCounted

## Immutable-at-the-call-site presentation contract for quest guidance.
## QuestManager owns progression; this object is the single shaped result that
## the HUD, compass, interaction focus, and save summaries can consume.

var zone_id := ""
var zone_name := ""
var quest_id := ""
var quest_title := ""
var objective_id := ""
var objective_text := ""
var next_action := ""
var tracker_text := ""
var contextual_text := ""
var compass_text := ""
var destination_zone := ""
var destination_name := ""
var target_ids: Array[String] = []
var guidance_scope := "exploration"
var route_hint := ""
var purpose := ""
var pinpoint := false
var save_summary: Dictionary = {}

func to_dictionary() -> Dictionary:
	return {
		"zone_id": zone_id,
		"zone_name": zone_name,
		"quest_id": quest_id,
		"quest_title": quest_title,
		"objective_id": objective_id,
		"objective_text": objective_text,
		"next_action": next_action,
		"tracker_text": tracker_text,
		"contextual_text": contextual_text,
		"compass_text": compass_text,
		"destination_zone": destination_zone,
		"destination_name": destination_name,
		"target_ids": target_ids.duplicate(),
		"guidance_scope": guidance_scope,
		"route_hint": route_hint,
		"purpose": purpose,
		"pinpoint": pinpoint,
		"save_summary": save_summary.duplicate(true),
	}
