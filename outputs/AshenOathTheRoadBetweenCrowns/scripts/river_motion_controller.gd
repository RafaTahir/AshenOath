extends Node3D

## One controller owns the small amount of animated river dressing. Individual
## leaves and ripples never run their own scripts, keeping Web/Potato cost flat.

var center_z := 0.0
var width := 0.0
var span := 0.0
var flow_time := 0.0
var leaves: MultiMeshInstance3D
var ripples: Array[Node3D] = []
var leaf_origins: Array[Vector3] = []
var ripple_origins: Array[Vector3] = []

func configure(center: float, river_width: float, river_span: float) -> void:
	center_z = center
	width = river_width
	span = river_span
	_build_dressing()

func _process(delta: float) -> void:
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

func _build_dressing() -> void:
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
	ripple_material.albedo_color = Color(0.44, 0.72, 0.64, 0.36)
	ripple_material.emission_enabled = true
	ripple_material.emission = Color(0.10, 0.24, 0.20)
	ripple_material.emission_energy_multiplier = 0.26
	ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(7):
		var ripple := MeshInstance3D.new()
		ripple.name = "RiverRipple_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.62 + float(index % 2) * 0.20, 0.012, 0.035)
		ripple.mesh = mesh
		ripple.material_override = ripple_material
		var origin := Vector3(-width * 0.30 + float(index % 4) * 0.42, -0.205, center_z - span * 0.40 + float(index) * span * 0.13)
		ripple.position = origin
		ripple.rotation.y = -0.12 + float(index % 3) * 0.16
		add_child(ripple)
		ripples.append(ripple)
		ripple_origins.append(origin)
