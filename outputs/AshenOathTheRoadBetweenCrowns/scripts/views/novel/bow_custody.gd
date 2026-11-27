extends Node
## Inventory continues to own the arrows and fittings. StoryState records which
## physical bow is available and survives restoring either side of the crossing.
var player: Node
var state: Node

static func bind(actor: Node, story: Node) -> void:
	var custody: Node = actor.get_node_or_null("BowCustody")
	if custody == null:
		custody = new()
		custody.name = "BowCustody"
		custody.player = actor
		actor.add_child(custody)
	custody.observe(story)

func observe(story: Node) -> void:
	if state != story:
		if is_instance_valid(state) and state.changed.is_connected(_sync): state.changed.disconnect(_sync)
		state = story
		state.changed.connect(_sync)
	_sync()

func _sync() -> void:
	var gear: EquipmentLoadout = player.equipment_loadout
	var available: bool = state.get_flag("novel_edition",0) != 1 or not state.get_flag("novel_departure_bow_lost",false) or state.get_flag("novel_departure_spare_bow",false) or state.get_flag("novel_spring_route","") == "open_road"
	if gear.bow_available == available: return
	gear.bow_available = available
	if not available:
		player._cancel_bow()
		if gear.requested_weapon == "bow" or gear.active_weapon == "bow": gear.set_active_weapon("sword")
	gear.emit_changed()

static func hang_spare(rack: Node3D, kael: Node) -> void:
	var bow: Node3D = kael._instantiate_modeled_prop(kael.MODELED_BOW_PATH)
	if bow == null: return
	kael._prepare_modeled_prop(bow,Color(0.24,0.12,0.055))
	rack.add_child(bow)
	bow.position = Vector3(0.14,0.68,0.12)
	bow.scale = Vector3.ONE * 0.44
	bow.rotation_degrees = Vector3(0,-90,17)
