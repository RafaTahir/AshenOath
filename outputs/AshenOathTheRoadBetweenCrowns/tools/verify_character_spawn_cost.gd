extends SceneTree

class TimedHelper extends "res://scripts/asset_spawn_helper.gd":
	var costs := {}
	func _normalize_scene_bounds(node: Node3D, height: float) -> void:
		var start := Time.get_ticks_usec()
		super._normalize_scene_bounds(node, height)
		costs["normalize_us"] = Time.get_ticks_usec() - start
	func _apply_safe_materials(node: Node3D, path: String) -> void:
		var start := Time.get_ticks_usec()
		super._apply_safe_materials(node, path)
		costs["materials_us"] = Time.get_ticks_usec() - start
	func _finalize_asset_root(node: Node3D, role: String = "") -> void:
		var start := Time.get_ticks_usec()
		super._finalize_asset_root(node, role)
		costs["finalize_us"] = Time.get_ticks_usec() - start
	func _compose_player_body(node: Node3D, path: String, role: String, variant: String = "") -> Node3D:
		var start := Time.get_ticks_usec()
		var result := super._compose_player_body(node, path, role, variant)
		costs["compose_us"] = Time.get_ticks_usec() - start
		return result
	func _prepare_spawned_asset(node: Node3D, path: String, role: String = "", category: String = "") -> void:
		var start := Time.get_ticks_usec()
		super._prepare_spawned_asset(node, path, role, category)
		costs["prepare_total_us"] = Time.get_ticks_usec() - start

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_anchor: Resource
	if OS.get_cmdline_user_args().has("--retain-animation-source"):
		source_anchor = load("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
	var helper := TimedHelper.new()
	root.add_child(helper)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.2, 3)
	root.add_child(camera)
	camera.current = true
	for index in range(3):
		helper.costs.clear()
		var start := Time.get_ticks_usec()
		var body := helper.spawn_visual_role("mira_human", "characters", "mira")
		helper.costs["spawn_total_us"] = Time.get_ticks_usec() - start
		if body == null:
			push_error("Character cost fixture could not spawn Mira")
			helper.free()
			camera.free()
			quit(1)
			return
		var actor := Node3D.new()
		actor.name = "mira"
		actor.add_child(body)
		start = Time.get_ticks_usec()
		root.add_child(actor)
		helper.costs["enter_tree_us"] = Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		preload("res://scripts/character_presentation.gd").apply_npc(actor, "mira")
		helper.costs["presentation_us"] = Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		await process_frame
		await process_frame
		helper.costs["two_frames_us"] = Time.get_ticks_usec() - start
		print("CHARACTER COST %s: %s" % [index, JSON.stringify(helper.costs)])
		actor.queue_free()
		await process_frame
	var cached_source := helper.resource_cache.has("res://assets_external/animations/AnimationLibrary_Godot_Opening.tres")
	helper.clear_runtime_caches()
	var released_source := helper.resource_cache.is_empty()
	print("CHARACTER COST: animation source retained=%s" % (source_anchor != null))
	helper.queue_free()
	camera.queue_free()
	for frame in range(4):
		await process_frame
	if not cached_source or not released_source:
		push_error("Animation source must be retained by the helper and released by cache cleanup")
		quit(1)
	else:
		print("CHARACTER COST: PASS source cache ownership and cleanup")
		quit(0)
