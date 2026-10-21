extends Node3D

## Optional regional work hosted by StoryActivityDirector. This node owns only
## live staging; all durable steps, choices, deliveries and XP use existing services.
const Catalog = preload("res://scripts/saga_catalog.gd")
const Interactable = preload("res://scripts/interactable.gd")
const Records = preload("res://scripts/campaign_record_presentation.gd")
const Encounters = preload("res://scripts/saga_encounters.gd")
const WorkPresentation = preload("res://scripts/saga_work_presentation.gd")
var host
var zone := ""
var points: Dictionary = {}
var _refresh_pending := false
var _refreshing := false
var _work: Dictionary = {}
var _elapsed := 0.0
var _escort: Node3D
var _escort_drivers: Array[Node] = []
var _escort_path: Array[Vector3] = []
var _escort_index := 0
var _used_positions: Array[Vector3] = []
var _site_positions: Dictionary = {}

static func install(game, director: Node, zone_id: String) -> void:
	var owner := director.get_node_or_null("SixWorldStories")
	if owner == null:
		owner = load("res://scripts/saga_activities.gd").new()
		owner.name = "SixWorldStories"
		owner.host = game
		owner.zone = zone_id
		director.add_child(owner)
		game.story_state.changed.connect(owner.queue_refresh)
		game.quests.changed.connect(owner.queue_refresh)
	owner.refresh()

func queue_refresh() -> void:
	if _refresh_pending or not is_inside_tree():
		return
	_refresh_pending = true
	call_deferred("refresh")

