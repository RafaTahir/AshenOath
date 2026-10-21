extends RefCounted

const Records = preload("res://scripts/campaign_record_presentation.gd")
const WOOD := Color(0.27,0.17,0.09)
const IRON := Color(0.20,0.23,0.22)
const LINEN := Color(0.65,0.62,0.48)
const LEAF := Color(0.16,0.34,0.13)

static func build(game, parent: Node3D, id: String, completed: bool, outcome: String) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "RegionalWork"
	assembly.set_meta("quest", id)
	assembly.set_meta("recorded_outcome", outcome)
	parent.add_child(assembly)
	match id:
		"saga_gre_q01", "saga_dep_q01":
			_plank(game, assembly, Vector3(0,0.45,0), Vector3(0.85,0.06,0.46))
			var beam := _plank(game, assembly, Vector3(0,0.82,0), Vector3(0.65,0.04,0.04))
			beam.name = "ScaleBeam"
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
			var brake := _plank(game,assembly,Vector3(0.41,0.65,0.06),Vector3(0.17,0.04,0.05))
			brake.name = "BellBrake"
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
				loop.name = "SnareLoop" + str(index)
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
			var gate := _plank(game,assembly,Vector3(0,0.25,0.04),Vector3(0.7,0.35,0.025))
			gate.name = "DrainGate"
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
				for index in range(3):
					var shoot := Node3D.new()
					shoot.name = "Seedling" + str(index)
					shoot.position.x = float(index - 1) * 0.2
					assembly.add_child(shoot)
					_rod(game,shoot,Vector3(0,0.14,0),0.016,0.18,LEAF)
					var leaf := _plank(game,shoot,Vector3(0,0.20,0),Vector3(0.15,0.012,0.04),LEAF)
					leaf.rotation.z = 0.3
					shoot.visible = completed
		"saga_gre_q05", "saga_dep_q05":
			_shelter(game,assembly,LINEN if outcome in ["courtyard","relief_store"] else WOOD)
			_record(assembly,Vector3(0.20,0.48,0.12))
		"saga_roa_q04":
			for index in range(3):
				var post := Node3D.new()
				post.name = "SignalPost" + str(index)
				assembly.add_child(post)
				_plank(game,post,Vector3(0,0.55,0),Vector3(0.05,1.1,0.05))
				for mark in range(index+1):
					_plank(game,post,Vector3(0,0.8+mark*0.07,0.04),Vector3(0.16,0.025,0.02),LINEN)
				if outcome == "hooded_lamps":
					_rod(game,post,Vector3(0,1.1,0),0.07,0.12,IRON)
		"saga_roa_q05":
			for x in [-0.50,0.50]:
				_plank(game,assembly,Vector3(x,0.55,0),Vector3(0.08,1.1,0.08))
			var beam := _plank(game,assembly,Vector3(0,0.75,0),Vector3(1.25,0.08,0.08))
			beam.name = "RetiredTollBeam"
			_record(assembly,Vector3(0.4,0.5,0.22))
		"saga_wyc_q04", "saga_dep_q03":
			var hinge := Node3D.new()
			hinge.name = "ScreenHinge"
			hinge.position.x = -0.45
			assembly.add_child(hinge)
			for index in range(5):
				_plank(game,hinge,Vector3(0.1+float(index)*0.17,0.45,0),Vector3(0.14,0.85,0.025))
			_record(assembly,Vector3(0,0.38,-0.16))
		"saga_roa_q02":
			_plank(game,assembly,Vector3(0,0.5,0),Vector3(0.08,1.0,0.08))
			_plank(game,assembly,Vector3(0,0.78,0.05),Vector3(0.6,0.28,0.025),LINEN)
			for index in range(3):
				var coil := TorusMesh.new()
				coil.inner_radius = 0.14-float(index)*0.025
				coil.outer_radius = coil.inner_radius+0.015
				coil.rings = 12
				coil.ring_segments = 4
				_mesh(game,assembly,coil,Vector3(0.25,0.04,0.13),LINEN)
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
	return assembly

