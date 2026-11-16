extends RefCounted
## combat boss view: scene effects and consequence presentation.

var _actor: Node3D

func _init(actor: Node3D) -> void:
	_actor = actor

func _boss_is_resolved(id: String) -> bool:
	if id == "bell_eater" and bool(_actor.story_state.get_flag("bell_eater_legacy_retired", false)):
		return true
	if id == "bog_wretch" and _actor.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
		return true
	if id == "captain_senn" and (_actor.quests.is_objective_done("main_soldier_without_banner", "senn_confrontation") or str(_actor.story_state.get_flag("senn_fate", "")) not in ["", "unresolved"]):
		return true
	if not bool(_actor.enemy_defs.get(id, {}).get("boss", false)):
		return false
	var story_resolved: String = str({
		"bell_eater": "bell_eater_defeated",
		"rootbound_colossus": "rootbound_colossus_defeated",
		"ashwing": "ashwing_defeated",
	}.get(id, ""))
	if story_resolved != "" and bool(_actor.story_state.get_flag(story_resolved, false)):
		return true
	if id == "white_hart_avatar" and bool(_actor.story_state.get_flag("final_choice_completed", false)):
		return true
	var saved: Variant = _actor.boss_saved_states.get(id, {})
	if typeof(saved) == TYPE_DICTIONARY:
		var saved_outcome: Variant = str(saved.get("outcome", ""))
		return saved_outcome in ["defeated", "release", "testimony", "witness", "mercy", "duty", "ash", "concord", "open_road"]
	return false

func _ensure_bell_eater() -> void:
	if _actor.current_zone_id != "greyfen" or _actor._boss_is_resolved("bell_eater"):
		return
	for enemy in _actor.active_enemies:
		if is_instance_valid(enemy) and str(_actor.read_presentation_tag(enemy, "boss_id", "")) == "bell_eater" and not enemy.dead:
			return
	# The chapel shell is occupied scenery. Spawn the boss in the broad west
	# cemetery approach so spatial recovery cannot relocate it outside its arena.
	var boss: Variant = _actor._spawn_enemy("bell_eater", Vector3(10.0, 0.8, 8.0))
	if boss != null:
		boss.name = "BellEaterEncounter"
		boss.leash_radius = 9.0
		_actor.write_presentation_tag(boss, "boss_arena", "cemetery")
		_actor._evacuate_bell_eater_bystanders()
		_actor.hud.show_status_cue("The Bell-Eater wakes", "danger")
		_actor.hud.toast("The bell rings once beneath the chapel. Something large pulls against the graves.")
		_actor._show_current_objective_guidance(6.0)
		_actor.audio.play_event("boss", 0.02)

func _retire_bell_eater() -> void:
	for enemy in _actor.active_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		if str(enemy.enemy_id) != "bell_eater" and not bool(_actor.read_presentation_tag(enemy, "bell_called_ghoulkin", false)):
			continue
		if enemy.dead:
			continue
		enemy.set_encounter_active(false)
		_actor.active_enemies.erase(enemy)
		if _actor.active_enemy_attacker == enemy:
			_actor.active_enemy_attacker = null
		enemy.queue_free()
	_actor._restore_bell_eater_bystanders()
	if _actor.camera_rig != null:
		_actor.camera_rig.clear_target_lock()
	if _actor.hud != null:
		_actor.hud.hide_enemy()
	_actor._sync_camera_enemy_cache()

func _open_rootbound_encounter() -> void:
	_actor.story_state.set_flag("rootbound_arena_entered", true)
	for enemy in _actor.active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id) == "rootbound_colossus":
			_actor.write_presentation_tag(enemy, "dormant_arena", false)
			enemy.set_physics_process(true)
	var invitation: Node = _actor.zone_root.find_child("rootbound_challenge", true, false) if _actor.zone_root != null else null
	if invitation != null:
		_actor._remove_interaction_candidate(invitation)
		invitation.queue_free()
	_actor.hud.toast("The guardian braces around the name-board. Follow the root channels before its heart opens.")

