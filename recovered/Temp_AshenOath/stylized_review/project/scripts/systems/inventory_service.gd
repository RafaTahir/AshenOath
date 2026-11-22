extends "res://scripts/systems/game_bindings.gd"
## Owns inventory operations; configure() injects dependencies.
signal inventory_operation_completed(result: Dictionary)

func _use_potion() -> void:
	_use_quick_item(inventory.quick_item("use_potion"))

func _throw_bomb() -> void:
	_use_quick_item(inventory.quick_item("throw_bomb"))

func _use_inventory_item(item_id: String) -> Dictionary:
	if player == null or not is_instance_valid(player) or inventory == null:
		return _preparation_item_result(item_id, false, "Kael must be on the road to prepare this item.")
	var item_name: String = inventory.get_item_name(item_id)
	if not inventory.can_consume(item_id):
		return _preparation_item_result(item_id, false, "No %s left." % item_name)
	if inventory.get_item_type(item_id) == "ammo":
		if player.get_selected_arrow_id() == item_id:
			return _preparation_item_result(item_id, false, "%s is already selected." % item_name, "select")
		var selected: bool = player.select_arrow(item_id)
		return _preparation_item_result(item_id, selected, "%s selected for the next shot." % item_name if selected else "These arrows cannot be selected.", "select")
	if inventory.get_item_type(item_id) == "oil":
		var applied: bool = inventory.apply_oil(item_id)
		return _preparation_item_result(item_id, applied, "%s coats the blades for %s of active play. One bottle used." % [item_name, inventory.oil_time_text()] if applied else "The coating could not be applied.", "apply", 1 if applied else 0)
	var effect: Dictionary = preload("res://scripts/preparation_view_model.gd").resolved_effect(item_id, inventory, progression)
	if item_id == "redroot_potion":
		var missing_health: float = maxf(0.0, player.health_component.max_health - player.health_component.health)
		if missing_health <= 0.0:
			return _preparation_item_result(item_id, false, "Health is full. Redroot remains in your pack.")
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Redroot remains.")
		var restored: float = minf(missing_health, float(effect.get("heal", 45.0)))
		player.health_component.heal(restored)
		audio.play_event("potion")
		return _preparation_item_result(item_id, true, "Redroot restored %s health." % str(snappedf(restored, 0.1)), "use", 1)
	if item_id == "bitterleaf_tonic":
		var missing_stamina: float = maxf(0.0, player.stamina_component.max_stamina - player.stamina_component.stamina)
		if missing_stamina <= 0.0:
			return _preparation_item_result(item_id, false, "Stamina is full. Bitterleaf remains in your pack.")
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Bitterleaf remains.")
		var restored: float = minf(missing_stamina, float(effect.get("stamina", 55.0)))
		player.stamina_component.restore(restored)
		audio.play_event("potion")
		return _preparation_item_result(item_id, true, "Bitterleaf restored %s stamina." % str(snappedf(restored, 0.1)), "use", 1)
	if item_id == "ash_bomb":
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Ash Bomb remains.")
		audio.play_event("bomb")
		if camera_rig != null:
			camera_rig.shake(0.12)
		combat.throw_bomb(player, active_enemies, float(effect.get("damage", 45.0)))
		for enemy in active_enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.enemy_id == "bog_wretch" and enemy.global_position.distance_to(player.global_position) <= 6.5:
				_expose_bog_core(enemy, "Ash Bomb")
		return _preparation_item_result(item_id, true, "Ash Bomb thrown.", "use", 1)
	if item_id == "iron_trap":
		if not inventory.consume(item_id):
			return _preparation_item_result(item_id, false, "No Iron Trap remains.")
		combat.place_trap(player, active_enemies)
		return _preparation_item_result(item_id, true, "Iron Trap set at your feet.", "use", 1)
	return _preparation_item_result(item_id, false, "This item has no preparation action.")

func _preparation_item_result(item_id: String, ok: bool, message: String, operation: String = "use", consumed: int = 0) -> Dictionary:
	return {
		"ok": ok, "operation": operation, "item_id": item_id,
		"quantity": consumed, "message": message, "reason": "" if ok else message,
		"spent": {"items": {item_id: consumed}} if consumed > 0 else {},
		"remaining": {"items": inventory.items.duplicate(true), "coin": int(inventory.coin)} if inventory != null else {}
	}

func _update_preparation_context() -> void:
	var snapshot: Dictionary = {"zone_id": current_zone_id}
	snapshot["respec_reason"] = _respec_unavailable_reason()
	if quest_presentation != null:
		snapshot["objective"] = quest_presentation.get_objective_view_model()
	var supply_sources: Dictionary = {}
	if vendor_service != null and inventory != null:
		for vendor_id: String in ["tor_forge", "mira_apothecary"]:
			for stock: Dictionary in vendor_service.list_stock(vendor_id, inventory, story_state, quests):
				var item_id: String = str(stock.get("item_id", ""))
				var quote: Dictionary = vendor_service.quote(vendor_id, item_id, 1, inventory, story_state, quests)
				if not supply_sources.has(item_id):
					supply_sources[item_id] = []
				supply_sources[item_id].append({"vendor_id":vendor_id, "name":str(vendor_service.get_vendor(vendor_id).get("name", vendor_id)), "price":int(stock.get("price", 0)), "reason":str(quote.get("reason", ""))})
	snapshot["supply_sources"] = supply_sources
	if player != null and is_instance_valid(player):
		snapshot.merge({
			"health": float(player.health_component.health), "max_health": float(player.health_component.max_health),
			"stamina": float(player.stamina_component.stamina), "max_stamina": float(player.stamina_component.max_stamina),
			"weapon_mode": str(player.get_weapon_mode()), "selected_arrow_id": str(player.get_selected_arrow_id()),
			"equipment": player.save_equipment_state()
		})
	hud.set_preparation_context(snapshot)

