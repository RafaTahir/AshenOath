extends RefCounted

static func validate(root: Node, require_animation: bool = true) -> Dictionary:
	var skeletons: Array = []
	var meshes: Array[MeshInstance3D] = []
	var animation_players: Array = []
	_collect(root,skeletons,meshes,animation_players)
	var bounds := _combined_bounds(root,meshes)
	var complete_bounds := bounds.size.y >= 1.35 and bounds.size.x >= 0.28 and bounds.size.z >= 0.16
	var has_skin := false
	for mesh in meshes:
		if mesh.skin != null or mesh.skeleton != NodePath(""):
			has_skin = true
			break
	var valid := not meshes.is_empty() and not skeletons.is_empty() and has_skin and complete_bounds
	if require_animation:
		valid = valid and not animation_players.is_empty()
	return {
		"valid":valid,
		"skeleton_count":skeletons.size(),
		"mesh_count":meshes.size(),
		"animation_player_count":animation_players.size(),
		"bounds":bounds,
		"has_skin":has_skin,
		"complete_bounds":complete_bounds,
	}

static func remove_proxy_anatomy(root: Node) -> void:
	var forbidden := ["faceplane","motion_arm","motion_leg","weapon_arm","longarm","clawleft","clawright","chestread","bootread","hair silhouette"]
	for child in root.get_children():
		remove_proxy_anatomy(child)
		var lowered := str(child.name).to_lower().replace("_"," ")
		for token in forbidden:
			if lowered.contains(token):
				child.queue_free()
				break

static func _collect(node: Node, skeletons: Array, meshes: Array[MeshInstance3D], animation_players: Array) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is MeshInstance3D and not str(node.name).to_lower().contains("shadow"):
		meshes.append(node)
	if node is AnimationPlayer:
		animation_players.append(node)
	for child in node.get_children():
		_collect(child,skeletons,meshes,animation_players)

static func _combined_bounds(root: Node, meshes: Array[MeshInstance3D]) -> AABB:
	var result := AABB()
	var initialized := false
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		var local_transform := _transform_relative_to(mesh,root)
		var bounds := local_transform * mesh.mesh.get_aabb()
		result = result.merge(bounds) if initialized else bounds
		initialized = true
	return result

static func _transform_relative_to(node: Node3D, root: Node) -> Transform3D:
	var transform := node.transform
	var current := node.get_parent()
	while current != null and current != root:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform
