extends Node3D
## A combat-owned device. The parent destination controls its lifetime; it
## cannot advance or affect another zone while that destination is cached.
var manager: WeakRef
var zone := ""
var device_id := ""
var kind := "trap"
var velocity := Vector3.ZERO
var age := 0.0
var consumed := false
var _poll := 0.0

func _ready() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.19, 0.20, 0.18)
	metal.metallic = 0.7
	metal.roughness = 0.65
	if kind in ["bomb", "stone"]:
		var shell := SphereMesh.new()
		shell.radius = 0.095
		shell.height = 0.19
		shell.radial_segments = 12
		shell.rings = 6
		_add_mesh(shell, metal, Vector3.ZERO)
		if kind == "stone":
			metal.metallic = 0.0
			metal.albedo_color = Color(0.32, 0.34, 0.30)
			scale = Vector3(0.8, 0.55, 0.65)
			return
		var band := TorusMesh.new()
		band.inner_radius = 0.085
		band.outer_radius = 0.105
		band.rings = 12
		band.ring_segments = 6
		_add_mesh(band, metal, Vector3.ZERO)
	else:
		var plate := CylinderMesh.new()
		plate.top_radius = 0.11
		plate.bottom_radius = 0.11
		plate.height = 0.025
		plate.radial_segments = 12
		_add_mesh(plate, metal, Vector3.UP * 0.025)
		for side in [-1.0, 1.0]:
			var jaw := BoxMesh.new()
			jaw.size = Vector3(0.055, 0.045, 0.42)
			_add_mesh(jaw, metal, Vector3(side * 0.19, 0.04, 0))
			for index in 5:
				var tooth := PrismMesh.new()
				tooth.size = Vector3(0.07, 0.08, 0.04)
				_add_mesh(tooth, metal, Vector3(side * 0.17, 0.065, -0.16 + index * 0.08))

func _add_mesh(mesh: Mesh, material: Material, offset: Vector3) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = offset
	add_child(visual)

func _physics_process(delta: float) -> void:
	var owner_node: Node = manager.get_ref() if manager != null else null
	if consumed or not is_instance_valid(owner_node) or not owner_node.device_can_tick(self): return
	age += delta
	if kind == "trap":
		_poll += delta
		if _poll >= 0.1:
			_poll = 0.0
			owner_node.try_trigger_trap(self)
		return
	var start := global_position
	var step := velocity * delta + Vector3.DOWN * 4.9 * delta * delta
	velocity += Vector3.DOWN * 9.8 * delta
	var query := PhysicsRayQueryParameters3D.create(start, start + step, 1)
	query.exclude = owner_node.device_exclusions()
	query.collide_with_areas = false
	var contact := get_world_3d().direct_space_state.intersect_ray(query)
	if not contact.is_empty():
		global_position = contact.position + contact.normal * 0.12
		consumed = true
		owner_node.explode_device(self)
	elif age >= 3.0:
		consumed = true
		owner_node.explode_device(self)
	else:
		global_position += step
		rotate_x(delta * 4.0)
