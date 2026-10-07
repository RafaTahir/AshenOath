extends Node
class_name EquipmentLoadout

## State/visibility owner for Kael's weapon presentation.
## Physics, animation, and bone transforms remain owned by the controller and
## imported skeleton; this node makes the equipment state deterministic and
## saveable without adding another transform authority.

signal changed

const BLADE_IDS := ["steel", "oathblade"]

var active_weapon := "sword"
var selected_blade_id := "steel"
var sword_drawn := false
var bow_aiming := false
var selected_arrow_id := "standard_arrow"
var nodes: Dictionary = {}

func bind_node(slot: String, node: Node) -> void:
	if node == null:
		nodes.erase(slot)
	else:
		nodes[slot] = node
	apply_visibility()

func set_active_weapon(value: String) -> void:
	var next := "bow" if value.to_lower() == "bow" else "sword"
	if active_weapon == next:
		apply_visibility()
		return
	active_weapon = next
	sword_drawn = false
	bow_aiming = false
	emit_changed()

func select_blade(value: String) -> void:
	selected_blade_id = normalized_blade_id(value)
	active_weapon = "sword"
	bow_aiming = false
	emit_changed()

static func normalized_blade_id(value: String) -> String:
	return value.to_lower() if value.to_lower() in BLADE_IDS else "steel"

func selected_weapon_name() -> String:
	if active_weapon == "bow":
		return "Bow"
	return "Oathblade" if selected_blade_id == "oathblade" else "Steel"

func set_sword_drawn(value: bool) -> void:
	sword_drawn = value
	if value:
		active_weapon = "sword"
		bow_aiming = false
	emit_changed()

func set_bow_aiming(value: bool) -> void:
	bow_aiming = value and active_weapon == "bow"
	apply_visibility()

func set_selected_arrow(value: String) -> void:
	selected_arrow_id = value if value != "" else "standard_arrow"
	emit_changed()

func save_state() -> Dictionary:
	return {
		"schema_version": 2,
		"active_weapon": active_weapon,
		"selected_blade_id": selected_blade_id,
		"sword_drawn": sword_drawn,
		"bow_aiming": false,
		"selected_arrow_id": selected_arrow_id,
	}

func load_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	active_weapon = "bow" if str(data.get("active_weapon", "sword")).to_lower() == "bow" else "sword"
	selected_blade_id = normalized_blade_id(str(data.get("selected_blade_id", "steel")))
	sword_drawn = bool(data.get("sword_drawn", false)) and active_weapon == "sword"
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
		bow.visible = active_weapon == "bow"
	if quiver != null and is_instance_valid(quiver):
		quiver.visible = active_weapon == "bow"

func emit_changed() -> void:
	apply_visibility()
	changed.emit()

func _set_slot_visible(slot: String, value: bool) -> void:
	var node: Node3D = nodes.get(slot) as Node3D
	if is_instance_valid(node):
		node.visible = value
