extends RefCounted

static func resolve(node: Node) -> Camera3D:
	var viewport := node.get_viewport()
	# Published prepared zones share their parent's rendered World3D. Their
	# isolated viewport stays attached for scene ownership with drawing disabled.
	if viewport is SubViewport and viewport.has_meta("prepared_zone_view") and not viewport.own_world_3d:
		var owner := viewport.get_parent()
		viewport = owner.get_viewport() if owner != null else null
	return viewport.get_camera_3d() if viewport != null else null
