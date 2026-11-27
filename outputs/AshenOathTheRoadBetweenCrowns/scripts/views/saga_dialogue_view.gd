extends RefCounted
var _activities: Node3D
func _init(activities: Node3D) -> void:
	_activities = activities
func append_cast_topics(actor: Node3D, content: Dictionary, exclude_id: String = "") -> void:
	var identity_id: Variant = _activities.CastProfile.canonical_identity(str(_activities.read_tag(actor, "story_cast_identity", actor.name)))
	if identity_id == "":
		return
	var actions: Array = content.get("actions", [])
	for id: String in _activities.Catalog.PEOPLE:
		if id == exclude_id or _activities.CastProfile.canonical_identity(id) != identity_id:
			continue
		var point: Node3D = _activities.points.get(id)
		if not is_instance_valid(point) or not bool(_activities.read_tag(point, "saga_wanted", false)):
			continue
		var title: Variant = "The work here"
		for quest_id: String in _activities.Catalog.QUESTS:
			var quest: Dictionary = _activities.Catalog.quest_row(quest_id,_activities.host.story_state)
			if str(quest.get("actor", "")) == id and _activities._quest_zone(quest_id) == _activities.zone and _activities._available(quest):
				title = str(quest.title)
				if not _activities.host.quests.is_completed(quest_id):
					break
		actions.append({"type":"saga_action", "operation":"person_topic", "label":"About " + title, "area":point.get_instance_id()})
	content["actions"] = actions

