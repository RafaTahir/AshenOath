extends Node3D

## One controller owns the small amount of animated river dressing. Individual
## leaves and ripples never run their own scripts, keeping Web/Potato cost flat.

var center_z := 0.0
var width := 0.0
var span := 0.0
var flow_time := 0.0
var leaves: MultiMeshInstance3D
var ripple_batch: MultiMeshInstance3D
var ripple_multimesh: MultiMesh
var ripples: Array[Node3D] = []
var ripple_widths: Array[float] = []
var ripple_angles: Array[float] = []
var current_ribbon_batch: MultiMeshInstance3D
var current_ribbon_multimesh: MultiMesh
var current_ribbons: Array[Node3D] = []
var current_ribbon_sizes: Array[Vector2] = []
var leaf_origins: Array[Vector3] = []
var ripple_origins: Array[Vector3] = []
var update_accumulator := 0.0
const UPDATE_INTERVAL := 1.0 / 30.0

func configure(center: float, river_width: float, river_span: float) -> void:
	center_z = center
	width = river_width
	span = river_span
	_build_dressing()

func _physics_process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < UPDATE_INTERVAL:
		return
	delta = update_accumulator
	update_accumulator = 0.0
	flow_time += delta
	if leaves != null and leaves.multimesh != null:
		for index in range(leaf_origins.size()):
			var origin := leaf_origins[index]
			var drift := fposmod(origin.z - center_z + flow_time * (0.18 + float(index % 3) * 0.035) + span * 0.5, span) - span * 0.5
			var position := Vector3(origin.x + sin(flow_time * 0.9 + float(index)) * 0.035, origin.y + sin(flow_time * 1.35 + float(index) * 0.7) * 0.018, center_z + drift)
			var transform := Transform3D(Basis(Vector3.UP, flow_time * (0.55 + float(index % 4) * 0.08)).scaled(Vector3.ONE), position)
			leaves.multimesh.set_instance_transform(index, transform)
	for index in range(ripples.size()):
		var ripple := ripples[index]
		if not is_instance_valid(ripple):
			continue
		var pulse := 0.78 + 0.22 * sin(flow_time * (1.5 + float(index % 3) * 0.25) + float(index))
		ripple.scale = Vector3(pulse, 1.0, 1.0)
		ripple.position.y = ripple_origins[index].y + sin(flow_time * 1.7 + float(index)) * 0.008
		if ripple_multimesh != null:
			var ripple_basis := Basis(Vector3.UP, ripple_angles[index]).scaled(Vector3(ripple_widths[index] * pulse, 0.012, 0.035))
			ripple_multimesh.set_instance_transform(index, Transform3D(ripple_basis, ripple.position))
	for index in range(current_ribbons.size()):
		var ribbon := current_ribbons[index]
		if not is_instance_valid(ribbon):
			continue
		ribbon.position.z = center_z - span * 0.30 + fposmod(flow_time * (0.16 + float(index) * 0.035) + float(index) * 1.9, span * 0.60)
		if current_ribbon_multimesh != null:
			var ribbon_size := current_ribbon_sizes[index]
			var ribbon_basis := Basis.IDENTITY.scaled(Vector3(ribbon_size.x, 1.0, ribbon_size.y))
			current_ribbon_multimesh.set_instance_transform(index, Transform3D(ribbon_basis, ribbon.position))

