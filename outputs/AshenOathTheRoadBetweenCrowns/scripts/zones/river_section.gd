extends RefCounted

const BRIDGE_WIDTH := 5.4
const BANK_CLEARANCE := 1.15

func build(parent: Node3D, context: Dictionary) -> Dictionary:
	var host = context.get("host")
	var center_z := float(context.get("center_z", 0.0))
	var width := float(context.get("width", 44.0))
	var span := float(context.get("span", 3.4))
	var root := Node3D.new()
	root.name = "LivingRiverSection"
	root.set_meta("river_center_z", center_z)
	root.set_meta("river_span", span)
	root.set_meta("bridge_half_width", BRIDGE_WIDTH * 0.5)
	parent.add_child(root)

	_make_box(root, "RiverBed", Vector3(0,-1.72,center_z), Vector3(width,0.20,span), Color(0.055,0.075,0.065), false)
	_make_box(root, "NorthBank", Vector3(0,0.10,center_z-span*0.68), Vector3(width,0.24,1.05), Color(0.16,0.13,0.085), false)
	_make_box(root, "SouthBank", Vector3(0,0.10,center_z+span*0.68), Vector3(width,0.24,1.05), Color(0.15,0.12,0.08), false)
	_make_water(root, center_z, width, span)
	_make_bridge(root, center_z, span)
	_make_bank_barriers(root, center_z, width, span)
	_make_recovery_volumes(root, host, center_z, width, span)

	for x in [-18.0,-14.0,-10.0,-6.0,6.0,10.0,14.0,18.0]:
		_make_reed(root, Vector3(x,0.34,center_z-span*0.54))
		_make_reed(root, Vector3(x+1.2,0.34,center_z+span*0.54))
	for x in [-16.0,-11.0,-7.0,7.5,12.0,16.5]:
		_make_bank_stone(root, Vector3(x,0.18,center_z-span*0.59), 0.48 + absf(x) * 0.012)
		_make_bank_stone(root, Vector3(x+1.4,0.18,center_z+span*0.59), 0.44 + absf(x) * 0.010)
	return {
		"root":root,
		"center_z":center_z,
		"span":span,
		"north_safe":Vector3(0,0.85,center_z-span*0.5-BANK_CLEARANCE),
		"south_safe":Vector3(0,0.85,center_z+span*0.5+BANK_CLEARANCE),
	}

func _make_water(root: Node3D, center_z: float, width: float, span: float) -> void:
	var water := MeshInstance3D.new()
	water.name = "FlowingRiverWater"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(width,0.06,span-0.30)
	water.mesh = water_mesh
	water.position = Vector3(0,-0.24,center_z)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode blend_mix,depth_draw_opaque,cull_back; uniform vec4 deep_color:source_color=vec4(0.035,0.18,0.25,0.90); uniform vec4 crest_color:source_color=vec4(0.18,0.52,0.62,0.84); void vertex(){ VERTEX.y += sin(VERTEX.x*1.7+TIME*1.9)*0.025 + sin(VERTEX.z*3.1-TIME*1.2)*0.015; } void fragment(){ float ripple=sin(UV.x*55.0-TIME*2.4+sin(UV.y*18.0))*0.5+0.5; ALBEDO=mix(deep_color.rgb,crest_color.rgb,ripple*0.24); ROUGHNESS=0.20; METALLIC=0.12; ALPHA=mix(deep_color.a,crest_color.a,ripple); }"
	material.shader = shader
	water.material_override = material
	root.add_child(water)

