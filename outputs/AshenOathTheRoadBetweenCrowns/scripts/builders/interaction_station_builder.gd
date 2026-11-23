extends RefCounted
const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
var _host: Api
var _scope: Scope
func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope
func _make_village_place(id: String, type: String, prompt: String, pos: Vector3, size: Vector3, color: Color) -> Variant:
	pos = _host.river_safe_position(pos,maxf(size.z*0.5,0.8))
	var area = _host.Interactable.new()
	area.setup(id,type,prompt)
	area.position = pos
	area.build_collision(1.35)
	_scope.zone_root.add_child(area)
	var prop_spec: Variant = _host._world_prop_spec(id)
	if not prop_spec.is_empty():
		_host.write_construction_tag(area, "world_prop_id", id)
		var prop_component: Variant = _host.InteractiveWorldProp.new()
		prop_component.name = "InteractiveWorldProp"
		area.add_child(prop_component)
		prop_component.configure(id, str(prop_spec.get("kind", "generic")), str(prop_spec.get("state_key", "")), "idle", _host.story_state)
	var table: MeshInstance3D = null
	var mesh: BoxMesh = null
	if id in ["forge_corner", "tor_forge"]:
		pass
	elif id in ["common_table", "barrel_board", "mira_apothecary"]:
		_host.GreyfenSocialPresentation.apply(area, id)
		if type == "minigame":
			_host._make_board_game_staging(area, id, size)
			if not _host._make_board_game_solidity(area, size):
				area.free()
				return null
	else:
		table = MeshInstance3D.new()
		table.name = "%s_VisibleProp" % id
		mesh = BoxMesh.new()
	if table == null:
		pass
	elif id == "village_well":
		table.position.y = 0.0
	elif id == "shrine_prayer":
		mesh.size = Vector3(size.x, 0.12, size.z)
		table.position.y = 0.48
		table.material_override = _host._mat(color.lightened(0.12))
		var supports: Variant = _host._make_multimesh_batch("ShrineBenchSupports", _host.shared_box_mesh, 2, _host._mat(color.darkened(0.12)))
		supports.reparent(area, false)
		for index in range(2):
			var x: Variant = -size.x * 0.38 if index == 0 else size.x * 0.38
			supports.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 0.42, size.z * 0.75)), Vector3(x, 0.21, 0.0)))
	elif type == "minigame":
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _host._mat(color.darkened(0.10))
		var legs: Variant = _host._make_multimesh_batch("%s_TableLegs" % id, _host.shared_box_mesh, 4, _host._mat(color.darkened(0.20)))
		legs.reparent(area, false)
		legs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var leg_index: Variant = 0
		for x in [-size.x * 0.38, size.x * 0.38]:
			for z in [-size.z * 0.34, size.z * 0.34]:
				legs.multimesh.set_instance_transform(leg_index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, size.y * 0.92, 0.14)), Vector3(x, size.y * 0.46, z)))
				leg_index += 1
		_host._make_board_game_staging(area, id, size)
	elif type == "vendor":
		mesh.size = Vector3(size.x, 0.16, size.z)
		table.position.y = size.y
		table.material_override = _host._mat(color.darkened(0.12))
		var canopy: Variant = MeshInstance3D.new()
		canopy.name = "%s_Canopy" % id
		var canopy_mesh: Variant = BoxMesh.new()
		canopy_mesh.size = Vector3(size.x + 0.32, 0.12, size.z + 0.28)
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0.0, size.y + 1.55, 0.0)
		canopy.material_override = _host._mat(color.lightened(0.12))
		area.add_child(canopy)
		var posts: Variant = _host._make_multimesh_batch("%s_CanopyPosts" % id, _host.shared_box_mesh, 2, _host._mat(color.darkened(0.25)))
		posts.reparent(area, false)
		posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var crates: Variant = _host._make_multimesh_batch("%s_StockCrates" % id, _host.shared_box_mesh, 2, _host._mat(color.darkened(0.28)))
		crates.reparent(area, false)
		crates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for index in range(2):
			var side: Variant = -1.0 if index == 0 else 1.0
			posts.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.10, 1.55, 0.10)), Vector3(side * size.x * 0.42, size.y * 0.78, 0.0)))
			crates.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(0.36, 0.30, 0.36)), Vector3(side * size.x * 0.30, 0.18, size.z * 0.58)))
		_host._make_light("%s_ShopGlow" % id, pos + Vector3(0, 1.25, 0), color.lightened(0.18), 0.7)
	else:
		mesh.size = size
		table.position.y = size.y * 0.5
		table.material_override = _host._mat(color)
	if table != null:
		table.mesh = mesh
		area.add_child(table)
	preload("res://scripts/living_cast_stations.gd").decorate_place(area, id)
	if id == "village_well":
		_host._apply_greyfen_well_visual(table, pos)
	_make_interaction_label(area, prompt, Vector3(0, size.y + 0.62, 0), 14, 0.0048, false)
	_host._connect_interactable(area)
	return area