func _build_dressing() -> void:
	ripples.clear()
	ripple_widths.clear()
	ripple_angles.clear()
	ripple_origins.clear()
	current_ribbons.clear()
	current_ribbon_sizes.clear()
	var leaf_mesh := QuadMesh.new()
	leaf_mesh.size = Vector2(0.20, 0.10)
	leaf_mesh.orientation = PlaneMesh.FACE_Z
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color(0.16, 0.23, 0.10, 0.94)
	leaf_material.roughness = 0.72
	leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaves = MultiMeshInstance3D.new()
	leaves.name = "RiverFloatingLeafBatch"
	var leaf_multimesh := MultiMesh.new()
	leaf_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	leaf_multimesh.mesh = leaf_mesh
	leaf_multimesh.instance_count = 14
	leaves.multimesh = leaf_multimesh
	leaves.material_override = leaf_material
	add_child(leaves)
	for index in range(14):
		var x := lerpf(-width * 0.38, width * 0.38, float(index % 7) / 6.0) + sin(float(index) * 3.7) * 0.18
		var z := center_z - span * 0.5 + fposmod(float(index) * 1.47, span)
		var origin := Vector3(x, -0.155, z)
		leaf_origins.append(origin)
		leaf_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))

	var ripple_material := StandardMaterial3D.new()
	ripple_material.albedo_color = Color(0.20, 0.46, 0.42, 0.30)
	ripple_material.emission_enabled = true
	ripple_material.emission = Color(0.10, 0.24, 0.20)
	ripple_material.emission_energy_multiplier = 0.26
	ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ripple_batch = MultiMeshInstance3D.new()
	ripple_batch.name = "RiverRippleBatch"
	ripple_multimesh = MultiMesh.new()
	ripple_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var ripple_mesh := BoxMesh.new()
	ripple_mesh.size = Vector3.ONE
	ripple_multimesh.mesh = ripple_mesh
	ripple_multimesh.instance_count = 7
	ripple_batch.multimesh = ripple_multimesh
	ripple_batch.material_override = ripple_material
	add_child(ripple_batch)
	for index in range(7):
		var ripple := Node3D.new()
		ripple.name = "RiverRipple_%02d" % index
		var origin := Vector3(-width * 0.30 + float(index % 4) * 0.42, -0.205, center_z - span * 0.40 + float(index) * span * 0.13)
		var ripple_width := 0.62 + float(index % 2) * 0.20
		var ripple_angle := -0.12 + float(index % 3) * 0.16
		ripple.position = origin
		ripple.rotation.y = ripple_angle
		add_child(ripple)
		ripples.append(ripple)
		ripple_origins.append(origin)
		ripple_widths.append(ripple_width)
		ripple_angles.append(ripple_angle)
		var ripple_basis := Basis(Vector3.UP, ripple_angle).scaled(Vector3(ripple_width, 0.012, 0.035))
		ripple_multimesh.set_instance_transform(index, Transform3D(ripple_basis, origin))
	# Keep current ribbons on a validated built-in material. The water surface
	# owns the animated shader; these overlays only need motion and a soft
	# translucent highlight. Avoiding per-ribbon ShaderMaterials also prevents
	# Compatibility renderer null-material lookups during zone retirement.
	var current_material := StandardMaterial3D.new()
	current_material.albedo_color = Color(0.15, 0.42, 0.38, 0.10)
	current_material.emission_enabled = true
	current_material.emission = Color(0.06, 0.16, 0.14)
	current_material.emission_energy_multiplier = 0.18
	current_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	current_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	current_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	current_ribbon_batch = MultiMeshInstance3D.new()
	current_ribbon_batch.name = "RiverCurrentRibbonBatch"
	current_ribbon_multimesh = MultiMesh.new()
	current_ribbon_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var ribbon_mesh := PlaneMesh.new()
	ribbon_mesh.size = Vector2.ONE
	current_ribbon_multimesh.mesh = ribbon_mesh
	current_ribbon_multimesh.instance_count = 3
	current_ribbon_batch.multimesh = current_ribbon_multimesh
	current_ribbon_batch.material_override = current_material
	add_child(current_ribbon_batch)
	for index in range(3):
		var ribbon := Node3D.new()
		ribbon.name = "RiverCurrentRibbon_%02d" % index
		var ribbon_size := Vector2(width * (0.58 + float(index) * 0.08), span * 0.22)
		ribbon.position = Vector3(0.0, -0.185, center_z - span * 0.30 + float(index) * 2.1)
		add_child(ribbon)
		current_ribbons.append(ribbon)
		current_ribbon_sizes.append(ribbon_size)
		var ribbon_basis := Basis.IDENTITY.scaled(Vector3(ribbon_size.x, 1.0, ribbon_size.y))
		current_ribbon_multimesh.set_instance_transform(index, Transform3D(ribbon_basis, ribbon.position))
