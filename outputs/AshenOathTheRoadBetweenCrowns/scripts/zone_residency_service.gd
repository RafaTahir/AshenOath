class_name ZoneResidencyService
extends Node

const MAX_CACHED_ROUTE_ZONES := 1
const ZONE_RETIRE_FRAMES := 8
const MAX_SKINNED_RESOURCE_ANCHORS := 4
const MAX_RETIRED_MATERIAL_ANCHORS := 64

var route_zone_cache: Dictionary = {}
var route_enemy_cache: Dictionary = {}
var route_zone_signatures: Dictionary = {}
var route_spatial_cache: Dictionary = {}
var retired_zone_roots: Array[Node] = []
var pending_zone_retirements := 0
var retired_skinned_actor_pool: Node3D
var skinned_resource_anchors: Dictionary = {}
var retired_material_anchors: Dictionary = {}
var retirement_material: StandardMaterial3D
var validate_resources: Callable

func configure(validator: Callable) -> void:
	validate_resources = validator

func release_shared_anchors() -> void:
	for raw_branch in skinned_resource_anchors.values():
		var branch := raw_branch as Node
		if branch != null and is_instance_valid(branch):
			_release_zone_render_resources(branch)
			branch.free()
	skinned_resource_anchors.clear()
	if retired_skinned_actor_pool != null and is_instance_valid(retired_skinned_actor_pool):
		_release_zone_render_resources(retired_skinned_actor_pool)
		retired_skinned_actor_pool.free()
	retired_skinned_actor_pool = null

func release_material_anchors() -> void:
	retirement_material = null
	retired_material_anchors.clear()
	validate_resources = Callable()

func _deferred_free_zone(retired_root: Node) -> void:
	# Keep the complete render hierarchy intact until the scene tree disposes it.
	# Manually detaching skins or surfaces races RenderingServer teardown. The
	# hidden cleanup owner keeps the retired root scene-owned while queue_free()
	# lets Godot release renderer dependencies at the end of a frame.
	for _frame in range(ZONE_RETIRE_FRAMES):
		await get_tree().process_frame
	if is_instance_valid(retired_root):
		# The root has been hidden, disabled, and given a full renderer grace
		# window above. Release server-owned geometry before destroying the
		# hierarchy; this avoids leaving physics shapes and renderer instances
		# alive when a retired procedural zone is torn down.
		_release_zone_render_resources(retired_root)
		retired_zone_roots.erase(retired_root)
		retired_root.free()
	else:
		retired_zone_roots.erase(retired_root)
	pending_zone_retirements = maxi(pending_zone_retirements - 1, 0)
	# Material anchors only bridge the renderer-safe retirement window. Once the
	# final staged root has been queued and released, no retired scene owns those
	# materials anymore; dropping the anchors here prevents shutdown retention
	# while keeping shared materials alive for any active zone that still uses
	# them.
	if pending_zone_retirements == 0:
		retired_material_anchors.clear()

func _release_zone_render_resources(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	# CollisionShape3D owns a PhysicsServer shape RID while its shape property is
	# populated. Clear it after the zone is disabled so the server can release
	# the RID before the parent hierarchy is destroyed.
	for raw_shape in root.find_children("*", "CollisionShape3D", true, false):
		var shape_node := raw_shape as CollisionShape3D
		if shape_node == null:
			continue
		shape_node.disabled = true
		shape_node.shape = null
	for raw_region in root.find_children("*", "NavigationRegion3D", true, false):
		var region := raw_region as NavigationRegion3D
		if region == null:
			continue
		region.enabled = false
		region.navigation_mesh = null
	# MeshInstance3D and MultiMeshInstance3D similarly retain renderer-side
	# instances until their geometry reference is cleared. This is only called
	# for hidden/retiring roots, never for an active zone.
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null:
			continue
		mesh_instance.visible = false
		# Godot's renderer has a deletion-path bug when a MeshInstance retains both
		# a material_override and surface overrides while its mesh is detached.
		# Clear every instance binding before releasing the geometry so retirement
		# cannot emit a null-material error or leave a renderer dependency behind.
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, null)
		mesh_instance.material_override = null
		mesh_instance.mesh = null
	for raw_batch in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := raw_batch as MultiMeshInstance3D
		if batch == null:
			continue
		batch.visible = false
		batch.material_override = null
		batch.multimesh = null

