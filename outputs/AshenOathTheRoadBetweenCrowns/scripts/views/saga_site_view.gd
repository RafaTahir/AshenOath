extends RefCounted
var _activities: Node3D
var _refresh_pending := false
var _refreshing := false
func _init(activities: Node3D) -> void:
	_activities = activities
func queue_refresh() -> void:
	if _refresh_pending or not _owns_published_zone():
		return
	_refresh_pending = true
	_refresh_published_zone.call_deferred()

func _refresh_published_zone() -> void:
	_refresh_pending = false
	if _owns_published_zone():
		refresh()

func _owns_published_zone() -> bool:
	if not is_instance_valid(_activities) or not _activities.is_inside_tree():
		return false
	var owner: Node = _activities.host
	if not is_instance_valid(owner) or owner.neighbor_building:
		return false
	var game: Node = owner.coordinator if owner is ZoneConstructionApi else owner
	if not is_instance_valid(game):
		return false
	var root: Node3D = game.zone_root
	var transition: WorldTransitionModel = game.world_transition
	return is_instance_valid(root) and root.is_ancestor_of(_activities) \
		and transition != null and transition.active_zone_id == _activities.zone and transition.manual_save_allowed()

func refresh() -> void:
	_refresh_pending = false
	if _refreshing or _activities.host == null or not is_instance_valid(_activities.host.zone_root) or not _activities.host.zone_root.is_ancestor_of(_activities) or _activities.zone != str(_activities.host.current_zone_id):
		return
	_refreshing = true
	if _owns_published_zone(): _activities._reconcile_rewards()
	for point: Node3D in _activities.points.values():
		_activities.write_tag(point, "saga_wanted", false)
	for id: String in _activities.Catalog.PEOPLE:
		var person: Dictionary = _activities.Catalog.PEOPLE[id]
		var location: Dictionary = _activities.Catalog.person_location(id, _activities.host.quests,_activities.host.story_state)
		if id == "saga_maren":
			if str(location.zone) == _activities.zone:
				_activities._maren_arrived_this_visit = true
			elif _activities._maren_arrived_this_visit and is_instance_valid(_activities.points.get(id)) and _activities.points[id].is_visible_in_tree():
				location = {"zone":_activities.zone, "site":str(_activities.read_tag(_activities.points[id], "saga_site", person.site))}
		if str(location.zone) == _activities.zone and (_activities.zone != "ruins" or _activities._late_road_open()):
			var area: Variant = _activities._point(id, "Speak with " + str(person.name), str(location.site), "person")
			var present: Variant = _activities.CastProfile.registered_actor(_activities.host.zone_root, id)
			if present != null and present != area:
				_activities.write_tag(area, "saga_topic_only", true)
				_activities.write_tag(area, "saga_alias_present", true)
				_activities.write_tag(area, "saga_actor_instance", present.get_instance_id())
				area.global_position = present.global_position
				continue
			if str(_activities.read_tag(area, "saga_site", "")) != str(location.site) and not bool(_activities._work.get("escort", false)):
				if str(_activities.read_tag(area, "locomotion_owner", "")) != "relief_escort":
					area.position = _activities._site_position(str(location.site), id)
				_activities.write_tag(area, "saga_site", str(location.site))
			if bool(person.get("alias", false)):
				var worker: Variant = _activities.host.zone_root.find_child("MillWorkerBody0", true, false) as Node3D
				if worker != null and worker.is_visible_in_tree():
					area.global_position = worker.global_position
					_activities.write_tag(worker, "story_actor_alias", "saga_dain")
					_activities.write_tag(area, "saga_alias_present", true)
					_activities.write_tag(area, "saga_actor_instance", worker.get_instance_id())
					_activities.CastProfile.register_actor(_activities.host.zone_root, area, id)
				else:
					_activities.write_tag(area, "saga_alias_present", false)
					if area.get_node_or_null("WorkProp") == null:
						_activities._add_work_prop(area, "record")
			elif id == "saga_odran" and _activities.host.story_state.get_flag("novel_edition",0)==1 and _activities.host.story_state.get_flag("novel_pell_care","")!="elna":
				var person_body: Node3D = area.get_node_or_null("Person")
				if person_body != null: person_body.visible = false
				if area.get_node_or_null("WorkProp") == null: _activities._add_work_prop(area,"record")
			elif id == "saga_odran" and _activities.host.quests.is_completed("saga_var_q03") and str(_activities.host.story_state.get_flag("saga_var_q03_outcome", "")) == "departed":
				var body: Variant = area.get_node_or_null("Person") as Node3D
				if body != null:
					body.visible = false
				if area.get_node_or_null("WorkProp") == null:
					_activities._add_work_prop(area, "record")
			elif area != null and area.get_node_or_null("Person") == null:
				_activities._add_person(area, person, id)
	for id: String in _activities.Catalog.QUESTS:
		var quest: Dictionary = _activities.Catalog.quest_row(id,_activities.host.story_state)
		if _activities._quest_zone(id) != _activities.zone or not _activities._available(quest):
			continue
		if bool(quest.get("early_clues", false)) and not _activities.host.quests.is_completed(id):
			for clue_step: Array in quest.steps:
				if str(clue_step[3]) != "inspect" or _activities.host.quests.is_objective_done(id, str(clue_step[0])):
					continue
				for index in range(clue_step[4].size()):
					if _activities._flag(id + ":" + str(clue_step[0]) + ":seen:" + str(index)):
						continue
					var clue: Variant = _activities._point(id + ":" + str(clue_step[0]) + ":inspect:" + str(index), "Inspect " + str(clue_step[4][index]), _activities.Catalog.part_site(id, clue_step, index, _activities.host.story_state), "record")
					_activities.write_tag(clue, "saga_inspect_index", index)
					_activities.write_tag(clue, "saga_early_clue", true)
		if _activities.host.quests.is_completed(id):
			var aftermath_site: Variant = "arrivals" if id == "side_escort_06" else str(quest.site)
			var completed: Variant = _activities._point(id + ":after", "Read " + str(quest.title) + " - " + _activities._outcome_name(id), aftermath_site, "aftermath")
			if completed != null:
				_activities._dress_aftermath(completed, id)
			continue
		if not _activities.host.quests.is_active(id):
			_activities._point(id + ":offer", "Read request: " + str(quest.title), str(quest.site), "record")
			continue
		var step: Variant = _activities._step(id)
		if step.is_empty():
			continue
		var objective: Variant = str(step[0])
		var part: Variant = _activities._part(id, objective)
		var site: Variant = _activities.Catalog.part_site(id, step, part, _activities.host.story_state)
		var mode: Variant = str(step[3])
		var prompt: Variant = str(step[1])
		_activities._ensure_assembly(id)
		if mode == "walk":
			var sites: Variant = _activities._walk_sites(id, step)
			var walk_site: Variant = str(sites[mini(part, sites.size() - 1)])
			var marker: Variant = _activities._point(id + ":" + objective + ":walk", "Check " + walk_site.replace("_", " ") + " on foot", walk_site, "record")
			if str(_activities.read_tag(marker, "saga_site", "")) != walk_site:
				marker.position = _activities._site_position(walk_site, str(marker.interaction_id))
				_activities.write_tag(marker, "saga_site", walk_site)
			continue
		if mode == "signal" and _activities._flag(id + ":signal_mode_set"):
			var returning: Variant = _activities._flag(id + ":left_work_area")
			_activities._point(id + ":" + objective + (":near" if returning else ":far"), "Return to the near marker" if returning else "Walk to the far marker", "posts" if returning else "line", "record")
			continue
		if mode == "inspect" and step[4].size() > 1:
			for index in range(step[4].size()):
				if _activities._flag(id + ":" + objective + ":seen:" + str(index)):
					continue
				var inspected: Variant = _activities._point(id + ":" + objective + ":inspect:" + str(index), "Inspect " + str(step[4][index]), _activities.Catalog.part_site(id, step, index, _activities.host.story_state), "record")
				if inspected != null:
					_activities.write_tag(inspected, "saga_inspect_index", index)
			continue
		if mode == "carry":
			var stages: Array = step[4]
			if part < stages.size():
				if part % 2 == 1:
					prompt = "Place " + str(stages[part - 1])
				else:
					prompt = "Take " + str(stages[part])
					if _activities.Catalog.BUNDLED_CARRIES.has(id + ":" + objective):
						prompt = "Collect " + str(_activities.Catalog.BUNDLED_CARRIES[id + ":" + objective]) + " together"
		elif step[4] is Array and not step[4].is_empty() and mode != "escort":
			prompt = str(step[4][mini(part, step[4].size() - 1)])
		var area: Variant = _activities._point(id + ":" + objective, prompt, site, _activities._prop_kind(mode, prompt))
		if area != null:
			_activities.write_tag(area, "saga_quest", id)
			_activities.write_tag(area, "saga_objective", objective)
			_activities.write_tag(area, "saga_part", part)
			if str(_activities.read_tag(area, "saga_site", "")) != site:
				area.position = _activities._site_position(site, str(area.interaction_id))
				_activities.write_tag(area, "saga_site", site)
			if mode in ["work", "bell", "door", "homecoming"]:
				var old_prop: Variant = area.get_node_or_null("WorkProp")
				if old_prop != null:
					old_prop.visible = site != str(_activities.Catalog.PRESENTATION_SITES.get(id, quest.site)) and mode == "work"
				if site == str(_activities.Catalog.PRESENTATION_SITES.get(id, quest.site)):
					area.global_position = _activities._assemblies[id].global_position
				if id == "side_escort_01" and str(step[0]) == "steady_arrival" and part < 2:
					area.position = _activities._site_position(_activities.Catalog.part_site(id, step, part, _activities.host.story_state), id + ":" + objective)
					if old_prop != null: old_prop.visible = false
				if id == "saga_wyc_q05":
					if old_prop != null: old_prop.visible = false
					var anchor_name: Variant = "PotWorkAnchor" if objective == "place_clean_pots" else "GateWorkAnchor"
					area.global_position = _activities._assemblies[id].get_node(anchor_name).global_position
			if mode == "escort":
				_activities._restore_escort(id, step, area)
				if id == "side_escort_04" and _activities._flag(id + ":escort_started"):
					area.prompt = "Resume the crossing with Nera"
	for id: String in _activities.Catalog.SECRETS:
		var secret: Array = _activities.Catalog.SECRETS[id]
		if str(secret[0]) == _activities.zone and _activities._secret_available(secret):
			_activities._point("saga_secret:" + id, "Inspect " + str(secret[1]).replace("_", " ") + " clue", str(secret[1]), "record")
	for prefix: String in _activities.Catalog.WORLDS:
		var world: Dictionary = _activities.Catalog.WORLDS[prefix]
		if _activities.zone == str(world.home):
			var q05: Variant = "saga_" + prefix + "_q05"
			if _activities.host.quests.is_completed(q05):
				_activities._point("saga_return:" + prefix, "Visit the changed work at " + str(world.name), str(_activities.Catalog.QUESTS[q05].site), "record")
	_activities.Encounters.refresh(_activities.host, _activities)
	for point: Node3D in _activities.points.values():
		var wanted: Variant = bool(_activities.read_tag(point, "saga_wanted", false))
		point.visible = wanted
		var topic_only: Variant = bool(_activities.read_tag(point, "saga_topic_only", false))
		point.set_interaction_enabled(wanted and not topic_only)
		if not wanted or topic_only:
			_activities.host._remove_interaction_candidate(point)
	_activities._sync_carried_work()
	var companion: Node = _activities.host.zone_root.get_node_or_null("Bracken")
	if companion != null and _activities.supports(companion, "refresh_regional_scents"):
		companion.refresh_regional_scents(_activities)
	var life: Node = _activities.host.zone_root.get_node_or_null("GreyfenLifeController")
	if life == null:
		life = _activities.host.zone_root.get_node_or_null("RegionalLifeController")
	if life == null and (not preload("res://scripts/story_cast_profile.gd").life_data().get("zones", {}).get(_activities.zone, {}).is_empty() or preload("res://scripts/story_world_scenes.gd").has_zone(_activities.zone)):
		life = load("res://scripts/greyfen_life_controller.gd").new()
		life.name = "RegionalLifeController"
		_activities.host.zone_root.add_child(life)
		life.configure(_activities.host, str(_activities.host.settings.settings.get("quality_preset", "balanced")), true)
	if life != null:
		life.enroll_region()
	_activities.host.interaction_focus_dirty = true
	_refreshing = false

