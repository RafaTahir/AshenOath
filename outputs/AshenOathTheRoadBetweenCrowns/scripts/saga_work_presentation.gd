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
		"side_escort_01":
			_plank(game,assembly,Vector3(0,0.38,0),Vector3(1.0,0.08,0.55))
			for x in [-0.38,0.38]:
				_plank(game,assembly,Vector3(x,0.19,0),Vector3(0.08,0.38,0.48))
			var wheel := TorusMesh.new()
			wheel.inner_radius = 0.24
			wheel.outer_radius = 0.29
			wheel.rings = 16
			wheel.ring_segments = 6
			var rim := _mesh(game,assembly,wheel,Vector3(0.50,0.30,0),WOOD)
			rim.rotation.z = PI * 0.5
			var brace := _plank(game,assembly,Vector3(0.25,0.16,0),Vector3(0.55,0.10,0.12))
			brace.name = "ReliefAxleBrace"
			_plank(game,assembly,Vector3(-0.18,0.44,0),Vector3(0.38,0.04,0.30),LINEN)
		"side_escort_02":
			_plank(game,assembly,Vector3(0,0.5,0),Vector3(0.08,1.0,0.08))
			var pointer := _plank(game,assembly,Vector3(0,0.82,0),Vector3(0.62,0.10,0.04),LINEN)
			pointer.name = "ReliefRoutePointer"
		"side_escort_03":
			for x in [-0.55,0.55]:
				_plank(game,assembly,Vector3(x,0.8,0),Vector3(0.10,1.6,0.10))
			_plank(game,assembly,Vector3(0,1.6,0),Vector3(1.25,0.12,0.12))
			var foot := _plank(game,assembly,Vector3(-0.40,0.16,0),Vector3(0.35,0.10,0.55))
			foot.name = "ReliefLiftBrace"
			_rod(game,assembly,Vector3(0,1.22,0),0.015,0.70,LINEN)
			var load := game._make_role_visual("crate","environment",Vector3.ONE * 0.25) as Node3D
			if load != null:
				load.name = "ReliefLoad"
				load.position.y = 0.85
				assembly.add_child(load)
				var wrapping := _plank(game,load,Vector3(0,0.15,0),Vector3(0.65,0.03,0.65),LINEN)
				wrapping.visible = outcome == "medicine"
			_plank(game,assembly,Vector3(0,0.18,0),Vector3(0.70,0.08,0.62))
		"side_escort_04":
			for index in range(3):
				var coil := TorusMesh.new()
				coil.inner_radius = 0.14 - float(index) * 0.025
				coil.outer_radius = coil.inner_radius + 0.015
				coil.rings = 12
				coil.ring_segments = 4
				var rope := _mesh(game,assembly,coil,Vector3(0,0.04,0),LINEN)
				rope.name = "ReliefCoil" + str(index)
		"side_escort_06":
			_plank(game,assembly,Vector3(0,0.45,0),Vector3(1.10,0.07,0.56))
			for x in [-0.43,0.43]:
				_plank(game,assembly,Vector3(x,0.22,0),Vector3(0.07,0.44,0.45))
			for x in [-0.26,0.26]:
				_rod(game,assembly,Vector3(x,0.51,0.04),0.10,0.04,WOOD)
			var supplies := _plank(game,assembly,Vector3(0,0.54,-0.12),Vector3(0.35,0.10,0.20),LINEN)
			supplies.name = "ReliefReceivedLoad"
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
			_build_watercourse(game, assembly)
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

