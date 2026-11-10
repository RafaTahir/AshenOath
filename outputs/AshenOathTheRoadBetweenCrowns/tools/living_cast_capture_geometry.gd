extends RefCounted

func support_point(space: PhysicsDirectSpaceState3D, feet: Vector3, excluded: Array, max_height_delta: float) -> Vector3:
	# Spatial clearance expects a ground/feet point, not a capsule centre.
	# A named activity coordinate alone cannot establish a floor beneath it.
	if space == null or not feet.is_finite(): return Vector3.INF
	var excluded_rids: Array[RID] = []
	excluded_rids.assign(excluded)
	var query := PhysicsRayQueryParameters3D.create(feet+Vector3.UP*2.0,feet-Vector3.UP*2.0,1,excluded_rids)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7: return Vector3.INF
	var support: Vector3 = hit.position
	return support if absf(support.y-feet.y) <= max_height_delta else Vector3.INF

## Capture-only visual geometry. Physics masks do not include decorative facades.
## Build each mesh BVH once, outside measured windows; query current transforms.
var entries: Array[Dictionary] = []
var meshes: Dictionary = {}
var skipped_skinned := 0

func build(scene: Node, player: Node3D = null) -> Dictionary:
	entries.clear()
	meshes.clear()
	skipped_skinned = 0
	_collect(scene, player)
	return {"instances":entries.size(), "unique_meshes":meshes.size(), "skipped_skinned":skipped_skinned,
		"method":"render mesh TriangleMesh BVH; live visibility, layers and transforms; actor/player excluded",
		"limitations":"conservative triangle coverage, not raster alpha/material sampling; particles and other skinned actors require image review"}

func _collect(node: Node, player: Node3D) -> void:
	if node == player:
		return
	if node is MeshInstance3D and node.mesh != null:
		if node.skin != null:
			skipped_skinned += 1
		else:
			_add_mesh(node, node.mesh, -1)
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		var count: int = node.multimesh.instance_count
		if node.multimesh.visible_instance_count >= 0:
			count = mini(count, node.multimesh.visible_instance_count)
		for index in range(count):
			_add_mesh(node, node.multimesh.mesh, index)
	for child: Node in node.get_children():
		_collect(child, player)

func _add_mesh(node: GeometryInstance3D, mesh: Mesh, instance: int) -> void:
	var id := mesh.get_instance_id()
	if not meshes.has(id):
		meshes[id] = mesh.generate_triangle_mesh()
	if meshes[id] != null:
		entries.append({"node":weakref(node), "mesh":id, "instance":instance, "bounds":mesh.get_aabb()})

func obstruction(start: Vector3, finish: Vector3, actor: Node3D, cull_mask: int) -> Dictionary:
	return _query_obstruction(start, finish, _query_entries(actor, cull_mask))

func _query_entries(actor: Node3D, cull_mask: int) -> Array[Dictionary]:
	# One fresh snapshot per validation, shared by its five rays. Transform and
	# visibility work used to run five times per sample (and twice per image).
	# Rebuild on every call so same-frame movement/hiding still invalidates hits.
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var node: GeometryInstance3D = entry.node.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree() or (node.layers & cull_mask) == 0:
			continue
		if is_instance_valid(actor) and (node == actor or actor.is_ancestor_of(node)):
			continue
		var transform := node.global_transform
		if int(entry.instance) >= 0:
			var multi: MultiMesh = node.multimesh
			if int(entry.instance) >= multi.instance_count or (multi.visible_instance_count >= 0 and int(entry.instance) >= multi.visible_instance_count):
				continue
			transform = transform * multi.get_instance_transform(int(entry.instance))
		if absf(transform.basis.determinant()) < 0.000001:
			continue
		result.append({"node":node, "mesh":entry.mesh, "instance":entry.instance,
			"transform":transform, "inverse":transform.affine_inverse(), "bounds":transform * (entry.bounds as AABB)})
	return result

func _query_obstruction(start: Vector3, finish: Vector3, candidates: Array[Dictionary]) -> Dictionary:
	var direction := finish - start
	if direction.length_squared() <= 0.0001: return {}
	var end := finish - direction.normalized() * 0.035
	var nearest: Dictionary = {}
	var nearest_distance := start.distance_squared_to(end)
	for entry: Dictionary in candidates:
		var bounds: AABB = entry.bounds
		if not bounds.has_point(start) and bounds.intersects_segment(start, end) == null: continue
		var inverse: Transform3D = entry.inverse
		var local_start := inverse * start
		var local_end := inverse * end
		var hit: Dictionary = meshes[entry.mesh].intersect_segment(local_start, local_end)
		if hit.is_empty():
			continue
		var position: Vector3 = (entry.transform as Transform3D) * hit.position
		var distance := start.distance_squared_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = {"node":str(entry.node.get_path()), "position":[position.x,position.y,position.z], "distance":sqrt(distance), "instance":entry.instance}
	return nearest

func validate_actor(camera: Camera3D, actor: Node3D, viewport: Vector2i, forward: Vector3) -> Dictionary:
	if actor.get_viewport().get_camera_3d() != camera:
		return {"reason":"fixture camera lost current ownership"}
	var height := float(actor.get_meta("cast_eye_height", 1.6))
	var right := forward.cross(Vector3.UP).normalized()
	var targets := [actor.global_position+Vector3.UP*height,actor.global_position+Vector3.UP*1.1,
		actor.global_position+Vector3.UP*0.7,actor.global_position+Vector3.UP*1.05+right*0.23,
		actor.global_position+Vector3.UP*1.05-right*0.23]
	var candidates := _query_entries(actor, camera.cull_mask)
	for target: Vector3 in targets:
		if camera.is_position_behind(target): return {"reason":"actor behind camera"}
		var pixel := camera.unproject_position(target)
		if pixel.x < viewport.x*0.07 or pixel.x > viewport.x*0.93 or pixel.y < viewport.y*0.07 or pixel.y > viewport.y*0.93:
			return {"reason":"actor projection outside safe frame","pixel":[pixel.x,pixel.y]}
		var hit := _query_obstruction(camera.global_position,target,candidates)
		if not hit.is_empty(): return {"reason":"rendered mesh obstruction","hit":hit}
	return {}
