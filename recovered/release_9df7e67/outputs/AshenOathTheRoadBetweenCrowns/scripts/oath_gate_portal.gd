extends Node3D
class_name OathGatePortal

## Lightweight visual state machine for route transitions.  The parent
## Interactable remains the authority for collision, focus, and travel.
signal state_changed(state_name: String)

enum PortalState { LOCKED, DORMANT, AWAKENING, PRELOADING, READY, TRAVELING, ERROR }

var portal_id := ""
var destination := ""
var state: PortalState = PortalState.DORMANT
var progress := 0.0
var streaming_service: Node
var audio_manager: Node
var _time := 0.0
var _panel: MeshInstance3D
var _ring: MeshInstance3D
var _arch_parts: Array[MeshInstance3D] = []
var _motes: Array[MeshInstance3D] = []
var _veil_layers: Array[MeshInstance3D] = []
var _panel_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _mote_material: StandardMaterial3D

const ARCH_STONE := Color(0.16, 0.15, 0.14)
const ARCH_EDGE := Color(0.31, 0.27, 0.21)
const DORMANT_GLOW := Color(0.20, 0.28, 0.30)
const READY_GLOW := Color(0.44, 0.76, 0.68)
const TRAVEL_GLOW := Color(0.79, 0.65, 0.35)
const ERROR_GLOW := Color(0.58, 0.18, 0.15)
const BALANCED_VISIBILITY_RANGE := 22.0

func configure(destination_id: String, id: String = "") -> void:
	destination = destination_id
	portal_id = id if id != "" else "oath_gate_%s" % destination_id
	set_meta("destination", destination)
	set_meta("portal_id", portal_id)

func bind_streaming(service: Node) -> void:
	streaming_service = service
	if streaming_service == null:
		return
	if streaming_service.has_signal("zone_progress") and not streaming_service.zone_progress.is_connected(_on_zone_progress):
		streaming_service.zone_progress.connect(_on_zone_progress)
	if streaming_service.has_signal("zone_ready") and not streaming_service.zone_ready.is_connected(_on_zone_ready):
		streaming_service.zone_ready.connect(_on_zone_ready)
	if streaming_service.has_signal("zone_failed") and not streaming_service.zone_failed.is_connected(_on_zone_failed):
		streaming_service.zone_failed.connect(_on_zone_failed)

func bind_audio(manager: Node) -> void:
	audio_manager = manager

func begin_preload() -> void:
	if state == PortalState.LOCKED or destination == "":
		return
	set_state(PortalState.AWAKENING)
	if streaming_service == null or not streaming_service.has_method("request_zone_for_portal"):
		set_ready()
		return
	set_state(PortalState.PRELOADING)
	if not streaming_service.request_zone_for_portal(destination):
		set_state(PortalState.ERROR)
		return
	if streaming_service.has_method("is_ready") and streaming_service.is_ready(destination):
		set_ready()

func mark_traveling() -> void:
	if state == PortalState.READY:
		set_state(PortalState.TRAVELING)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_build_visuals()
	_apply_state()

func set_state(next_state: PortalState) -> void:
	if state == next_state:
		return
	state = next_state
	_apply_state()
	_play_state_audio(next_state)
	state_changed.emit(_state_name())

func _play_state_audio(next_state: PortalState) -> void:
	if audio_manager == null or not is_instance_valid(audio_manager):
		return
	var cue := ""
	match next_state:
		PortalState.AWAKENING, PortalState.PRELOADING:
			cue = "portal_ash"
		PortalState.READY:
			cue = "portal_ready"
		PortalState.TRAVELING:
			cue = "portal_travel"
		PortalState.ERROR:
			cue = "portal_error"
	if cue != "" and audio_manager.has_method("play_event_limited"):
		audio_manager.play_event_limited(cue, 0.25, 0.035)

func set_state_name(next_state: String) -> void:
	var normalized := next_state.strip_edges().to_upper()
	for value in PortalState.keys():
		if value == normalized:
			set_state(PortalState[value])
			return

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if progress >= 1.0 and state == PortalState.PRELOADING:
		set_state(PortalState.READY)

func set_ready() -> void:
	set_progress(1.0)
	set_state(PortalState.READY)

