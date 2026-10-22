extends RefCounted

## Offline skin compilation for the Ranger's retained Universal head layers.
## Body geometry, material bindings and the existing locomotion bones stay intact.
static func compile(root: Node3D) -> bool:
	var skeleton: Skeleton3D
	for candidate: Node in root.find_children("*", "Skeleton3D", true, false):
		skeleton = candidate as Skeleton3D
		break
	if skeleton == null:
		return false
	if skeleton.find_bone("Face_Jaw") >= 0:
		return true
	var head := skeleton.find_bone("Head")
	if head < 0:
		return false
	var layers: Array[Dictionary] = []
	var eyes: Array[Vector3] = []
	var head_rest := skeleton.get_bone_global_rest(head)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null or mesh.mesh == null or not bool(mesh.get_meta("cast_head_layer", false)):
			continue
		var head_bind := -1
		for index in mesh.skin.get_bind_count():
			if mesh.skin.get_bind_bone(index) == head or str(mesh.skin.get_bind_name(index)) == "Head":
				head_bind = index
				break
		if head_bind < 0:
			return false
		var to_skeleton := head_rest * mesh.skin.get_bind_pose(head_bind)
		layers.append({"node":mesh, "head_bind":head_bind, "to_skeleton":to_skeleton})
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if _region(material) != "eyes":
				continue
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				eyes.append(to_skeleton * vertex)
	if layers.is_empty() or eyes.is_empty():
		push_error("Ranger facial source requires composed head skin and eye surfaces; layers=%s eyes=%s" % [layers.size(), eyes.size()])
		return false
	var bounds := AABB(eyes[0], Vector3.ZERO)
	var positive_min := INF
	for point in eyes:
		bounds = bounds.expand(point)
		if point.x > 0.0:
			positive_min = minf(positive_min, point.x)
	if not is_finite(positive_min):
		return false
	var center := bounds.get_center()
	var eye_x := (bounds.end.x + positive_min) * 0.5
	var front := 1.0 if center.z >= head_rest.origin.z else -1.0
	var centers: Dictionary = {}
	for side: String in ["L", "R"]:
		var sign_value := 1.0 if side == "L" else -1.0
		centers["Eye_" + side] = Vector3(sign_value*eye_x, center.y, center.z)
		centers["LidUpper_" + side] = Vector3(sign_value*eye_x, center.y+0.014, center.z+front*0.009)
		centers["LidLower_" + side] = Vector3(sign_value*eye_x, center.y-0.014, center.z+front*0.009)
		centers["Brow_" + side] = Vector3(sign_value*eye_x, center.y+0.028, center.z+front*0.013)
		centers["Mouth_" + side] = Vector3(sign_value*0.016, center.y-0.058, center.z+front*0.016)
	centers.Jaw = Vector3(0, center.y-0.063, center.z-front*0.018)
	var controls: Dictionary = {}
	var weighted: Dictionary = {}
	for name: String in centers:
		skeleton.add_bone("Face_" + name)
		var bone := skeleton.get_bone_count()-1
		skeleton.set_bone_parent(bone, head)
		skeleton.set_bone_rest(bone, head_rest.affine_inverse() * Transform3D(Basis.IDENTITY, centers[name]))
		controls[name] = bone
		weighted[name] = 0
	for layer: Dictionary in layers:
		var node: MeshInstance3D = layer.node
		var source: Mesh = node.mesh
		var skin := node.skin.duplicate() as Skin
		var binds: Dictionary = {}
		for name: String in centers:
			binds[name] = skin.get_bind_count()
			var rest := Transform3D(Basis.IDENTITY, centers[name])
			skin.add_bind(int(controls[name]), rest.affine_inverse() * layer.to_skeleton)
		var compiled := ArrayMesh.new()
		compiled.resource_name = source.resource_name
		for surface in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.size() != vertices.size()*4 or weights.size() != bones.size():
				return false
			var region := _region(node.get_active_material(surface) as BaseMaterial3D)
			for index in vertices.size():
				var point: Vector3 = layer.to_skeleton * vertices[index]
				var side := "L" if point.x >= 0.0 else "R"
				var influences: Dictionary = {}
				if region in ["eyes", "brows"]:
					influences[("Eye_" if region == "eyes" else "Brow_") + side] = 0.9
				elif region == "skin" and point.y > center.y-0.13 and (point.z-center.z)*front > -0.008:
					var eye_weight := _band(absf(point.x), eye_x, 0.029)
					var upper := point.y >= center.y
					influences[("LidUpper_" if upper else "LidLower_") + side] = eye_weight*_band(point.y, center.y+(0.012 if upper else -0.012), 0.020)
					influences["Brow_" + side] = eye_weight*_band(point.y, center.y+0.031, 0.021)*0.65
					influences["Mouth_" + side] = _band(point.x, 0.016 if side == "L" else -0.016, 0.026)*_band(point.y, center.y-0.058, 0.022)*0.7
					influences.Jaw = _band(point.x, 0, 0.085)*_band(point.y, center.y-0.088, 0.045)*0.65
				var total := 0.0
				for name: String in influences.keys():
					if float(influences[name]) <= 0.015:
						influences.erase(name)
					else:
						total += float(influences[name])
				if influences.is_empty():
					continue
				var merged: Dictionary = {}
				var scale_value := minf(1.0, 0.9/maxf(total, 0.001))
				for name: String in influences:
					merged[int(binds[name])] = float(influences[name])*scale_value
					weighted[name] += 1
				var remaining := 1.0-minf(total, 0.9)
				for component in range(4):
					var slot := index*4+component
					merged[bones[slot]] = float(merged.get(bones[slot], 0.0))+weights[slot]*remaining
				var strongest: Array = merged.keys()
				strongest.sort_custom(func(a, b): return float(merged[a]) > float(merged[b]))
				strongest.resize(mini(4, strongest.size()))
				var normalization := 0.0
				for bind: int in strongest:
					normalization += float(merged[bind])
				for component in range(4):
					var bind := int(strongest[component]) if component < strongest.size() else int(layer.head_bind)
					bones[index*4+component] = bind
					weights[index*4+component] = float(merged[bind])/normalization if component < strongest.size() else 0.0
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			# Imported eye/brow layers contain custom channels. Their format bits
			# must accompany the arrays or Godot rejects those complete surfaces.
			var format: int = source.surface_get_format(surface) if source is ArrayMesh else 0
			compiled.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, format)
			if compiled.get_surface_count() != surface+1:
				push_error("Ranger facial surface cannot be compiled: %s[%s], format=%s" % [node.name, surface, format])
				return false
			compiled.surface_set_material(surface, source.surface_get_material(surface))
			if source is ArrayMesh:
				compiled.surface_set_name(surface, source.surface_get_name(surface))
		node.mesh = compiled
		node.skin = skin
	for count: int in weighted.values():
		if count <= 0:
			push_error("Ranger facial controls lack weighted anatomy: %s; eye bounds=%s head rest=%s" % [weighted, bounds, head_rest])
			return false
	return true

static func _region(material: BaseMaterial3D) -> String:
	if material == null:
		return ""
	var token := str(material.resource_name).to_lower()
	if material.albedo_texture != null:
		token += " " + str(material.albedo_texture.resource_path).to_lower()
	if token.contains("eye"):
		return "eyes"
	if token.contains("hair"):
		return "brows"
	return "skin"

static func _band(value: float, center: float, radius: float) -> float:
	return pow(maxf(0, 1.0-absf(value-center)/radius), 2.0)
