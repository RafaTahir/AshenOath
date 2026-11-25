extends SceneTree
## Pass the exported GLB and destination .scn as absolute paths after --.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		quit(1)
		return
	var model := document.generate_scene(state)
	var edge := model.find_child("EdgeHeel", true, false)
	var tip := model.find_child("EdgeTip", true, false)
	var packed := PackedScene.new()
	if edge == null or tip == null or packed.pack(model) != OK:
		push_error("Expected authored cutting edge and grip origin")
		quit(1)
		return
	var result := ResourceSaver.save(packed, args[1], ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_COMPRESS)
	model.free()
	quit(0 if result == OK else 1)
