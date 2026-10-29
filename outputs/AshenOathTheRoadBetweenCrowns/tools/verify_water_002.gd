extends SceneTree

var failures := 0

func _initialize() -> void:
	if "--aftermath-only" in OS.get_cmdline_user_args():
		call_deferred("_verify_aftermath")
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene is unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	game.call("_new_game")
	await _frames(8)
	await _verify_river(game, "greyfen")
	game.call("_load_zone", "wychwood", Vector3(0, 1, 8))
	await _frames(10)
	await _verify_river(game, "wychwood")
	var result_code := 0 if failures == 0 else 1
	await _shutdown_game(game)
	print("WATER-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(result_code)

func _verify_river(game, zone_id: String) -> void:
	var zone_root: Node = game.get("zone_root")
	var river: Node = zone_root.find_child("LivingRiverSection", true, false) if zone_root != null else null
	check(river != null, "%s river is missing" % zone_id)
	if river == null:
		return
	var motion: Node = river.find_child("RiverMotionController", true, false)
	check(motion != null, "%s river motion controller is missing" % zone_id)
	if motion != null:
		check(str(motion.get_meta("ticket", "")) == "WATER-002", "%s river motion ticket metadata is missing" % zone_id)
		var leaves: Node = motion.find_child("RiverFloatingLeafBatch", true, false)
		check(leaves != null and leaves is MultiMeshInstance3D, "%s river leaf batch is missing" % zone_id)
		if leaves is MultiMeshInstance3D:
			var multimesh := (leaves as MultiMeshInstance3D).multimesh
			check(multimesh != null and multimesh.instance_count >= 14, "%s river leaf batch is under-populated" % zone_id)
			if multimesh != null:
				var start_time := float(motion.get("flow_time"))
				var start := multimesh.get_instance_transform(0).origin
				for _tick in range(20):
					await physics_frame
				var end := multimesh.get_instance_transform(0).origin
				check(float(motion.get("flow_time")) > start_time + 0.10, "%s river motion clock is stalled" % zone_id)
				if DisplayServer.get_name().to_lower() != "headless":
					check(end.x > start.x + 0.04 and absf(end.z - start.z) < 0.10, "%s river leaves do not flow along the channel" % zone_id)
		var ribbons := motion.find_child("RiverCurrentRibbonBatch", true, false) as MultiMeshInstance3D
		check(ribbons != null and ribbons.multimesh != null, "%s current ribbons are missing" % zone_id)
		if ribbons != null and ribbons.multimesh != null:
			var ribbon_sizes: Array = motion.get("current_ribbon_sizes")
			check(not ribbon_sizes.is_empty() and ribbon_sizes[0].x < float(motion.get("width")) * 0.20, "%s current ribbon spans too much of the channel" % zone_id)
		check(_count_named(motion, "RiverRipple_") >= 7, "%s river ripple dressing is incomplete" % zone_id)
	check(river.find_child("RiverBankWetness_North", true, false) != null, "%s north bank wetness is missing" % zone_id)
	check(river.find_child("RiverBankWetness_South", true, false) != null, "%s south bank wetness is missing" % zone_id)
	for bank in ["North", "South"]:
		var foam := river.find_child("RiverShoreFoam_%s" % bank, true, false) as MeshInstance3D
		check(foam != null and foam.mesh is ArrayMesh, "%s %s shore foam is not broken shoreline geometry" % [zone_id, bank])
	var water: Node = river.find_child("FlowingRiverWater", true, false)
	check(water != null and water is MeshInstance3D, "%s flowing water is missing" % zone_id)
	if water is MeshInstance3D:
		check(str(water.get_meta("water_role", "")) == "WATER-002", "%s water role metadata is missing" % zone_id)
		check((water as MeshInstance3D).mesh is ArrayMesh, "%s water surface lacks authored shoreline geometry" % zone_id)
		if (water as MeshInstance3D).mesh is ArrayMesh:
			var mesh := (water as MeshInstance3D).mesh as ArrayMesh
			check(mesh.surface_get_array_len(0) >= 1000, "%s water surface lacks vertex resolution for flow" % zone_id)
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(absf(vertices[0].z - vertices[3].z) > 0.001, "%s water still has a straight bank edge" % zone_id)
		var material := (water as MeshInstance3D).material_override
		check(material is ShaderMaterial, "%s water shader material is missing" % zone_id)
		if material is ShaderMaterial:
			var code := (material as ShaderMaterial).shader.code
			for token in ["flow_uv", "depth", "foam", "ripple", "NORMAL", "flow_speed"]:
				check(token in code, "%s water shader lacks %s" % [zone_id, token])
			check("min(UV.y, 1.0 - UV.y)" in code and "vec2(-TIME" in code, "%s shader treats channel ends as banks or flows across the banks" % zone_id)

func _count_named(node: Node, prefix: String) -> int:
	var result := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		result += _count_named(child, prefix)
	return result

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _shutdown_game(game: Node) -> void:
	if is_instance_valid(game) and game.has_method("prepare_resource_shutdown"):
		game.prepare_resource_shutdown()
		await _frames(20)
	if is_instance_valid(game) and game.has_method("finalize_resource_shutdown"):
		game.finalize_resource_shutdown()
		await _frames(12)
	print("VERIFIER_PHASE: SHUTDOWN")
	if is_instance_valid(game):
		game.queue_free()
		await _frames(8)
	RenderingServer.force_sync()
	await _frames(4)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)

