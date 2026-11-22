extends SceneTree

func _init() -> void:
	var entries: Array = []
	_walk("res://", entries)
	entries.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for entry in entries:
		print("%d\t%s" % [entry[0], entry[1]])
	quit()

func _walk(path: String, entries: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if dir.current_is_dir():
				_walk(child, entries)
			else:
				var file := FileAccess.open(child, FileAccess.READ)
				if file != null:
					entries.append([file.get_length(), child])
		name = dir.get_next()
	dir.list_dir_end()
