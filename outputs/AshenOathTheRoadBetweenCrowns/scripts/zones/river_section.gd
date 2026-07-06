extends RefCounted

func build(parent: Node3D, context: Dictionary) -> Dictionary:
	var host = context.host
	var center_z := float(context.get("center_z", 0.0))
	var width := float(context.get("width", 44.0))
	var span := float(context.get("span", 5.5))
	var root := Node3D.new()
	root.name = "LivingRiverSection"
	parent.add_child(root)
	_make_box(root, "RiverBed", Vector3(0,-2.15,center_z), Vector3(width,0.25,span), Color(0.055,0.075,0.065), true)
	_make_box(root, "NorthBank", Vector3(0,0.18,center_z-span*0.58), Vector3(width,0.45,0.95), Color(0.16,0.13,0.085), true)
	_make_box(root, "SouthBank", Vector3(0,0.18,center_z+span*0.58), Vector3(width,0.45,0.95), Color(0.15,0.12,0.08), true)
	var water := MeshInstance3D.new(); water.name = "FlowingRiverWater"
	var water_mesh := BoxMesh.new(); water_mesh.size = Vector3(width,0.08,span-0.6); water.mesh = water_mesh
	water.position = Vector3(0,0.02,center_z)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode blend_mix,depth_draw_opaque,cull_back; uniform vec4 deep_color:source_color=vec4(0.035,0.18,0.25,0.88); uniform vec4 crest_color:source_color=vec4(0.18,0.52,0.62,0.82); void vertex(){ VERTEX.y += sin(VERTEX.x*1.7+TIME*1.9)*0.025 + sin(VERTEX.z*3.1-TIME*1.2)*0.015; } void fragment(){ float ripple=sin(UV.x*55.0-TIME*2.4+sin(UV.y*18.0))*0.5+0.5; ALBEDO=mix(deep_color.rgb,crest_color.rgb,ripple*0.24); ROUGHNESS=0.20; METALLIC=0.12; ALPHA=mix(deep_color.a,crest_color.a,ripple); }"
	mat.shader = shader
	water.material_override = mat; root.add_child(water)
	var volume := Area3D.new(); volume.name = "SwimmableRiverVolume"; volume.position = Vector3(0,-0.95,center_z); root.add_child(volume)
	var volume_shape := CollisionShape3D.new(); var volume_box := BoxShape3D.new(); volume_box.size = Vector3(width-1.0,2.0,span-0.8); volume_shape.shape = volume_box; volume.add_child(volume_shape)
	volume.body_entered.connect(func(body):
		if body.has_method("enter_water"): body.enter_water({"surface_y":0.08,"current":Vector3(0.32,0,0),"safe_exit":Vector3(0,0.8,center_z-span*0.72)})
	)
	volume.body_exited.connect(func(body):
		if body.has_method("exit_water"): body.exit_water()
	)
	_make_bridge(root, center_z)
	for x in [-18.0,-14.0,-10.0,-6.0,6.0,10.0,14.0,18.0]:
		_make_reed(root, Vector3(x,0.38,center_z-span*0.44))
		_make_reed(root, Vector3(x+1.2,0.38,center_z+span*0.44))
	for x in [-16.0,-11.0,-7.0,7.5,12.0,16.5]:
		_make_bank_stone(root, Vector3(x,0.22,center_z-span*0.49), 0.55 + absf(x) * 0.015)
		_make_bank_stone(root, Vector3(x+1.4,0.20,center_z+span*0.49), 0.48 + absf(x) * 0.012)
	if host != null:
		host.call("_make_village_place", "river_water", "village_place", "Draw clean river water", Vector3(-5.8,0.1,center_z-span*0.46), Vector3(1.1,0.4,0.8), Color(0.10,0.30,0.38))
	return {"root":root,"water":volume,"safe_exit":Vector3(0,0.8,center_z-span*0.72)}

func _make_bridge(root: Node3D, z: float) -> void:
	_make_box(root,"RiverBridgeDeck",Vector3(0,0.28,z),Vector3(4.8,0.34,6.2),Color(0.22,0.13,0.065),true)
	for plank_index in range(9):
		_make_box(root,"BridgePlank_%02d" % plank_index,Vector3(0,0.48,z-2.72+plank_index*0.68),Vector3(4.55,0.08,0.58),Color(0.24+float(plank_index%2)*0.035,0.145,0.075),false)
	for x in [-2.15,2.15]:
		_make_box(root,"BridgeRail",Vector3(x,0.95,z),Vector3(0.16,1.15,6.2),Color(0.14,0.08,0.04),true)
		for dz in [-2.6,-1.3,0.0,1.3,2.6]: _make_box(root,"BridgePost",Vector3(x,0.9,z+dz),Vector3(0.28,1.45,0.28),Color(0.12,0.07,0.035),false)

func _make_reed(root: Node3D, pos: Vector3) -> void:
	_make_box(root,"RiverReed",pos,Vector3(0.05,0.75,0.05),Color(0.22,0.34,0.12),false)

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
	var mesh := MeshInstance3D.new(); mesh.name=node_name; var box:=BoxMesh.new(); box.size=size; mesh.mesh=box; mesh.position=pos
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.82; mesh.material_override=mat; root.add_child(mesh)
	if collision:
		var body:=StaticBody3D.new(); body.position=pos; root.add_child(body); var shape:=CollisionShape3D.new(); var solid:=BoxShape3D.new(); solid.size=size; shape.shape=solid; body.add_child(shape)
