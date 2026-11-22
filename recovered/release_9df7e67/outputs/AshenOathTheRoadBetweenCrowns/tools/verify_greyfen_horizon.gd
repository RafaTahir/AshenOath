extends SceneTree

const GreyfenSection = preload("res://scripts/zones/greyfen_section.gd")
const Frontier = preload("res://scripts/greyfen_frontier.gd")
var failures: Array[String] = []

class HostFixture extends Node:
	var zone_root := Node3D.new()

func _initialize() -> void:
	var host := HostFixture.new()
	root.add_child(host)
	host.add_child(host.zone_root)
	var section := GreyfenSection.new()
	section._build_horizon_ridges(ZoneBuildContext.new(host, "greyfen"))
	_check(host.zone_root.find_child("GreyfenHorizonRidges", true, false) == null, "Obsolete perimeter wall ownership remains")
	var frontier := host.zone_root.find_child("GreyfenAuthoredFrontier", true, false)
	_check(frontier != null, "Authored adjoining landscape is missing")
	if frontier != null:
		_check(frontier.find_children("*", "CollisionObject3D", true, false).is_empty(), "Adjoining art changes physical traversal")
		var ground := frontier.find_child("VillageAdjoiningLandscape", true, false) as MeshInstance3D
		_check(ground != null and ground.mesh != null and ground.mesh.get_surface_count() == 2, "Adjoining landscape requires both ground and track")
		if ground != null and ground.mesh != null:
			for surface in ground.mesh.get_surface_count():
				var material := ground.get_active_material(surface) as StandardMaterial3D
				_check(material != null and material.albedo_texture != null, "Adjoining landscape has no authored surface texture")
				var arrays := ground.mesh.surface_get_arrays(surface)
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					_check(normal.y > 0.5, "Adjoining ground has a downward or wall-facing normal")
			for point in ground.mesh.get_faces():
				_check(point.is_finite() and (absf(point.z) >= 16.99 or absf(point.x) >= 20.99), "Adjoining landscape enters the physical village core")
			_check(ground.mesh.get_aabb().size.z > 130.0, "Adjoining ground does not close distant depth")
			_check(ground.mesh.get_faces().size() / 3 <= 3500, "Complete adjoining landscape exceeds its geometry budget")
			for x in [-21.0, -12.0, -5.0, 0.0, 5.0, 12.0, 21.0]:
				for z in [-17.0, 17.0]:
					_check(absf(Frontier.height_at(x, z)) < 0.001, "Adjoining surface does not meet the physical village floor")
			for z in [-17.0, -10.0, 0.0, 10.0, 17.0]:
				for x in [-21.0, 21.0]:
					_check(absf(Frontier.height_at(x, z)) < 0.001, "Village side surface leaves an exposed boundary gap")
	for count in [24, 40]:
		var positions := Frontier.tree_positions(count)
		_check(positions.size() == count, "Quality tier loses its forest population")
		for position in positions:
			_check(position.is_finite() and absf(position.y - Frontier.height_at(position.x, position.z)) < 0.001, "Adjoining tree is not grounded on its owner")
			_check(absf(position.z) > 18.7 or absf(position.x) > 21.4, "Adjoining tree obstructs a playable route")
	host.free()
	print("GREYFEN HORIZON GEOMETRY: %s (not visual acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
