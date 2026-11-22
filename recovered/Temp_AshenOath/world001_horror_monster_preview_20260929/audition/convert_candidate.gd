extends SceneTree

func _initialize() -> void:
	var source := load("res://Idle.fbx") as PackedScene
	if source == null:
		push_error("Horror candidate source did not import")
		quit(1)
		return
	var actor := source.instantiate()
	var document := GLTFDocument.new()
	document.image_format = "JPEG"
	document.lossy_quality = 0.72
	var state := GLTFState.new()
	var append_result := document.append_from_scene(actor, state)
	if append_result != OK:
		push_error("GLB append failed: %d" % append_result)
		actor.free()
		quit(1)
		return
	var target := "D:/Temp/AshenOath/world001_horror_monster_preview_20260929/horror_idle_candidate.glb"
	var write_result := document.write_to_filesystem(state, target)
	actor.free()
	if write_result != OK:
		push_error("GLB write failed: %d" % write_result)
		quit(1)
		return
	print("CANDIDATE_GLB bytes=%d sha256=%s" % [FileAccess.get_file_as_bytes(target).size(), FileAccess.get_sha256(target)])
	quit(0)
