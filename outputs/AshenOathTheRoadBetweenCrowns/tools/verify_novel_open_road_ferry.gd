extends SceneTree

const Activity = preload("res://scripts/community_activity.gd")
const Ending = preload("res://scripts/community_ending.gd")
const InteractableScene = preload("res://scripts/interactable.gd")
const Presentation = preload("res://scripts/community_presentation.gd")
const Route = preload("res://scripts/core/community_route_details.gd")
const StoryState = preload("res://scripts/story_state.gd")

class ReadyEquipment extends RefCounted:
	func is_transitioning() -> bool: return false
	func is_drawn() -> bool: return false

class Player extends Node3D:
	var can_control := true
	var health_component := {"health":100.0}
	var equipment_loadout := ReadyEquipment.new()
	var hurt_react_time := 0.0
	var transition_locked := false
	var velocity := Vector3.ZERO
	var weapon_mode := ""
	var animation_driver: Node
	func _request_equipment(_mode, _id, _drawn) -> void: pass
	func get_selected_blade_id() -> String: return ""

class Status extends RefCounted:
	func set_guidance_hint(_text, _duration) -> void: pass

class Host extends Node:
	var zone_root := Node3D.new()
	var current_zone_id := "lantern_reach"
	var story_state := StoryState.new()
	var player := Player.new()
	var day_night: Node
	var quests: Node
	var hud := Status.new()
	var pending_ending := "depart"
	var pending_player_restore: Dictionary = {}
	var zone_transition_pending := false
	var zone_load_request_pending := false
	var story_save_pending := false
	func _journey_load_pending() -> bool: return false
	func _remove_interaction_candidate(_area) -> void: pass
	func _persist_story_action() -> void: story_save_pending = false
	func _configure_npc_animation(_visual, _id) -> void: pass
	func _mat(color: Color) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		return material
	func _make_role_visual(_role, _category, _size) -> Node3D:
		var stand_in := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		stand_in.add_child(mesh)
		return stand_in

