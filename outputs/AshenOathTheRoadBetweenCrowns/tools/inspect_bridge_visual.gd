extends SceneTree

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	for _index in range(16):
		await process_frame
	var camera: Camera3D = game.camera_rig.camera
	game.camera_rig.set_process(false)
	camera.look_at_from_position(Vector3(0, 2.2, 10.2), Vector3(0, 0.35, 4.5), Vector3.UP)
	for z in [3.0, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0]:
		print("BRIDGE PROJECTION z=%.2f deck=%s low=%s" % [z, camera.unproject_position(Vector3(0, 0.16, z)), camera.unproject_position(Vector3(0, 0.03, z))])
	var river: Node = game.zone_root.find_child("LivingRiverSection", true, false)
	for child in river.get_children():
		if child is MultiMeshInstance3D and child.name.contains("bridge_timber"):
			var batch := child as MultiMeshInstance3D
			print("BRIDGE BATCH instances=%d material=%s" % [batch.multimesh.instance_count, batch.material_override])
			for index in range(batch.multimesh.instance_count):
				var instance_transform := batch.multimesh.get_instance_transform(index)
				if absf(instance_transform.origin.x) < 0.4:
					print("BRIDGE CENTER instance=%d z=%.3f y=%.3f size=%s color=%s" % [index, instance_transform.origin.z, instance_transform.origin.y, instance_transform.basis.get_scale(), batch.multimesh.get_instance_color(index)])
		elif child is MeshInstance3D and child.name.begins_with("BridgeApproach"):
			print("BRIDGE APPROACH mesh=%s material=%s" % [child.name, child.material_override])
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		for _index in range(int(game.ZONE_RETIRE_FRAMES) + 4):
			await process_frame
	game.queue_free()
	for _index in range(8):
		await process_frame
	quit()
