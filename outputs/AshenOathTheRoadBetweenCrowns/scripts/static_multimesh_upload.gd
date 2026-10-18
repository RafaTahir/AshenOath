extends RefCounted

static func upload(batch: MultiMesh, transforms: Array, colors: Array = [], calculate_bounds: bool = false) -> void:
	if batch.transform_format != MultiMesh.TRANSFORM_3D or batch.instance_count != transforms.size():
		push_error("Static batch buffer must match its declared 3D instance count")
		return
	if batch.use_colors and not colors.is_empty() and colors.size() != transforms.size():
		push_error("Static batch colors must match its declared instance count")
		return
	var stride := 12 + (4 if batch.use_colors else 0) + (4 if batch.use_custom_data else 0)
	# Preserve custom data if a future caller uses it; these authored batches do not.
	var data := batch.buffer if batch.use_custom_data else PackedFloat32Array()
	data.resize(transforms.size() * stride)
	var bounds := AABB()
	var source_bounds := batch.mesh.get_aabb() if calculate_bounds else AABB()
	for index in transforms.size():
		var transform: Transform3D = transforms[index]
		var offset := index * stride
		data[offset] = transform.basis.x.x
		data[offset + 1] = transform.basis.y.x
		data[offset + 2] = transform.basis.z.x
		data[offset + 3] = transform.origin.x
		data[offset + 4] = transform.basis.x.y
		data[offset + 5] = transform.basis.y.y
		data[offset + 6] = transform.basis.z.y
		data[offset + 7] = transform.origin.y
		data[offset + 8] = transform.basis.x.z
		data[offset + 9] = transform.basis.y.z
		data[offset + 10] = transform.basis.z.z
		data[offset + 11] = transform.origin.z
		if batch.use_colors:
			var color: Color = colors[index] if index < colors.size() else Color.WHITE
			data[offset + 12] = color.r
			data[offset + 13] = color.g
			data[offset + 14] = color.b
			data[offset + 15] = color.a
		if calculate_bounds:
			var instance_bounds := transform * source_bounds
			bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	batch.buffer = data
	if calculate_bounds and not transforms.is_empty():
		batch.custom_aabb = bounds.grow(0.02)
