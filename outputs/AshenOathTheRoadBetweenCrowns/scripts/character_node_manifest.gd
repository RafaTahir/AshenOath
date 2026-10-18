extends RefCounted

## Relative paths and immutable metadata only; never a shared live actor node.
static func compile(root: Node3D) -> void:
	var meshes: Array[String] = []
	var players: Array[String] = []
	var skeletons: Array[String] = []
	_collect(root, root, meshes, players, skeletons)
	root.set_meta("prepared_mesh_paths", PackedStringArray(meshes))
	root.set_meta("prepared_player_paths", PackedStringArray(players))
	root.set_meta("prepared_skeleton_paths", PackedStringArray(skeletons))

static func _collect(root: Node, node: Node, meshes: Array[String], players: Array[String], skeletons: Array[String]) -> void:
	var parts: Array[String] = []
	var cursor := node
	while cursor != root:
		parts.push_front(str(cursor.name))
		cursor = cursor.get_parent()
	var path := "/".join(parts) if not parts.is_empty() else "."
	if node is MeshInstance3D:
		meshes.append(path)
	if node is AnimationPlayer:
		players.append(path)
	if node is Skeleton3D:
		skeletons.append(path)
	for child in node.get_children():
		_collect(root, child, meshes, players, skeletons)

static func meshes(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for path in root.get_meta("prepared_mesh_paths", PackedStringArray()):
		var node := root.get_node_or_null(NodePath(path)) as MeshInstance3D
		if node != null:
			result.append(node)
	return result
