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
var shared_pulse_mesh: ArrayMesh
var rainfall: MultiMeshInstance3D
var weather := "clear"
var weather_focus: WeakRef
var rain_roof: Dictionary = {}
var rain_cursor := 0
var work_sparks: MultiMeshInstance3D
var work_contacts: Array[Dictionary] = []
const UPDATE_INTERVAL := 1.0 / 10.0

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
	_tick_rain(delta)
	_tick_work_contacts(delta)
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
	_surface_pulse(world_position, color, false)

func pulse_water_contact(point: Vector3, listener: Vector3) -> void:
	if not point.is_finite() or not listener.is_finite() or point.distance_squared_to(listener) > 144.0: return
	if is_inside_tree() and get_tree().paused: return
	_surface_pulse(point, Color(0.34, 0.54, 0.49), true)

func _surface_pulse(world_position: Vector3, color: Color, water: bool) -> void:
	if active_pulses >= (1 if quality == "potato" else 3):
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "InteractionCompletionPulse"
	# A hollow, surface-following mark leaves the completed object visible.
	# Shared annulus geometry also avoids a cylinder's unused wall/bottom faces.
	if shared_pulse_mesh == null:
		shared_pulse_mesh = _make_pulse_ring(20 if quality == "potato" else 32)
	pulse.mesh = shared_pulse_mesh
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse.scale = Vector3(0.18, 0.01, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = not water and quality != "potato"
	material.emission = color
	material.emission_energy_multiplier = 0.34
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pulse.material_override = material
	add_child(pulse)
	var elevated := Vector3(world_position.x, world_position.y + (0.004 if water else 0.06), world_position.z)
	pulse.position = to_local(elevated) if is_inside_tree() else elevated
	active_pulses += 1
	var tween := pulse.create_tween()
	var radius := 0.48 if water else 1.15
	var seconds := 0.65 if water else 0.28
	tween.tween_property(pulse, "scale", Vector3(radius, 0.01, radius), seconds)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(func():
		active_pulses = maxi(0, active_pulses - 1)
		pulse.queue_free()
	)

func emit_work_contact(point: Vector3, listener: Vector3, kind: String) -> void:
	if kind != "forge" or not point.is_finite() or not listener.is_finite() or point.distance_squared_to(listener) > 121.0: return
	if is_inside_tree() and get_tree().paused: return
	# Share the existing completion-effect cap; contact never allocates a light
	# or an independent particle ticker for a worker or workstation.
	if active_pulses >= (1 if quality == "potato" else 3): return
	if work_sparks == null:
		work_sparks = MultiMeshInstance3D.new()
		work_sparks.name = "VerifiedForgeContacts"
		work_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := SphereMesh.new()
		mesh.radius = 0.012
		mesh.height = 0.024
		mesh.radial_segments = 5
		mesh.rings = 2
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.55, 0.13)
		mesh.material = material
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = 12
		batch.visible_instance_count = 0
		work_sparks.multimesh = batch
		add_child(work_sparks)
	work_contacts.append({"point":to_local(point) if is_inside_tree() else point, "age":0.0})
	active_pulses += 1
	_tick_work_contacts(0.0)

func _tick_work_contacts(delta: float) -> void:
	if work_sparks == null: return
	for index in range(work_contacts.size() - 1, -1, -1):
		work_contacts[index].age = float(work_contacts[index].age) + delta
		if float(work_contacts[index].age) >= 0.36:
			work_contacts.remove_at(index)
			active_pulses = maxi(0, active_pulses - 1)
	var cursor := 0
	for contact: Dictionary in work_contacts:
		var time := float(contact.age)
		for index in (2 if quality == "potato" else 4):
			var direction := Vector3(cos(index * 2.4 + 0.3), 0.85 + index * 0.04, sin(index * 2.4 + 0.3))
			var position: Vector3 = contact.point + direction * time * 0.85 + Vector3.DOWN * 2.4 * time * time
			var size := maxf(0.05, 1.0 - time / 0.36)
			work_sparks.multimesh.set_instance_transform(cursor, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), position))
			cursor += 1
	work_sparks.multimesh.visible_instance_count = cursor

func set_weather(value: String, focus: Node3D) -> void:
	weather = value if zone_id not in ["record_hall", "undercroft", "vargan_court"] else "clear"
	weather_focus = weakref(focus)
	if weather != "rain":
		if is_instance_valid(rainfall): rainfall.visible = false
		return
	if rainfall == null:
		rainfall = MultiMeshInstance3D.new()
		rainfall.name = "NearbyRain"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.009, 0.18, 0.009)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.64,0.74,0.78,0.35)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		rainfall.multimesh = MultiMesh.new()
		rainfall.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		rainfall.multimesh.mesh = mesh
		rainfall.multimesh.instance_count = 40
		rainfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rainfall)
		rainfall.multimesh.custom_aabb = AABB(Vector3(-8,-1,-8), Vector3(16,8,16))
	rainfall.visible = true

func _tick_rain(_delta: float) -> void:
	if weather != "rain" or not is_instance_valid(rainfall) or weather_focus == null: return
	var focus := weather_focus.get_ref() as Node3D
	if not is_instance_valid(focus): return
	rainfall.global_position = focus.global_position
	# Four roof probes per update; cache the rest instead of forty rays per frame.
	for offset in 4:
		var index := (rain_cursor+offset)%rainfall.multimesh.instance_count
		var point := focus.global_position+Vector3(sin(float(index)*21.17)*7.0,0.0,cos(float(index)*17.63)*7.0)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*7.0,point+Vector3.UP*0.5,1))
		rain_roof[index] = not hit.is_empty() and hit.position.y > focus.global_position.y+0.9
	rain_cursor = (rain_cursor+4)%rainfall.multimesh.instance_count
	for index in rainfall.multimesh.instance_count:
		var x := sin(float(index)*21.17)*7.0
		var z := cos(float(index)*17.63)*7.0
		var y := 6.0-fposmod(elapsed*6.0+float(index)*0.73,6.0)
		var hidden := bool(rain_roof.get(index,true))
		rainfall.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO if hidden else Vector3.ONE),Vector3(x,y,z)))

func _make_pulse_ring(segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		for radius in [0.41, 0.5]:
			vertices.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
			normals.append(Vector3.UP)
		var a := index * 2
		var b := ((index + 1) % segments) * 2
		indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "SharedInteractionCompletionRing"
	return mesh

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
	mote_batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