func refresh() -> void:
	_refresh_pending = false
	if _refreshing or host == null or not is_instance_valid(host.zone_root) or not host.zone_root.is_ancestor_of(self) or zone != str(host.current_zone_id):
		return
	_refreshing = true
	_reconcile_rewards()
	for point: Node3D in points.values():
		point.set_meta("saga_wanted", false)
	for id: String in Catalog.PEOPLE:
		var person: Dictionary = Catalog.PEOPLE[id]
		if str(person.zone) == zone and (zone != "ruins" or _late_road_open()):
			var area := _point(id, "Speak with " + str(person.name), str(person.site), "person")
			if bool(person.get("alias", false)):
				var worker := host.zone_root.find_child("MillWorkerBody0", true, false) as Node3D
				if worker != null and worker.is_visible_in_tree():
					area.global_position = worker.global_position
					worker.set_meta("story_actor_alias", "saga_dain")
					area.set_meta("saga_alias_present", true)
				else:
					area.set_meta("saga_alias_present", false)
					if area.get_node_or_null("WorkProp") == null:
						_add_work_prop(area, "record")
			elif id == "saga_odran" and host.quests.is_completed("saga_var_q03") and str(host.story_state.get_flag("saga_var_q03_outcome", "")) == "departed":
				var body := area.get_node_or_null("Person") as Node3D
				if body != null:
					body.visible = false
				if area.get_node_or_null("WorkProp") == null:
					_add_work_prop(area, "record")
			elif area != null and area.get_node_or_null("Person") == null:
				_add_person(area, person, id)
	for id: String in Catalog.QUESTS:
		var quest: Dictionary = Catalog.QUESTS[id]
		if str(quest.zone) != zone or not _available(quest):
			continue
		if host.quests.is_completed(id):
			var completed := _point(id + ":after", "Read " + str(quest.title) + " - " + _outcome_name(id), str(quest.site), "aftermath")
			if completed != null:
				_dress_aftermath(completed, id)
				if id in ["saga_gre_q05", "saga_roa_q05"]:
					for escort_step: Array in quest.steps:
						if str(escort_step[3]) == "escort":
							_restore_escort(id, escort_step, completed)
			continue
		if not host.quests.is_active(id):
			_point(id + ":offer", "Read request: " + str(quest.title), str(quest.site), "record")
			continue
		var step := _step(id)
		if step.is_empty():
			continue
		var objective := str(step[0])
		var site := str(step[2])
		var part := _part(id, objective)
		var mode := str(step[3])
		var prompt := str(step[1])
		if mode == "inspect" and step[4].size() > 1:
			for index in range(step[4].size()):
				if _flag(id + ":" + objective + ":seen:" + str(index)):
					continue
				var inspected := _point(id + ":" + objective + ":inspect:" + str(index), "Inspect " + str(step[4][index]), site, "record")
				if inspected != null:
					inspected.set_meta("saga_inspect_index", index)
			continue
		if mode == "carry":
			var stages: Array = step[4]
			if part < stages.size():
				if part % 2 == 1:
					site = str(stages[part])
					prompt = "Place " + str(stages[part - 1])
				else:
					prompt = "Take " + str(stages[part])
		elif step[4] is Array and not step[4].is_empty():
			prompt = str(step[4][mini(part, step[4].size() - 1)])
		var area := _point(id + ":" + objective, prompt, site, _prop_kind(mode, prompt))
		if area != null:
			area.set_meta("saga_quest", id)
			area.set_meta("saga_objective", objective)
			area.set_meta("saga_part", part)
			# Reposition held-work destinations rather than leaving the old pickup
			# location active after a reload or a carried-piece transaction.
			if str(area.get_meta("saga_site", "")) != site:
				area.position = _site_position(site, str(area.interaction_id))
				area.set_meta("saga_site", site)
			if mode in ["work", "bell", "door"] and area.get_node_or_null("RegionalWork") == null:
				var old_prop := area.get_node_or_null("WorkProp")
				if old_prop != null:
					old_prop.visible = false
				WorkPresentation.build(host, area, id, false, str(host.story_state.get_flag(id + "_outcome", "")))
			if mode == "escort":
				_restore_escort(id, step, area)
	for id: String in Catalog.SECRETS:
		var secret: Array = Catalog.SECRETS[id]
		if str(secret[0]) == zone and _secret_available(secret):
			_point("saga_secret:" + id, "Inspect " + str(secret[1]).replace("_", " ") + " clue", str(secret[1]), "record")
	for prefix: String in Catalog.WORLDS:
		var world: Dictionary = Catalog.WORLDS[prefix]
		if zone == str(world.home):
			var q05 := "saga_" + prefix + "_q05"
			if host.quests.is_completed(q05):
				_point("saga_return:" + prefix, "Visit the changed work at " + str(world.name), str(Catalog.QUESTS[q05].site), "record")
	Encounters.refresh(host, self)
	for point: Node3D in points.values():
		var wanted := bool(point.get_meta("saga_wanted", false))
		point.visible = wanted
		point.set_interaction_enabled(wanted)
		if not wanted:
			host._remove_interaction_candidate(point)
			# Keep the completed physical work in the world without leaving an
			# obsolete Use target. Its local geometry is projected at the same spot.
			var work := point.get_node_or_null("RegionalWork")
			if work != null and point.has_meta("saga_quest") and host.quests.is_objective_done(str(point.get_meta("saga_quest")), str(point.get_meta("saga_objective"))):
				point.visible = true
	host.interaction_focus_dirty = true
	_refreshing = false

func _point(id: String, prompt: String, site: String, kind: String) -> Node3D:
	var point: Node3D = points.get(id)
	if point == null:
		point = Interactable.new()
		point.setup(id.replace(":", "_"), "story_activity", prompt)
		point.interaction_id = id
		point.dialogue_id = id
		point.name = id.replace(":", "_")
		point.position = _site_position(site, id)
		point.set_meta("saga_site", site)
		point.build_collision(0.75)
		add_child(point)
		points[id] = point
		var label := Label3D.new()
		label.name = "InteractionWorldLabel"
		label.visible = false
		label.text = prompt
		label.position.y = 1.45
		label.font_size = 20
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		point.add_child(label)
		if kind != "person":
			_add_work_prop(point, kind)
		host._connect_interactable(point)
	point.prompt = prompt
	point.display_name = prompt
	point.set_meta("saga_wanted", true)
	return point

