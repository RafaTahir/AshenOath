extends RefCounted

static func upload(batch: MultiMesh, transforms: Array, colors: Array = [], calculate_bounds: bool = false) -> void:
	if batch.transform_format != MultiMesh.TRANSFORM_3D or batch.instance_count != transforms.size():
		push_error("Static batch buffer must match its declared 3D instance count")
		return
	if batch.use_colors and not colors.is_empty() and colors.size() != transforms.size():
		push_error("Static batch colors must match its declared instance count")
		return
	if transforms.any(func(value: Variant): return value is Dictionary) and not batch.use_custom_data:
		_upload_prepared_parts(batch, transforms, colors, calculate_bounds)
		return
	var stride := 12 + (4 if batch.use_colors else 0) + (4 if batch.use_custom_data else 0)
	# Preserve custom data if a future caller uses it; these authored batches do not.
	var data := batch.buffer if batch.use_custom_data else PackedFloat32Array()
	data.resize(transforms.size() * stride)
	var bounds := AABB()
	var source_bounds := batch.mesh.get_aabb() if calculate_bounds else AABB()
	for index in transforms.size():
		var transform: Transform3D = transforms[index].transform if transforms[index] is Dictionary else transforms[index]
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

static func prepare_record(transform: Transform3D, color: Color = Color.WHITE) -> Dictionary:
	var data := PackedFloat32Array([
		transform.basis.x.x, transform.basis.y.x, transform.basis.z.x, transform.origin.x,
		transform.basis.x.y, transform.basis.y.y, transform.basis.z.y, transform.origin.y,
		transform.basis.x.z, transform.basis.y.z, transform.basis.z.z, transform.origin.z,
	])
	var tinted := data.duplicate()
	tinted.append_array(PackedFloat32Array([color.r, color.g, color.b, color.a]))
	return {"transform": transform, "color": color, "buffer": data, "color_buffer": tinted,
		"unit_bounds": transform * AABB(Vector3.ONE * -0.5, Vector3.ONE)}

static func _upload_prepared_parts(batch: MultiMesh, records: Array, colors: Array, calculate_bounds: bool) -> void:
	var data := PackedFloat32Array()
	var bounds := AABB()
	var source_bounds := batch.mesh.get_aabb()
	var unit_box := source_bounds == AABB(Vector3.ONE * -0.5, Vector3.ONE)
	for index in records.size():
		var value: Variant = records[index]
		var record: Dictionary = value if value is Dictionary else prepare_record(value, colors[index] if index < colors.size() else Color.WHITE)
		data.append_array(record.color_buffer if batch.use_colors else record.buffer)
		if calculate_bounds:
			var instance_bounds: AABB = record.unit_bounds if unit_box else record.transform * source_bounds
			bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	batch.buffer = data
	if calculate_bounds and not records.is_empty():
		batch.custom_aabb = bounds.grow(0.02)
