extends RefCounted
const DEADLINE_MS := 120000
var owner: SceneTree
var stabilize_route_bearing := true
var route_camera_yaw := 0.0
var expected_ash_supply_arrows := 20
var failures: Array[String]:
	get: return owner.failures
var root: Window:
	get: return owner.root
var process_frame: Signal:
	get: return owner.process_frame
var physics_frame: Signal:
	get: return owner.physics_frame
var paused: bool:
	get: return owner.paused
func create_timer(seconds: float): return owner.create_timer(seconds)
const ACCEPTANCE_INPUT_MODE := "touch"
func _advance_toward_combat_target(game: Node, enemy: Node3D) -> void:
	var offset: Vector3 = enemy.global_position - game.player.global_position
	offset.y = 0.0
	var direction := offset.normalized()
	var forward: float = game.camera_rig.get_flat_forward().dot(direction)
	var right: float = game.camera_rig.get_flat_right().dot(direction)
	await _key(KEY_W, forward > 0.35)
	await _key(KEY_S, forward < -0.35)
	await _key(KEY_D, right > 0.35)
	await _key(KEY_A, right < -0.35)
	await _frames(6)

func _align_chapel_entrance(game: Node) -> void:
	if not failures.is_empty():
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _align_route_axis(game, 2, 8.29, KEY_W, KEY_S, "crow_shrine_entrance")

func _align_route_axis(game: Node, axis: int, target: float, negative_key: Key, positive_key: Key, label: String) -> void:
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 4000
	var settled_ticks := 0
	while Time.get_ticks_msec() < deadline:
		var error: float = target - game.player.global_position[axis]
		var drive := _alignment_drive(error, game.player.velocity[axis], game.player.deceleration, game.player.get_physics_process_delta_time())
		await _key(negative_key, drive < 0)
		await _key(positive_key, drive > 0)
		await physics_frame
		if Time.get_ticks_msec() >= deadline:
			break
		if absf(game.player.global_position[axis] - target) <= 0.08 and absf(game.player.velocity[axis]) < 0.2:
			settled_ticks += 1
		else:
			settled_ticks = 0
		if settled_ticks >= 3:
			break
	await _key(negative_key, false)
	await _key(positive_key, false)
	if settled_ticks < 3:
		_fail("Physical %s alignment timed out; position=%s" % [label, game.player.global_position])
	else:
		print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _alignment_drive(error: float, velocity: float, braking: float, step: float) -> int:
	if absf(error) <= 0.08:
		return 0
	# Brake before arrival; reversing at full speed produces a limit cycle.
	if absf(velocity) > 0.2:
		if error * velocity < 0.0:
			return 0
		var stopping := velocity * velocity / (2.0 * maxf(braking, 0.01)) + absf(velocity) * step
		if absf(error) <= stopping + 0.08:
			return 0
	return 1 if error > 0.0 else -1

func _await_focused_interaction(game: Node, interaction_id: String, label: String, timeout_ms: int = 3000) -> bool:
	if not failures.is_empty():
		return false
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if game.active_interactable != null and game.active_interactable.interaction_id == interaction_id and game.call("_interaction_target_valid", game.active_interactable) and Time.get_ticks_usec() >= game.interaction_input_block_until_usec:
			return true
		await process_frame
	_fail("%s did not receive real focus within %d ms; position=%s focus=%s" % [label, timeout_ms, game.player.global_position, game.active_interactable])
	return false

func _await_playable_zone(game: Node, zone_id: String, label: String) -> bool:
	if not failures.is_empty():
		return false
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and (game.current_zone_id != zone_id or game.zone_transition_pending or game.player.transition_locked or not game.player.can_control):
		await process_frame
	if game.current_zone_id != zone_id or game.zone_transition_pending or game.player.transition_locked or not game.player.can_control:
		_fail("%s did not become playable; zone=%s" % [label, game.current_zone_id])
		return false
	print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])
	return true

func _before_ashwing_attack(_game: Node) -> void:
	pass

