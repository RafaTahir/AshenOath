extends RefCounted

## Retained craft materials and reusable joinery, projected from durable work.
## No process callbacks: the one activity director refreshes changed state.
const Rules = preload("res://scripts/community_campaign.gd")
const WOOD := Color(0.27,0.18,0.11)
const LINEN := Color(0.61,0.58,0.46)
const IRON := Color(0.20,0.23,0.22)

static func build(context: ZoneBuildContext) -> void:
	var root := Node3D.new()
	root.name = "CommunityWork"
	context.add_node(root)
	var host = context.construction_host()
	for id: String in Rules.data().work:
		var task: Dictionary = Rules.data().work[id]
		if str(task.region) != context.zone_id: continue
		var assembly := Node3D.new()
		assembly.name = id
		assembly.position = Vector3(task.position[0],0,task.position[2]) + Vector3(0,0,-0.65)
		assembly.set_meta("community_work",id)
		root.add_child(assembly)
		match id:
			"kitchen_trestle", "kitchen_places", "promise_meal":
				_table(host,assembly)
				for x in [-0.4,0.0,0.4]: _bowl(host,assembly,Vector3(x,0.84,0))
				var brace := _box(host,assembly,Vector3(0,0.38,0),Vector3(1.15,0.08,0.10),WOOD)
				brace.name = "WorkingPart"
				brace.set_meta("unfinished_rotation",Vector3(0,0,0.32))
			"kitchen_screen":
				for x in [-0.75,0.75]: _box(host,assembly,Vector3(x,1,0),Vector3(0.1,2,0.1),WOOD)
				var screen := _box(host,assembly,Vector3(0,1.2,0),Vector3(1.5,1.15,0.035),LINEN)
				screen.name = "WorkingPart"
				screen.set_meta("unfinished_rotation",Vector3(0,0,0.2))
			"crossing_beam", "crossing_rail":
				for x in [-0.6,0.6]: _box(host,assembly,Vector3(x,0.5,0),Vector3(0.15,1,0.15),WOOD)
				var beam := _box(host,assembly,Vector3(0,0.85,0),Vector3(1.65,0.14,0.18),WOOD)
				beam.name = "WorkingPart"
				beam.set_meta("unfinished_rotation",Vector3(0,0,0.18))
				for x in [-0.58,0.58]: _box(host,assembly,Vector3(x,0.85,0),Vector3(0.055,0.18,0.21),IRON)
			"crossing_load", "ferry_load":
				_table(host,assembly,0.3)
				var load := _box(host,assembly,Vector3(0,0.6,0),Vector3(0.7,0.44,0.48),LINEN)
				load.name = "WorkingPart"
				load.set_meta("unfinished_rotation",Vector3(0,0,0.16))
				_wheel(host,assembly,Vector3(0.65,0.32,0))
			"ferry_landing":
				for x in [-0.7,0.7]: _box(host,assembly,Vector3(x,0.12,0),Vector3(0.1,0.24,1.1),WOOD)
				var deck := _box(host,assembly,Vector3(0,0.25,0),Vector3(1.5,0.10,1.0),WOOD)
				deck.name = "WorkingPart"
				deck.set_meta("unfinished_rotation",Vector3(0,0,0.10))
			"ferry_rope":
				for x in [-0.7,0.7]: _box(host,assembly,Vector3(x,0.6,0),Vector3(0.12,1.2,0.12),WOOD)
				var line := _box(host,assembly,Vector3(0,0.85,0),Vector3(1.45,0.026,0.026),LINEN)
				line.name = "WorkingPart"
				line.set_meta("unfinished_rotation",Vector3(0,0,0.13))
				_wheel(host,assembly,Vector3(-0.7,0.84,0.1))
			"refuge_bunks", "refuge_places":
				for x in [-0.6,0.6]:
					for z in [-0.8,0.8]: _box(host,assembly,Vector3(x,0.3,z),Vector3(0.09,0.6,0.09),WOOD)
				_box(host,assembly,Vector3(0,0.48,0),Vector3(1.3,0.09,1.9),WOOD)
				var bed := _box(host,assembly,Vector3(0,0.57,0),Vector3(1.2,0.10,1.8),LINEN)
				bed.name = "WorkingPart"
				bed.set_meta("unfinished_rotation",Vector3(0,0,0.10))
				_box(host,assembly,Vector3(0,0.65,-0.6),Vector3(0.8,0.14,0.35),LINEN.lightened(0.1))
			"refuge_shelves", "promise_records":
				for x in [-0.6,0.6]: _box(host,assembly,Vector3(x,0.8,0),Vector3(0.09,1.6,0.4),WOOD)
				for y in [0.35,0.85,1.35]:
					_box(host,assembly,Vector3(0,y,0),Vector3(1.25,0.07,0.5),WOOD)
					for x in [-0.35,0.1]: _box(host,assembly,Vector3(x,y+0.065,0),Vector3(0.32,0.06,0.38),LINEN)
				var lining := _box(host,assembly,Vector3(0,1.1,0.21),Vector3(1.1,0.45,0.015),LINEN)
				lining.name = "WorkingPart"
				lining.set_meta("unfinished_rotation",Vector3(0,0,0.15))
			"promise_alarm":
				for x in [-0.5,0.5]: _box(host,assembly,Vector3(x,1,0),Vector3(0.1,2,0.1),WOOD)
				_box(host,assembly,Vector3(0,1.95,0),Vector3(1.1,0.12,0.12),WOOD)
				var bell := CylinderMesh.new()
				bell.top_radius=0.12; bell.bottom_radius=0.26; bell.height=0.4
				var hung := _mesh(host,assembly,bell,Vector3(0,1.65,0),IRON)
				hung.name = "WorkingPart"
				hung.set_meta("unfinished_rotation",Vector3(0,0,0))
				_box(host,assembly,Vector3(0.2,0.95,0),Vector3(0.02,1.15,0.02),LINEN)
		# These are visible supports with explicit collision and a clear 0.65 m
		# work edge. Actor/player capsules never share the prop's centre.
		if id not in ["refuge_bunks","refuge_places","ferry_landing"]:
			ZoneBuildContext.add_collision_box(root,id+"Support",assembly.position+Vector3(0,0.5,-0.25),Vector3(1.4,1,0.45))
	_choice_arrangements(host,root,context.zone_id)
	refresh(context.zone_root,context.story_state)

