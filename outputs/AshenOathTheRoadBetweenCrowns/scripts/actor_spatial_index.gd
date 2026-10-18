extends RefCounted

## Owner-local XZ grid. A query returns registrations in their original order.
var cell_size := 2.0
var _cells: Dictionary = {}
var _entries: Dictionary = {}
var _sequence := 0

func update(node: Node3D, payload: Variant = null) -> void:
	if not is_instance_valid(node):
		return
	var id := node.get_instance_id()
	var cell := _cell(node.global_position)
	if _entries.has(id):
		var record: Dictionary = _entries[id]
		if record.cell != cell:
			_remove_cell(record.cell, id)
			record.cell = cell
			_add_cell(cell, id)
		if payload != null:
			record.payload = payload
		return
	_entries[id] = {"node": weakref(node), "payload": payload, "cell": cell, "order": _sequence}
	_sequence += 1
	_add_cell(cell, id)

func remove(id: int) -> void:
	if _entries.has(id):
		_remove_cell(_entries[id].cell, id)
		_entries.erase(id)

func nearby(position: Vector3, radius: float) -> Array:
	var found: Array[Dictionary] = []
	var low := _cell(position - Vector3(radius, 0.0, radius))
	var high := _cell(position + Vector3(radius, 0.0, radius))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for id in _cells.get(Vector2i(x, z), {}).keys():
				var record: Dictionary = _entries[id]
				var node := record.node.get_ref() as Node3D
				if node == null:
					remove(id)
					continue
				var offset := node.global_position - position
				offset.y = 0.0
				if offset.length_squared() <= radius * radius:
					found.append(record)
	found.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.order) < int(b.order))
	return found.map(func(record: Dictionary): return record.payload if record.payload != null else record.node.get_ref())

func clear() -> void:
	_cells.clear()
	_entries.clear()
	_sequence = 0

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))

func _add_cell(cell: Vector2i, id: int) -> void:
	if not _cells.has(cell):
		_cells[cell] = {}
	_cells[cell][id] = true

func _remove_cell(cell: Vector2i, id: int) -> void:
	if not _cells.has(cell):
		return
	_cells[cell].erase(id)
	if _cells[cell].is_empty():
		_cells.erase(cell)