func _break_halvern_guard(game: Node) -> void:
	if not game.quests.is_active("main_last_witness") or not game.quests.is_objective_done("main_last_witness", "reach_undercroft"):
		_fail("Undercroft Continue lost The Last Witness arrival")
		return
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "halvern_boss" and not candidate.dead:
			if boss != null:
				_fail("Undercroft Continue restored multiple Halverns")
				return
			boss = candidate
	if boss == null:
		_fail("Undercroft Continue did not restore Halvern")
		return
	var audio_sync: Dictionary = {}
	if OS.get_cmdline_user_args().has("--audio-sync-combat"):
		audio_sync = _observe_enemy_audio_sync(game, [boss])
	print("REAL_INPUT halvern_reload=PASS player=%s boss=%s" % [game.player.global_position, boss.global_position])
	await _turn_camera_north(game)
	await _move_until(game, KEY_W, "halvern_duel_approach", func(p: Vector3) -> bool: return p.distance_to(boss.global_position) < 2.4, 10000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 18000
	var parry_attempts := 0
	while Time.get_ticks_msec() < deadline and not bool(game.story_state.get_flag("halvern_guard_broken", false)):
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss) or boss.dead:
			_fail("Halvern duel ended before a real-input guard break")
			return
		if float(boss.get("pending_attack_time")) > 0.0 and float(boss.get("pending_attack_time")) < game.player.get_parry_window_duration() * 0.75:
			await _key(KEY_Q, true)
			await _frames(2)
			await _key(KEY_Q, false)
			parry_attempts += 1
			await _frames(8)
		else:
			await physics_frame
	if not bool(game.story_state.get_flag("halvern_guard_broken", false)) or not game.quests.is_objective_done("main_last_witness", "break_halvern_guard"):
		_fail("Real Q parry did not break Halvern's guard; attempts=%d player=%s boss=%s health=%.1f" % [parry_attempts, game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF, game.player.health_component.health])
		return
	print("REAL_INPUT halvern_guard_parry=PASS attempts=%d health=%.1f" % [parry_attempts, game.player.health_component.health])
	if not audio_sync.is_empty():
		if audio_sync.windup == 0 or audio_sync.parry == 0:
			_fail("Halvern audio input coverage is incomplete: " + JSON.stringify(audio_sync))
		print("REAL_INPUT parry_audio_sync=%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(audio_sync)])
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or not bool(slot.get("data", {}).get("story_state", {}).get("flags", {}).get("halvern_guard_broken", false)):
		_fail("Real pause-menu save did not retain Halvern guard break")
	else:
		print("REAL_INPUT halvern_parry_manual_save=PASS zone=undercroft")

func _check_enemy_audio_sync(game: Node, enemy: Node, phase: String, state: Dictionary) -> void:
	state[phase] += 1
	var event_name: String = "parry" if phase == "parry" else game.audio.enemy_event_name(enemy.enemy_id, phase)
	var variants: Array = game.audio.recorded_variants.get(event_name, [])
	var max_age := 0.30 if phase == "windup" else (0.12 if phase == "parry" else 0.08)
	for cue in game.audio.active_cue_order:
		if is_instance_valid(cue) and cue.playing and cue.stream is AudioStreamOggVorbis \
				and cue.stream in variants and cue.get_playback_position() <= max_age:
			return
	_fail("Actual enemy %s event did not start/coalesce its recorded %s cue in the signal frame" % [phase, event_name])

func _choose_assembly_testimony(game: Node) -> void:
	await owner._interact("witnesses_ready")
	await owner._close_dialogue()
	owner._check(game.quests.is_objective_done("main_crowns_without_mercy","gather_witnesses"),"Actual witness records complete the assembly preparation")
	await owner._choose_outcome("assembly_choice","confession_method","witnesses")
	owner._check(game.quests.is_completed("main_crowns_without_mercy") and game.quests.is_active("main_hart_remembers"),"Actual public testimony starts the finale")
	owner._check(str(game.story_state.get_flag("confession_method",""))=="witnesses","The assembly retains the chosen public account")
	await _save_campaign_checkpoint(game)

func _choose_focused_dialogue_action(_game: Node, interaction_id: String, _action_prefix: String, _label: String) -> void:
	if interaction_id=="edric_campaign":
		var outcome := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else "compelled" if OS.get_cmdline_user_args().has("--edric-compelled") else "cooperate"
		await owner._choose_outcome(interaction_id,"edric_stance",outcome)
	elif interaction_id=="vargan_ledger_choice":
		var flag := "vargan_ledger_hidden" if OS.get_cmdline_user_args().has("--ledger-hidden") else "vargan_ledger_left_copied" if OS.get_cmdline_user_args().has("--ledger-copied") else "vargan_ledger_taken_openly"
		await owner._choose_outcome(interaction_id,flag,true)
	else: _fail("Unreviewed authored action selector: "+interaction_id)

func _choose_mill_record(game: Node) -> void:
	await owner._choose_outcome("miller_record","mill_operation","closed")
	var next := "main_empty_tables" if owner.expanded else "main_soldier_without_banner"
	owner._check(game.quests.is_completed("main_ash_at_the_mill") and game.quests.is_active(next),"Ash unlocks the correct revision's next chapter")
	await _save_campaign_checkpoint(game)

func _clear_ash_mill_ghoulkin(game: Node) -> void:
	await _key(KEY_1, true)
	await _frames(2)
	await _key(KEY_1, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "sword":
		_fail("Sword input did not equip Kael for the mill clearing")
		return
	var deadline := Time.get_ticks_msec() + 90000
	var last_attack := 0
	var last_potion := 0
	var last_damage := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_ash_at_the_mill", "mill_encounter"):
			await _release_combat_movement()
			var ashwing_count := 0
			for candidate in game.active_enemies:
				if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "ashwing" and not candidate.dead:
					ashwing_count += 1
			if ashwing_count != 1:
				_fail("Mill victory staged %d living Ashwing bosses instead of one" % ashwing_count)
			else:
				print("REAL_INPUT ash_mill_cleared=PASS ashwing_count=1 player_health=%.1f" % game.player.health_component.health)
				await _save_ashwing_handoff(game)
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died before clearing the ash-bound mill")
			return
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and not candidate.dead and bool(candidate.get_meta("ash_mill_enemy", false)):
				enemy = candidate
				break
		if enemy == null:
			await _frames(5)
			continue
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_damage = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage > 22000:
			_fail("Ash mill combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				await _key(KEY_T, true)
				await _frames(2)
				await _key(KEY_T, false)
				await _frames(3)
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and Time.get_ticks_msec() - last_potion > 6000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		await _frames(3)
	_fail("Ash mill combat timed out before the encounter handoff")

func _clear_bell_summons_real_input(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	var last_attack := 0
	var last_potion := 0
	var observed: Node3D = null
	var observed_health := INF
	var last_progress := Time.get_ticks_msec()
	var defeated := 0
	while Time.get_ticks_msec() < deadline:
		var enemy: Node3D = null
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and bool(candidate.get_meta("bell_called_ghoulkin", false)) and not candidate.dead:
				enemy = candidate
				break
		if enemy == null:
			await _release_combat_movement()
			print("REAL_INPUT bell_summons_cleared=PASS defeated=%d health=%.1f" % [defeated, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died fighting the actual bell summon")
			return
		if enemy != observed:
			observed = enemy
			observed_health = INF
			last_progress = Time.get_ticks_msec()
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 20000:
			_fail("Bell summon combat stalled: player=%s enemy=%s health=%.1f" % [game.player.global_position, enemy.global_position, observed_health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			if game.camera_rig.get_locked_combat_target() != null:
				await _key(KEY_T, true)
				await _frames(2)
				await _key(KEY_T, false)
				await _frames(3)
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 65.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		await _frames(3)
		if is_instance_valid(enemy) and enemy.dead:
			defeated += 1
	_fail("Real-input bell summon cleanup timed out")

func _collect_castle_evidence(game: Node) -> void:
	if not game.quests.is_active("main_blood_under_stone") or not game.quests.is_objective_done("main_blood_under_stone", "reach_castle"):
		_fail("Castle evidence continuation lost the arrival beat")
		return
	await _move_until(game, KEY_D, "castle_mile_marker_lane", func(p: Vector3) -> bool: return p.x > -3.9, 10000)
	await _move_until(game, KEY_W, "castle_mile_marker_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_mile_marker", 8000)
	await _use_focused_interaction(game, "vargan_mile_marker", "castle_mile_marker")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "castle_cart_south_lane", func(p: Vector3) -> bool: return p.z < 3.5, 5000)
	await _move_until(game, KEY_D, "castle_cart_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_supply_cart", 7000)
	await _use_focused_interaction(game, "vargan_supply_cart", "castle_supply_cart")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_A, "castle_gate_center_lane", func(p: Vector3) -> bool: return p.x < 0.5, 6000)
	await _move_until(game, KEY_W, "castle_courtyard_door_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "gate_vargan_court", 10000)
	await _use_focused_interaction(game, "gate_vargan_court", "castle_courtyard_door")
	if not await _await_playable_zone(game, "vargan_court", "castle_courtyard_arrival"):
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "enter_courtyard"):
		_fail("Real Castle door travel did not complete enter_courtyard")
		return
	await _move_until(game, KEY_A, "castle_guard_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_gate_guard", 5000)
	await _use_focused_interaction(game, "vargan_gate_guard", "castle_gate_guard")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "speak_guard"):
		_fail("Real guard conversation did not complete speak_guard")
		return
	await _move_until(game, KEY_D, "castle_notice_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_gate_notice", 6000)
	await _use_focused_interaction(game, "vargan_gate_notice", "castle_gate_notice")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_blood_under_stone", "castle_evidence_ready"):
		_fail("Three physically inspected Castle clues did not complete evidence threshold")
		return
	print("REAL_INPUT castle_three_clues=PASS court=true guard=true evidence_ready=true")
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	if not bool(slot.get("ok", false)) or str(slot.get("data", {}).get("zone", "")) != "vargan_court":
		_fail("Real pause-menu save did not retain Castle courtyard evidence")
	else:
		print("REAL_INPUT castle_evidence_manual_save=PASS zone=vargan_court")

func _confront_edric(game: Node) -> void:
	var outcome := "exposed" if OS.get_cmdline_user_args().has("--edric-exposed") else ("compelled" if OS.get_cmdline_user_args().has("--edric-compelled") else "cooperate")
	if not bool(game.story_state.get_flag("castle_haunting_cleared", false)) or not game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"):
		_fail("Record Hall Continue lost the cleared haunting")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_D, "edric_east_of_archive_tables", func(p: Vector3) -> bool: return p.x > 3.25, 5000)
	await _move_until(game, KEY_W, "edric_north_of_ledger_table_sprint", func(p: Vector3) -> bool: return p.z < -10.3, 8000, true)
	# A transient edge-of-range focus during sprint braking is not arrival.
	# This north aisle is clear of the archive tables and away from the gate.
	await _move_until(game, KEY_A, "edric_conversation_approach", func(p: Vector3) -> bool: return p.x < 1.5, 6000)
	var choice := "Expose him now" if outcome == "exposed" else ("Compel a confession" if outcome == "compelled" else "Testify under protection")
	await _choose_focused_dialogue_action(game, "edric_campaign", choice, "edric_testimony")
	if not failures.is_empty():
		return
	if not game.quests.is_completed("main_blood_under_stone") or not game.quests.is_active("main_last_witness") or str(game.story_state.get_flag("edric_stance", "")) != outcome:
		_fail("Real Edric choice did not complete Blood Under Stone and begin The Last Witness")
		return
	print("REAL_INPUT edric_testimony=PASS stance=%s last_witness_active=true" % outcome)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "record_hall" or str(saved.get("story_state", {}).get("flags", {}).get("edric_stance", "")) != outcome:
		_fail("Real pause-menu save lost Edric's choice or Record Hall zone")
	else:
		print("REAL_INPUT edric_manual_save=PASS zone=record_hall stance=%s" % outcome)

func _continue_names_they_burned(game: Node) -> void:
	await owner._travel("greyfen")
	for id in ["register_anwen","register_tor"]:
		await owner._interact(id)
		await owner._close_dialogue()
	await owner._travel("burned_farmstead")
	await owner._interact("register_rook")
	await owner._close_dialogue()
	owner._check(game.quests.is_objective_done("main_names_they_burned","reconstruct_register"),"Three actual register fragments reconstruct the account")
	await owner._travel("old_mill")
	await _save_campaign_checkpoint(game)

func _continue_teeth_in_rain(game: Node) -> void:
	if not game.quests.is_active("main_teeth_in_rain") or not game.quests.is_completed("main_bell_beneath_greyfen"):
		_fail("Continue did not restore the completed Bell choice and Teeth in the Rain")
		return
	print("REAL_INPUT teeth_checkpoint=PASS choice=%s position=%s" % [game.story_state.get_flag("crow_shrine_state", ""), game.player.global_position])
	await _leave_chapel_for_south_road(game)
	await _move_until(game, KEY_A, "bridge_return_centerline", func(p: Vector3) -> bool: return p.x < 0.4, 10000)
	await _move_until(game, KEY_W, "village_north_bank", func(p: Vector3) -> bool: return p.z < 0.8, 7000)
	await _move_until(game, KEY_A, "mira_west_lane", func(p: Vector3) -> bool: return p.x < -5.8, 6000)
	await _move_until(game, KEY_W, "mira_frontage", func(p: Vector3) -> bool: return p.z < -0.65, 5000)
	await _use_focused_interaction(game, "mira", "mira_teeth_briefing")
	if failures.is_empty() and not game.quests.is_objective_done("main_teeth_in_rain", "speak_mira"):
		_fail("Mira's real dialogue did not complete the Teeth in the Rain briefing")
	var mira := game.zone_root.find_child("mira", true, false) as Node3D
	if failures.is_empty() and (mira == null or game.player.global_position.distance_to(mira.global_position) > 3.6):
		_fail("Dialogue staging moved Kael away from Mira's reachable frontage: %s" % game.player.global_position)
	elif failures.is_empty():
		print("REAL_INPUT speak_mira=PASS position=%s" % game.player.global_position)
	var objective: Dictionary = game.quest_presentation.get_objective_view_model()
	if failures.is_empty() and (str(objective.get("quest_id", "")) != "main_teeth_in_rain" or str(objective.get("objective_id", "")) != "read_chapel_names"):
		_fail("Mira's conversation left Greyfen tracking the wrong next beat: %s" % objective)
		return
	if failures.is_empty():
		await _turn_camera_north(game)
		await _move_until(game, KEY_S, "mira_to_bridge_lane", func(p: Vector3) -> bool: return p.z > 0.5, 5000)
		await _move_until(game, KEY_D, "mira_to_bridge_centerline", func(p: Vector3) -> bool: return p.x > -0.3, 6000)
		await _move_until(game, KEY_S, "chapel_south_bank", func(p: Vector3) -> bool: return p.z > 10.0, 7000)
		await _move_until(game, KEY_D, "chapel_names_east_lane", func(p: Vector3) -> bool: return p.x > 14.4, 10000)
		await _move_until(game, KEY_W, "chapel_names_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "chapel_names", 5000)
		await _use_focused_interaction(game, "chapel_names", "chapel_names")
		if failures.is_empty() and not game.quests.is_objective_done("main_teeth_in_rain", "read_chapel_names"):
			_fail("Real chapel-name inspection did not complete the next Teeth in the Rain beat")
		elif failures.is_empty():
			print("REAL_INPUT read_chapel_names=PASS position=%s" % game.player.global_position)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "chapel_to_south_road", func(p: Vector3) -> bool: return p.z > 10.3, 4000)
	await _move_until(game, KEY_A, "chapel_to_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 10000)
	await _move_until(game, KEY_W, "chapel_to_north_bank", func(p: Vector3) -> bool: return p.z < 0.8, 7000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "teeth_greyfen_to_wychwood", func(_p: Vector3) -> bool: return game.current_zone_id == "wychwood" and not game.zone_transition_pending and not game.player.transition_locked and game.player.can_control, 12000)
	if not failures.is_empty():
		return
	await _continue_wychwood_teeth(game)

func _continue_wychwood_teeth(game: Node) -> void:
	await owner._interact("ritual_stones")
	await owner._close_dialogue()
	owner._check(game.quests.is_objective_done("main_teeth_in_rain","name_the_dead"),"Oren's name is spoken through the actual ritual stones")
	await owner._interact("saga_bog_challenge")
	var bog: Node3D
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.enemy_id)=="bog_wretch" and not enemy.dead: bog=enemy; break
	if bog==null:
		_fail("Actual northern Wychwood invitation did not stage the Bog Wretch")
		return
	await _fight_bog_wretch(game,bog)
	await owner._choose_outcome("bog_core_choice","bog_core_fate","returned")
	owner._check(game.quests.is_completed("main_teeth_in_rain"),"The current Wychwood encounter and actual memory choice complete Teeth")

func _drive_contact_strike(game: Node, enemy: Node3D, last_attack: int, interval_ms: int) -> int:
	var offset: Vector3 = enemy.global_position - game.player.global_position
	offset.y = 0.0
	if offset.length() > _melee_approach_radius(game, enemy):
		await _advance_toward_combat_target(game, enemy)
		return last_attack
	await _release_combat_movement()
	if Time.get_ticks_msec() - last_attack > interval_ms:
		await _frames(2)
		await _mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		await _mouse_button(MOUSE_BUTTON_LEFT, false)
		return Time.get_ticks_msec()
	return last_attack

func _enter_record_hall(game: Node) -> void:
	await owner._travel("record_hall")
	await _save_campaign_checkpoint(game)

func _enter_undercroft(game: Node) -> void:
	await owner._travel("undercroft")
	await _save_campaign_checkpoint(game)

func _fail(message: String) -> void: owner._fail(message)

func _fight_ashwing_real_input(game: Node) -> void:
	if not game.quests.is_objective_done("main_ash_at_the_mill", "mill_encounter") or bool(game.story_state.get_flag("ashwing_defeated", false)):
		_fail("Ashwing Continue did not restore the undefeated mill encounter")
		return
	var boss: Node3D = null
	var boss_count := 0
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "ashwing" and not candidate.dead:
			boss = candidate
			boss_count += 1
	if boss_count != 1:
		_fail("Ashwing Continue restored %d living bosses" % boss_count)
		return
	print("REAL_INPUT ashwing_reload=PASS boss=%s arrows=%d health=%.1f" % [boss.global_position, game.inventory.items.get("standard_arrow", 0), game.player.health_component.health])
	if not game.camera_rig._is_valid_combat_target(boss):
		await _turn_camera_north(game)
		await _move_until(game, KEY_S, "ashwing_south_frontage", func(p: Vector3) -> bool: return p.z > -1.4, 5000)
		await _move_until(game, KEY_D, "ashwing_clear_east_yard", func(p: Vector3) -> bool: return p.x > 1.3, 6500)
		if not failures.is_empty():
			return
	if game.camera_rig.get_locked_combat_target() != boss:
		if game.camera_rig.get_locked_combat_target() != null:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(10)
		await _key(KEY_T, true)
		await _frames(2)
		await _key(KEY_T, false)
		await _frames(10)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Ashwing")
		return
	await _before_ashwing_attack(game)
	if not failures.is_empty():
		return
	await _key(KEY_C, true)
	await _frames(100)
	await _key(KEY_C, false)
	await _frames(22)
	print("REAL_INPUT ashwing_oathfire_observation hits=%d boss_health=%.1f" % [int(game.get_meta("last_oathfire_hit_count", 0)), boss.health_component.health])
	await _key(KEY_2, true)
	await _frames(2)
	await _key(KEY_2, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "bow":
		_fail("Bow input did not equip Kael for Ashwing")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	await _mouse_button(MOUSE_BUTTON_RIGHT, true)
	await _frames(15)
	var last_potion := 0
	for _shot in range(arrows_before):
		if bool(boss.get("dead")) or bool(game.story_state.get_flag("ashwing_defeated", false)) or game.player.health_component.health <= 0.0:
			break
		if game.player.health_component.health < 70.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and Time.get_ticks_msec() - last_potion > 2000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = Time.get_ticks_msec()
		await _mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		await _mouse_button(MOUSE_BUTTON_LEFT, false)
		await _frames(26)
	await _mouse_button(MOUSE_BUTTON_RIGHT, false)
	print("REAL_INPUT ashwing_combat_observation arrows_used=%d boss_health=%.1f player_health=%.1f potions=%d player=%s boss=%s" % [arrows_before - int(game.inventory.items.get("standard_arrow", 0)), boss.health_component.health if is_instance_valid(boss) else 0.0, game.player.health_component.health, int(game.inventory.items.get("redroot_potion", 0)), game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF])
	if not bool(game.story_state.get_flag("ashwing_defeated", false)):
		_fail("Real-input Ashwing encounter did not resolve")
	else:
		print("REAL_INPUT ashwing_defeat=PASS")
		await _choose_mill_record(game)

func _fight_bell_eater_real_input(game: Node) -> void:
	if bool(game.story_state.get_flag("bell_eater_defeated", false)):
		_fail("Bell fight must begin with an actual undefeated encounter")
		return
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and candidate.enemy_id == "bell_eater" and not candidate.dead:
			if boss != null:
				_fail("Bell route contains duplicate living bosses")
				return
			boss = candidate
	if boss == null:
		_fail("Genuine shrine save did not restore the living Bell-Eater")
		return
	await _align_chapel_entrance(game)
	# A chasing boss can occupy the waypoint. Engage it from reachable range
	# rather than asking the real capsule to walk through that living body.
	await _move_until(game, KEY_A, "bell_chapel_doorway", func(p: Vector3) -> bool:
		var offset: Vector3 = boss.global_position - p
		offset.y = 0.0
		return p.x < 13.7 or offset.length() <= 1.7
	, 5000)
	if not failures.is_empty():
		return
	await _key(KEY_T, true)
	await _frames(2)
	await _key(KEY_T, false)
	await _frames(8)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Bell-Eater outside the chapel")
		return
	await _key(KEY_C, true)
	await _frames(100)
	await _key(KEY_C, false)
	await _frames(22)
	var deadline := Time.get_ticks_msec() + 90000
	var last_progress := Time.get_ticks_msec()
	var observed_health: float = boss.health_component.health
	var last_attack := 0
	var last_potion := 0
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("bell_eater_defeated", false)):
			await _mouse_button(MOUSE_BUTTON_RIGHT, false)
			await _release_combat_movement()
			for flag in ["cemetery_bell_silent", "boss_reward_granted_bell_eater", "boss_reward_bell_iron", "boss_reward_chapel_key"]:
				if not bool(game.story_state.get_flag(flag, false)):
					_fail("Actual Bell-Eater death omitted %s" % flag)
			if failures.is_empty():
				print("REAL_INPUT bell_eater_fight=PASS health=%.1f phase=%d rewards=true aftermath=true position=%s" % [game.player.health_component.health, boss.boss_phase if is_instance_valid(boss) else 3, game.player.global_position])
				await _clear_bell_summons_real_input(game)
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss):
			_fail("Bell-Eater fight ended without actual resolution")
			break
		var now := Time.get_ticks_msec()
		if boss.health_component.health < observed_health:
			observed_health = boss.health_component.health
			last_progress = now
		if now - last_progress > 25000:
			_fail("Bell combat stalled: player=%s boss=%s health=%.1f" % [game.player.global_position, boss.global_position, observed_health])
			break
		var separation: Vector3 = boss.global_position - game.player.global_position
		separation.y = 0.0
		var defending: bool = boss.pending_attack_time > 0.0 and separation.length() < 4.0
		await _mouse_button(MOUSE_BUTTON_RIGHT, defending)
		if defending:
			await _release_combat_movement()
		if not defending and game.player.health_component.health < 75.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = now
		elif not defending:
			last_attack = await _drive_contact_strike(game, boss, last_attack, 430)
		await _frames(3)
	await _mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _key(KEY_W, false)
	if failures.is_empty():
		_fail("Real-input Bell-Eater fight timed out")

func _fight_bog_wretch(game: Node, enemy: Node3D) -> void:
	await _move_until(game, KEY_D, "bog_arena_centerline", func(p: Vector3) -> bool: return p.x > -0.5, 6000)
	await _move_until(game, KEY_W, "bog_arena_approach", func(p: Vector3) -> bool: return p.z < -3.5, 8000)
	if not failures.is_empty():
		return
	var bombs_before := int(game.inventory.items.get("ash_bomb", 0))
	var health_before_bomb: float = enemy.health_component.health
	if bombs_before > 0:
		await _key(KEY_F, true)
		await _frames(2)
		await _key(KEY_F, false)
		await _frames(6)
		if int(game.inventory.items.get("ash_bomb", 0)) >= bombs_before or not bool(game.story_state.get_flag("bog_core_exposed", false)) or enemy.health_component.health >= health_before_bomb:
			_fail("Real Ash Bomb did not expose and damage the Bog Wretch; bombs=%d health=%.1f exposed=%s" % [game.inventory.items.get("ash_bomb", 0), enemy.health_component.health, game.story_state.get_flag("bog_core_exposed", false)])
			return
		print("REAL_INPUT bog_ash_weakness=PASS enemy_health=%.1f" % enemy.health_component.health)
	var deadline := Time.get_ticks_msec() + 90000
	var last_progress := Time.get_ticks_msec()
	var observed_health: float = enemy.health_component.health
	var last_attack := 0
	var last_potion := 0
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_teeth_in_rain", "fight_bog_wretch"):
			await _release_combat_movement()
			print("REAL_INPUT bog_wretch_fight=PASS health=%.1f position=%s" % [game.player.health_component.health, game.player.global_position])
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(enemy):
			_fail("Bog Wretch fight ended without the objective; player_health=%.1f enemy_health=%.1f player=%s enemy=%s" % [game.player.health_component.health, enemy.health_component.health if is_instance_valid(enemy) else -1.0, game.player.global_position, enemy.global_position if is_instance_valid(enemy) else Vector3.INF])
			return
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 25000:
			_fail("Bog Wretch combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(9)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 75.0 and game.player.attack_cooldown <= 0.01 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 6000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 430)
		await _frames(3)
	_fail("Real-input Bog Wretch fight timed out; enemy_health=%.1f player_health=%.1f" % [enemy.health_component.health, game.player.health_component.health])

func _fight_cemetery_ambush(game: Node) -> void:
	var ambusher: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and bool(candidate.get_meta("act_one_cemetery_ambush", false)) and not candidate.dead:
			ambusher = candidate
			break
	if ambusher == null:
		_fail("Two graves did not spawn the cemetery ambusher")
		return
	var spawn: Vector3 = ambusher.global_position
	if spawn.x < 10.0 or spawn.x > 18.0 or spawn.z < 7.0 or spawn.z > 11.2:
		_fail("Cemetery ambusher was relocated outside its authored arena: %s" % spawn)
		return
	print("REAL_INPUT cemetery_ambusher_spawn=PASS position=%s" % spawn)
	var deadline := Time.get_ticks_msec() + 45000
	var last_attack := 0
	var last_damage := Time.get_ticks_msec()
	var observed_health := INF
	while Time.get_ticks_msec() < deadline:
		if game.quests.is_objective_done("main_bell_beneath_greyfen", "cemetery_ambush"):
			await _release_combat_movement()
			print("REAL_INPUT cemetery_ambush=PASS player=%s health=%.1f" % [game.player.global_position, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died in the real-input cemetery ambush")
			return
		if not is_instance_valid(ambusher):
			_fail("Cemetery ambusher vanished before quest completion")
			return
		if ambusher.health_component.health < observed_health:
			observed_health = ambusher.health_component.health
			last_damage = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage > 20000:
			_fail("Cemetery combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, ambusher.global_position, ambusher.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != ambusher:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(8)
		var separation: Vector3 = ambusher.global_position - game.player.global_position
		separation.y = 0.0
		last_attack = await _drive_contact_strike(game, ambusher, last_attack, 430)
		await _frames(3)
	_fail("Cemetery combat timed out with enemy_health=%.1f" % ambusher.health_component.health)

func _fight_hart_ending(game: Node, covenant: String) -> void:
	var boss: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "white_hart_avatar" and not candidate.dead:
			if boss != null:
				_fail("Hart %s choice staged multiple living avatars" % covenant)
				return
			boss = candidate
	if boss == null:
		_fail("Hart %s choice did not stage the avatar" % covenant)
		return
	print("REAL_INPUT hart_%s_combat_started=PASS boss=%s health=%.1f" % [covenant, boss.global_position, boss.health_component.health])
	await _key(KEY_1, true)
	await _frames(2)
	await _key(KEY_1, false)
	await _key(KEY_T, true)
	await _frames(2)
	await _key(KEY_T, false)
	await _frames(8)
	var deadline := Time.get_ticks_msec() + 60000
	var last_attack := 0
	var last_potion := 0
	var observed_health: float = boss.health_component.health
	var last_progress := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("final_choice_completed", false)):
			print("REAL_INPUT hart_%s_combat_defeat=PASS boss_health=%.1f player_health=%.1f" % [covenant, boss.health_component.health if is_instance_valid(boss) else 0.0, game.player.health_component.health])
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(boss):
			_fail("Hart %s fight ended before the covenant resolved; player_health=%.1f" % [covenant, game.player.health_component.health])
			return
		if boss.health_component.health < observed_health:
			observed_health = boss.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 15000:
			_fail("Hart %s fight stalled; player=%s boss=%s health=%.1f" % [covenant, game.player.global_position, boss.global_position, boss.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != boss:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(5)
		var now := Time.get_ticks_msec()
		var distance: float = game.player.global_position.distance_to(boss.global_position)
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 5000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = now
		elif distance > 2.1:
			await _key(KEY_W, true)
			await _frames(7)
			await _key(KEY_W, false)
		elif float(boss.get("pending_attack_time")) > 0.0 and float(boss.get("pending_attack_time")) < game.player.get_parry_window_duration() * 0.75:
			await _key(KEY_Q, true)
			await _frames(2)
			await _key(KEY_Q, false)
		elif now - last_attack > 420:
			await _mouse_button(MOUSE_BUTTON_LEFT, true)
			await _frames(2)
			await _mouse_button(MOUSE_BUTTON_LEFT, false)
			last_attack = now
		await _frames(3)
	_fail("Hart %s fight exceeded its 60-second real-input deadline" % covenant)

func _fight_record_haunting(game: Node) -> void:
	if not bool(game.story_state.get_flag("vargan_ledger_choice_made", false)) or bool(game.story_state.get_flag("castle_haunting_cleared", false)):
		_fail("Record Hall Continue lost the unresolved haunting")
		return
	var enemy: Node3D = null
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.get("enemy_id")) == "wychwood_stalker" and not candidate.dead:
			if enemy != null:
				_fail("Record Hall Continue restored more than one haunting")
				return
			enemy = candidate
	if enemy == null:
		_fail("Record Hall Continue did not restore its haunting")
		return
	print("REAL_INPUT record_haunting_reload=PASS player=%s enemy=%s health=%.1f" % [game.player.global_position, enemy.global_position, game.player.health_component.health])
	await _key(KEY_1, true)
	await _frames(2)
	await _key(KEY_1, false)
	await _key(KEY_T, true)
	await _frames(2)
	await _key(KEY_T, false)
	await _frames(8)
	var deadline := Time.get_ticks_msec() + 50000
	var last_progress := Time.get_ticks_msec()
	var last_attack := 0
	var last_potion := 0
	var observed_health: float = enemy.health_component.health
	while Time.get_ticks_msec() < deadline:
		if bool(game.story_state.get_flag("castle_haunting_cleared", false)) and game.quests.is_objective_done("main_blood_under_stone", "survive_haunting"):
			if not await _await_playable_zone(game, "record_hall", "record_hall_after_haunting"):
				return
			print("REAL_INPUT record_haunting_defeat=PASS health=%.1f" % game.player.health_component.health)
			var slot := await _save_campaign_checkpoint(game)
			if not failures.is_empty():
				return
			var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
			if not bool(slot.get("ok", false)) or not bool(flags.get("castle_haunting_cleared", false)):
				_fail("Real pause-menu save lost the cleared Record Hall haunting")
			else:
				print("REAL_INPUT record_haunting_manual_save=PASS zone=record_hall")
			return
		if game.player.health_component.health <= 0.0 or not is_instance_valid(enemy):
			_fail("Haunting ended before quest completion; player_health=%.1f" % game.player.health_component.health)
			return
		if enemy.health_component.health < observed_health:
			observed_health = enemy.health_component.health
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 18000:
			_fail("Haunting combat stalled: player=%s enemy=%s enemy_health=%.1f" % [game.player.global_position, enemy.global_position, enemy.health_component.health])
			return
		if game.camera_rig.get_locked_combat_target() != enemy:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(6)
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 65.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 5000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			last_potion = now
		else:
			last_attack = await _drive_contact_strike(game, enemy, last_attack, 420)
		await _frames(3)
	_fail("Real-input Record Hall haunting timed out")

func _fight_rootbound_real_input(game: Node) -> void:
	await _verify_rootbound_reload(game)
	if not failures.is_empty():
		return
	var boss: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "rootbound_colossus":
			boss = enemy
			break
	await _key(KEY_T, true)
	await _frames(2)
	await _key(KEY_T, false)
	await _frames(8)
	if game.camera_rig.get_locked_combat_target() != boss:
		_fail("Real target-lock input did not acquire Rootbound")
		return
	await _key(KEY_2, true)
	await _frames(2)
	await _key(KEY_2, false)
	await _frames(5)
	if str(game.player.weapon_mode) != "bow":
		_fail("Real weapon-switch input did not equip bow")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	var potions_before := int(game.inventory.items.get("redroot_potion", 0))
	var potion_requests := 0
	var initial_health: float = boss.health_component.health
	await _mouse_button(MOUSE_BUTTON_RIGHT, true)
	await _frames(15)
	var last_potion := 0
	for shot in range(arrows_before):
		if bool(boss.get("dead")) or bool(game.story_state.get_flag("rootbound_colossus_defeated", false)):
			break
		if game.player.health_component.health <= 0.0:
			break
		var now := Time.get_ticks_msec()
		if game.player.health_component.health < 70.0 and int(game.inventory.items.get("redroot_potion", 0)) > 0 and now - last_potion > 2000:
			await _key(KEY_R, true)
			await _frames(2)
			await _key(KEY_R, false)
			potion_requests += 1
			last_potion = now
		var draw_deadline := Time.get_ticks_msec() + 4000
		while game.player.bow_draw_time < game.player.BOW_MAX_DRAW and Time.get_ticks_msec() < draw_deadline and not bool(boss.get("dead")) and game.player.health_component.health > 0.0:
			await _frames(1)
		if bool(boss.get("dead")) or game.player.health_component.health <= 0.0:
			break
		if game.player.bow_draw_time < game.player.BOW_MAX_DRAW:
			_fail("Rootbound bow did not reach full draw through held aim input")
			break
		await _mouse_button(MOUSE_BUTTON_LEFT, true)
		await _frames(2)
		await _mouse_button(MOUSE_BUTTON_LEFT, false)
		await _frames(26)
	await _mouse_button(MOUSE_BUTTON_RIGHT, false)
	print("REAL_INPUT rootbound_combat_observation arrows_used=%d boss_health=%.1f/%.1f player_health=%.1f potions=%d player=%s boss=%s" % [arrows_before - int(game.inventory.items.get("standard_arrow", 0)), boss.health_component.health if is_instance_valid(boss) else 0.0, initial_health, game.player.health_component.health, int(game.inventory.items.get("redroot_potion", 0)), game.player.global_position, boss.global_position if is_instance_valid(boss) else Vector3.INF])
	if potion_requests > 0 and int(game.inventory.items.get("redroot_potion", 0)) != potions_before - potion_requests:
		_fail("Bow-equipped potion input did not consume a carried Redroot Potion")
	print("REAL_INPUT rootbound_potion_input requests=%d consumed=%d not_exercised=%s" % [potion_requests, potions_before - int(game.inventory.items.get("redroot_potion", 0)), potion_requests == 0])
	if not bool(game.story_state.get_flag("rootbound_colossus_defeated", false)):
		_fail("Real-input Rootbound encounter did not resolve")
	else:
		print("REAL_INPUT rootbound_defeat=PASS")

func _fight_senn_guard(game: Node) -> void:
	owner._check(game.quests.is_active("main_soldier_without_banner"),"Senn confrontation belongs to the active Soldier chapter")
	await owner._interact("saga_senn_challenge")
	var enemy: Node3D
	for candidate in game.active_enemies:
		if is_instance_valid(candidate) and str(candidate.enemy_id)=="captain_senn" and not candidate.dead: enemy=candidate; break
	if enemy==null:
		_fail("Actual Senn challenge did not stage the living captain")
		return
	await owner._tap(KEY_1)
	var deadline := Time.get_ticks_msec()+90000
	var last_attack := 0
	var last_potion := 0
	while Time.get_ticks_msec()<deadline and failures.is_empty():
		if game.quests.is_objective_done("main_soldier_without_banner","senn_confrontation"):
			await owner._release()
			await owner._choose_outcome("captain_senn","senn_fate","testimony")
			owner._check(game.quests.is_completed("main_soldier_without_banner") and str(game.story_state.get_flag("senn_fate",""))=="testimony","Senn yields alive and receives his actual recorded outcome")
			await _save_campaign_checkpoint(game)
			return
		if game.player.health_component.health<=0 or not is_instance_valid(enemy) or enemy.dead:
			_fail("Senn encounter ended before the captain yielded alive")
			return
		if game.camera_rig.get_locked_combat_target()!=enemy:
			if game.camera_rig.get_locked_combat_target()!=null: await owner._tap(KEY_T)
			await owner._tap(KEY_T)
			await owner._frames(6)
		var now := Time.get_ticks_msec()
		if game.player.health_component.health<65 and int(game.inventory.items.get("redroot_potion",0))>0 and now-last_potion>6000:
			await owner._tap(KEY_R); last_potion=now
		elif float(enemy.pending_attack_time)>0 and float(enemy.pending_attack_time)<game.player.get_parry_window_duration()*0.75:
			await owner._release()
			await owner._tap(KEY_Q)
		else: last_attack=await _drive_contact_strike(game,enemy,last_attack,430)
		await owner._frames(3)
	_fail("Actual Senn challenge exceeded its ninety-second deadline")

func _fight_wychwood_pack(game: Node) -> void:
	if not failures.is_empty():
		return
	var audio_sync: Dictionary = {}
	if OS.get_cmdline_user_args().has("--audio-sync-combat"):
		audio_sync = _observe_enemy_audio_sync(game, game.active_enemies)
	await _move_until(game, KEY_W, "wychwood_clearing", func(p: Vector3) -> bool: return p.z < -4.5, 5000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 150000
	var last_attack := 0
	var last_potion := 0
	var last_progress := -1
	var last_damage_progress := Time.get_ticks_msec()
	var observed_enemy_health := INF
	var captured_ghoulkin_states: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		if OS.get_cmdline_user_args().has("--ghoulkin-motion-proof"):
			for actor in game.active_enemies:
				if not is_instance_valid(actor) or actor.enemy_id != "ghoulkin" or actor.animation_driver == null:
					continue
				var state: String = actor.animation_driver.current_state
				if state not in ["walk", "run", "attack", "hit", "death"] or captured_ghoulkin_states.has(state):
					continue
				await RenderingServer.frame_post_draw
				var path := "D:/Temp/AshenOath/ghoulkin_authored_20260930/real_input_%s.png" % state
				if root.get_texture().get_image().save_png(path) != OK:
					_fail("Actual Ghoulkin %s frame could not be captured" % state)
				captured_ghoulkin_states[state] = true
				print("REAL_INPUT ghoulkin_motion=%s actor=%s grounded=%s frame=%s" % [state, actor.global_position, actor.is_on_floor(), path])
		if game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				await _key(keycode, false)
			print("REAL_INPUT five_enemy_fight=PASS kills=%d health=%.1f" % [game.wychwood_pack_kills, game.player.health_component.health])
			if not audio_sync.is_empty():
				if audio_sync.death != 5 or audio_sync.hit == 0 or audio_sync.windup == 0 or audio_sync.attack == 0:
					_fail("Five-enemy audio input coverage is incomplete: " + JSON.stringify(audio_sync))
				print("REAL_INPUT combat_audio_sync=%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(audio_sync)])
			return
		if game.player.health_component.health <= 0.0:
			_fail("Kael died in the real-input five-enemy fight after %d kills" % game.wychwood_pack_kills)
			return
		if game.wychwood_pack_kills != last_progress:
			last_progress = game.wychwood_pack_kills
			observed_enemy_health = INF
			last_damage_progress = Time.get_ticks_msec()
			print("REAL_INPUT combat_progress kills=%d health=%.1f position=%s" % [last_progress, game.player.health_component.health, game.player.global_position])
		var enemy: Node3D = game.camera_rig.get_locked_combat_target()
		if enemy == null:
			await _key(KEY_T, true)
			await _frames(2)
			await _key(KEY_T, false)
			await _frames(10)
			enemy = game.camera_rig.get_locked_combat_target()
		if enemy == null:
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				await _key(keycode, false)
			await _frames(5)
			if Time.get_ticks_msec() - last_damage_progress > 25000:
				_fail("No visible active target acquired during the five-enemy fight")
				return
			continue
		if not game.active_enemies.has(enemy) or enemy.dead or not enemy.is_encounter_active():
			_fail("Real lock-on selected an invalid encounter actor")
			return
		var total_health := 0.0
		for candidate in game.active_enemies:
			if is_instance_valid(candidate) and not candidate.dead:
				total_health += float(candidate.health_component.health)
		if total_health < observed_enemy_health:
			observed_enemy_health = total_health
			last_damage_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_damage_progress > 25000:
			var stuck_offset: Vector3 = enemy.global_position - game.player.global_position
			stuck_offset.y = 0.0
			var stuck_lock: Node3D = game.camera_rig.get_locked_combat_target()
			_fail("Combat stalled after %d kills: player=%s enemy=%s enemy_health=%.1f distance=%.2f camera_yaw=%.2f locked=%s velocity=%s" % [game.wychwood_pack_kills, game.player.global_position, enemy.global_position, enemy.health_component.health, stuck_offset.length(), game.camera_rig.yaw, stuck_lock.name if stuck_lock != null else "none", game.player.velocity])
			return
		var separation: Vector3 = enemy.global_position - game.player.global_position
		separation.y = 0.0
		# The animation's measured blade sweep, not its broad candidate radius,
		# determines striking distance. Keep approaching until contact is reachable.
		if separation.length() > 1.1:
			await _advance_toward_combat_target(game, enemy)
		else:
			for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
				await _key(keycode, false)
			var now := Time.get_ticks_msec()
			if now - last_attack >= 430:
				# Neutral movement lets the normal attack edge face the live lock,
				# rather than overriding it with the camera's lagging forward yaw.
				await _frames(2)
				await _mouse_button(MOUSE_BUTTON_LEFT, true)
				await _frames(2)
				await _mouse_button(MOUSE_BUTTON_LEFT, false)
				last_attack = now
			if game.player.health_component.health < 65.0 and now - last_potion > 6000:
				await _key(KEY_R, true)
				await _frames(2)
				await _key(KEY_R, false)
				last_potion = now
		await _frames(3)
	_fail("Real-input Wychwood combat timed out; kills=%d health=%.1f position=%s" % [game.wychwood_pack_kills, game.player.health_component.health, game.player.global_position])

func _finish() -> void: owner._fail("Legacy helper requested early fixture completion")

func _focus_vendor_button(label_prefix: String, _backwards: bool = false) -> bool:
	# Select an actual visible row for the subsequent screen tap; never move GUI focus.
	return owner._touch_vendor_target(label_prefix)

func _frames(count: int) -> void: await owner._frames(count)

func _hear_assembly_witnesses(game: Node) -> void:
	for row: Array in [["witness_3","anwen"],["witness_-3","rook"],["witness_-7","mira"]]:
		var actor := game.zone_root.find_child(str(row[0]),true,false) as Node3D
		var willing := str(game.story_state.get_flag("witness_consent_"+str(row[1]),""))=="voluntary"
		if not willing:
			owner._check(actor==null or not actor.is_visible_in_tree(),"Absent or refusing witness is never staged as willing: "+str(row[1]))
			continue
		owner._check(actor!=null and actor.is_visible_in_tree() and not actor.find_children("*","Skeleton3D",true,false).is_empty(),"Willing assembly witness retains native body: "+str(row[1]))
		await owner._interact(str(row[0]))
		await owner._close_dialogue()
	await owner._interact("witness_7")
	await owner._close_dialogue()

func _inspect_ash_millstones(game: Node) -> void:
	if not game.quests.is_active("main_ash_at_the_mill") or not game.quests.is_objective_done("main_ash_at_the_mill", "reach_mill"):
		_fail("Mill continuation lost Ash at the Mill arrival beat")
		return
	await _move_until(game, KEY_D, "ash_mill_front_lane", func(p: Vector3) -> bool: return p.x > -5.2, 5000)
	await _move_until(game, KEY_W, "ash_mill_front_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "millstones", 10000)
	await _use_focused_interaction(game, "millstones", "ash_millstones")
	if failures.is_empty() and not game.quests.is_objective_done("main_ash_at_the_mill", "inspect_millstones"):
		_fail("Real millstones E interaction did not complete inspect_millstones")
	elif failures.is_empty():
		print("REAL_INPUT ash_millstones_clue=PASS position=%s" % game.player.global_position)
		await _clear_ash_mill_ghoulkin(game)

func _key(key: Key, pressed: bool) -> void: await owner._touch_key(key,pressed)

func _leave_chapel_for_south_road(game: Node) -> void:
	await _align_chapel_entrance(game)
	if not failures.is_empty():
		return
	# Combat may end on either side of the gate cap. The x13.2 aisle clears
	# the gate at x10.6, headstones at x12.2/14 and bell posts at x15.15/16.35.
	await _align_route_axis(game, 0, 13.2, KEY_A, KEY_D, "chapel_west_doorway_exit")
	if not failures.is_empty():
		return
	# Cross the authored west gate before turning south. The inner south
	# lane contains graves/rubble; its wall is not a cemetery exit.
	await _move_until(game, KEY_A, "cemetery_west_gate_exit", func(p: Vector3) -> bool: return p.x < 9.4, 5000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "cemetery_exit_lane", func(p: Vector3) -> bool: return p.z > 10.4, 5000)

func _meet_anwen_and_inspect_graves(game: Node) -> void:
	await _move_until(game, KEY_A, "cemetery_bridge_centerline", func(p: Vector3) -> bool: return p.x < 0.45, 4000)
	await _move_until(game, KEY_S, "cemetery_south_bank", func(p: Vector3) -> bool: return p.z > 9.2, 7000)
	await _move_until(game, KEY_D, "cemetery_gate_lane", func(p: Vector3) -> bool: return p.x > 9.0, 7000)
	await _move_until(game, KEY_W, "cemetery_anwen_approach", func(p: Vector3) -> bool: return p.z < 8.8, 4000)
	if not failures.is_empty():
		return
	await _use_focused_interaction(game, "sister_anwen", "cemetery_anwen")
	if not failures.is_empty():
		return
	if not game.quests.is_objective_done("main_bell_beneath_greyfen", "meet_anwen_gate"):
		_fail("Real cemetery Anwen conversation did not complete meet_anwen_gate")
		return
	await _move_until(game, KEY_W, "harl_pier_clearance", func(p: Vector3) -> bool: return p.z < 8.5, 4000)
	await _move_until(game, KEY_D, "harl_grave_lane", func(p: Vector3) -> bool: return p.x > 11.0, 4000)
	await _use_focused_interaction(game, "grave_harl", "harl_grave")
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "soldier_grave_south", func(p: Vector3) -> bool: return p.z > 8.8, 4000)
	await _move_until(game, KEY_D, "soldier_grave_lane", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "grave_soldier", 5000)
	await _use_focused_interaction(game, "grave_soldier", "soldier_grave")
	if failures.is_empty() and game.quests.is_objective_done("main_bell_beneath_greyfen", "grave_truth"):
		print("REAL_INPUT cemetery_grave_truth=PASS position=%s" % game.player.global_position)
		await _fight_cemetery_ambush(game)
		if failures.is_empty():
			await _open_crow_chapel(game)
	elif failures.is_empty():
		_fail("Two player-inspected graves did not complete grave_truth")

func _melee_approach_radius(game: Node, enemy: Node3D) -> float:
	var radii := 0.0
	for actor in [game.player, enemy]:
		for child in actor.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				radii += child.shape.radius
				break
	# Respect measured sword reach without interpenetrating large capsules.
	return maxf(1.1, radii + 0.06)

func _mouse_button(button: MouseButton, pressed: bool) -> void: await owner._touch_mouse(button,pressed)

func _move_until(game: Node, keycode: Key, label: String, arrived: Callable, timeout_ms: int, sprinting := false) -> void:
	if not failures.is_empty():
		return
	await _key(keycode, true)
	if sprinting:
		await _key(KEY_SHIFT, true)
	var deadline := Time.get_ticks_msec() + timeout_ms
	var reached_in_time := false
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if Time.get_ticks_msec() >= deadline:
			break
		if arrived.call(game.player.global_position):
			reached_in_time = true
			break
		if stabilize_route_bearing and absf(angle_difference(float(game.camera_rig.yaw),route_camera_yaw))>0.04:
			var forward := Vector3(-sin(route_camera_yaw),0,-cos(route_camera_yaw))
			await owner._face(game.player.global_position+forward*5.0)
	await _key(keycode, false)
	if sprinting:
		await _key(KEY_SHIFT, false)
	var failure_state := "paused=%s can_control=%s transition_locked=%s zone=%s zone_pending=%s input=%s velocity=%s dialogue=%s focus=%s camera_yaw=%.3f" % [
		paused, game.player.can_control, game.player.transition_locked, game.current_zone_id,
		game.zone_transition_pending, game.input_router.movement_vector(), game.player.velocity,
		game.hud.dialogue_layer.visible,
		game.active_interactable.interaction_id if game.active_interactable != null else "none",
		game.camera_rig.yaw,
	]
	var collision_owners: Array[String] = []
	for collision_index in game.player.get_slide_collision_count():
		var contact: KinematicCollision3D = game.player.get_slide_collision(collision_index)
		var collider: Object = contact.get_collider()
		var shape_owner := "none"
		if collider is CollisionObject3D:
			var body := collider as CollisionObject3D
			var owner_id := body.shape_find_owner(contact.get_collider_shape_index())
			var owner_node: Object = body.shape_owner_get_owner(owner_id)
			if owner_node is CollisionShape3D:
				var shape_node := owner_node as CollisionShape3D
				shape_owner = "%s center=%s size=%s" % [shape_node.name, shape_node.global_position, (shape_node.shape as BoxShape3D).size if shape_node.shape is BoxShape3D else "non-box"]
		collision_owners.append("%s shape=%s point=%s normal=%s" % [str(collider.get_path()) if collider is Node else str(collider), shape_owner, contact.get_position(), contact.get_normal()])
	var ray_origin: Vector3 = game.player.global_position + Vector3.UP * 0.85
	var ray_direction: Vector3 = Vector3.RIGHT if keycode == KEY_D else (-Vector3.RIGHT if keycode == KEY_A else (Vector3.BACK if keycode == KEY_S else Vector3.FORWARD))
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 2.0)
	query.exclude = [game.player.get_rid()]
	query.collision_mask = game.player.collision_mask
	var forward_hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
	failure_state += " slides=%s forward_hit=%s" % [collision_owners, {"collider": str((forward_hit.get("collider") as Node).get_path()) if forward_hit.get("collider") is Node else "none", "point": forward_hit.get("position", Vector3.INF), "normal": forward_hit.get("normal", Vector3.ZERO)}]
	await _frames(3)
	if not reached_in_time:
		_fail("Movement did not reach %s; position=%s %s" % [label, game.player.global_position, failure_state])
	else:
		print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _observe_enemy_audio_sync(game: Node, enemies: Array) -> Dictionary:
	var state := {"windup": 0, "hit": 0, "attack": 0, "parry": 0, "death": 0}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		enemy.windup_started.connect(func(actor: Node) -> void:
			_check_enemy_audio_sync(game, actor, "windup", state))
		enemy.damaged.connect(func(actor: Node, _health: float, _maximum: float) -> void:
			_check_enemy_audio_sync(game, actor, "hit", state))
		enemy.died.connect(func(actor: Node) -> void:
			_check_enemy_audio_sync(game, actor, "death", state))
		enemy.attack_resolved.connect(func(actor: Node, parried: bool, _contact: Vector3) -> void:
			_check_enemy_audio_sync(game, actor, "parry" if parried else "attack", state))
	return state

func _open_crow_chapel(game: Node) -> void:
	owner.region=str(game.current_zone_id)
	if not game.quests.is_objective_done("main_bell_beneath_greyfen","open_chapel"):
		await owner._interact("chapel_door")
		await owner._close_dialogue()
	if not bool(game.story_state.get_flag("bell_eater_defeated",false)):
		await _fight_bell_eater_real_input(game)
	await owner._choose_outcome("crow_shrine_choice","crow_shrine_state","cleansed")
	owner._check(game.quests.is_completed("main_bell_beneath_greyfen"),"Bell chapter earned after its actual encounter")

func _prepare_for_ash_mill(game: Node) -> void:
	if not game.quests.is_active("main_ash_at_the_mill"):
		_fail("Ash at the Mill was not active on Continue")
		return
	await _move_until(game, KEY_A, "ash_shop_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 5000)
	await _move_until(game, KEY_W, "ash_shop_north_road", func(p: Vector3) -> bool: return p.z < -4.3, 5000)
	await _move_until(game, KEY_D, "ash_shop_front_lane", func(p: Vector3) -> bool: return p.x > 10.0, 7000)
	await _move_until(game, KEY_S, "ash_shop_front_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "tor_forge", 5000)
	if not failures.is_empty():
		return
	await _key(KEY_E, true)
	await _frames(3)
	await _key(KEY_E, false)
	await _frames(8)
	if not game.hud.inventory_layer.visible or not paused:
		_fail("Focused Tor forge E input did not open its vendor menu")
		return
	var arrows_before := int(game.inventory.items.get("standard_arrow", 0))
	var coins_before := int(game.inventory.coin)
	if arrows_before < 0 or arrows_before > 24 or coins_before < 0:
		_fail("Actual carried ammunition/coins violate their inventory bounds")
		return
	if arrows_before < 5:
		if not await _focus_vendor_button("Claim Tor's free emergency arrows"):
			return
		await _key(KEY_ENTER, true)
		await _frames(3)
		await _key(KEY_ENTER, false)
		await _frames(5)
	var refilled_arrows := maxi(5, arrows_before)
	if int(game.inventory.items.get("standard_arrow", 0)) != refilled_arrows or int(game.inventory.coin) != coins_before:
		_fail("Tor's emergency policy changed paid coins or actual carried ammunition")
		return
	print("REAL_INPUT tor_supply_before_purchase=PASS arrows=%d coin=%d emergency_used=%s" % [refilled_arrows, coins_before, arrows_before < 5])
	var purchases := maxi(0, 20 - refilled_arrows)
	if coins_before < purchases:
		_fail("Actual campaign economy cannot fund twenty standard arrows")
		return
	if purchases > 0:
		if not await _focus_vendor_button("Buy Standard Arrow", true):
			return
		for _purchase in range(purchases):
			await _key(KEY_ENTER, true)
			await _frames(2)
			await _key(KEY_ENTER, false)
			await _frames(2)
	expected_ash_supply_arrows = refilled_arrows + purchases
	if int(game.inventory.items.get("standard_arrow", 0)) != expected_ash_supply_arrows or int(game.inventory.coin) != coins_before - purchases:
		_fail("Tor purchase violated exact quantity or one-coin-per-arrow payment")
		return
	print("REAL_INPUT tor_paid_arrows=PASS arrows=%d coin=%d purchases=%d" % [expected_ash_supply_arrows, coins_before - purchases, purchases])
	if not await _focus_vendor_button("Close"):
		return
	await _key(KEY_ENTER, true)
	await _frames(3)
	await _key(KEY_ENTER, false)
	await _frames(8)
	if paused or game.hud.inventory_layer.visible or not game.player.can_control:
		_fail("Closing Tor's shop did not restore gameplay control")
		return
	await _move_until(game, KEY_W, "ash_depart_forge_front", func(p: Vector3) -> bool: return p.z < -4.3, 5000)
	await _move_until(game, KEY_A, "ash_depart_center_road", func(p: Vector3) -> bool: return p.x < 0.4, 7000)
	await _move_until(game, KEY_W, "ash_depart_west_road", func(p: Vector3) -> bool: return p.z < -9.7, 7000)
	await _move_until(game, KEY_A, "ash_depart_deep_wood", func(_p: Vector3) -> bool: return game.current_zone_id == "deep_wood", 12000)
	if not await _await_playable_zone(game, "deep_wood", "ash_deep_wood_arrival"):
		return
	await create_timer(0.5).timeout
	var slot: Dictionary = game.save_manager._read_slot(game.save_manager.AUTOSAVE_PATH)
	var saved: Dictionary = slot.get("data", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "deep_wood" or int((saved.get("inventory", {}) as Dictionary).get("items", {}).get("standard_arrow", 0)) != expected_ash_supply_arrows:
		_fail("Deep Wood autosave lost the vendor arrow purchase")
	else:
		print("REAL_INPUT ash_supply_autosave=PASS zone=deep_wood arrows=%d" % expected_ash_supply_arrows)

func _release_combat_movement() -> void:
	for keycode in [KEY_W, KEY_S, KEY_D, KEY_A]:
		await _key(keycode, false)

func _report_to_anwen(game: Node) -> void:
	if not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_fail("Returned before completing the five-enemy objective")
		return
	await _move_until(game, KEY_S, "anwen_report_north_approach", func(p: Vector3) -> bool: return p.z > -3.4, 7000)
	await _move_until(game, KEY_D, "anwen_report_offset", func(p: Vector3) -> bool: return p.x > 1.55, 4000)
	if not failures.is_empty():
		return
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen":
		_fail("Anwen report did not receive real focus; position=%s" % game.player.global_position)
		return
	await _key(KEY_E, true)
	await _frames(3)
	await _key(KEY_E, false)
	await _frames(5)
	if not game.hud.dialogue_layer.visible:
		_fail("Real E input did not open Anwen's return report")
		return
	for _page in range(24):
		if not game.hud.dialogue_layer.visible:
			break
		await _key(KEY_ENTER, true)
		await _frames(3)
		await _key(KEY_ENTER, false)
		await _frames(5)
	if not game.quests.is_completed("main_road_of_crows") or not game.quests.is_active("main_bell_beneath_greyfen"):
		_fail("Real Anwen report did not complete Road of Crows and start Bell Beneath Greyfen")
	else:
		var relocated_anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
		print("REAL_INPUT anwen_report=PASS road_complete=true bell_active=true anwen_position=%s pending_relocation=%s dialogue_visible=%s" % [relocated_anwen.global_position if relocated_anwen != null else Vector3.INF, game.pending_anwen_relocation, game.hud.dialogue_layer.visible])

func _resolve_halvern_witness(game: Node) -> void:
	await owner._choose_outcome("halvern","halvern_fate","witness")
	var next := "main_house_many_names" if owner.expanded else "main_crowns_without_mercy"
	owner._check(game.quests.is_completed("main_last_witness") and game.quests.is_active(next),"Last Witness unlocks the correct revision's next chapter")
	owner._check(str(game.story_state.get_flag("halvern_fate",""))=="witness","Halvern retains his authored voluntary outcome")
	await _save_campaign_checkpoint(game)

func _resolve_record_ledger(game: Node) -> void:
	var selected_flag := "vargan_ledger_hidden" if OS.get_cmdline_user_args().has("--ledger-hidden") else ("vargan_ledger_left_copied" if OS.get_cmdline_user_args().has("--ledger-copied") else "vargan_ledger_taken_openly")
	var choice := str({"vargan_ledger_hidden": "Hide the fragment", "vargan_ledger_left_copied": "Leave it and copy the seal", "vargan_ledger_taken_openly": "Take the fragment openly"}[selected_flag])
	if not game.quests.is_objective_done("main_blood_under_stone", "locate_record_hall") or bool(game.story_state.get_flag("vargan_ledger_choice_made", false)):
		_fail("Record Hall Continue did not restore the unresolved ledger beat")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_W, "record_ledger_approach", func(_p: Vector3) -> bool: return game.active_interactable != null and game.active_interactable.interaction_id == "vargan_ledger_choice", 12000)
	await _choose_focused_dialogue_action(game, "vargan_ledger_choice", choice, "record_ledger_choice")
	if not failures.is_empty():
		return
	if not bool(game.story_state.get_flag("vargan_ledger_choice_made", false)) or not game.quests.is_objective_done("main_blood_under_stone", "ledger_choice") or not game.quests.is_objective_done("main_blood_under_stone", "recover_ledger"):
		_fail("Real ledger E/Enter did not resolve the ledger decision")
		return
	for flag in ["vargan_ledger_hidden", "vargan_ledger_left_copied", "vargan_ledger_taken_openly"]:
		if bool(game.story_state.get_flag(flag, false)) != (flag == selected_flag):
			_fail("Ledger decision did not retain an exclusive %s outcome" % selected_flag)
			return
	if not await _await_playable_zone(game, "record_hall", "record_hall_after_ledger"):
		return
	var haunting_count := 0
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get("enemy_id")) == "wychwood_stalker" and not enemy.dead:
			haunting_count += 1
	if haunting_count != 1:
		_fail("Ledger decision staged %d living Record Hall hauntings" % haunting_count)
		return
	print("REAL_INPUT record_ledger_haunting_staged=PASS choice=%s" % selected_flag)
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var flags: Dictionary = slot.get("data", {}).get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or not bool(flags.get("vargan_ledger_choice_made", false)) or not bool(flags.get(selected_flag, false)) or str(slot.get("data", {}).get("zone", "")) != "record_hall":
		_fail("Real pause-menu save lost the Record Hall ledger or encounter state")
	else:
		print("REAL_INPUT record_ledger_manual_save=PASS zone=record_hall")

func _return_from_rootbound(game: Node) -> void:
	await owner._travel("greyfen")
	await owner._choose_outcome("names_decision","names_policy","published")
	owner._check(game.quests.is_completed("main_names_they_burned"),"All recovered register evidence leads to the actual Names choice")

func _return_register_to_deep_wood(game: Node) -> void:
	await owner._travel("deep_wood")
	await _save_campaign_checkpoint(game)

func _return_wychwood_to_greyfen(game: Node) -> void:
	if not game.quests.is_objective_done("main_road_of_crows", "fight_ghoulkin"):
		_fail("Wychwood return requires the actual completed fight")
		return
	await _turn_camera_north(game)
	if not failures.is_empty():
		return
	if game.player.global_position.x > 0.35:
		await _move_until(game, KEY_A, "wychwood_return_centerline", func(p: Vector3) -> bool: return p.x < 0.35, 4000)
	elif game.player.global_position.x < -0.35:
		await _move_until(game, KEY_D, "wychwood_return_centerline", func(p: Vector3) -> bool: return p.x > -0.35, 4000)
	if not failures.is_empty():
		return
	await _move_until(game, KEY_S, "wychwood_to_greyfen_boundary", func(_p: Vector3) -> bool: return game.current_zone_id == "greyfen", 12000)
	if not await _await_playable_zone(game, "greyfen", "wychwood_to_greyfen"):
		return
	# Walking has its own bounded deadline. Loading owns the existing strict
	# transition gate, measured from the runtime request, not this later await.
	var elapsed_ms := float(game.last_loading_metrics.get("to_playable_ms", INF))
	var reused := bool(game.zone_runtime_coordinator.last_activation.get("reused", false))
	var budget_ms := 350.0 if reused else 900.0
	if not is_finite(elapsed_ms) or elapsed_ms > budget_ms:
		_fail("Greyfen return transition exceeded %s budget: %.1f ms > %.1f ms" % ["warm" if reused else "cold", elapsed_ms, budget_ms])

func _run_opening(game: Node) -> void:
	var anwen_only := false
	var wychwood_only := false
	print("REAL_INPUT menu_to_greyfen=PASS position=%s" % game.player.global_position)
	await _move_until(game, KEY_W, "bridge_south_lip", func(p: Vector3) -> bool: return p.z < 6.0, 6000)
	await _move_until(game, KEY_W, "bridge_north_bank", func(p: Vector3) -> bool: return p.z < 1.5, 6000)
	await _move_until(game, KEY_W, "anwen_lane", func(p: Vector3) -> bool: return p.z < -3.4, 6000)
	await _move_until(game, KEY_D, "anwen_offset", func(p: Vector3) -> bool: return p.x > 1.55, 4000)
	var focus_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < focus_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen"):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != "sister_anwen":
		_fail("Anwen was not focusable after physical route; position=%s focus=%s" % [game.player.global_position, game.active_interactable])
	else:
		await _key(KEY_E, true)
		await _frames(3)
		await _key(KEY_E, false)
		await _frames(5)
		if not game.hud.dialogue_layer.visible:
			_fail("Real E input did not open Anwen's dialogue")
		else:
			print("REAL_INPUT anwen_dialogue=PASS position=%s" % game.player.global_position)
			if absf(game.player.global_position.y) > 0.08:
				_fail("Kael is suspended above Greyfen during the paused Anwen conversation")
			if anwen_only:
				await RenderingServer.frame_post_draw
				var dialogue_image := root.get_texture().get_image()
				if dialogue_image == null or dialogue_image.get_size() != Vector2i(1280, 720) or dialogue_image.save_png("user://world001_anwen_grounded_dialogue.png") != OK:
					_fail("Grounded real-input dialogue capture failed")
			for _page in range(16):
				if not game.hud.dialogue_layer.visible:
					break
				await _key(KEY_ENTER, true)
				await _frames(3)
				await _key(KEY_ENTER, false)
				await _frames(5)
			if game.hud.dialogue_layer.visible or paused:
				_fail("Anwen conversation did not release gameplay after focused input")
			else:
				print("REAL_INPUT anwen_conversation_closed=PASS")
				if not game.quests.is_objective_done("main_road_of_crows", "speak_anwen"):
					_fail("Anwen conversation did not advance the Road of Crows objective")
				if anwen_only:
					var anwen := game.zone_root.find_child("sister_anwen", true, false) as Node3D
					if anwen == null or game.player.global_position.distance_to(anwen.global_position) > 3.6:
						_fail("Dialogue staging displaced Kael away from Anwen: %s" % game.player.global_position)
					await _shutdown_game(game)
					_finish()
					return
				await _move_until(game, KEY_A, "north_road_center", func(p: Vector3) -> bool: return p.x < 0.45, 4000)
				if failures.is_empty():
					await _key(KEY_W, true)
					var travel_deadline := Time.get_ticks_msec() + 12000
					while Time.get_ticks_msec() < travel_deadline and game.current_zone_id != "wychwood":
						await physics_frame
					await _key(KEY_W, false)
					await _frames(5)
					if game.current_zone_id != "wychwood" or game.zone_transition_pending or game.player.transition_locked:
						_fail("Physical north-road travel did not reach playable Wychwood; zone=%s position=%s" % [game.current_zone_id, game.player.global_position])
					else:
						print("REAL_INPUT greyfen_to_wychwood=PASS position=%s" % game.player.global_position)
						await _move_until(game, KEY_W, "wychwood_first_layby", func(p: Vector3) -> bool: return p.z < 10.8, 4000)
						await _move_until(game, KEY_A, "bram_ledger_offset", func(p: Vector3) -> bool: return p.x < -0.7, 3000)
						if failures.is_empty():
							var clue_deadline := Time.get_ticks_msec() + 3000
							while Time.get_ticks_msec() < clue_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != "corpse"):
								await process_frame
							if game.active_interactable == null or game.active_interactable.interaction_id != "corpse":
								_fail("Bram's ledger did not receive normal focus at its layby")
							else:
								await _key(KEY_E, true)
								await _frames(3)
								await _key(KEY_E, false)
								await _frames(7)
								if not game.quests.is_objective_done("main_road_of_crows", "bram"):
									_fail("Real E input did not record Bram's ledger evidence")
								else:
									print("REAL_INPUT bram_ledger=PASS position=%s" % game.player.global_position)
						await _use_south_bank_clue(game, "black_feathers", "sella", KEY_D, 0.75, 9.0)
						await _use_south_bank_clue(game, "claw_marks", "vargan_wire", KEY_A, -0.7, 7.3)
						if failures.is_empty() and not game.quests.is_objective_done("main_road_of_crows", "evidence_ready"):
							_fail("Three player-collected clues did not advance the evidence objective")
						await _move_until(game, KEY_D, "wychwood_bridge_centerline", func(p: Vector3) -> bool: return p.x > -0.25, 3000)
						await _move_until(game, KEY_W, "wychwood_north_bank", func(p: Vector3) -> bool: return p.z < -2.8, 7000)
						if failures.is_empty() and (game.current_zone_id != "wychwood" or game.player.health_component.health <= 0.0):
							_fail("Player did not survive a real-input Wychwood bridge crossing")
						await _fight_wychwood_pack(game)
						if failures.is_empty():
							await _return_wychwood_to_greyfen(game)
							if failures.is_empty():
								await _report_to_anwen(game)
								if failures.is_empty():
									if wychwood_only:
										print("REAL_INPUT wychwood_affected_route=PASS new_game=true clues=3 enemies=5 bridges=both return_report=true")
									else:
										await _meet_anwen_and_inspect_graves(game)

func _save_ashwing_handoff(game: Node) -> void:
	var slot := await _save_campaign_checkpoint(game)
	if not failures.is_empty():
		return
	var saved: Dictionary = slot.get("data", {})
	var saved_flags: Dictionary = saved.get("story_state", {}).get("flags", {})
	if not bool(slot.get("ok", false)) or str(saved.get("zone", "")) != "old_mill" or not bool(saved_flags.get("ashwing_spawned", false)):
		_fail("Real pause-menu save did not retain the Ashwing mill handoff")
	else:
		print("REAL_INPUT ashwing_handoff_manual_save=PASS zone=old_mill")

func _save_campaign_checkpoint(game: Node) -> Dictionary:
	owner.region=str(game.current_zone_id)
	await owner._release()
	await owner._tap(KEY_ESCAPE)
	await owner._button("Quick Save")
	await owner._frames(12)
	return game.save_manager._read_slot(game.save_manager.SAVE_PATH)

func _shutdown_game(_game: Node) -> void: owner._fail("Legacy helper requested early world teardown")

func _travel_to_ash_mill(game: Node) -> void:
	await owner._travel("old_mill")
	await _save_campaign_checkpoint(game)

func _travel_to_assembly(game: Node) -> void:
	await owner._travel("assembly")
	await _save_campaign_checkpoint(game)

func _travel_to_bandit_road(game: Node) -> void:
	await owner._travel("bandit_road")
	await _save_campaign_checkpoint(game)

func _travel_to_castle_approach(game: Node) -> void:
	await owner._travel("vargan_approach")
	await _save_campaign_checkpoint(game)

func _travel_to_hart_glade(game: Node) -> void:
	await owner._travel("hart_glade")
	await _save_campaign_checkpoint(game)

func _turn_camera_north(game: Node) -> void:
	route_camera_yaw = 0.0
	await owner._face(game.player.global_position+Vector3.FORWARD*5.0)
	owner._check(absf(angle_difference(float(game.camera_rig.yaw),route_camera_yaw))<0.06,"Screen swipes restore the route bearing")

func _use_focused_interaction(game: Node, interaction_id: String, label: String, expected_speaker: String = "") -> void:
	if not await _await_focused_interaction(game, interaction_id, label):
		return
	var requires_dialogue: bool = game.active_interactable.interaction_type == "dialogue"
	await _key(KEY_E, true)
	await _frames(3)
	await _key(KEY_E, false)
	await _frames(5)
	if requires_dialogue and not game.hud.dialogue_layer.visible:
		_fail("%s real E input did not open its dialogue" % label)
		return
	if expected_speaker != "" and (not game.hud.dialogue_layer.visible or game.hud.dialogue_title.text != expected_speaker):
		_fail("%s did not show the actual %s conversation" % [label, expected_speaker])
		return
	if game.hud.dialogue_layer.visible:
		for _page in range(24):
			if not game.hud.dialogue_layer.visible:
				break
			await _key(KEY_ENTER, true)
			await _frames(3)
			await _key(KEY_ENTER, false)
			await _frames(5)
		if game.hud.dialogue_layer.visible:
			_fail("%s dialogue did not return control" % label)
			return
	print("REAL_INPUT %s=PASS position=%s" % [label, game.player.global_position])

func _use_south_bank_clue(game: Node, clue_id: String, objective_id: String, side_key: Key, target_x: float, approach_z: float) -> void:
	if not failures.is_empty():
		return
	if side_key == KEY_D:
		await _move_until(game, side_key, clue_id + "_offset", func(p: Vector3) -> bool: return p.x > target_x, 4000)
	else:
		await _move_until(game, side_key, clue_id + "_offset", func(p: Vector3) -> bool: return p.x < target_x, 4000)
	await _move_until(game, KEY_W, clue_id + "_layby", func(p: Vector3) -> bool: return p.z < approach_z, 4000)
	if not failures.is_empty():
		return
	var focus_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < focus_deadline and (game.active_interactable == null or game.active_interactable.interaction_id != clue_id):
		await process_frame
	if game.active_interactable == null or game.active_interactable.interaction_id != clue_id:
		_fail("%s did not receive normal focus at its layby; position=%s focus=%s" % [clue_id, game.player.global_position, game.active_interactable])
		return
	await _key(KEY_E, true)
	await _frames(3)
	await _key(KEY_E, false)
	await _frames(7)
	if not game.quests.is_objective_done("main_road_of_crows", objective_id):
		_fail("Real E input did not record %s evidence" % objective_id)
	else:
		print("REAL_INPUT %s=PASS position=%s" % [objective_id, game.player.global_position])

func _verify_rootbound_reload(game: Node) -> void:
	owner._check(game.quests.is_objective_done("main_names_they_burned","reconstruct_register"),"Rootbound requires the actually reconstructed register")
	if not bool(game.story_state.get_flag("rootbound_arena_entered",false)):
		await owner._interact("rootbound_challenge")
	owner._check(bool(game.story_state.get_flag("rootbound_arena_entered",false)),"Actual invitation opens the guardian's memory clearing")
