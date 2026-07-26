extends RefCounted

const BRIDGE_WIDTH := 5.4
const BANK_CLEARANCE := 1.15

var visual_box_batches: Dictionary = {}
var stone_transforms: Array[Transform3D] = []

func build(context: ZoneBuildContext, center_z: float, width: float, span: float) -> Dictionary:
	visual_box_batches.clear()
	stone_transforms.clear()
	var root := Node3D.new()
	root.name = "LivingRiverSection"
	root.set_meta("river_center_z", center_z)
	root.set_meta("river_span", span)
	root.set_meta("bridge_half_width", BRIDGE_WIDTH * 0.5)
	context.add_node(root)

	_make_box(root, "RiverBed", Vector3(0,-1.72,center_z), Vector3(width,0.20,span), Color(0.055,0.075,0.065), false)
	_make_box(root, "NorthBank", Vector3(0,0.10,center_z-span*0.68), Vector3(width,0.24,1.05), Color(0.16,0.13,0.085), false)
	_make_box(root, "SouthBank", Vector3(0,0.10,center_z+span*0.68), Vector3(width,0.24,1.05), Color(0.15,0.12,0.08), false)
	_make_bank_slope(root, "NorthBankSlope", Vector3(0,-0.05,center_z-span*0.51), width, -8.0)
	_make_bank_slope(root, "SouthBankSlope", Vector3(0,-0.05,center_z+span*0.51), width, 8.0)
	_make_water(root, center_z, width, span)
	_make_river_audio(root, center_z)
	_make_bridge(root, center_z, span)
	_make_bank_barriers(root, center_z, width, span)
	_make_recovery_volumes(root, context, center_z, width, span)

	for x in [-18.0,-14.0,-10.0,-6.0,6.0,10.0,14.0,18.0]:
		_make_reed(root, Vector3(x,0.34,center_z-span*0.54))
		_make_reed(root, Vector3(x+1.2,0.34,center_z+span*0.54))
	for x in [-16.0,-11.0,-7.0,7.5,12.0,16.5]:
		_make_bank_stone(root, Vector3(x,0.18,center_z-span*0.59), 0.48 + absf(x) * 0.012)
		_make_bank_stone(root, Vector3(x+1.4,0.18,center_z+span*0.59), 0.44 + absf(x) * 0.010)
	_flush_visual_batches(root)
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
	shader.code = "shader_type spatial; render_mode blend_mix,depth_draw_opaque,cull_back; uniform vec4 deep_color:source_color=vec4(0.025,0.13,0.19,0.92); uniform vec4 shallow_color:source_color=vec4(0.11,0.34,0.39,0.88); uniform vec4 foam_color:source_color=vec4(0.70,0.78,0.72,0.72); void vertex(){ VERTEX.y += sin(VERTEX.x*1.7+TIME*1.55)*0.022 + sin(VERTEX.z*3.1-TIME*1.05)*0.013; } void fragment(){ float current=sin(UV.x*60.0-TIME*2.1+sin(UV.y*20.0))*0.5+0.5; float shore=1.0-smoothstep(0.0,0.16,min(UV.y,1.0-UV.y)); float foam=shore*smoothstep(0.56,0.86,current); vec3 water=mix(deep_color.rgb,shallow_color.rgb,shore*0.70+current*0.12); ALBEDO=mix(water,foam_color.rgb,foam*0.72); ROUGHNESS=mix(0.16,0.42,shore); METALLIC=0.02; ALPHA=mix(deep_color.a,foam_color.a,foam); }"
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
	var foundation_index := 0
	for x in [-BRIDGE_WIDTH * 0.34, BRIDGE_WIDTH * 0.34]:
		for dz in [-span * 0.43, span * 0.43]:
			_make_box(root, "BridgeStoneFoundation_%d" % foundation_index, Vector3(x, -0.44, z + dz), Vector3(0.72, 0.82, 0.72), Color(0.20, 0.22, 0.20), false)
			foundation_index += 1

func _make_bank_slope(root: Node3D, node_name: String, pos: Vector3, width: float, angle_degrees: float) -> void:
	var slope := MeshInstance3D.new()
	slope.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.26, 0.92)
	slope.mesh = mesh
	slope.position = pos
	slope.rotation_degrees.x = angle_degrees
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.12, 0.075)
	material.roughness = 0.96
	slope.material_override = material
	root.add_child(slope)

func _make_river_audio(root: Node3D, center_z: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "RiverCurrentAudio"
	player.position = Vector3(0, -0.10, center_z)
	player.max_distance = 24.0
	player.unit_size = 5.0
	player.volume_db = -31.0
	player.stream = _river_loop()
	player.autoplay = true
	root.add_child(player)

func _river_loop() -> AudioStreamWAV:
	var rate := 11025
	var frames := rate
	var data := PackedByteArray()
	data.resize(frames * 2)
	var smooth := 0.0
	var seed := 1979
	for index in range(frames):
		seed = int((seed * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(seed % 65536) / 32768.0) - 1.0
		smooth = lerpf(smooth, noise, 0.035)
		var wave := sin(float(index) / float(rate) * TAU * 42.0) * 0.10
		var sample := int(clampf((smooth * 0.42 + wave) * 32767.0, -32767.0, 32767.0))
		data[index * 2] = sample & 0xff
		data[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream

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

func _make_recovery_volumes(root: Node3D, context: ZoneBuildContext, center_z: float, width: float, span: float) -> void:
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
			if body is CharacterBody3D:
				context.recover_from_river(body, center_z, span)
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
	var marker := Node3D.new()
	marker.name = "RiverBankStone_%d_%d" % [int(pos.x * 10.0), int(pos.z * 10.0)]
	marker.position = pos
	root.add_child(marker)
	var scale_value := Vector3(radius * 2.6, radius * 0.744, radius * 1.76)
	stone_transforms.append(Transform3D(Basis.IDENTITY.scaled(scale_value), pos))

func _make_box(root: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var marker := Node3D.new()
	marker.name = node_name
	marker.position = pos
	root.add_child(marker)
	var batch_key := "river_boxes"
	if not visual_box_batches.has(batch_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.roughness = 0.82
		material.vertex_color_use_as_albedo = true
		visual_box_batches[batch_key] = {"material": material, "transforms": [], "colors": []}
	visual_box_batches[batch_key].transforms.append(Transform3D(Basis.IDENTITY.scaled(size), pos))
	visual_box_batches[batch_key].colors.append(color)
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

func _flush_visual_batches(root: Node3D) -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	for batch_key in visual_box_batches:
		var entry: Dictionary = visual_box_batches[batch_key]
		var transforms: Array = entry.transforms
		var colors: Array = entry.colors
		if transforms.is_empty():
			continue
		var batch := MultiMeshInstance3D.new()
		batch.name = "RiverBoxBatch_%s" % str(batch_key)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = box_mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
			multimesh.set_instance_color(index, colors[index])
		batch.multimesh = multimesh
		batch.material_override = entry.material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(batch)
	if stone_transforms.is_empty():
		return
	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.5
	stone_mesh.height = 1.0
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 4
	var stones := MultiMeshInstance3D.new()
	stones.name = "RiverBankStoneBatch"
	var stone_multimesh := MultiMesh.new()
	stone_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	stone_multimesh.mesh = stone_mesh
	stone_multimesh.instance_count = stone_transforms.size()
	for index in range(stone_transforms.size()):
		stone_multimesh.set_instance_transform(index, stone_transforms[index])
	stones.multimesh = stone_multimesh
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.14,0.17,0.15)
	stone_material.roughness = 0.92
	stones.material_override = stone_material
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stones)