func _evacuate_bell_eater_bystanders() -> void:
	if _actor.zone_root == null:
		return
	var staging: Variant = {
		"sister_anwen": Vector3(9.2, 0.0, 5.2),
		"widow_elna": Vector3(8.6, 0.0, 6.0),
	}
	for actor_id in staging:
		var actor: Variant = _actor.zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or bool(_actor.read_presentation_tag(actor, "bell_eater_evacuated", false)):
			continue
		_actor.write_presentation_tag(actor, "bell_eater_evacuated", true)
		_actor.write_presentation_tag(actor, "bell_eater_return_position", actor.global_position)
		actor.global_position = _actor.validate_walkable_position(staging[actor_id])
		if actor is Area3D:
			(actor as Area3D).monitoring = false
			(actor as Area3D).monitorable = false
		var driver: Variant = actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and (driver != null):
			driver.set_dialogue_pose(true)
		_actor._systems["dialogue"]._face_npc_toward_player(actor)

func _restore_bell_eater_bystanders() -> void:
	if _actor.zone_root == null:
		return
	for actor_id in ["sister_anwen", "widow_elna"]:
		var actor: Variant = _actor.zone_root.find_child(actor_id, true, false) as Node3D
		if actor == null or not bool(_actor.read_presentation_tag(actor, "bell_eater_evacuated", false)):
			continue
		var original: Variant = _actor.read_presentation_tag(actor, "bell_eater_return_position", actor.global_position)
		if original is Vector3:
			actor.global_position = _actor.validate_walkable_position(original)
		if actor is Area3D:
			(actor as Area3D).monitoring = true
			(actor as Area3D).monitorable = true
		_actor.write_presentation_tag(actor, "bell_eater_evacuated", false)
		var driver: Variant = actor.find_child("CharacterAnimationDriver", true, false)
		if driver != null and (driver != null):
			driver.set_dialogue_pose(false)

func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void:
	_actor.story_state.set_flag("boss_%s_phase" % boss_id, phase)
	if _actor.audio != null:
		_actor.audio.set_music_state("boss_%s" % boss_id)

func _on_boss_checkpoint(controller: Node) -> void:
	if controller == null:
		return
	var boss_id: Variant = str(controller.get("boss_id"))
	var state: Dictionary = controller.save_state() if (controller != null) else {}
	_actor.boss_saved_states[boss_id] = state
	_actor.story_state.set_flag("boss_%s_checkpoint" % boss_id, int(controller.get("checkpoint")))
	# A phase boundary is an authored checkpoint. It must survive a reload even
	# when the player dies before the next ordinary autosave boundary.
	if _actor.save_manager != null and _actor.player != null and is_instance_valid(_actor.player) and not _actor.resource_shutdown_prepared:
		_actor.save_manager.checkpoint(_actor._host)

func _on_boss_resolved(boss_id: String, outcome: String) -> void:
	_actor.story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	_actor._apply_boss_resolution_contract(boss_id)
	_actor._collect_progression_rewards()
	for candidate in _actor.active_enemies:
		if not is_instance_valid(candidate) or str(candidate.enemy_id) != boss_id:
			continue
		var controller: Node = candidate.get_node_or_null("BossEncounterController")
		if controller != null and (controller != null):
			_actor.boss_saved_states[boss_id] = controller.save_state()
		break
	if _actor.save_manager != null and _actor.player != null and is_instance_valid(_actor.player) and not _actor.resource_shutdown_prepared:
		_actor.save_manager.checkpoint(_actor._host)

