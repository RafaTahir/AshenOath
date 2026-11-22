extends "res://scripts/hud/hud_component.gd"
## Combat feedback: explicit view operations; requests leave through typed signals.

func _on_honor_changed(entry: Dictionary) -> void:
	toast("Honor %s%d: %s" % ["+" if int(entry.delta) >= 0 else "", int(entry.delta), str(entry.text)], 5.0)

func _gameplay_surface_blocked() -> bool:
	return loading_armed or _dialogue_review_open or (menu_layer != null and menu_layer.visible) or (dialogue_layer != null and dialogue_layer.visible) or (inventory_layer != null and inventory_layer.visible)

func _on_hud_surface_visibility_changed() -> void:
	if hud_root == null:
		return
	var blocked := _gameplay_surface_blocked()
	hud_root.visible = not blocked
	if not blocked:
		view.call_deferred("_present_pending_journey_return")
	if blocked:
		clear_ambient_subtitle(_ambient_owner)
		raw_hint = ""
		_hint_remaining = 0.0
		_status_remaining = 0.0
		hint_label.visible = false
		status_label.visible = false
		if hint_tween != null and hint_tween.is_valid():
			hint_tween.kill()
		if status_tween != null and status_tween.is_valid():
			status_tween.kill()
	else:
		prompt_label.visible = raw_prompt != ""
		prompt_back.visible = prompt_label.visible
	_present_notice()
	_update_process_policy()

func _draw_resource_attention(seconds: float = 4.0) -> void:
	_attention_remaining = maxf(_attention_remaining, seconds)
	_refresh_resource_attention()
	_update_process_policy()

func _refresh_resource_attention() -> void:
	if vitals_back == null or vitals_warning_label == null:
		return
	var low_health := last_health > 0.0 and last_health / maxf(last_health_max, 1.0) <= 0.28
	var spent: bool = last_stamina <= 0.0
	vitals_warning_label.text = "Low health · stamina spent" if low_health and spent else ("Low health" if low_health else ("Stamina spent — let it recover" if spent else ""))
	var emphasized := _attention_remaining > 0.0 or low_health or spent
	vitals_back.color = Color(0.008, 0.012, 0.015, 0.94 if high_contrast else (0.12 if emphasized else 0.0))
	vitals_warning_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68) if high_contrast else Color(0.96, 0.74, 0.50))

func update_health(current: float, maximum: float) -> void:
	if current == last_health and maximum == last_health_max and health_bar.value == current and health_bar.max_value == maximum and health_value_label.text == "%d / %d" % [int(round(current)), int(round(maximum))]:
		return
	var previous = last_health
	last_health = current
	last_health_max = maximum
	health_bar.max_value = maximum
	health_bar.value = current
	health_value_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current < previous:
		_flash_bar(health_bar, Color(1.0, 0.32, 0.22))
		_draw_resource_attention(5.0)
	elif current > previous:
		_flash_bar(health_bar, Color(0.78, 0.24, 0.16))
		_draw_resource_attention(3.0)
	_refresh_resource_attention()
	_update_process_policy()

func update_stamina(current: float, maximum: float) -> void:
	if current == last_stamina and maximum == last_stamina_max and stamina_bar.value == current and stamina_bar.max_value == maximum and stamina_value_label.text == "%d / %d" % [int(round(current)), int(round(maximum))]:
		return
	var previous = last_stamina
	last_stamina = current
	last_stamina_max = maximum
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_value_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current < previous - 5.0:
		_flash_bar(stamina_bar, Color(1.0, 0.75, 0.22))
		_draw_resource_attention(3.0)
	_refresh_resource_attention()