func _make_bridge(root: Node3D, z: float, span: float) -> void:
	var bridge_length := span + 2.6
	_make_box(root,"RiverBridgeDeck",Vector3(0,0.18,z),Vector3(BRIDGE_WIDTH,0.26,bridge_length),Color(0.22,0.13,0.065),true)
	var ramp_length := 1.5
	var ramp_angle := atan(0.21 / ramp_length)
	var ramp_offset := bridge_length * 0.5 + ramp_length * 0.5 - 0.06
	_make_bridge_ramp(root, "BridgeApproachRampNorth", Vector3(0,0.135,z-ramp_offset), Vector3(BRIDGE_WIDTH-0.28,0.14,ramp_length), -ramp_angle)
	_make_bridge_ramp(root, "BridgeApproachRampSouth", Vector3(0,0.135,z+ramp_offset), Vector3(BRIDGE_WIDTH-0.28,0.14,ramp_length), ramp_angle)
	var plank_count := 9
	for plank_index in range(plank_count):
		var local_z := -bridge_length * 0.42 + float(plank_index) * (bridge_length * 0.84 / float(plank_count - 1))
		_make_box(root,"BridgePlank_%02d" % plank_index,Vector3(0,0.34,z+local_z),Vector3(BRIDGE_WIDTH-0.24,0.07,0.52),Color(0.24+float(plank_index%2)*0.035,0.145,0.075),false)
	for x in [-BRIDGE_WIDTH*0.5+0.16,BRIDGE_WIDTH*0.5-0.16]:
		_make_box(root,"BridgeRail",Vector3(x,0.88,z),Vector3(0.14,1.0,span+0.7),Color(0.14,0.08,0.04),true)
		for dz in [-span*0.42,0.0,span*0.42]:
			_make_box(root,"BridgePost",Vector3(x,0.82,z+dz),Vector3(0.24,1.3,0.24),Color(0.12,0.07,0.035),false)

func _make_bridge_ramp(root: Node3D, node_name: String, pos: Vector3, size: Vector3, angle: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation.x = angle
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20,0.12,0.06)
	material.roughness = 0.86
	mesh.material_override = material
	root.add_child(mesh)
	var body := StaticBody3D.new()
	body.name = "%sCollision" % node_name
	body.position = pos
	body.rotation.x = angle
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	body.add_child(shape)

func _make_bank_barriers(root: Node3D, center_z: float, width: float, span: float) -> void:
	var side_length := (width - BRIDGE_WIDTH) * 0.5
	var side_offset := BRIDGE_WIDTH * 0.5 + side_length * 0.5
	var barrier_index := 0
	for bank_z in [center_z-span*0.5-0.18, center_z+span*0.5+0.18]:
		_make_invisible_barrier(root, "RiverBankBarrier_%d" % barrier_index, Vector3(-side_offset,0.74,bank_z), Vector3(side_length,1.48,0.34))
		barrier_index += 1
		_make_invisible_barrier(root, "RiverBankBarrier_%d" % barrier_index, Vector3(side_offset,0.74,bank_z), Vector3(side_length,1.48,0.34))
		barrier_index += 1

func _make_recovery_volumes(root: Node3D, host, center_z: float, width: float, span: float) -> void:
	var side_length := (width - BRIDGE_WIDTH) * 0.5
	var side_offset := BRIDGE_WIDTH * 0.5 + side_length * 0.5
	var recovery_index := 0
	for x in [-side_offset, side_offset]:
		var volume := Area3D.new()
		volume.name = "RiverRecoveryVolume_%d" % recovery_index
		recovery_index += 1
		volume.position = Vector3(x,-0.70,center_z)
		root.add_child(volume)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(side_length,3.0,span+0.5)
		shape.shape = box
		volume.add_child(shape)
		volume.body_entered.connect(func(body):
			if body is CharacterBody3D and host != null and host.has_method("_recover_from_river"):
				host.call("_recover_from_river", body, center_z, span)
		)

func _make_invisible_barrier(root: Node3D, node_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _make_reed(root: Node3D, pos: Vector3) -> void:
	_make_box(root,"RiverReed",pos,Vector3(0.05,0.68,0.05),Color(0.22,0.34,0.12),false)

func _make_bank_stone(root: Node3D, pos: Vector3, radius: float) -> void:
	var stone := MeshInstance3D.new()
	stone.name = "RiverBankStone_%d_%d" % [int(pos.x * 10.0), int(pos.z * 10.0)]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.2
	mesh.radial_segments = 8
	mesh.rings = 4
	stone.mesh = mesh
	stone.position = pos
	stone.scale = Vector3(1.3,0.62,0.88)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14,0.17,0.15)
	material.roughness = 0.92
	stone.material_override = material
	root.add_child(stone)

func _make_box(root: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material_override = material
	root.add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		body.position = pos
		root.add_child(body)
		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = size
		shape.shape = solid
		body.add_child(shape)
