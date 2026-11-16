extends "res://scripts/hud/hud_component.gd"
func show_vendor(vendor_id: String, vendor_service: Variant, inventory: Variant, quests: Variant = null, story_state: Variant = null) -> void:
	prepare_gameplay_ui()
	_capture_inventory_state()
	_evidence_position_key = ""
	_inventory_screen = "vendor:" + vendor_id
	_inventory_generation += 1
	_vendor_context = {"id":vendor_id, "service":vendor_service, "inventory":inventory, "quests":quests, "state":story_state}
	_set_ui_pointer("journal")
	inventory_layer.visible = true
	_prepare_inventory_surface(true)
	var vendor: Dictionary = vendor_service.get_vendor(vendor_id)
	var heading: String = "%s\n%s\nCoin: %d\n\n" % [str(vendor.get("name", "Vendor")).to_upper(), str(vendor.get("subtitle", "")), int(inventory.coin)]
	var selection: Dictionary = _preparation_selection.get(_inventory_screen, {})
	var display: Dictionary = vendor_service.presentation(vendor_id, str(selection.get("id", "")), inventory, story_state, quests)
	var selected_id: String = str(display.selected_id)
	_preparation_selection[_inventory_screen] = {"kind": "item", "id": selected_id}
	inventory_text.text = heading + "Supplies and fittings"
	if selected_id != "":
		var quote: Dictionary = display.quote
		var received_id: String = str(quote.get("item_id", selected_id))
		var preparation_progression: Variant = _journal_context.get("progression")
		if is_instance_valid(_game_owner):
			preparation_progression = _game_owner.get("progression") if is_instance_valid(_game_owner) else null
		var detail: Dictionary = PreparationViewModel.item_detail(received_id, inventory, preparation_progression, _preparation_context, story_state, quests)
		detail["actions"] = []
		inventory_text.text = heading + PreparationPanel.item_text(detail) + "\n" + PreparationPanel.purchase_text(quote)
		var buy: Button = _preparation_button(str(display.purchase_label), "action:buy:" + selected_id, _preparation_actions, bool(quote.get("ok", false)))
		buy.pressed.connect(func(id_value: String = selected_id) -> void: vendor_purchase_requested.emit(vendor_id, id_value, 1))
		if bool(display.bundle):
			var bundle: Button = _preparation_button("Buy 5 · %d coin" % int(display.bundle_price), "action:buy5:" + selected_id, _preparation_actions)
			bundle.pressed.connect(func(id_value: String = selected_id) -> void: vendor_purchase_requested.emit(vendor_id, id_value, 5))
	_add_preparation_heading("SUPPLIES AND SERVICES")
	for entry: Dictionary in display.entries:
		var request_id: String = str(entry.id)
		var title: String = str(entry.title)
		var entry_button: Button = _preparation_button(title, "item:" + request_id, craft_buttons)
		entry_button.toggle_mode = true
		entry_button.button_pressed = selected_id == request_id
		entry_button.pressed.connect(func(id_value: String = request_id) -> void: _select_preparation_entry("item", id_value))
	var surplus: Array = display.surplus
	if not surplus.is_empty():
		_add_preparation_heading("SELL SURPLUS · ROAD RESERVES RETAINED")
		for offer: Dictionary in surplus:
			var item_id: String = str(offer.item_id)
			var sale: Variant = _preparation_button("Sell 1 %s · +%d coin" % [inventory.get_item_name(item_id),int(offer.unit_price)],"action:sell:"+item_id,craft_buttons)
			sale.tooltip_text = str(offer.message)
			sale.pressed.connect(func(id_value: String = item_id) -> void: vendor_sale_requested.emit(vendor_id,id_value,1))
	_add_preparation_close()
	_queue_responsive_layout()
	view.call_deferred("_restore_inventory_state", _inventory_screen, _inventory_generation)