func _site_position(site: String, id: String) -> Vector3:
	var key := site + ":" + id
	if _site_positions.has(key):
		return _site_positions[key]
	var base: Vector3 = Catalog.SITES.get(zone, {}).get(site, Vector3(3, 0, 8))
	var offset := Vector3.ZERO
	# Spread work within its authored shoulder; no solid prop or invented floor
	# is added to the main route. All pieces retain the same bank as their site.
	var seed := absi(id.hash()) % 7
	for index in range(24):
		var angle := float((index + seed) % 8) * TAU / 8.0
		var radius := 0.0 if index == 0 else 0.8 + floorf(float(index - 1) / 8.0) * 0.65
		offset = Vector3(cos(angle), 0, sin(angle)) * radius
		var candidate := base + offset
		if host.spatial_service != null and not host.spatial_service.is_walkable_position(candidate, 0.55, host.spatial_service.bank_for(base)):
			continue
		var free := true
		for used: Vector3 in _used_positions:
			if used.distance_squared_to(candidate) < 0.55 * 0.55:
				free = false
				break
		if free:
			_used_positions.append(candidate)
			_site_positions[key] = candidate
			return candidate
	# Never silently put a required action in a wall. The existing validated
	# nearest-safe search supplies a reachable fallback on this bank.
	var result: Vector3 = host.spatial_service.validate_position(base, 0.55, host.spatial_service.bank_for(base)) if host.spatial_service != null else base
	_used_positions.append(result)
	_site_positions[key] = result
	return result

func _add_person(area: Node3D, person: Dictionary, id: String) -> void:
	var visual: Node3D = host.asset_helper.spawn_visual_role(str(person.role), "characters", id)
	if visual == null:
		push_error("Required saga person unavailable: " + id)
		return
	visual.name = "Person"
	area.add_child(visual)
	host._configure_npc_animation(visual, id)
	area.set_meta("saga_person", id)
	area.set_meta("protected_optional_speaker", true)
	if zone == "greyfen":
		load("res://scripts/character_presentation.gd").apply_npc(visual, id, false)
		var ambient = load("res://scripts/npc_ambient.gd").new()
		ambient.name = "NpcAmbient"
		ambient.setup(id, host.player, host)
		area.add_child(ambient)

func _add_work_prop(area: Node3D, kind: String) -> void:
	var visual: Node3D
	if kind in ["record", "aftermath"]:
		visual = Records.make_visual("register_mira")
	elif kind == "stone":
		visual = host._make_role_visual("forest_rock", "environment", Vector3.ONE * 0.16)
	else:
		visual = host._make_role_visual("crate" if kind == "load" else "barrel", "environment", Vector3.ONE * 0.20)
	if visual != null:
		visual.name = "WorkProp"
		area.add_child(visual)
		visual.position.y = 0.06

func _prop_kind(mode: String, prompt: String) -> String:
	if mode in ["inspect", "talk", "choice", "signal", "return"]:
		return "record"
	if prompt.to_lower().contains("stone"):
		return "stone"
	return "load" if mode in ["carry", "escort"] else "tool"

func _available(quest: Dictionary) -> bool:
	if zone == "ruins" and not _late_road_open():
		return false
	match str(quest.get("requires", "")):
		"bell": return _flag("bell_eater_defeated") or _flag("bell_eater_legacy_retired")
		"bog": return host.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch")
		"mill": return _flag("ashwing_defeated") and (str(host.story_state.get_flag("mill_operation", "")) != "" or host.quests.is_completed("main_ash_at_the_mill"))
		"senn": return str(host.story_state.get_flag("senn_fate", "")) in ["testimony", "exile", "punished"]
		"ledger": return _flag("vargan_ledger_choice_made") or host.quests.is_objective_done("main_blood_under_stone", "ledger_choice") or host.quests.is_completed("main_blood_under_stone")
		"halvern": return str(host.story_state.get_flag("halvern_fate", "")) in ["witness", "released", "destroyed"]
		"hart": return _flag("final_choice_completed")
	return true

func _late_road_open() -> bool:
	return host.quests.is_unlocked("main_hart_remembers") or host.quests.is_active("main_hart_remembers") or _flag("final_choice_completed")

func _secret_available(secret: Array) -> bool:
	if zone == "ruins" and not _late_road_open():
		return false
	match str(secret[6]):
		"water": return host.quests.is_completed("saga_wyc_q05")
		"hart": return _flag("final_choice_completed")
		"passage": return _flag("command_proof_recovered") or host.story_state.has_evidence("vargan_ledger") or _flag("vargan_service_passage_known")
	return true

