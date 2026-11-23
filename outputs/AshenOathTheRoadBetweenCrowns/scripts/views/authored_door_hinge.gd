extends RefCounted

static var _door_meshes: Dictionary = {}

static func open_authored_door(door: MeshInstance3D) -> void:
	if door.mesh == null or door.mesh.get_surface_count() < 2 or door.has_node("OpenDoorHinge"): return
	var source := door.mesh as ArrayMesh
	if source == null: return
	var materials: Array[Material] = []
	for i in range(source.get_surface_count()):
		materials.append(door.get_active_material(i))
		door.set_surface_override_material(i,null)
	var key := source.get_rid()
	if not _door_meshes.has(key):
		var frame := ArrayMesh.new()
		var leaf := ArrayMesh.new()
		for i in range(source.get_surface_count()):
			var mesh := leaf if i == 1 else frame
			mesh.add_surface_from_arrays(source.surface_get_primitive_type(i),source.surface_get_arrays(i))
		_door_meshes[key] = [frame,leaf]
	var parts: Array = _door_meshes[key]
	door.mesh = parts[0]
	var surface := 0
	for i in range(materials.size()):
		if i == 1: continue
		door.set_surface_override_material(surface,materials[i]); surface += 1
	var hinge := Node3D.new(); hinge.name = "OpenDoorHinge"
	var leaf := MeshInstance3D.new(); leaf.mesh = parts[1]
	hinge.position.x = leaf.mesh.get_aabb().position.x
	leaf.position.x = -hinge.position.x
	leaf.material_override = materials[1]
	leaf.cast_shadow = door.cast_shadow
	door.add_child(hinge); hinge.add_child(leaf)
	hinge.rotation.y = PI*0.5
