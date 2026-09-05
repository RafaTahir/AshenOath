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
	}