func _make_board_game_staging(area: Node3D, id: String, size: Vector3) -> void:
	var board_size: Variant = Vector2(size.x * 0.70, size.z * 0.68)
	var board_back: Variant = MeshInstance3D.new()
	board_back.name = "%s_CarvedBoard" % id
	var board_mesh: Variant = BoxMesh.new()
	board_mesh.size = Vector3(board_size.x + 0.18, 0.055, board_size.y + 0.18)
	board_back.mesh = board_mesh
	board_back.position = Vector3(0.0, size.y + 0.10, 0.0)
	board_back.material_override = _host._mat(Color(0.20, 0.11, 0.055))
	area.add_child(board_back)
	var columns: Variant = 3 if id == "common_table" else 6
	var rows: Variant = columns
	var square_size: Variant = Vector3(board_size.x / columns - 0.018, 0.018, board_size.y / rows - 0.018)
	var square_batches: Array[MultiMeshInstance3D] = []
	for parity in range(2):
		var count: Variant = (columns * rows + 1) / 2 if parity == 0 else columns * rows / 2
		var material: Variant = _host._mat(Color(0.38, 0.24, 0.12) if parity == 0 else Color(0.16, 0.095, 0.045))
		var batch: Variant = _host._make_multimesh_batch("%s_BoardSquares_%d" % [id, parity], _host.shared_box_mesh, int(count), material)
		batch.reparent(area, false)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		square_batches.append(batch)
	var square_indices: Variant = [0, 0]
	for row in range(rows):
		for column in range(columns):
			var x: Variant = -board_size.x * 0.5 + board_size.x * (float(column) + 0.5) / float(columns)
			var z: Variant = -board_size.y * 0.5 + board_size.y * (float(row) + 0.5) / float(rows)
			var parity: Variant = (row + column) % 2
			square_batches[parity].multimesh.set_instance_transform(square_indices[parity], Transform3D(Basis.IDENTITY.scaled(square_size), Vector3(x, size.y + 0.14, z)))
			square_indices[parity] += 1
			if id == "common_table" and (row + column) % 2 == 1 and row != 1:
				var mark: Variant = MeshInstance3D.new()
				mark.name = "%s_CarvedMark_%d_%d" % [id, row, column]
				var mark_mesh: Variant = CylinderMesh.new()
				mark_mesh.top_radius = 0.075
				mark_mesh.bottom_radius = 0.075
				mark_mesh.height = 0.035
				mark_mesh.radial_segments = 10
				mark.mesh = mark_mesh
				mark.position = Vector3(x, size.y + 0.18, z)
				mark.material_override = _host._mat(Color(0.72, 0.48, 0.20) if row < 2 else Color(0.72, 0.68, 0.48))
				area.add_child(mark)
	var chair_batch: MultiMeshInstance3D = null
	if not bool(_host.read_construction_tag(area, "authored_social_furniture", false)):
		chair_batch = _host._make_multimesh_batch("%s_ChairParts" % id, _host.shared_box_mesh, 4, _host._mat(Color(0.20, 0.12, 0.065)))
		chair_batch.reparent(area, false)
		chair_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_host._make_board_game_chair(area, Vector3(0.0, 0.0, size.z * 0.90), PI, chair_batch, 0)
	_host._make_board_game_chair(area, Vector3(0.0, 0.0, -size.z * 0.90), 0.0, chair_batch, 2)