func update_progression(model: Dictionary) -> void:
	if xp_label == null or xp_bar == null:
		return
	if model == _last_progression_model:
		return
	_last_progression_model = model.duplicate(true)
	var capped: bool = int(model.get("level", 1)) >= int(model.get("cap", 20))
	xp_label.text = "Lv %d | %d Marks\n%s" % [int(model.get("level", 1)), int(model.get("marks", 0)), "Level cap reached" if capped else "%d / %d XP" % [int(model.get("current", 0)), int(model.get("needed", 200))]]
	xp_label.tooltip_text = "%d total XP. Growth and practices are in the journal." % int(model.get("xp", 0))
	xp_bar.max_value = maxf(1.0, float(model.get("needed", 200)))
	xp_bar.value = xp_bar.max_value if capped else float(model.get("current", 0))

func show_enemy(name: String, current: float, maximum: float) -> void:
	enemy_label.text = "Target: %s" % name
	enemy_bar.max_value = maximum
	enemy_bar.value = current
	enemy_value_label.text = "%d / %d" % [int(round(max(current, 0.0))), int(round(maximum))]
	enemy_bar.visible = current > 0.0
	enemy_label.visible = current > 0.0
	enemy_value_label.visible = current > 0.0
	if current > 0.0:
		_draw_resource_attention(4.0)
		if enemy_hide_tween != null and enemy_hide_tween.is_running():
			enemy_hide_tween.kill()
		enemy_hide_tween = view.create_tween()
		enemy_hide_tween.tween_interval(5.0)
		enemy_hide_tween.tween_callback(hide_enemy)

func hide_enemy() -> void:
	enemy_bar.visible = false
	enemy_label.visible = false
	enemy_value_label.visible = false

func set_target_lock_status(enemy_name: String, distance: float) -> void:
	if target_status_label == null:
		return
	var text := "Locked · %s · %d m" % [enemy_name, int(round(distance))]
	if target_status_label.text != text:
		target_status_label.text = text
	target_status_label.visible = true

func clear_target_lock_status() -> void:
	if target_status_label != null:
		target_status_label.visible = false

func toast(text: String, seconds: float = 2.15) -> void:
	post_notice(text, "info", seconds, "")

func post_notice(text: String, category: String = "info", duration: float = 3.0, dedupe_key: String = "") -> void:
	var key := dedupe_key if dedupe_key != "" else category + ":" + text.strip_edges()
	if not _notice_active.is_empty() and str(_notice_active.get("key", "")) == key:
		_notice_active["text"] = text
		_notice_remaining = maxf(_notice_remaining, duration)
		_present_notice()
		return
	if not _notice_active.is_empty() and notices.priority(category) > int(_notice_active.get("priority", 0)):
		notices.push(str(_notice_active.text), str(_notice_active.category), _notice_remaining, str(_notice_active.key))
		_notice_active.clear()
	notices.push(text, category, duration, key)
	_advance_notices(0.0)
	_update_process_policy()

func _advance_notices(delta: float) -> void:
	var reading := dialogue_layer != null and (dialogue_layer.visible or _dialogue_review_open)
	var menu_open := (menu_layer != null and menu_layer.visible) or (inventory_layer != null and inventory_layer.visible)
	if menu_open and str(_notice_active.get("category", "")) == "combat":
		_notice_active.clear()
	if reading:
		if str(_notice_active.get("category", "")) == "combat":
			_notice_active.clear()
		if toast_label != null:
			toast_label.visible = false
		if notice_back != null:
			notice_back.visible = false
		if notice_category_label != null:
			notice_category_label.visible = false
		return
	if toasts_suppressed and not _notice_active.is_empty() and str(_notice_active.get("category", "")) not in ["error", "unavailable"]:
		return
	if not _notice_active.is_empty():
		_notice_remaining -= delta
		if _notice_remaining <= 0.0:
			_notice_active.clear()
	if _notice_active.is_empty():
		_notice_active = notices.take(false, toasts_suppressed, menu_open)
		if not _notice_active.is_empty():
			_notice_remaining = float(_notice_active.duration)
	_present_notice()
	_update_process_policy()