static func ensure_stations(game, zone: String) -> void:
	# Called after publication, when the actual region floor and spatial owner
	# exist. Reuse the measured native-work geometry; no duplicate generic table
	# or guessed hand target is added over the player's construction assemblies.
	var stations = load("res://scripts/living_cast_stations.gd")
	var host = ZoneBuildContext.active_host(game)
	for id: String in Rules.data().station_assignments.get(zone,{}):
		var row: Dictionary = Rules.data().station_assignments[zone][id]
		if game.zone_root.find_child(str(row.node),true,false) != null: continue
		var stand := Vector3(row.stand[0],row.stand[1],row.stand[2])
		var station: Node3D
		if id in ["nessa","elna","toma","nera","vale","merrow","edric"]:
			var assembly: Node3D = stations._add_regional_work(game,id,row.stand,"_community")
			if assembly != null: station=assembly.get_node_or_null(str(row.node))
		elif id=="anwen":
			var table: Node3D = stations.add_care_table(game.zone_root)
			if table != null:
				table.position=stand-Vector3(0,0,.78)
				station=table.get_node_or_null("LifeWork_anwen")
		elif id in ["mira","rook"]:
			var assembly := Node3D.new()
			assembly.name="CommunityMeasured_"+id
			assembly.position=stand-(Vector3(-.35,0,-1.12) if id=="mira" else Vector3(-1.78,0,0))
			game.zone_root.add_child(assembly)
			if id=="mira":
				load("res://scripts/greyfen_social_presentation.gd").apply(assembly,"mira_apothecary")
				ZoneBuildContext.add_collision_box(assembly,"CounterSolid",Vector3(0,.38,0),Vector3(1.75,.76,1.25))
			else:
				var mesh: Mesh = stations._retained_timber_structure()
				if mesh != null:
					var table := MeshInstance3D.new()
					table.mesh=mesh
					table.scale=Vector3(2.8/2.2,1,1.8/1.5)
					assembly.add_child(table)
				ZoneBuildContext.add_collision_box(assembly,"TableSolid",Vector3(0,.465,0),Vector3(2.8,.93,1.8))
			stations.decorate_place(assembly,"mira_apothecary" if id=="mira" else "common_table")
			station=assembly.get_node_or_null("LifeWork_"+id)
			var prop: Node3D = assembly.get_node_or_null("MiraDryingLeaves" if id=="mira" else "RookStationSatchel")
			if station!=null and prop!=null: station.set_meta("task_prop",weakref(prop))
		elif id=="tor":
			var assembly := Node3D.new()
			assembly.name="CommunityMeasured_tor"
			assembly.position=stand-Vector3(-1.40,0,.45)
			game.zone_root.add_child(assembly)
			for x in [-1.60,-.84]: _box(host,assembly,Vector3(x,.46,.10),Vector3(.12,.92,.14),WOOD)
			var beam := _box(host,assembly,Vector3(-1.22,.86,.10),Vector3(1.1,.12,.14),WOOD)
			beam.name="SupportedRepairBeam"
			ZoneBuildContext.add_collision_box(assembly,"BeamSolid",Vector3(-1.22,.46,.10),Vector3(1.1,.92,.14))
			station=stations.add_work(assembly,"tor",Vector3(-1.22,.92,.10),Vector3(-1.40,0,.45),Vector3.ZERO,0.0)
			station.get_node("WorkRight").position=Vector3(-1.22,1.185,.10)
			station.set_meta("task_prop",weakref(beam))
		if station==null:
			push_error("Community station is missing verified geometry: "+zone+"/"+id)
			continue
		station.name=str(row.node)
		station.set_meta("work_identity",id)