func activate(id: String) -> void:
	var area: Node3D = _activities.points.get(id)
	if not _activities._within_reach(area):
		return
	if id.begins_with("saga_secret:"):
		_activities._open_secret(area, id.trim_prefix("saga_secret:"))
		return
	if id.begins_with("saga_return:"):
		var prefix: Variant = id.trim_prefix("saga_return:")
		_activities.host.progression.claim_saga_return(prefix, _activities.host.quests)
		_activities._open(area, str(_activities.Catalog.WORLDS[prefix].name), _activities._aftermath_text("saga_" + prefix + "_q05"), [])
		_activities._persist()
		return
	if _activities.Catalog.PEOPLE.has(id):
		_activities._open_person(area, id)
		return
	if id.begins_with("saga_bog_") or id == "saga_senn_challenge":
		_activities.Encounters.activate(_activities.host, id, area)
		return
	var quest_id: Variant = id.get_slice(":", 0)
	if not _activities.Catalog.QUESTS.has(quest_id):
		return
	var quest: Dictionary = _activities.Catalog.quest_row(quest_id,_activities.host.story_state)
	if bool(_activities.read_tag(area, "saga_early_clue", false)):
		for clue_step: Array in quest.steps:
			if str(clue_step[0]) != id.get_slice(":", 1):
				continue
			var index: Variant = int(_activities.read_tag(area, "saga_inspect_index", -1))
			if index < 0 or index >= clue_step[4].size():
				return
			var action: Variant = _activities._action(area, "observe", quest_id, str(area.prompt))
			action["clue_objective"] = str(clue_step[0])
			action["inspect_index"] = index
			_activities._open(area, str(quest.title), _activities.Catalog.observation(quest_id, clue_step, index,_activities.host.story_state), [action])
			return
	if id.ends_with(":offer"):
		_activities._open(area, str(quest.title), _activities.Catalog.opening(quest_id,_activities.host.story_state), [_activities._action(area, "accept", quest_id, "Offer a hand")])
		return
	if id.ends_with(":after"):
		_activities._collect_delivery(quest_id)
		_activities._open(area, str(quest.title), _activities._aftermath_text(quest_id), [])
		return
	var step: Variant = _activities._step(quest_id)
	if step.is_empty() or str(step[0]) != id.get_slice(":", 1):
		return
	var mode: Variant = str(step[3])
	if mode == "walk":
		_activities.host.hud.toast("Check the marked place on foot. Reading a marker does not count as walking the route.")
		return
	if mode == "homecoming" and not _activities._flag("aftermath_walk_completed"):
		_activities.host.hud.toast("Finish your existing return: speak with Anwen, do the bench work and reflect at the road. Nera will wait at arrivals.")
		return
	if mode == "signal" and (id.ends_with(":far") or id.ends_with(":near")):
		_activities.host.hud.toast("Check the far marker on foot, then return to the near post.")
		return
	if mode in ["choice", "signal"]:
		var actions: Array = []
		for outcome: String in step[4]:
			if _activities._choice_allowed(quest_id, outcome):
				var action: Variant = _activities._action(area, "choice", quest_id, str(step[4][outcome]))
				action["outcome"] = outcome
				actions.append(action)
		_activities._open(area, str(quest.title), str(step[1]), actions)
	elif mode == "escort":
		_activities._start_escort(quest_id, step, area)
	elif mode in ["work", "carry", "door", "bell"]:
		if quest_id == "saga_gre_q04" and str(step[0]) == "return_kettle" and str(_activities.host.story_state.get_flag(quest_id + "_outcome", "")) == "replayed" and not _activities._flag("saga_gre_q04:round_played"):
			_activities.host.hud.toast("Play one ordinary Three Marks round at the common table. Winning is not required.")
		else:
			_activities._begin_work(quest_id, step, area)
	elif mode == "return" and not _activities._flag(quest_id + ":left_work_area"):
		_activities.host.hud.toast("Leave the quiet work area before returning to inspect fresh signs.")
	elif quest_id == "saga_gre_q04" and str(step[0]) == "return_kettle" and str(_activities.host.story_state.get_flag(quest_id + "_outcome", "")) == "replayed" and not _activities._flag("saga_gre_q04:round_played"):
		_activities.host.hud.toast("Play one ordinary Three Marks round at the common table. Winning is not required.")
	else:
		var part: Variant = _activities._part(quest_id, str(step[0]))
		var account: Variant = _activities._account(quest_id, step)
		if step[4] is Array and step[4].size() > 1:
			account = str(area.prompt) + ".\n\n" + account
		var action: Variant = _activities._action(area, "work" if mode in ["work", "carry", "door", "bell"] else "advance", quest_id, str(area.prompt), part)
		if area.has_meta("saga_inspect_index"):
			var index: Variant = int(_activities.read_tag(area, "saga_inspect_index"))
			action["inspect_index"] = index
			account = _activities.Catalog.observation(quest_id, step, index,_activities.host.story_state)
		var performance: Dictionary = _activities.Catalog.performance(quest_id)
		var dialogue: Dictionary = performance.get("dialogue_" + str(_activities.host.story_state.get_flag(quest_id + "_outcome", "")), performance.get("dialogue", {}))
		var lines: Array = dialogue.get(str(step[0]), [])
		var pages: Array = _activities.host.dialogue._build_pages({"name":quest.title, "lines":lines}) if mode in ["talk", "homecoming"] and not lines.is_empty() else []
		_activities._open(area, str(quest.title), account, [action], _activities._nearby_speaker(quest_id) if mode in ["talk", "homecoming"] else "narrator", "", pages)