func _present_notice() -> void:
	if toast_label == null:
		return
	var text := str(_notice_active.get("text", ""))
	var menu_open := (menu_layer != null and menu_layer.visible) or (inventory_layer != null and inventory_layer.visible)
	var reading := dialogue_layer != null and (dialogue_layer.visible or _dialogue_review_open)
	var may_show := not toasts_suppressed or str(_notice_active.get("category", "")) in ["error", "unavailable"]
	toast_label.visible = text != "" and not menu_open and not reading and may_show
	toast_label.text = text
	var notice_alpha := 1.0
	if not reduced_motion and not flash_reduction and not _notice_active.is_empty():
		var duration := float(_notice_active.get("duration", 2.2))
		notice_alpha = minf(smoothstep(0.0, 0.20, duration - _notice_remaining), smoothstep(0.0, 0.30, _notice_remaining))
	toast_label.modulate = Color(1, 1, 1, notice_alpha)
	if notice_category_label != null:
		var category := str(_notice_active.get("category", "info"))
		notice_category_label.text = str({"story":"Story", "inventory":"Supplies", "save":"Saved", "error":"Unable to complete", "unavailable":"Unavailable", "combat":"In the fight", "info":"On the road"}.get(category, "On the road"))
		notice_category_label.visible = toast_label.visible
		notice_category_label.modulate.a = notice_alpha
	if notice_back != null:
		notice_back.visible = toast_label.visible
		notice_back.modulate.a = notice_alpha
	if inventory_notice_label != null:
		inventory_notice_label.text = text if inventory_layer.visible and not reading else ""
		inventory_notice_label.tooltip_text = text
		if inventory_layer.visible and not reading and str(_notice_active.get("category", "")) not in ["error", "unavailable"]:
			_present_preparation_notice()
	if is_instance_valid(_menu_notice):
		_menu_notice.text = text
		_menu_notice.visible = text != "" and not reading
		_menu_notice.add_theme_color_override("font_color", Color(1.0, 0.78, 0.53) if str(_notice_active.get("category", "")) in ["error", "unavailable"] else Color(0.86, 0.83, 0.70))
	_refresh_touch_message_visibility()

func set_toasts_suppressed(suppressed: bool) -> void:
	toasts_suppressed = suppressed
	_present_notice()
	_update_process_policy()

func set_guidance_hint(text: String, seconds: float = 4.5) -> void:
	raw_hint = "" if _gameplay_surface_blocked() else text
	hint_label.text = _format_input_text(text)
	hint_label.visible = raw_hint != ""
	hint_label.modulate = Color(1, 1, 1, 1)
	if hint_tween != null and hint_tween.is_running():
		hint_tween.kill()
	_hint_remaining = maxf(seconds, 2.2) if raw_hint != "" else 0.0
	_refresh_touch_message_visibility()
	_update_process_policy()

func show_status_cue(text: String, kind: String = "neutral") -> void:
	if _gameplay_surface_blocked() or text.strip_edges() == "":
		return
	var priority := int({"neutral":0, "hurt":1, "item":2, "block":2, "stamina":3, "parry":3, "danger":4, "victory":4}.get(kind, 1))
	if _status_remaining > 0.7 and priority < _status_priority:
		return
	if _status_remaining > 0.0 and status_label.text == text and kind == _status_kind:
		return
	_status_kind = kind
	_status_priority = priority
	_status_remaining = 1.8 if priority >= 3 else 1.35
	status_label.text = text
	status_label.visible = true
	status_label.modulate = _status_color(kind)
	if status_tween != null and status_tween.is_running():
		status_tween.kill()
	_draw_resource_attention(3.0)
	_refresh_touch_message_visibility()