static func _choice_arrangements(host, root: Node3D, zone: String) -> void:
	var table := Node3D.new()
	table.name = "CommunityPublicTable"
	var board: Array = Rules.BOARDS[zone].position
	table.position = Vector3(board[0],0,board[2]-0.7)
	root.add_child(table)
	_table(host,table)
	for x in [-0.35,0,0.35]: _box(host,table,Vector3(x,0.83,0),Vector3(0.28,0.025,0.35),LINEN)
	var groups := {"central":Vector3(-5,0,4.2),"households":Vector3(-5,0,4.2)} if zone=="lantern_reach" else {"distributed":Vector3(-7,0,4.2),"protected":Vector3(-7,0,4.2)}
	for choice: String in groups:
		var assembly := Node3D.new()
		assembly.name = "Arrangement_"+choice
		assembly.position = groups[choice]
		assembly.set_meta("community_choice",choice)
		assembly.set_meta("community_choice_flag","community_distribution" if zone=="lantern_reach" else "community_records")
		root.add_child(assembly)
		_table(host,assembly)
		for index in range(3):
			var at := Vector3(-0.4+index*0.4,0.87,0)
			if choice=="central": _bowl(host,assembly,at)
			elif choice=="households": _box(host,assembly,at+Vector3(0,0.1,0),Vector3(0.32,0.2,0.3),LINEN)
			elif choice=="distributed": _box(host,assembly,at,Vector3(0.32,0.035,0.38),LINEN)
			else:
				_box(host,assembly,at,Vector3(0.32,0.07,0.38),WOOD)
				_box(host,assembly,at+Vector3(0,0.05,0),Vector3(0.04,0.015,0.4),IRON)
	if zone == "lantern_reach":
		for choice in ["crossing","ferry"]:
			var route := Node3D.new()
			route.name = "PublicRoute_"+choice
			route.set_meta("community_choice",choice)
			route.set_meta("community_choice_flag","community_route")
			root.add_child(route)
			if choice=="crossing":
				for x in range(3,11):
					_box(host,route,Vector3(x,0.12,0),Vector3(0.95,0.13,2),WOOD)
					for z in [-1.1,1.1]: _box(host,route,Vector3(x,0.65,z),Vector3(0.07,1.3,0.07),WOOD)
				for z in [-1.1,1.1]: _box(host,route,Vector3(6.5,1.2,z),Vector3(8,0.08,0.08),WOOD)
				ZoneBuildContext.add_collision_box(route,"CrossingDeck",Vector3(6.5,0.12,0),Vector3(8,0.13,2))
				for z in [-1.1,1.1]: ZoneBuildContext.add_collision_box(route,"CrossingRail",Vector3(6.5,0.65,z),Vector3(8,1.3,0.08))
			else:
				for x in [3.0,10.0]:
					_box(host,route,Vector3(x,0.8,-1),Vector3(0.15,1.6,0.15),WOOD)
				_box(host,route,Vector3(6.5,1.1,-1),Vector3(7,0.035,0.035),LINEN)
				var ferry := Node3D.new()
				ferry.name="Ferry"
				ferry.position=Vector3(3.5,0,0)
				route.add_child(ferry)
				for z in [-0.5,0,0.5]: _box(host,ferry,Vector3(0,0.15,z),Vector3(2.2,0.18,0.45),WOOD)
				for x in [-1,1]: _box(host,ferry,Vector3(x,0.45,0),Vector3(0.1,0.5,1.45),WOOD)
				ZoneBuildContext.add_collision_box(ferry,"FerryDeck",Vector3(0,0.15,0),Vector3(2.2,0.18,1.45))