func set_locked(locked: bool) -> void:
	set_state(PortalState.LOCKED if locked else PortalState.DORMANT)

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _ring != null:
		var pulse := 0.82 + sin(_time * 2.1) * 0.08
		_ring.scale = Vector3.ONE * pulse
		_ring.rotation.z = sin(_time * 0.45) * 0.035
	if _panel != null:
		_panel.position.z = sin(_time * 0.9) * 0.018
		_panel.scale.y = 1.0 + sin(_time * 1.4) * 0.012
	for index in _veil_layers.size():
		var veil := _veil_layers[index]
		veil.position.x = sin(_time * (0.45 + index * 0.12)) * 0.035
		veil.scale.x = 1.0 + sin(_time * (0.72 + index * 0.16) + index) * 0.035
	for index in _motes.size():
		var mote := _motes[index]
		var base := float(index) * 1.73
		mote.position.y = 0.45 + fposmod(_time * (0.12 + index * 0.012) + base, 1.9)
		mote.position.x = sin(_time * 0.8 + base) * (0.84 + index * 0.025)
		mote.position.z = cos(_time * 0.65 + base) * 0.08
	if state == PortalState.PRELOADING and streaming_service != null:
		if streaming_service.has_method("get_progress"):
			set_progress(streaming_service.get_progress(destination))
		if streaming_service.has_method("get_state") and streaming_service.get_state(destination) == "failed":
			set_state(PortalState.ERROR)

func _build_visuals() -> void:
	if _panel != null:
		return
	var stone := StandardMaterial3D.new()
	stone.albedo_color = ARCH_STONE
	stone.roughness = 0.92
	var edge := StandardMaterial3D.new()
	edge.albedo_color = ARCH_EDGE
	edge.roughness = 0.70
	for part in [
		{"size": Vector3(0.30, 2.45, 0.34), "pos": Vector3(-1.0, 1.225, 0.0)},
		{"size": Vector3(0.30, 2.45, 0.34), "pos": Vector3(1.0, 1.225, 0.0)},
		{"size": Vector3(2.30, 0.30, 0.34), "pos": Vector3(0.0, 2.30, 0.0)},
	]:
		var arch := MeshInstance3D.new()
		arch.name = "OathGateStone"
		var mesh := BoxMesh.new()
		mesh.size = part["size"]
		arch.mesh = mesh
		arch.position = part["pos"]
		arch.material_override = stone
		arch.visibility_range_end = BALANCED_VISIBILITY_RANGE
		add_child(arch)
		_arch_parts.append(arch)
	# Short stone voussoirs turn the flat lintel into a readable, walk-through
	# arch. They are visual only; the Interactable owns the travel collision.
	for index in range(7):
		var arch_angle := deg_to_rad(180.0 - float(index) * 30.0)
		var voussoir := MeshInstance3D.new()
		voussoir.name = "OathGateVoussoir_%02d" % index
		var voussoir_mesh := BoxMesh.new()
		voussoir_mesh.size = Vector3(0.40, 0.34, 0.42)
		voussoir.mesh = voussoir_mesh
		voussoir.position = Vector3(cos(arch_angle) * 0.92, 1.28 + sin(arch_angle) * 1.02, 0.0)
		voussoir.rotation.z = -arch_angle + PI * 0.5
		voussoir.material_override = edge
		voussoir.visibility_range_end = BALANCED_VISIBILITY_RANGE
		add_child(voussoir)
		_arch_parts.append(voussoir)

	_panel = MeshInstance3D.new()
	_panel.name = "OathGateBlackGlass"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1.72, 2.08, 0.045)
	_panel.mesh = panel_mesh
	_panel.position = Vector3(0.0, 1.10, 0.02)
	_panel_material = StandardMaterial3D.new()
	_panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_panel_material.albedo_color = Color(DORMANT_GLOW.r, DORMANT_GLOW.g, DORMANT_GLOW.b, 0.28)
	_panel_material.roughness = 0.25
	_panel.material_override = _panel_material
	_panel.visibility_range_end = BALANCED_VISIBILITY_RANGE
	add_child(_panel)
	for layer_index in range(2):
		var veil := MeshInstance3D.new()
		veil.name = "OathGateVeil_%02d" % layer_index
		var veil_mesh := QuadMesh.new()
		veil_mesh.size = Vector2(1.48 - layer_index * 0.16, 1.82 - layer_index * 0.16)
		veil.mesh = veil_mesh
		veil.position = Vector3(0.0, 1.12, -0.012 - layer_index * 0.012)
		var veil_material := StandardMaterial3D.new()
		veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		veil_material.albedo_color = Color(0.04, 0.10, 0.12, 0.14 - layer_index * 0.035)
		veil_material.emission_enabled = true
		veil_material.emission = Color(0.08, 0.24, 0.25)
		veil_material.emission_energy_multiplier = 0.34
		veil.material_override = veil_material
		veil.visibility_range_end = BALANCED_VISIBILITY_RANGE
		add_child(veil)
		_veil_layers.append(veil)

	_ring = MeshInstance3D.new()
	_ring.name = "OathGateRunicEdge"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.87
	ring_mesh.outer_radius = 0.95
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, 1.10, -0.035)
	_ring.rotation.x = PI * 0.5
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.emission_enabled = true
	_ring_material.emission_energy_multiplier = 1.3
	_ring.material_override = _ring_material
	_ring.visibility_range_end = BALANCED_VISIBILITY_RANGE
	add_child(_ring)
	var threshold := MeshInstance3D.new()
	threshold.name = "OathGateThresholdStone"
	var threshold_mesh := BoxMesh.new()
	threshold_mesh.size = Vector3(2.05, 0.10, 0.52)
	threshold.mesh = threshold_mesh
	threshold.position = Vector3(0.0, 0.05, 0.15)
	threshold.material_override = edge
	threshold.visibility_range_end = BALANCED_VISIBILITY_RANGE
	add_child(threshold)

	_mote_material = StandardMaterial3D.new()
	_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_material.emission_enabled = true
	_mote_material.emission_energy_multiplier = 1.5
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.035
	mote_mesh.height = 0.07
	mote_mesh.radial_segments = 5
	mote_mesh.rings = 3
	for index in 7:
		var mote := MeshInstance3D.new()
		mote.name = "OathGateAshMote_%02d" % index
		mote.mesh = mote_mesh
		mote.material_override = _mote_material
		mote.visibility_range_end = BALANCED_VISIBILITY_RANGE
		mote.position = Vector3((float(index) - 3.0) * 0.24, 0.45 + index * 0.18, 0.0)
		add_child(mote)
		_motes.append(mote)

