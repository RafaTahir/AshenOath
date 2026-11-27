extends Node3D

## Optional regional work hosted by StoryActivityDirector. This node owns only
## live staging; all durable steps, choices, deliveries and XP use existing services.
const Catalog = preload("res://scripts/saga_catalog.gd")
const Interactable = preload("res://scripts/interactable.gd")
const Records = preload("res://scripts/campaign_record_presentation.gd")
const Encounters = preload("res://scripts/saga_encounters.gd")
const WorkPresentation = preload("res://scripts/saga_work_presentation.gd")
const Presence = preload("res://scripts/character_presence.gd")
const CastProfile = preload("res://scripts/story_cast_profile.gd")
var host
var zone := ""
var points: Dictionary = {}
var _work: Dictionary = {}
var _elapsed := 0.0
var _escort: Node3D
var _escort_drivers: Array[Node] = []
var _escort_path: Array[Vector3] = []
var _escort_index := 0
var _used_positions: Array[Vector3] = []
var _site_positions: Dictionary = {}
var _assemblies: Dictionary = {}
var _carried: Node3D
var _carried_key := ""
var _walk_tick := 0.0
var _escort_hint := ""
var _escort_legs: Dictionary = {}
var _escort_trail: Array[Vector3] = []
var _relief_travelers: Array[Node3D] = []
var _maren_arrived_this_visit := false

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

var saga_site_view = preload("res://scripts/views/saga_site_view.gd").new(self)
var saga_dialogue_view = preload("res://scripts/views/saga_dialogue_view.gd").new(self)
var saga_work_view = preload("res://scripts/views/saga_work_view.gd").new(self)
func queue_refresh() -> void: saga_site_view.queue_refresh()

func refresh() -> void: saga_site_view.refresh()
func _point(id: String, prompt: String, site: String, kind: String) -> Node3D: return saga_site_view._point(id, prompt, site, kind)
func _site_position(site: String, id: String) -> Vector3: return saga_site_view._site_position(site, id)
func _add_person(area: Node3D, person: Dictionary, id: String) -> void: saga_site_view._add_person(area, person, id)
func append_cast_topics(actor: Node3D, content: Dictionary, exclude_id: String = "") -> void: saga_dialogue_view.append_cast_topics(actor, content, exclude_id)
func _add_work_prop(area: Node3D, kind: String) -> void: saga_site_view._add_work_prop(area, kind)
func _prop_kind(mode: String, prompt: String) -> String: return saga_site_view._prop_kind(mode, prompt)
func _available(quest: Dictionary) -> bool: return saga_site_view._available(quest)
func _late_road_open() -> bool: return saga_site_view._late_road_open()
func _secret_available(secret: Array) -> bool: return saga_site_view._secret_available(secret)
func _step(id: String) -> Array:
	for step: Array in Catalog.quest_row(id,host.story_state).get("steps", []):
		if not host.quests.is_objective_done(id, str(step[0])):
			return _method_step(id, step)
	return []

func _quest_zone(id: String) -> String:
	return Catalog.step_zone(id, _step(id)) if id == "side_escort_06" else str(Catalog.quest_row(id,host.story_state).zone)

func _walk_sites(id: String, step: Array) -> Array:
	if id == "side_escort_02" and str(host.story_state.get_flag(id + "_outcome", "")) == "work_line":
		return ["workers", "boundary", "blind"]
	return step[4]