func _make_board_game_solidity(area: Node3D, size: Vector3) -> bool:
	var visual: Variant = area.get_node_or_null("GreyfenSocialFurniture") as MeshInstance3D
	if visual == null or visual.mesh == null:
		push_error("Required solid board furniture is missing: " + str(area.name))
		return false
	var fitted: ConcavePolygonShape3D = preload("res://scripts/core/prepared_greyfen_social_collision.gd").fitted(str(area.name), visual.mesh)
	if fitted == null:
		push_error("Cannot build solid board furniture: " + str(area.name))
		return false
	var body: Variant = StaticBody3D.new()
	body.name = "SolidFurniture"
	body.collision_layer = 1
	body.collision_mask = 1
	_host.write_construction_tag(body, "walkable_support", false)
	area.add_child(body)
	var shape: Variant = CollisionShape3D.new()
	shape.name = "FittedTableAndChairs"
	shape.shape = fitted
	shape.transform = visual.transform
	body.add_child(shape)
	_host.write_construction_tag(area, "interaction_anchor", Vector3(0, size.y + 0.18, 0))
	var arrival: Variant = Marker3D.new()
	arrival.name = "BoardGameOpponentApproach"
	# Rook takes the open north corner. The east side has the keepsake stand.
	var common_table := str(area.name) == "common_table"
	arrival.position = Vector3(size.x * 0.5, 0, -1.6) if common_table else Vector3(-size.x * 0.5 - 1.0, 0, 0)
	area.add_child(arrival)
	var corner: Variant = Marker3D.new()
	corner.name = "BoardGameOpponentCorner"
	corner.position = Vector3(arrival.position.x, 0, -size.z * 0.90 - 1.1) if common_table else Vector3(0.0, area.position.y, -10.0) - area.position
	area.add_child(corner)
	return true
func _make_board_game_chair(area: Node3D, position: Vector3, yaw: float, batch: MultiMeshInstance3D, first_index: int) -> void:
	var chair: Variant = Node3D.new()
	chair.name = "BoardGameChair_North" if position.z < 0.0 else "BoardGameChair_South"
	chair.position = position
	chair.rotation.y = yaw
	area.add_child(chair)
	if batch == null:
		return
	var orientation: Variant = Basis(Vector3.UP, yaw)
	batch.multimesh.set_instance_transform(first_index, Transform3D(orientation.scaled(Vector3(0.90, 0.14, 0.82)), position + orientation * Vector3(0.0, 0.62, 0.0)))
	batch.multimesh.set_instance_transform(first_index + 1, Transform3D(orientation.scaled(Vector3(0.90, 0.90, 0.12)), position + orientation * Vector3(0.0, 1.02, 0.32)))
func _make_ledger_interaction_visual(area: Node3D, scale_override: Vector3) -> void:
	var ledger_root: Variant = Node3D.new()
	ledger_root.name = "SealedCommandLedgerVisual"
	ledger_root.scale = scale_override
	area.add_child(ledger_root)
	var cover: Variant = MeshInstance3D.new()
	cover.name = "LedgerLeatherCover"
	var cover_mesh: Variant = BoxMesh.new()
	cover_mesh.size = Vector3(0.82, 0.11, 0.56)
	cover.mesh = cover_mesh
	cover.position = Vector3(0.0, 0.17, 0.0)
	cover.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	cover.material_override = _host._mat(Color(0.16, 0.075, 0.040))
	ledger_root.add_child(cover)
	var pages: Variant = MeshInstance3D.new()
	pages.name = "LedgerPages"
	var pages_mesh: Variant = BoxMesh.new()
	pages_mesh.size = Vector3(0.68, 0.065, 0.46)
	pages.mesh = pages_mesh
	pages.position = Vector3(0.0, 0.232, 0.0)
	pages.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	pages.material_override = _host._mat(Color(0.58, 0.48, 0.31))
	ledger_root.add_child(pages)
	var seal: Variant = MeshInstance3D.new()
	seal.name = "LedgerWaxSeal"
	var seal_mesh: Variant = CylinderMesh.new()
	seal_mesh.top_radius = 0.075
	seal_mesh.bottom_radius = 0.075
	seal_mesh.height = 0.025
	seal_mesh.radial_segments = 10
	seal.mesh = seal_mesh
	seal.position = Vector3(0.18, 0.285, -0.04)
	seal.rotation_degrees = Vector3(90.0, 0.0, -7.0)
	seal.material_override = _host._mat(Color(0.43, 0.075, 0.045))
	ledger_root.add_child(seal)
