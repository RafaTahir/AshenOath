extends RefCounted

const Api = preload("res://scripts/core/zone_construction_api.gd")
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
const TREES_PER_UNIT := 16
var _host: Api
var _scope: Scope

func _init(host: Api, scope: Scope) -> void:
	_host = host
	_scope = scope

func flush_authored() -> bool:
	var plan := _authored_tree_plan()
	for batch: Dictionary in plan.batches:
		_resolve_tree_source(plan, batch)
	for batch: Dictionary in plan.batches:
		_append_tree_transforms(plan, batch, 0, batch.items.size())
		_publish_authored_tree_batch(plan, batch)
	return bool(plan.authored)

func publication_units() -> Array[Callable]:
	var plan := _authored_tree_plan()
	var units := _authored_tree_units(plan)
	units.append(_publish_tree_fallback.bind(plan))
	return units

func _authored_tree_plan() -> Dictionary:
	var batches: Array[Dictionary] = []
	var plan := {"authored": false, "batches": batches}
	if _host.asset_helper == null or _host.settings == null:
		return plan
	if str(_host.settings.settings.get("quality_preset", "balanced")) == "potato":
		return plan
	var grouped_items: Dictionary = {}
	for item in _scope.tree_batch_data:
		var role := str(item.get("asset_role", "forest_tree"))
		if not grouped_items.has(role):
			grouped_items[role] = []
		grouped_items[role].append(item)
	for role: String in grouped_items:
		batches.append({"role": role, "items": grouped_items[role], "transforms": [], "clearance": null})
	plan.authored = not batches.is_empty()
	return plan

func _authored_tree_units(plan: Dictionary) -> Array[Callable]:
	var units: Array[Callable] = []
	# Resolve every authored source before emitting either visual or collision
	# nodes so a broken later role can use the original whole-zone fallback.
	for batch: Dictionary in plan.batches:
		units.append(_resolve_tree_source.bind(plan, batch))
	for batch: Dictionary in plan.batches:
		var items: Array = batch.items
		for start in range(0, items.size(), TREES_PER_UNIT):
			units.append(_append_tree_transforms.bind(plan, batch, start, mini(start + TREES_PER_UNIT, items.size())))
		units.append(_publish_authored_tree_batch.bind(plan, batch))
	return units

func _resolve_tree_source(plan: Dictionary, batch: Dictionary) -> void:
	if not bool(plan.authored):
		return
	var source: Dictionary = _host.asset_helper.forest_tree_source(str(batch.role))
	batch.source = source
	plan.authored = not source.is_empty()

func _append_tree_transforms(plan: Dictionary, batch: Dictionary, start: int, end: int) -> void:
	if not bool(plan.authored):
		return
	var clearance: StaticBody3D = batch.clearance
	if clearance == null:
		clearance = StaticBody3D.new()
		clearance.name = "TreeCameraClearance_%s" % str(batch.role).replace(":", "_")
		clearance.collision_layer = 1 << 6
		clearance.collision_mask = 0
		_scope.zone_root.add_child(clearance)
		batch.clearance = clearance
	var source: Dictionary = batch.source
	var bounds: AABB = source.bounds
	var normalization: Transform3D = source.normalization
	for index in range(start, end):
		var item: Dictionary = batch.items[index]
		var position: Vector3 = item.get("asset_position", Vector3.ZERO)
		var scale_value: Vector3 = item.get("asset_scale", Vector3.ONE)
		var yaw := float(item.get("asset_yaw", 0.0))
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(scale_value)
		var transform := Transform3D(basis, position) * normalization
		batch.transforms.append(transform)
		var shape := CollisionShape3D.new()
		shape.shape = preload("res://scripts/immutable_collision_shapes.gd").box(bounds.size * scale_value * float(source.scale))
		shape.transform = Transform3D(Basis(Vector3.UP, yaw), transform * bounds.get_center())
		clearance.add_child(shape)

func _publish_authored_tree_batch(plan: Dictionary, batch: Dictionary) -> void:
	if not bool(plan.authored):
		return
	var source: Dictionary = batch.source
	var mesh: Mesh = source.mesh
	var material: Material = source.material
	if material == null and mesh.get_surface_count() == 1:
		material = _host.world_materials.get_material("forest_ground", str(_host.settings.settings.get("quality_preset", "balanced")), Color(0.08, 0.18, 0.09), 0.0, false)
	var name := "AuthoredTreeBatch_%s" % str(batch.role).replace(":", "_")
	var trees := _host._make_multimesh_batch(name, mesh, batch.transforms.size(), material)
	_host._upload_static_batch(trees, batch.transforms)

func _publish_procedural_trees() -> void:
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.42, 1.8, 0.42)
	var trunks := _host._make_multimesh_batch("TreeTrunkBatch", trunk_mesh, _scope.tree_batch_data.size(), _host.world_materials.get_material("timber", str(_host.settings.settings.get("quality_preset", "balanced")), Color(0.42, 0.30, 0.20), 0.0, false))
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.72
	crown_mesh.height = 1.62
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var crown_material := _host._mat(Color.WHITE)
	crown_material.vertex_color_use_as_albedo = true
	var crowns := _host._make_multimesh_batch("TreeCrownBatch", crown_mesh, _scope.tree_batch_data.size(), crown_material, true)
	var trunk_transforms: Array = []
	var crown_transforms: Array = []
	var crown_colors: Array = []
	for item: Dictionary in _scope.tree_batch_data:
		trunk_transforms.append(item.trunk)
		var crown_transform: Transform3D = item.crown
		crown_transform.basis = crown_transform.basis.scaled(Vector3(1.10, 0.72, 1.10))
		crown_transforms.append(crown_transform)
		crown_colors.append(item.color)
	_host._upload_static_batch(trunks, trunk_transforms)
	_host._upload_static_batch(crowns, crown_transforms, crown_colors)

func _publish_tree_fallback(plan: Dictionary) -> void:
	if not bool(plan.authored):
		_publish_procedural_trees()

func flush() -> void:
	if not _scope.tree_batch_data.is_empty() and not flush_authored():
		_publish_procedural_trees()