class Director extends Node:
	func _danger_near(_host) -> bool: return false
	func _rest_unavailable(_area) -> String: return ""
	func _cancel_rest() -> void: pass
	func _cancel_friend_work() -> void: pass
	func _point(root: Node3D, id: String, prompt: String, position: Vector3, _title, _color) -> void:
		var station := InteractableScene.new()
		station.setup(id,"story_activity",prompt)
		station.position = position
		root.add_child(station)

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var host := Host.new()
	root.add_child(host)
	host.add_child(host.story_state)
	host.add_child(host.zone_root)
	host.zone_root.add_child(host.player)
	var director := Director.new()
	host.zone_root.add_child(director)
	var state := host.story_state
	state.flags = {
		"campaign_revision":2, "novel_edition":1, "final_covenant":"open_road", "covenant_ritual_started":true,
		"covenant_ritual_step":3, "open_road_relocation_started":true, "open_road_protection_dismantled":true,
		"territorial_protection_active":false, "hart_complete_account_access":false, "human_records_preserved":true,
		"community_route":"crossing", "community_route_ready":true, "community_refuge_ready":true,
	}
	var world_work := Node3D.new()
	world_work.name = "CommunityWork"
	host.zone_root.add_child(world_work)
	Presentation._choice_arrangements(host,world_work,"lantern_reach")
	var activity := Activity.new()
	activity.director = director
	activity.game = host
	activity.zone = host.current_zone_id
	activity._station("ferry","Board at the west landing",Vector3(3,0,0.8),{"operation":"ferry","dock":"west","seconds":8.0})
	activity._station("departure_return_ferry","Board at the east landing",Vector3(10.5,0,0.8),{"operation":"ferry","dock":"east","seconds":8.0})
	var west: Node3D = activity.stations.ferry.get_ref()
	var east: Node3D = activity.stations.departure_return_ferry.get_ref()
	var boat := host.zone_root.get_node(Activity.FERRY_PATH) as Node3D
	var ferry := boat.get_parent() as Node3D
	var bridge := world_work.get_node("PublicRoute_crossing") as Node3D
	var guide := ferry.get_node("FerryGuide") as Node3D
	var haul := ferry.get_node("HaulRig") as Node3D

	activity.refresh()
	_check(ferry.visible and not bridge.visible, "The rescue takes the ferry even on the bridge route")
	_check(guide.visible and not west.visible and not east.visible, "Boarding waits for preparation")
	_check(Ending.complete_action("departure_load","lantern_reach",state), "Prepare the rescue at Lantern Reach")
	activity.refresh()
	_check(not guide.visible and haul.visible, "The upstream guide is gone and the hauling line survives")
	_check(west.visible and not east.visible, "The first group boards on the west bank")
	_check(Route.departure(state).target_ids == ["community:ferry"], "Guidance does not send a bridge-route journey to the bridge")
	_check(host.zone_root.find_children("*","Skeleton3D",true,false).is_empty(), "Passenger visuals do not add active rigs")

	host.player.position = west.position
	activity.activate(west)
	activity.tick(4.0)
	_check(is_equal_approx(boat.position.x,6.5) and absf(host.player.position.x-boat.position.x) < 1.0, "Kael travels aboard the actual ferry")
	_check(is_equal_approx(activity.rescue_cast.get_node("bera").global_position.x,boat.global_position.x), "Bera's group travels with the ferry")
	_check(Ending.departure_manifest(state).arrived_passengers == 0, "A midstream ferry cannot count arrivals")
	activity.refresh()
	_check(is_equal_approx(boat.position.x,6.5), "Refreshing presentation does not snap a moving ferry to shore")
	activity.cancel(false)
	_check(host.player.position.is_equal_approx(Vector3(3,0.02,1.5)) and host.player.can_control and is_equal_approx(boat.position.x,3.5), "An interrupted ferry returns player and boat to the saved dock")
	_check(west.visible and Ending.departure_manifest(state).completed_legs == 0, "An interrupted ferry can be retried")

	activity.activate(west)
	activity.tick(8.0)
	_check(Ending.departure_manifest(state).arrived_passengers == 4 and host.player.position.is_equal_approx(Vector3(10.5,0.02,1.5)), "The first leg lands with four people safe")
	_check(not west.visible and east.visible and Route.departure(state).target_ids == ["community:departure_return_ferry"], "Only the east return is available after the first leg")
	state.flags = JSON.parse_string(JSON.stringify(state.flags))
	activity.refresh()
	_check(is_equal_approx(boat.position.x,9.5) and not guide.visible, "Restored progress retains the east dock and guide loss")
	activity.activate(east)
	activity.tick(4.0)
	_check(is_equal_approx(boat.position.x,6.5) and activity.rescue_cast.get_node("bera").position.x > 10.0 and activity.rescue_cast.get_node("siv").position.x < 3.5, "The return carries crew and leaves both groups ashore")
	activity.tick(4.0)
	_check(Ending.departure_manifest(state).arrived_passengers == 4 and not west.visible and not east.visible and host.player.position.x < 3.5, "The empty return lands on the west bank and requires the rescue")

	_check(not Ending.complete_action("departure_second_rescue","lantern_reach",state), "Siv’s rescue waits for the actual bank encounter")
	state.set_flag("novel_bank_cleared",true) # Encounter boundary; the rendered river journey covers this trigger.
	_check(Ending.complete_action("departure_second_rescue","lantern_reach",state), "Prepare Siv's three after the empty return")
	activity.refresh()
	activity.activate(west)
	activity.tick(4.0)
	_check(is_equal_approx(activity.rescue_cast.get_node("siv").global_position.x,boat.global_position.x), "The second outbound carries Siv's group")
	activity.cancel(false)
	state.flags = JSON.parse_string(JSON.stringify(state.flags))
	activity.refresh()
	_check(west.visible and host.player.position.x < 3.5 and state.get_flag("novel_departure_calf_injured") == true and state.get_flag("novel_departure_bow_lost") == true, "The canceled second crossing restores the west dock and preserves the wound and bow loss")
	activity.activate(west)
	activity.tick(8.0)
	_check(Ending.departure_manifest(state).arrived_passengers == 7 and not Ending.ready_to_finish(state), "The second loaded trip lands with all seven and handover pending")
	_check(state.get_flag("community_route") == "crossing", "Temporary use of the ferry preserves the public route choice")
	for failure: String in failures: push_error(failure)
	print("NOVEL OPEN ROAD FERRY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL",failures.size()])
	quit(0 if failures.is_empty() else 1)