func update_equipment(potions: int, bombs: int, oil_name: String, arrow_count: int = -1, arrow_type: String = "Standard", weapon_name: String = "Steel", remedy_id: String = "redroot_potion", tool_id: String = "ash_bomb", oil_seconds: int = -1) -> void:
	var view_key: Array = [potions, bombs, oil_name, arrow_count, arrow_type, weapon_name, remedy_id, tool_id, oil_seconds, input_device, _action_label("use_potion"), _action_label("throw_bomb"), _action_label("fire_bow"), _action_label("light_attack"), _action_label("block"), _action_label("dodge"), _action_label("open_inventory")]
	if view_key == _equipment_view_key:
		return
	_equipment_view_key = view_key
	var supplies_changed := potions != last_potions or bombs != last_bombs or arrow_count != last_arrow_count or oil_name != last_oil_name
	last_potions = potions
	last_bombs = bombs
	last_oil_name = oil_name
	last_oil_seconds = oil_seconds
	last_arrow_count = arrow_count
	last_arrow_type = arrow_type
	last_weapon_name = weapon_name
	last_remedy_id = remedy_id
	last_tool_id = tool_id
	var oil_text = oil_name if oil_name != "" else "No oil"
	if oil_name != "" and oil_seconds >= 0:
		oil_text += " %d:%02d" % [floori(float(oil_seconds) / 60.0), oil_seconds % 60]
	equipment_label.text = weapon_name + " | " + oil_text
	equipment_label.tooltip_text = "Selected weapon: %s. Active blade oil: %s" % [weapon_name, oil_text]
	if supply_labels.has("potions"):
		(supply_labels["potions"] as Label).text = "Bitterleaf" if remedy_id == "bitterleaf_tonic" else "Redroot"
		(supply_labels["bombs"] as Label).text = "Iron Trap" if tool_id == "iron_trap" else "Ash Bomb"
		_set_quick_motif("potions", "tonic" if remedy_id == "bitterleaf_tonic" else "potions")
		_set_quick_motif("bombs", "trap" if tool_id == "iron_trap" else "bombs")
		(supply_labels["arrows"] as Label).text = arrow_type
		(supply_labels["arrows"] as Label).tooltip_text = arrow_type + " arrows"
		(_quick_bindings["potions"] as Label).text = _action_label("use_potion")
		(_quick_bindings["bombs"] as Label).text = _action_label("throw_bomb")
		(_quick_bindings["arrows"] as Label).text = _action_label("fire_bow").replace("Left Mouse", "LMB").replace("LeftMouse", "LMB").replace("Right Mouse", "RMB").replace("RightMouse", "RMB")
		_gameplay_bindings.text = "%s  Strike\n%s  Guard\n%s  Dodge\n%s  Journal" % [_action_label("light_attack"), _action_label("block"), _action_label("dodge"), _action_label("open_inventory")]
		(supply_counts["potions"] as Label).text = str(maxi(potions, 0))
		(supply_counts["bombs"] as Label).text = str(maxi(bombs, 0))
		(supply_counts["arrows"] as Label).text = str(arrow_count) if arrow_count >= 0 else "—"
	if supplies_changed:
		_draw_resource_attention(3.5)

func _set_quick_motif(slot: String, motif: String) -> void:
	var icon: Control = _quick_icons[slot]
	if str(icon.get_meta("quick_motif", slot)) != motif:
		icon.set_meta("quick_motif", motif)
		icon.call("configure", motif, high_contrast)