func _apply_boss_resolution_contract(boss_id: String) -> void:
	var definition: Dictionary = _actor.boss_defs.get(boss_id, {})
	if definition.is_empty():
		return
	var grant_key: Variant = "boss_reward_granted_%s" % boss_id
	if not bool(_actor.story_state.get_flag(grant_key, false)):
		var rewards: Variant = definition.get("rewards", [])
		if typeof(rewards) == TYPE_ARRAY:
			for reward_id in rewards:
				var reward: Variant = str(reward_id).strip_edges()
				if reward != "":
					_actor.story_state.set_flag("boss_reward_%s" % reward, true)
		_actor.story_state.set_flag(grant_key, true)
	var aftermath: Variant = str(definition.get("aftermath_state", "")).strip_edges()
	if aftermath != "":
		_actor.story_state.set_flag(aftermath, true)

func _publish_halvern_exit() -> void:
	if _actor.current_zone_id == "undercroft" and str(_actor.story_state.get_flag("halvern_fate", "")) != "" and not _actor._has_interactable("gate_record_hall"):
		_actor._make_zone_gate("Return through the Record Hall toward Greyfen", Vector3(-6, 0, 14), "record_hall", Vector3(6, 0.95, -12))

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	_actor.story_state.set_flag("boss_%s_outcome" % boss_id, outcome)
	if boss_id == "halvern_boss":
		_actor.story_state.set_flag("halvern_fate", "witness" if outcome in ["testimony", "release", "witness"] else outcome)
		_actor._publish_halvern_exit()
		if _actor.current_zone_id == "undercroft":
			_actor.quests.complete_objective("main_last_witness", "break_halvern_guard")
			_actor.hud.show_status_cue("Halvern lowers his blade", "victory")
			_actor.hud.toast("The knight will speak. The undercroft no longer needs a gravekeeper.")
			if enemy != null:
				enemy.set_encounter_active(false)
	elif boss_id == "white_hart_avatar":
		var covenant: Variant = str({"witness":"witness", "mercy":"mercy", "release":"mercy", "duty":"duty", "ash":"ash"}.get(outcome, outcome))
		_actor.story_state.set_flag("final_covenant", covenant)
		_actor.story_state.set_flag("final_choice_completed", true)
		_actor.quests.complete_objective("main_hart_remembers", "final_choice")
		if _actor.current_zone_id == "hart_glade":
			_actor.hud.show_status_cue("The Hart accepts the oath", "victory")
			_actor.hud.toast("The road remembers %s." % covenant.capitalize())
			if enemy != null:
				enemy.set_encounter_active(false)

func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	var cue: Variant = "The arena shifts beneath the witness."
	if enemy.enemy_id == "white_hart_avatar":
		cue = "The Hart tears roots from the old road." if phase == 2 else "The covenant is breaking."
	elif enemy.enemy_id == "bell_eater":
		cue = "The bell harness splits. The dead answer from below."
	elif enemy.enemy_id == "rootbound_colossus":
		cue = "The roots tear open around its heart."
	elif enemy.enemy_id == "ashwing":
		cue = "Ashwing breaks from the mill roof."
	elif enemy.enemy_id == "halvern_boss":
		cue = "Halvern stops defending the old command."
	_actor.hud.show_status_cue("%s — Phase %d" % [enemy.display_name, phase], "danger")
	_actor.hud.toast(cue)
	_actor.audio.set_music_state("boss_%s" % str(enemy.enemy_id))
	_actor.audio.play_event("reveal" if phase == 2 else "boss", 0.025)
	if _actor.world_vfx != null and is_instance_valid(_actor.world_vfx):
		_actor.world_vfx.pulse_interaction(enemy.global_position)
		_actor.CombatFeedback.impact_burst(_actor.zone_root, enemy.global_position + Vector3.UP, true, Color(0.58, 0.88, 0.72))