func _show_preparation_menu() -> void:
	_update_preparation_context()
	hud.show_inventory(inventory, quests, story_state, progression)

func _craft_preparation_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = crafting.craft_result(item_id)
	preparation_action_in_progress = false
	_finish_preparation_operation(result)

func _use_preparation_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = _use_inventory_item(item_id)
	preparation_action_in_progress = false
	_finish_preparation_operation(result)

func _set_inventory_preference(key: String, value: String) -> void:
	var ok: bool = inventory.set_quick_item(key.trim_prefix("quick:"), value) if key.begins_with("quick:") else inventory.set_kit_preference(key, value)
	var message: String = "Pack order saved."
	if key == "category":
		message = value.capitalize()
	elif key.begins_with("quick:"):
		message = inventory.get_item_name(value) + " assigned to the " + ("remedy" if key == "quick:use_potion" else "field tool") + " slot."
	_finish_preparation_operation({"ok": ok, "operation": "inventory_preference", "message": message if ok else "That inventory choice is unavailable."})

func _learn_preparation_practice(upgrade_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = progression.unlock_result(upgrade_id)
	preparation_action_in_progress = false
	if bool(result.get("ok", false)):
		_apply_progression_to_player()
	_finish_preparation_operation(result)

func _respec_unavailable_reason() -> String:
	if not game_started or current_zone_id != "greyfen" or not is_instance_valid(player) or not is_instance_valid(zone_root):
		return "Visit the shrine bench in Greyfen."
	if _journey_load_pending() or zone_transition_pending or zone_load_request_pending:
		return "Wait until the journey handoff has finished."
	if _story_has_active_combat():
		return "Finish the encounter before redistributing practices."
	var bench := zone_root.find_child("shrine_prayer", true, false) as Node3D
	if bench == null or player.global_position.distance_to(bench.global_position) > 3.5:
		return "Stand beside Greyfen's shrine bench, then open Growth."
	return ""

func _redistribute_practices() -> void:
	var reason := _respec_unavailable_reason()
	if reason != "":
		_finish_preparation_operation({"ok": false, "operation": "respec", "message": reason})
		return
	preparation_action_in_progress = true
	var result: Dictionary = progression.respec_result()
	preparation_action_in_progress = false
	_finish_preparation_operation(result)

func _use_quick_item(item_id: String) -> void:
	preparation_action_in_progress = true
	var result: Dictionary = _use_inventory_item(item_id)
	preparation_action_in_progress = false
	var ok: bool = bool(result.get("ok", false))
	hud.post_notice(str(result.get("message", "")), "inventory" if ok else "error", 3.5, "quick:" + item_id)
	if ok:
		_refresh_equipment_readout()
		story_save_pending = true
		_host.call_deferred("_persist_story_action")

func _finish_preparation_operation(result: Dictionary, vendor_id: String = "") -> void:
	if bool(result.get("ok", false)):
		_refresh_equipment_readout()
		story_save_pending = true
		_host.call_deferred("_persist_story_action")
	# Let the currently pressed control finish its event before rebuilding it.
	var screen_key: String = hud.preparation_screen_key()
	_host.call_deferred("_refresh_preparation_after_operation", result, vendor_id, screen_key)
	inventory_operation_completed.emit(result)

func _refresh_preparation_after_operation(result: Dictionary, vendor_id: String, screen_key: String) -> void:
	if resource_shutdown_prepared or hud == null:
		return
	if screen_key == "" or hud.preparation_screen_key() != screen_key:
		hud.post_notice(str(result.get("message", result.get("reason", ""))), "inventory" if bool(result.get("ok", false)) else "error", 3.5)
		return
	_update_preparation_context()
	if vendor_id == "":
		hud.show_inventory(inventory, quests, story_state, progression)
	else:
		hud.show_vendor(vendor_id, vendor_service, inventory, quests, story_state)
	if not hud.show_preparation_result(result):
		hud.post_notice(str(result.get("message", result.get("reason", ""))), "inventory" if bool(result.get("ok", false)) else "error", 3.5)

func _purchase_from_vendor(vendor_id: String, item_id: String, quantity: int = 1) -> void:
	if vendor_service == null:
		return
	var result: Dictionary
	preparation_action_in_progress = true
	if item_id == "__emergency_arrows__":
		result = vendor_service.claim_emergency_arrow_refill(vendor_id, inventory)
	elif item_id == "__emergency_healing__":
		result = vendor_service.claim_emergency_healing_refill(vendor_id, inventory)
	else:
		result = vendor_service.buy(vendor_id, item_id, quantity, inventory, story_state, quests)
	preparation_action_in_progress = false
	audio.play_event("ui")
	_finish_preparation_operation(result, vendor_id)

func _sell_to_vendor(vendor_id: String, item_id: String, quantity: int) -> void:
	if vendor_service == null or inventory == null or not game_started: return
	preparation_action_in_progress = true
	var result: Dictionary = vendor_service.sell(vendor_id,item_id,quantity,inventory)
	preparation_action_in_progress = false
	_finish_preparation_operation(result,vendor_id)