func _open_person(area: Node3D, id: String) -> void:
	if not _activities._flag(id + "_met"):
		_activities.host.story_state.set_flag(id + "_met", true)
		_activities._persist()
	var person: Dictionary = _activities.Catalog.PEOPLE[id]
	var actions: Array = []
	var finished: Variant = false
	var remembered: Variant = ""
	for quest_id: String in _activities.Catalog.QUESTS:
		var quest: Dictionary = _activities.Catalog.quest_row(quest_id,_activities.host.story_state)
		if str(quest.get("actor", "")) != id or _activities._quest_zone(quest_id) != _activities.zone or not _activities._available(quest):
			continue
		finished = finished or _activities.host.quests.is_completed(quest_id)
		if _activities.host.quests.is_completed(quest_id):
			remembered = _activities._aftermath_text(quest_id)
		if not _activities.host.quests.is_active(quest_id) and not _activities.host.quests.is_completed(quest_id):
			actions.append(_activities._action(area, "offer", quest_id, str(quest.title)))
		elif _activities.host.quests.is_active(quest_id):
			actions.append(_activities._action(area, "directions", quest_id, "About " + str(quest.title)))
	var written: bool = (id=="saga_odran" and _activities.Catalog.Garden.active("saga_var_q03",_activities.host.story_state) and _activities.host.story_state.get_flag("novel_pell_care","")!="elna") or (bool(person.get("alias", false)) and not bool(_activities.read_tag(area, "saga_alias_present", false))) or (id == "saga_odran" and _activities.host.quests.is_completed("saga_var_q03") and str(_activities.host.story_state.get_flag("saga_var_q03_outcome", "")) == "departed")
	if not written and bool(_activities.host.story_state.honor_view(id).known):
		actions.append(_activities._action(area, "honor", "", "How do things stand between us?"))
	var words: Variant = str(_activities.Catalog.GREETINGS.get(id, person.line)) if finished else str(person.line)
	if id in ["saga_iven", "saga_edda"] and _activities.host.quests.is_completed("saga_wyc_q05"):
		var water_outcome: Variant = str(_activities.host.story_state.get_flag("saga_wyc_q05_outcome", ""))
		var acknowledgement: Variant = str(_activities.Catalog.performance("saga_wyc_q05").get("return_lines", {}).get(id, {}).get(water_outcome, ""))
		if acknowledgement != "":
			words = acknowledgement
			remembered = _activities._aftermath_text("saga_wyc_q05")
	if id == "saga_odran" and _activities.Catalog.Garden.active("saga_var_q03",_activities.host.story_state):
		words = "Three marks from three hired hands. I can show the duplicated charges and the tool bond. The choice of work is theirs." if not written else "Toma’s filed petition carries three marks. The workers’ tool bonds have been settled."
	if id == "saga_maren":
		words = _activities._maren_greeting()
	if not written and bool(_activities.host.story_state.honor_view(id).grievance):
		words = str(_activities.host.story_state.honor_view(id).reaction)
	if written:
		words = "Previously authorized note from " + str(person.name) + ":\n" + ("My tools and traveling tray were returned. I have left by my own choice. The offered seed labels remain available to inspect." if id == "saga_odran" else words)
	_activities._open(area, str(person.name) + (" - recorded note" if written else ""), words, actions, "narrator" if written else id, remembered)

func _maren_greeting() -> String:
	if _activities.host.quests.is_completed("side_escort_06"):
		var outcome: Variant = str(_activities.host.story_state.get_flag("side_escort_06_outcome", ""))
		var parting: Variant = "The next route is mine to choose. Supper can just be supper." if outcome == "company" else "The next route is mine to choose. We can work together without sharing the rest."
		return str(_activities.Catalog.aftermath("side_escort_06", outcome)) + "\n\nNera: '" + parting + "'"
	if _activities.host.quests.is_completed("side_escort_05"):
		return "You corrected your own account. Mine says what I gave it, and no more. There is still a load to hand over after your business in the glade."
	if _activities.host.quests.is_completed("side_escort_04"):
		return "All of us crossed. That matters. It is not the same as having come back for us then."
	if _activities.host.quests.is_completed("side_escort_01"):
		return "I have a crew to think about. Ask me about the work we are doing now, Kael. The old road is not going anywhere."
	return str(_activities.Catalog.PEOPLE.saga_maren.line)

func _action(area: Node3D, operation: String, quest_id: String, label: String, part: int = -1) -> Dictionary:
	var step: Variant = _activities._step(quest_id)
	return {"type":"saga_action", "label":label, "operation":operation, "quest":quest_id, "area":area.get_instance_id(), "objective":str(step[0]) if not step.is_empty() else "", "part":part if part >= 0 else (_activities._part(quest_id, str(step[0])) if not step.is_empty() else 0)}

func _nearby_speaker(id: String) -> String:
	var speaker: Variant = str(_activities.Catalog.quest_row(id,_activities.host.story_state).get("actor", ""))
	var person: Node3D = _activities.points.get(speaker)
	if not is_instance_valid(person) or (person.get_node_or_null("Person") == null and not bool(_activities.read_tag(person, "saga_alias_present", false))) or not person.is_visible_in_tree() or person.global_position.distance_to(_activities.host.player.global_position) > 5.0:
		return "narrator"
	return speaker

