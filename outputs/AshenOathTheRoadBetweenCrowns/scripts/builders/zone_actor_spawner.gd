extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
var _host: Api
var _scope: Scope
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
func _make_clue(id: String, prompt: String, pos: Vector3, quest_id: String, objective_id: String, color: Color) -> Variant:
	var area = _host._make_named_interactable(id, "clue", prompt, pos, color, Vector3(0.55, 0.25, 0.55))
	if area == null:
		return null
	area.quest_id = quest_id
	area.objective_id = objective_id
	if _scope.spatial_service != null and id in ["corpse", "bandit_camp"]:
		_scope.spatial_service.add_presence_landmark("scavenge" if id == "corpse" else "camp", area.position, 0.6)
	return area
func _make_named_interactable(id: String, type: String, prompt: String, pos: Vector3, color: Color, scale_override: Vector3 = Vector3.ONE) -> Variant:
	if _host._is_interaction_removed(id):
		return null
	pos = _host.river_safe_position(pos,0.8)
	var area = _host.Interactable.new()
	area.setup(id, type, prompt)
	area.position = pos
	area.build_collision(2.8 if type == "zone" else 1.45)
	_scope.zone_root.add_child(area)
	var prop_spec: Variant = _host._world_prop_spec(id)
	if not prop_spec.is_empty():
		_host.write_construction_tag(area, "world_prop_id", id)
		var prop_component: Variant = _host.InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", _host.story_state)
	var role = _host._role_for_interactable(id)
	var presentation_id: String = {"witness_-7": "mira", "witness_-3": "rook", "witness_3": "sister_anwen"}.get(id, id)
	if id in ["notice_board", "side_contracts"]:
		_host.write_construction_tag(area, "external_world_prop", "notice_board")
	elif id == "white_hart":
		var witness: Node3D = _scope.zone_root.find_child("WhiteHartWitnessDisplay", true, false)
		if witness == null:
			witness = _host.CharacterPresentation.make_hart_witness(_host.asset_helper, pos)
			if witness == null:
				_host.CharacterAnimationDriver.record_configuration(_scope.zone_root, id, null)
				area.queue_free()
				return null
			_scope.zone_root.add_child(witness)
		_host.CharacterAnimationDriver.record_configuration(_scope.zone_root, "white_hart_witness", witness.find_child("HartWitnessAnimation", true, false))
		_host.write_construction_tag(area, "external_character_visual", "WhiteHartWitnessDisplay")
	elif id.begins_with("covenant_"):
		_host.write_construction_tag(area, "external_story_visual", "covenant_record")
	elif id in ["crow_shrine_choice", "rootbound_challenge"]:
		_host.write_construction_tag(area, "external_story_visual", "authored_shrine")
	elif id in ["oren_token", "retain_evidence"]:
		_host._make_token_interaction_visual(area, Vector3.ONE * 0.65)
	elif type == "clue" and _scope.zone_id == "wychwood" and _host.WychwoodEvidencePresentation.apply(area, id):
		pass
	elif type == "clue" and _host.CemeteryEvidencePresentation.apply(area, id):
		pass
	elif _host.CampaignRecordPresentation.apply(area, id):
		pass
	elif _host.should_defer_character_role(role, id):
		var marker: Variant = Node3D.new()
		marker.name = "DeferredCharacterVisual_%s" % id
		_host.write_construction_tag(marker, "deferred_visual_role", role)
		_host.write_construction_tag(marker, "deferred_visual_category", "characters")
		_host.write_construction_tag(marker, "deferred_visual_actor_id", presentation_id)
		_host.write_construction_tag(marker, "deferred_visual_scale", Vector3.ONE)
		area.add_child(marker)
		_host.write_construction_tag(area, "character_variant_seed", presentation_id)
	else:
		var mapped = _host._make_role_visual(role, "characters", Vector3.ONE)
		if mapped != null:
			area.add_child(mapped)
			_host.write_construction_tag(area, "character_variant_seed", presentation_id)
			if not _host._configure_npc_animation(mapped, presentation_id):
				area.queue_free()
				return null
		elif str(role) != "":
			_host.CharacterAnimationDriver.record_configuration(_scope.zone_root, presentation_id, null)
			area.queue_free()
			return null
		elif id in ["assembly_choice", "witness_7"]:
			_host._make_ledger_interaction_visual(area, Vector3.ONE)
			var book: Variant = area.get_node("SealedCommandLedgerVisual") as Node3D
			book.position.y = 0.83
		elif id == "vargan_ledger_choice":
			_host._make_ledger_interaction_visual(area, scale_override)
		elif id == "post_victory_token":
			_host._make_token_interaction_visual(area, scale_override)
		elif type == "zone" or type == "blocked_zone":
			_host._make_gate_marker(area, color, scale_override)
		else:
			var mesh = MeshInstance3D.new()
			mesh.mesh = CapsuleMesh.new()
			mesh.scale = Vector3(0.45, 0.85, 0.45) * scale_override
			mesh.position.y = 0.85 * scale_override.y
			mesh.material_override = _host._mat(color)
			area.add_child(mesh)
	var has_character_role: bool = str(role) != ""
	if has_character_role:
		preload("res://scripts/story_cast_profile.gd").register_actor(_scope.zone_root, area, presentation_id)
	if type == "dialogue" and id not in ["notice_board", "white_hart"] and has_character_role and not _host.should_defer_character_role(role, id):
		_host.CharacterPresentation.apply_npc(area, presentation_id)
	if _scope.zone_id == "assembly" and id in ["witness_-7", "witness_-3", "witness_3"]:
		for witness_mesh in area.find_children("*", "MeshInstance3D", true, false):
			witness_mesh.visibility_range_end = maxf(witness_mesh.visibility_range_end, 32.0)
	if type != "clue" and type != "herb" and id != "notice_board":
		_host._make_interaction_label(area, _host._label_for_interactable(id, prompt), Vector3(0, 2.15 * max(scale_override.y, 0.75), 0), 14 if type == "zone" else 16, 0.0038 if type == "zone" else 0.0048, true)
	if type == "dialogue" and id != "notice_board" and has_character_role:
		var ambient = _host.NpcAmbient.new()
		ambient.setup(presentation_id, _host.player, _host)
		area.add_child(ambient)
	_host._connect_interactable(area)
	return area
