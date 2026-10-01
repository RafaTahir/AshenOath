extends SceneTree

const Game = preload("res://scripts/game.gd")
const River = preload("res://scripts/zones/river_section.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Core = preload("res://scenes/runtime/greyfen_gameplay_core.tscn")
var failures: Array[String] = []

class SettingsFixture extends Node:
	var settings := {"quality_preset": "balanced"}

func _initialize() -> void:
	var game := Game.new()
	game.zone_root = Core.instantiate()
	game.settings = SettingsFixture.new()
	game.world_materials = Materials.new()
	root.add_child(game.zone_root)
	root.add_child(game.settings)
	root.add_child(game.world_materials)
	var river := River.new()
	var section: Dictionary = river.build(ZoneBuildContext.new(game, "greyfen"), 4.5, 42.0, 3.4, true)
	var river_root: Node3D = section.root
	await process_frame
	var before := _colliders(game.zone_root)
	river.hydrate_visuals(river_root, 4.5, 42.0, 3.4)
	game._finish_greyfen_ground_surfaces()
	_check(_colliders(game.zone_root) == before, "Visual shore changed collision resources or transforms")
	for index in range(4):
		var pier := river_root.get_node("BridgeStoneFoundation_%d" % index) as MeshInstance3D
		_check(absf(pier.position.z - 4.5) < 1.7 and is_equal_approx(pier.position.y, -1.62), "Pier is buried under a bank instead of supporting the river span: %s" % pier.position)
	_check(river_root.find_child("NorthBankSlope", true, false) == null and river_root.find_child("SouthBankSlope", true, false) == null, "Greyfen still has competing bank owners")
	var merged := game.zone_root.get_node_or_null("GreyfenGroundMerged") as MeshInstance3D
	_check(merged != null and merged.mesh is ArrayMesh, "Authored ground is unavailable")
	if merged != null:
		var faces := merged.mesh.get_faces()
		var flat_overlap := 0
		var submerged_vertices := 0
		for i in range(0, faces.size(), 3):
			var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			if absf(center.x) > Game.BridgeSurfaceContract.HALF_WIDTH and absf(center.y) < 0.001 and absf(center.z - 4.5) < 2.019:
				flat_overlap += 1
		for point in faces:
			if point.y < -0.29:
				submerged_vertices += 1
		_check(flat_overlap == 0, "Flat soil still covers the bank (%d triangles)" % flat_overlap)
		_check(submerged_vertices >= 144, "Bank does not overlap the lowest wave")
	for side in ["North", "South"]:
		var wet := river_root.get_node_or_null("RiverBankWetness_" + side) as MeshInstance3D
		_check(wet != null and wet.mesh is ArrayMesh and wet.position == Vector3.ZERO, "Wetness is a relocated box rather than a supported contour")
		if wet != null:
			for point in wet.mesh.get_faces():
				_check(absf(point.x) > River.BRIDGE_WIDTH * 0.5 + 0.19, "Wetness enters the bridge route")
	var current_audio := river_root.get_node("RiverCurrentAudio") as AudioStreamPlayer3D
	current_audio.stop()
	current_audio.stream = null
	await create_timer(0.12).timeout
	game.zone_root.free()
	game.settings.free()
	game.world_materials.free()
	game.zone_root = null
	game.settings = null
	game.world_materials = null
	game.zone_residency.free()
	game.zone_residency = null
	game.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("GREYFEN SHORE OWNERSHIP: %s (geometry/collision contract; NOT visual or player-route acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _colliders(node: Node) -> Dictionary:
	var result: Dictionary = {}
	if node is CollisionShape3D:
		result[str(node.get_path())] = [node.shape.get_instance_id(), node.global_transform]
	for child in node.get_children():
		result.merge(_colliders(child))
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