func _step(id: String) -> Array:
	for step: Array in Catalog.QUESTS.get(id, {}).get("steps", []):
		if not host.quests.is_objective_done(id, str(step[0])):
			return step
	return []

func _part(id: String, objective: String) -> int:
	return maxi(0, int(host.story_state.get_flag(id + ":" + objective + ":part", 0)))

func activate(id: String) -> void:
	var area: Node3D = points.get(id)
	if not _within_reach(area):
		return
	if id.begins_with("saga_secret:"):
		_open_secret(area, id.trim_prefix("saga_secret:"))
		return
	if id.begins_with("saga_return:"):
		var prefix := id.trim_prefix("saga_return:")
		if not host.progression.claim_saga_return(prefix, host.quests):
			host.hud.toast("The work remains. A meaningful return is recorded once after leaving this place.")
		_persist()
		return
	if Catalog.PEOPLE.has(id):
		_open_person(area, id)
		return
	if id.begins_with("saga_bog_") or id == "saga_senn_challenge":
		Encounters.activate(host, id, area)
		return
	var quest_id := id.get_slice(":", 0)
	if not Catalog.QUESTS.has(quest_id):
		return
	var quest: Dictionary = Catalog.QUESTS[quest_id]
	if id.ends_with(":offer"):
		_open(area, str(quest.title), str(quest.hook), [_action(area, "accept", quest_id, "Offer a hand")])
		return
	if id.ends_with(":after"):
		_collect_delivery(quest_id)
		_open(area, str(quest.title), _aftermath_text(quest_id), [])
		return
	var step := _step(quest_id)
	if step.is_empty() or str(step[0]) != id.get_slice(":", 1):
		return
	var mode := str(step[3])
	if mode in ["choice", "signal"]:
		var actions: Array = []
		for outcome: String in step[4]:
			if _choice_allowed(quest_id, outcome):
				var action := _action(area, "choice", quest_id, str(step[4][outcome]))
				action["outcome"] = outcome
				actions.append(action)
		_open(area, str(quest.title), str(step[1]), actions)
	elif mode == "escort":
		_start_escort(quest_id, step, area)
	elif mode == "return" and not _flag(quest_id + ":left_work_area"):
		host.hud.toast("Leave the quiet work area before returning to inspect fresh signs.")
	elif quest_id == "saga_gre_q04" and str(step[0]) == "return_kettle" and str(host.story_state.get_flag(quest_id + "_outcome", "")) == "replayed" and not _flag("saga_gre_q04:round_played"):
		host.hud.toast("Play one ordinary Three Marks round at the common table. Winning is not required.")
	else:
		var part := _part(quest_id, str(step[0]))
		var account := str(step[5])
		if step[4] is Array and step[4].size() > 1:
			account = str(area.prompt) + ".\n\n" + account
		var action := _action(area, "work" if mode in ["work", "carry", "door", "bell"] else "advance", quest_id, str(area.prompt), part)
		if area.has_meta("saga_inspect_index"):
			action["inspect_index"] = int(area.get_meta("saga_inspect_index"))
		_open(area, str(quest.title), account, [action])

func _open_person(area: Node3D, id: String) -> void:
	if not _flag(id + "_met"):
		host.story_state.set_flag(id + "_met", true)
		_persist()
	var person: Dictionary = Catalog.PEOPLE[id]
	var actions: Array = []
	var finished := false
	for quest_id: String in Catalog.QUESTS:
		var quest: Dictionary = Catalog.QUESTS[quest_id]
		if str(quest.get("actor", "")) != id or str(quest.zone) != zone or not _available(quest):
			continue
		finished = finished or host.quests.is_completed(quest_id)
		if not host.quests.is_active(quest_id) and not host.quests.is_completed(quest_id):
			actions.append(_action(area, "offer", quest_id, str(quest.title)))
		elif host.quests.is_active(quest_id):
			actions.append(_action(area, "directions", quest_id, "About " + str(quest.title)))
	var written: bool = (bool(person.get("alias", false)) and not bool(area.get_meta("saga_alias_present", false))) or (id == "saga_odran" and host.quests.is_completed("saga_var_q03") and str(host.story_state.get_flag("saga_var_q03_outcome", "")) == "departed")
	var words := str(person.get("return" if finished else "line", ""))
	if written:
		words = "Previously authorized note from " + str(person.name) + ":\n" + ("My tools and traveling tray were returned. I have left by my own choice. The offered seed labels remain available to inspect." if id == "saga_odran" else words)
	_open(area, str(person.name) + (" - recorded note" if written else ""), words, actions, "narrator" if written else id)