static func refresh(root: Node3D, state) -> void:
	var work := root.get_node_or_null("CommunityWork")
	if work == null: return
	for assembly: Node3D in work.get_children():
		if assembly.has_meta("community_choice"):
			assembly.visible = str(state.get_flag(str(assembly.get_meta("community_choice_flag")),"")) == str(assembly.get_meta("community_choice"))
			var usable: bool = assembly.visible and (not str(assembly.name).begins_with("PublicRoute_") or Rules._true(state,"community_route_ready"))
			for shape: CollisionShape3D in assembly.find_children("*","CollisionShape3D",true,false): shape.set_deferred("disabled",not usable)
			if str(assembly.name)=="PublicRoute_ferry":
				var ferry := assembly.get_node_or_null("Ferry") as Node3D
				if ferry != null: ferry.position.x=9.5 if Rules._true(state,"community_route_load_crossed") else 3.5
		if not assembly.has_meta("community_work"): continue
		var piece := assembly.get_node_or_null("WorkingPart") as Node3D
		if piece != null: piece.rotation = Vector3.ZERO if Rules._true(state,"community_work:"+str(assembly.get_meta("community_work"))) else piece.get_meta("unfinished_rotation",Vector3.ZERO)

static func animate_work(root: Node3D, id: String, fraction: float) -> void:
	var piece := root.get_node_or_null("CommunityWork/"+id+"/WorkingPart") as Node3D
	if piece != null: piece.rotation = (piece.get_meta("unfinished_rotation",Vector3.ZERO) as Vector3).lerp(Vector3.ZERO,clampf(fraction,0,1))

static func _table(host, parent: Node3D, height: float = 0.8) -> void:
	for x in [-0.6,0.6]:
		for z in [-0.22,0.22]: _box(host,parent,Vector3(x,height*0.5,z),Vector3(0.09,height,0.09),WOOD)
	_box(host,parent,Vector3(0,height,0),Vector3(1.45,0.08,0.65),WOOD)

static func _bowl(host, parent: Node3D, position: Vector3) -> void:
	var bowl := TorusMesh.new()
	bowl.inner_radius=0.07; bowl.outer_radius=0.115; bowl.rings=12; bowl.ring_segments=6
	_mesh(host,parent,bowl,position,WOOD.lightened(0.14))

static func _wheel(host, parent: Node3D, position: Vector3) -> void:
	var rim := TorusMesh.new()
	rim.inner_radius=0.25; rim.outer_radius=0.30; rim.rings=16; rim.ring_segments=6
	_mesh(host,parent,rim,position,WOOD).rotation.z=PI*0.5

static func _box(host, parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return _mesh(host,parent,mesh,position,color)

static func _mesh(host, parent: Node3D, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.position=position
	node.material_override=host._mat(color)
	parent.add_child(node)
	return node
