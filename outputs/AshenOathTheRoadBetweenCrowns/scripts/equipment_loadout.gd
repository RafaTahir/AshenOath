extends Node
class_name EquipmentLoadout

## State/visibility owner for Kael's weapon presentation.
## Physics, animation, and bone transforms remain owned by the controller and
## imported skeleton; this node makes the equipment state deterministic and
## saveable without adding another transform authority.

signal changed
signal transition_started(action: String, duration: float)
signal transition_finished

const BLADE_IDS := ["steel", "oathblade"]
const DRAW_SECONDS := 0.64
const SHEATH_SECONDS := 0.58
const CONTACT_FRACTION := 0.48

var active_weapon := "sword"
var selected_blade_id := "steel"
var sword_drawn := false
var bow_aiming := false
var bow_drawn := false
var selected_arrow_id := "standard_arrow"
var nodes: Dictionary = {}
var transition := ""
var transition_elapsed := 0.0
var transition_duration := 0.0
var contact_transferred := false
var requested_weapon := "sword"
var requested_blade := "steel"
var requested_drawn := false

func is_transitioning() -> bool:
	return transition != ""

func is_drawn() -> bool:
	return bow_drawn if active_weapon == "bow" else sword_drawn

func transition_progress() -> float:
	return clampf(transition_elapsed / maxf(transition_duration, 0.001), 0.0, 1.0)

func request_loadout(weapon: String, blade: String, drawn: bool = true) -> bool:
	if is_transitioning():
		return false
	requested_weapon = "bow" if weapon == "bow" else "sword"
	requested_blade = normalized_blade_id(blade)
	requested_drawn = drawn
	var same := active_weapon == requested_weapon and (active_weapon == "bow" or selected_blade_id == requested_blade)
	if same and is_drawn() == drawn:
		return false
	bow_aiming = false
	if is_drawn():
		_begin_transition("sheath")
	else:
		_apply_requested_loadout()
	return true

func _begin_transition(action: String) -> void:
	transition = action
	transition_elapsed = 0.0
	transition_duration = DRAW_SECONDS if action == "draw" else SHEATH_SECONDS
	contact_transferred = false
	transition_started.emit(action, transition_duration)

func advance_transition(delta: float) -> void:
	if not is_transitioning():
		return
	transition_elapsed = minf(transition_elapsed + maxf(delta, 0.0), transition_duration)
	if not contact_transferred and transition_progress() >= CONTACT_FRACTION:
		contact_transferred = true
		if active_weapon == "bow":
			bow_drawn = transition == "draw"
		else:
			sword_drawn = transition == "draw"
		emit_changed()
	if transition_elapsed < transition_duration:
		return
	var completed := transition
	transition = ""
	if completed == "sheath":
		_apply_requested_loadout()
	else:
		transition_finished.emit()

func _apply_requested_loadout() -> void:
	active_weapon = requested_weapon
	selected_blade_id = requested_blade
	sword_drawn = false
	bow_drawn = false
	emit_changed()
	if requested_drawn:
		_begin_transition("draw")
	else:
		transition_finished.emit()

func cancel_transition() -> void:
	if not is_transitioning():
		return
	# Keep the contact already reached, never a half-drawn pose or pending switch.
	transition = ""
	transition_elapsed = 0.0
	requested_weapon = active_weapon
	requested_blade = selected_blade_id
	requested_drawn = is_drawn()
	transition_finished.emit()
	emit_changed()

func bind_node(slot: String, node: Node) -> void:
	if node == null:
		nodes.erase(slot)
	else:
		nodes[slot] = node
	apply_visibility()

func set_active_weapon(value: String) -> void:
	cancel_transition()
	var next := "bow" if value.to_lower() == "bow" else "sword"
	if active_weapon == next:
		apply_visibility()
		return
	active_weapon = next
	sword_drawn = false
	bow_drawn = next == "bow"
	bow_aiming = false
	emit_changed()

func select_blade(value: String) -> void:
	cancel_transition()
	selected_blade_id = normalized_blade_id(value)
	active_weapon = "sword"
	bow_drawn = false
	bow_aiming = false
	emit_changed()

static func normalized_blade_id(value: String) -> String:
	return value.to_lower() if value.to_lower() in BLADE_IDS else "steel"

func selected_weapon_name() -> String:
	if active_weapon == "bow":
		return "Bow"
	return "Oathblade" if selected_blade_id == "oathblade" else "Steel"

func set_sword_drawn(value: bool) -> void:
	cancel_transition()
	sword_drawn = value
	if value:
		active_weapon = "sword"
		bow_drawn = false
		bow_aiming = false
	emit_changed()

func set_bow_aiming(value: bool) -> void:
	bow_aiming = value and active_weapon == "bow" and bow_drawn and not is_transitioning()
	apply_visibility()

func set_selected_arrow(value: String) -> void:
	selected_arrow_id = value if value != "" else "standard_arrow"
	emit_changed()

func save_state() -> Dictionary:
	var saved_weapon := requested_weapon if is_transitioning() else active_weapon
	var saved_drawn := requested_drawn if is_transitioning() else is_drawn()
	return {
		"schema_version": 3,
		"active_weapon": saved_weapon,
		"selected_blade_id": requested_blade if is_transitioning() else selected_blade_id,
		"sword_drawn": saved_drawn and saved_weapon == "sword",
		"bow_drawn": saved_drawn and saved_weapon == "bow",
		"bow_aiming": false,
		"selected_arrow_id": selected_arrow_id,
	}

func load_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	cancel_transition()
	active_weapon = "bow" if str(data.get("active_weapon", "sword")).to_lower() == "bow" else "sword"
	selected_blade_id = normalized_blade_id(str(data.get("selected_blade_id", "steel")))
	sword_drawn = bool(data.get("sword_drawn", false)) and active_weapon == "sword"
	bow_drawn = bool(data.get("bow_drawn", true)) and active_weapon == "bow"
	bow_aiming = false
	selected_arrow_id = str(data.get("selected_arrow_id", "standard_arrow"))
	if selected_arrow_id == "":
		selected_arrow_id = "standard_arrow"
	emit_changed()

func apply_visibility() -> void:
	var drawn := active_weapon == "sword" and sword_drawn
	for blade_id: String in BLADE_IDS:
		var in_hand := drawn and selected_blade_id == blade_id
		_set_slot_visible(blade_id + "_hand", in_hand)
		_set_slot_visible(blade_id + "_back", not in_hand)
		_set_slot_visible(blade_id + "_scabbard", true)
	var sword_hand = nodes.get("sword_hand")
	var sword_back = nodes.get("sword_back")
	var bow = nodes.get("bow")
	var quiver = nodes.get("quiver")
	if sword_hand != null and is_instance_valid(sword_hand):
		sword_hand.visible = active_weapon == "sword" and sword_drawn
	if sword_back != null and is_instance_valid(sword_back):
		sword_back.visible = active_weapon == "bow" or not sword_drawn
	if bow != null and is_instance_valid(bow):
		bow.visible = active_weapon == "bow" and bow_drawn
	_set_slot_visible("bow_back", active_weapon != "bow" or not bow_drawn)
	if quiver != null and is_instance_valid(quiver):
		quiver.visible = true

func emit_changed() -> void:
	apply_visibility()
	changed.emit()

func _set_slot_visible(slot: String, value: bool) -> void:
	var node: Node3D = nodes.get(slot) as Node3D
	if is_instance_valid(node):
		node.visible = value