func _action(area: Node3D, operation: String, quest_id: String, label: String, part: int = -1) -> Dictionary:
	var step := _step(quest_id)
	return {"type":"saga_action", "label":label, "operation":operation, "quest":quest_id, "area":area.get_instance_id(), "objective":str(step[0]) if not step.is_empty() else "", "part":part if part >= 0 else (_part(quest_id, str(step[0])) if not step.is_empty() else 0)}

func _open(area: Node3D, title: String, text: String, actions: Array, speaker_id: String = "narrator") -> void:
	if speaker_id != "narrator":
		host._stage_dialogue_moment(area)
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":title, "pages":[{"speaker":title, "speaker_id":speaker_id, "text":text}], "actions":actions})

func choose(action: Dictionary) -> void:
	var area := instance_from_id(int(action.get("area", 0))) as Node3D
	if not _within_reach(area):
		host._resume_game()
		return
	var operation := str(action.get("operation", ""))
	if operation == "secret":
		if str(area.interaction_id) != "saga_secret:" + str(action.get("secret", "")):
			return
		host._resume_game()
		_claim_secret(str(action.get("secret", "")), bool(action.get("sealed", false)))
		return
	var id := str(action.get("quest", ""))
	var quest: Dictionary = Catalog.QUESTS.get(id, {})
	if quest.is_empty() or str(quest.zone) != zone or not _available(quest):
		host._resume_game()
		return
	if operation == "offer":
		_open(area, str(quest.title), str(quest.hook), [_action(area, "accept", id, "Offer a hand")])
		return
	if operation == "directions":
		var step := _step(id)
		_open(area, str(quest.title), str(step[1]) + ". The current work is marked in your journal.", [])
		return
	host._resume_game()
	if operation == "accept":
		if not host.quests.is_active(id) and not host.quests.is_completed(id):
			host.quests.unlocked[id] = true
			host.quests.start_quest(id)
			_commit()
		return
	var step := _step(id)
	if step.is_empty() or str(step[0]) != str(action.get("objective", "")) or _part(id, str(step[0])) != int(action.get("part", -1)):
		return
	if operation == "choice":
		var outcome := str(action.get("outcome", ""))
		if not step[4] is Dictionary or not step[4].has(outcome) or not _choice_allowed(id, outcome):
			return
		if str(step[3]) == "signal":
			# A selected signaling mode is not proof of walking the line.
			host.story_state.set_flag(id + "_outcome", outcome)
			host.story_state.set_flag(id + ":signal_mode_set", true)
			host.hud.toast("Walk to the far marker, then return to check the line.")
			_commit()
			return
		_complete_step(id, step, outcome)
	elif operation == "work":
		_work = {"id":id, "step":step, "area":weakref(area), "start":host.player.global_position, "part":int(action.part)}
		_elapsed = 0.0
		host.player._request_equipment(host.player.weapon_mode, host.player.get_selected_blade_id(), false)
	else:
		if action.has("inspect_index"):
			var index := int(action.inspect_index)
			if int(area.get_meta("saga_inspect_index", -1)) != index or index < 0 or index >= step[4].size() or _flag(id + ":" + str(step[0]) + ":seen:" + str(index)):
				return
			host.story_state.set_flag(id + ":" + str(step[0]) + ":seen:" + str(index), true)
		_advance_part(id, step)

func _choice_allowed(id: String, outcome: String) -> bool:
	if id != "saga_dep_q05":
		return true
	var operation := str(host.story_state.get_flag("mill_operation", ""))
	return outcome == "workshop" or (outcome == "relief_store" and operation == "closed") or (outcome == "checking_station" and operation not in ["", "closed"])