func _retire_zone_root(retired_root: Node) -> void:
	if retired_root == null or not is_instance_valid(retired_root):
		return
	if retired_zone_roots.has(retired_root):
		return
	_remove_root_from_route_cache(retired_root)
	_anchor_retired_materials(retired_root)
	_anchor_shared_skinned_resources(retired_root)
	_quiesce_zone_runtime(retired_root)
	validate_resources.call(retired_root)
	_bind_retirement_material(retired_root)
	_set_zone_collision_enabled(retired_root, false)
	retired_root.visible = false
	retired_root.process_mode = Node.PROCESS_MODE_DISABLED
	retired_root.position = Vector3(0, -2000.0 - retired_zone_roots.size() * 100.0, 0)
	retired_root.name = "__retiring_%s_%d" % [str(retired_root.name), pending_zone_retirements]
	retired_root.set_meta("zone_resource_owner", "retiring")
	retired_zone_roots.append(retired_root)
	pending_zone_retirements += 1
	_deferred_free_zone(retired_root)

func _bind_retirement_material(root: Node) -> void:
	if retirement_material == null:
		retirement_material = StandardMaterial3D.new()
		retirement_material.albedo_color = Color(0.08, 0.08, 0.08)
		retirement_material.roughness = 1.0
	_keep_retired_material(retirement_material)
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh != null:
			# Retirement uses one material binding for the whole hidden instance.
			# Remove authored per-surface bindings first; keeping both binding types
			# is the renderer deletion pattern that produces null-material errors.
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, null)
		mesh_instance.material_override = retirement_material
	for raw_batch in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := raw_batch as MultiMeshInstance3D
		batch.material_override = retirement_material

func _anchor_retired_materials(root: Node) -> void:
	for raw_mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.material_override != null:
			_keep_retired_material(mesh_instance.material_override)
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material != null:
				_keep_retired_material(material)

func _keep_retired_material(material: Material) -> void:
	if retired_material_anchors.size() >= MAX_RETIRED_MATERIAL_ANCHORS:
		return
	var key := str(material.get_rid().get_id())
	if not retired_material_anchors.has(key):
		retired_material_anchors[key] = material

func _anchor_shared_skinned_resources(root: Node) -> void:
	if retired_skinned_actor_pool == null or not is_instance_valid(retired_skinned_actor_pool):
		retired_skinned_actor_pool = Node3D.new()
		retired_skinned_actor_pool.name = "SharedSkinnedResourceAnchors"
		retired_skinned_actor_pool.visible = false
		retired_skinned_actor_pool.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(retired_skinned_actor_pool)
	var branches: Array[Node] = []
	for raw_skeleton in root.find_children("*", "Skeleton3D", true, false):
		var branch := raw_skeleton as Node
		while branch.get_parent() != null and branch.get_parent() != root:
			branch = branch.get_parent()
		if branch.get_parent() == root and not branches.has(branch):
			branches.append(branch)
	for branch in branches:
		var fingerprint := _skinned_resource_fingerprint(branch)
		if fingerprint.is_empty() or skinned_resource_anchors.has(fingerprint):
			continue
		if skinned_resource_anchors.size() >= MAX_SKINNED_RESOURCE_ANCHORS:
			break
		# A skinned branch is detached from the zone before the normal zone
		# validation pass. Validate it in place so imported meshes with empty
		# surfaces cannot reach the renderer during retirement.
		validate_resources.call(branch)
		branch.reparent(retired_skinned_actor_pool, false)
		if branch is Node3D:
			(branch as Node3D).visible = false
		branch.process_mode = Node.PROCESS_MODE_DISABLED
		skinned_resource_anchors[fingerprint] = branch

func _skinned_resource_fingerprint(branch: Node) -> String:
	var fingerprints: Array[String] = []
	for raw_mesh in branch.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.skin == null or mesh_instance.mesh == null:
			continue
		var fingerprint := mesh_instance.mesh.resource_path
		if fingerprint.is_empty():
			fingerprint = "mesh_rid:%s" % str(mesh_instance.mesh.get_rid().get_id())
		if not fingerprints.has(fingerprint):
			fingerprints.append(fingerprint)
	fingerprints.sort()
	return "|".join(fingerprints)

func _quiesce_zone_runtime(root: Node) -> void:
	for raw_player in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := raw_player as AnimationPlayer
		animation_player.stop(true)
		animation_player.active = false
	for raw_tree in root.find_children("*", "AnimationTree", true, false):
		(raw_tree as AnimationTree).active = false
	for raw_audio in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(raw_audio as AudioStreamPlayer3D).stop()

