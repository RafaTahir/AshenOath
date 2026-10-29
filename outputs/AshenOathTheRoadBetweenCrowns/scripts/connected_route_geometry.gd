extends RefCounted

const Sectors = preload("res://scripts/world_sector_manifest.gd")
static var _door_meshes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _shapes: Dictionary = {}
static var _landmark_box: BoxMesh
const SOIL_SECTIONS := 6
const SOIL_CROSS_SECTIONS := 6
const SOIL_CREST_HEIGHT := 2.2

static func soil_crest_height(station: int) -> float:
	return SOIL_CREST_HEIGHT + sin(float(station) * 1.7) * 0.15

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
	var masonry := context.make_world_material("medieval_brick",Color(0.60,0.61,0.55)).duplicate() as BaseMaterial3D
	masonry.cull_mode = BaseMaterial3D.CULL_DISABLED
	for edge: Dictionary in Sectors.connections(context.zone_id):
		var path := Node3D.new()
		path.name = "RoadTo_"+str(edge.target)
		path.set_meta("connected_target",str(edge.target))
		roads.add_child(path)
		var source_points := Sectors.connector_points(edge)
		var normal := Sectors.direction(str(edge.id))
		path.transform = Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),source_points[0]+normal*2.0)
		# Geometry and route queries consume the same centerline, including bends.
		var points := PackedVector3Array()
		for point: Vector3 in source_points: points.append(path.transform.affine_inverse()*point)
		var style := _route_style(edge)
		path.set_meta("route_style",style)
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
				# The arch has its own masonry piers. Soil shoulders must not rise
				# into six-metre wedges simply to reach its roof.
				crest.append(side[i]+outward*2.2+Vector3.UP*(4.5 if stone else soil_crest_height(i)))
				outer.append(side[i]+outward*5.5)
			_strip(path,"Bank",side,crest,banks,true,"bank" if not stone else "")
			_strip(path,"BackSlope",crest,outer,banks,false,"backslope" if not stone else "")
		# Cover only the bends, keeping the entrance and regional view open.
		# This also makes the normal collision-safe camera respect the passage.
		var roof_left := PackedVector3Array([left[1]+Vector3.UP*4.5,left[2]+Vector3.UP*4.5])
		var roof_right := PackedVector3Array([right[1]+Vector3.UP*4.5,right[2]+Vector3.UP*4.5])
		# The covered bend is a supported old road arch, not a floating soil lid.
		_strip(path,"BendArch",roof_left,roof_right,masonry,true,"arch")
		_make_route_details(path,edge,points,left,right,style,timber,masonry,context)
		_make_gate(path,edge,width,timber)
		_make_landmark(path,edge,width,timber,banks)
		path.set_meta("required_ground",true)
		var marker := context.zone_root.find_child("gate_"+str(edge.target),true,false) as Node3D
		if marker == null:
			marker = context.make_zone_gate("Road to "+str(edge.target).replace("_"," ").capitalize(),source_points[0],str(edge.target),Vector3.ZERO)
		if marker != null: marker.position = source_points[0]

static func _route_style(edge: Dictionary) -> String:
	var pair: Array = [str(edge.source),str(edge.target)]
	if "marsh_crossing" in pair: return "causeway"
	if "record_hall" in pair or "undercroft" in pair or "vargan_court" in pair: return "castle"
	if "hart_glade" in pair or "ruins" in pair: return "sanctuary"
	if "old_mill" in pair or "burned_farmstead" in pair: return "haul_road"
	if "vargan_approach" in pair or "bandit_road" in pair: return "watch_road"
	return "forest_cutting"

