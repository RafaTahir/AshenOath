extends Node

## Installed by the published sector's StoryActivityDirector. Scene progress
## belongs to StoryState so a discarded sector can reconstruct unfinished work.
const Tableau = preload("res://scripts/novel/tabletop.gd")
const LAYER := "NovelScenes"
static var books: Dictionary = {}
var owner_director: Node
var game
var zone: String
var stations: Dictionary = {}
var turns: Dictionary = {}
var pending: Dictionary = {}
var menu: Dictionary = {}
var generation := 0
var elapsed := 0.0
var work_start := Vector3.ZERO
var refresh_queued := false
var alarm_count := 0
var alarm_silence := 0.0

static func current(host) -> Node:
	if not is_instance_valid(host.zone_root): return null
	return host.zone_root.get_node_or_null("StoryActivities/" + LAYER)

static func install(director: Node) -> void:
	if director.host.story_state.get_flag("novel_edition", 0) != 1: return
	var layer: Node = director.get_node_or_null(LAYER)
	if layer == null:
		layer = load("res://scripts/novel/novel_scenes.gd").new()
		layer.name = LAYER
		layer.owner_director = director
		layer.game = director.host
		layer.zone = director.zone
		director.add_child(layer)
		director.host.story_state.changed.connect(layer.schedule_refresh)
		director.host.quests.changed.connect(layer.schedule_refresh)
	layer.refresh()

static func _book(act: int) -> Array:
	if not books.has(act):
		var path := "res://data/novel/act_%d.json" % act
		if not FileAccess.file_exists(path): return []
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("scenes") is Array:
			push_error("Unreadable narrative act: " + path)
			return []
		books[act] = parsed.scenes
	return books[act]

static func route(state, objective: String) -> Dictionary:
	if state == null or not objective.begins_with("novel_"): return {}
	var id := objective.trim_prefix("novel_")
	for act in range(1,5):
		for scene: Dictionary in _book(act):
			if str(scene.id) != id: continue
			var index := int(state.get_flag("novel_step_"+id,0))
			if index < 0 or index >= scene.beats.size(): return {}
			var beat: Dictionary = scene.beats[index]
			return {"destination_zone":beat.zone,"destination_name":str(beat.zone).replace("_"," ").capitalize(),"next_action":beat.prompt,"target_ids":[beat.get("actor","novel_"+id+"_"+str(index))],"route_hint":str(beat.get("place",scene.title)),"pinpoint":true}
	return {}

func schedule_refresh() -> void:
	if refresh_queued: return
	refresh_queued = true
	call_deferred("refresh")

func refresh() -> void:
	refresh_queued = false
	if not is_inside_tree() or owner_director.get_parent() != game.zone_root: return
	turns.clear()
	var active: Dictionary = {}
	_refresh_burden()
	preload("res://scripts/novel/working_places.gd").project(self,zone,game.story_state)
	for act in range(1, 5):
		for scene: Dictionary in _book(act):
			var index := int(game.story_state.get_flag("novel_step_" + str(scene.id), 0))
			if index < 0 or index >= scene.beats.size(): continue
			var beat: Dictionary = scene.beats[index]
			for variant: Dictionary in beat.get("variants",[]):
				if _allows(variant.get("when",{})):
					beat = beat.merged(variant,true)
					break
			if beat.zone != zone or not _allows(scene.get("when", {})) or not _allows(beat.get("when", {})): continue
			var key := str(scene.id)
			turns[key] = {"scene":scene, "index":index, "beat":beat}
			if beat.has("actor"): continue
			var station := _station(key, index, beat)
			active[station] = true
	for area: Node3D in stations.values():
		var enabled := active.has(area)
		if area.visible == enabled and area.is_interaction_enabled() == enabled: continue
		area.visible = enabled
		area.set_interaction_enabled(enabled)
		if not enabled: game._remove_interaction_candidate(area)
	game.interaction_focus_dirty = true

func _allows(rule: Dictionary) -> bool:
	var q := str(rule.get("quest",""))
	if q != "" and not (game.quests.is_active(q) or game.quests.is_completed(q)): return false
	for closed: String in rule.get("before", []):
		if game.quests.is_completed(closed): return false
	for id: String in rule.get("complete", []):
		if not game.quests.is_completed(id): return false
	for pair: Array in rule.get("objectives", []):
		if not game.quests.is_objective_done(str(pair[0]), str(pair[1])): return false
	for key: String in rule.get("flags", {}):
		if game.story_state.get_flag(key, null) != rule.flags[key]: return false
	for key: String in rule.get("unless", {}):
		if game.story_state.get_flag(key, null) == rule.unless[key]: return false
	return true

