extends SceneTree

const Director = preload("res://scripts/visual_director.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	root.add_child(director)
	var zone := Node3D.new()
	root.add_child(zone)
	director.apply_zone("greyfen", zone)
	director.set_time(720.0, "day", 0)
	var light := OmniLight3D.new()
	light.name = "LateLantern"
	zone.add_child(light)
	var glow := MeshInstance3D.new()
	glow.name = "LateLitWindow"
	glow.mesh = BoxMesh.new()
	glow.material_override = StandardMaterial3D.new()
	zone.add_child(glow)
	var batch := MultiMeshInstance3D.new()
	var glass := StandardMaterial3D.new()
	glass.emission_enabled = true
	batch.set_meta("night_window_material", glass)
	batch.set_meta("night_window_color", Color(0.95, 0.52, 0.18))
	zone.add_child(batch)
	var pool := MultiMeshInstance3D.new()
	pool.set_meta("night_only_geometry", true)
	zone.add_child(pool)
	var applied_time := director.last_applied_time_minutes
	director.refresh_zone_lighting(zone)
	var passed := not light.visible and not glow.visible and not pool.visible
	passed = passed and director.sun_disc.visible and not director.moon_disc.visible and not director.star_field.visible
	passed = passed and not director.sky_canvas.visible and not director.sky_backdrop.visible
	var late := OmniLight3D.new()
	late.name = "IncrementalLantern"
	zone.add_child(late)
	director.refresh_zone_lighting(zone, [late])
	director.refresh_zone_lighting(zone, [late])
	passed = passed and not late.visible and director.night_node_cache[zone.get_instance_id()].lights.size() == 2
	passed = passed and director.last_applied_time_minutes == applied_time and not director.force_time_update
	passed = passed and glass.emission_energy_multiplier == 0.0 and batch.visible
	director.set_time(0.0, "night", 0)
	passed = passed and not director.sun_disc.visible and director.moon_disc.visible and director.star_field.visible
	passed = passed and director.moon_disc.material_override.albedo_color.a > 0.8
	passed = passed and light.visible and glow.visible and pool.visible and late.visible
	passed = passed and glass.emission_energy_multiplier > 0.6 and batch.visible
	glow.free()
	pool.free()
	director.refresh_zone_lighting(zone)
	passed = passed and director.night_node_cache[zone.get_instance_id()].meshes.is_empty()
	var replacement := Node3D.new()
	root.add_child(replacement)
	director.apply_zone("record_hall", replacement)
	passed = passed and not director.sun_rays.visible and not director.moon_disc.visible and not director.star_field.visible
	director.refresh_zone_lighting(zone)
	passed = passed and director.current_zone_root == replacement
	director.clear_runtime_caches()
	zone.queue_free()
	replacement.queue_free()
	director.queue_free()
	for frame in range(4):
		await process_frame
	if not passed:
		push_error("Deferred lighting state mismatch")
	print("DEFERRED NIGHT LIGHTING: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
