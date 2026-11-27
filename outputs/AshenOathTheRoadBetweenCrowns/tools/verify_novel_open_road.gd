extends SceneTree

## Pure model fixture: no game world, scene instantiation, saves or transport.
const Ending = preload("res://scripts/community_ending.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
var failures: Array[String] = []

class State extends RefCounted:
	var flags: Dictionary = {}
	func get_flag(key: String, fallback: Variant = null) -> Variant: return flags.get(key,fallback)
	func set_flag(key: String, value: Variant) -> void: flags[key] = value
	func begin_change() -> void: pass
	func end_change() -> void: pass

func _check(valid: bool, message: String) -> void:
	if not valid: failures.append(message)

func _state(novel: bool = true) -> State:
	var state := State.new()
	state.flags = {"campaign_revision":2, "final_covenant":"open_road", "covenant_ritual_started":true, "covenant_ritual_step":3, "open_road_relocation_started":true, "open_road_protection_dismantled":true, "territorial_protection_active":false, "hart_complete_account_access":false, "human_records_preserved":true, "community_route_ready":true, "community_refuge_ready":true, "community_route":"ferry", "open_road_named_roster":[], "open_road_households":["water_carrier","quality_sweeper"]}
	if novel: state.flags["novel_edition"] = 1
	return state

func _resume(state: State) -> State:
	var restored := State.new()
	restored.flags = JSON.parse_string(JSON.stringify(state.flags))
	_check(Revision.save_revision_error({"story_state":{"flags":restored.flags},"world_state":{"pending_ending":"depart"},"zone":"lantern_reach"}) == "", "Every phase satisfies the existing save revision guard")
	_check(Ending.departure_manifest(restored) == Ending.departure_manifest(state), "JSON resume preserves the passenger manifest")
	_check(Ending.next_departure_leg(restored) == Ending.next_departure_leg(state), "JSON resume preserves the next physical leg")
	return restored

func _initialize() -> void:
	var state := _state()
	_check(Ending.next_departure_leg(state).is_empty(), "No boarding before request verification")
	_check(not Ending.complete_action("departure_arrival","hearthward",state), "No arrival before crossings")
	_check(not Ending.complete_action("departure_second_rescue","lantern_reach",state), "No second rescue before return")
	_check(not state.get_flag("novel_departure_bow_lost",false), "The bow is still aboard before the rescue")
	_check(Ending.complete_action("departure_load","lantern_reach",state), "Read back the requests and retain the hauling line")
	_check(state.get_flag("novel_departure_upstream_guide_lost") == true and state.get_flag("novel_departure_hauling_line_retained") == true, "The lost upstream guide is distinct from the surviving hauling line")
	_check(not state.flags.has("novel_departure_supply_losses"), "Supply losses are not reported before crossing")
	state = _resume(state)
	var first := Ending.next_departure_leg(state)
	_check(first.leg == 1 and first.from == "west" and first.to == "east" and first.passengers == 4 and first.aboard == 6 and first.capacity == 6, "Bera's four and two crew fill the first trip")
	_check(first.passenger_ids == ["bera","bera_daughter","bera_child_1","bera_child_2"], "Use exact relational household members")
	_check(not Ending.complete_departure_leg(3,state) and not Ending.player_crossed("ferry",state) and not Ending.finish_crossing(state), "No legacy shortcut or out-of-order trip")
	_check(Ending.complete_departure_leg(1,state), "First physical east-bank arrival")
	_check(not Ending.complete_departure_leg(1,state), "First trip cannot be replayed")
	_check(Ending.departure_manifest(state).arrived_passengers == 4 and not state.get_flag("open_road_route_crossed",false), "Only Bera's household is safe east after trip one")
	state = _resume(state)
	var returning := Ending.next_departure_leg(state)
	_check(returning.leg == 2 and returning.from == "east" and returning.to == "west" and returning.passengers == 0 and returning.aboard == 2, "Return trip has crew only")
	_check(Ending.complete_departure_leg(2,state), "Physical empty return")
	state = _resume(state)
	_check(Ending.departure_dock(state) == "west" and Ending.next_departure_leg(state).is_empty(), "Second outbound remains blocked before the west-bank rescue")
	_check(not Ending.complete_departure_leg(3,state) and not Ending.complete_action("departure_delivery","lantern_reach",state), "No rescue or delivery bypass")
	_check(not Ending.complete_action("departure_second_rescue","hearthward",state), "Rescue belongs to Lantern's west bank")
	_check(not Ending.complete_action("departure_second_rescue","lantern_reach",state), "Siv’s rescue waits for the actual bank encounter")
	state.set_flag("novel_bank_cleared",true) # Encounter boundary; the rendered river journey covers this trigger.
	_check(Ending.complete_action("departure_second_rescue","lantern_reach",state), "Rescue records the calf wound and cut-loose bow")
	_check(state.get_flag("novel_departure_calf_injured") == true and state.get_flag("novel_departure_bow_lost") == true, "The incidents persist independently of animation")
	state = _resume(state)
	var second := Ending.next_departure_leg(state)
	_check(second.leg == 3 and second.passengers == 3 and second.aboard == 5 and second.passenger_ids == ["siv","siv_father","siv_sister"], "Siv's household and crew remain below capacity")
	_check(Ending.complete_departure_leg(3,state), "Second physical east-bank arrival")
	_check(Ending.departure_manifest(state).arrived_passengers == 7 and Ending.departure_dock(state) == "east", "All seven are now safe east")
	_check(state.get_flag("open_road_player_crossed") == true and state.get_flag("open_road_route_crossed") == true and state.get_flag("open_road_crossing_progress") == 1.0, "Only the third leg commits aggregate crossing flags")
	state = _resume(state)
	_check(not Ending.complete_action("departure_delivery","hearthward",state), "Delivery is a separate east-bank station")
	_check(Ending.complete_action("departure_delivery","lantern_reach",state), "Delivery records people and material losses separately")
	_check(state.get_flag("novel_departure_supply_losses") == Ending.NOVEL_LOSSES and state.get_flag("open_road_load_carried") == false, "Exact material losses persist without changing passenger count")
	_check(state.get_flag("novel_departure_care") == {"wound_bound":"siv","wound_cleaned":"anwen"}, "Field binding and overnight cleaning are saved at the east-bank shelter")
	state = _resume(state)
	_check(not Ending.complete_action("departure_arrival","lantern_reach",state), "Hearthward arrival cannot complete at the river")
	_check(Ending.complete_action("departure_arrival","hearthward",state), "Nera counts all seven inside Hearthward")
	_check(not Ending.ready_to_finish(state) and state.get_flag("covenant_ritual_ready") == false and state.get_flag("open_road_relocation_completed") == true, "Arrival saves the count without skipping the handover")
	var completed_care: Dictionary = {"wound_bound":"siv","wound_cleaned":"anwen","arrival_count":"nera","twelve_stitches":"mira","food_and_places":"nessa"}
	_check(state.get_flag("novel_departure_care") == completed_care, "Door count, stitches and household support are saved at arrival")
	state = _resume(state)
	_check(Ending.complete_action("departure_handover","hearthward",state), "Separate relief handover")
	_check(state.get_flag("novel_departure_care") == completed_care, "Handover preserves care already recorded")
	_check(state.get_flag("novel_departure_handover_assignments") == {"greyfen_ferry":{"crew_assigned":true},"mill_run":{"carriers":["siv","toma"]},"outlying_shelters":{"lead":"nera","drivers":2},"stores_check":{"workers":["kael","merrow"],"seated":true},"follow_up":"vale"}, "The handover records routes, seated work and follow-up separately")
	_check(Ending.ready_to_finish(_resume(state)), "Resume after handover can finish the covenant")
	_check(not Ending.complete_action("departure_handover","hearthward",state), "Handover cannot be repeated")
	state.set_flag("final_choice_completed",true)
	_resume(state)
	var legacy := _state(false)
	_check(Ending.complete_action("departure_load","lantern_reach",legacy) and Ending.player_crossed("ferry",legacy), "Legacy keeps its existing single-crossing progression")
	_check(Ending.complete_action("departure_delivery","lantern_reach",legacy) and Ending.complete_action("departure_arrival","hearthward",legacy) and Ending.ready_to_finish(legacy), "Legacy completion remains unchanged")
	_check(not legacy.flags.has("novel_departure_legs"), "Legacy journeys are never opted in")
	for invalid: Variant in [true,"1",0,2]:
		legacy.flags["novel_edition"] = invalid
		_check(not Ending.novel_departure(legacy), "Only numeric edition one enables the new model")
	legacy.flags["novel_edition"] = 1.0
	_check(Ending.novel_departure(legacy), "JSON numeric edition one remains supported")
	legacy.flags["final_covenant"] = "concord"
	_check(not Ending.novel_departure(legacy), "Other covenants never enter the novel departure branch")
	for failure in failures: push_error(failure)
	print("NOVEL OPEN ROAD MODEL: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL",failures.size()])
	quit(0 if failures.is_empty() else 1)
