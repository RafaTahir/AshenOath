extends RefCounted

static func refresh(path: String, record: Dictionary) -> void:
	if int(record.status) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var values: Array = []
		record.status = ResourceLoader.load_threaded_get_status(path, values)
		record.progress = float(values[0]) if not values.is_empty() else 0.0
		if int(record.status) in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED]:
			# The engine retains a request token even when loading failed. Consume
			# that result once before a cancelled/failed claim can be discarded.
			var loaded: bool = int(record.status) == ResourceLoader.THREAD_LOAD_LOADED
			record.resource = ResourceLoader.load_threaded_get(path)
			if loaded:
				record.progress = 1.0
			if not loaded or record.resource == null:
				record.status = ResourceLoader.THREAD_LOAD_FAILED