func _make_zone_gate(prompt: String, pos: Vector3, zone_target: String, spawn_pos: Vector3) -> Variant:
	var homeward: bool = bool(_host.story_state.get_flag("final_choice_completed", false)) and ((_scope.zone_id == "hart_glade" and zone_target == "assembly") or (_scope.zone_id == "assembly" and zone_target == "undercroft"))
	if homeward:
		zone_target = "greyfen"
		spawn_pos = Vector3(0, 1, 9.8)
		prompt = "Walk the road home to Greyfen"
	var area = _host._make_named_interactable("gate_%s" % zone_target, "zone", prompt, pos, Color(0.18, 0.22, 0.28), Vector3(1.0, 1.2, 1.0))
	if area == null:
		return null
	area.zone_target = zone_target
	_host.write_construction_tag(area, "spawn_pos", spawn_pos)
	for child in area.get_children():
		if child is MeshInstance3D:
			child.visible = false
	if (_scope.zone_id == "greyfen" and zone_target == "assembly") or (_scope.zone_id == "assembly" and zone_target == "greyfen"):
		_host.write_construction_tag(area, "civic_phase",true)
		return area
	if homeward:
		_host.write_construction_tag(area, "homecoming_route", true)
		return area
	if _host.seamless_world != null and _host.seamless_world.should_suppress_exterior_gate(_scope.zone_id, zone_target):
		_host.write_construction_tag(area, "seamless_exterior_gate", true)
		_host.write_construction_tag(area, "interactive_road_entrance", true)
		area.display_name = _host.coordinator._zone_display_name(zone_target)
		area.prompt = "Travel " + area.display_name
		if not WorldSectorManifest.is_exterior(_scope.zone_id) or not WorldSectorManifest.is_exterior(zone_target):
			_host.write_construction_tag(area, "interior_door",true)
		return area
	if _host.seamless_world != null and _host.seamless_world.should_use_physical_door(_scope.zone_id, zone_target):
		_host.write_construction_tag(area, "interior_door", true)
		_host._add_physical_door_visual(area, zone_target)
		return area
	var portal: Variant = _host.OathGatePortal.new()
	portal.name = "OathGatePortal"
	portal.configure(zone_target, "gate_%s" % zone_target)
	if (portal != null):
		portal.bind_audio(_host.audio)
	area.add_child(portal)
	if _host.zone_streaming != null and (portal != null):
		portal.bind_streaming(_host.zone_streaming)
		if (_host.zone_streaming != null) and _host.zone_streaming.is_embedded_destination(zone_target):
			portal.set_ready()
	else:
		portal.set_state(_host.OathGatePortal.PortalState.READY)
	return area