static func _make_route_details(parent: Node3D, edge: Dictionary, points: PackedVector3Array, left: PackedVector3Array, right: PackedVector3Array, style: String, timber: Material, stone: Material, context: ZoneBuildContext) -> void:
	var masonry: Array[Transform3D] = []
	var wood: Array[Transform3D] = []
	var drainage: Array[Transform3D] = []
	# Low retaining courses and drain edges follow the actual bend. Nothing
	# extends into the walkable strip or adds an obstacle to the route collider.
	for side: PackedVector3Array in [left,right]:
		for segment in range(points.size()-1):
			var length := side[segment].distance_to(side[segment+1])
			var tangent := (side[segment+1]-side[segment]).normalized()
			var yaw := atan2(tangent.x,tangent.z)
			var count := maxi(1,ceili(length/1.25))
			for index in range(count):
				var fraction := (float(index)+0.5)/float(count)
				var center := points[segment].lerp(points[segment+1],fraction)
				var border := side[segment].lerp(side[segment+1],fraction)
				var outward := (border-center).normalized()
				var height := 0.22+float(index%3)*0.035
				masonry.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(0.38,height,length/float(count)-0.04)),border+outward*0.28+Vector3.UP*height*0.5))
				drainage.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(0.16,0.012,length/float(count))),border-outward*0.12+Vector3.UP*0.018))
				if style == "causeway" and index%2 == 0:
					wood.append(_landmark_part(border+outward*0.34+Vector3.UP*0.55,Vector3(0.14,1.10,0.14)))
			if style == "causeway":
				var middle := (side[segment]+side[segment+1])*0.5
				var outward := (middle-(points[segment]+points[segment+1])*0.5).normalized()
				wood.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(0.12,0.12,length)),middle+outward*0.34+Vector3.UP*0.92))
	# Repeated masonry ribs explain how the cutting roof is supported. They sit
	# outside its retained camera/collision envelope, preserving head clearance.
	for fraction in [0.08,0.5,0.92]:
		var a := left[1].lerp(left[2],fraction)
		var b := right[1].lerp(right[2],fraction)
		var across := (b-a).normalized()
		var mid := (a+b)*0.5
		var forward := (points[2]-points[1]).normalized()
		var yaw := atan2(forward.x,forward.z)
		for sign_value in [-1.0,1.0]:
			var foot: Vector3 = mid+across*float(sign_value)*(a.distance_to(b)*0.5+0.24)
			for course in range(6):
				masonry.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(0.42,0.72,0.54)),foot+Vector3.UP*(0.36+float(course)*0.75)))
		for arch_step in range(9):
			var f := (float(arch_step)+0.5)/9.0
			var position := a.lerp(b,f)+Vector3.UP*(4.62+sin(f*PI)*0.70)
			var slope := cos(f*PI)*PI*0.70/a.distance_to(b)
			var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,atan(slope))
			masonry.append(Transform3D(basis.scaled(Vector3(a.distance_to(b)/9.0+0.03,0.22,0.54)),position))
	# The road's work differs by region, using the retained timber/stone set.
	var shoulder := right[0]+(right[0]-points[0]).normalized()*0.6
	if style == "haul_road":
		for index in range(4):
			wood.append(Transform3D(Basis(Vector3.UP,0.12).scaled(Vector3(0.25,0.18,2.0)),shoulder+Vector3(float(index%2)*0.27,0.10+float(index/2)*0.19,1.5)))
	elif style == "sanctuary":
		for index in range(3):
			masonry.append(_landmark_part(shoulder+Vector3(0,0.22+float(index)*0.40,1.1),Vector3(0.50-float(index)*0.08,0.40,0.45),0.04*float(index)))
	elif style in ["forest_cutting","watch_road"]:
		for z in [0.0,1.4,2.8]:
			wood.append(_landmark_part(shoulder+Vector3(0,0.60,z),Vector3(0.16,1.2,0.16)))
		wood.append(_landmark_part(shoulder+Vector3(0,0.90,1.4),Vector3(0.10,0.13,3.0)))
	_add_box_batch(parent,"RoadMasonry",masonry,stone)
	_add_box_batch(parent,"RoadJoinery",wood,timber)
	_add_box_batch(parent,"RoadDrainage",drainage,context.make_world_material("wet_mud",Color(0.24,0.28,0.25)))
	_make_waypost(parent,edge,left[0]+(left[0]-points[0]).normalized()*0.40,timber,context)

