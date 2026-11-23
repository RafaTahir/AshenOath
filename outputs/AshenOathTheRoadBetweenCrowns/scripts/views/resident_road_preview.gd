extends RefCounted

var _previews: Dictionary = {}

func begin(root: Node, source_zone: String) -> bool:
	var roads := root.get_node_or_null("ConnectedRoads")
	var approach := roads.get_node_or_null("RoadTo_" + source_zone) if roads != null else null
	if not is_instance_valid(approach):
		return false
	var id: int = root.get_instance_id()
	var previous: Dictionary = _previews.get(id, {})
	if not previous.is_empty() and previous.approach.get_ref() == approach:
		return true
	end(root)
	var visibility: Array[Dictionary] = []
	_previews[id] = {"approach": weakref(approach), "mode": approach.process_mode, "visibility": visibility}
	# Only the reciprocal road should be rendered or support the crossing.
	approach.process_mode = Node.PROCESS_MODE_PAUSABLE
	var pending: Array[Node] = []
	for child: Node in root.get_children():
		if child != roads:
			pending.append(child)
	for child: Node in roads.get_children():
		if child != approach:
			pending.append(child)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node3D:
			visibility.append({"node": weakref(node), "visible": node.visible})
			node.visible = false
		else:
			for child: Node in node.get_children():
				pending.append(child)
	return true

func end(root: Node) -> void:
	var id: int = root.get_instance_id()
	if not _previews.has(id):
		return
	var preview: Dictionary = _previews[id]
	_previews.erase(id)
	for entry: Dictionary in preview.visibility:
		var node := entry.node.get_ref() as Node3D
		if is_instance_valid(node):
			node.visible = bool(entry.visible)
	var approach := preview.approach.get_ref() as Node
	if is_instance_valid(approach):
		approach.process_mode = int(preview.mode)