func _method_step(id: String, original: Array) -> Array:
	var step := original.duplicate(true)
	var outcome := str(host.story_state.get_flag(id + "_outcome", ""))
	if id == "side_escort_01" and str(step[0]) == "steady_arrival" and outcome == "wheel":
		step[4] = ["Seat Tor's axle brace", "Hold the clean linen within Anwen's reach", "Check the secured wheel and leave the traveler space"]
	if id == "side_escort_03":
		var operation := str(host.story_state.get_flag("mill_operation", ""))
		if operation == "closed":
			step[5] += " The mill remains closed; this is the independent relief frame in the yard."
		elif operation != "":
			step[5] += " The recorded mill arrangement remains in force. This load uses the separate yard frame."
	if id == "side_escort_06":
		var covenant := str(host.story_state.get_flag("final_covenant", ""))
		step[5] += "\n" + str({"ash":"The Hart remains dead. The relief work does not summon its memory.", "kill":"The Hart remains dead. The relief work does not summon its memory.", "mercy":"The binding is released; the receiving work is voluntary.", "free":"The binding is released; the receiving work is voluntary.", "witness":"The public account and the relief handover remain separate things.", "expose":"The public account and the relief handover remain separate things.", "duty":"The recorded stewardship does not pledge these travelers.", "bind":"The recorded stewardship does not pledge these travelers."}.get(covenant, "The recorded covenant and its actual consequences stand."))
	if id == "saga_gre_q01" and outcome == "coerced":
		step[5] = "Nessa accepts the corrected measure, not the threat. The household repays under fear of its address being exposed; this was not voluntary help."
	if id == "saga_dep_q01" and outcome == "falsified":
		step[5] = "Tor: 'You have marked the current fee paid when we both know it was taken twice. That is your entry, not my agreement.' The old command evidence is untouched."
		if str(step[0]) == "settle_account":
			step[5] = "Kael chose to falsify this current dispatch. The next load still needs the physical tag and false copy; no old command evidence changes."
		if str(step[0]) == "mark_next_load":
			step[1] = "Re-tag the next load and place the knowingly false current dispatch"
			step[4] = ["Re-tag the next load", "Place the false paid dispatch copy"]
	if id == "saga_var_q02" and outcome == "conditional_pass":
		step[5] = "The family has its real pass. The optional complaint is withheld under Merrow's bargain, not withdrawn freely. No guaranteed campaign evidence has been removed."
		if str(step[0]) == "choose_protection":
			step[5] = "Kael accepted Merrow's conditional bargain. Withholding the optional complaint and delivering the actual pass remain to be done. Guaranteed campaign proof is unaffected."
		if str(step[0]) == "deliver_copy":
			step[1] = "Withhold the optional complaint and deliver the household's pass"
			step[4] = ["Seal the optional complaint in Merrow's withheld tray", "Place the household's conditional pass copy"]
	return step

func _account(id: String, step: Array) -> String:
	if id.begins_with("side_escort_"):
		return str(_method_step(id, step)[5])
	if str(host.story_state.get_flag(id + "_outcome", "")) in ["coerced", "falsified", "conditional_pass"]:
		return str(_method_step(id, step)[5])
	if Catalog.Garden.active(id,host.story_state): return str(step[5])
	return Catalog.account(id, step)

func _part(id: String, objective: String) -> int:
	return maxi(0, int(host.story_state.get_flag(id + ":" + objective + ":part", 0)))

func activate(id: String) -> void: saga_dialogue_view.activate(id)
func _open_person(area: Node3D, id: String) -> void: saga_dialogue_view._open_person(area, id)
func _maren_greeting() -> String: return saga_dialogue_view._maren_greeting()
func _action(area: Node3D, operation: String, quest_id: String, label: String, part: int = -1) -> Dictionary: return saga_dialogue_view._action(area, operation, quest_id, label, part)
func _nearby_speaker(id: String) -> String: return saga_dialogue_view._nearby_speaker(id)
func _open(area: Node3D, title: String, text: String, actions: Array, speaker_id: String = "narrator", recall: String = "", pages: Array = []) -> void: saga_dialogue_view._open(area, title, text, actions, speaker_id, recall, pages)
func choose(action: Dictionary) -> void: saga_dialogue_view.choose(action)
func _resume_known_inspections(id: String) -> void:
	if not host.quests.is_active(id) or not bool(Catalog.quest_row(id,host.story_state).get("early_clues", false)):
		return
	var step := _step(id)
	if step.is_empty() or str(step[3]) != "inspect":
		return
	var count := 0
	for index in range(step[4].size()):
		if _flag(id + ":" + str(step[0]) + ":seen:" + str(index)):
			count += 1
	host.story_state.set_flag(id + ":" + str(step[0]) + ":part", count)
	if count == step[4].size():
		_complete_step(id, step)

