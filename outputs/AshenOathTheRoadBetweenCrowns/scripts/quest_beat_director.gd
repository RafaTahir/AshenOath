extends Node
class_name QuestBeatDirector

## Presentation-only beat contract. QuestManager owns completion and save data;
## this service turns the active objective into one consistent staging cue.

signal beat_changed(beat: Dictionary)

const BEATS := {
	"main_road_of_crows": {
		"speak_anwen": {"stage":"shrine", "cue":"Anwen is waiting at the shrine.", "next":"Speak with Sister Anwen."},
		"evidence_ready": {"stage":"wychwood_road", "cue":"The road has enough evidence to name what happened.", "next":"Find the five creatures in Wychwood."},
		"fight_ghoulkin": {"stage":"wychwood_clearing", "cue":"The clearing has gone quiet around Kael.", "next":"Survive the Wychwood pack."},
		"return_village": {"stage":"greyfen_return", "cue":"The village needs to hear what Kael found.", "next":"Return to Greyfen and choose how to report."},
	},
	"main_bell_beneath_greyfen": {
		"meet_anwen_gate": {"stage":"cemetery_gate", "cue":"Anwen has moved to the cemetery gate.", "next":"Meet Sister Anwen beside the graves."},
		"grave_truth": {"stage":"disturbed_graves", "cue":"The graves are telling one story from several angles.", "next":"Inspect the disturbed graves."},
		"cemetery_ambush": {"stage":"chapel_approach", "cue":"The bell has drawn something out of the soil.", "next":"Defeat what rose between the graves."},
		"crow_shrine_choice": {"stage":"crow_shrine", "cue":"The shrine is open, but its covenant is not innocent.", "next":"Choose what the Crow Shrine should remember."},
	},
	"main_teeth_in_rain": {
		"speak_mira": {"stage":"greyfen_herbalist", "cue":"Mira knows what the ash is doing to the living.", "next":"Ask Mira what the dead remember."},
		"name_the_dead": {"stage":"ritual_stones", "cue":"A name spoken aloud can change the road.", "next":"Speak Oren's name at the ritual stones."},
		"fight_bog_wretch": {"stage":"deep_wood_clearing", "cue":"Something in the deeper wood is carrying a human memory.", "next":"Find the Bog Wretch."},
	},
	"main_blood_under_stone": {
		"reach_castle": {"stage":"vargan_approach", "cue":"The old military road ends at House Vargan.", "next":"Reach Castle Vargan."},
		"castle_evidence_ready": {"stage":"vargan_records", "cue":"The road closure was deliberate, not forgotten.", "next":"Locate the sealed record hall."},
		"ledger_choice": {"stage":"record_hall_ledger", "cue":"The ledger can be evidence, leverage, or a secret.", "next":"Decide what to do with the command ledger."},
	},
	"main_last_witness": {
		"break_halvern_guard": {"stage":"vargan_undercroft", "cue":"Halvern is guarding the last testimony with his life.", "next":"Force the Gravebound Knight to yield."},
	},
	"main_hart_remembers": {
		"hear_testimony": {"stage":"white_hart_glade", "cue":"The road has reopened to its oldest witness.", "next":"Hear what the living and the dead remember."},
		"final_choice": {"stage":"white_hart_glade", "cue":"Kael's final oath will decide what survives the truth.", "next":"Choose Witness, Mercy, Duty, or Ash."},
	},
}

var quest_manager: Node
var story_state: Node
var zone_id := "greyfen"
var current_beat: Dictionary = {}

func setup(manager: Node, state: Node) -> void:
	quest_manager = manager
	story_state = state
	if quest_manager != null and quest_manager.has_signal("changed") and not quest_manager.changed.is_connected(refresh):
		quest_manager.changed.connect(refresh)
	refresh()

func set_zone(id: String) -> void:
	zone_id = id.strip_edges().to_lower()
	refresh()

func refresh() -> Dictionary:
	var tracked := str(quest_manager.get_tracked_quest()) if quest_manager != null and quest_manager.has_method("get_tracked_quest") else ""
	var objective_id := ""
	if quest_manager != null and tracked != "" and quest_manager.has_method("get_active_objective_id"):
		objective_id = str(quest_manager.get_active_objective_id(tracked))
	current_beat = {}
	if BEATS.has(tracked) and BEATS[tracked].has(objective_id):
		current_beat = BEATS[tracked][objective_id].duplicate(true)
		current_beat["quest_id"] = tracked
		current_beat["objective_id"] = objective_id
		current_beat["zone_id"] = zone_id
	beat_changed.emit(current_beat)
	return current_beat.duplicate(true)

func get_current_beat() -> Dictionary:
	return current_beat.duplicate(true)

func get_next_action(fallback: String = "Follow the road") -> String:
	return str(current_beat.get("next", fallback))

func decorate_tracker(base_text: String) -> String:
	if base_text == "" or current_beat.is_empty():
		return base_text
	var next_action := str(current_beat.get("next", "")).strip_edges()
	if next_action == "":
		return base_text
	var lines := base_text.split("\n", false)
	if lines.size() < 2:
		return base_text
	# The beat director is the final presentation authority. Keep the quest
	# manager's title and progress line, but replace stale contextual wording.
	lines[1] = "- " + next_action.trim_suffix(".")
	return "\n".join(lines)

func get_stage() -> String:
	return str(current_beat.get("stage", ""))

func save_state() -> Dictionary:
	return {"zone_id": zone_id}

func load_state(data: Dictionary) -> void:
	zone_id = str(data.get("zone_id", zone_id)).strip_edges().to_lower()
	refresh()
