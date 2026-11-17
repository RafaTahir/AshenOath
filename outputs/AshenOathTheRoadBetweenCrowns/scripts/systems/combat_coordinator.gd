extends "res://scripts/systems/game_bindings.gd"
## Owns combat operations; configure() injects dependencies.
signal combat_impact(position: Vector3, heavy: bool)

const CombatImpactView = preload("res://scripts/views/combat_impact_view.gd")
var combat_impact_view: RefCounted = CombatImpactView.new(self)
const CombatEncounterView = preload("res://scripts/views/combat_encounter_view.gd")
var combat_encounter_view: RefCounted = CombatEncounterView.new(self)
const CombatBossView = preload("res://scripts/views/combat_boss_view.gd")
var combat_boss_view: RefCounted = CombatBossView.new(self)
const HitModel = preload("res://scripts/models/combat_hit_model.gd")

func _on_player_blade_contact(contact: Dictionary) -> void:
	var heavy: Variant = bool(contact.get("heavy", false))
	if bool(contact.get("first_sample", true)):
		audio.play_event("heavy" if heavy else "swing")
	var civilians: Variant = _civilian_contact_candidates(player.global_position, 4.0)
	var result: Dictionary = combat.resolve_player_blade_contact(player, active_enemies, contact, inventory.active_oil, civilians)
	if not bool(result.get("hit", false)):
		var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(_host)
		if practice != null and practice.blade_contact(contact):
			result["hit"] = true
			result["surface"] = "wood"
			result["kind"] = "practice"
	player.confirm_blade_contact(int(contact.get("attack_id", -1)), bool(result.get("hit", false)))
	if bool(result.get("hit", false)):
		_present_surface_contact(result, false)
		_hitstop(0.055 if heavy else 0.032)
		var contact_color: Variant = Color(0.66, 0.88, 1.0) if str(result.get("blade_id", "steel")) == "oathblade" or str(result.get("source_tag", "")) == "spirit" else Color(0.98, 0.78, 0.34)
		if str(result.get("surface", "")) != "flesh": CombatFeedback.weapon_contact(
			zone_root,
			result.get("blade_base", player.global_position),
			result.get("blade_tip", player.global_position),
			result.get("contact_point", result.get("point", player.global_position)),
			heavy,
			contact_color,
			result.get("previous_base", Vector3.ZERO),
			result.get("previous_tip", Vector3.ZERO)
		)
		if input_router != null:
			input_router.rumble(0.16 if heavy else 0.09, 0.30 if heavy else 0.20, 0.07)
		if camera_rig != null:
			camera_rig.shake(0.09 if heavy else 0.045)
		var target = result.get("enemy")
		if target != null and is_instance_valid(target) and target.health_component != null:
			hud.show_enemy(target.display_name, target.health_component.health, target.health_component.max_health)
			if target.enemy_id == "bog_wretch":
				if inventory.active_oil == "moon_oil":
					_expose_bog_core(target, "Moon Oil")
				elif heavy:
					_record_bog_stagger(target, "heavy blows")

func _on_player_arrow_unavailable() -> void:
	combat_impact_view._on_player_arrow_unavailable()

