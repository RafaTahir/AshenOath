extends RefCounted

const LENGTH := 0.76

static func attach(parent: Node3D, model: Node3D, at_tip: bool = false) -> Node3D:
	var anchor := Node3D.new()
	parent.add_child(anchor)
	anchor.add_child(model)
	model.rotation = Vector3(-PI * 0.5, 0, 0)
	model.scale = Vector3.ONE * 0.25
	model.position = Vector3.ZERO
	var bounds: AABB = preload("res://scripts/character_role_contract.gd")._visible_bounds(model)
	if bounds.size.z > 0.0001:
		model.scale *= LENGTH / bounds.size.z
		bounds = preload("res://scripts/character_role_contract.gd")._visible_bounds(model)
	model.position = Vector3(-bounds.get_center().x, -bounds.get_center().y, -bounds.position.z if at_tip else -bounds.end.z)
	return anchor