static func _build_watercourse(game, assembly: Node3D) -> void:
	# A shallow bank-side run, not another crossing or a change to river collision.
	var natural := Node3D.new()
	natural.name = "NaturalRun"
	assembly.add_child(natural)
	var points := [Vector3(-1.3,0,0), Vector3(0,0,0.65), Vector3(1.2,0,1.5), Vector3(2.3,0,1.5)]
	for index in range(points.size()-1):
		_water_segment(game, natural, points[index], points[index+1], false)
	var side := Node3D.new()
	side.name = "ContainedChannel"
	assembly.add_child(side)
	_water_segment(game, side, Vector3(-1.3,0,0), Vector3(-0.45,0,-0.2), true)
	_water_segment(game, side, Vector3(-0.45,0,-0.2), Vector3(2.3,0,-0.2), true)
	var debris := Node3D.new()
	debris.name = "InletDebris"
	assembly.add_child(debris)
	for index in range(3):
		var piece := _plank(game,debris,Vector3(-1.0+index*0.12,0.09,index*0.12),Vector3(0.55,0.08,0.07))
		piece.rotation.y = -0.5 + index*0.45
	var screen := Node3D.new()
	screen.name = "ReusedScreen"
	screen.position = Vector3(-0.45,0,-0.2)
	screen.rotation.y = PI*0.5
	assembly.add_child(screen)
	for index in range(7):
		_plank(game,screen,Vector3(-0.27+index*0.09,0.26,0),Vector3(0.025,0.45,0.05))
	for y in [0.08,0.44]:
		_plank(game,screen,Vector3(0,y,0),Vector3(0.65,0.04,0.06))
	var gate := _plank(game,screen,Vector3(0,0.25,0.04),Vector3(0.56,0.35,0.025))
	gate.name = "DrainGate"
	var stand := Node3D.new()
	stand.name = "CollectionStand"
	stand.position = Vector3(2.3,0,-0.2)
	assembly.add_child(stand)
	_plank(game,stand,Vector3(0,0.31,0),Vector3(0.82,0.06,0.55))
	for x in [-0.32,0.32]:
		_plank(game,stand,Vector3(x,0.15,0),Vector3(0.06,0.30,0.5))
	for index in range(2):
		var pot := Node3D.new()
		pot.name = "CleanPot" + str(index)
		pot.position = Vector3(-0.21+index*0.42,0.35,0)
		stand.add_child(pot)
		_rod(game,pot,Vector3(0,0.11,0),0.13,0.22,Color(0.39,0.29,0.20))
		var rim := TorusMesh.new()
		rim.inner_radius = 0.105
		rim.outer_radius = 0.14
		rim.rings = 12
		rim.ring_segments = 5
		_mesh(game,pot,rim,Vector3(0,0.23,0),Color(0.48,0.35,0.23))
		_rod(game,pot,Vector3(0,0.222,0),0.104,0.006,Color(0.05,0.19,0.21))
		var waiting := Node3D.new()
		waiting.name = "WaitingPot" + str(index)
		waiting.position = Vector3(2.0+index*0.42,0,-0.8)
		assembly.add_child(waiting)
		_mesh(game,waiting,pot.get_child(0).mesh,Vector3(0,0.11,0),Color(0.39,0.29,0.20))
		_mesh(game,waiting,rim,Vector3(0,0.23,0),Color(0.48,0.35,0.23))
		_rod(game,waiting,Vector3(0,0.222,0),0.104,0.006,Color(0.17,0.14,0.09))
	var work_anchor := Marker3D.new()
	work_anchor.name = "GateWorkAnchor"
	work_anchor.position = Vector3(0,0,-0.65)
	assembly.add_child(work_anchor)
	var pot_anchor := Marker3D.new()
	pot_anchor.name = "PotWorkAnchor"
	pot_anchor.position = Vector3(2.3,0,-0.8)
	assembly.add_child(pot_anchor)

static func _water_segment(game, parent: Node3D, start: Vector3, end: Vector3, contained: bool) -> void:
	var segment := Node3D.new()
	segment.position = (start + end)*0.5
	segment.rotation.y = atan2((end-start).x, (end-start).z)
	parent.add_child(segment)
	var length := start.distance_to(end)
	_plank(game,segment,Vector3(0,0.018,0),Vector3(0.56,0.03,length),WOOD if contained else Color(0.13,0.16,0.13))
	for x in [-0.27,0.27]:
		_plank(game,segment,Vector3(x,0.075,0),Vector3(0.055,0.12 if contained else 0.04,length),WOOD if contained else Color(0.25,0.29,0.24))
	var surface := PlaneMesh.new()
	surface.size = Vector2(0.45,length)
	var water := _mesh(game,segment,surface,Vector3(0,0.045,0),Color(0.05,0.19,0.21))
	water.name = "Water"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var river := game.zone_root.get_node_or_null("LivingRiverSection/FlowingRiverWater") as MeshInstance3D
	if river != null:
		# Share the existing river clock/material, without a second per-frame owner.
		water.material_override = river.material_override

