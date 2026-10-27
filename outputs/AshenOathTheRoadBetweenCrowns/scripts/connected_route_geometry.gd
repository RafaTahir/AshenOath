extends RefCounted

const Sectors = preload("res://scripts/world_sector_manifest.gd")
static var _door_meshes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _shapes: Dictionary = {}
static var _landmark_box: BoxMesh

static func open_authored_door(door: MeshInstance3D) -> void:
	if door.mesh == null or door.mesh.get_surface_count() < 2 or door.has_meta("hinged_authored_door"): return
	var source := door.mesh as ArrayMesh
	if source == null: return
	var materials: Array[Material] = []
	for i in range(source.get_surface_count()):
		materials.append(door.get_active_material(i))
		door.set_surface_override_material(i,null)
	var key := source.get_rid()
	if not _door_meshes.has(key):
		var frame := ArrayMesh.new()
		var leaf := ArrayMesh.new()
		for i in range(source.get_surface_count()):
			var mesh := leaf if i == 1 else frame
			mesh.add_surface_from_arrays(source.surface_get_primitive_type(i),source.surface_get_arrays(i))
		_door_meshes[key] = [frame,leaf]
	var parts: Array = _door_meshes[key]
	door.mesh = parts[0]
	var surface := 0
	for i in range(materials.size()):
		if i == 1: continue
		door.set_surface_override_material(surface,materials[i]); surface += 1
	var hinge := Node3D.new(); hinge.name = "OpenDoorHinge"
	var leaf := MeshInstance3D.new(); leaf.mesh = parts[1]
	hinge.position.x = leaf.mesh.get_aabb().position.x
	leaf.position.x = -hinge.position.x
	leaf.material_override = materials[1]
	leaf.cast_shadow = door.cast_shadow
	door.add_child(hinge); hinge.add_child(leaf)
	hinge.rotation.y = PI*0.5
	door.set_meta("hinged_authored_door",true)

static func install(context: ZoneBuildContext) -> void:
	if context.zone_root.has_node("ConnectedRoads"): return
	var roads := Node3D.new()
	roads.name = "ConnectedRoads"
	context.add_node(roads)
	var stone := context.zone_id in ["vargan_approach","vargan_court","record_hall","undercroft"]
	var ground := context.make_world_material("cobblestone" if stone else "forest_ground",Color(0.43,0.47,0.40)).duplicate() as BaseMaterial3D
	var banks := context.make_world_material("medieval_brick" if stone else "forest_ground",Color(0.39,0.43,0.35)).duplicate() as BaseMaterial3D
	ground.cull_mode = BaseMaterial3D.CULL_DISABLED; banks.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.emission_enabled = true; ground.emission = Color(0.06,0.07,0.06); ground.emission_energy_multiplier = 0.2
	var timber := context.make_world_material("timber",Color(0.52,0.45,0.32))
	for edge: Dictionary in Sectors.connections(context.zone_id):
		var path := Node3D.new()
		path.name = "RoadTo_"+str(edge.target)
		path.set_meta("connected_target",str(edge.target))
		roads.add_child(path)
		var source_points := Sectors.connector_points(edge)
		var normal := Sectors.direction(str(edge.id))
		path.transform = Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),source_points[0]+normal*2.0)
		var points := PackedVector3Array([Vector3(0,0,-2),Vector3(0,0,4),Vector3(-6,0,4),Vector3(-6,0,8)])
		var width := float(edge.half_width)
		var left: PackedVector3Array = []
		var right: PackedVector3Array = []
		for i in range(points.size()):
			var incoming := (points[i]-points[maxi(0,i-1)]).normalized()
			var outgoing := (points[mini(i+1,points.size()-1)]-points[i]).normalized()
			if i == 0: incoming = outgoing
			if i == points.size()-1: outgoing = incoming
			var normal_a := incoming.cross(Vector3.UP)
			var normal_b := outgoing.cross(Vector3.UP)
			var miter := (normal_a+normal_b).normalized()
			var extent := width/maxf(0.5,miter.dot(normal_b))
			left.append(points[i]-miter*extent)
			right.append(points[i]+miter*extent)
		_strip(path,"Ground",left,right,ground,true)
		for side: PackedVector3Array in [left,right]:
			var crest: PackedVector3Array = []
			var outer: PackedVector3Array = []
			for i in range(side.size()):
				var outward := (side[i]-points[i]).normalized()
				crest.append(side[i]+outward*1.3+Vector3.UP*(4.5 if stone else 5.4+sin(float(i)*1.7)*0.35))
				outer.append(side[i]+outward*4.0)
			_strip(path,"Bank",side,crest,banks,true,"bank" if not stone else "")
			_strip(path,"BackSlope",crest,outer,banks,false,"backslope" if not stone else "")
		# Cover only the bends, keeping the entrance and regional view open.
		# This also makes the normal collision-safe camera respect the passage.
		var roof_left := PackedVector3Array([left[1]+Vector3.UP*4.5,left[2]+Vector3.UP*4.5])
		var roof_right := PackedVector3Array([right[1]+Vector3.UP*4.5,right[2]+Vector3.UP*4.5])
		_strip(path,"BendArch",roof_left,roof_right,banks,true,"arch" if not stone else "")
		_make_gate(path,edge,width,timber)
		_make_landmark(path,edge,width,timber,banks)
		path.set_meta("required_ground",true)
		var marker := context.zone_root.find_child("gate_"+str(edge.target),true,false) as Node3D
		if marker == null:
			marker = context.make_zone_gate("Road to "+str(edge.target).replace("_"," ").capitalize(),source_points[0],str(edge.target),Vector3.ZERO)
		if marker != null: marker.position = source_points[0]

