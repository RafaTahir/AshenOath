extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not ProjectSettings.load_resource_pack(args[0], false):
		push_error("Cannot mount opening pack")
		quit(1)
		return
	for variant in range(4):
		var suffix := "" if variant == 0 else "_%d" % variant
		var path := "res://assets_external/environment/village/GreyfenHouse_Authored%s.res" % suffix
		var mesh := ResourceLoader.load(path) as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 6:
			push_error("Packed Greyfen house missing: " + path)
			quit(1)
			return
		for surface in mesh.get_surface_count():
			if mesh.surface_get_material(surface) == null:
				push_error("Packed Greyfen house has null material: " + path)
				quit(1)
				return
		print("PACKED HOUSE PASS variant=%d bounds=%s" % [variant, mesh.get_aabb()])
	var forge_path := "res://assets_external/environment/village/GreyfenForge_Authored.res"
	var forge := ResourceLoader.load(forge_path) as ArrayMesh
	if forge == null or forge.get_surface_count() != 6:
		push_error("Packed Greyfen forge missing: " + forge_path)
		quit(1)
		return
	for surface in forge.get_surface_count():
		if forge.surface_get_material(surface) == null:
			push_error("Packed Greyfen forge has null material surface %d" % surface)
			quit(1)
			return
	print("PACKED FORGE PASS bounds=%s" % forge.get_aabb())
	var shrine_path := "res://assets_external/environment/village/GreyfenShrine_Authored.res"
	var shrine := ResourceLoader.load(shrine_path) as ArrayMesh
	if shrine == null or shrine.get_surface_count() != 6:
		push_error("Packed Greyfen shrine missing: " + shrine_path)
		quit(1)
		return
	for surface in shrine.get_surface_count():
		if shrine.surface_get_material(surface) == null:
			push_error("Packed Greyfen shrine has null material surface %d" % surface)
			quit(1)
			return
	print("PACKED SHRINE PASS bounds=%s" % shrine.get_aabb())
	quit(0)
