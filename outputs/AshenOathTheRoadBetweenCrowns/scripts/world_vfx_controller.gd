extends Node3D

var quality := "balanced"
var zone_id := "greyfen"
var mote_positions: Array[Vector3] = []
var mote_batch: MultiMeshInstance3D
var active_pulses := 0
var elapsed := 0.0
var update_accumulator := 0.0
var shared_mote_mesh: SphereMesh
var shared_mote_material: StandardMaterial3D
const UPDATE_INTERVAL := 1.0 / 20.0

func configure(active_zone: String, quality_preset: String) -> void:
	zone_id = active_zone
	quality = quality_preset if quality_preset in ["potato", "balanced", "quality"] else "balanced"
	_build_ambient_motes()

func _physics_process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < UPDATE_INTERVAL:
		return
	delta = update_accumulator
	update_accumulator = 0.0
	elapsed += delta
	if mote_batch == null or mote_batch.multimesh == null:
		return
	for index in range(mote_positions.size()):
		var mote_position: Vector3 = mote_positions[index]
		var speed := 0.12 + float(index % 4) * 0.025
		mote_position += Vector3(sin(elapsed * 0.35 + index) * 0.0015, speed * delta, cos(elapsed * 0.28 + index) * 0.0012)
		if mote_position.y > 3.8:
			mote_position = Vector3(_mote_x(index), 0.18, _mote_z(index))
		mote_positions[index] = mote_position
		mote_batch.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, mote_position))

func pulse_interaction(world_position: Vector3, color: Color = Color(0.72, 0.84, 0.66)) -> void:
	if active_pulses >= (1 if quality == "potato" else 3):
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "InteractionCompletionPulse"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.012
	mesh.radial_segments = 20 if quality == "potato" else 32
	pulse.mesh = mesh
	pulse.scale = Vector3(0.18, 0.01, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = quality != "potato"
	material.emission = color
	material.emission_energy_multiplier = 0.34
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse.material_override = material
	add_child(pulse)
	var elevated := Vector3(world_position.x, world_position.y + 0.06, world_position.z)
	pulse.position = to_local(elevated) if is_inside_tree() else elevated
	active_pulses += 1
	var tween := pulse.create_tween()
	tween.tween_property(pulse, "scale", Vector3(1.15, 0.01, 1.15), 0.28)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(func():
		active_pulses = maxi(0, active_pulses - 1)
		pulse.queue_free()
	)

func budget_snapshot() -> Dictionary:
	return {"quality": quality, "motes": mote_positions.size(), "active_pulses": active_pulses}

func _build_ambient_motes() -> void:
	if mote_batch != null and is_instance_valid(mote_batch):
		mote_batch.queue_free()
	mote_batch = null
	mote_positions.clear()
	if zone_id in ["record_hall", "undercroft"]:
		return
	var count := 4 if quality == "potato" else (14 if quality == "quality" else 8)
	shared_mote_mesh = SphereMesh.new()
	shared_mote_mesh.radius = 0.018
	shared_mote_mesh.height = 0.028
	shared_mote_mesh.radial_segments = 5
	shared_mote_mesh.rings = 3
	shared_mote_material = StandardMaterial3D.new()
	shared_mote_material.albedo_color = _mote_color()
	shared_mote_material.emission_enabled = quality == "quality"
	shared_mote_material.emission = _mote_color()
	shared_mote_material.emission_energy_multiplier = 0.12
	mote_batch = MultiMeshInstance3D.new()
	mote_batch.name = "SharedWeatherMoteBatch"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shared_mote_mesh
	multimesh.instance_count = count
	mote_batch.multimesh = multimesh
	mote_batch.material_override = shared_mote_material
	mote_batch.visibility_range_end = 32.0
	add_child(mote_batch)
	for index in range(count):
		var position := Vector3(_mote_x(index), 0.18 + fmod(float(index) * 0.73, 3.5), _mote_z(index))
		mote_positions.append(position)
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))

func _mote_x(index: int) -> float:
	return -7.0 + fmod(float(index * 37), 14.0)

func _mote_z(index: int) -> float:
	return -8.0 + fmod(float(index * 53), 16.0)

func _mote_color() -> Color:
	if zone_id in ["wychwood", "deep_wood", "marsh_crossing", "hart_glade"]:
		return Color(0.42, 0.50, 0.29, 0.38)
	if zone_id in ["vargan_approach", "vargan_court"]:
		return Color(0.56, 0.52, 0.47, 0.32)
	return Color(0.64, 0.58, 0.48, 0.34)