func _open(area: Node3D, title: String, text: String, actions: Array, speaker_id: String = "narrator", recall: String = "", pages: Array = []) -> void:
	_activities._cancel_work()
	var content: Variant = {"name":title, "pages":[{"speaker":str(_activities.Catalog.PEOPLE.get(speaker_id, {}).get("name", title)), "speaker_id":speaker_id, "text":text, "performance":load("res://scripts/story_scene_direction.gd").for_regional(speaker_id)}], "actions":actions}
	if _activities.Catalog.PEOPLE.has(speaker_id):
		_activities.append_cast_topics(area, content, speaker_id)
	if _activities.Catalog.PEOPLE.has(speaker_id) and not bool(_activities.read_tag(area,"saga_topic_only",false)) and speaker_id != "narrator":
		var novel: Node = preload("res://scripts/novel/novel_scenes.gd").current(_activities.host)
		if novel != null: novel.invitations(area,content)
	if not pages.is_empty():
		content["pages"] = pages
		for page: Dictionary in pages:
			page["performance"] = load("res://scripts/story_scene_direction.gd").for_regional(str(page.get("speaker_id", "narrator")))
	if recall != "":
		content.pages.append({"speaker":"Work you completed", "speaker_id":"narrator", "text":recall, "performance":{"framing":"two_shot"}})
	if speaker_id != "narrator":
		var speaker: Node3D = _activities.points.get(speaker_id, area)
		var aliased: Variant = instance_from_id(int(_activities.read_tag(speaker, "saga_actor_instance", 0))) as Node3D
		if is_instance_valid(aliased) and _activities.host.zone_root.is_ancestor_of(aliased) and aliased.is_visible_in_tree():
			speaker = aliased
			content.pages[0]["speaker_actor_id"] = aliased.get_instance_id()
		if _activities.Catalog.PEOPLE.has(speaker_id) and not _activities._flag(speaker_id + "_met"):
			_activities.host.story_state.set_flag(speaker_id + "_met", true)
			_activities._persist()
		_activities.host._stage_dialogue_moment(speaker)
		load("res://scripts/story_performance.gd").begin(speaker, _activities.host.player, content, _activities.host.story_state)
	_activities.host.get_tree().paused = true
	_activities.host.audio.set_game_paused(true)
	var introduction_key: Variant = _activities.CastProfile.introduce(_activities.host, speaker_id, content) if speaker_id != "narrator" else ""
	_activities.host.hud.show_dialogue(_activities.host._prepare_dialogue_presence(content))
	_activities.CastProfile.remember_introduction(_activities.host, introduction_key)

