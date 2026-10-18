extends RefCounted

## Broad phase only. The original exact rectangle/surface checks stay authoritative.
const CELL_SIZE := 4.0
var cells: Dictionary = {}
var entries: Dictionary = {}
var oversized: Dictionary = {}

func add(id: String, center: Vector3, half_size: Vector2, entry: Dictionary) -> void:
	entries[id] = entry
	var low := _cell(center.x - half_size.x, center.z - half_size.y)
	var high := _cell(center.x + half_size.x, center.z + half_size.y)
	if (high.x - low.x + 1) * (high.y - low.y + 1) > 4096:
		oversized[id] = true
		return
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var cell := Vector2i(x, z)
			if not cells.has(cell):
				cells[cell] = {}
			cells[cell][id] = true

func candidates(position: Vector3, margin: float) -> Array:
	var padding := maxf(margin, 0.0)
	var low := _cell(position.x - padding, position.z - padding)
	var high := _cell(position.x + padding, position.z + padding)
	var ids: Dictionary = oversized.duplicate()
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			ids.merge(cells.get(Vector2i(x, z), {}))
	var result: Array = []
	for id in ids:
		result.append(entries[id])
	return result

func contains(position: Vector3, margin: float) -> bool:
	for entry: Dictionary in candidates(position, margin):
		var center: Vector3 = entry.center
		var size: Vector2 = entry.half_size
		if absf(position.x - center.x) <= size.x + margin and absf(position.z - center.z) <= size.y + margin:
			return true
	return false

func clear() -> void:
	cells.clear()
	entries.clear()
	oversized.clear()

func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL_SIZE), floori(z / CELL_SIZE))
