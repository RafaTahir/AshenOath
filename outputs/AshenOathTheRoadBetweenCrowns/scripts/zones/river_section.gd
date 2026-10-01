extends RefCounted

const RiverMotionController = preload("res://scripts/river_motion_controller.gd")
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const StonePier = preload("res://assets/landscape/bridge_stone_pier.res")

const BRIDGE_WIDTH := BridgeSurfaceContract.DECK_WIDTH
const BANK_CLEARANCE := 1.15

var visual_box_batches: Dictionary = {}
var stone_transforms: Array[Transform3D] = []
var bridge_timber_material: StandardMaterial3D

func build(context: ZoneBuildContext, center_z: float, width: float, span: float, collision_only := false) -> Dictionary:
	visual_box_batches.clear()
	stone_transforms.clear()
	var root := Node3D.new()
	root.name = "LivingRiverSection"
	root.set_meta("river_center_z", center_z)
	root.set_meta("river_span", span)
	root.set_meta("bridge_half_width", BridgeSurfaceContract.HALF_WIDTH)
	root.set_meta("ground_owns_bank_surface", context.zone_id == "greyfen")
	context.add_node(root)
	_make_bridge_safety_colliders(root, center_z, span)
	_make_bank_barriers(root, center_z, width, span)
	_make_recovery_volumes(root, context, center_z, width, span)
	if collision_only:
		root.set_meta("opening_boot_collision_only", true)
	else:
		hydrate_visuals(root, center_z, width, span)
	return {
		"root":root,
		"center_z":center_z,
		"span":span,
		"north_safe":Vector3(0,0.85,center_z-span*0.5-BANK_CLEARANCE),
		"south_safe":Vector3(0,0.85,center_z+span*0.5+BANK_CLEARANCE),
	}

func hydrate_visuals(root: Node3D, center_z: float, width: float, span: float) -> void:
	if root == null or bool(root.get_meta("river_visuals_ready", false)):
		return
	visual_box_batches.clear()
	stone_transforms.clear()
	bridge_timber_material = StandardMaterial3D.new()
	bridge_timber_material.albedo_texture = preload("res://assets_external/textures/runtime/timber_albedo.jpg")
	bridge_timber_material.vertex_color_use_as_albedo = true
	bridge_timber_material.uv1_triplanar = true
	bridge_timber_material.uv1_world_triplanar = true
	bridge_timber_material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	bridge_timber_material.roughness = 0.86

	_make_box(root, "RiverBed", Vector3(0,-1.72,center_z), Vector3(width,0.20,span), Color(0.055,0.075,0.065), false)
	if not bool(root.get_meta("ground_owns_bank_surface", false)):
		_make_bank_slope(root, "NorthBankSlope", center_z - span * 0.5, width, -1.0)
		_make_bank_slope(root, "SouthBankSlope", center_z + span * 0.5, width, 1.0)
	_make_water(root, center_z, width, span)
	_make_shore_foam(root, center_z, width, span)
	_make_shore_wetness(root, center_z, width, span)
	var motion := RiverMotionController.new()
	motion.name = "RiverMotionController"
	motion.set_meta("ticket", "WATER-002")
	motion.configure(center_z, width, span)
	root.add_child(motion)
	_make_river_audio(root, center_z)
	_make_bridge(root, center_z, span)

	for x in [-18.0,-14.0,-10.0,-6.0,6.0,10.0,14.0,18.0]:
		_make_reed(root, Vector3(x,0.34,center_z-span*0.54))
		_make_reed(root, Vector3(x+1.2,0.34,center_z+span*0.54))
	for x in [-16.0,-11.0,-7.0,7.5,12.0,16.5]:
		_make_bank_stone(root, Vector3(x,0.18,center_z-span*0.59), 0.48 + absf(x) * 0.012)
		_make_bank_stone(root, Vector3(x+1.4,0.18,center_z+span*0.59), 0.44 + absf(x) * 0.010)
	_flush_visual_batches(root)
	root.set_meta("opening_boot_collision_only", false)
	root.set_meta("river_visuals_ready", true)

