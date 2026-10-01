extends SceneTree

const GreyfenSection = preload("res://scripts/zones/greyfen_section.gd")
const AssetHelper = preload("res://scripts/asset_spawn_helper.gd")
const RiverSection = preload("res://scripts/zones/river_section.gd")
var failures: Array[String] = []

class SettingsFixture extends Node:
	var settings := {"quality_preset": "balanced"}

class HostFixture extends Node:
	var zone_root := Node3D.new()
	var settings := SettingsFixture.new()
	var asset_helper := AssetHelper.new()

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Greyfen framing requires real renderer-backed MultiMesh transforms")
		quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	var host := HostFixture.new()
	root.add_child(host)
	host.add_child(host.zone_root)
	host.add_child(host.settings)
	host.add_child(host.asset_helper)
	var section := GreyfenSection.new()
	var counts: Array[int] = []
	for quality in ["balanced", "potato"]:
		host.settings.settings.quality_preset = quality
		section._build_horizon_forest(ZoneBuildContext.new(host, "greyfen"))
		await process_frame
		await RenderingServer.frame_post_draw
		var layer := host.zone_root.get_node_or_null("GreyfenHorizonForest") as Node3D
		_check(layer != null, "Actual horizon forest was not built")
		if layer == null:
			continue
		var batch := layer.get_node("GreyfenDistantTreeBatch") as MultiMeshInstance3D
		var instances := batch.multimesh
		counts.append(instances.instance_count)
		_check(instances.mesh.get_surface_count() == 2, "Forest bark/leaf surface contract changed")
		_check(batch.material_override == null, "Forest replaces approved source materials")
		_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Distant forest enables extra shadow passes")
		_check(layer.find_children("*", "CollisionObject3D", true, false).is_empty(), "Forest changes collision or recovery")
		var triangles := 0
		var minimum_height := INF
		var maximum_height := 0.0
		var intrusion_count := 0
		var first_intrusion := Vector3.ZERO
		for surface in instances.mesh.get_surface_count():
			_check(instances.mesh.surface_get_material(surface) != null, "Forest has a null material")
			triangles += instances.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
		for index in instances.instance_count:
			var transform := instances.get_instance_transform(index)
			var bounds: AABB = transform * instances.mesh.get_aabb()
			minimum_height = minf(minimum_height, bounds.size.y)
			maximum_height = maxf(maximum_height, bounds.size.y)
			_check(transform.origin.is_finite(), "Forest transform is invalid")
			_check(absf(bounds.position.y) < 0.001, "Forest feet are not grounded")
			_check(bounds.size.y >= 8.79 and bounds.size.y <= 11.29, "Forest normalized height drift")
			for surface in instances.mesh.get_surface_count():
				var vertices: PackedVector3Array = instances.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var point := transform * vertex
					if point.y < 2.5:
						if absf(point.x) <= 21.4 and absf(point.z) <= 18.7:
							intrusion_count += 1
							first_intrusion = point
						_check(absf(point.x) > 21.4 or absf(point.z) > 18.7, "Horizon trunk enters playable bounds")
					_check(not (point.z < -17.0 and absf(point.x) < 2.1), "Forest obscures the north-road sightline")
		section._build_horizon_forest(ZoneBuildContext.new(host, "greyfen"))
		_check(host.zone_root.get_child_count() == 1, "Horizon forest is not idempotent")
		print("FRAMING %s: %d instances, %d triangles, two cached surfaces" % [quality, instances.instance_count, triangles * instances.instance_count])
		print("FRAMING bounds: heights %.6f..%.6f, intrusions %d, example %s, source %s" % [minimum_height, maximum_height, intrusion_count, first_intrusion, instances.mesh.get_aabb()])
		layer.free()
	_check(counts.size() == 2 and counts[0] > counts[1] and counts[0] <= 40, "Quality density does not reduce the forest budget")
	var river := Node3D.new()
	host.zone_root.add_child(river)
	var river_builder := RiverSection.new()
	river_builder.hydrate_visuals(river, 4.5, 42.0, 3.4)
	var timber := river_builder.bridge_timber_material
	_check(timber.uv1_triplanar and timber.uv1_world_triplanar, "Bridge timber does not share continuous world projection")
	_check(timber.uv1_scale.is_equal_approx(Vector3.ONE * 0.55), "Bridge timber density changed")
	_check(timber.albedo_texture.resource_path.ends_with("/timber_albedo.jpg"), "Bridge timber source changed")
	_check(river.find_children("*", "CollisionObject3D", true, false).is_empty(), "River visual hydration alters traversal")
	host.asset_helper.clear_runtime_caches()
	host.queue_free()
	river_builder = null
	section = null
	for frame in 16:
		await process_frame
	RenderingServer.force_sync()
	print("GREYFEN FRAMING: %s (geometry/material contract, not visual or performance acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
		push_error(message)
