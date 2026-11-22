extends Node
class_name WorldPropController

## One cheap ticker for ambient world-object motion. It never owns quest logic;
## story flags only select the presentation state of registered props.

var zone_root: Node3D
var zone_id := ""
var quality := "balanced"
var story_state: Node
var audio: Node
var entries: Array[Dictionary] = []
var _elapsed := 0.0
var _accumulator := 0.0
const TICK_INTERVAL := 1.0 / 10.0

func configure(root: Node3D, id: String, quality_preset: String, state_owner: Node, audio_manager: Node = null) -> void:
	zone_root = root
	zone_id = id
	quality = quality_preset
	story_state = state_owner
	audio = audio_manager
	add_to_group("world_prop_controller")
	_scan(zone_root)
	_bind_components()
	_sync_story_states()

func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < TICK_INTERVAL or get_tree().paused:
		return
	var step := _accumulator
	_accumulator = 0.0
	_elapsed += step
	for entry in entries:
		var node := entry.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		_update_entry(entry, step)

func _scan(node: Node) -> void:
	if node is Node3D and node.has_meta("world_prop_kind"):
		_register(node as Node3D, str(node.get_meta("world_prop_id", node.name)), str(node.get_meta("world_prop_kind", "generic")), str(node.get_meta("world_prop_state_key", "")))
	for child in node.get_children():
		_scan(child)

func _bind_components() -> void:
	if zone_root == null:
		return
	for raw in get_tree().get_nodes_in_group("interactive_world_prop"):
		var component := raw as InteractiveWorldProp
		if component == null or not is_instance_valid(component):
			continue
		if not zone_root.is_ancestor_of(component) and component != zone_root:
			continue
		component.bind_story_state(story_state)
		component.state_changed.connect(_on_component_state_changed)

func _register(node: Node3D, id: String, kind: String, persistent_key: String) -> void:
	for existing in entries:
		if existing.get("node") == node:
			return
	entries.append({
		"node": node,
		"id": id,
		"kind": kind,
		"state_key": persistent_key,
		"base_position": node.position,
		"base_rotation": node.rotation,
		"base_scale": node.scale,
		"phase": float(abs(id.hash()) % 31) * 0.21,
		"state": "idle",
	})
	if str(node.name).begins_with("WorldPropAnchor_") and not node.has_meta("world_prop_decorated"):
		node.set_meta("world_prop_decorated", true)
		_decorate_anchor(node, kind, id)

func _decorate_anchor(anchor: Node3D, kind: String, id: String) -> void:
	if kind == "notice_board":
		for index in range(3):
			var paper := MeshInstance3D.new()
			paper.name = "NoticePaper_%02d" % index
			var paper_mesh := BoxMesh.new()
			paper_mesh.size = Vector3(0.30 + float(index % 2) * 0.06, 0.34, 0.025)
			paper.mesh = paper_mesh
			paper.position = Vector3(-0.48 + float(index) * 0.46, 1.16 + float(index % 2) * 0.07, -0.09)
			paper.rotation_degrees.z = -5.0 + float(index) * 7.0
			paper.material_override = _material(Color(0.68, 0.58, 0.39))
			paper.set_meta("world_prop_kind", "paper")
			paper.set_meta("world_prop_id", id)
			anchor.add_child(paper)
	elif kind == "forge":
		var count := 2 if quality == "potato" else 3
		for index in range(count):
			var spark := MeshInstance3D.new()
			spark.name = "ForgeSpark_%02d" % index
			spark.mesh = SphereMesh.new()
			spark.scale = Vector3.ONE * 0.045
			spark.position = Vector3(-0.22 + float(index) * 0.20, 0.72 + float(index % 2) * 0.16, 0.0)
			spark.material_override = _emissive_material(Color(1.0, 0.42, 0.10), 1.25)
			spark.set_meta("world_prop_kind", "forge")
			spark.set_meta("world_prop_id", id)
			anchor.add_child(spark)
	elif kind == "shrine":
		var ember := MeshInstance3D.new()
		ember.name = "ShrineEmber"
		ember.mesh = SphereMesh.new()
		ember.scale = Vector3(0.06, 0.11, 0.06)
		ember.position = Vector3(0.0, 1.46, -0.24)
		ember.material_override = _emissive_material(Color(0.64, 0.86, 0.60), 0.75)
		ember.set_meta("world_prop_kind", "shrine")
		ember.set_meta("world_prop_id", id)
		anchor.add_child(ember)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _sync_story_states() -> void:
	for entry in entries:
		var key := str(entry.get("state_key", ""))
		if key != "" and story_state != null and story_state.has_method("get_flag"):
			var saved: Variant = story_state.get_flag(key, null)
			if saved != null and str(saved) != "":
				entry.state = str(saved)
		_apply_entry_state(entry)

