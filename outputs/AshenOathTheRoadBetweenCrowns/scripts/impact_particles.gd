extends MultiMeshInstance3D

const COUNT := 12
static var shared_mesh: SphereMesh
static var materials: Dictionary = {}
var particles: Array[Dictionary] = []
var remaining := 0.0
var accumulator := 0.0
var duration := 0.4

func restart(point: Vector3, normal: Vector3, travel: Vector3, surface: String, reduce_flashes: bool) -> void:
	if shared_mesh == null:
		shared_mesh = SphereMesh.new()
		shared_mesh.radius = 0.012
		shared_mesh.height = 0.024
		shared_mesh.radial_segments = 4
		shared_mesh.rings = 2
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = shared_mesh
		multimesh.instance_count = COUNT
	var key := surface + str(reduce_flashes)
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = {"flesh":Color(0.34,0.025,0.018),"wood":Color(0.35,0.21,0.09),"foliage":Color(0.20,0.32,0.10),"metal":Color(0.73,0.60,0.37)}.get(surface,Color(0.43,0.43,0.40))
		material.roughness = 0.38 if surface == "flesh" else 0.8
		if surface == "metal" and not reduce_flashes:
			material.emission_enabled = true
			material.emission = Color(0.65,0.34,0.07)
			material.emission_energy_multiplier = 0.7
		materials[key] = material
	material_override = materials[key]
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_position = point
	duration = 0.20 if surface == "metal" else 0.42
	remaining = duration
	accumulator = 0.0
	particles.clear()
	if normal.length_squared() < 0.01: normal = -travel.normalized()
	if normal.length_squared() < 0.01: normal = Vector3.UP
	for index in COUNT:
		var velocity := normal * randf_range(0.3,1.0) + travel * randf_range(0.2,1.4) + Vector3(randf_range(-0.45,0.45),randf_range(0.2,0.9),randf_range(-0.45,0.45))
		particles.append({"position":Vector3.ZERO,"velocity":velocity,"scale":randf_range(0.45,1.0)})
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01),Vector3.ZERO))
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		visible = false
		set_physics_process(false)
		return
	accumulator += delta
	if accumulator < 1.0 / 30.0: return
	var step := accumulator
	accumulator = 0.0
	for index in particles.size():
		var particle: Dictionary = particles[index]
		particle.velocity.y -= 5.5 * step
		particle.position += particle.velocity * step
		var size := float(particle.scale) * smoothstep(0.0, duration * 0.5, remaining)
		var orientation := Basis(Quaternion(Vector3.UP,(particle.velocity as Vector3).normalized()))
		multimesh.set_instance_transform(index,Transform3D(orientation.scaled(Vector3(0.55,1.4,0.55)*size),particle.position))