func _choice_allowed(id: String, outcome: String) -> bool: return saga_dialogue_view._choice_allowed(id, outcome)
func _advance_part(id: String, step: Array) -> void:
	var part := _part(id, str(step[0]))
	var next := part + 1
	var total: int = step[4].size() if step[4] is Array and not step[4].is_empty() else 1
	var key := id + ":" + str(step[0])
	# Only an actual new pickup earns a bundled delivery. An old save holding a
	# single piece still places that piece before collecting the remaining load.
	if str(step[3]) == "carry" and Catalog.BUNDLED_CARRIES.has(key):
		if part % 2 == 0:
			host.story_state.set_flag(key + ":bundle_pickup", next)
		elif int(host.story_state.get_flag(key + ":bundle_pickup", -1)) == part:
			next = total
			host.story_state.set_flag(key + ":bundle_pickup", -1)
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
	if id == "side_escort_01" and str(step[0]) == "hear_recognition":
		host.story_state.set_flag("escort_abandonment_acknowledged", true)
	if str(step[3]) in ["choice", "signal"]:
		var outcome := str(host.story_state.get_flag(id + "_outcome", ""))
		host.story_state.record_decision(id + ":" + str(step[0]), {"label":str(step[4].get(outcome, outcome)), "result":_account(id, step), "sets_flags":{id + "_outcome":outcome}})
	var quest: Dictionary = Catalog.quest_row(id,host.story_state)
	if str(step[0]) == str(quest.steps.back()[0]):
		if str(host.story_state.get_flag(id + "_outcome", "")) == "":
			push_error("Saga quest cannot finish without its recorded branch: " + id)
			host.quests.end_change()
			host.story_state.end_change()
			return
		_collect_delivery(id)
		if str(quest.get("lore", "")) != "":
			var lore_id := ("saga_" if id.begins_with("side_escort_") else "") + id + "_lore"
			host.story_state.record_evidence(lore_id, {"zone":zone, "kind":"account", "title":quest.title, "text":quest.lore})
		var person := str(quest.get("actor", ""))
		if person != "":
			var harmful := str(host.story_state.get_flag(id + "_outcome", "")) in ["coerced", "falsified", "conditional_pass"]
			host.story_state.record_relationship_event({"id":"lr.saga." + id, "actor":person.trim_prefix("saga_"), "kind":"boundary" if person == "saga_maren" else "broken" if harmful else "help", "text":str(quest.title) + ": " + _aftermath_text(id), "acknowledgement":_account(id, step) if harmful or person == "saga_maren" else str(Catalog.GREETINGS.get(person, "Thank you for staying to see it through."))})
	if host.quests.is_choice_objective(id, str(step[0])):
		host.quests.complete_choice(id, str(step[0]))
	else:
		host.quests.complete_objective(id, str(step[0]))
	var account := _account(id, step)
	host.story_state.set_flag(id + ":last_account", account)
	host.story_state.end_change()
	host.quests.end_change()
	host.hud.toast(account)
	_resume_known_inspections(id)
	_commit()

func _collect_delivery(id: String) -> void:
	var quest: Dictionary = Catalog.quest_row(id,host.story_state)
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

func _outcome_name(id: String) -> String: return saga_dialogue_view._outcome_name(id)
func _aftermath_text(id: String) -> String: return saga_dialogue_view._aftermath_text(id)
func _dress_aftermath(area: Node3D, id: String) -> void: saga_site_view._dress_aftermath(area, id)
func _ensure_assembly(id: String) -> void: saga_site_view._ensure_assembly(id)
func _begin_work(id: String, step: Array, area: Node3D) -> void: saga_work_view._begin_work(id, step, area)
func _cancel_work() -> void: saga_work_view._cancel_work()
func _sync_carried_work() -> void: saga_work_view._sync_carried_work()
func scent_candidates() -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	for point: Node3D in points.values():
		if bool(point.get_meta("saga_scent", false)) and point.is_visible_in_tree() and point.is_interaction_enabled():
			candidates.append(point)
	return candidates