func _point(id: String, prompt: String, site: String, kind: String) -> Node3D:
	var point: Node3D = _activities.points.get(id)
	if point == null:
		point = _activities.Interactable.new()
		point.setup(id.replace(":", "_"), "story_activity", prompt)
		point.interaction_id = id
		point.dialogue_id = id
		point.name = id.replace(":", "_")
		point.position = _activities._site_position(site, id)
		_activities.write_tag(point, "saga_site", site)
		point.build_collision(0.75)
		_activities.add_child(point)
		_activities.points[id] = point
		var label: Variant = Label3D.new()
		label.name = "InteractionWorldLabel"
		label.visible = false
		label.text = prompt
		label.position.y = 1.45
		label.font_size = 20
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		point.add_child(label)
		if kind != "person":
			if not id.contains(":inspect:") or not _activities.WorkPresentation.clue_visual(_activities.host, point, prompt):
				_activities._add_work_prop(point, kind)
		if id.contains(":inspect:") and (prompt.to_lower().contains("track") or prompt.to_lower().contains("hoofprint") or prompt.to_lower().contains("scar")):
			_activities.write_tag(point, "saga_scent", true)
		_activities.host._connect_interactable(point)
	point.prompt = prompt
	point.display_name = prompt
	_activities.write_tag(point, "saga_wanted", true)
	return point