static func _add_box_batch(parent: Node3D, name: String, pieces: Array[Transform3D], material: Material) -> void:
	if pieces.is_empty(): return
	if _landmark_box == null:
		_landmark_box = BoxMesh.new()
		_landmark_box.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _landmark_box
	batch.instance_count = pieces.size()
	for i in range(pieces.size()): batch.set_instance_transform(i,pieces[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = name
	visual.multimesh = batch
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

static func _make_waypost(parent: Node3D, edge: Dictionary, position: Vector3, timber: Material, context: ZoneBuildContext) -> void:
	var sign := Node3D.new()
	sign.name = "RouteWaypost"
	sign.position = position
	parent.add_child(sign)
	var pieces: Array[Transform3D] = [
		_landmark_part(Vector3(0,0.9,0),Vector3(0.15,1.8,0.15)),
		_landmark_part(Vector3(0,1.65,0),Vector3(2.05,0.42,0.11))]
	_add_box_batch(sign,"SignTimber",pieces,timber)
	var text := TextMesh.new()
	text.text = str(edge.target).replace("_"," ").capitalize()
	text.font_size = 42
	text.pixel_size = 0.003
	text.depth = 0.004
	var label := MeshInstance3D.new()
	label.name = "Destination"
	label.mesh = text
	label.position = Vector3(0,1.65,-0.061)
	label.rotation.y = PI
	label.material_override = context.make_material(Color(0.82,0.77,0.60))
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign.add_child(label)

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
	var leaf := Node3D.new(); leaf.name = "TimberLeaf"
	leaf.position = Vector3(half,2.25,0)
	hinge.add_child(leaf)
	var pieces: Array[Transform3D] = []
	var plank_width := half*2.0/12.0
	for index in range(12):
		pieces.append(_landmark_part(Vector3(-half+plank_width*(float(index)+0.5),0,0),Vector3(plank_width-0.012,4.5,0.18)))
	for y in [-1.65,1.55]:
		pieces.append(_landmark_part(Vector3(0,y,-0.13),Vector3(half*2.0,0.15,0.12)))
	var brace_start := Vector3(-half+0.15,-1.55,-0.14)
	var brace_end := Vector3(half-0.15,1.45,-0.14)
	pieces.append(Transform3D(Basis(Quaternion(Vector3.UP,(brace_end-brace_start).normalized())).scaled(Vector3(0.15,brace_start.distance_to(brace_end),0.12)),(brace_start+brace_end)*0.5))
	_add_box_batch(leaf,"GateJoinery",pieces,material)
	var body := StaticBody3D.new()
	body.set_meta("walkable_support",false)
	var shape := CollisionShape3D.new()
	var box := preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(half*2,4.5,0.18))
	shape.shape = box; body.add_child(shape); leaf.add_child(body)

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
	visual.set_meta("connector_surface", name)
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
	elif profile == "backslope":
		# The outer bank is scenery, not extra player collision, but it still
		# owns solid camera clearance at a bend or while looking back.
		preload("res://scripts/camera_controller.gd").install_visual_clearance(visual)

static func _build_contoured_strip(left: PackedVector3Array, right: PackedVector3Array, profile: String) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	var soil := profile in ["bank", "backslope"]
	var cross_sections := SOIL_CROSS_SECTIONS if soil else 4
	for segment in range(left.size() - 1):
		var length := left[segment].distance_to(left[segment + 1])
		# Both faces of a bank use identical stations, including at the crest.
		# Different inner/outer arc lengths must not open cracks in a curved runout.
		var sections := SOIL_SECTIONS if soil else maxi(2, ceili(length / 1.4))
		for section in sections:
			for across in cross_sections:
				var corners: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var u := float(section + corner.x) / sections
					var v := float(across + corner.y) / cross_sections
					var inner := left[segment].lerp(left[segment + 1], u)
					var outer := right[segment].lerp(right[segment + 1], u)
					var point := inner.lerp(outer, v)
					var ridge := outer if profile == "bank" else inner
					var undulation := sin(ridge.x * 1.13 + ridge.z * 0.67) * 0.22 + cos(ridge.x * 0.47 - ridge.z * 1.31) * 0.12
					if profile == "arch":
						point.y += sin(v * PI) * 0.70
					else:
						# Meet the existing ground at both ends instead of exposing a
						# full-height triangular soil cut to the village/return camera.
						var progress := (float(segment) + u) / float(left.size() - 1)
						var runout := smoothstep(0.0, 1.0 / 3.0, progress) * smoothstep(0.0, 1.0 / 3.0, 1.0 - progress)
						var crest_weight := smoothstep(0.0,1.0,v) if profile == "bank" else 1.0 - smoothstep(0.0,1.0,v)
						var foot_height := inner.y if profile == "bank" else outer.y
						point.y = lerpf(foot_height, ridge.y + undulation, crest_weight * runout)
						var outward := outer - inner
						outward.y = 0.0
						# Never push a bank inward across the retained walkable edge.
						point += outward.normalized() * sin(v * PI) * (0.10 + 0.10 * sin(point.x * 2.1 + point.z * 1.7))
					corners.append(point)
					# Retain the soil texture at metre scale, not stretched over a tall face.
					uvs.append(Vector2(v * inner.distance_to(outer), distance + u * length) if soil else Vector2(v * 2.0, distance + u * length) * 0.35)
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