func _station(key: String, index: int, beat: Dictionary) -> Node3D:
	var id := "novel_" + key + "_" + str(index)
	if stations.has(id): return stations[id]
	var ground := Vector3(beat.at[0], 0, beat.at[1])
	owner_director._point(game.zone_root, id, str(beat.prompt), ground, "", Color.WHITE)
	var area := game.zone_root.find_child(id, true, false) as Node3D
	area.state_label = str(beat.prompt)
	area.display_name = str(beat.get("place",turns[key].scene.title))
	area.set_meta("novel_scene", key)
	area.set_meta("novel_index", index)
	Tableau.dress(area, str(beat.get("object","")), float(beat.get("height",0)))
	stations[id] = area
	return area

func _actor_id(area: Node3D) -> String:
	if area.has_meta("community_actor_id"):
		return str(preload("res://scripts/community_campaign.gd").ACTORS.get(str(area.get_meta("community_actor_id")), ""))
	return str(area.get("interaction_id"))

func invitations(area: Node3D, content: Dictionary) -> void:
	for key: String in turns:
		var turn: Dictionary = turns[key]
		if str(turn.beat.get("actor", "")) == _actor_id(area):
			content.actions.append({"type":"novel_visit","label":turn.beat.prompt,"id":key,"index":turn.index,"source":area.get_instance_id()})

func _valid(key: String, index: int, area: Node3D) -> bool:
	if not is_instance_valid(area) or not is_instance_valid(game.player) or not turns.has(key): return false
	var turn: Dictionary = turns[key]
	if game.zone_transition_pending or game.current_zone_id != zone or owner_director.get_parent() != game.zone_root or not game.zone_root.is_ancestor_of(area): return false
	if not area.is_visible_in_tree() or not area.is_interaction_enabled() or game.player.global_position.distance_to(area.global_position) > 3.6 or game._story_has_active_combat(): return false
	if index != int(game.story_state.get_flag("novel_step_"+key,0)) or index != turn.index or not _allows(turn.scene.get("when", {})) or not _allows(turn.beat.get("when", {})): return false
	if turn.beat.has("actor"): return _actor_id(area) == str(turn.beat.actor)
	return str(area.get_meta("novel_scene","")) == key and int(area.get_meta("novel_index",-1)) == index

func activate(key: String, index: int, area: Node3D) -> void:
	if not _valid(key,index,area) or not pending.is_empty(): return
	var beat: Dictionary = turns[key].beat
	var choices: Array = beat.get("choices", [])
	if beat.get("mechanic","") == "alarm":
		_strike(key,index,area)
		return
	if beat.has("actor") or not choices.is_empty():
		generation += 1
		var actions: Array[Dictionary] = []
		var offered: Array = []
		for option: Dictionary in choices:
			if _allows(option.get("when",{})): offered.append(option)
		if choices.is_empty(): offered.append({"label":beat.get("reply","Listen"),"result":beat.get("result","")})
		for i in offered.size():
			actions.append({"type":"novel_reply","label":offered[i].label,"index":i,"generation":generation})
		actions.append({"type":"close","label":"Leave it for now"})
		var page := {"speaker":beat.get("speaker","Kael"),"speaker_id":beat.get("actor","player"),"text":beat.get("line",beat.prompt)}
		var content := {"name":turns[key].scene.title,"pages":[page],"actions":actions}
		if beat.has("actor"):
			game._stage_dialogue_moment(area)
			preload("res://scripts/story_performance.gd").begin(area,game.player,content,game.story_state)
		game.get_tree().paused = true
		game.audio.set_game_paused(true)
		game.hud.show_dialogue(content)
		menu = {"key":key,"index":index,"area":weakref(area),"options":offered,"view":game.hud._dialogue_view_generation}
	else:
		_begin_work(key,index,area,{})

func reply(action: Dictionary) -> void:
	var selected := int(action.get("index",-1))
	if menu.is_empty() or int(action.get("generation",-1)) != generation or game.hud.dialogue_layer.visible or game.hud._dialogue_view_generation != int(menu.view)+1: return
	var request := menu
	menu = {}
	game._resume_game()
	if selected < 0 or selected >= request.options.size(): return
	var area: Node3D = request.area.get_ref()
	var option: Dictionary = request.options[selected]
	if _valid(request.key,request.index,area) and _allows(option.get("when",{})):
		_begin_work(request.key,request.index,area,option)