func _on_player_arrow(request: Dictionary) -> void:
	if player == null or zone_root == null:
		return
	if bool(request.get("training", false)):
		var range_node: Variant = instance_from_id(int(request.get("training_owner", 0))) as Node
		if is_instance_valid(range_node) and range_node == zone_root.get_node_or_null("GreyfenArcheryRange"):
			range_node.fire(request)
		# A retired or cancelled training request can never fall through to damage.
		return
	var origin: Vector3 = request.get("origin", player.global_position + Vector3.UP * 1.3)
	var direction: Vector3 = request.get("direction", -player.global_transform.basis.z)
	if direction.length_squared() < 0.5:
		direction = -player.global_transform.basis.z
	direction = direction.normalized()
	var arrow_id: Variant = str(request.get("arrow_id", "standard_arrow"))
	var arrow_def: Dictionary = inventory.item_defs.get(arrow_id, {})
	var effect: Dictionary = arrow_def.get("effect", {})
	var damage: float = HitModel.arrow_damage(effect, float(request.get("draw_ratio", 0.0)))
	if float(request.get("draw_ratio", 0.0)) >= 0.99:
		damage *= progression.effect_value("saga_full_draw_damage_multiplier", 1.0)
	var arrow_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			arrow_exclusions.append(enemy.get_rid())
	audio.play_event("swing", 0.02)
	var arrow_targets: Array = active_enemies.duplicate()
	arrow_targets.append_array(_civilian_contact_candidates(origin, float(request.get("range",24.0)) + 2.0))
	combat_vfx_coordinator.launch_arrow(zone_root, origin, direction, float(request.get("range", 24.0)), arrow_targets, combat, arrow_exclusions, {
		"width": float(request.get("width", 0.34)),
		"damage": damage,
		"velocity": preload("res://scripts/arrow_flight.gd").speed(effect, float(request.get("draw_ratio", 0.0))),
		"source_tag": "arrow_%s" % arrow_id,
	}, Callable(_host, "_on_arrow_impact").bind(arrow_id, damage, zone_root.get_instance_id()))

func _on_arrow_impact(result: Dictionary, arrow_id: String, damage: float, zone_instance: int) -> void:
	combat_impact_view._on_arrow_impact(result, arrow_id, damage, zone_instance)

func _present_surface_contact(result: Dictionary, arrow: bool) -> void:
	combat_impact_view._present_surface_contact(result, arrow)

func _civilian_contact_candidates(position: Vector3, radius: float) -> Array:
	if not is_instance_valid(zone_root): return []
	var life: Node
	for owner_name: String in ["GreyfenLifeController", "RegionalLifeController"]:
		life = zone_root.get_node_or_null(owner_name)
		if life != null: break
	var people: Array = []
	for area in interaction_focus.registered_nearby(position,zone_root,radius):
		if str(area.get("interaction_type")) == "dialogue" and area.find_child("CharacterAnimationDriver",true,false) != null:
			people.append(area)
	if life == null and not people.is_empty():
		life = _gameplay_script("greyfen_life_controller").new()
		life.name = "RegionalLifeController"
		zone_root.add_child(life)
		life.configure(_host,str(settings.settings.get("quality_preset","balanced")),true)
	if life == null: return []
	for person in people: life.enroll_contact_actor(person)
	return life.contact_candidates(position,radius)

func _make_arrow_trail(origin: Vector3, endpoint: Vector3, color: Color) -> void:
	combat_impact_view._make_arrow_trail(origin, endpoint, color)

func _on_player_beam_phase(phase: String) -> void:
	combat_impact_view._on_player_beam_phase(phase)