func _site_position(site: String, id: String) -> Vector3:
	var key: Variant = site + ":" + id
	if _activities._site_positions.has(key):
		return _activities._site_positions[key]
	var base: Vector3 = _activities.Catalog.SITES.get(_activities.zone, {}).get(site, Vector3(3, 0, 8))
	if _activities.zone == "wychwood" and id == "saga_wyc_q05_workplace":
		_activities._site_positions[key] = base
		return base
	if _activities.zone == "greyfen" and id == "saga_secret:GRE-S01":
		base = Vector3(-11.45, 0, -6.8)
		_activities._site_positions[key] = base
		return base
	if _activities.zone == "greyfen" and site == "bell" and id.ends_with("_workplace"):
		_activities._site_positions[key] = base
		return base
	if _activities.zone == "greyfen" and site == "well":
		base = Vector3(-8.65, 0, -0.2)
		if id == "saga_secret:GRE-S02":
			_activities._site_positions[key] = base
			return base
	if site == "escort_care":
		var care: Node3D = _activities.host.zone_root.get_node_or_null("OpeningCareScene")
		base = _activities.host.zone_root.to_local(care.tray_area.global_position) + Vector3(0, 0, 0.65) if care != null and is_instance_valid(care.tray_area) else Vector3(1.15, 0, -5.45)
	elif site == "escort_forge":
		base = Vector3(9.22, 0, -1.85)
	var offset: Variant = Vector3.ZERO
	var seed: Variant = absi(id.hash()) % 7
	for index in range(24):
		var angle: Variant = float((index + seed) % 8) * TAU / 8.0
		var radius: Variant = 0.0 if index == 0 else 0.8 + floorf(float(index - 1) / 8.0) * 0.65
		offset = Vector3(cos(angle), 0, sin(angle)) * radius
		var candidate: Variant = base + offset
		if _activities.host.spatial_service != null and not _activities.host.spatial_service.is_walkable_position(candidate, 0.55, _activities.host.spatial_service.bank_for(base)):
			continue
		var free: Variant = true
		for used: Vector3 in _activities._used_positions:
			if used.distance_squared_to(candidate) < 0.55 * 0.55:
				free = false
				break
		if free:
			_activities._used_positions.append(candidate)
			_activities._site_positions[key] = candidate
			return candidate
	var result: Vector3 = _activities.host.spatial_service.validate_position(base, 0.55, _activities.host.spatial_service.bank_for(base)) if _activities.host.spatial_service != null else base
	_activities._used_positions.append(result)
	_activities._site_positions[key] = result
	return result