static func _progress(game, id: String, objective: String) -> float:
	if game.quests.is_objective_done(id, objective) or game.quests.is_completed(id):
		return 1.0
	for step: Array in preload("res://scripts/saga_catalog.gd").QUESTS[id].steps:
		if str(step[0]) == objective:
			var total: int = step[4].size() if step[4] is Array and not step[4].is_empty() else 1
			return clampf(float(game.story_state.get_flag(id + ":" + objective + ":part", 0)) / float(total), 0.0, 1.0)
	return 0.0

static func sync_progress(assembly: Node3D, game, id: String) -> void:
	if not is_instance_valid(assembly):
		return
	var complete: bool = game.quests.is_completed(id)
	var beam := assembly.get_node_or_null("ScaleBeam") as Node3D
	if beam != null:
		beam.rotation.z = 0.0 if complete or _progress(game,id,"weigh_next_batch") > 0.0 or _progress(game,id,"mark_next_load") > 0.0 else 0.15
	var brake := assembly.get_node_or_null("BellBrake") as Node3D
	if brake != null:
		brake.rotation.z = -0.45 if _progress(game,id,"seat_counterweight") > 0.0 and _progress(game,id,"seat_counterweight") < 1.0 else 0.0
	var door := assembly.get_node_or_null("DoorHinge") as Node3D
	if door != null:
		var part := int(game.story_state.get_flag(id + ":check_clearance:part", 0))
		door.rotation.y = -PI*0.5 if not complete and part == 1 else 0.0
	var screen := assembly.get_node_or_null("ScreenHinge") as Node3D
	if screen != null:
		screen.rotation.y = -PI*0.48 if complete or _progress(game,id,"open_blind") > 0.0 or _progress(game,id,"clear_entry") >= 1.0 else 0.0
	for index in range(3):
		var snare := assembly.get_node_or_null("SnareLoop" + str(index)) as Node3D
		if snare != null:
			snare.rotation.z = 0.0 if _progress(game,id,"release_line") >= float(index+1)/3.0 else PI*0.35
		var shoot := assembly.get_node_or_null("Seedling" + str(index)) as Node3D
		if shoot != null:
			shoot.visible = complete or _progress(game,id,"plant_trial") > 0.0 or _progress(game,id,"store_reserve") > 0.0
		var post := assembly.get_node_or_null("SignalPost" + str(index)) as Node3D
		if post != null:
			var sites: Array = preload("res://scripts/saga_catalog.gd").PART_SITES["saga_roa_q04:set_markers"]
			var local_site: Vector3 = preload("res://scripts/saga_catalog.gd").SITES["marsh_crossing"][str(sites[index])]
			post.position = assembly.to_local(game.zone_root.to_global(local_site))
			post.rotation.z = 0.0 if _progress(game,id,"set_markers") >= float(index+1)/3.0 else 0.28
	var gate := assembly.get_node_or_null("DrainGate") as Node3D
	if gate != null:
		gate.position.y = 0.48 if _progress(game,id,"clear_and_set") >= 1.0 else 0.25
	var toll := assembly.get_node_or_null("RetiredTollBeam") as Node3D
	if toll != null and _progress(game,id,"open_lane") > 0.0:
		toll.position = Vector3(0.65,0.06,-0.3)
		toll.rotation.y = PI*0.5
	var cover := assembly.get_node_or_null("WorkCover") as Node3D
	if cover != null and id == "saga_dep_q05":
		cover.scale.x = maxf(0.15, _progress(game,id,"fit_cover"))

static func animate_work(assembly: Node3D, mode: String, part: int, amount: float) -> void:
	if not is_instance_valid(assembly):
		return
	if mode == "door" and part < 2:
		var hinge := assembly.get_node_or_null("DoorHinge") as Node3D
		if hinge != null:
			hinge.rotation.y = -PI*0.5*(amount if part == 0 else 1.0-amount)
	elif mode == "bell":
		var bell := assembly.get_node_or_null("WarningBell") as Node3D
		if bell != null:
			bell.rotation.z = sin(amount*TAU*2.0)*0.18*(1.0-amount)

