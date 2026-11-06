extends RefCounted

## Contacts belong to visible retained furniture. These markers describe
## geometry; the existing routine owner still owns occupancy and movement.
static func add_work(parent: Node3D, actor: String, contact: Vector3, stand: Vector3, hands: Vector3, hand_clearance: float = 0.025) -> Node3D:
	var name := "LifeWork_" + actor
	var existing := parent.get_node_or_null(name) as Node3D
	if existing != null: return existing
	var station := Node3D.new()
	station.name = name
	parent.add_child(station)
	_marker(station, "WorkContact", contact)
	_marker(station, "WorkStand", stand)
	_marker(station, "WorkLeft", contact - hands + Vector3.UP * hand_clearance)
	_marker(station, "WorkRight", contact + hands + Vector3.UP * hand_clearance)
	station.set_meta("contact_geometry", str(parent.name))
	return station

static func decorate_place(area: Node3D, id: String) -> void:
	if id == "mira_apothecary":
		var visual := area.get_node_or_null("GreyfenSocialFurniture") as MeshInstance3D
		if visual == null or visual.mesh == null or not visual.mesh.has_meta("counter_height"):
			push_error("Mira's work requires the authored counter-height metadata")
			return
		var height := float(visual.mesh.get_meta("counter_height"))
		# A small raised drying rack gives the short retained rig a supported
		# work surface. Its four feet stand on the authored counter, rather than
		# lifting the hand targets above empty air.
		var rack := area.get_node_or_null("MiraRaisedDryingRack") as MeshInstance3D
		if rack == null:
			rack = MeshInstance3D.new()
			rack.name = "MiraRaisedDryingRack"
			rack.mesh = _retained_timber_structure()
			if rack.mesh == null:
				rack.free()
				return
			rack.scale = Vector3(0.30,0.15/0.93,0.20)
			rack.position = Vector3(-0.35,height,-0.54)
			area.add_child(rack)
		_add_drying_leaves(area, height + 0.15)
		add_work(area, "mira", Vector3(-0.35,height+0.15,-0.68), Vector3(-0.35,0,-1.12), Vector3(-0.12,0,0))
	elif id == "common_table":
		# The retained table is 2.8 x 0.93 x 1.8m. Work from its western
		# edge, clear of both chairs and the player's board-game approach.
		var satchel := area.get_node_or_null("RookStationSatchel") as Node3D
		if satchel == null:
			var source := load("res://assets_external/environment_prepared/living_cast/rook_station_satchel.scn") as PackedScene
			if source == null:
				push_error("Rook's work requires its authored station satchel")
				return
			satchel = source.instantiate() as Node3D
			satchel.name = "RookStationSatchel"
			satchel.position = Vector3(-1.22,0.93,0)
			area.add_child(satchel)
		# Both hands meet the attached strap. The bag stays on the table when
		# Rook stops working; the existing life owner restores its knot state.
		add_work(area, "rook", Vector3(-1.30,1.11,0), Vector3(-1.78,0,0), Vector3(0,0,0.10), 0.0)
	elif id == "shrine_prayer":
		var seat := _marker(area, "LifeRest_anwen", Vector3(0,0.54,0))
		seat.set_meta("rest_supported", true)
		seat.set_meta("rest_kind", "seated")
		seat.set_meta("stand_offset", Vector3(0,-0.54,0.64))
		seat.set_meta("interaction_owner", "shrine_prayer")

static func add_care_table(zone: Node3D) -> Node3D:
	var existing := zone.get_node_or_null("AnwenCareTable") as Node3D
	if existing != null: return existing
	var mesh := _retained_timber_structure()
	if mesh == null: return null
	var table := Node3D.new()
	table.name = "AnwenCareTable"
	table.position = Vector3(3.5,0,-7.35)
	zone.add_child(table)
	var visual := MeshInstance3D.new()
	visual.name = "RetainedTimberTable"
	visual.mesh = mesh
	visual.scale = Vector3(0.55,1.015/0.93,0.55)
	table.add_child(visual)
	preload("res://scripts/camera_controller.gd").install_visual_clearance(visual)
	var body := StaticBody3D.new()
	body.name = "TableSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "TableCollision"
	collision.shape = preload("res://scripts/immutable_collision_shapes.gd").box(Vector3(1.21,1.015,0.825))
	collision.position.y = 1.015 * 0.5
	body.add_child(collision)
	table.add_child(body)
	add_work(table, "anwen", Vector3(0,1.015,0.40), Vector3(0,0,0.78), Vector3(0.12,0,0))
	return table

static func _retained_timber_structure() -> ArrayMesh:
	var source := load("res://assets_external/environment/props/GreyfenSocial_barrel_board.res") as ArrayMesh
	if source == null or source.get_surface_count() < 1:
		push_error("Living cast work surfaces require retained Greyfen furniture")
		return null
	# Reuse only the authored timber structure, without the board-game chairs.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(0))
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh

static func _add_drying_leaves(area: Node3D, height: float) -> void:
	if area.get_node_or_null("MiraDryingLeaves") != null: return
	# Reuse the retained leaf mesh for three small sorted piles. These are
	# supported work details, with no separate update or particle controller.
	var leaves := load("res://assets_external/environment/forest/Fern_1.obj") as ArrayMesh
	if leaves == null:
		push_error("Mira's drying rack requires the retained leaf mesh")
		return
	var bounds := leaves.get_aabb()
	if minf(bounds.size.x,minf(bounds.size.y,bounds.size.z)) <= 0.0001:
		push_error("Mira's retained leaf mesh has invalid bounds")
		return
	var piles := Node3D.new()
	piles.name = "MiraDryingLeaves"
	area.add_child(piles)
	var bottom_centre := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	for index in range(3):
		var pile := MeshInstance3D.new()
		pile.name = "SortedLeaves%d" % index
		pile.mesh = leaves
		var target_size := Vector3(0.12,0.025,0.08)
		pile.basis = Basis(Vector3.UP,(-0.18 if index % 2 == 0 else 0.22)).scaled(target_size / bounds.size)
		pile.position = Vector3(-0.35+float(index-1)*0.15,height,-0.57) - pile.basis*bottom_centre
		pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piles.add_child(pile)

static func _marker(parent: Node3D, name: String, point: Vector3) -> Marker3D:
	var result := parent.get_node_or_null(name) as Marker3D
	if result == null:
		result = Marker3D.new()
		result.name = name
		parent.add_child(result)
	result.position = point
	return result
