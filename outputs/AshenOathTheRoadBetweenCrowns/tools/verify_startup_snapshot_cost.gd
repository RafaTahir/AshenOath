extends SceneTree

var graphical := false
var last_draw := 0
var worst_draw_gap := 0
var draw_count := 0
var draw_started := 0
var worst_render := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	graphical = DisplayServer.get_name().to_lower() != "headless"
	if graphical:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		last_draw = Time.get_ticks_usec()
		RenderingServer.frame_post_draw.connect(_record_draw)
		RenderingServer.frame_pre_draw.connect(_begin_draw)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Mirror the Web shell contract natively: the HTML layer covers a hidden
	# in-engine menu while the exact gameplay frame compiles underneath it.
	game.hud.show_main_menu()
	game.hud.set_boot_shell_cover_active(true)
	var shell_cover_hidden: bool = not bool(game.hud.menu_layer.visible)
	game._on_launch_accepted()
	var prewarm_started := Time.get_ticks_msec()
	var deadline := Time.get_ticks_msec() + 30000
	while not game.route_zone_cache.has("greyfen") and Time.get_ticks_msec() < deadline:
		await process_frame
	var ok: bool = game.route_zone_cache.has("greyfen")
	ok = ok and shell_cover_hidden and game.hud.menu_layer.visible
	print("STARTUP SHELL COVER: %s prewarm_ms=%d" % [
		"PASS" if shell_cover_hidden and game.hud.menu_layer.visible else "FAIL",
		Time.get_ticks_msec() - prewarm_started,
	])
	var prewarm_root: Node3D = null
	if ok:
		prewarm_root = game.route_zone_cache.get("greyfen") as Node3D
		ok = bool(prewarm_root.get_meta("opening_visual_profile_prewarmed", false))
		print("STARTUP VISUAL PROFILE PREWARM: %s" % ["PASS" if ok else "FAIL"])
	if ok:
		var boot_anwen := prewarm_root.find_child("sister_anwen", true, false) as Area3D
		print("STARTUP BOOT ANWEN: meta=%d visible=%d total=%d collision=%s area_visible=%s" % [
			int(boot_anwen.get_meta("opening_boot_visual_count", 0)) if boot_anwen != null else -1,
			_visible_renderable_count(boot_anwen) if boot_anwen != null else -1,
			_renderable_count(boot_anwen) if boot_anwen != null else -1,
			_has_enabled_collision(boot_anwen) if boot_anwen != null else false,
			boot_anwen.visible if boot_anwen != null else false,
		])
		ok = boot_anwen != null and boot_anwen.visible and _has_enabled_collision(boot_anwen)
		ok = ok and int(boot_anwen.get_meta("opening_boot_visual_count", 0)) > 0
		ok = ok and _visible_renderable_count(boot_anwen) >= int(boot_anwen.get_meta("opening_boot_visual_count", 0))
		var deferred_gate_count := 0
		for child in prewarm_root.get_children():
			if child is Area3D and bool(child.get_meta("opening_boot_gate", false)):
				deferred_gate_count += 1
				print("STARTUP BOOT GATE: name=%s meta=%d visible=%d total=%d collision=%s area_visible=%s" % [
					child.name, int(child.get_meta("opening_boot_visual_count", 0)),
					_visible_renderable_count(child), _renderable_count(child),
					_has_enabled_collision(child), (child as Area3D).visible,
				])
				ok = ok and (child as Area3D).visible and _has_enabled_collision(child)
				# Boot gates are removed by the gameplay stage rather than revealed.
				# Their legacy marker meshes are already hidden by _make_zone_gate,
				# so a zero deferral count is valid when every renderer is invisible.
				ok = ok and _renderable_count(child) > 0
				ok = ok and _visible_renderable_count(child) == 0
		ok = ok and deferred_gate_count == 3
		print("STARTUP BOOT VISUAL READINESS: %s anwen=%s gates=%d" % [
			"PASS" if ok else "FAIL", boot_anwen != null, deferred_gate_count,
		])
	if ok and graphical:
		ok = bool(game.route_zone_cache["greyfen"].get_meta("opening_first_frame_rendered", false))
		ok = ok and bool(game.route_zone_cache["greyfen"].get_meta("opening_unpaused_frame_prewarmed", false))
		print("STARTUP RENDER READINESS: %s" % ["PASS" if ok else "FAIL"])
	if ok:
		var new_game_started := Time.get_ticks_msec()
		game._new_game()
		# Production deliberately holds gameplay hydration for eight seconds so
		# the first controllable window is not competing with imported actors.
		var hydration_deadline := Time.get_ticks_msec() + 15000
		while game.opening_detail_stage_index < 2 and Time.get_ticks_msec() < hydration_deadline:
			await process_frame
		var active_anwen := game.zone_root.find_child("sister_anwen", true, false) as Area3D
		ok = active_anwen != null and active_anwen.visible and _has_enabled_collision(active_anwen)
		ok = ok and _visible_renderable_count(active_anwen) > 0
		print("STARTUP ANWEN HYDRATION: %s stage=%d" % [
			"PASS" if ok else "FAIL", game.opening_detail_stage_index,
		])
		print("STARTUP FIRST CONTROL SETTLE: ms=%d" % (Time.get_ticks_msec() - new_game_started))
		var player_atlas := _opening_character_atlas_contract(
			game.player, "Kael_A_Set_Atlas", "Kael_A_Set_Atlas.png", 1,
			["KaelSwordSocket", "KaelBackSwordSocket"]
		)
		var anwen_atlas := _opening_character_atlas_contract(
			active_anwen, "Anwen_A_Set_Atlas", "Anwen_A_Set_Atlas.png", 1,
			["AnwenStaffSocket"]
		)
		ok = ok and bool(player_atlas.get("valid", false)) and bool(anwen_atlas.get("valid", false))
		print("STARTUP OPENING CHARACTER ATLAS: %s kael=%s anwen=%s" % [
			"PASS" if bool(player_atlas.get("valid", false)) and bool(anwen_atlas.get("valid", false)) else "FAIL",
			JSON.stringify(player_atlas), JSON.stringify(anwen_atlas),
		])
		var probe = load("res://scripts/qa_browser_telemetry.gd").new()
		root.add_child(probe)
		var worst := 0
		for index in range(20):
			if index == 1:
				var catalog_growth_marker := Node3D.new()
				catalog_growth_marker.name = "DeferredCatalogGrowthMarker"
				game.zone_root.add_child(catalog_growth_marker)
			var started := Time.get_ticks_usec()
			var state: Dictionary = probe.snapshot_for_game(game)
			var encoded := JSON.stringify(state)
			var elapsed := Time.get_ticks_usec() - started
			worst = maxi(worst, elapsed)
			if index == 0:
				print("SNAPSHOT FIRST: usec=%d bytes=%d" % [elapsed, encoded.length()])
				var interaction_ids: Array[String] = []
				for interaction in state.get("interactions", []):
					interaction_ids.append(str(interaction.get("id", "")))
				var gate_targets: Array[String] = []
				for gate in state.get("gates", []):
					gate_targets.append(str(gate.get("target", "")))
				print("STARTUP CATALOG: root_children=%d cache=%d interactions=%s gates=%s" % [
					game.zone_root.get_child_count(), game.interaction_area_cache.size(),
					JSON.stringify(interaction_ids), JSON.stringify(gate_targets),
				])
				ok = ok and "sister_anwen" in interaction_ids
				ok = ok and "wychwood" in gate_targets
			elif index == 1:
				var refreshed_ids: Array[String] = []
				for interaction in state.get("interactions", []):
					refreshed_ids.append(str(interaction.get("id", "")))
				var refreshed_gates: Array[String] = []
				for gate in state.get("gates", []):
					refreshed_gates.append(str(gate.get("target", "")))
				ok = ok and "sister_anwen" in refreshed_ids and "wychwood" in refreshed_gates
				print("STARTUP CATALOG INVALIDATION: %s" % ["PASS" if ok else "FAIL"])
			ok = ok and bool(state.get("ready", false))
		print("SNAPSHOT WORST: usec=%d samples=20" % worst)
		probe.queue_free()
		var materials: Dictionary = {}
		var shaders: Dictionary = {}
		var shader_details: Dictionary = {}
		for mesh_node in game.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.mesh == null:
				continue
			for surface in range(mesh_node.mesh.get_surface_count()):
				var material: Material = mesh_node.get_active_material(surface)
				if material == null:
					continue
				var material_id := material.get_instance_id()
				if materials.has(material_id):
					continue
				materials[material_id] = true
				var features: Dictionary = {"class": material.get_class()}
				if material is BaseMaterial3D:
					for property in [
						"shading_mode", "transparency", "cull_mode", "normal_enabled",
						"ao_enabled", "emission_enabled", "uv1_triplanar",
						"uv1_world_triplanar", "vertex_color_use_as_albedo",
						"billboard_mode", "no_depth_test", "grow_enabled",
						"distance_fade_mode", "proximity_fade_enabled",
						"alpha_antialiasing_mode", "texture_filter",
					]:
						features[property] = material.get(property)
				elif material is ShaderMaterial:
					var custom_shader := (material as ShaderMaterial).shader
					features["shader_code_hash"] = hash(custom_shader.code) if custom_shader != null else 0
				var key := JSON.stringify(features)
				shaders[key] = int(shaders.get(key, 0)) + 1
				if not shader_details.has(key):
					shader_details[key] = {"features": features, "materials": [], "nodes": []}
				var detail: Dictionary = shader_details[key]
				var material_name := material.resource_name if material.resource_name != "" else "<unnamed>"
				if material_name not in detail.materials:
					detail.materials.append(material_name)
				if detail.nodes.size() < 8:
					detail.nodes.append(str(mesh_node.get_path()))
		print("STARTUP MATERIALS: unique=%d feature_groups=%d (not compiled shader count)" % [materials.size(), shaders.size()])
		var ordered_groups := shader_details.keys()
		ordered_groups.sort_custom(func(a: String, b: String) -> bool: return int(shaders[a]) > int(shaders[b]))
		for group_index in ordered_groups.size():
			var group_key: String = ordered_groups[group_index]
			var detail: Dictionary = shader_details[group_key]
			print("STARTUP MATERIAL GROUP %02d: count=%d features=%s materials=%s nodes=%s" % [
				group_index + 1,
				int(shaders[group_key]),
				JSON.stringify(detail.features),
				JSON.stringify(detail.materials),
				JSON.stringify(detail.nodes),
			])
		if graphical:
			for index in range(30):
				await RenderingServer.frame_post_draw
			print("STARTUP GRAPHICAL: frames=%d worst_gap_ms=%.2f draws=%d primitives=%d" % [draw_count, worst_draw_gap / 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			print("STARTUP RENDER CALLBACK: worst_ms=%.2f (CPU submission, not GPU timer)" % [worst_render / 1000.0])
	if graphical:
		RenderingServer.frame_post_draw.disconnect(_record_draw)
		RenderingServer.frame_pre_draw.disconnect(_begin_draw)
	# This fixture owns the complete process lifetime. The prepare phase keeps
	# detached actor branches and cache-backed continuations alive for staged
	# route retirement, which is correct during play but leaks bare RefCounted
	# coroutine states when the verifier exits immediately afterward.
	game.finalize_resource_shutdown()
	for index in range(12):
		await process_frame
	game.queue_free()
	for index in range(12):
		await process_frame
	print("STARTUP SNAPSHOT PROFILE: %s (native only)" % ["PASS" if ok else "FAIL"])
	quit(0 if ok else 1)

func _has_enabled_collision(node: Node) -> bool:
	for descendant in node.find_children("*", "CollisionShape3D", true, false):
		if not (descendant as CollisionShape3D).disabled:
			return true
	return false

func _visible_renderable_count(node: Node) -> int:
	var count := 0
	for descendant in node.find_children("*", "", true, false):
		if (descendant is MeshInstance3D or descendant is GPUParticles3D) and (descendant as Node3D).visible:
			count += 1
	return count

func _renderable_count(node: Node) -> int:
	var count := 0
	for descendant in node.find_children("*", "", true, false):
		if descendant is MeshInstance3D or descendant is GPUParticles3D:
			count += 1
	return count

func _opening_character_atlas_contract(node: Node, material_name: String, texture_name: String, minimum_surfaces: int, required_sockets: Array) -> Dictionary:
	var materials: Dictionary = {}
	var surfaces := 0
	var uv_valid := true
	var texture_valid := true
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or str(mesh.get_meta("universal_material_budget", "")) != "single_material_prebaked_atlas":
			continue
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				texture_valid = false
				continue
			materials[material.get_instance_id()] = material.resource_name
			texture_valid = texture_valid and material.resource_name == material_name
			texture_valid = texture_valid and material.albedo_texture != null
			texture_valid = texture_valid and material.albedo_texture.resource_path.get_file() == texture_name
			var arrays := mesh.mesh.surface_get_arrays(surface_index)
			var uv_data = arrays[Mesh.ARRAY_TEX_UV]
			if not (uv_data is PackedVector2Array) or uv_data.is_empty():
				uv_valid = false
			else:
				for uv in uv_data:
					if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
						uv_valid = false
						break
			surfaces += 1
	var sockets_valid := true
	for socket_name in required_sockets:
		sockets_valid = sockets_valid and node.find_child(str(socket_name), true, false) != null
	var skeleton := node.find_child("Skeleton3D", true, false) as Skeleton3D
	var valid := surfaces >= minimum_surfaces and materials.size() == 1 and uv_valid and texture_valid
	valid = valid and skeleton != null and skeleton.get_bone_count() >= 60 and sockets_valid
	return {
		"valid": valid, "surfaces": surfaces, "materials": materials.size(),
		"uv": uv_valid, "texture": texture_valid,
		"bones": skeleton.get_bone_count() if skeleton != null else 0,
		"sockets": sockets_valid,
	}

func _record_draw() -> void:
	var now := Time.get_ticks_usec()
	worst_draw_gap = maxi(worst_draw_gap, now - last_draw)
	worst_render = maxi(worst_render, now - draw_started)
	last_draw = now
	draw_count += 1

func _begin_draw() -> void:
	draw_started = Time.get_ticks_usec()
