extends SceneTree

const Landscape = preload("res://scripts/world_landscape_presentation.gd")
const River = preload("res://scripts/zones/river_section.gd")
const Materials = preload("res://scripts/world_material_library.gd")
const Core = preload("res://scenes/runtime/greyfen_gameplay_core.tscn")
var failures: Array[String] = []

class SettingsFixture extends Node:
	var settings := {"quality_preset": "balanced"}

class HostFixture extends Node:
	var zone_root: Node3D
	var settings: Node
	var world_materials: Node

func _initialize() -> void:
	var host := HostFixture.new()
	host.zone_root = Core.instantiate()
	host.settings = SettingsFixture.new()
	host.world_materials = Materials.new()
	root.add_child(host)
	host.add_child(host.zone_root)
	host.add_child(host.settings)
	host.add_child(host.world_materials)
	await process_frame
	var before := _colliders(host.zone_root)
	var source: ArrayMesh = Landscape.FAR_TERRAIN
	_check(source.get_surface_count() == 1 and source.surface_get_array_index_len(0) / 3 == 512, "Far terrain draw/triangle budget drift")
	var normals: PackedVector3Array = source.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in normals:
		_check(normal.y > 0.0, "Terrain has inverted or vertical normals")
	var material_before: StandardMaterial3D = host.world_materials.get_material("forest_ground", "balanced", Color(0.75, 0.82, 0.72), 0.0, false)
	var original_uv := material_before.uv1_scale
	for spec in [["wychwood", Vector2(42, 38), 1.3, -0.35], ["hart_glade", Vector2(22, 19), 1.4, -0.02]]:
		var context := ZoneBuildContext.new(host, spec[0])
		var terrain := Landscape.build(context, spec[1], spec[2], spec[3])
		_check(terrain.mesh == source, "Terrain creates a new per-zone mesh")
		_check(Landscape.build(context, spec[1], spec[2], spec[3]) == terrain, "Terrain build is not idempotent")
		var material := terrain.material_override as StandardMaterial3D
		_check(material != null and material.albedo_texture != null and material.vertex_color_use_as_albedo, "Terrain material/texture missing")
		_check(material.uv1_scale.is_equal_approx(original_uv * Vector3(spec[1].x, spec[1].y, 1)), "Terrain texture is stretched")
		for point in source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var fitted: Vector3 = terrain.transform * point
			_check(absf(fitted.x) >= spec[1].x - 0.0001 or absf(fitted.z) >= spec[1].y - 0.0001, "Far terrain invades playable/support interior")
			if is_zero_approx(point.y):
				_check(is_equal_approx(fitted.y, float(spec[3])), "Terrain seam is not seated")
		terrain.free()
	_check(material_before.uv1_scale == original_uv and not material_before.vertex_color_use_as_albedo, "Terrain mutates cached world material")
	var river := River.new()
	var foundation_material := StandardMaterial3D.new()
	foundation_material.vertex_color_use_as_albedo = true
	for index in range(4):
		river._make_bridge_abutment(host.zone_root, "Foundation_%d" % index, Vector3(index * 2, -0.25, 4.5), foundation_material)
		var pier := host.zone_root.get_node("Foundation_%d" % index) as MeshInstance3D
		_check(pier.mesh == River.StonePier and pier.mesh.get_surface_count() == 1, "Foundation is not shared one-surface sourced masonry")
		_check(pier.mesh.surface_get_array_index_len(0) / 3 <= 2800, "Foundation exceeds fitted stone geometry budget")
		var bounds: AABB = pier.transform * pier.mesh.get_aabb()
		_check(absf(bounds.position.y + 1.62) < 0.001 and absf(bounds.end.y - 0.096) < 0.002, "Foundation floats or penetrates deck")
	_check(_colliders(host.zone_root) == before, "Presentation changes collider identity/transform")
	host.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("LANDSCAPE FOUNDATION CONTRACT: %s (geometry/material/collision only; NOT visual, route or FPS acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
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