func _on_player_beam(charge_ratio: float, direction: Vector3) -> void:
	if player == null or zone_root == null:
		return
	_clear_oathfire_effects()
	var locked_direction: Vector3 = direction
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5 and player.has_method("get_beam_locked_direction"):
		locked_direction = player.get_beam_locked_direction()
	if locked_direction.length_squared() < 0.5:
		locked_direction = -player.global_transform.basis.z
	locked_direction.y = 0.0
	if locked_direction.length_squared() < 0.5:
		locked_direction = Vector3.FORWARD
	locked_direction = locked_direction.normalized()
	var origin: Vector3 = player.get_oathfire_origin() if player.has_method("get_oathfire_origin") else player.global_position + Vector3(0, 1.12, 0) + locked_direction * 0.62
	var beam_range: float = 12.0 + progression.effect_value("beam_range_bonus", 0.0)
	var endpoint: Vector3 = origin + locked_direction * beam_range
	var query = PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
	var beam_exclusions: Array[RID] = [player.get_rid()]
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			beam_exclusions.append(enemy.get_rid())
	query.exclude = beam_exclusions
	query.collide_with_areas = false
	var result: Dictionary = _host.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		endpoint = result.position
	var damage: float = HitModel.beam_damage(charge_ratio)
	var cast: Variant = {
		"origin": origin,
		"direction": locked_direction,
		"endpoint": endpoint,
		"endpoint_distance": origin.distance_to(endpoint),
		"width": 1.2,
		"damage": damage,
		"charge_ratio": charge_ratio
	}
	var hits: Array = combat.resolve_oathfire_cast(active_enemies, cast)
	var practice: Node = preload("res://scripts/greyfen_village_details.gd").current(_host)
	if practice != null: practice.oathfire_contact(cast)
	_host.set_meta("last_oathfire_cast", cast)
	_host.set_meta("last_oathfire_hit_count", hits.size())
	_make_oathfire_beam(origin, endpoint, charge_ratio, not _performance_mode())
	CombatFeedback.beam_endpoint(zone_root, endpoint, locked_direction, not _performance_mode())
	if camera_rig != null:
		camera_rig.shake(0.12 + 0.08 * charge_ratio)
	CombatFeedback.ground_ring(zone_root, player.global_position, Color(0.18, 0.72, 0.95), 0.75, 0.18)
	CombatFeedback.impact_burst(zone_root, origin, false, Color(0.62, 0.95, 1.0))
	CombatFeedback.impact_burst(zone_root, endpoint, true, Color(0.26, 0.82, 1.0))
	for enemy in hits:
		if is_instance_valid(enemy) and enemy.has_method("interrupt_boss_windup") and str(enemy.get("enemy_id")) == "ashwing":
			if enemy.interrupt_boss_windup("oathfire"):
				hud.toast("Oathfire breaks Ashwing's breath.")
		CombatFeedback.impact_burst(zone_root, enemy.global_position + Vector3(0, 0.9, 0), true, Color(0.30, 0.88, 1.0))
	hud.show_status_cue("Oathfire Beam", "item")