static func carried_item(game, label: String) -> Node3D:
	if not is_instance_valid(game.player) or game.player.animation_driver == null:
		return null
	var skeleton: Skeleton3D = game.player.animation_driver.get_skeleton()
	if skeleton == null:
		return null
	var bone := -1
	for alias: String in ["hand_l", "LeftHand", "hand.L", "mixamorig:LeftHand"]:
		bone = skeleton.find_bone(alias)
		if bone >= 0:
			break
	if bone < 0:
		return null
	var hand := BoneAttachment3D.new()
	hand.name = "RegionalCarriedSupply"
	hand.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(hand)
	var bundle := Node3D.new()
	bundle.name = "Supply"
	hand.add_child(bundle)
	var inherited := skeleton.global_basis.get_scale().abs()
	bundle.scale = Vector3(1.0/maxf(inherited.x,0.001),1.0/maxf(inherited.y,0.001),1.0/maxf(inherited.z,0.001))
	bundle.position = Vector3(0,-0.10/maxf(inherited.y,0.001),0)
	if label.to_lower().contains("stone"):
		var stone := game._make_role_visual("forest_rock", "environment", Vector3(0.055,0.045,0.055)) as Node3D
		if stone != null:
			bundle.add_child(stone)
	elif label.to_lower().contains("cop") or label.to_lower().contains("record"):
		var record := Records.make_visual("register_mira") as Node3D
		if record != null:
			record.scale *= 0.55
			bundle.add_child(record)
	elif label.to_lower().contains("fill") or label.to_lower().contains("bundle") or label.to_lower().contains("coat"):
		_rod(game,bundle,Vector3(0,-0.06,0),0.10,0.24,LINEN)
		_rod(game,bundle,Vector3(0,0.07,0),0.035,0.025,WOOD)
	elif label.to_lower().contains("cup") or label.to_lower().contains("kettle") or label.to_lower().contains("tray"):
		_rod(game,bundle,Vector3(0,-0.08,0),0.09,0.18,IRON if label.to_lower().contains("kettle") else WOOD)
	else:
		for index in range(3):
			_plank(game,bundle,Vector3(float(index-1)*0.07,0,0),Vector3(0.06,0.08,0.32))
		_plank(game,bundle,Vector3(0,0.045,0),Vector3(0.23,0.012,0.035),LINEN)
	return hand

static func clue_visual(game, parent: Node3D, prompt: String) -> bool:
	var words := prompt.to_lower()
	if words.contains("track") or words.contains("hoofprint") or words.contains("scrape"):
		for index in range(4):
			var print_mesh := SphereMesh.new()
			print_mesh.radius = 0.055
			print_mesh.height = 0.015
			print_mesh.radial_segments = 8
			print_mesh.rings = 4
			_mesh(game,parent,print_mesh,Vector3(-0.07 if index%2==0 else 0.07,0.012,float(index)*0.18-0.25),Color(0.12,0.10,0.08))
		return true
	if words.contains("scar") or words.contains("feather sign") or (words.contains("boundary") and not words.contains("growth")) or words.contains("notch"):
		_plank(game,parent,Vector3(0,0.45,0),Vector3(0.09,0.9,0.07))
		for index in range(2):
			var notch := _plank(game,parent,Vector3(0.01,0.64+float(index)*0.07,0.04),Vector3(0.12,0.018,0.012),LINEN)
			notch.rotation.z = -0.35
		return true
	if words.contains("stump") or words.contains("fresh cut") or words.contains("living boundary growth"):
		_rod(game,parent,Vector3(0,0.16,0),0.20,0.32,WOOD)
		_rod(game,parent,Vector3(0,0.325,0),0.17,0.01,Color(0.57,0.43,0.27))
		return true
	if words.contains("sack") or words.contains("bundle") or words.contains("compost"):
		_rod(game,parent,Vector3(0,0.18,0),0.18,0.36,LINEN)
		_rod(game,parent,Vector3(0,0.375,0),0.08,0.035,WOOD)
		return true
	return false

static func _shelter(game, parent: Node3D, color: Color) -> void:
	for x in [-0.7,0.7]:
		for z in [-0.4,0.4]:
			_plank(game,parent,Vector3(x,0.85,z),Vector3(0.055,1.7,0.055))
	var cover := _plank(game,parent,Vector3(0,1.73,0),Vector3(1.65,0.04,1.1),color)
	cover.name = "WorkCover"
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
