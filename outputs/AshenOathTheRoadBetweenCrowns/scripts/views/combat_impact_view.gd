extends RefCounted
## combat impact view: scene effects and consequence presentation.

var _actor: Node3D

func _init(actor: Node3D) -> void:
	_actor = actor

func _on_player_arrow_unavailable() -> void:
	_actor.hud.toast("No arrows. Tor keeps a reserve at his forge in Greyfen.")
	_actor.hud.show_status_cue("No arrows", "hurt")

func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void:
	if not is_instance_valid(_actor.zone_root) or zone_instance != _actor.zone_root.get_instance_id(): return
	if bool(result.get("hit", false)):
		_actor._present_surface_contact(result, true)
		if str(result.get("kind", "")) == "scenery": return
		_actor.hud.show_status_cue("Arrow struck a person" if str(result.get("kind", "")) == "civilian" else "Arrow hit: %d" % int(damage), "item")
		var target = result.get("enemy")
		if target != null and is_instance_valid(target):
			_actor.hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.dead and arrow_id in ["standard_arrow", "bodkin_arrow"] and _actor.progression.effect_value("arrow_recovery_on_kill", 0.0) > 0.0:
				_actor.inventory.add_item(arrow_id, 1)
				_actor.story_save_pending = true
				_actor._host.call_deferred("_persist_story_action")

func _present_surface_contact(result: Dictionary, arrow: bool) -> void:
	var surface: Variant = str(result.get("surface", "metal"))
	var event: Variant = ("arrow_contact" if arrow else "flesh_contact") if surface == "flesh" else str({"wood":"wood_contact","stone":"stone_contact","foliage":"foliage_contact"}.get(surface,"light_hit"))
	_actor.audio.play_spatial_event(event,result.get("point",_actor.player.global_position),_actor.player.global_position,14.0,0.06,0.06)
	_actor.combat_vfx_coordinator.surface_contact(_actor.zone_root,result,bool(_actor.settings.settings.get("blood_effects",true)),bool(_actor.settings.settings.get("flash_reduction",false)))
	_actor.audio.perception_cue.emit(result.get("point",_actor.player.global_position),7.0,str(result.get("kind","")) != "scenery")

func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	_actor.combat_vfx_coordinator.make_arrow_trail(_actor.zone_root, origin, endpoint, color)

func _on_player_beam_phase(phase: String) -> void:
	match phase:
		"sheathing": _actor.audio.play_event("oathfire_sheathe",0.02)
		"charging": _actor.audio.play_event("oathfire_charge",0.01)
		"releasing": _actor.audio.play_event("oathfire_release",0.015)

func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	var reduce_flashes: Variant = bool(_actor.settings.settings.get("flash_reduction", false))
	_actor.combat_vfx_coordinator.make_oathfire_beam(_actor.zone_root, origin, endpoint, charge_ratio, rich_effect, reduce_flashes)

func _clear_oathfire_effects() -> void:
	_actor.combat_vfx_coordinator.clear_oathfire_effects()

func _on_player_footstep() -> void:
	if _actor.audio == null or _actor.player == null:
		return
	var on_road = abs(_actor.player.global_position.x) < 2.25
	if _actor.current_zone_id == "wychwood":
		on_road = abs(_actor.player.global_position.x) < 2.5 and _actor.player.global_position.z > -12.5
	var surface: Variant = "road" if on_road else "forest"
	if _actor.current_zone_id in ["vargan_court", "record_hall", "undercroft", "assembly"]:
		surface = "stone"
	elif _actor.current_zone_id in ["marsh_crossing", "old_mill", "burned_farmstead"]:
		surface = "mud"
	elif _actor.current_zone_id == "hart_glade":
		surface = "forest"
	elif _actor.spatial_service != null and _actor.spatial_service.is_on_bridge(_actor.player.global_position):
		surface = "wood"
	surface = _actor.combat.foot_surface(_actor.player, surface)
	_actor.audio.play_footstep(_actor.current_zone_id, on_road, surface)