func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if _actor.zone_root != null:
		var attack_direction: Vector3 = -enemy.global_transform.basis.z
		_actor.CombatFeedback.boss_attack_release(_actor.zone_root, contact_position, attack_direction, attack_id, radius, parried)
	var cue: String = str({
		"bell_shockwave": "Bell shockwave",
		"grave_slam": "Grave slam",
		"ghoulkin_call": "The graves answer",
		"root_lanes": "Root lanes split the clearing",
		"ground_rupture": "The ground remembers the rupture",
		"heart_stagger": "The oathwood heart is exposed",
		"wing_blast": "Ashwing's wings break the air",
		"ash_breath": "Ash breath fills the mill",
		"swoop": "Ashwing drops from the smoke",
		"parry_test": "Halvern tests the guard",
		"counter_lunge": "Halvern answers the opening",
		"memory_echo": "The Hart returns a memory",
		"antler_sweep": "The Hart sweeps the old road",
		"road_reopening": "The road opens beneath the witness",
	}.get(attack_id, "The arena answers"))
	_actor.hud.show_status_cue(cue, "danger" if not parried else "parry")
	_actor.audio.play_event_limited("parry" if parried else "boss", 0.18, 0.025)
	if attack_id == "ghoulkin_call" and not bool(_actor.read_presentation_tag(enemy, "called_ghoulkin", false)):
		_actor.write_presentation_tag(enemy, "called_ghoulkin", true)
		var call_position: Vector3 = enemy.global_position + Vector3(2.2, 0.8, 1.4)
		var called: Variant = _actor._spawn_enemy("ghoulkin", call_position)
		if called != null:
			_actor.write_presentation_tag(called, "bell_called_ghoulkin", true)
			called.leash_radius = 8.0
			_actor.hud.toast("A Ghoulkin claws up through the bell's shadow.")

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	_actor.wychwood_encounter_started = true
	for enemy in _actor.active_enemies:
		if enemy != null and not enemy.dead and not enemy.is_encounter_active() and enemy.enemy_id in ids:
			enemy.set_encounter_active(true)
			break
	if _actor.hud != null:
		_actor.hud.toast(cue)
	if _actor.audio != null:
		_actor.audio.play_event("reveal", 0.02)

func _ensure_wychwood_wave() -> void:
	if _actor.wychwood_pack_kills >= 5 or _actor.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		return
	for enemy in _actor.active_enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.has_meta("wychwood_wave"):
			continue
		if int(_actor.read_presentation_tag(enemy, "wychwood_wave")) != _actor.wychwood_pack_kills:
			continue
		_actor.wychwood_encounter_started = true
		if not enemy.is_encounter_active():
			enemy.set_encounter_active(true)
			if _actor.hud != null:
				_actor.hud.toast("Movement answers from the clearing.")
		return

func checkpoint_return_position() -> Vector3:
	var recorded: Vector3 = _actor.player.global_position
	if _actor.spatial_service == null or not _actor._story_has_active_combat():
		return recorded
	var bank: int = _actor.spatial_service.bank_for(recorded)
	var best: Vector3 = recorded
	var best_clearance: Variant = -1.0
	var anchors: Array = _actor.spatial_service.safe_spawns.duplicate()
	anchors.append_array(_actor.spatial_service.recovery_anchors)
	for anchor: Vector3 in anchors:
		if _actor.spatial_service.bank_for(anchor) != bank or not _actor.spatial_service.is_walkable_position(anchor, 0.55, bank):
			continue
		var clearance: Variant = INF
		for enemy in _actor.active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
				clearance = minf(clearance, anchor.distance_to(enemy.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			best = anchor
	return best if best_clearance >= 5.0 else recorded

func _has_active_encounter_enemy() -> bool:
	for enemy in _actor.active_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.dead and enemy.is_encounter_active():
			return true
	return false

func _enemy_attack_token(enemy: Node, claim: bool) -> bool:
	if claim:
		if _actor.active_enemy_attacker != null and is_instance_valid(_actor.active_enemy_attacker) and _actor.active_enemy_attacker != enemy:
			return false
		_actor.active_enemy_attacker = enemy
		return true
	if _actor.active_enemy_attacker == enemy:
		_actor.active_enemy_attacker = null
	return true