func mark_stamina_exhausted() -> void:
	_flash_bar(stamina_bar, Color(1.0, 0.32, 0.16))
	show_status_cue("Stamina spent", "stamina")

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(hud_root)
	vitals_back = ColorRect.new()
	vitals_back.name = "VitalityShadow"
	vitals_back.color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(vitals_back)
	vitals_box = VBoxContainer.new()
	vitals_box.visible = false
	hud_root.add_child(vitals_box)
	_hart_emblem = HudEmblem.new()
	_hart_emblem.name = "HartMedallion"
	_hart_emblem.call("configure", "hart", high_contrast)
	hud_root.add_child(_hart_emblem)
	health_bar = ProgressBar.new()
	health_bar.name = "BloodRibbon"
	health_bar.max_value = 125
	health_bar.value = 125
	health_bar.show_percentage = false
	hud_root.add_child(health_bar)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaRibbon"
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	hud_root.add_child(stamina_bar)
	xp_bar = ProgressBar.new()
	xp_bar.name = "ExperienceRibbon"
	xp_bar.max_value = 200
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_back := StyleBoxFlat.new()
	xp_back.bg_color = Color(0.04, 0.06, 0.07, 0.85)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.58, 0.78, 0.72)
	xp_bar.add_theme_stylebox_override("background", xp_back)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	hud_root.add_child(xp_bar)
	xp_label = _hud_label(hud_root, "ExperienceLevel", 16)
	xp_label.max_lines_visible = 2
	xp_label.text = "Lv 1 | 0 Marks\n0 / 200 XP"
	health_value_label = _hud_label(hud_root, "BloodValue", 16)
	health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_value_label = _hud_label(hud_root, "StaminaValue", 16)
	stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var blood_name: Label = _hud_label(hud_root, "BloodCaption", 16)
	blood_name.text = "BLOOD"
	var stamina_name: Label = _hud_label(hud_root, "StaminaCaption", 16)
	stamina_name.text = "STAMINA"
	_bar_name_labels = [blood_name, stamina_name]
	vitals_warning_label = _hud_label(hud_root, "ResourceCondition", 16)
	vitals_warning_label.max_lines_visible = 1
	supplies_grid = GridContainer.new()
	supplies_grid.name = "QuickSupplies"
	supplies_grid.columns = 3
	hud_root.add_child(supplies_grid)
	for id: String in ["potions", "bombs", "arrows"]:
		var slot: Control = Control.new()
		slot.name = id.capitalize() + "QuickSlot"
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		supplies_grid.add_child(slot)
		_quick_slots[id] = slot
		var icon: Control = HudEmblem.new()
		icon.call("configure", id, high_contrast)
		slot.add_child(icon)
		_quick_icons[id] = icon
		var count: Label = _hud_label(slot, id + "Count", 18)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		supply_counts[id] = count
		var item: Label = _hud_label(slot, id + "Name", 16)
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.max_lines_visible = 1
		supply_labels[id] = item
		var binding: Label = _hud_label(slot, id + "Binding", 16)
		binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		binding.max_lines_visible = 2
		_quick_bindings[id] = binding
	equipment_label = _hud_label(hud_root, "ActiveBladeOil", 16)
	equipment_label.max_lines_visible = 1
	_gameplay_bindings = _hud_label(hud_root, "CurrentControlHints", 16)
	_gameplay_bindings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gameplay_bindings.max_lines_visible = 4
	_navigation_dial = HudNavigationDial.new()
	_navigation_dial.name = "RoadNavigator"
	_navigation_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_navigation_dial)
	_pointer_pause_button = Button.new()
	_pointer_pause_button.name = "GameplayPause"
	_pointer_pause_button.text = "II"
	_pointer_pause_button.tooltip_text = "Pause"
	_pointer_pause_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_pointer_pause_button.pressed.connect(func(): pause_requested.emit())
	_style_button(_pointer_pause_button)
	hud_root.add_child(_pointer_pause_button)
	_world_clock_label = _hud_label(hud_root, "WorldClock", 16)
	_world_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_clock_label.max_lines_visible = 1
	_world_clock_label.text = _world_clock_text
	tracker_back = ColorRect.new()
	tracker_back.name = "ObjectiveShadow"
	(tracker_back as ColorRect).color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(tracker_back)
	tracker_title_label = _hud_label(hud_root, "TrackedStoryTitle", 18)
	tracker_title_label.max_lines_visible = 2
	tracker_caption_label = _hud_label(hud_root, "NextStepCaption", 16)
	tracker_caption_label.visible = false
	_quest_rule = ColorRect.new()
	_quest_rule.color = Color(0.69, 0.61, 0.4, 0.62)
	hud_root.add_child(_quest_rule)
	_quest_marker = _hud_label(hud_root, "ObjectiveMarker", 16)
	_quest_marker.text = "◆"
	tracker_label = _hud_label(hud_root, "QuestTrackerObjective", 20)
	tracker_label.max_lines_visible = -1
	tracker_route_label = _hud_label(hud_root, "StoryRouteHint", 16)
	tracker_route_label.max_lines_visible = 2
	tracker_work_label = _hud_label(hud_root, "NearbyStoryWork", 16)
	tracker_work_label.max_lines_visible = 2
	tracker_footer_label = _hud_label(hud_root, "JournalBinding", 16)
	tracker_footer_label.max_lines_visible = 1
	compass_back = ColorRect.new()
	compass_back.color = Color(0.01, 0.012, 0.014, 0.0)
	hud_root.add_child(compass_back)
	compass_label = _hud_label(hud_root, "CurrentLocation", 16)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compass_label.max_lines_visible = 1
	enemy_label = _hud_label(hud_root, "EnemyFocusLabel", 18)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.max_lines_visible = 1
	enemy_label.visible = false
	enemy_bar = ProgressBar.new()
	enemy_bar.name = "EnemyVitalityRibbon"
	enemy_bar.show_percentage = false
	enemy_bar.visible = false
	hud_root.add_child(enemy_bar)
	enemy_value_label = _hud_label(hud_root, "EnemyVitalityValue", 16)
	enemy_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_value_label.visible = false
	target_status_label = _hud_label(hud_root, "TargetLockStatus", 16)
	target_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_status_label.visible = false
	prompt_back = ColorRect.new()
	prompt_back.name = "InteractionShadow"
	prompt_back.color = Color(0.01, 0.012, 0.014, 0.24)
	prompt_back.visible = false
	hud_root.add_child(prompt_back)
	prompt_label = _hud_label(hud_root, "InteractionPrompt", 20)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.max_lines_visible = 2
	prompt_label.visible = false
	notice_back = ColorRect.new()
	notice_back.name = "NoticeShadow"
	notice_back.color = Color(0.01, 0.012, 0.014, 0.2)
	notice_back.visible = false
	hud_root.add_child(notice_back)
	notice_category_label = _hud_label(hud_root, "NoticeCategory", 16)
	notice_category_label.visible = false
	toast_label = _hud_label(hud_root, "StoryNotice", 20)
	toast_label.max_lines_visible = 3
	toast_label.visible = false
	hint_label = _hud_label(hud_root, "ContextualCombatHint", 16)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.max_lines_visible = 2
	hint_label.visible = false
	status_label = _hud_label(hud_root, "CombatStatusCue", 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	for node: Node in hud_root.get_children():
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_equipment(0, 0, "", -1)
	_refresh_story_focus()

func _labeled_bar(label_text: String, bar: ProgressBar, value_label: Label) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(58, 20)
	label.add_theme_font_size_override("font_size", 12)
	_bar_name_labels.append(label)
	row.add_child(label)
	bar.custom_minimum_size = Vector2(122, 16)
	row.add_child(bar)
	value_label.text = "%d / %d" % [int(bar.value), int(bar.max_value)]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(72, 20)
	value_label.add_theme_font_size_override("font_size", 12)
	row.add_child(value_label)
	return row

func _flash_bar(bar: ProgressBar, color: Color) -> void:
	if flash_reduction or reduced_motion:
		return
	var previous := _bar_tweens.get(bar) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	bar.modulate = color
	var tween = view.create_tween()
	_bar_tweens[bar] = tween
	tween.tween_property(bar, "modulate", Color.WHITE, 0.18)

func _status_color(kind: String) -> Color:
	if high_contrast:
		return Color(1.0, 0.96, 0.84)
	if kind == "parry":
		return Color(0.66, 0.88, 1.0, 1.0)
	if kind == "block" or kind == "stamina":
		return Color(1.0, 0.74, 0.28, 1.0)
	if kind == "hurt":
		return Color(1.0, 0.34, 0.22, 1.0)
	if kind == "victory":
		return Color(0.76, 0.90, 0.58, 1.0)
	if kind == "item":
		return Color(0.82, 0.70, 0.45, 1.0)
	return Color(0.86, 0.81, 0.69, 1.0)
