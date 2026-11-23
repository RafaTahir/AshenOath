extends RefCounted

static func update(parent: Node3D, position: Vector3, rescued: bool, safe_home: bool) -> void:
	var props := parent.get_node_or_null("BrackenRescueProps") as Node3D
	if props == null:
		props = _make_rescue_props(parent, position)
	var strap := props.get_node("CaughtStrap") as MeshInstance3D
	strap.visible = not rescued
	var bowl := props.get_node_or_null("BrackenWaterBowl") as MeshInstance3D
	if safe_home and bowl == null:
		bowl = _make_water_bowl(props)
	if bowl != null:
		bowl.visible = safe_home

static func _make_rescue_props(parent: Node3D, position: Vector3) -> Node3D:
	# A ground prop, not anatomy attached to an unvalidated bone. The loose
	# strap disappears on release; the discarded loops remain by the road.
	var props := Node3D.new()
	props.name = "BrackenRescueProps"
	props.position = position
	parent.add_child(props)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.16, 0.10)
	material.roughness = 0.95
	var vertices := PackedVector3Array()
	for center: Vector3 in [Vector3(-0.57, 0.035, 0.1), Vector3(-0.65, 0.045, 0.4)]:
		for i in range(18):
			var angle: float = TAU * float(i) / 18.0
			var next: float = TAU * float(i + 1) / 18.0
			var a := center + Vector3(cos(angle) * 0.31, 0, sin(angle) * 0.22)
			var b := center + Vector3(cos(next) * 0.31, 0, sin(next) * 0.22)
			var inner_a := center + (a - center) * 0.77
			var inner_b := center + (b - center) * 0.77
			vertices.append_array(PackedVector3Array([a, inner_a, b, b, inner_a, inner_b]))
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var harness := MeshInstance3D.new()
	harness.name = "DiscardedTravellingHarness"
	harness.mesh = mesh
	harness.material_override = material
	props.add_child(harness)
	var caught_strap := MeshInstance3D.new()
	caught_strap.name = "CaughtStrap"
	var strap := BoxMesh.new()
	strap.size = Vector3(0.035, 0.025, 0.50)
	caught_strap.mesh = strap
	caught_strap.material_override = material
	caught_strap.position = Vector3(-0.23, 0.12, 0.38)
	caught_strap.rotation_degrees = Vector3(-24, -50, 0)
	props.add_child(caught_strap)
	return props

static func _make_water_bowl(parent: Node3D) -> MeshInstance3D:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.26, 0.16, 0.09)
	wood.roughness = 0.86
	var rim := TorusMesh.new()
	rim.inner_radius = 0.21
	rim.outer_radius = 0.31
	rim.rings = 20
	rim.ring_segments = 10
	var bowl := MeshInstance3D.new()
	bowl.name = "BrackenWaterBowl"
	bowl.mesh = rim
	bowl.material_override = wood
	bowl.position = Vector3(0.66, 0.045, 0.46)
	parent.add_child(bowl)

	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.29, 0.39, 0.40)
	water.roughness = 0.25
	var surface := CylinderMesh.new()
	surface.top_radius = 0.24
	surface.bottom_radius = 0.22
	surface.height = 0.04
	surface.radial_segments = 20
	var fill := MeshInstance3D.new()
	fill.name = "Water"
	fill.mesh = surface
	fill.material_override = water
	fill.position.y = -0.018
	bowl.add_child(fill)
	return bowl

static func command_menu(travel: Dictionary) -> Dictionary:
	var place := str(travel.get("zone", "greyfen")).replace("_", " ").capitalize()
	var present := bool(travel.get("present", false))
	var status := "Along the road with Kael" if present else "Finding a safe path to Kael"
	if str(travel.get("command", "follow")) == "wait":
		status = "Waiting in " + place
	var commands: Array = [["follow", "Walk with me"], ["recall", "Come, Bracken"]]
	if present:
		commands.insert(1, ["wait", "Wait here"])
	return {"status": status, "commands": commands}