static func _make_landmark(parent: Node3D, edge: Dictionary, half: float, timber: Material, stone: Material) -> void:
	var definition := Sectors.road_landmark(str(edge.source), str(edge.target))
	if definition.is_empty(): return
	# Each sector owns its side of a real paired landmark at the common plane.
	# The crossing transform places the other half opposite it, not somewhere
	# inferred from the atlas's deliberately non-geographic diagram positions.
	var landmark := Node3D.new()
	landmark.name = "RoadLandmark"
	landmark.transform = parent.transform.affine_inverse() * Sectors.crossing_frame(edge)
	landmark.set_meta("atlas_landmark", str(definition.name))
	parent.add_child(landmark)
	var h := float(definition.height)
	var x := half + 2.1
	var pieces: Array[Transform3D] = []
	var kind := str(definition.kind)
	if kind in ["aqueduct", "ruined_arch"]:
		for side in [-1.0, 1.0]:
			pieces.append(_landmark_part(Vector3(side*x,h*0.36,-1.6),Vector3(1.1,h*0.72,1.6)))
			pieces.append(_landmark_part(Vector3(side*(x-0.6),h*0.78,-1.6),Vector3(2.0,0.65,1.6),-side*0.28))
			pieces.append(_landmark_part(Vector3(side*(x-1.5),h*0.88,-1.6),Vector3(1.3,0.58,1.6),-side*0.56))
		if kind == "aqueduct":
			for side in [-1.0, 1.0]:
				pieces.append(_landmark_part(Vector3(side*(x-0.3),h,-1.6),Vector3(2.4,0.45,1.9)))
	elif kind == "bastion":
		for side in [-1.0, 1.0]:
			pieces.append(_landmark_part(Vector3(side*x,h*0.43,-1.8),Vector3(2.0,h*0.86,2.4)))
			for tooth in [-0.7, 0.0, 0.7]:
				pieces.append(_landmark_part(Vector3(side*x+tooth,h*0.92,-1.8),Vector3(0.35,h*0.16,2.4)))
	else:
		for side in [-1.0, 1.0]:
			for offset in [-0.7, 0.7]:
				pieces.append(_landmark_part(Vector3(side*x+offset,h*0.46,-1.8),Vector3(0.28,h*0.92,0.32)))
			pieces.append(_landmark_part(Vector3(side*x,h*0.74,-1.8),Vector3(2.0,0.24,2.3)))
			pieces.append(_landmark_part(Vector3(side*x,h*0.95,-1.8),Vector3(2.5,0.30,2.7)))
			if kind == "bell_frame":
				pieces.append(_landmark_part(Vector3(side*x,h*0.83,-1.8),Vector3(0.65,0.7,0.6)))
			elif kind == "beacon":
				pieces.append(_landmark_part(Vector3(side*x,h*0.84,-1.8),Vector3(0.6,0.65,0.6),0.5))
		if kind == "gantry":
			pieces.append(_landmark_part(Vector3(0,h*0.91,-1.8),Vector3(x*2.0,0.30,0.35)))
	if _landmark_box == null: _landmark_box = BoxMesh.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _landmark_box
	batch.instance_count = pieces.size()
	for i in pieces.size(): batch.set_instance_transform(i, pieces[i])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	visual.material_override = stone if kind in ["aqueduct", "ruined_arch", "bastion"] else timber
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmark.add_child(visual)

static func _landmark_part(position: Vector3, size: Vector3, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK,roll).scaled(size),position)

static func _make_gate(parent: Node3D, edge: Dictionary, half: float, material: Material) -> void:
	var gate := Node3D.new(); gate.name = "TravelGate"
	gate.transform = parent.transform.affine_inverse()*Sectors.crossing_frame(edge)
	parent.add_child(gate)
	var hinge := Node3D.new(); hinge.name = "Hinge"; hinge.position.x = -half
	gate.add_child(hinge)
	var leaf := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(half*2,4.5,0.18)
	leaf.mesh = mesh; leaf.position = Vector3(half,2.25,0); leaf.material_override = material
	hinge.add_child(leaf)
	var body := StaticBody3D.new()
	body.set_meta("walkable_support",false)
	var shape := CollisionShape3D.new()
	var box := preload("res://scripts/immutable_collision_shapes.gd").box(mesh.size)
	shape.shape = box; body.add_child(shape); leaf.add_child(body)
	for y in [0.6,3.8]:
		var band := MeshInstance3D.new()
		var strip := BoxMesh.new(); strip.size = Vector3(half*2,0.12,0.22)
		band.mesh = strip; band.position = Vector3(half,y,0); band.material_override = material
		hinge.add_child(band)

