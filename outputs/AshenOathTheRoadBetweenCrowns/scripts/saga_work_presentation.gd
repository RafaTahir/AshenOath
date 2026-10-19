extends RefCounted

const Records = preload("res://scripts/campaign_record_presentation.gd")
const WOOD := Color(0.27,0.17,0.09)
const IRON := Color(0.20,0.23,0.22)
const LINEN := Color(0.65,0.62,0.48)
const LEAF := Color(0.16,0.34,0.13)

static func build(game, parent: Node3D, id: String, completed: bool, outcome: String) -> void:
	var assembly := Node3D.new()
	assembly.name = "RegionalWork"
	assembly.set_meta("quest", id)
	assembly.set_meta("recorded_outcome", outcome)
	parent.add_child(assembly)
	match id:
		"saga_gre_q01", "saga_dep_q01":
			_plank(game, assembly, Vector3(0,0.45,0), Vector3(0.85,0.06,0.46))
			var beam := _plank(game, assembly, Vector3(0,0.82,0), Vector3(0.65,0.04,0.04))
			beam.rotation.z = 0.0 if completed else 0.15
			_rod(game, assembly, Vector3(0,0.62,0),0.025,0.5,IRON)
			for x in [-0.27,0.27]:
				_rod(game, assembly, Vector3(x,0.65,0),0.10,0.035,IRON)
		"saga_gre_q02":
			for x in [-0.45,0.45]:
				_plank(game,assembly,Vector3(x,0.85,0),Vector3(0.09,1.7,0.09))
			_plank(game,assembly,Vector3(0,1.65,0),Vector3(1.0,0.12,0.12))
			var bell := _rod(game,assembly,Vector3(0,1.25,0),0.19,0.27,IRON)
			bell.name = "WarningBell"
			_rod(game,assembly,Vector3(0,1.05,0),0.23,0.05,IRON)
			_rod(game,assembly,Vector3(0.30,0.80,0),0.012,1.25,LINEN)
		"saga_gre_q03":
			for x in [-0.50,0.50]:
				_plank(game,assembly,Vector3(x,0.8,0),Vector3(0.08,1.6,0.08))
			_plank(game,assembly,Vector3(0,1.60,0),Vector3(1.08,0.08,0.10))
			_plank(game,assembly,Vector3(0,0.04,0),Vector3(1.08,0.08,0.25))
			var hinge := Node3D.new()
			hinge.name = "DoorHinge"
			hinge.position.x = -0.45
			assembly.add_child(hinge)
			for index in range(6):
				_plank(game,hinge,Vector3(0.075 + index * 0.15,0.8,0),Vector3(0.14,1.5,0.035))
			_plank(game,hinge,Vector3(0.45,0.5,0.03),Vector3(0.9,0.065,0.04))
			_plank(game,hinge,Vector3(0.45,1.15,0.03),Vector3(0.9,0.065,0.04))
			_rod(game,hinge,Vector3(0.78,0.84,0.06),0.035,0.08,IRON).rotation.x = PI * 0.5
			if outcome == "braced":
				var brace := _plank(game,assembly,Vector3(0.6,0.65,-0.08),Vector3(0.09,1.2,0.09))
				brace.rotation.z = 0.12
		"saga_wyc_q02":
			for index in range(3):
				var loop := MeshInstance3D.new()
				var mesh := TorusMesh.new()
				mesh.inner_radius = 0.14
				mesh.outer_radius = 0.155
				mesh.rings = 12
				mesh.ring_segments = 5
				loop.mesh = mesh
				loop.material_override = game._mat(IRON)
				loop.position = Vector3(float(index - 1)*0.45,0.025,0)
				loop.rotation.z = 0 if completed else PI*0.35
				assembly.add_child(loop)
		"saga_wyc_q03", "saga_har_q02":
			for x in [-0.5,0.5]:
				_plank(game,assembly,Vector3(x,0.22,0),Vector3(0.08,0.44,0.4))
			_plank(game,assembly,Vector3(0,0.46,0),Vector3(1.25,0.07,0.45))
			if id == "saga_har_q02":
				for index in range(3):
					_plank(game,assembly,Vector3(-0.3+index*0.3,0.54,0),Vector3(0.22,0.035,0.32),Color(0.40,0.43,0.40))
		"saga_wyc_q05":
			for index in range(7):
				_plank(game,assembly,Vector3(-0.45+index*0.15,0.26,0),Vector3(0.025,0.45,0.05))
			for y in [0.08,0.44]:
				_plank(game,assembly,Vector3(0,y,0),Vector3(1,0.04,0.06))
			for x in [-0.35,0.35]:
				_rod(game,assembly,Vector3(x,0.12,0.42),0.12,0.20,Color(0.39,0.29,0.20))
		"saga_dep_q02", "saga_dep_q04", "saga_var_q03", "saga_har_q04", "saga_har_q05":
			if id == "saga_har_q05" and outcome == "resting_shelter":
				_shelter(game,assembly,LINEN)
			else:
				var width := 0.85 if outcome != "terrace" else 1.25
				_plank(game,assembly,Vector3(0,0.035,0),Vector3(width,0.05,0.65),Color(0.12,0.095,0.065))
				for x in [-width*0.5,width*0.5]:
					_plank(game,assembly,Vector3(x,0.13,0),Vector3(0.035,0.2,0.7))
				for z in [-0.34,0.34]:
					_plank(game,assembly,Vector3(0,0.13,z),Vector3(width,0.2,0.035))
				if completed:
					for x in [-0.2,0,0.2]:
						_rod(game,assembly,Vector3(x,0.14,0),0.016,0.18,LEAF)
						var leaf := _plank(game,assembly,Vector3(x,0.20,0),Vector3(0.15,0.012,0.04),LEAF)
						leaf.rotation.z = 0.3
		"saga_gre_q05", "saga_dep_q05":
			_shelter(game,assembly,LINEN if outcome in ["courtyard","relief_store"] else WOOD)
			_record(assembly,Vector3(0.20,0.48,0.12))
		"saga_roa_q04":
			for index in range(3):
				_plank(game,assembly,Vector3(float(index-1)*0.5,0.55,0),Vector3(0.05,1.1,0.05))
				for mark in range(index+1):
					_plank(game,assembly,Vector3(float(index-1)*0.5,0.8+mark*0.07,0.04),Vector3(0.16,0.025,0.02),LINEN)
				if outcome == "hooded_lamps":
					_rod(game,assembly,Vector3(float(index-1)*0.5,1.1,0),0.07,0.12,IRON)
		"saga_har_q01", "saga_var_q05":
			for index in range(3):
				var stone := game._make_role_visual("forest_rock", "environment", Vector3(0.14,0.22,0.10)) as Node3D
				if stone != null:
					stone.position.x = float(index-1)*0.45
					assembly.add_child(stone)
			_record(assembly,Vector3(0,0.4,0.12))
		_:
			_record(assembly,Vector3(0,0.48,0))
			_plank(game,assembly,Vector3(0,0.44,0),Vector3(0.75,0.05,0.42))
			for x in [-0.29,0.29]:
				_plank(game,assembly,Vector3(x,0.22,0),Vector3(0.04,0.44,0.32))

static func _shelter(game, parent: Node3D, color: Color) -> void:
	for x in [-0.7,0.7]:
		for z in [-0.4,0.4]:
			_plank(game,parent,Vector3(x,0.85,z),Vector3(0.055,1.7,0.055))
	var cover := _plank(game,parent,Vector3(0,1.73,0),Vector3(1.65,0.04,1.1),color)
	cover.rotation.z = 0.045
	_plank(game,parent,Vector3(0,0.42,0),Vector3(1.1,0.06,0.4))

static func _record(parent: Node3D, pos: Vector3) -> void:
	var record := Records.make_visual("register_mira")
	if record != null:
		record.position = pos
		parent.add_child(record)

static func _plank(game, parent: Node3D, pos: Vector3, size: Vector3, color: Color = WOOD) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(game,parent,mesh,pos,color)

static func _rod(game, parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius*1.05
	mesh.height = height
	mesh.radial_segments = 10
	return _mesh(game,parent,mesh,pos,color)

static func _mesh(game, parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = game._mat(color)
	node.position = pos
	parent.add_child(node)
	return node