func _refresh_burden() -> void:
	if not is_instance_valid(game.player): return
	var kind := ""
	var returning := int(game.story_state.get_flag("novel_step_willow_frame",0))
	if returning in [2,3]: kind = "frame"
	if int(game.story_state.get_flag("novel_step_culvert",0)) == 3: kind = "frame"
	if int(game.story_state.get_flag("novel_step_loaded_ground",0)) == 1: kind = "load"
	var prop := game.player.get_node_or_null("NovelBurden") as Node3D
	if prop != null and prop.get_meta("kind","") == kind: return
	if prop != null:
		game.player.remove_child(prop)
		prop.queue_free()
	if kind.is_empty(): return
	prop = Tableau.dress(game.player,kind)
	prop.name = "NovelBurden"
	prop.set_meta("kind",kind)
	prop.position = Vector3(-0.43,0.72,0.26)
	prop.rotation.z = -0.08

func _strike(key: String, index: int, area: Node3D) -> void:
	if alarm_count > 0 and alarm_silence < 0.23: return
	game.audio.play_event("shrine_bell",0.03)
	if alarm_count == 3 and alarm_silence < 1.0:
		alarm_count = 0
		alarm_silence = 0.0
		game.hud.set_guidance_hint("Let the third note die before the second group. Start again.",3)
		return
	alarm_count += 1
	alarm_silence = 0.0
	if alarm_count < 6:
		game.hud.set_guidance_hint("Three. Leave a breath of silence." if alarm_count == 3 else "%d of three" % ((alarm_count-1)%3+1),2)
		return
	alarm_count = 0
	_begin_work(key,index,area,{})

func _begin_work(key: String, index: int, area: Node3D, option: Dictionary) -> void:
	var beat: Dictionary = turns[key].beat
	pending = {"key":key,"index":index,"area":weakref(area),"option":option}
	work_start = game.player.global_position
	elapsed = 0.0
	if float(beat.get("seconds",0)) <= 0:
		_finish()
		return
	if game.player.animation_driver != null:
		game.player.animation_driver.trigger_action("story_offer",1.0,0.12,false,float(beat.seconds))
	game.hud.set_guidance_hint(str(beat.get("working",beat.prompt)),float(beat.seconds))

func _physics_process(delta: float) -> void:
	if alarm_count > 0: alarm_silence += delta
	if pending.is_empty(): return
	var area: Node3D = pending.area.get_ref()
	if not _valid(pending.key,pending.index,area) or not game.player.can_control or game.player.global_position.distance_to(work_start) > 0.55:
		cancel()
		return
	elapsed += delta
	if elapsed >= float(turns[pending.key].beat.get("seconds",0)): _finish()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE, NOTIFICATION_APPLICATION_FOCUS_OUT]: cancel()

func cancel() -> void:
	if pending.is_empty(): return
	pending = {}
	if is_instance_valid(game) and is_instance_valid(game.player) and game.player.animation_driver != null and game.player.animation_driver.current_state == "story_offer":
		game.player.animation_driver.stop_action("idle",0.12)

func _finish() -> void:
	var request := pending
	var turn: Dictionary = turns[request.key]
	var beat: Dictionary = turn.beat
	var option: Dictionary = request.option
	cancel()
	var state = game.story_state
	state.begin_change()
	if beat.has("actor"):
		state.set_flag("novel_heard_"+str(beat.actor)+"_"+str(request.key),true)
	state.set_flag("novel_step_"+str(request.key),int(request.index)+1)
	if option.get("set",{}).get("novel_season") == "spring" and state.get_flag("novel_season","") != "spring":
		game.day_night.set_time(game.day_night.get_time(),int(game.day_night.day_count)+180)
	for outcome: Dictionary in [beat,option]:
		for key: String in outcome.get("set", {}): state.set_flag(key,outcome.set[key])
		if outcome.has("evidence"): state.record_evidence("novel:"+str(outcome.evidence.id),{"zone":zone,"title":outcome.evidence.title,"text":outcome.evidence.text,"kind":outcome.evidence.get("kind","observed")})
	if int(request.index)+1 == turn.scene.beats.size():
		state.set_flag("novel_done_"+str(request.key),true)
		preload("res://scripts/novel/novel_campaign.gd").finish_scene(game.quests,str(request.key))
	state.end_change()
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	refresh()
	var words := str(option.get("result",beat.get("result","")))
	if turns.has(request.key):
		words += "  " + str(turns[request.key].beat.prompt) + "."
	if words != "": game.hud.set_guidance_hint(words,7.0)
