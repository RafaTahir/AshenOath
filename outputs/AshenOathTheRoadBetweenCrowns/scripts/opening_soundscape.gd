extends Node3D
class_name OpeningSoundscape

## One cheap coordinator owns opening-region accents. It ticks below the frame
## rate and lets AudioManager apply distance attenuation and master volume.
var zone_id := ""
var listener: Node3D
var audio_manager: Node
var zone_root: Node3D
var quality := "balanced"
var _anchors: Dictionary = {}
var _tick_remaining := 0.0

func configure(root: Node3D, id: String, target: Node3D, manager: Node, preset: String = "balanced") -> void:
	zone_root = root
	zone_id = id
	listener = target
	audio_manager = manager
	quality = preset
	_collect_anchors()
	_tick_remaining = 0.15
	set_process(true)

func set_listener(target: Node3D) -> void:
	listener = target

func _process(delta: float) -> void:
	if listener == null or not is_instance_valid(listener) or audio_manager == null or not is_instance_valid(audio_manager):
		return
	_tick_remaining -= delta
	if _tick_remaining > 0.0:
		return
	_collect_anchors()
	if audio_manager.has_method("tick_opening_soundscape"):
		audio_manager.tick_opening_soundscape(zone_id, listener, _anchors, quality)
	_tick_remaining = 0.58 if quality == "potato" else (0.38 if quality == "balanced" else 0.30)

func _collect_anchors() -> void:
	if zone_root == null or not is_instance_valid(zone_root):
		return
	_anchors.clear()
	_anchors["village"] = zone_root.global_position + Vector3(-3.0, 0.0, -3.0)
	_anchors["forest"] = zone_root.global_position + Vector3(0.0, 0.0, -3.0)
	for raw_node in zone_root.find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node == null:
			continue
		var node_name := node.name.to_lower()
		var kind := str(node.get_meta("world_prop_kind", ""))
		if node_name.contains("rivercurrentaudio"):
			_anchors["river"] = node.global_position
		elif node_name.contains("oathgateportal"):
			_anchors["portal"] = node.global_position
		elif kind == "shrine" or node_name.contains("shrineglow") or node_name.contains("crowcemeterybell"):
			_anchors["shrine"] = node.global_position
			if node_name.contains("bell"):
				_anchors["bell"] = node.global_position
		elif kind == "forge" or node_name.contains("forge"):
			_anchors["forge"] = node.global_position
	if not _anchors.has("river"):
		_anchors["river"] = zone_root.global_position + Vector3(0.0, 0.0, 4.5 if zone_id == "greyfen" else 0.0)
	if not _anchors.has("shrine"):
		_anchors["shrine"] = zone_root.global_position + Vector3(6.0, 0.0, -7.0)
	if not _anchors.has("bell"):
		_anchors["bell"] = _anchors["shrine"]
	if not _anchors.has("forge"):
		_anchors["forge"] = zone_root.global_position + Vector3(9.5, 0.0, 4.5)
