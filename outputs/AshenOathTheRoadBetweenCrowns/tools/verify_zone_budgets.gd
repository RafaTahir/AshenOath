extends SceneTree

var failures := 0
const ZONES := ["greyfen", "wychwood", "vargan_approach", "vargan_court", "record_hall", "hart_glade"]

func _initialize() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_new_game")
	for zone_id in ZONES:
		game.call("_load_zone", zone_id, Vector3(0, 1, 8))
		await _frames(3)
		_verify_zone(game, zone_id)
	print("ZONE BUDGETS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _verify_zone(game, zone_id: String) -> void:
	var nodes: int = _walk(game.zone_root).size()
	var meshes: int = game.zone_root.find_children("*", "MeshInstance3D", true, false).size()
	var skeletons: int = game.zone_root.find_children("*", "Skeleton3D", true, false).size()
	var lights: int = game.zone_root.find_children("*", "Light3D", true, false).size()
	print("ZONE_BUDGET %s nodes=%d meshes=%d skeletons=%d lights=%d" % [zone_id, nodes, meshes, skeletons, lights])
	check(nodes <= 1350, "%s exceeds 1350 active nodes" % zone_id)
	check(meshes <= 420, "%s exceeds 420 MeshInstance nodes" % zone_id)
	check(skeletons <= 10, "%s exceeds 10 active skeletons" % zone_id)
	check(lights <= 8, "%s exceeds 8 local lights" % zone_id)
	for mesh in game.zone_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.material_override
			if material == null: material = mesh.get_surface_override_material(surface)
			if material == null: material = mesh.mesh.surface_get_material(surface)
			check(material != null, "%s has a null material surface on %s" % [zone_id, mesh.name])

func _walk(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children(): result.append_array(_walk(child))
	return result

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