func _within_reach(area: Node3D) -> bool:
	if not is_instance_valid(area) or not is_instance_valid(host.player) or not is_ancestor_of(area) \
		or not area.is_visible_in_tree():
		return false
	if not area.is_interaction_enabled():
		if not bool(area.get_meta("saga_topic_only", false)) or not bool(area.get_meta("saga_wanted", false)):
			return false
		var actor := instance_from_id(int(area.get_meta("saga_actor_instance", 0))) as Node3D
		if not is_instance_valid(actor) or not host.zone_root.is_ancestor_of(actor) or not actor.is_visible_in_tree():
			return false
		if not Presence.can_see(host.player, actor, 4.0):
			return false
		area.global_position = actor.global_position
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

func _restore_escort(id: String, step: Array, area: Node3D) -> void: saga_work_view._restore_escort(id, step, area)
func _escort_person(actor_id: String, position: Vector3) -> Node3D: return saga_work_view._escort_person(actor_id, position)
func _release_escort_ownership() -> void: saga_work_view._release_escort_ownership()
func _start_escort(id: String, step: Array, area: Node3D) -> void: saga_work_view._start_escort(id, step, area)
func _physics_process(delta: float) -> void:
	if host == null or str(host.current_zone_id) != zone or not is_instance_valid(host.player):
		return
	if is_instance_valid(_carried):
		_carried.visible = host.player.sword_sheathed and not host.player.bow_aiming and str(host.player.beam_cast_state) == ""
	_tick_return_steps()
	_walk_tick -= delta
	if _walk_tick <= 0.0:
		_walk_tick = 0.20
		_tick_walk_steps()
	if _work.is_empty():
		return
	if bool(_work.get("escort", false)):
		_tick_escort(delta)
		return
	var area: Node3D = _work.area.get_ref()
	if not _within_reach(area) or host.player.global_position.distance_to(_work.start) > 0.35 or not host.player.can_control or host.player.transition_locked or float(host.player.attack_anim_time) > 0.0 or str(host.player.beam_cast_state) != "" or float(host.player.hurt_react_time) > 0.0:
		_cancel_work()
		return
	if host.player.equipment_loadout.is_transitioning():
		return
	if host.player.equipment_loadout.is_drawn():
		_cancel_work()
		return
	if not Presence.claim(host.player, "work", get_instance_id()):
		_cancel_work()
		return
	host.player.set_meta("cast_work_cancel", _cancel_work)
	if host.player.animation_driver != null:
		var activity := str(_work.performance.activity)
		var surface_prop := str(_work.get("surface_prop", ""))
		if surface_prop != "":
			host.player.animation_driver.set_life_workstation({"activity": activity, "surface_prop": surface_prop})
		host.player.animation_driver.set_life_activity(activity)
	_elapsed += delta
	var duration := float(_work.performance.duration)
	WorkPresentation.animate_work(_assemblies.get(str(_work.id)), str(_work.step[3]), int(_work.part), minf(_elapsed / duration, 1.0), str(_work.step[0]))
	if _elapsed >= duration:
		var id := str(_work.id)
		var step: Array = _work.step
		var part := int(_work.part)
		_cancel_work()
		if str(step[3]) == "bell" and part == 0 and host.audio != null:
			host.audio.play_event("shrine_bell", 0.02)
		_advance_part(id, step)

func _tick_walk_steps() -> void: saga_work_view._tick_walk_steps()
func _tick_return_steps() -> void: saga_work_view._tick_return_steps()
func _tick_escort(delta: float) -> void: saga_work_view._tick_escort(delta)
func _follow_relief_trail() -> void: saga_work_view._follow_relief_trail()
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_maren_arrived_this_visit = false
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not bool(_work.get("escort", false)):
			_cancel_work()

func _exit_tree() -> void:
	_cancel_work()
	_release_escort_ownership()
	if is_instance_valid(_carried):
		_carried.queue_free()

func read_tag(node: Object, key: StringName, fallback: Variant = null) -> Variant: return node.get_meta(key,fallback) if is_instance_valid(node) else fallback
func write_tag(node: Object, key: StringName, value: Variant) -> void:
	if is_instance_valid(node): node.set_meta(key,value)
func supports(node: Object, method: StringName) -> bool: return is_instance_valid(node) and node.has_method(method)