func _make_gate_marker(parent: Node3D, color: Color, scale_override: Vector3) -> void:
	var pillar_material: Variant = _host._mat(color.lightened(0.10))
	for side in [-1.0, 1.0]:
		var pillar: Variant = MeshInstance3D.new()
		var pillar_mesh: Variant = BoxMesh.new()
		pillar_mesh.size = Vector3(0.30, 1.72, 0.26)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 0.86 * scale_override.x, 0.86 * scale_override.y, 0)
		pillar.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
		pillar.material_override = pillar_material
		parent.add_child(pillar)
	var lintel: Variant = MeshInstance3D.new()
	var lintel_mesh: Variant = BoxMesh.new()
	lintel_mesh.size = Vector3(2.05, 0.24, 0.28)
	lintel.mesh = lintel_mesh
	lintel.position.y = 1.72 * scale_override.y
	lintel.scale = Vector3(scale_override.x, scale_override.y, scale_override.z)
	lintel.material_override = _host._mat(color.lightened(0.18))
	parent.add_child(lintel)
func _apply_greyfen_well_visual(visual: MeshInstance3D, pos: Vector3) -> void:
	var well_mesh: Variant = _host.opening_well_mesh if _host.opening_well_mesh != null else load("res://assets_external/environment/village/GreyfenWell_Authored.res") as ArrayMesh
	if well_mesh == null or well_mesh.get_surface_count() != 6:
		push_error("Required authored Greyfen well is unavailable")
		return
	visual.mesh = well_mesh
	var well_tints: Variant = {
		"medieval_brick": Color(0.69, 0.67, 0.61),
		"plaster": Color(0.72, 0.72, 0.67),
		"timber": Color(0.44, 0.33, 0.22),
		"roof_tiles": Color(0.42, 0.24, 0.16),
		"glazing": Color(0.10, 0.25, 0.29),
		"metal": Color(0.24, 0.27, 0.27),
	}
	var well_quality: Variant = str(_host.settings.settings.get("quality_preset", "balanced"))
	for surface_index in well_mesh.get_surface_count():
		var surface_name: Variant = well_mesh.surface_get_name(surface_index)
		if not well_tints.has(surface_name):
			push_error("Unknown authored Greyfen well surface: " + surface_name)
			return
		var material: StandardMaterial3D = _host._mat(well_tints[surface_name]) if surface_name == "glazing" else _host.world_materials.get_material(surface_name, well_quality, well_tints[surface_name], 0.0, false)
		visual.set_surface_override_material(surface_index, material)
	var body: Variant = StaticBody3D.new()
	body.name = "GreyfenWellBody"
	body.position = pos + Vector3(0, 0.42, 0)
	_scope.zone_root.add_child(body)
	var collision: Variant = CollisionShape3D.new()
	collision.name = "GreyfenWellCollision"
	var cylinder: Variant = preload("res://scripts/immutable_collision_shapes.gd").cylinder(0.87, 0.84)
	collision.shape = cylinder
	body.add_child(collision)
func _add_physical_door_visual(area: Node3D, zone_target: String) -> void:
	var frame_material: Variant = _host._mat(Color(0.16, 0.13, 0.10))
	var door_material: Variant = _host._mat(Color(0.08, 0.055, 0.040))
	var frame: Variant = MeshInstance3D.new()
	frame.name = "InteriorDoorFrame"
	var frame_mesh: Variant = BoxMesh.new()
	frame_mesh.size = Vector3(2.5, 3.0, 0.24)
	frame.mesh = frame_mesh
	frame.position = Vector3(0, 1.5, 0)
	frame.material_override = frame_material
	area.add_child(frame)
	var door: Variant = MeshInstance3D.new()
	door.name = "InteriorDoor"
	var door_mesh: Variant = BoxMesh.new()
	door_mesh.size = Vector3(1.65, 2.45, 0.12)
	door.mesh = door_mesh
	door.position = Vector3(0, 1.25, -0.15)
	door.material_override = door_material
	area.add_child(door)
	var label: Variant = Label3D.new()
	label.name = "InteriorDoorDestination"
	label.text = _host._zone_display_name(zone_target)
	label.position = Vector3(0, 2.2, -0.24)
	label.font_size = 22
	label.modulate = Color(0.82, 0.72, 0.53, 0.85)
	label.visible = false
	area.add_child(label)