func _make_oathfire_beam(origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	combat_impact_view._make_oathfire_beam(origin, endpoint, charge_ratio, rich_effect)

func _clear_oathfire_effects() -> void:
	combat_impact_view._clear_oathfire_effects()

func _on_player_footstep() -> void:
	combat_impact_view._on_player_footstep()

func _on_player_parried() -> void:
	combat_impact_view._on_player_parried()

func _on_player_blocked(_amount: float) -> void:
	combat_impact_view._on_player_blocked(_amount)

func _on_player_hurt(_amount: float) -> void:
	combat_impact_view._on_player_hurt(_amount)

func _on_player_stamina_exhausted(_action: String) -> void:
	combat_impact_view._on_player_stamina_exhausted(_action)

func _on_enemy_died(enemy: Variant) -> void:
	combat_encounter_view._on_enemy_died(enemy)

func _try_complete_black_dog_investigation() -> void:
	combat_encounter_view._try_complete_black_dog_investigation()

func _try_complete_oren_thread_trace(publish_return: bool = true) -> void:
	combat_encounter_view._try_complete_oren_thread_trace(publish_return)

func _record_encounter_knowledge(enemy: Variant) -> void:
	combat_encounter_view._record_encounter_knowledge(enemy)

func _on_enemy_damaged(enemy: Variant, current: float, maximum: float) -> void:
	combat_impact_view._on_enemy_damaged(enemy, current, maximum)

func _on_enemy_windup_started(enemy: Variant) -> void:
	combat_impact_view._on_enemy_windup_started(enemy)

func _on_enemy_attack_resolved(enemy: Variant, parried: bool, contact_position: Vector3) -> void:
	combat_impact_view._on_enemy_attack_resolved(enemy, parried, contact_position)

func _on_enemy_parry_window_opened(enemy: Node, duration: float) -> void:
	combat_impact_view._on_enemy_parry_window_opened(enemy, duration)

func _record_bog_stagger(enemy: Variant, source: String) -> void:
	combat_encounter_view._record_bog_stagger(enemy, source)

func _expose_bog_core(enemy: Variant, method: String) -> void:
	combat_encounter_view._expose_bog_core(enemy, method)

func _on_target_lock_changed(target_actor: Node3D, locked: bool) -> void:
	combat_impact_view._on_target_lock_changed(target_actor, locked)

func _update_target_lock_hud() -> void:
	combat_impact_view._update_target_lock_hud()

func _on_combat_impact(pos: Vector3, heavy: bool) -> void:
	combat_impact_view._on_combat_impact(pos, heavy)

func _hitstop(seconds: float) -> void:
	combat_impact_view._hitstop(seconds)

func _has_living_enemy(enemy_id: String) -> bool:
	return combat_encounter_view._has_living_enemy(enemy_id)

func accept_ordinary_surrender(enemy: Node) -> void:
	combat_encounter_view.accept_ordinary_surrender(enemy)

func _nearest_living_enemy(max_distance: float) -> Variant:
	return combat_encounter_view._nearest_living_enemy(max_distance)

func _on_player_died() -> void:
	combat_encounter_view._on_player_died()

func _spawn_enemy(id: String, pos: Vector3, visual_role: String = "") -> Node:
	return _zone_construction()._spawn_enemy(id, pos, visual_role)

func _boss_is_resolved(id: String) -> bool:
	return combat_boss_view._boss_is_resolved(id)

func _ensure_bell_eater() -> void:
	combat_boss_view._ensure_bell_eater()

func _retire_bell_eater() -> void:
	combat_boss_view._retire_bell_eater()

func _open_rootbound_encounter() -> void:
	combat_boss_view._open_rootbound_encounter()

func _evacuate_bell_eater_bystanders() -> void:
	combat_boss_view._evacuate_bell_eater_bystanders()

func _restore_bell_eater_bystanders() -> void:
	combat_boss_view._restore_bell_eater_bystanders()

func _on_boss_controller_phase_changed(boss_id: String, phase: int) -> void:
	combat_boss_view._on_boss_controller_phase_changed(boss_id, phase)

func _on_boss_checkpoint(controller: Node) -> void:
	combat_boss_view._on_boss_checkpoint(controller)

func _on_boss_resolved(boss_id: String, outcome: String) -> void:
	combat_boss_view._on_boss_resolved(boss_id, outcome)

func _apply_boss_resolution_contract(boss_id: String) -> void:
	combat_boss_view._apply_boss_resolution_contract(boss_id)

func _publish_halvern_exit() -> void:
	combat_boss_view._publish_halvern_exit()

func _on_boss_peaceful_resolution(boss_id: String, outcome: String, enemy: Node) -> void:
	combat_boss_view._on_boss_peaceful_resolution(boss_id, outcome, enemy)

func _on_boss_phase_changed(enemy: Node, phase: int) -> void:
	combat_boss_view._on_boss_phase_changed(enemy, phase)

func _on_boss_special_attack(enemy: Node, attack_id: String, contact_position: Vector3, radius: float, damage: float, parried: bool) -> void:
	combat_boss_view._on_boss_special_attack(enemy, attack_id, contact_position, radius, damage, parried)

func _activate_wychwood_wave(ids: Array, cue: String) -> void:
	combat_boss_view._activate_wychwood_wave(ids, cue)

func _ensure_wychwood_wave() -> void:
	combat_boss_view._ensure_wychwood_wave()

func checkpoint_return_position() -> Vector3:
	return combat_boss_view.checkpoint_return_position()

func _has_active_encounter_enemy() -> bool:
	return combat_boss_view._has_active_encounter_enemy()

func _enemy_attack_token(enemy: Node, claim: bool) -> bool:
	return combat_boss_view._enemy_attack_token(enemy, claim)

func read_presentation_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
	return node.get_meta(key, fallback)

func write_presentation_tag(node: Node, key: StringName, value: Variant) -> void:
	node.set_meta(key, value)