func _on_player_parried() -> void:
	if _actor.current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(_actor._host, "parry")
	if _actor.progression != null and _actor.player != null:
		_actor.player.stamina_component.restore(_actor.progression.effect_value("parry_stamina_restore", 0.0) + _actor.progression.entitlement_effect("saga_parry_restore", 0.0))
	_actor.tutorial_flags["block_hint_done"] = true
	_actor.hud.set_guidance_hint("")

func _on_player_blocked(_amount: float) -> void:
	if _actor.current_zone_id == "wychwood": preload("res://scripts/greyfen_guidance.gd").learn(_actor._host, "block")
	_actor.audio.play_event("block")
	if _actor.input_router != null:
		_actor.input_router.rumble(0.18, 0.32, 0.08)
	if _actor.camera_rig != null:
		_actor.camera_rig.shake(0.08)
	if _actor.zone_root != null and _actor.player != null:
		var blade: Dictionary = _actor.player.get_blade_world_segment()
		var contact: Vector3 = (blade.base as Vector3).lerp(blade.tip, 0.55)
		_actor.CombatFeedback.block_flash(_actor.zone_root, _actor.player.global_position, false, contact)
		_actor.CombatFeedback.ground_ring(_actor.zone_root, _actor.player.global_position, Color(0.58, 0.36, 0.12), 0.45, 0.12)
	_actor.hud.show_status_cue("Blocked", "block")
	_actor.tutorial_flags["block_hint_done"] = true
	_actor.hud.set_guidance_hint("")

func _on_player_hurt(_amount: float) -> void:
	_actor.audio.play_event("hurt")
	if _actor.input_router != null:
		_actor.input_router.rumble(0.36, 0.58, 0.14)
	if _actor.camera_rig != null:
		_actor.camera_rig.shake(0.14)
	if _actor.zone_root != null and _actor.player != null:
		_actor.CombatFeedback.impact_burst(_actor.zone_root, _actor.player.global_position + Vector3(0, 1.0, 0), false, Color(0.9, 0.22, 0.12))
	_actor.hud.show_status_cue("Hit: -%d" % int(_amount), "hurt")

func _on_player_stamina_exhausted(_action: String) -> void:
	_actor.hud.mark_stamina_exhausted()
	_actor.hud.set_guidance_hint("Breath is spent. Back away, then strike.", 2.8)

func _on_enemy_damaged(enemy: Variant, current: float, maximum: float) -> void:
	_actor._record_encounter_knowledge(enemy)
	_actor.hud.show_enemy(enemy.display_name, current, maximum)
	_actor.hud.show_status_cue("Enemy hit", "item")
	_actor.audio.play_enemy_event(enemy.enemy_id, "hit", enemy.global_position, _actor.player.global_position)

func _on_enemy_windup_started(enemy: Variant) -> void:
	_actor._record_encounter_knowledge(enemy)
	if enemy != null and _actor.player != null:
		_actor.audio.play_enemy_event(enemy.enemy_id, "windup", enemy.global_position, _actor.player.global_position)
	if _actor.zone_root != null and enemy != null:
		if not bool(enemy.get("is_boss")):
			_actor.CombatFeedback.ground_ring(_actor.zone_root, enemy.global_position, Color(0.46, 0.05, 0.025), 0.62, 0.18)
	if enemy != null and enemy.health_component != null:
		_actor.hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)
	var guide_guard_pending: Variant = str(_actor.story_state.get_flag("greyfen_guide", "")) == "active" and (not bool(_actor.story_state.get_flag("greyfen_lesson:block", false)) or not bool(_actor.story_state.get_flag("greyfen_lesson:parry", false)))
	if _actor.current_zone_id == "wychwood" and (guide_guard_pending or not bool(_actor.tutorial_flags.get("block_hint_done", false))):
		_actor.hud.set_guidance_hint(_actor._systems["hud"]._guard_tutorial_hint(), 4.2)