func activate_prop(prop_id: String) -> bool:
	var activated := false
	for raw in get_tree().get_nodes_in_group("interactive_world_prop"):
		var component := raw as InteractiveWorldProp
		if component != null and is_instance_valid(component) and component.get_prop_id() == prop_id and zone_root.is_ancestor_of(component):
			component.activate()
			_play_prop_audio(component.get_kind())
			activated = true
	for entry in entries:
		if str(entry.get("id", "")) == prop_id:
			entry.state = _next_state(str(entry.get("kind", "generic")), str(entry.get("state", "idle")))
			_apply_entry_state(entry)
			activated = true
	return activated

func set_prop_state(prop_id: String, state: String) -> bool:
	var changed := false
	for entry in entries:
		if str(entry.get("id", "")) == prop_id:
			entry.state = state
			_apply_entry_state(entry)
			changed = true
	return changed

func get_prop_snapshot() -> Array:
	var result: Array = []
	for entry in entries:
		var node := entry.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		result.append({"id": str(entry.id), "kind": str(entry.kind), "state": str(entry.state), "visible": node.visible})
	return result

func _next_state(kind: String, state: String) -> String:
	if kind in ["flame", "candle", "lantern"]:
		return "extinguished" if state == "lit" else "lit"
	if kind == "bell":
		return "rung" if state != "rung" else "silent"
	return "used" if state == "idle" else "idle"

func _update_entry(entry: Dictionary, _delta: float) -> void:
	var node := entry.get("node") as Node3D
	var kind := str(entry.get("kind", "generic"))
	var phase := float(entry.get("phase", 0.0))
	var wave := sin(_elapsed * (2.7 if kind in ["flame", "forge"] else 0.82) + phase)
	var base_rotation: Vector3 = entry.get("base_rotation", Vector3.ZERO)
	var base_scale: Vector3 = entry.get("base_scale", Vector3.ONE)
	if kind in ["flame", "forge", "candle", "lantern"]:
		node.scale = Vector3(base_scale.x * (1.0 + wave * 0.05), base_scale.y * (1.0 + wave * 0.08), base_scale.z * (1.0 - wave * 0.03))
		node.rotation = Vector3(base_rotation.x, base_rotation.y, base_rotation.z + wave * 0.035)
	elif kind in ["cloth", "sign", "paper"]:
		node.rotation = Vector3(base_rotation.x, base_rotation.y, base_rotation.z + wave * 0.045)
	elif kind == "wheel":
		node.rotation = Vector3(base_rotation.x + _delta * 0.45, base_rotation.y, base_rotation.z)
	elif kind == "bell":
		var amount := 0.08 if str(entry.get("state", "")) == "rung" else 0.018
		node.rotation = Vector3(base_rotation.x, base_rotation.y, base_rotation.z + sin(_elapsed * 2.0 + phase) * amount)

func _apply_entry_state(entry: Dictionary) -> void:
	var node := entry.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		return
	var state := str(entry.get("state", "idle"))
	var inactive := state == "extinguished" or state == "off"
	if str(entry.get("kind", "")) in ["flame", "candle", "lantern"]:
		node.visible = not inactive

func _on_component_state_changed(_prop_id: String, _state: String) -> void:
	_play_prop_audio("interaction")

func _play_prop_audio(kind: String) -> void:
	if audio == null or not is_instance_valid(audio) or not audio.has_method("play_event_limited"):
		return
	var cue := "village_life"
	if kind in ["shrine", "candle"]:
		cue = "shrine_candle"
	elif kind == "bell":
		cue = "shrine_bell"
	elif kind == "cloth":
		cue = "cloth_wind"
	audio.play_event_limited(cue, 0.18, 0.035)
