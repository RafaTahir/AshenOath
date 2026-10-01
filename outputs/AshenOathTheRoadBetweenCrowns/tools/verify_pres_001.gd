extends SceneTree

const VisualDirector := preload("res://scripts/visual_director.gd")
const RiverSection := preload("res://scripts/zones/river_section.gd")
const OUTDOORS := ["greyfen", "wychwood", "cemetery", "deep_wood", "marsh_crossing", "hart_glade", "vargan_approach", "vargan_court", "assembly"]
var failures: Array[String] = []

func _initialize() -> void:
	var director := VisualDirector.new()
	root.add_child(director)
	await process_frame
	_check(director.cloud_layer.get_child_count() == 7, "Cached cloud pool changed")
	var unique_meshes: Dictionary = {}
	for formation in director.cloud_layer.get_children():
		_check(formation.get_child_count() == 1, "Cloud has overlapping card owners")
		var body := formation.get_child(0) as MeshInstance3D
		_check(body.mesh is ArrayMesh, "Cloud is still a flat primitive")
		unique_meshes[body.mesh.get_instance_id()] = true
		var bounds := body.mesh.get_aabb()
		_check(bounds.size.x > 12 and bounds.size.y > 2 and bounds.size.z > 5, "Cloud has no volume")
		var material := body.material_override as StandardMaterial3D
		_check(material != null and material.vertex_color_use_as_albedo, "Cloud underside shading is missing")
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and not material.no_depth_test, "Cloud overdraw/depth contract failed")
		var arrays := body.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		_check(vertices.size() < 1500 and indices.size() / 3 < 2800 and colors.size() == vertices.size(), "Cloud geometry exceeds its authored budget")
		for i in range(0, indices.size(), 3):
			var a := int(indices[i])
			var b := int(indices[i + 1])
			var c := int(indices[i + 2])
			var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			_check(cross.length_squared() > 0.00000001, "Cloud includes degenerate triangles")
			_check(cross.dot(normals[a] + normals[b] + normals[c]) <= 0.000001, "Cloud surface winding is inverted")
	_check(unique_meshes.size() == 3 and director.cloud_materials.size() == 1, "Cloud resources are not shared")
	for disc in [director.sun_disc, director.moon_disc]:
		_check(disc.material_override.billboard_keep_scale and not disc.material_override.no_depth_test, "Celestial billboard discards apparent size or depth")
	for zone in OUTDOORS:
		director.apply_zone(zone)
		_check(director.current_environment.fog_sky_affect <= 0.25, zone + ": fog obscures sky")
		for minute in [375.0, 720.0, 1155.0, 60.0]:
			director.force_time_update = true
			director.set_time(minute, "fixture")
			_check(not (director.sun_disc.visible and director.moon_disc.visible), zone + ": celestial bodies overlap")
			if minute == 720:
				_check(director.sun_disc.visible and not director.star_field.visible, zone + ": invalid day")
				_check(director.sun_disc.position.z < -180.0, zone + ": sun sits in front of cloud volume")
			if minute == 60:
				_check(director.moon_disc.visible and director.star_field.visible, zone + ": invalid night")
				_check(director.moon_disc.position.z < -180.0, zone + ": moon sits in front of cloud volume")
				var horizon: Color = director.authored_sky_material.sky_horizon_color
				_check(horizon.get_luminance() < 0.18, zone + ": night sky is washed into daylight")
	for quality in ["potato", "balanced", "quality"]:
		director.apply_settings({"quality_preset": quality, "reduced_motion": true})
		var expected := 2 if quality == "potato" else (4 if quality == "balanced" else 7)
		var visible := 0
		for formation in director.cloud_layer.get_children():
			visible += 1 if formation.visible else 0
		_check(visible == expected, quality + ": cloud density changed")
	for zone in ["record_hall", "undercroft"]:
		director.apply_zone("greyfen")
		director.set_time(720.0, "day")
		director.apply_zone(zone)
		_check(not director.cloud_layer.visible and not director.sun_disc.visible and not director.moon_disc.visible and not director.star_field.visible, zone + ": exterior geometry visible inside")
		_check(director.current_environment.fog_sky_affect == 0.0, zone + ": interior background fogging")
		var expected_basis: Basis = director.sun.global_basis
		var expected_color: Color = director.sun.light_color
		director.apply_zone("greyfen")
		director.set_time(60.0, "night")
		director.apply_zone(zone)
		_check(director.sun.global_basis.is_equal_approx(expected_basis) and director.sun.light_color.is_equal_approx(expected_color), zone + ": lighting direction depends on exterior history")
	var river := RiverSection.new()
	var water := river._water_channel_mesh(40.0, 4.0)
	var arrays := water.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	_check(tangents.size() == vertices.size() * 4, "Water tangent basis is absent")
	for i in range(0, tangents.size(), 4):
		var tangent := Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
		_check(tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001 and absf(tangent.y) < 0.001, "Water tangent basis is not finite/unit/plane-aligned")
	director.clear_runtime_caches()
	root.remove_child(director)
	director.free()
	water = null
	river = null
	await process_frame
	RenderingServer.force_sync()
	print("PRES-001 CONTRACT: %s (geometry/material/phase only; not visual or performance acceptance)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