static func _sync_watercourse(assembly: Node3D, game) -> void:
	const ID := "saga_wyc_q05"
	var outcome := str(game.story_state.get_flag(ID + "_outcome", ""))
	var known := outcome in ["side_channel", "natural_run"]
	var work := _progress(game,ID,"clear_and_set") if known else 0.0
	var pots := _progress(game,ID,"place_clean_pots") if known else 0.0
	assembly.get_node("InletDebris").visible = work < 1.0/3.0
	var side := assembly.get_node("ContainedChannel") as Node3D
	side.visible = outcome == "side_channel" and work >= 2.0/3.0
	for run: Node3D in [assembly.get_node("NaturalRun"), side]:
		for segment: Node3D in run.get_children():
			segment.get_node("Water").visible = known and work >= 1.0
	var screen := assembly.get_node("ReusedScreen") as Node3D
	# Natural flow bypasses the reused screen, stored clear on the dry bank.
	screen.position = Vector3(-0.45,0,-0.2) if outcome != "natural_run" or work < 2.0/3.0 else Vector3(-0.65,0,-0.85)
	screen.rotation.z = 0.0 if work >= 2.0/3.0 else -0.35
	(screen.get_node("DrainGate") as Node3D).position.y = 0.56 if work >= 1.0 else 0.25
	var stand := assembly.get_node("CollectionStand") as Node3D
	var destination := Vector3(2.3,0,1.5) if outcome == "natural_run" else Vector3(2.3,0,-0.2)
	stand.position = destination if work >= 1.0 else Vector3(2.3,0,-0.2)
	(assembly.get_node("PotWorkAnchor") as Node3D).position = destination + Vector3(0,0,-0.6)
	for index in range(2):
		stand.get_node("CleanPot" + str(index)).visible = pots >= float(index+1)/3.0
		assembly.get_node("WaitingPot" + str(index)).visible = pots < float(index+1)/3.0

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
	if id == "saga_wyc_q05":
		_sync_watercourse(assembly,game)
	var complete: bool = game.quests.is_completed(id)
	var axle := assembly.get_node_or_null("ReliefAxleBrace") as Node3D
	if axle != null:
		var needed := 1.0 / 3.0 if str(game.story_state.get_flag(id + "_outcome", "")) == "wheel" else 2.0 / 3.0
		axle.rotation.z = 0.0 if _progress(game,id,"steady_arrival") >= needed else -0.22
	var pointer := assembly.get_node_or_null("ReliefRoutePointer") as Node3D
	if pointer != null:
		pointer.rotation.y = (0.4 if str(game.story_state.get_flag(id + "_outcome", "")) == "work_line" else -0.4) if _progress(game,id,"mark_passage") >= 1.0 else PI * 0.5
	var foot := assembly.get_node_or_null("ReliefLiftBrace") as Node3D
	if foot != null: foot.rotation.z = 0.0 if _progress(game,id,"brace_lift") > 0.0 else -0.25
	var relief_load := assembly.get_node_or_null("ReliefLoad") as Node3D
	if relief_load != null: relief_load.position.y = lerpf(0.85, 0.23, _progress(game,id,"lower_load"))
	var received := assembly.get_node_or_null("ReliefReceivedLoad") as Node3D
	if received != null: received.visible = complete or _progress(game,id,"handover_relief") >= 1.0
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
	var load := assembly.get_node_or_null("ReliefLoad") as Node3D
	if load != null and mode == "work":
		var quest := str(assembly.get_meta("quest", ""))
		if quest == "side_escort_03" and bool(assembly.get_meta("lowering", false)):
			load.position.y = lerpf(0.85, 0.23, (float(part) + amount) / 3.0)
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
	if words.contains("clapper"):
		var stone := game._make_role_visual("forest_rock", "environment", Vector3(0.24,0.12,0.20)) as Node3D
		if stone != null: parent.add_child(stone)
		for index in range(3):
			_plank(game,parent,Vector3(-0.15 + float(index) * 0.12,0.12,0),Vector3(0.025,0.012,0.16),IRON)
		_rod(game,parent,Vector3(0.18,0.10,0.05),0.012,0.20,LINEN).rotation.z = PI * 0.5
		return true
	if words.contains("windward post"):
		_plank(game,parent,Vector3(0,0.50,0),Vector3(0.10,1.0,0.10))
		for index in range(4):
			_plank(game,parent,Vector3(0.01,0.55 + float(index) * 0.07,0.056),Vector3(0.09,0.04,0.006),Color(0.50,0.51,0.48))
		return true
	if words.contains("blade marks"):
		var stone := game._make_role_visual("forest_rock", "environment", Vector3(0.25,0.10,0.25)) as Node3D
		if stone != null: parent.add_child(stone)
		for index in range(3):
			var mark := _plank(game,parent,Vector3(float(index) * 0.06,0.10,0),Vector3(0.01,0.01,0.30),IRON)
			mark.rotation.y = 0.4
		return true
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