func _cache_route_zone(zone_id: String, root: Node3D, enemies: Array, signature: int, keep_visible: bool = false, disable_collision: bool = true, disable_process: bool = true) -> void:
	if root == null or not is_instance_valid(root):
		return
	var existing = route_zone_cache.get(zone_id)
	if existing != null and existing != root and is_instance_valid(existing):
		_release_route_spatial_service(zone_id)
		_retire_zone_root(existing)
	_remove_root_from_route_cache(root)
	root.visible = keep_visible
	root.process_mode = Node.PROCESS_MODE_DISABLED if disable_process else Node.PROCESS_MODE_PAUSABLE
	root.position = Vector3.ZERO if keep_visible else Vector3(0, -1000, 0)
	root.set_meta("zone_resource_owner", "cached")
	root.set_meta("zone_resource_id", zone_id)
	var cached_collision_disabled := false
	if keep_visible and disable_collision:
		_set_zone_collision_enabled(root, false)
		cached_collision_disabled = true
	else:
		# Moving the inactive zone away removes route interference while keeping
		# its collision state intact. Re-enabling hundreds of cached colliders on
		# the next arrival made warm transitions miss the browser budget.
		cached_collision_disabled = false
	root.set_meta("cached_collision_disabled", cached_collision_disabled)
	root.set_meta("cached_process_disabled", disable_process)
	route_zone_cache[zone_id] = root
	route_enemy_cache[zone_id] = _valid_cached_enemies(enemies)
	route_zone_signatures[zone_id] = signature

func _cache_route_spatial_service(zone_id: String, service: Node) -> void:
	if service == null or not is_instance_valid(service):
		return
	var existing = route_spatial_cache.get(zone_id)
	if existing != null and existing != service and is_instance_valid(existing):
		existing.queue_free()
	service.process_mode = Node.PROCESS_MODE_DISABLED
	route_spatial_cache[zone_id] = service

func _release_route_spatial_service(zone_id: String, protected_services: Array = []) -> void:
	var cached = route_spatial_cache.get(zone_id)
	route_spatial_cache.erase(zone_id)
	if cached == null or not is_instance_valid(cached):
		return
	if protected_services.has(cached):
		return
	cached.queue_free()

func _activate_cached_zone(zone_id: String) -> Node3D:
	var cached_root = route_zone_cache.get(zone_id)
	if cached_root == null or not is_instance_valid(cached_root):
		return null
	route_zone_cache.erase(zone_id)
	cached_root.set_meta("zone_resource_owner", "active")
	cached_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	cached_root.position = Vector3.ZERO
	if bool(cached_root.get_meta("cached_collision_disabled", false)):
		_set_zone_collision_enabled(cached_root, true)
	cached_root.set_meta("cached_collision_disabled", false)
	cached_root.visible = true
	return cached_root as Node3D

func _remove_root_from_route_cache(root: Node) -> void:
	for raw_id in route_zone_cache.keys().duplicate():
		var id := str(raw_id)
		if route_zone_cache.get(id) == root:
			route_zone_cache.erase(id)
			route_enemy_cache.erase(id)
			route_zone_signatures.erase(id)

func _trim_route_zone_cache(preferred_ids: Array) -> void:
	var retained: Array[String] = []
	for raw_id in preferred_ids:
		var id := str(raw_id)
		if route_zone_cache.has(id) and not retained.has(id) and retained.size() < MAX_CACHED_ROUTE_ZONES:
			retained.append(id)
	for raw_id in route_zone_cache.keys().duplicate():
		var id := str(raw_id)
		if retained.has(id):
			continue
		var cached_root = route_zone_cache.get(id)
		route_zone_cache.erase(id)
		route_enemy_cache.erase(id)
		route_zone_signatures.erase(id)
		_release_route_spatial_service(id)
		if is_instance_valid(cached_root):
			_retire_zone_root(cached_root)

func _set_zone_collision_enabled(node: Node, enabled: bool) -> void:
	var targets: Array = node.get_meta("zone_collision_targets", [])
	if targets.is_empty():
		targets = _collect_zone_collision_targets(node)
		node.set_meta("zone_collision_targets", targets)
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		_set_single_zone_collision_enabled(target, enabled)

func _collect_zone_collision_targets(root: Node) -> Array:
	var targets: Array = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is NavigationRegion3D or current is CollisionObject3D:
			targets.append(current)
		for child in current.get_children():
			pending.append(child)
	return targets

func _set_single_zone_collision_enabled(node: Node, enabled: bool) -> void:
	if node is NavigationRegion3D:
		(node as NavigationRegion3D).enabled = enabled
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta("zone_collision_layer"):
			collision_object.set_meta("zone_collision_layer", collision_object.collision_layer)
			collision_object.set_meta("zone_collision_mask", collision_object.collision_mask)
		collision_object.collision_layer = int(collision_object.get_meta("zone_collision_layer", 1)) if enabled else 0
		collision_object.collision_mask = int(collision_object.get_meta("zone_collision_mask", 1)) if enabled else 0
	if node is Area3D:
		var area := node as Area3D
		if not area.has_meta("zone_monitoring"):
			area.set_meta("zone_monitoring", area.monitoring)
			area.set_meta("zone_monitorable", area.monitorable)
		area.monitoring = bool(area.get_meta("zone_monitoring", true)) if enabled else false
		area.monitorable = bool(area.get_meta("zone_monitorable", true)) if enabled else false

func _valid_cached_enemies(entries: Array) -> Array:
	var result: Array = []
	for enemy in entries:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result