class WaterWorkHost extends Node:
	var zone_root: Node3D
	var quests: Node
	var story_state: Node
	var spatial_service = null
	var materials: Dictionary = {}
	func _mat(color: Color) -> StandardMaterial3D:
		if not materials.has(color):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			materials[color] = material
		return materials[color]

func _verify_aftermath() -> void:
	const ID := "saga_wyc_q05"
	const Catalog = preload("res://scripts/saga_catalog.gd")
	const Work = preload("res://scripts/saga_work_presentation.gd")
	var host := WaterWorkHost.new()
	root.add_child(host)
	host.zone_root = Node3D.new()
	host.add_child(host.zone_root)
	host.story_state = preload("res://scripts/story_state.gd").new()
	host.quests = preload("res://scripts/quest_manager.gd").new()
	host.add_child(host.story_state)
	host.add_child(host.quests)
	host.quests.load_quests("res://data/quests.json")
	var progression := preload("res://scripts/progression_manager.gd").new()
	host.add_child(progression)
	progression.load_definitions()
	host.quests.quest_completed.connect(func(id): progression.award_for_quest(id,"side",true))
	var river := Node3D.new()
	river.name = "LivingRiverSection"
	host.zone_root.add_child(river)
	preload("res://scripts/zones/river_section.gd").new()._make_water(river,0,44,3.4)
	var capture_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	if capture_dir != "":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var camera := Camera3D.new()
		host.zone_root.add_child(camera)
		camera.position = Vector3(13,4,-0.5)
		camera.look_at(Vector3(8.4,0.2,-5.6))
		camera.current = true
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55,-35,0)
		host.zone_root.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.12,0.17,0.18)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.5
		host.zone_root.add_child(environment)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(44,34)
		floor_mesh.mesh = plane
		floor_mesh.position.y = -0.02
		floor_mesh.material_override = host._mat(Color(0.18,0.23,0.16))
		host.zone_root.add_child(floor_mesh)
	for outcome: String in ["side_channel", "natural_run"]:
		host.story_state.load_state({})
		host.quests.load_state({})
		progression.load_state({})
		host.quests.unlocked[ID] = true
		check(host.quests.start_quest(ID), "Optional work fixture did not start")
		host.story_state.set_flag(ID + "_outcome",outcome)
		var director := preload("res://scripts/saga_activities.gd").new()
		director.host = host
		director.zone = "wychwood"
		host.zone_root.add_child(director)
		director.set_physics_process(false)
		director._ensure_assembly(ID)
		var assembly: Node3D = director._assemblies[ID]
		check(assembly.global_position.is_equal_approx(Catalog.SITES.wychwood.water), "Water apparatus displaced by marker allocation")
		check(assembly.get_node("InletDebris").visible, "Survey starts with cleared debris")
		check(not assembly.get_node("CollectionStand/CleanPot0").visible, "Pots placed before work")
		for part in range(1,4):
			host.story_state.set_flag(ID + ":clear_and_set:part",part)
			director._ensure_assembly(ID)
			check(not assembly.get_node("InletDebris").visible, "Removed debris reappears")
			check(assembly.get_node("ContainedChannel").visible == (outcome == "side_channel" and part >= 2), "Channel does not match recorded work")
			var saved: Dictionary = JSON.parse_string(JSON.stringify(host.story_state.save_state()))
			host.story_state.load_state(saved)
			director._ensure_assembly(ID)
			var reconstructed := Work.build(host,host.zone_root,ID,false,outcome)
			Work.sync_progress(reconstructed,host,ID)
			check(reconstructed.get_node("ContainedChannel").visible == assembly.get_node("ContainedChannel").visible and reconstructed.get_node("ReusedScreen").position == assembly.get_node("ReusedScreen").position, "Interrupted work differs after reconstruction")
			reconstructed.free()
		check((assembly.get_node("ReusedScreen/DrainGate") as Node3D).position.y > 0.5, "Final gate obstructs flow")
		var expected: Vector3 = Catalog.SITES.wychwood.pots_natural if outcome == "natural_run" else Catalog.SITES.wychwood.pots
		check((assembly.get_node("CollectionStand") as Node3D).global_position.is_equal_approx(expected), "Collection stand did not reach its authored bank")
		var pot_step: Array = Catalog.QUESTS[ID].steps.back()
		check(Catalog.part_site(ID,pot_step,0,host.story_state) == ("pots_natural" if outcome == "natural_run" else "pots"), "Objective points at the old collection site")
		for part in range(1,3):
			host.story_state.set_flag(ID + ":place_clean_pots:part",part)
			director._ensure_assembly(ID)
			for index in range(2):
				check(assembly.get_node("CollectionStand/CleanPot" + str(index)).visible == (index < part), "Pot work is not incremental")
				check(assembly.get_node("WaitingPot" + str(index)).visible == (index >= part), "A pot is duplicated or lost")
		var before: String = JSON.stringify(host.story_state.save_state())
		for repeat in range(3): director._ensure_assembly(ID)
		check(JSON.stringify(host.story_state.save_state()) == before and progression.total_xp == 0, "Visual synchronization wrote state or awarded XP")
		for step: Array in Catalog.QUESTS[ID].steps:
			if str(step[3]) == "choice": host.quests.complete_choice(ID,str(step[0]))
			else: host.quests.complete_objective(ID,str(step[0]))
		check(host.quests.is_completed(ID) and progression.total_xp == 500, "Water quest did not award exactly 500 XP")
		var quest_save: Dictionary = JSON.parse_string(JSON.stringify(host.quests.save_state()))
		var story_save: Dictionary = JSON.parse_string(JSON.stringify(host.story_state.save_state()))
		var xp_save: Dictionary = JSON.parse_string(JSON.stringify(progression.save_state()))
		director.free()
		host.quests.load_state(quest_save)
		host.story_state.load_state(story_save)
		progression.load_state(xp_save)
		director = preload("res://scripts/saga_activities.gd").new()
		director.host = host
		director.zone = "wychwood"
		host.zone_root.add_child(director)
		director.set_physics_process(false)
		director._ensure_assembly(ID)
		assembly = director._assemblies[ID]
		check((assembly.get_node("CollectionStand") as Node3D).global_position.is_equal_approx(expected), "Re-entry lost the selected bank")
		check(assembly.get_node("CollectionStand/CleanPot1").visible, "Completed pots lost on reconstruction")
		check(not progression.award_for_quest(ID,"side",true) and progression.total_xp == 500, "Re-entry permits duplicate XP")
		for actor in ["saga_iven", "saga_edda"]:
			check(not str(Catalog.performance(ID).return_lines[actor][outcome]).is_empty(), "Missing outcome acknowledgement")
		if capture_dir != "":
			await _frames(3)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture_dir.path_join(outcome + ".png")) == OK, "Water aftermath capture failed")
		director.free()
	# A completed legacy quest without a trustworthy branch must not invent one.
	host.story_state.load_state({})
	var unknown := Work.build(host,host.zone_root,ID,true,"")
	Work.sync_progress(unknown,host,ID)
	check(not unknown.get_node("ContainedChannel").visible and not unknown.get_node("CollectionStand/CleanPot0").visible, "Unknown legacy choice fabricated an outcome")
	check("does not identify" in Catalog.aftermath(ID,""), "Unknown branch received a fabricated account")
	unknown.free()
	host.free()
	await _frames(2)
	print("WATER-AFTERMATH: %s; isolated work/save/re-entry/500 XP checks, not an earned campaign or browser pass" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
