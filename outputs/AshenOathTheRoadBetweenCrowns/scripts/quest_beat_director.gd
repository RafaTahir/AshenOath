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
		"open_chapel": {"stage":"ruined_crow_chapel", "cue":"The chapel door has stopped pretending it is only stone.", "next":"Open the ruined Crow Chapel."},
		"crow_shrine_choice": {"stage":"crow_shrine", "cue":"The shrine is open, but its covenant is not innocent.", "next":"Choose what the Crow Shrine should remember."},
	},
	"main_teeth_in_rain": {
		"speak_mira": {"stage":"greyfen_herbalist", "cue":"Mira knows what the ash is doing to the living.", "next":"Ask Mira what the dead remember."},
		"read_chapel_names": {"stage":"ruined_crow_chapel", "cue":"The chapel wall still holds the names Greyfen tried to rub away.", "next":"Read the erased names in the Crow Chapel."},
		"name_the_dead": {"stage":"ritual_stones", "cue":"A name spoken aloud can change the road.", "next":"Speak Oren's name at the ritual stones."},
		"fight_bog_wretch": {"stage":"deep_wood_clearing", "cue":"Something in the deeper wood is carrying a human memory.", "next":"Find the Bog Wretch."},
		"bog_core_choice": {"stage":"deep_wood_clearing", "cue":"The memory core still holds a choice that belongs to the living.", "next":"Choose what to do with the Bog Wretch's memory core."},
	},
	"main_names_they_burned": {
		"reconstruct_register": {"stage":"burned_register", "cue":"Three fragments are enough to restore the road's missing names.", "next":"Reconstruct the refugee register."},
		"names_choice": {"stage":"greyfen_assembly", "cue":"The restored names can be spoken now or held until the road is weaker.", "next":"Choose whether to publish the names."},
	},
	"main_ash_at_the_mill": {
		"reach_mill": {"stage":"old_mill_approach", "cue":"The mill is still turning on what Greyfen refused to name.", "next":"Reach the abandoned mill."},
		"inspect_millstones": {"stage":"old_mill_floor", "cue":"The stones remember what was ground into Greyfen's fields.", "next":"Inspect the millstones."},
		"mill_encounter": {"stage":"old_mill_marsh_edge", "cue":"Ash is moving against the wind above the mill.", "next":"Clear the ash-bound mill."},
		"mill_choice": {"stage":"old_mill_records", "cue":"The mill records can expose the bargain or preserve its evidence.", "next":"Choose the fate of the mill records."},
	},
	"main_soldier_without_banner": {
		"reach_bandit_road": {"stage":"bandit_road", "cue":"Captain Senn kept the old road but discarded its banner.", "next":"Find Captain Senn on the bandit road."},
		"senn_confrontation": {"stage":"bandit_road_duel", "cue":"Senn is measuring whether Kael wants justice or testimony.", "next":"Break Senn's guard or win his surrender."},
		"senn_choice": {"stage":"bandit_road_testimony", "cue":"A soldier without a banner still has a version of the order.", "next":"Choose Senn's punishment, testimony, or exile."},
	},
	"main_blood_under_stone": {
		"reach_castle": {"stage":"vargan_approach", "cue":"The old military road ends at House Vargan.", "next":"Reach Castle Vargan."},
		"speak_guard": {"stage":"vargan_gatehouse", "cue":"The gate guard knows the road was closed by an order, not weather.", "next":"Speak with the gate guard."},
		"enter_courtyard": {"stage":"vargan_courtyard", "cue":"The portcullis is open, but House Vargan still watches the approach.", "next":"Enter Castle Vargan's outer courtyard."},
		"castle_evidence_ready": {"stage":"vargan_records", "cue":"The road closure was deliberate, not forgotten.", "next":"Locate the sealed record hall."},
		"locate_record_hall": {"stage":"record_hall_threshold", "cue":"The archive door carries the seal that kept the names buried.", "next":"Locate the sealed record hall."},
		"recover_ledger": {"stage":"record_hall_ledger", "cue":"The command ledger has been cut open but not destroyed.", "next":"Examine the sealed command ledger."},
		"ledger_choice": {"stage":"record_hall_ledger", "cue":"The ledger can be evidence, leverage, or a secret.", "next":"Decide what to do with the command ledger."},
		"survive_haunting": {"stage":"record_hall_haunting", "cue":"The erased names are no longer content to stay on the page.", "next":"Survive what the erased names awakened."},
		"last_witness_hook": {"stage":"vargan_undercroft_threshold", "cue":"The record hall points below the castle, where one witness refused the order.", "next":"Descend beneath Vargan stone to find the last witness."},
	},
	"main_last_witness": {
		"reach_undercroft": {"stage":"vargan_undercroft", "cue":"The last witness is below the stone that kept the command sealed.", "next":"Enter the Vargan undercroft."},
		"break_halvern_guard": {"stage":"vargan_undercroft", "cue":"Halvern is guarding the last testimony with his life.", "next":"Force the Gravebound Knight to yield."},
		"halvern_choice": {"stage":"vargan_undercroft_testimony", "cue":"The knight can be freed, questioned, or left to the grave he chose.", "next":"Choose Halvern's fate."},
	},
	"main_crowns_without_mercy": {
		"gather_witnesses": {"stage":"witness_route", "cue":"A confession needs more than one surviving voice.", "next":"Gather witnesses or their surviving records."},
		"greyfen_assembly": {"stage":"greyfen_assembly", "cue":"Greyfen has to hear the names together, not as scattered rumors.", "next":"Open Greyfen's assembly."},
		"confession_choice": {"stage":"greyfen_assembly_choice", "cue":"The assembly is listening. Kael must decide how much truth to carry forward.", "next":"Decide how the truth will be spoken."},
	},
	"main_hart_remembers": {
		"enter_glade": {"stage":"white_hart_road", "cue":"The reopened road ends where the witness was bound.", "next":"Walk the reopened road to the White Hart."},
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
