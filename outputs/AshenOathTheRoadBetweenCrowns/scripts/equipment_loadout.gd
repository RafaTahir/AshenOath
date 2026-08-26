extends Node
class_name EquipmentLoadout

## State/visibility owner for Kael's weapon presentation.
## Physics, animation, and bone transforms remain owned by the controller and
## imported skeleton; this node makes the equipment state deterministic and
## saveable without adding another transform authority.

signal changed

var active_weapon := "sword"
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
	if active_weapon == "bow":
		sword_drawn = false
		emit_changed()

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
		"active_weapon": active_weapon,
		"sword_drawn": sword_drawn,
		"bow_aiming": false,
		"selected_arrow_id": selected_arrow_id,
	}

func load_state(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	active_weapon = "bow" if str(data.get("active_weapon", "sword")).to_lower() == "bow" else "sword"
	sword_drawn = bool(data.get("sword_drawn", false)) and active_weapon == "sword"
	bow_aiming = false
	selected_arrow_id = str(data.get("selected_arrow_id", "standard_arrow"))
	if selected_arrow_id == "":
		selected_arrow_id = "standard_arrow"
	apply_visibility()

func apply_visibility() -> void:
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