func _apply_state() -> void:
	if _panel == null:
		return
	var glow := DORMANT_GLOW
	var alpha := 0.24
	var energy := 0.9
	match state:
		PortalState.LOCKED:
			glow = Color(0.12, 0.12, 0.12)
			alpha = 0.10
			energy = 0.15
		PortalState.AWAKENING, PortalState.PRELOADING:
			glow = TRAVEL_GLOW
			alpha = 0.32
			energy = 1.25
		PortalState.READY:
			glow = READY_GLOW
			alpha = 0.38
			energy = 1.55
		PortalState.TRAVELING:
			glow = TRAVEL_GLOW
			alpha = 0.48
			energy = 1.90
		PortalState.ERROR:
			glow = ERROR_GLOW
			alpha = 0.30
			energy = 1.10
	_panel_material.albedo_color = Color(glow.r, glow.g, glow.b, alpha)
	_ring_material.albedo_color = glow
	_ring_material.emission = glow
	_ring_material.emission_energy_multiplier = energy
	_mote_material.albedo_color = Color(glow.r, glow.g, glow.b, 0.90)
	_mote_material.emission = glow
	_mote_material.emission_energy_multiplier = energy

func _state_name() -> String:
	return PortalState.keys()[int(state)]

func _on_zone_progress(zone_id: String, value: float) -> void:
	if zone_id == destination and state == PortalState.PRELOADING:
		set_progress(value)

func _on_zone_ready(zone_id: String, _resource: Resource) -> void:
	if zone_id == destination and state in [PortalState.AWAKENING, PortalState.PRELOADING]:
		set_ready()

func _on_zone_failed(zone_id: String, _reason: String) -> void:
	if zone_id == destination:
		set_state(PortalState.ERROR)