func _advance_part(id: String, step: Array) -> void:
	var next := _part(id, str(step[0])) + 1
	var total: int = step[4].size() if step[4] is Array and not step[4].is_empty() else 1
	host.story_state.set_flag(id + ":" + str(step[0]) + ":part", next)
	if next >= total:
		_complete_step(id, step)
	else:
		_commit()

func _complete_step(id: String, step: Array, chosen_outcome: String = "") -> void:
	host.story_state.begin_change()
	host.quests.begin_change()
	if chosen_outcome != "":
		host.story_state.set_flag(id + "_outcome", chosen_outcome)
	if str(step[3]) in ["choice", "signal"]:
		var outcome := str(host.story_state.get_flag(id + "_outcome", ""))
		host.story_state.record_decision(id + ":" + str(step[0]), {"label":str(step[4].get(outcome, outcome)), "result":str(step[5]), "sets_flags":{id + "_outcome":outcome}})
	var quest: Dictionary = Catalog.QUESTS[id]
	if str(step[0]) == str(quest.steps.back()[0]):
		if str(host.story_state.get_flag(id + "_outcome", "")) == "":
			push_error("Saga quest cannot finish without its recorded branch: " + id)
			host.quests.end_change()
			host.story_state.end_change()
			return
		_collect_delivery(id)
		if str(quest.get("lore", "")) != "":
			host.story_state.record_evidence(id + "_lore", {"zone":zone, "kind":"account", "title":quest.title, "text":quest.lore})
	if host.quests.is_choice_objective(id, str(step[0])):
		host.quests.complete_choice(id, str(step[0]))
	else:
		host.quests.complete_objective(id, str(step[0]))
	host.story_state.set_flag(id + ":last_account", str(step[5]))
	host.story_state.end_change()
	host.quests.end_change()
	host.hud.toast(str(step[5]))
	_commit()

func _collect_delivery(id: String) -> void:
	var quest: Dictionary = Catalog.QUESTS[id]
	host.inventory.deliver_once("saga:quest:" + id, {"items":quest.get("items", {}), "ingredients":quest.get("ingredients", {})})
	if host.inventory.has_pending_delivery("saga:quest:" + id):
		host.hud.toast("Some supplies remain here for collection after you make room.")

func _reconcile_rewards() -> void:
	for prefix: String in Catalog.WORLDS:
		var condition: String = {"gre":"bell", "wyc":"bog", "dep":"ash", "roa":"senn", "var":"halvern", "har":"hart"}[prefix]
		var earned := _available({"requires":condition})
		if condition == "ash":
			earned = _flag("ashwing_defeated")
		if not earned:
			continue
		var id := str(Catalog.WORLDS[prefix].reward)
		var newly_earned: bool = host.progression.grant_saga_entitlement(id)
		if not host.inventory.reward_deliveries.has("saga:reward:" + prefix):
			host.inventory.deliver_once("saga:reward:" + prefix, {"items":{id:1}})
			newly_earned = true
		if newly_earned:
			_persist()
		if id == "saga_oathbearer_inlay":
			var covenant := str(host.story_state.get_flag("final_covenant", ""))
			host.inventory.item_defs[id].description = str(Catalog.REWARDS[id].description) + "\n" + str({"witness":"Witness: a copied inscription keeps the account accessible.", "mercy":"Mercy: a private unbinding mark preserves a release.", "duty":"Duty: the fitting records Kael's voluntary charge alone.", "ash":"Ash: an unbound heat-dissipating fitting; no replacement pledge."}.get(covenant, "The recorded covenant is retained."))

func _open_secret(area: Node3D, id: String) -> void:
	var secret: Array = Catalog.SECRETS[id]
	if host.progression.claimed_rewards.has("secret:" + id):
		host.inventory.deliver_once("saga:secret:" + id, {"items":secret[5], "ingredients":{"redroot":2} if id == "DEP-S03" else {}})
		_open(area, id, str(secret[4]), [])
		_persist()
		return
	var action := {"type":"saga_action", "operation":"secret", "label":str(secret[3]), "area":area.get_instance_id(), "secret":id}
	var actions: Array = [action]
	if str(secret[6]) == "consent":
		action.label = "Read the letter under the standing invitation"
		var sealed := action.duplicate()
		sealed["sealed"] = true
		sealed.label = "Acknowledge the offered letter; keep it sealed"
		actions.append(sealed)
	_open(area, id, str(secret[2]), actions)

