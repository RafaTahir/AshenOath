extends SceneTree

const Adapter = preload("res://scripts/community_activity.gd")
const Rules = preload("res://scripts/community_campaign.gd")
const State = preload("res://scripts/story_state.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Interactable = preload("res://scripts/interactable.gd")
const SavesOwner = preload("res://scripts/save_manager.gd")
var failures: Array[String] = []
var checks := 0

class Equipment extends RefCounted:
	var drawn := false
	var transitioning := false
	func is_transitioning() -> bool: return transitioning
	func is_drawn() -> bool: return drawn
class FakeAnimation extends RefCounted:
	var current_state := "idle"
	func trigger_action(id: String, _a, _b, _c, _d) -> void: current_state=id
	func stop_action(id: String, _a) -> void: current_state=id
class Health extends RefCounted:
	var health := 100.0
class Player extends Node3D:
	var can_control := true
	var transition_locked := false
	var weapon_mode := "sword"
	var velocity := Vector3.ZERO
	var hurt_react_time := 0.0
	var equipment_loadout := Equipment.new()
	var animation_driver := FakeAnimation.new()
	var health_component := Health.new()
	func get_selected_blade_id() -> String: return "sword"
	func _request_equipment(_a, _b, _c) -> void: pass
class Layer extends RefCounted:
	var visible := false
class HUD extends RefCounted:
	var dialogue_layer := Layer.new()
	var _dialogue_view_generation := 0
	var content: Dictionary = {}
	func toast(_text) -> void: pass
	func set_guidance_hint(_text,_seconds) -> void: pass
	func show_dialogue(value: Dictionary) -> void:
		_dialogue_view_generation+=1
		dialogue_layer.visible=true
		content=value
	func close_surface() -> void:
		_dialogue_view_generation+=1
		dialogue_layer.visible=false
class Audio extends RefCounted:
	func set_game_paused(_value) -> void: pass
	func set_dialogue_active(_value) -> void: pass
	func play_event(_a,_b) -> void: pass
class Saves extends RefCounted:
	func predecision(_game,_id) -> void: pass
class Game extends Node3D:
	var current_zone_id := "lantern_reach"
	var zone_root := Node3D.new()
	var player := Player.new()
	var story_state := State.new()
	var quests := Quests.new()
	var hud := HUD.new()
	var audio := Audio.new()
	var save_manager := Saves.new()
	var zone_transition_pending := false
	var zone_load_request_pending := false
	var pending_player_restore := {}
	var pending_ending := ""
	var story_action_in_progress := false
	var story_save_pending := false
	func _journey_load_pending() -> bool: return false
	func _remove_interaction_candidate(_area) -> void: pass
	func _prepare_dialogue_presence(content: Dictionary) -> Dictionary: return content
	func _stage_dialogue_moment(_actor) -> void: pass
	func _resume_game() -> void: get_tree().paused=false
	func _persist_story_action() -> void: pass
	func _finish_story_action(_action) -> void: pass
class Director extends Node:
	var host
	var community: RefCounted
	var zone := "lantern_reach"
	var danger := false
	func _danger_near(_game) -> bool: return danger
	func _rest_unavailable(area: Node3D) -> String:
		return "blocked" if not is_instance_valid(area) or danger or area.global_position.distance_to(host.player.global_position)>2.8 else ""
	func _cancel_rest() -> void: pass
	func _cancel_friend_work() -> void: pass
	func _point(root: Node3D,id: String,prompt: String,position: Vector3,_title,_color) -> void:
		var area := Interactable.new()
		area.setup(id,"story_activity",prompt)
		area.position=position
		root.add_child(area)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.add_child(game.zone_root); game.add_child(game.player)
	game.add_child(game.story_state); game.add_child(game.quests)
	game.story_state.set_flag("campaign_revision",2)
	game.quests.load_quests("res://data/quests.json")
	game.quests.configure_campaign_revision(2)
	game.quests.unlocked["main_empty_tables"]=true
	game.quests.start_quest("main_empty_tables")
	game.quests.complete_objective("main_empty_tables","reach_lantern_reach")
	game.quests.complete_objective("main_empty_tables","hear_households")
	var director := Director.new(); director.host=game; director.name="StoryActivities"
	game.zone_root.add_child(director)
	var adapter := Adapter.new(); adapter.configure(director)
	director.community=adapter
	var area: Node3D = adapter.stations["work:kitchen_trestle"].get_ref()
	game.player.global_position=area.global_position+Vector3(0,0.9,0.7)
	adapter.activate(area)
	adapter.tick(1.0)
	_check(not adapter.work.is_empty() and adapter.elapsed==1.0,"work actually advances while controlled")
	game.player.position.x+=0.31
	adapter.tick(0.1)
	_check(adapter.work.is_empty() and not Rules._true(game.story_state,"community_work:kitchen_trestle"),"movement cancels without partial credit")
	game.player.global_position=area.global_position+Vector3(0,0.9,0.7)
	adapter.activate(area); adapter.tick(1.0); adapter.cancel(false)
	_check(adapter.elapsed==0 and not Rules._true(game.story_state,"community_work:kitchen_trestle"),"pause cancellation discards timer")
	adapter.activate(area); director.danger=true; adapter.tick(4.0)
	_check(not Rules._true(game.story_state,"community_work:kitchen_trestle"),"threat cannot complete work at boundary")
	director.danger=false
	adapter.activate(area); game.player.equipment_loadout.drawn=true; adapter.tick(4.0)
	_check(not Rules._true(game.story_state,"community_work:kitchen_trestle"),"drawing weapon cancels work")
	game.player.equipment_loadout.drawn=false
	adapter.activate(area)
	for frame in range(39): adapter.tick(0.1)
	_check(not Rules._true(game.story_state,"community_work:kitchen_trestle"),"work cannot finish early")
	adapter.tick(0.11)
	_check(Rules._true(game.story_state,"community_work:kitchen_trestle"),"complete physical duration credits exactly its task")
	_check(not game.quests.is_objective_done("main_empty_tables","prepare_kitchen"),"one task cannot complete three-task preparation")
	# Two native menu interactions: the second invalidates the first instance
	# and generation before either can write a choice.
	var board: Node3D=adapter.stations.board.get_ref()
	game.player.global_position=board.global_position+Vector3(0,0.9,0.7)
	game.quests.complete_objective("main_empty_tables","prepare_kitchen")
	game.story_state.set_flag("community_kitchen_ready",true)
	adapter.activate(board)
	var stale: Dictionary=game.hud.content.actions[0].duplicate(true)
	game.hud.close_surface(); game._resume_game()
	adapter.activate(board)
	var current: Dictionary=game.hud.content.actions[0].duplicate(true)
	game.hud.close_surface()
	adapter.choose(stale)
	_check(str(game.story_state.get_flag("community_distribution",""))=="","stale menu cannot commit")
	adapter.choose(current)
	_check(str(game.story_state.get_flag("community_distribution",""))=="central","current source menu commits the authored choice")
	_check(not game.quests.is_completed("main_empty_tables"),"menu choice cannot replace served meal")
	adapter.choose(current)
	_check(not game.quests.is_completed("main_empty_tables"),"replayed callback cannot advance aftermath")
	# A synthetic ferry node tests the adapter's movement and owner cleanup,
	# while keeping all native models and level construction outside this suite.
	var work_root := Node3D.new(); work_root.name="CommunityWork"; game.zone_root.add_child(work_root)
	var public_route := Node3D.new(); public_route.name="PublicRoute_ferry"; work_root.add_child(public_route)
	var boat := Node3D.new(); boat.name="Ferry"; public_route.add_child(boat)
	game.quests.unlocked["main_road_kept_open"]=true; game.quests.start_quest("main_road_kept_open")
	game.quests.complete_objective("main_road_kept_open","survey_crossing")
	game.quests.complete_choice("main_road_kept_open","agree_route")
	game.quests.complete_objective("main_road_kept_open","secure_route")
	game.story_state.set_flag("community_route","ferry"); game.story_state.set_flag("community_route_ready",true)
	Rules.finish_aftermath("main_road_kept_open","lantern_reach",game.story_state,game.quests)
	adapter.refresh()
	var ferry: Node3D=adapter.stations.ferry.get_ref()
	game.player.global_position=ferry.global_position+Vector3(0,0.95,0.6)
	adapter.activate(ferry); adapter.tick(2.0)
	_check(not game.player.can_control and boat.position.x>3.5 and boat.position.x<9.5,"ferry owns movement only during transit")
	SavesOwner.stop_transient_activity_for_save(game)
	_check(adapter.work.is_empty() and game.player.can_control and game.player.global_position.is_equal_approx(Vector3(3,0.95,1.5)),"save owner returns interrupted ferry to safe bank")
	_check(Rules._true(game.story_state,"community_route_load_carried") and not Rules._true(game.story_state,"community_route_load_crossed"),"save cancellation retains load but not unperformed passage")
	adapter.activate(ferry); adapter.tick(7.6)
	_check(Rules._true(game.story_state,"community_route_load_crossed") and game.player.can_control,"full crossing restores input and records arrival")
	_check(not game.quests.is_completed("main_road_kept_open"),"arriving boat cannot replace delivery")
	var delivery: Node3D=adapter.stations.delivery.get_ref()
	adapter.activate(delivery); adapter.tick(3.1)
	_check(game.quests.is_completed("main_road_kept_open"),"actual timed far-landing delivery finishes route")
	# Consent comes from the actual speaking instance, and only after its
	# authored answer has been presented in a fresh owned menu.
	game.quests.unlocked["main_what_we_promise"]=true; game.quests.start_quest("main_what_we_promise")
	var nessa := Interactable.new(); nessa.setup("saga_nessa","dialogue","Speak to Nessa")
	nessa.set_meta("community_actor_id","nessa"); game.zone_root.add_child(nessa)
	game.player.global_position=Vector3(0,0.95,0.7)
	adapter.activate(nessa)
	var ask: Dictionary=game.hud.content.actions[0].duplicate(true)
	game.hud.close_surface(); adapter.choose(ask)
	_check(not game.story_state.get_flag("community_keeper_consent",{}).has("nessa"),"hearing a willing answer does not silently record it")
	_check(str(game.hud.content.pages[0].text)==str(Rules.data().consent_offers.nessa.yes),"actual authored participant answer is presented")
	var record: Dictionary=game.hud.content.actions[0].duplicate(true)
	SavesOwner.stop_transient_activity_for_save(game)
	_check(adapter.menu_generation==int(record.generation) and not adapter.menu_actions.is_empty(),"deferred autosave preserves the newly opened participant answer")
	record["id"]="anwen"; record["accepted"]=false
	game.hud.close_surface(); adapter.choose(record)
	_check(game.story_state.get_flag("community_keeper_consent",{}).get("nessa")==true and not game.story_state.get_flag("community_keeper_consent",{}).has("anwen"),"caller cannot replace participant identity or authored answer")
	adapter.activate(nessa)
	var withdraw: Dictionary=game.hud.content.actions[2].duplicate(true)
	game.hud.close_surface(); adapter.choose(withdraw)
	_check(game.story_state.get_flag("community_keeper_consent",{}).get("nessa")==false,"participant withdrawal clears only its own offered shift")
	game.hud.close_surface(); game._resume_game()
	preload("res://scripts/story_performance.gd").finish(nessa)
	adapter.cancel(); paused=false
	for failure: String in failures: printerr("COMMUNITY ACTIVITY: "+failure)
	print("COMMUNITY ACTIVITY: %s checks=%d (synthetic actor and UI; no models/input claim)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	game.free()
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
