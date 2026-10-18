extends SceneTree

const Factory = preload("res://tools/prepared_zone_geometry_factory.gd")
const ROOT := "res://assets_external/environment/prepared/"
var failed := false

func _initialize() -> void:
	call_deferred("_compile")

func _compile() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var packed := load("res://scenes/runtime/greyfen_gameplay_core.tscn") as PackedScene
	var source := packed.instantiate() as Node3D
	root.add_child(source)
	var specs: Array = []
	for id in ["GroundNorthWest", "GroundNorthEast", "GroundSouthWest", "GroundSouthEast", "GroundCenterNorthVisual", "GroundCenterSouthVisual"]:
		var node := source.find_child(id, true, false)
		var surface := node as MeshInstance3D if node is MeshInstance3D else node.get_node("Surface") as MeshInstance3D
		specs.append({"name": id, "origin": source.to_local(surface.global_position), "size": surface.scale})
	_save("greyfen_ground", Factory.greyfen_ground(specs))
	for id in ["PavedRoadMain", "PavedRoadVillage", "PavedRoadCastle"]:
		var road := source.find_child(id, true, false) as MeshInstance3D
		_save("greyfen_" + id, Factory._make_greyfen_road_surface(road.scale, road.position))
	source.free()
	_save("AshMillYard", Factory.mill_path(Vector3(-5.2, 0.048, -5.5), 8.0, 3.0))
	_save("AshMillCartTrack", Factory.mill_path(Vector3(0, 0.039, 0), 3.35, 28.0))
	_save("mill_ridge", Factory.mill_ridge())
	_save("mill_ramp", Factory.ramp(0.48, 2.6))
	_save("farm_ramp", Factory.ramp(0.40, 1.6))
	var vault: Dictionary = Factory.record_vault()
	for id in vault:
		_save(id, vault[id])
	_save("record_ribs", Factory.record_ribs())
	var undercroft := load("res://assets_external/environment/village/UndercroftVault_Authored.res") as ArrayMesh
	var roof := ArrayMesh.new()
	roof.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, undercroft.surface_get_arrays(0))
	_save("undercroft_roof_collision", roof.create_trimesh_shape())
	quit(1 if failed else 0)

func _save(id: String, resource: Resource) -> void:
	var error := ResourceSaver.save(resource, ROOT + id + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		failed = true
		push_error("Geometry compilation failed: %s (%s)" % [id, error_string(error)])