func _claim_secret(id: String, sealed: bool) -> void:
	if not Catalog.SECRETS.has(id):
		return
	var secret: Array = Catalog.SECRETS[id]
	if str(secret[0]) != zone or not _secret_available(secret):
		return
	host.story_state.begin_change()
	host.inventory.deliver_once("saga:secret:" + id, {"items":secret[5], "ingredients":{"redroot":2} if id == "DEP-S03" else {}})
	host.story_state.set_flag("saga_secret_" + id, "sealed" if sealed else "read")
	host.story_state.record_evidence("saga_secret_" + id, {"zone":zone, "kind":"discovery", "title":id + " - " + str(secret[2]), "text":"The offered letter was acknowledged and kept sealed." if sealed else str(secret[4])})
	host.progression.award_saga_secret(id, Catalog.region_for_prefix(id.left(3).to_lower()), str(secret[2]))
	host.story_state.end_change()
	host.hud.toast("The offered letter remains sealed." if sealed else str(secret[4]))
	_commit()

func _outcome_name(id: String) -> String:
	return str(host.story_state.get_flag(id + "_outcome", "recorded")).replace("_", " ")

func _aftermath_text(id: String) -> String:
	var text := str(Catalog.QUESTS[id].steps.back()[5]) + "\n\nRecorded arrangement: " + _outcome_name(id) + "."
	if id == "saga_har_q05":
		text += "\nCovenant: " + str(host.story_state.get_flag("final_covenant", "")) + ". The original journey home remains separate."
	return text

func _dress_aftermath(area: Node3D, id: String) -> void:
	if area.has_meta("saga_dressed"):
		return
	area.set_meta("saga_dressed", true)
	WorkPresentation.build(host, area, id, true, str(host.story_state.get_flag(id + "_outcome", "")))

func _within_reach(area: Node3D) -> bool:
	if not is_instance_valid(area) or not is_instance_valid(host.player) or not is_ancestor_of(area) \
		or not area.is_visible_in_tree() or not area.is_interaction_enabled():
		return false
	# This starts the encounter; requiring its guards to be gone first retires
	# the challenge itself. Ordinary regional work remains unavailable in combat.
	var encounter_start := str(area.get("interaction_id")) == "saga_senn_challenge"
	return host.player.global_position.distance_to(area.global_position) <= 4.0 \
		and (encounter_start or not host._story_has_active_combat()) \
		and not host.zone_transition_pending and not host._journey_load_pending()

func _flag(id: String) -> bool:
	return bool(host.story_state.get_flag(id, false))

func _commit() -> void:
	refresh()
	host._refresh_tracker()
	_persist()

func _persist() -> void:
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func _restore_escort(id: String, step: Array, area: Node3D) -> void:
	if _escort != null:
		return
	_escort = Node3D.new()
	_escort.name = "SagaTravelers" if id == "saga_gre_q05" else "FirstRoadTraveler"
	add_child(_escort)
	var saved: Variant = host.story_state.get_flag(id + ":escort_position", null)
	_escort.position = Vector3(float(saved[0]), float(saved[1]), float(saved[2])) if saved is Array and saved.size() == 3 else area.position + Vector3(0.5,0,0)
	var count := 2 if id == "saga_gre_q05" else 1
	for index in range(count):
		var body := host.asset_helper.spawn_visual_role("villager_human" if index == 0 else "villager_female_human", "characters", id + "_traveler_" + str(index)) as Node3D
		if body != null:
			body.position.x = float(index) * 0.65
			_escort.add_child(body)
			host._configure_npc_animation(body, id + "_traveler_" + str(index))
			var driver := body.get_node_or_null("CharacterAnimationDriver")
			if driver != null:
				_escort_drivers.append(driver)