func _add_person(area: Node3D, person: Dictionary, id: String) -> void:
	var visual: Node3D = _activities.host.asset_helper.spawn_visual_role(_activities.CastProfile.visual_role(id, str(person.role)), "characters", id)
	if visual == null:
		push_error("Required saga person unavailable: " + id)
		return
	visual.name = "Person"
	area.add_child(visual)
	if not _activities.host._configure_npc_animation(visual, id):
		visual.queue_free()
		push_error("Required saga person has no compatible playback: " + id)
		return
	_activities.CastProfile.register_actor(_activities.host.zone_root, area, id)
	_activities.write_tag(area, "saga_person", id)
	_activities.write_tag(area, "protected_optional_speaker", true)
	load("res://scripts/character_presentation.gd").apply_npc(visual, id, false)
	_activities.write_tag(area, "cast_presence_profile", load("res://scripts/story_cast_profile.gd").presence_profile(id))
	var ambient = load("res://scripts/npc_ambient.gd").new()
	ambient.name = "NpcAmbient"
	ambient.setup(id, _activities.host.player, _activities.host)
	area.add_child(ambient)

func _add_work_prop(area: Node3D, kind: String) -> void:
	var visual: Node3D
	if kind in ["record", "aftermath"]:
		visual = _activities.Records.make_visual("register_mira")
	elif kind == "stone":
		visual = _activities.host._make_role_visual("forest_rock", "environment", Vector3.ONE * 0.16)
	else:
		visual = _activities.host._make_role_visual("crate" if kind == "load" else "barrel", "environment", Vector3.ONE * 0.20)
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
	if quest.get("needs_garden_petition",false) and not _activities._flag("novel_petition_filed"): return false
	if str(quest.get("previous", "")) != "" and not _activities.host.quests.is_completed(str(quest.previous)):
		return false
	if _activities.zone == "ruins" and not _activities._late_road_open():
		return false
	match str(quest.get("requires", "")):
		"bell": return _activities._flag("bell_eater_defeated") or _activities._flag("bell_eater_legacy_retired")
		"bog": return _activities.host.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch")
		"mill": return _activities._flag("ashwing_defeated") and (str(_activities.host.story_state.get_flag("mill_operation", "")) != "" or _activities.host.quests.is_completed("main_ash_at_the_mill"))
		"senn": return str(_activities.host.story_state.get_flag("senn_fate", "")) in ["testimony", "exile", "punished"]
		"ledger": return _activities._flag("vargan_ledger_choice_made") or _activities.host.quests.is_objective_done("main_blood_under_stone", "ledger_choice") or _activities.host.quests.is_completed("main_blood_under_stone")
		"halvern": return str(_activities.host.story_state.get_flag("halvern_fate", "")) in ["witness", "released", "destroyed"]
		"hart": return _activities._flag("final_choice_completed")
	return true