func choose(action: Dictionary) -> void:
	var area: Variant = instance_from_id(int(action.get("area", 0))) as Node3D
	if is_instance_valid(area) and bool(_activities.read_tag(area, "saga_topic_only", false)):
		var actor: Variant = instance_from_id(int(_activities.read_tag(area, "saga_actor_instance", 0))) as Node3D
		if not is_instance_valid(actor) or not _activities.host.zone_root.is_ancestor_of(actor) or not actor.is_visible_in_tree():
			_activities.host._resume_game()
			return
		area.global_position = actor.global_position
	if not _activities._within_reach(area):
		_activities.host._resume_game()
		return
	var operation: Variant = str(action.get("operation", ""))
	if operation == "person_topic" and _activities.Catalog.PEOPLE.has(str(area.interaction_id)):
		_activities._open_person(area, str(area.interaction_id))
		return
	if operation == "honor" and _activities.Catalog.PEOPLE.has(str(area.get("interaction_id"))):
		var person_id: Variant = str(area.get("interaction_id"))
		_activities._open(area, str(_activities.Catalog.PEOPLE[person_id].name), str(_activities.host.story_state.honor_view(person_id).reaction), [], person_id)
		return
	if operation == "secret":
		if str(area.interaction_id) != "saga_secret:" + str(action.get("secret", "")):
			return
		_activities.host._resume_game()
		_activities._claim_secret(str(action.get("secret", "")), bool(action.get("sealed", false)))
		return
	var id: Variant = str(action.get("quest", ""))
	var quest: Dictionary = _activities.Catalog.quest_row(id,_activities.host.story_state)
	if quest.is_empty() or _activities._quest_zone(id) != _activities.zone or not _activities._available(quest):
		_activities.host._resume_game()
		return
	if operation == "offer":
		_activities._open(area, str(quest.title), _activities.Catalog.opening(id,_activities.host.story_state), [_activities._action(area, "accept", id, "Offer a hand")])
		return
	if operation == "observe" and bool(quest.get("early_clues", false)):
		var objective: Variant = str(action.get("clue_objective", ""))
		var index: Variant = int(action.get("inspect_index", -1))
		if str(area.interaction_id) != id + ":" + objective + ":inspect:" + str(index) or int(_activities.read_tag(area, "saga_inspect_index", -1)) != index:
			return
		_activities.host._resume_game()
		_activities.host.story_state.set_flag(id + ":" + objective + ":seen:" + str(index), true)
		_activities._resume_known_inspections(id)
		_activities._commit()
		return
	if operation == "directions":
		var step: Variant = _activities._step(id)
		_activities._open(area, str(quest.title), str(step[1]) + ". The current work is marked in your journal.", [])
		return
	_activities.host._resume_game()
	if operation == "accept":
		if not _activities.host.quests.is_active(id) and not _activities.host.quests.is_completed(id):
			_activities.host.quests.unlocked[id] = true
			_activities.host.quests.start_quest(id)
			_activities._resume_known_inspections(id)
			_activities._commit()
		return
	var step: Variant = _activities._step(id)
	if step.is_empty() or str(step[0]) != str(action.get("objective", "")) or _activities._part(id, str(step[0])) != int(action.get("part", -1)):
		return
	if str(step[3]) == "homecoming" and not _activities._flag("aftermath_walk_completed"):
		return
	if operation == "choice":
		var outcome: Variant = str(action.get("outcome", ""))
		if not step[4] is Dictionary or not step[4].has(outcome) or not _activities._choice_allowed(id, outcome):
			return
		if str(step[3]) == "signal":
			_activities.host.story_state.set_flag(id + "_outcome", outcome)
			_activities.host.story_state.set_flag(id + ":signal_mode_set", true)
			_activities.host.hud.toast("Walk to the far marker, then return to check the line.")
			_activities._commit()
			return
		_activities._complete_step(id, step, outcome)
	elif operation == "work":
		_activities._begin_work(id, step, area)
	else:
		if action.has("inspect_index"):
			var index: Variant = int(action.inspect_index)
			if int(_activities.read_tag(area, "saga_inspect_index", -1)) != index or index < 0 or index >= step[4].size() or _activities._flag(id + ":" + str(step[0]) + ":seen:" + str(index)):
				return
			_activities.host.story_state.set_flag(id + ":" + str(step[0]) + ":seen:" + str(index), true)
		_activities._advance_part(id, step)

func _choice_allowed(id: String, outcome: String) -> bool:
	if id != "saga_dep_q05":
		return true
	var operation: Variant = str(_activities.host.story_state.get_flag("mill_operation", ""))
	return outcome == "workshop" or (outcome == "relief_store" and operation == "closed") or (outcome == "checking_station" and operation not in ["", "closed"])

func _outcome_name(id: String) -> String:
	return str(_activities.host.story_state.get_flag(id + "_outcome", "recorded")).replace("_", " ")

func _aftermath_text(id: String) -> String:
	var text: Variant = _activities.Catalog.aftermath(id, str(_activities.host.story_state.get_flag(id + "_outcome", "")),_activities.host.story_state)
	if str(_activities.host.story_state.get_flag(id + "_outcome", "")) in ["coerced", "falsified", "conditional_pass"]:
		text = str(_activities._method_step(id, _activities.Catalog.quest_row(id,_activities.host.story_state).steps.back())[5])
	if id == "saga_har_q05":
		text += "\nCovenant: " + str(_activities.host.story_state.get_flag("final_covenant", "")) + ". The original journey home remains separate."
	return text