func _make_water(root: Node3D, center_z: float, width: float, span: float) -> void:
	var water := MeshInstance3D.new()
	water.name = "FlowingRiverWater"
	water.mesh = _water_channel_mesh(width, span)
	water.position = Vector3(0,-0.24,center_z)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 deep_color : source_color = vec4(0.010, 0.040, 0.065, 0.96);
uniform vec4 shallow_color : source_color = vec4(0.028, 0.145, 0.180, 0.92);
uniform vec4 foam_color : source_color = vec4(0.32, 0.58, 0.52, 0.64);
uniform float flow_speed = 1.0;

void vertex() {
	float flow = TIME * flow_speed;
	float wave_a = sin(VERTEX.x * 0.44 - flow * 0.95 + sin(VERTEX.z * 3.2) * 0.7);
	float wave_b = sin(VERTEX.x * 1.08 - flow * 1.34 + VERTEX.z * 4.0);
	VERTEX.y += wave_a * 0.020 + wave_b * 0.009;
}

void fragment() {
	vec2 flow_uv = UV + vec2(-TIME * 0.035 * flow_speed, sin(UV.x * 17.0 + TIME * 0.3) * 0.008);
	float bank_distance = min(UV.y, 1.0 - UV.y);
	float shore = 1.0 - smoothstep(0.0, 0.22, bank_distance);
	float depth = smoothstep(0.0, 0.48, bank_distance);
	float current_a = sin(flow_uv.x * 24.0 + sin(flow_uv.y * 17.0 + TIME * 0.45) * 2.1) * 0.5 + 0.5;
	float current_b = sin(flow_uv.x * 51.0 + flow_uv.y * 29.0 + sin(flow_uv.y * 13.0) * 2.8) * 0.5 + 0.5;
	float current = mix(current_a, current_b, 0.32);
	float broken_ripple = sin(flow_uv.x * 43.0 + flow_uv.y * 37.0 + sin(flow_uv.x * 13.0 + flow_uv.y * 21.0) * 3.0);
	float ripple = smoothstep(0.78, 0.98, broken_ripple * 0.5 + 0.5);
	float foam = shore * smoothstep(0.62, 0.90, current);
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, depth * 0.88);
	water += current * vec3(0.010, 0.025, 0.023) + ripple * vec3(0.007, 0.019, 0.018);
	ALBEDO = mix(water, foam_color.rgb, foam * 0.32);
	ROUGHNESS = mix(0.44, 0.26, depth);
	METALLIC = 0.02;
	ALPHA = mix(shallow_color.a, deep_color.a, depth);
	vec3 ripple_normal = normalize(vec3((current_a - 0.5) * 0.11, (current_b - 0.5) * 0.09, 1.0));
	NORMAL_MAP = ripple_normal * 0.5 + 0.5;
}
"""
	material.shader = shader
	water.material_override = material
	water.set_meta("water_role", "WATER-002")
	root.add_child(water)

func _water_channel_mesh(width: float, span: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := maxi(24, int(width / 1.2))
	var cross_sections := 8
	for x_index in range(sections):
		var x_left := float(x_index) / float(sections)
		var x_right := float(x_index + 1) / float(sections)
		for z_index in range(cross_sections):
			var z_near := float(z_index) / float(cross_sections)
			var z_far := float(z_index + 1) / float(cross_sections)
			var a := _water_channel_vertex(x_left, z_near, width, span)
			var b := _water_channel_vertex(x_right, z_near, width, span)
			var c := _water_channel_vertex(x_left, z_far, width, span)
			var d := _water_channel_vertex(x_right, z_far, width, span)
			for item in [[a, Vector2(x_left, z_near)], [b, Vector2(x_right, z_near)], [c, Vector2(x_left, z_far)], [b, Vector2(x_right, z_near)], [d, Vector2(x_right, z_far)], [c, Vector2(x_left, z_far)]]:
				surface.set_normal(Vector3.UP)
				surface.set_uv(item[1])
				surface.add_vertex(item[0])
	surface.generate_tangents()
	return surface.commit()

func _water_channel_vertex(x_fraction: float, z_fraction: float, width: float, span: float) -> Vector3:
	var x := (x_fraction - 0.5) * width
	var bank_wobble := sin(x * 0.71) * 0.10 + sin(x * 1.87 + 0.8) * 0.055
	var half_span := span * 0.5 - 0.15
	var north := -half_span + bank_wobble
	var south := half_span + sin(x * 0.83 + 1.7) * 0.09 - sin(x * 1.53) * 0.055
	return Vector3(x, 0.0, lerpf(north, south, z_fraction))

func _make_shore_foam(root: Node3D, center_z: float, width: float, span: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.38, 0.36)
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var foam := MeshInstance3D.new()
		foam.name = "RiverShoreFoam_%s" % ("North" if side < 0.0 else "South")
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for bank_side in [-1.0, 1.0]:
			var x_start := -width * 0.5 + 0.35 if bank_side < 0.0 else BRIDGE_WIDTH * 0.5 + 0.35
			var x_end := -BRIDGE_WIDTH * 0.5 - 0.35 if bank_side < 0.0 else width * 0.5 - 0.35
			var segments := maxi(8, int((x_end - x_start) / 1.4))
			for index in range(segments):
				if (index + (1 if side > 0.0 else 0)) % 4 == 0:
					continue
				var x_a := lerpf(x_start, x_end, float(index) / float(segments)) + 0.08
				var x_b := lerpf(x_start, x_end, float(index + 1) / float(segments)) - 0.10
				var ripple_a := sin(x_a * 1.71 + side * 2.0) * 0.045
				var ripple_b := sin(x_b * 1.71 + side * 2.0) * 0.045
				var bank_z: float = center_z + side * (span * 0.5 - 0.14)
				var near_a := Vector3(x_a, -0.193, bank_z + ripple_a)
				var near_b := Vector3(x_b, -0.193, bank_z + ripple_b)
				var far_a := near_a - Vector3(0, 0, side * (0.07 + float(index % 3) * 0.02))
				var far_b := near_b - Vector3(0, 0, side * (0.05 + float((index + 1) % 3) * 0.02))
				for point in [near_a, far_a, near_b, near_b, far_a, far_b]:
					surface.set_color(Color(0.62, 0.77, 0.70) if index % 3 == 1 else Color(0.45, 0.65, 0.61))
					surface.add_vertex(point)
		foam.mesh = surface.commit()
		foam.material_override = material
		root.add_child(foam)

func _make_shore_wetness(root: Node3D, center_z: float, width: float, span: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.12, 0.095)
	material.roughness = 0.98
	for side in [-1.0, 1.0]:
		var wet := MeshInstance3D.new()
		wet.name = "RiverBankWetness_%s" % ("North" if side < 0.0 else "South")
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for reach in [[-width * 0.5, -BRIDGE_WIDTH * 0.5 - 0.20], [BRIDGE_WIDTH * 0.5 + 0.20, width * 0.5]]:
			var segments := ceili((float(reach[1]) - float(reach[0])) / 0.85)
			for index in range(segments):
				var x0 := lerpf(float(reach[0]), float(reach[1]), float(index) / segments)
				var x1 := lerpf(float(reach[0]), float(reach[1]), float(index + 1) / segments)
				var edge0 := _water_channel_vertex(x0 / width + 0.5, 0.0 if side < 0 else 1.0, width, span).z + center_z
				var edge1 := _water_channel_vertex(x1 / width + 0.5, 0.0 if side < 0 else 1.0, width, span).z + center_z
				_add_bank_quad(surface, Vector3(x0, -0.136, edge0 + side * 0.18), Vector3(x1, -0.136, edge1 + side * 0.18), Vector3(x0, -0.24, edge0 + side * 0.05), Vector3(x1, -0.24, edge1 + side * 0.05), side)
		surface.generate_normals()
		wet.mesh = surface.commit()
		wet.material_override = material
		root.add_child(wet)

func _make_bridge(root: Node3D, z: float, span: float) -> void:
	var bridge_length := BridgeSurfaceContract.bridge_length(span)
	# The zone ground builder owns one continuous, collider-tested bridge corridor.
	# Keep this bridge section visual-only so a second deck or apron shape cannot
	# introduce a seam at the bank joins.
	_make_box(root,"RiverBridgeDeckVisual",Vector3(0,0.055,z),Vector3(BRIDGE_WIDTH-0.12,0.06,bridge_length),Color(0.55,0.46,0.36),false)
	var ramp_length := 1.8
	var ramp_offset := bridge_length * 0.5 + ramp_length * 0.5 - 0.06
	_make_bridge_ramp(root, "BridgeApproachRampNorth", Vector3(0,0.09,z-ramp_offset), Vector3(BRIDGE_WIDTH-0.28,0.18,ramp_length))
	_make_bridge_ramp(root, "BridgeApproachRampSouth", Vector3(0,0.09,z+ramp_offset), Vector3(BRIDGE_WIDTH-0.28,0.18,ramp_length))
	var plank_count := maxi(13, int(ceil(bridge_length / 0.46)))
	for plank_index in range(plank_count):
		var local_z := -bridge_length * 0.47 + float(plank_index) * (bridge_length * 0.94 / float(plank_count - 1))
		var plank_tint := 0.025 * float(plank_index % 3)
		_make_box(root,"BridgePlank_%02d" % plank_index,Vector3(0,0.12,z+local_z),Vector3(BRIDGE_WIDTH-0.24,0.075,0.42),Color(0.72+plank_tint,0.63+plank_tint*0.55,0.50+plank_tint*0.20),false)
	# Open rails preserve the safety silhouette without creating the opaque
	# one-metre-high wall produced by the former full-length rail slabs.
	var rail_length := bridge_length - 0.42
	var post_count := 5
	for x in [-BRIDGE_WIDTH*0.5+0.16,BRIDGE_WIDTH*0.5-0.16]:
		for rail_y in [0.58, 0.98]:
			_make_box(root,"BridgeRail",Vector3(x,rail_y,z),Vector3(0.14,0.12,rail_length),Color(0.58,0.48,0.37),false)
		for post_index in range(post_count):
			var dz := -rail_length * 0.5 + float(post_index) * rail_length / float(post_count - 1)
			_make_box(root,"BridgePost",Vector3(x,0.64,z+dz),Vector3(0.21,1.10,0.21),Color(0.54,0.43,0.31),false)
	# Interlocking masonry courses support the deck from the river bed.
	var foundation_material := StandardMaterial3D.new()
	foundation_material.albedo_color = Color(0.38,0.40,0.37)
	foundation_material.roughness = 0.94
	foundation_material.vertex_color_use_as_albedo = true
	var foundation_index := 0
	for x in [-BRIDGE_WIDTH * 0.34, BRIDGE_WIDTH * 0.34]:
		for dz in [-span * 0.5 + 0.25, span * 0.5 - 0.25]:
			_make_bridge_abutment(root, "BridgeStoneFoundation_%d" % foundation_index, Vector3(x, -0.25, z + dz), foundation_material)
			foundation_index += 1

func _make_bridge_abutment(root: Node3D, node_name: String, pos: Vector3, material: Material) -> void:
	var stone := MeshInstance3D.new()
	stone.name = node_name
	stone.mesh = StonePier
	stone.position = Vector3(pos.x, -1.62, pos.z)
	stone.material_override = material
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stone)

func _make_bridge_safety_colliders(root: Node3D, z: float, span: float) -> void:
	for side in [-1.0, 1.0]:
		_make_invisible_barrier(
			root,
			"BridgeSafetyRail_%s" % ("West" if side < 0.0 else "East"),
			Vector3(side * (BRIDGE_WIDTH * 0.5 - 0.16), 0.88, z),
			Vector3(0.14, 1.0, span + 0.7)
		)

func _make_bank_slope(root: Node3D, node_name: String, waterline_z: float, width: float, bank_side: float) -> void:
	var slope := MeshInstance3D.new()
	slope.name = node_name
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for shore_side in [-1.0, 1.0]:
		var x_start := -width * 0.5 if shore_side < 0.0 else BRIDGE_WIDTH * 0.5 + 0.12
		var x_end := -BRIDGE_WIDTH * 0.5 - 0.12 if shore_side < 0.0 else width * 0.5
		var segments := maxi(8, int(ceil((x_end - x_start) / 1.6)))
		for index in range(segments):
			var x_a := lerpf(x_start, x_end, float(index) / float(segments))
			var x_b := lerpf(x_start, x_end, float(index + 1) / float(segments))
			var wobble_a := sin(x_a * 0.83 + bank_side) * 0.10 + sin(x_a * 1.91) * 0.055
			var wobble_b := sin(x_b * 0.83 + bank_side) * 0.10 + sin(x_b * 1.91) * 0.055
			var land_a := Vector3(x_a, 0.035, waterline_z + bank_side * (0.92 + wobble_a))
			var land_b := Vector3(x_b, 0.035, waterline_z + bank_side * (0.92 + wobble_b))
			var lip_a := Vector3(x_a, -0.105, waterline_z + bank_side * (0.15 + wobble_a * 0.4))
			var lip_b := Vector3(x_b, -0.105, waterline_z + bank_side * (0.15 + wobble_b * 0.4))
			var water_a := Vector3(x_a, -0.25, waterline_z - bank_side * 0.08)
			var water_b := Vector3(x_b, -0.25, waterline_z - bank_side * 0.08)
			_add_bank_quad(surface, land_a, land_b, lip_a, lip_b, bank_side)
			_add_bank_quad(surface, lip_a, lip_b, water_a, water_b, bank_side)
	surface.generate_normals()
	slope.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets_external/textures/runtime/wet_mud_albedo.jpg")
	material.albedo_color = Color(0.57, 0.62, 0.54)
	material.roughness = 0.96
	slope.material_override = material
	root.add_child(slope)

func _add_bank_quad(surface: SurfaceTool, land_a: Vector3, land_b: Vector3, water_a: Vector3, water_b: Vector3, bank_side: float) -> void:
	var points: Array = [land_a, water_a, land_b, land_b, water_a, water_b] if bank_side > 0.0 else [land_a, land_b, water_a, land_b, water_b, water_a]
	for point in points:
		surface.set_uv(Vector2(point.x * 0.22, point.z * 0.22))
		surface.add_vertex(point)

func _make_river_audio(root: Node3D, center_z: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "RiverCurrentAudio"
	player.position = Vector3(0, -0.10, center_z)
	player.max_distance = 24.0
	player.unit_size = 5.0
	player.volume_db = -30.0
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

func _make_bridge_ramp(root: Node3D, node_name: String, pos: Vector3, size: Vector3) -> void:
	# The continuous corridor below owns collision. Batched low boards give the
	# approach the same timber rhythm as the deck without a snagging ramp shape.
	var count := maxi(3, int(round(size.z / 0.45)))
	var anchor := Node3D.new()
	anchor.name = node_name
	anchor.position = pos
	anchor.set_meta("visual_only", true)
	anchor.set_meta("batched_board_count", count)
	root.add_child(anchor)
	var step := size.z / float(count)
	for index in range(count):
		var board_z := pos.z - size.z * 0.5 + step * (float(index) + 0.5)
		_make_box(root, "ApproachBoard_%s_%d" % [node_name, index], Vector3(pos.x, 0.03, board_z), Vector3(size.x, 0.06, step - 0.025), Color(0.68, 0.59, 0.46), false)

func _make_bridge_apron_collision(root: Node3D, node_name: String, pos: Vector3, size: Vector3, slope_sign: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var half_width := size.x * 0.5
	var half_length := size.z * 0.5
	var outer_z := slope_sign * half_length
	var inner_z := -slope_sign * half_length
	var bottom_y := -size.y * 0.5
	var outer_top_y := 0.0 - pos.y
	var inner_top_y := BridgeSurfaceContract.DECK_COLLISION_TOP - pos.y
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-half_width, bottom_y, outer_z),
		Vector3(half_width, bottom_y, outer_z),
		Vector3(-half_width, bottom_y, inner_z),
		Vector3(half_width, bottom_y, inner_z),
		Vector3(-half_width, outer_top_y, outer_z),
		Vector3(half_width, outer_top_y, outer_z),
		Vector3(-half_width, inner_top_y, inner_z),
		Vector3(half_width, inner_top_y, inner_z),
	])
	shape.shape = wedge
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
	var recovery_handler := context.river_recovery_handler()
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
		volume.body_entered.connect(recovery_handler.bind(center_z, span))

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
	var batch_key := "bridge_timber" if node_name.begins_with("Bridge") or node_name.begins_with("ApproachBoard") else "river_boxes"
	if not visual_box_batches.has(batch_key):
		var material := bridge_timber_material if batch_key == "bridge_timber" else StandardMaterial3D.new()
		if batch_key == "river_boxes":
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
