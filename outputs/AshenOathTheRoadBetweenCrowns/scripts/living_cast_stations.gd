extends RefCounted

const CastProfile = preload("res://scripts/story_cast_profile.gd")
const STAGE_TWO := {
	"nessa":{"source":"res://assets_external/environment_prepared/living_cast/station_nessa.scn", "contact_height":1.02},
	"elna":{"source":"res://assets_external/environment_prepared/living_cast/station_elna.scn", "contact_height":1.02},
	"toma":{"source":"res://assets_external/environment_prepared/living_cast/station_toma.scn", "contact_height":1.02},
	"nera":{"source":"res://assets_external/environment_prepared/living_cast/station_nera.scn", "contact_height":1.10},
	"vale":{"source":"res://assets_external/environment_prepared/living_cast/station_vale.scn", "contact_height":1.02},
	"merrow":{"source":"res://assets_external/environment_prepared/living_cast/station_merrow.scn", "contact_height":1.02},
	"edric":{"source":"res://assets_external/environment_prepared/living_cast/station_edric.scn", "contact_height":1.02},
}

## Called after region construction and before routine enrollment. Furniture is
## static; the existing controller owns reservations, movement and all effects.
static func ensure_region(host) -> void:
	var definitions: Dictionary = CastProfile.life_data().get("zones", {}).get(str(host.current_zone_id), {}).duplicate(true)
	if not definitions.has("saga_nera") and CastProfile.registered_actor(host.zone_root,"saga_maren") != null:
		var routine := CastProfile.routine("saga_maren", str(host.current_zone_id), host.story_state, host.quests, "day")
		if not routine.is_empty() and not routine.path.is_empty():
			var point: Vector3 = routine.path[0]
			definitions["saga_maren"] = {"work":[point.x,point.y,point.z]}
	var created: Dictionary = {}
	for id: String in definitions:
		var identity := CastProfile.canonical_identity(id)
		if identity not in STAGE_TWO and identity != "senn": continue
		if created.has(identity): continue
		var actor := CastProfile.registered_actor(host.zone_root, id)
		if actor == null or not actor.visible: continue
		created[identity] = true
		var definition: Dictionary = definitions[id]
		if identity in STAGE_TWO:
			_add_regional_work(host, identity, definition.work, "")
			if definition.has("after_work"):
				_add_regional_work(host, identity, definition.after_work, "_after")
		if definition.has("rest"):
			_add_rest_stool(host, identity, definition.rest)

static func _add_regional_work(host, identity: String, raw: Array, suffix: String) -> Node3D:
	var name := "LivingWork_" + identity + suffix
	var existing := host.zone_root.get_node_or_null(name) as Node3D
	if existing != null: return existing
	var stand := Vector3(float(raw[0]),float(raw[1]),float(raw[2]))
	var safe: Vector3 = host.validate_walkable_position(stand)
	if safe.distance_squared_to(stand) > 0.04: return null
	var recipe: Dictionary = STAGE_TWO[identity]
	var source := load(str(recipe.source)) as PackedScene
	var mesh := _retained_timber_structure()
	if source == null or mesh == null:
		push_error("Living cast station is missing its authored task prop: " + identity)
		return null
	var root := Node3D.new()
	root.name = name
	root.position = safe
	host.zone_root.add_child(root)
	var table := MeshInstance3D.new()
	table.name = "SupportedWorkTable"
	table.mesh = mesh
	table.scale = Vector3(1.10/2.2,1.0/0.93,0.80/1.5)
	table.position.z = -0.76
	root.add_child(table)
	preload("res://scripts/camera_controller.gd").install_visual_clearance(table)
	_add_box_solid(root, "TableSolid", Vector3(1.10,1.0,0.80), Vector3(0,0.5,-0.76))
	var prop := source.instantiate() as Node3D
	if prop == null or str(prop.get_meta("actor_identity", "")) != identity \
			or not bool(prop.get_meta("stationary_supported_prop", false)) or not bool(prop.get_meta("grip_geometry_verified", false)):
		push_error("Living cast station prop has invalid contact provenance: " + identity)
		if prop != null: prop.free()
		root.queue_free()
		return null
	prop.name = "StationWork_" + identity
	prop.position = Vector3(0,1.0,-0.40)
	root.add_child(prop)
	var contact := Vector3(0,float(recipe.contact_height),-0.40)
	var station := add_work(root, identity + suffix, contact, Vector3.ZERO, Vector3(0.12,0,0), 0.0)
	for side: String in ["Left", "Right"]:
		var grip := prop.find_child("Grip" + side, true, false) as Marker3D
		if grip == null:
			push_error("Living cast task prop lacks a calibrated grip: " + identity + "/" + side)
			root.queue_free()
			return null
		_marker(station, "Work" + side, station.to_local(grip.global_position))
	station.set_meta("task_prop", weakref(prop))
	station.set_meta("work_identity", identity)
	# Distinct seats around the actual table let shared meals reserve a place
	# without taking another worker's hands or the player's interaction spot.
	for side in [-1, 1]:
		var place := _marker(root, "LifeMeal_%s_%s" % [identity, "left" if side < 0 else "right"], Vector3(float(side)*1.0,0,-0.76))
		place.set_meta("meal_supported", true)
		place.set_meta("table_point", Vector3(0,1.0,-0.76))
	return root

static func _add_rest_stool(host, identity: String, raw: Array) -> void:
	var name := "LivingRest_" + identity
	if host.zone_root.get_node_or_null(name) != null: return
	var stand := Vector3(float(raw[0]),float(raw[1]),float(raw[2]))
	if host.validate_walkable_position(stand).distance_squared_to(stand) > 0.04: return
	var mesh := _retained_timber_structure()
	if mesh == null: return
	var root := Node3D.new()
	root.name = name
	root.position = stand
	host.zone_root.add_child(root)
	var seat := MeshInstance3D.new()
	seat.name = "SupportedTimberSeat"
	seat.mesh = mesh
	seat.scale = Vector3(0.66/2.2,0.50/0.93,0.42/1.5)
	seat.position.z = -0.56
	root.add_child(seat)
	_add_box_solid(root, "SeatSolid", Vector3(0.66,0.50,0.42), Vector3(0,0.25,-0.56))
	var anchor := _marker(root, "LifeRest_" + identity, Vector3(0,0.50,-0.56))
	anchor.set_meta("rest_supported", true)
	anchor.set_meta("rest_kind", "seated")
	anchor.set_meta("rest_identity", identity)
	anchor.set_meta("stand_offset", Vector3(0,-0.50,0.56))

static func _add_box_solid(parent: Node3D, name: String, size: Vector3, point: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = preload("res://scripts/immutable_collision_shapes.gd").box(size)
	shape.position = point
	body.add_child(shape)
	parent.add_child(body)

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
