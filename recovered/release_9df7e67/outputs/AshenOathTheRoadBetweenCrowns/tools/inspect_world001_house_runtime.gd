extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	for _index in 10:
		await process_frame
	for node in game.zone_root.find_children("*", "Node3D", true, false):
		if not node.is_in_group("greyfen_house"):
			continue
		var visual := node.find_child("AuthoredHouse", true, false) as MeshInstance3D
		if visual == null:
			print("HOUSE_RUNTIME missing visual " + node.name)
			continue
		var parts: Array[String] = []
		for index in visual.mesh.get_surface_count():
			var material := visual.get_active_material(index) as StandardMaterial3D
			parts.append("%s=%s tint=%s emission=%s energy=%.2f" % [visual.mesh.surface_get_name(index), str(material != null), str(material.albedo_color) if material != null else "null", str(material.emission_enabled) if material != null else "null", material.emission_energy_multiplier if material != null else 0.0])
		print("HOUSE_RUNTIME %s at %s visual=%s visible=%s bounds=%s surfaces=%s" % [node.name, node.global_position, visual.global_position, visual.visible, visual.mesh.get_aabb(), "; ".join(parts)])
	game.queue_free()
	await process_frame
	quit(0)
