extends SceneTree

const DEADLINE_MS := 30000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.settings.set_quality_preset("balanced")
	game.call("_new_game")
	var deadline := Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		if game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)):
			break
		await process_frame
	if game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false)):
		push_error("Greyfen did not finish hydration")
		quit(1)
		return
	var totals := {"nodes": 0, "meshes": 0, "surfaces": 0, "shadows": 0, "multimeshes": 0, "instances": 0, "lights": 0, "particles": 0}
	var groups: Dictionary = {}
	var shadow_sizes := {"under_0_3m": 0, "under_0_6m": 0, "under_1m": 0, "over_1m": 0}
	var small_shadow_owners: Array[String] = []
	for node in game.zone_root.find_children("*", "", true, false):
		if not node is Node3D or not _effectively_visible(node as Node3D, game.zone_root):
			continue
		var owner: Node = node
		while owner.get_parent() != game.zone_root and owner.get_parent() != null:
			owner = owner.get_parent()
		var group_name := str(owner.name)
		if not groups.has(group_name):
			groups[group_name] = {"nodes": 0, "meshes": 0, "surfaces": 0, "shadows": 0, "multimeshes": 0, "instances": 0, "lights": 0, "particles": 0}
		var bucket: Dictionary = groups[group_name]
		bucket.nodes += 1
		totals.nodes += 1
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				bucket.meshes += 1
				totals.meshes += 1
				bucket.surfaces += mesh_node.mesh.get_surface_count()
				totals.surfaces += mesh_node.mesh.get_surface_count()
				if mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					bucket.shadows += 1
					totals.shadows += 1
					var local_size := mesh_node.mesh.get_aabb().size
					var scale_size := mesh_node.global_transform.basis.get_scale() * local_size
					var extent := maxf(scale_size.x, maxf(scale_size.y, scale_size.z))
					if extent < 0.3:
						shadow_sizes.under_0_3m += 1
					elif extent < 0.6:
						shadow_sizes.under_0_6m += 1
					elif extent < 1.0:
						shadow_sizes.under_1m += 1
					else:
						shadow_sizes.over_1m += 1
					if extent < 0.6:
						small_shadow_owners.append("%s %.2fm" % [str(node.get_path()), extent])
		elif node is MultiMeshInstance3D:
			var batch := node as MultiMeshInstance3D
			if batch.multimesh != null:
				bucket.multimeshes += 1
				totals.multimeshes += 1
				bucket.instances += batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0 else batch.multimesh.instance_count
				totals.instances += batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0 else batch.multimesh.instance_count
				if batch.multimesh.mesh != null:
					bucket.surfaces += batch.multimesh.mesh.get_surface_count()
					totals.surfaces += batch.multimesh.mesh.get_surface_count()
				if batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					bucket.shadows += 1
					totals.shadows += 1
		elif node is Light3D:
			bucket.lights += 1
			totals.lights += 1
		elif node is GPUParticles3D:
			bucket.particles += 1
			totals.particles += 1
	var sorted_names := groups.keys()
	sorted_names.sort_custom(func(a, b): return int(groups[a].surfaces) > int(groups[b].surfaces))
	print("GREYFEN_RENDER_TOTAL %s" % JSON.stringify(totals))
	print("GREYFEN_SHADOW_SIZES %s" % JSON.stringify(shadow_sizes))
	print("GREYFEN_SMALL_SHADOW_OWNERS %s" % JSON.stringify(small_shadow_owners))
	for group_name in sorted_names.slice(0, mini(25, sorted_names.size())):
		print("GREYFEN_RENDER_OWNER %s %s" % [group_name, JSON.stringify(groups[group_name])])
	if game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
	for _index in range(game.ZONE_RETIRE_FRAMES + 6):
		await process_frame
	if game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
	for _index in range(8):
		await process_frame
	root.remove_child(game)
	game.free()
	print("GREYFEN RENDER OWNERS: PASS")
	quit(0)

func _effectively_visible(node: Node3D, zone_root: Node3D) -> bool:
	var current: Node = node
	while current != null and current != zone_root:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true
