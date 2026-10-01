extends SceneTree

func _initialize() -> void:
	var enemy = load("res://scripts/enemy_ai.gd").new()
	root.add_child(enemy)
	enemy.setup("rootbound_colossus", {"boss": true, "health": 340}, null)
	await process_frame
	var socket := enemy.find_child("RootboundHeartSocket", true, false) as BoneAttachment3D
	var heart := enemy.find_child("RootboundHeart", true, false) as MeshInstance3D
	var failed := socket == null or heart == null
	for forbidden in ["RootboundBarkHarness", "RootboundShoulderMantle", "RootboundRootArmLeft", "RootboundRootArmRight", "RootboundRootFootLeft", "RootboundRootFootRight", "RootboundCrownBranch", "RootboundBarkPlate"]:
		failed = failed or enemy.find_child(forbidden, true, false) != null
	if not failed:
		failed = failed or not socket.is_ancestor_of(heart) or socket.bone_name != "Chest"
		var skeleton: Skeleton3D = enemy.animation_driver.get_skeleton()
		var jaw := skeleton.find_bone("Jaw1")
		var chest := skeleton.find_bone("Chest")
		failed = failed or jaw < 0 or chest < 0
		if jaw >= 0 and chest >= 0:
			var facing := skeleton.global_basis * (skeleton.get_bone_global_pose(jaw).origin - skeleton.get_bone_global_pose(chest).origin)
			failed = failed or facing.z >= -0.05
		var frame: Transform3D = enemy.boss_visual_root.transform
		failed = not _heart_matches_chest_surface(enemy, skeleton, heart) or failed
		var prior_energy := -1.0
		for phase in [1, 2, 3]:
			enemy.apply_boss_phase_visual(phase)
			var material := heart.material_override as StandardMaterial3D
			failed = failed or material == null
			if material != null:
				failed = failed or material.emission_energy_multiplier <= prior_energy
				prior_energy = material.emission_energy_multiplier
		enemy.animation_driver.set_external_tick(true)
		enemy.animation_driver.trigger_action("attack", 1.0, 0.0, true)
		enemy.animation_driver.advance_external(0.3)
		enemy.animation_driver.get_skeleton().force_update_all_bone_transforms()
		enemy._animate_boss_identity(0.3)
		await process_frame
		failed = failed or not enemy.boss_visual_root.transform.is_equal_approx(frame)
		var bounds: AABB = heart.global_transform * heart.get_aabb()
		failed = failed or bounds.size.length() < 0.2 or bounds.size.length() > 0.8
	if enemy.asset_helper != null:
		enemy.asset_helper.clear_runtime_caches()
	enemy.queue_free()
	for frame in range(8):
		await process_frame
	print("ROOTBOUND IDENTITY: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _heart_matches_chest_surface(enemy: Node3D, skeleton: Skeleton3D, heart: MeshInstance3D) -> bool:
	var center := enemy.to_local(heart.global_position)
	var front := INF
	var samples := 0
	# Evaluate the skinned mesh, not its rest AABB or the deeply recessed bone pivot.
	for mesh in enemy.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex_index in range(vertices.size()):
				var skinned := Vector3.ZERO
				for influence in range(4):
					var slot := vertex_index * 4 + influence
					if weights[slot] == 0:
						continue
					var bind := bones[slot]
					var bone_index := skeleton.find_bone(mesh.skin.get_bind_name(bind))
					if bone_index < 0:
						bone_index = mesh.skin.get_bind_bone(bind)
					skinned += (skeleton.get_bone_global_pose(bone_index) * mesh.skin.get_bind_pose(bind) * vertices[vertex_index]) * weights[slot]
				var point := enemy.to_local(skeleton.to_global(skinned))
				if absf(point.x - center.x) < 0.25 and absf(point.y - center.y) < 0.22:
					front = minf(front, point.z)
					samples += 1
	var valid := samples > 0 and center.z - front >= -0.12 and center.z - front <= 0.04
	if not valid:
		push_error("Rootbound heart misses skinned chest surface: center=%s front=%s samples=%s" % [center, front, samples])
	return valid
