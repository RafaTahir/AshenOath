extends "res://scripts/hud/hud_component.gd"
## Hud lifecycle: explicit view operations; requests leave through typed signals.
var _gameplay_ui_step := 0

func set_runtime_services(owner: Node, saves: Node) -> void:
	_game_owner = owner
	_settings_source = owner.get("settings") if is_instance_valid(owner) else null
	_save_manager = saves
	_save_service()
	if is_instance_valid(_honor_source) and _honor_source.honor_changed.is_connected(_on_honor_changed):
		_honor_source.honor_changed.disconnect(_on_honor_changed)
	_honor_source = owner.get("story_state") if is_instance_valid(owner) else null
	if is_instance_valid(_honor_source) and not _honor_source.honor_changed.is_connected(_on_honor_changed):
		_honor_source.honor_changed.connect(_on_honor_changed)

func initialize_view() -> void:
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_ambient_subtitles()
	var bow_sight := preload("res://scripts/bow_reticle.gd").new()
	bow_sight.hud = view
	hud_root.add_child(bow_sight)
	_build_menu_layer()
	# Stable surface identities keep menu/input ownership valid while their
	# gameplay-only content waits for the pre-control preparation boundary.
	dialogue_layer = PanelContainer.new()
	dialogue_layer.name = "DialogueLowerThird"
	dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_layer.hide()
	view.add_child(dialogue_layer)
	inventory_layer = PanelContainer.new()
	inventory_layer.hide()
	view.add_child(inventory_layer)
	_build_loading_layer()
	for surface: Control in [menu_layer, dialogue_layer, inventory_layer, loading_layer]:
		surface.visibility_changed.connect(_on_hud_surface_visibility_changed)
	_apply_theme()
	apply_accessibility(_current_settings())
	if not view.get_viewport().size_changed.is_connected(_on_viewport_resized):
		view.get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_hud_layout()
	_on_hud_surface_visibility_changed()
	_update_process_policy()

func prepare_gameplay_ui() -> void:
	while not _gameplay_ui_ready:
		_prepare_gameplay_ui_step()

func prepare_gameplay_ui_async(keep_preparing: Callable) -> bool:
	while not _gameplay_ui_ready:
		await view.get_tree().process_frame
		if not keep_preparing.call():
			return false
		_prepare_gameplay_ui_step()
	return bool(keep_preparing.call())

func _prepare_gameplay_ui_step() -> void:
	match _gameplay_ui_step:
		0: _build_dialogue()
		1: _build_inventory()
		2: _apply_theme()
		3: apply_accessibility(_current_settings())
		4:
			_apply_hud_layout()
			_gameplay_ui_ready = true
	_gameplay_ui_step += 1

func advance_view(delta: float) -> void:
	if health_bar == null:
		return
	_advance_notices(delta)
	if _ambient_remaining > 0.0:
		_ambient_remaining = maxf(0.0, _ambient_remaining - delta)
		if _ambient_remaining <= 0.0 or _gameplay_surface_blocked() or view.get_tree().paused:
			clear_ambient_subtitle(_ambient_owner)
	if loading_armed and loading_layer != null and not loading_layer.visible:
		loading_elapsed += delta
		if loading_elapsed >= 0.75:
			loading_layer.visible = true
			_update_process_policy()
	if _attention_remaining > 0.0:
		_attention_remaining = maxf(0.0, _attention_remaining - delta)
		if _attention_remaining <= 0.0:
			_refresh_resource_attention()
	if _hint_remaining > 0.0:
		_hint_remaining = maxf(0.0, _hint_remaining - delta)
		if _hint_remaining <= 0.0:
			raw_hint = ""
			hint_label.visible = false
	if _status_remaining > 0.0:
		_status_remaining = maxf(0.0, _status_remaining - delta)
		if _status_remaining <= 0.0:
			status_label.visible = false
	_refresh_touch_message_visibility()
	_update_process_policy()

func _update_process_policy() -> void:
	if health_bar == null:
		return
	var loading_delay_active := loading_armed and loading_layer != null and not loading_layer.visible
	view.set_process(_ambient_remaining > 0.0 or loading_delay_active or notices.has_pending() or not _notice_active.is_empty() or _attention_remaining > 0.0 or _hint_remaining > 0.0 or _status_remaining > 0.0)