func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	if _host._boss_is_resolved(id):
		return null
	if _scope.active_enemies.filter(func(actor: Node) -> bool: return is_instance_valid(actor) and not actor.dead).size() >= 5:
		return null
	pos = _host.river_safe_position(pos,1.2)
	var reward_key: Variant = "%s:%.2f:%.2f" % [id,pos.x,pos.z]
	if bool(_host.story_state.get_flag("ordinary_surrender:"+_scope.zone_id+":"+reward_key,false)):return null
	if not _host.CharacterRoleSpec.is_airborne(id):
		pos.y = 0.0
	var enemy = _host.EnemyAI.new()
	_host.write_construction_tag(enemy, "progression_reward_id", "%s:%.2f:%.2f" % [id, pos.x, pos.z])
	_host.write_construction_tag(enemy, "progression_zone", _scope.zone_id)
	_host.write_construction_tag(enemy, "ordinary_surrender_eligible",id=="bandit" and _scope.zone_id=="wychwood")
	enemy.visual_role_override = visual_role
	enemy.visible = false
	_scope.zone_root.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(id, _host.enemy_defs.get(id, {}), _host.player)
	if not _host.CharacterAnimationDriver.record_configuration(_scope.zone_root, "%s:%s" % [id, enemy.get_instance_id()], enemy.animation_driver):
		enemy.queue_free()
		return null
	enemy.visible = true
	enemy.encounter_slot = _scope.active_enemies.size()
	enemy.setup_navigation(_scope.spatial_service)
	enemy.listen_to_world(_host.audio)
	if _scope.zone_id == "wychwood" and id in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute"]:
		_host.write_construction_tag(enemy, "progression_opening_wave", not _host.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"))
		enemy.set_encounter_active(false)
	enemy.attack_gate = _host.coordinator._enemy_attack_token
	if id == "ghoulkin":
		enemy.rotation_degrees.y = 180.0
		if not _host.neighbor_building and _host.audio != null and _scope.zone_id == "wychwood" and not bool(_host.tutorial_flags.get("ghoulkin_spawn_audio", false)):
			_host.tutorial_flags["ghoulkin_spawn_audio"] = true
			_host.audio.play_event("ghoulkin_idle", 0.025)
	enemy.died.connect(_host.coordinator._on_enemy_died)
	enemy.damaged.connect(_host.coordinator._on_enemy_damaged)
	enemy.windup_started.connect(_host.coordinator._on_enemy_windup_started)
	enemy.attack_resolved.connect(_host.coordinator._on_enemy_attack_resolved)
	if enemy.has_signal("special_attack_resolved"):
		enemy.special_attack_resolved.connect(_host.coordinator._on_boss_special_attack)
	if enemy.has_signal("parry_window_opened"):
		enemy.parry_window_opened.connect(_host.coordinator._on_enemy_parry_window_opened)
	enemy.boss_phase_changed.connect(_host.coordinator._on_boss_phase_changed)
	if bool(_host.enemy_defs.get(id, {}).get("boss", false)):
		var boss_controller: Node = Node.new()
		boss_controller.set_script(_host.BossEncounterScript)
		boss_controller.name = "BossEncounterController"
		enemy.add_child(boss_controller)
		var boss_definition: Dictionary = _host.enemy_defs.get(id, {}).duplicate(true)
		if _host.boss_defs.has(id) and typeof(_host.boss_defs[id]) == TYPE_DICTIONARY:
			boss_definition.merge(_host.boss_defs[id], true)
		boss_controller.configure(id, boss_definition, enemy, _host)
		if _host.boss_saved_states.has(id) and typeof(_host.boss_saved_states[id]) == TYPE_DICTIONARY:
			boss_controller.load_state(_host.boss_saved_states[id])
		if boss_controller.has_signal("phase_changed"):
			boss_controller.connect("phase_changed", Callable(_host.coordinator, "_on_boss_controller_phase_changed"))
		if boss_controller.has_signal("resolved"):
			boss_controller.connect("resolved", Callable(_host.coordinator, "_on_boss_resolved"))
	_scope.active_enemies.append(enemy)
	preload("res://scripts/story_encounter_director.gd").apply(_host, enemy)
	_host._sync_camera_enemy_cache()
	return enemy
func _configure_npc_animation(mapped: Node3D, id: String) -> bool:
	var existing: Variant = mapped.get_node_or_null("CharacterAnimationDriver")
	if existing != null:
		return _host.CharacterAnimationDriver.record_configuration(_scope.zone_root, id, existing)
	var clips: Variant = {
		"idle": "Idle", "walk": "Walk", "walk_back": "Walk",
		"strafe": "Walk", "run": "Sprint", "work": "Interact",
		"dialogue": "Idle_Talking", "hit": "Hit_Chest", "death": "Death01"
	}
	var family: Variant = str(_host.read_construction_tag(mapped, "character_animation_family", "")).to_lower()
	if family == "design_pack_native":
		clips = {"idle":"Idle", "walk":"Walking", "walk_back":"Walking", "strafe":"Walking", "run":"Running", "work":"Interact", "dialogue":"Interact", "hit":"HitReact", "death":"Death"}
		if id.begins_with("design_ecology:"):
			var ecology_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
			if ecology_data is Dictionary:
				for entry: Dictionary in ecology_data.get("sightings", []):
					if str(entry.role) == id.trim_prefix("design_ecology:"):
						clips["idle"] = str(entry.get("clip", "Idle"))
	elif family.contains("warrior"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("cleric"):
		clips.merge({"run": "Run", "work": "Idle_Weapon", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("rogue"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	elif family.contains("monk"):
		clips.merge({"run": "Run", "work": "Idle", "dialogue": "Idle", "hit": "RecieveHit", "death": "Death"}, true)
	if id == "sister_anwen":
		clips["idle"] = "Idle_Talking"
		clips["hit"] = "Hit_Chest"
		clips.erase("death")
	elif id == "injured_traveler":
		clips["idle"] = "Sitting_Idle"
		clips["dialogue"] = "Sitting_Talking"
		clips["work"] = "Sitting_Idle"
	elif id == "rook":
		clips["idle"] = "Idle_Talking"
		clips["hit"] = "Hit_Head"
	elif id in ["board_rook", "board_tor"]:
		clips["idle"] = "Sitting_Idle"
		clips["dialogue"] = "Sitting_Talking"
		clips["work"] = "Sitting_Talking"
		_host.write_construction_tag(mapped, "cast_activity_override", "")
	var driver = _host.CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	if not driver.configure(mapped, clips):
		_host.CharacterAnimationDriver.record_configuration(_scope.zone_root, id, driver)
		return false
	_host.CharacterAnimationDriver.record_configuration(_scope.zone_root, id, driver)
	if id not in ["board_rook", "board_tor"] and family != "design_pack_native":
		load("res://scripts/grounded_feet_modifier.gd").install_npc(mapped, driver)
	var npc_animation_rate: Variant = 8.0
	driver.set_update_rate_hz(npc_animation_rate)
	return true
func should_defer_character_role(_role: String, _actor_id: String) -> bool:
	return false
func _make_token_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var token_root: Variant = Node3D.new()
	token_root.name = "OrenTokenAndVarganWireVisual"
	token_root.scale = scale_override
	area.add_child(token_root)
	var token: Variant = MeshInstance3D.new()
	token.name = "OrenCompleteToken"
	var token_mesh: Variant = BoxMesh.new()
	token_mesh.size = Vector3(0.28, 0.07, 0.38)
	token.mesh = token_mesh
	token.position = Vector3(-0.12, 0.12, 0.0)
	token.rotation_degrees = Vector3(0.0, -24.0, 8.0)
	token.material_override = _host._mat(Color(0.48, 0.30, 0.12))
	token_root.add_child(token)
	var wire: Variant = MeshInstance3D.new()
	wire.name = "VarganBindingWire"
	var wire_mesh: Variant = TorusMesh.new()
	wire_mesh.inner_radius = 0.07
	wire_mesh.outer_radius = 0.09
	wire_mesh.rings = 8
	wire_mesh.ring_segments = 6
	wire.mesh = wire_mesh
	wire.position = Vector3(0.12, 0.15, 0.05)
	wire.rotation_degrees = Vector3(78.0, 12.0, 14.0)
	var wire_material: Variant = _host._mat(Color(0.13, 0.13, 0.12))
	wire_material.metallic = 0.55
	wire_material.roughness = 0.48
	wire.material_override = wire_material
	token_root.add_child(wire)
func _remove_interactable(id: String) -> void:
	if _scope.zone_root == null:
		return
	for child in _scope.zone_root.get_children():
		if str(child.get("interaction_id")) == id:
			if (child != null):
				child.set_interaction_enabled(false)
			if _scope.zone_root == _host.coordinator.zone_root: _host.coordinator._remove_interaction_candidate(child)
			_scope.unregister_actor(child)
			child.queue_free()
func _has_interactable(id: String) -> bool:
	if _scope.zone_root == null:
		return false
	for child in _scope.zone_root.get_children():
		if not child.is_queued_for_deletion() and (str(child.name) == id or str(child.get("interaction_id")) == id):
			return true
	return false
func _has_living_enemy(enemy_id: String) -> bool:
	for enemy in _scope.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == enemy_id:
			return true
	return false
func _build_design_pack_ecology(only_index: int = -1) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_ecology.json"))
	if not data is Dictionary:
		push_error("Required design-pack ecology data is unavailable")
		return
	var sightings: Array = data.get("sightings",[])
	for index in sightings.size():
		if only_index >= 0 and index != only_index: continue
		var sighting: Dictionary = sightings[index]
		if str(sighting.zone) != _scope.zone_id:
			continue
		var id: Variant = "design_ecology:" + str(sighting.role)
		var publication_key: Variant = id.replace(":", "_")
		if _scope.zone_root.has_meta(publication_key):
			continue
		var p: Array = sighting.position
		var area: Node3D = _host._make_named_interactable(id, "story_activity", "Observe " + str(sighting.name), Vector3(float(p[0]), 0, float(p[2])), Color.WHITE)
		if area == null:
			continue
		_host.write_construction_tag(area, "design_ecology", sighting)
		area.rotation_degrees.y = float(sighting.get("yaw", 0))
		for child: Node in area.get_children():
			if child is Node3D and child.has_meta("character_animation_family"):
				child.position.y += float(p[1])
				var offset: Array = sighting.get("visual_offset", [0, 0, 0])
				child.position += Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		var driver: Variant = area.find_child("CharacterAnimationDriver", true, false)
		if driver != null:
			_host.write_construction_tag(driver, "ecology_clip", str(sighting.get("clip", "Idle")))
		_host.write_construction_tag(_scope.zone_root, publication_key, true)
func _make_narrative_aftermath(zone_id: String) -> void:
	if _scope.zone_root == null:
		return
	if zone_id == "wychwood":
		if _host.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin") or bool(_host.story_state.get_flag("wychwood_pack_cleared", false)):
			_host._make_post_ghoulkin_story_clue()
			_host._append_prepared_detail("WychwoodPackAshResidue_b4fd8b7b91")
			_host._append_prepared_detail("WychwoodPackBrokenBinding_c070cc1a73")
		if bool(_host.story_state.get_flag("all_road_evidence", false)) and not _host.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			_host._make_all_evidence_safe_edge()
		for evidence in [
			["bram", Vector3(-2.0, 0.10, 7.4), Color(0.30, 0.18, 0.12)],
			["sella", Vector3(-4.0, 0.10, 4.0), Color(0.24, 0.035, 0.03)],
			["oren", Vector3(3.8, 0.10, 2.2), Color(0.48, 0.36, 0.18)],
			["vargan_wire", Vector3(2.5, 0.10, 4.8), Color(0.14, 0.14, 0.13)],
			["drag_marks", Vector3(0.0, 0.09, -4.2), Color(0.09, 0.055, 0.035)]
		]:
			if _host.quests.is_objective_done("main_road_of_crows", str(evidence[0])) or bool(_host.story_state.get_flag("road_evidence_%s" % evidence[0], false)):
				var marker: Variant = _host._make_visual_box("ExaminedEvidence_%s" % evidence[0], evidence[1], Vector3(0.34, 0.025, 0.34), evidence[2])
				_host.write_construction_tag(marker, "narrative_state", "examined")
	elif zone_id == "greyfen":
		var report_method: Variant = str(_host.story_state.get_flag("evidence_report", ""))
		if report_method != "":
			var report_colors: Variant = {
				"private": Color(0.58, 0.50, 0.34),
				"public": Color(0.62, 0.18, 0.12),
				"retained": Color(0.25, 0.22, 0.18)
			}
			_host._make_visual_box("GreyfenReportedNotice", Vector3(-1.98, 1.18, 9.34), Vector3(0.46, 0.58, 0.025), report_colors.get(report_method, Color(0.5, 0.45, 0.34)))
			_host._append_prepared_detail("GreyfenWitnessCandle_2eae43d10b")
		if bool(_host.story_state.get_flag("cemetery_ambush_cleared", false)):
			_host._append_prepared_detail("CemeterySettledEarth_8df2d0e6f7")
			_host._append_prepared_detail("CemeteryAftermathLantern_4116c2053a")
func _make_post_ghoulkin_story_clue() -> void:
	if _scope.zone_root == null or _scope.zone_root.find_child("RoadCrowsPostVictoryBootTracks", true, false) != null:
		return
	_host._make_dark_track("RoadCrowsPostVictoryBootTracks", Vector3(0.95, 0.087, -4.25), Vector3(0.30, 0.026, 1.9), Color(0.020, 0.018, 0.015))
	_host._make_dark_track("RoadCrowsPostVictoryClawTracks", Vector3(1.45, 0.088, -4.75), Vector3(0.34, 0.025, 1.55), Color(0.060, 0.022, 0.016))
	_host._append_prepared_detail("RoadCrowsPostVictoryCutThread_632cbbbd56")
	_host._make_black_feather_scatter("RoadCrowsPostVictoryFeathers", Vector3(0.35, 0.11, -3.95), 4, 0.55)
	_host._make_named_interactable("post_victory_token", "clue", "Examine the token in the dead creature's hand", Vector3(1.35, 0.0, -4.55), Color(0.46, 0.28, 0.12), Vector3(0.55, 0.55, 0.55))