func _on_enemy_attack_resolved(enemy: Variant, parried: bool, contact_position: Vector3) -> void:
	if parried:
		var blade: Dictionary = _actor.player.get_blade_world_segment()
		contact_position = Geometry3D.get_closest_point_to_segment(contact_position, blade.base, blade.tip)
		_actor.audio.play_event_limited("parry", 0.10, 0.03)
		if _actor.input_router != null:
			_actor.input_router.rumble(0.24, 0.52, 0.10)
		if _actor.camera_rig != null:
			_actor.camera_rig.shake(0.18)
		if _actor.zone_root != null:
			_actor.CombatFeedback.block_flash(_actor.zone_root, _actor.player.global_position, true, contact_position)
			_actor.CombatFeedback.impact_burst(_actor.zone_root, contact_position, true, Color(0.74, 0.88, 1.0))
			_actor.CombatFeedback.ground_ring(_actor.zone_root, _actor.player.global_position, Color(0.22, 0.46, 0.72), 0.65, 0.16)
		_actor.hud.show_status_cue("Parry", "parry")
		_actor.hud.toast("Parry breaks %s's guard." % enemy.display_name)
		if enemy != null and enemy.enemy_id == "bog_wretch":
			_actor._record_bog_stagger(enemy, "parries")
	else:
		if enemy != null:
			_actor.audio.play_enemy_event(enemy.enemy_id, "attack", contact_position, _actor.player.global_position)
		if _actor.zone_root != null and enemy != null:
			_actor.CombatFeedback.impact_burst(_actor.zone_root, contact_position, false, Color(0.85, 0.30, 0.12))
	if enemy != null and enemy.health_component != null:
		_actor.hud.show_enemy(enemy.display_name, enemy.health_component.health, enemy.health_component.max_health)

func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not bool(enemy.get("is_boss")):
		return
	if enemy.enemy_id == "captain_senn":
		preload("res://scripts/saga_encounters.gd").senn_yields(_actor._host, enemy)
	elif enemy.enemy_id == "halvern_boss":
		_actor.story_state.set_flag("halvern_guard_broken", true)
		if _actor.quests.is_active("main_last_witness"):
			_actor.quests.complete_objective("main_last_witness", "break_halvern_guard")
		_actor.hud.show_status_cue("Halvern's guard breaks", "parry")
		_actor._show_current_objective_guidance(maxf(duration, 2.5))
		_actor.audio.play_event_limited("parry", 0.16, 0.02)

func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void:
	if _actor.hud == null:
		return
	if not locked or target_actor == null or not is_instance_valid(target_actor):
		_actor.hud.clear_target_lock_status()
		return
	var display_name: Variant = str(target_actor.get("display_name"))
	_actor.hud.set_target_lock_status(display_name if display_name != "" else "Enemy", _actor.player.global_position.distance_to(target_actor.global_position))

func _update_target_lock_hud() -> void:
	if _actor.hud == null or _actor.camera_rig == null or not (_actor.camera_rig != null):
		return
	var target_actor: Node3D = _actor.camera_rig.get_locked_combat_target()
	if target_actor == null or not is_instance_valid(target_actor):
		_actor.hud.clear_target_lock_status()
		return
	var display_name: Variant = str(target_actor.get("display_name"))
	_actor.hud.set_target_lock_status(display_name if display_name != "" else "Enemy", _actor.player.global_position.distance_to(target_actor.global_position))

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	_actor._hitstop(0.055 if heavy else 0.032)
	if _actor.audio != null:
		_actor.audio.play_event("heavy_hit" if heavy else "light_hit", 0.04)
	if _actor.camera_rig != null:
		_actor.camera_rig.shake(0.11 if heavy else 0.06)
	_actor._make_hit_spark(pos, heavy)
	if _actor.zone_root != null:
		_actor.CombatFeedback.ground_ring(_actor.zone_root, pos, Color(0.54, 0.36, 0.16), 0.42 if heavy else 0.30, 0.12)
	_actor.combat_impact.emit(pos, heavy)

func _hitstop(seconds: float) -> void:
	if _actor._host.get_tree().paused or _actor.zone_transition_pending:
		return
	if _actor.settings != null and bool(_actor.settings.settings.get("reduced_motion", false)):
		return
	if not is_equal_approx(Engine.time_scale, 0.18):
		_actor._hitstop_restore_scale = Engine.time_scale
	_actor._hitstop_generation += 1
	var generation: Variant = _actor._hitstop_generation
	Engine.time_scale = 0.18
	var timer: Variant = _actor._create_owned_timer(seconds, true)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func() -> void:
		if generation == _actor._hitstop_generation:
			Engine.time_scale = _actor._hitstop_restore_scale
	)