func _late_road_open() -> bool:
	return _activities.host.quests.is_unlocked("main_hart_remembers") or _activities.host.quests.is_active("main_hart_remembers") or _activities._flag("final_choice_completed")

func _secret_available(secret: Array) -> bool:
	if _activities.zone == "ruins" and not _activities._late_road_open():
		return false
	match str(secret[6]):
		"water": return _activities.host.quests.is_completed("saga_wyc_q05")
		"hart": return _activities._flag("final_choice_completed")
		"passage": return _activities._flag("command_proof_recovered") or _activities.host.story_state.has_evidence("vargan_ledger") or _activities._flag("vargan_service_passage_known")
	return true

func _dress_aftermath(area: Node3D, id: String) -> void:
	_activities._ensure_assembly(id)
	var old_prop: Variant = area.get_node_or_null("WorkProp")
	if old_prop != null:
		old_prop.visible = false

func _ensure_assembly(id: String) -> void:
	var assembly: Node3D = _activities._assemblies.get(id)
	var complete: bool = _activities.host.quests.is_completed(id)
	var outcome: Variant = str(_activities.host.story_state.get_flag(id + "_outcome", ""))
	if is_instance_valid(assembly) and str(_activities.read_tag(assembly, "recorded_outcome", "")) != outcome:
		assembly.get_parent().queue_free()
		assembly = null
	if not is_instance_valid(assembly):
		var anchor: Variant = Node3D.new()
		anchor.name = id + "_workplace"
		var site: Variant = str(_activities.Catalog.PRESENTATION_SITES.get(id, _activities.Catalog.quest_row(id,_activities.host.story_state).site))
		if id == "side_escort_06" and _activities.zone == "greyfen":
			site = "arrivals"
		anchor.position = _activities._site_position(site, id + "_workplace")
		_activities.add_child(anchor)
		assembly = _activities.WorkPresentation.build(_activities.host, anchor, id, complete, outcome)
		_activities._assemblies[id] = assembly
	_activities.WorkPresentation.sync_progress(assembly, _activities.host, id)
	if id == "side_escort_03":
		_activities.write_tag(assembly, "lowering", _activities.host.quests.is_objective_done(id, "choose_load"))