func _start_escort(id: String, step: Array, area: Node3D) -> void:
	_restore_escort(id, step, area)
	var site := str(step[4][1])
	if id == "saga_gre_q05":
		site = "kitchen" if str(host.story_state.get_flag(id + "_outcome", "")) == "store" else "courtyard"
	var destination := _site_position(site, id + "_escort_destination")
	_escort_path = host.spatial_service.build_route(_escort.position, destination, 0.65) if host.spatial_service != null else []
	if _escort_path.is_empty():
		host.hud.toast("The travelers wait safely. Clear the short path before asking them to follow.")
		return
	_escort_index = 0
	_work = {"id":id, "step":step, "escort":true}
	host.story_state.set_flag(id + ":escort_started", true)
	host.hud.toast("Stay nearby. The travelers walk and wait if you leave them behind.")

func _physics_process(delta: float) -> void:
	if host == null or str(host.current_zone_id) != zone or not is_instance_valid(host.player):
		return
	_tick_return_steps()
	if _work.is_empty():
		return
	if bool(_work.get("escort", false)):
		_tick_escort(delta)
		return
	var area: Node3D = _work.area.get_ref()
	if not _within_reach(area) or host.player.global_position.distance_to(_work.start) > 0.35 or not host.player.can_control:
		_work.clear()
		_elapsed = 0
		return
	if host.player.equipment_loadout.is_transitioning():
		return
	_elapsed += delta
	if _elapsed >= 1.25:
		var id := str(_work.id)
		var step: Array = _work.step
		_work.clear()
		_elapsed = 0
		if str(step[3]) == "door":
			var hinge := area.find_child("DoorHinge", true, false) as Node3D
			if hinge != null:
				hinge.rotation.y = -PI * 0.5 if _part(id, str(step[0])) == 0 else 0.0
		if str(step[3]) == "bell" and host.audio != null:
			host.audio.play_event("ui", 0.02)
		_advance_part(id, step)

func _tick_return_steps() -> void:
	for id: String in ["saga_har_q03", "saga_roa_q04"]:
		if not host.quests.is_active(id) or str(Catalog.QUESTS[id].zone) != zone:
			continue
		var step := _step(id)
		if step.is_empty() or str(step[3]) not in ["return", "signal"]:
			continue
		var key := id + ":left_work_area"
		var anchor: Vector3 = Catalog.SITES[zone][step[2]]
		if host.player.global_position.distance_to(anchor) >= 7.0 and (str(step[3]) != "signal" or _flag(id + ":signal_mode_set")):
			if not _flag(key):
				host.story_state.set_flag(key, true)
		elif _flag(key) and host.player.global_position.distance_to(anchor) < 2.8 and str(step[3]) == "signal":
			_complete_step(id, step)

func _tick_escort(delta: float) -> void:
	if _escort == null or host._story_has_active_combat() or _escort.global_position.distance_to(host.player.global_position) > 6.0:
		for driver: Node in _escort_drivers:
			if is_instance_valid(driver):
				driver.set_locomotion_motion(Vector3.ZERO, true)
		return
	if _escort_index >= _escort_path.size():
		var id := str(_work.id)
		var step: Array = _work.step
		_work.clear()
		_complete_step(id, step)
		for driver: Node in _escort_drivers:
			if is_instance_valid(driver):
				driver.set_locomotion_motion(Vector3.ZERO, true)
		return
	var target := _escort_path[_escort_index]
	var offset := target - _escort.position
	offset.y = 0
	if offset.length() < 0.15:
		_escort_index += 1
		return
	var destination := _escort.position + offset.normalized() * minf(delta * 1.35, offset.length())
	if host.spatial_service != null and not host.spatial_service.validate_runtime_segment(_escort.position, destination, 0.5, host.player):
		return
	_escort.position = destination
	_escort.rotation.y = atan2(-offset.x, -offset.z)
	for driver: Node in _escort_drivers:
		if is_instance_valid(driver):
			driver.set_locomotion_motion(offset.normalized() * 1.35, true)
	var id := str(_work.id)
	host.story_state.flags[id + ":escort_position"] = [_escort.position.x, _escort.position.y, _escort.position.z]

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not bool(_work.get("escort", false)):
			_work.clear()
		_elapsed = 0
