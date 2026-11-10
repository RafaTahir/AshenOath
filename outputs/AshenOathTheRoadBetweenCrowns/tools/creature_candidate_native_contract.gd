extends RefCounted

## Raw native equivalence only. Never prepare, normalize, correct or promote.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const MAX_COMPONENT_ERROR := 0.000001
const AMBIENT_CLIPS := ["Idle", "Investigate", "Feed", "Sleep"]

static func compare(candidate: Node3D, retained_path: String) -> Dictionary:
	var report := {"verified":false, "retained_path":retained_path, "component_tolerance":MAX_COMPONENT_ERROR,
		"errors":[], "frames":{}, "rests":{}, "mesh_bounds":{}, "aggregate_bounds":{}, "protected_clips":{},
		"normalization_applied":false, "prepared_role_scale_verified":false, "collision_dimensions_verified":false, "visual_accepted":false}
	if candidate == null or not FileAccess.file_exists(retained_path):
		report.errors.append("Missing candidate scene or retained GLB")
		return report
	var source_sha := FileAccess.get_sha256(retained_path)
	report["retained_sha256"] = source_sha
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(retained_path, state) != OK:
		report.errors.append("Retained GLB cannot import through the same native path")
		return report
	var retained := document.generate_scene(state) as Node3D
	if retained == null:
		report.errors.append("Retained GLB does not produce a native scene")
		return report
	if retained.has_meta("prepared_source_bounds") or candidate.has_meta("prepared_source_bounds"):
		report.errors.append("Raw candidate comparison must not use overridden prepared bounds")
	var original: Dictionary = {"frames":{}, "rests":{}, "mesh_bounds":{}}
	var current: Dictionary = {"frames":{}, "rests":{}, "mesh_bounds":{}}
	_inventory(retained, ".", original)
	_inventory(candidate, ".", current)
	for field: String in ["frames", "rests", "mesh_bounds"]:
		var before: Array = original[field].keys()
		var after: Array = current[field].keys()
		before.sort()
		after.sort()
		if before != after:
			report.errors.append("Native " + field + " identity/multiplicity changed")
		for path: String in before:
			if not current[field].has(path): continue
			if field == "frames":
				var error := _transform_error(original[field][path], current[field][path])
				report.frames[path] = error
				if error > MAX_COMPONENT_ERROR: report.errors.append("Raw node frame changed: " + path)
			elif field == "mesh_bounds":
				var error := _bounds_error(original[field][path], current[field][path])
				report.mesh_bounds[path] = {"retained":_bounds_data(original[field][path]), "candidate":_bounds_data(current[field][path]), "maximum_error":error}
				if error > MAX_COMPONENT_ERROR: report.errors.append("Native mesh AABB changed: " + path)
			else:
				var left: Array = original.rests[path]
				var right: Array = current.rests[path]
				var error := 0.0
				if left.size() != right.size():
					report.errors.append("Skeleton bone count changed: " + path)
				for index in mini(left.size(), right.size()):
					if left[index].name != right[index].name or left[index].parent != right[index].parent:
						report.errors.append("Skeleton identity/order/parent changed: " + path + "/" + str(index))
					error = maxf(error, _transform_error(left[index].rest, right[index].rest))
					error = maxf(error, _transform_error(left[index].pose, right[index].pose))
				report.rests[path] = {"bones":left.size(), "maximum_error":error}
				if error > MAX_COMPONENT_ERROR: report.errors.append("Raw skeleton rest/default pose changed: " + path)
	if original.frames.is_empty() or original.rests.is_empty() or original.mesh_bounds.is_empty():
		report.errors.append("Retained candidate inventory lacks actual frames, skeletons or meshes")
	var helper := Helper.new()
	var original_bounds: AABB = helper._calculate_node_bounds(retained)
	var candidate_bounds: AABB = helper._calculate_node_bounds(candidate)
	helper.free()
	var bounds_error := _bounds_error(original_bounds, candidate_bounds)
	report.aggregate_bounds = {"owner":"AssetSpawnHelper._calculate_node_bounds", "retained":_bounds_data(original_bounds), "candidate":_bounds_data(candidate_bounds), "maximum_error":bounds_error}
	if original_bounds.size == Vector3.ZERO or candidate_bounds.size == Vector3.ZERO:
		report.errors.append("Actual native normalization bounds are empty")
	if bounds_error > MAX_COMPONENT_ERROR:
		report.errors.append("Actual native normalization bounds changed")
	var original_clips := _protected_fingerprints(retained)
	var candidate_clips := _protected_fingerprints(candidate)
	report.protected_clips = {"retained":original_clips, "candidate":candidate_clips, "equal":original_clips == candidate_clips}
	if original_clips.is_empty() or original_clips != candidate_clips:
		report.errors.append("Retained protected native animation fingerprints changed")
	retained.free()
	if FileAccess.get_sha256(retained_path) != source_sha:
		report.errors.append("Retained source bytes changed during read-only comparison")
	report.verified = report.errors.is_empty()
	return report

static func _inventory(node: Node, path: String, result: Dictionary) -> void:
	if node is Node3D:
		result.frames[path] = (node as Node3D).transform
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var bones: Array[Dictionary] = []
		for index in skeleton.get_bone_count():
			bones.append({"name":str(skeleton.get_bone_name(index)), "parent":skeleton.get_bone_parent(index), "rest":skeleton.get_bone_rest(index), "pose":skeleton.get_bone_pose(index)})
		result.rests[path] = bones
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.mesh_bounds[path] = (node as MeshInstance3D).mesh.get_aabb()
	for child: Node in node.get_children():
		_inventory(child, path + "/" + str(child.name), result)

static func _transform_error(first: Transform3D, second: Transform3D) -> float:
	if not first.is_finite() or not second.is_finite(): return INF
	var maximum := 0.0
	for column in 4:
		var left: Vector3 = first.origin if column == 3 else first.basis[column]
		var right: Vector3 = second.origin if column == 3 else second.basis[column]
		for axis in 3: maximum = maxf(maximum, absf(left[axis] - right[axis]))
	return maximum

static func _bounds_error(first: AABB, second: AABB) -> float:
	if not first.position.is_finite() or not first.size.is_finite() or not second.position.is_finite() or not second.size.is_finite(): return INF
	var maximum := 0.0
	for axis in 3:
		maximum = maxf(maximum, absf(first.position[axis] - second.position[axis]))
		maximum = maxf(maximum, absf(first.size[axis] - second.size[axis]))
	return maximum

static func _bounds_data(bounds: AABB) -> Dictionary:
	return {"position":[bounds.position.x, bounds.position.y, bounds.position.z], "size":[bounds.size.x, bounds.size.y, bounds.size.z]}

static func _protected_fingerprints(node: Node) -> Dictionary:
	var result := {}
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for name: StringName in player.get_animation_list():
			if str(name).get_file() in AMBIENT_CLIPS: continue
			var animation := player.get_animation(name)
			var values: Array = [animation.length, animation.loop_mode]
			for track in animation.get_track_count():
				values.append([animation.track_get_type(track), str(animation.track_get_path(track)), animation.track_is_enabled(track), animation.track_get_interpolation_type(track)])
				for key in animation.track_get_key_count(track): values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key)])
			result[str(name)] = var_to_str(values).sha256_text()
	for child: Node in node.get_children():
		var nested := _protected_fingerprints(child)
		for key: String in nested: result[str(child.name) + "/" + key] = nested[key]
	return result