func _make_interaction_label(area: Node3D, text: String, pos: Vector3, font_size: int, pixel_size: float, outlined: bool) -> void:
	var label: Label3D = Label3D.new()
	label.name = "InteractionWorldLabel"
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color(0.84, 0.78, 0.62)
	label.visibility_range_begin = 1.5
	label.visibility_range_end = 6.0
	label.visible = false
	if outlined:
		label.outline_size = 3
		label.outline_modulate = Color(0.02, 0.018, 0.015)
	area.add_child(label)
func _make_hanging_cloth(pos: Vector3, size: Vector3, color: Color) -> void:
	var columns: Variant = 5
	var rows: Variant = 3
	var vertices: Variant = PackedVector3Array()
	var normals: Variant = PackedVector3Array()
	var uvs: Variant = PackedVector2Array()
	var indices: Variant = PackedInt32Array()
	for row in range(rows + 1):
		var v: Variant = float(row) / float(rows)
		for column in range(columns + 1):
			var u: Variant = float(column) / float(columns)
			var x: Variant = (u - 0.5) * size.x
			var hem: Variant = (0.07 + 0.04 * sin(float(column) * 2.3)) * v * v
			var y: Variant = (0.5 - v) * size.y + hem
			var z: Variant = sin(u * PI * 4.0) * 0.055 + v * v * 0.035
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3.BACK)
			uvs.append(Vector2(u, v))
	for row in range(rows):
		for column in range(columns):
			var a: Variant = row * (columns + 1) + column
			var b: Variant = a + 1
			var c: Variant = a + columns + 1
			var d: Variant = c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var cloth_mesh: Variant = ArrayMesh.new()
	cloth_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth: Variant = MeshInstance3D.new()
	cloth.name = "HangingClothDrape_%d" % _scope.zone_root.get_child_count()
	cloth.position = pos
	cloth.mesh = cloth_mesh
	var cloth_material: Variant = _host._mat(color).duplicate() as StandardMaterial3D
	cloth_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_material.roughness = 0.96
	cloth.material_override = cloth_material
	_scope.zone_root.add_child(cloth)
func _make_wheelbarrow(pos: Vector3, yaw: float) -> void:
	var root = Node3D.new()
	root.name = "WheelbarrowStoryProp"
	root.position = pos
	root.rotation_degrees.y = yaw
	_scope.zone_root.add_child(root)
	_host._add_visual_box_child(root, "WheelbarrowTray", Vector3(0, 0.38, 0), Vector3(1.0, 0.24, 0.55), Color(0.15, 0.085, 0.045))
	_host._add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, -0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	_host._add_visual_box_child(root, "WheelbarrowHandle", Vector3(-0.62, 0.42, 0.23), Vector3(0.75, 0.07, 0.07), Color(0.12, 0.070, 0.038))
	var wheel = MeshInstance3D.new()
	wheel.name = "WheelbarrowWheel"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.08
	mesh.radial_segments = 8
	wheel.mesh = mesh
	wheel.position = Vector3(0.53, 0.22, 0)
	wheel.rotation_degrees.z = 90
	wheel.material_override = _host._mat(Color(0.055, 0.040, 0.030))
	root.add_child(wheel)
func _make_cart(pos: Vector3, include_visual: bool = true) -> void:
	pos = _host.river_safe_position(pos,1.0)
	if include_visual:
		_host._make_prop_box("BrokenCartBed", pos + Vector3(0, 0.45, 0), Vector3(2.0, 0.28, 1.1), Color(0.17, 0.10, 0.055))
		for x in [-0.78, 0.78]:
			var wheel = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.35
			mesh.bottom_radius = 0.35
			mesh.height = 0.12
			wheel.mesh = mesh
			wheel.position = pos + Vector3(x, 0.35, -0.62)
			wheel.rotation_degrees.z = 90
			wheel.material_override = _host._mat(Color(0.07, 0.05, 0.035))
			_host.write_construction_tag(wheel, "world_prop_kind", "cart_wheel")
			_host.write_construction_tag(wheel, "world_prop_id", "greyfen_cart_wheel")
			_scope.zone_root.add_child(wheel)
	_host._make_world_prop_anchor("cart", "cart", pos)