static func open_gate(root: Node3D, target: String, instant: bool) -> void:
	var gate := root.get_node_or_null("ConnectedRoads/RoadTo_"+target+"/TravelGate") as Node3D
	if gate == null: return
	var hinge := gate.get_node("Hinge") as Node3D
	if instant:
		var tween: Tween = gate.get_meta("opening_tween") if gate.has_meta("opening_tween") else null
		if tween != null and tween.is_valid(): tween.kill()
		hinge.rotation.y = PI*0.5
		_gate_collision(gate,true)
	elif not gate.has_meta("opening_tween"):
		_gate_collision(gate,false)
		var tween := gate.create_tween()
		tween.tween_property(hinge,"rotation:y",PI*0.5,0.25)
		tween.tween_callback(func():
			if is_instance_valid(gate): _gate_collision(gate,true)
		)
		gate.set_meta("opening_tween",tween)

static func close_gate(root: Node3D, target: String, actor_position: Vector3) -> void:
	var gate := root.get_node_or_null("ConnectedRoads/RoadTo_"+target+"/TravelGate") as Node3D
	if gate == null: return
	var tween: Tween = gate.get_meta("opening_tween") if gate.has_meta("opening_tween") else null
	if tween != null and tween.is_valid(): tween.kill()
	gate.remove_meta("opening_tween")
	gate.get_node("Hinge").rotation.y = 0.0
	# Do not insert a closing collider through somebody standing at the leaf.
	# The boundary owner still holds that crossing until preparation completes.
	_gate_collision(gate,gate.global_position.distance_squared_to(actor_position) > 4.0)

static func _gate_collision(gate: Node, enabled: bool) -> void:
	for body: CollisionObject3D in gate.find_children("*","CollisionObject3D",true,false):
		body.collision_layer = 1 if enabled else 0
		body.collision_mask = 1 if enabled else 0

static func _strip(parent: Node3D, name: String, left: PackedVector3Array, right: PackedVector3Array, material: Material, collision: bool, profile: String = "") -> void:
	var key := var_to_bytes([left,right,profile]).hex_encode()
	var reference: WeakRef = _meshes.get(key)
	var mesh: ArrayMesh = reference.get_ref() if reference != null else null
	if mesh == null:
		mesh = _build_contoured_strip(left,right,profile) if profile != "" else _build_strip(left,right)
		_meshes[key] = weakref(mesh)
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		body.set_meta("walkable_support",name == "Ground")
		var shape := CollisionShape3D.new()
		var cached: WeakRef = _shapes.get(key)
		var triangles: ConcavePolygonShape3D = cached.get_ref() if cached != null else null
		if triangles == null:
			triangles = mesh.create_trimesh_shape(); triangles.backface_collision = true
			_shapes[key] = weakref(triangles)
		shape.shape = triangles
		body.add_child(shape)
		visual.add_child(body)

static func _build_contoured_strip(left: PackedVector3Array, right: PackedVector3Array, profile: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	const CROSS_SECTIONS := 4
	for segment in range(left.size() - 1):
		var length := left[segment].distance_to(left[segment + 1])
		var sections := maxi(2, ceili(length / 1.4))
		for section in sections:
			for across in CROSS_SECTIONS:
				var corners: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var u := float(section + corner.x) / sections
					var v := float(across + corner.y) / CROSS_SECTIONS
					var inner := left[segment].lerp(left[segment + 1], u)
					var outer := right[segment].lerp(right[segment + 1], u)
					var point := inner.lerp(outer, v)
					var ridge := outer if profile == "bank" else inner
					var undulation := sin(ridge.x * 1.13 + ridge.z * 0.67) * 0.22 + cos(ridge.x * 0.47 - ridge.z * 1.31) * 0.12
					if profile == "arch":
						point.y += sin(v * PI) * 0.70
					else:
						var crest_weight := v if profile == "bank" else 1.0 - v
						point.y += undulation * crest_weight
						var outward := outer - inner
						outward.y = 0.0
						# Never push a bank inward across the retained walkable edge.
						point += outward.normalized() * sin(v * PI) * (0.10 + 0.10 * sin(point.x * 2.1 + point.z * 1.7))
					corners.append(point)
					uvs.append(Vector2(v * 2.0, distance + u * length) * 0.35)
				for vertex in [0,2,3,0,1,2]:
					surface.set_uv(uvs[vertex])
					surface.add_vertex(corners[vertex])
		distance += length
	surface.generate_normals()
	return surface.commit()

static func _build_strip(left: PackedVector3Array, right: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	for i in range(left.size()-1):
		var length := left[i].distance_to(left[i+1])
		var vertices := [left[i],right[i+1],right[i],left[i],left[i+1],right[i+1]]
		var uv := [Vector2(0,distance),Vector2(2,distance+length),Vector2(2,distance),Vector2(0,distance),Vector2(0,distance+length),Vector2(2,distance+length)]
		for v in range(6):
			surface.set_uv(uv[v]*0.35)
			surface.add_vertex(vertices[v])
		distance += length
	surface.generate_normals()
	return surface.commit()
