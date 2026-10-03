extends SceneTree

const MaterialLibrary = preload("res://scripts/world_material_library.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := MaterialLibrary.new()
	root.add_child(library)
	var surfaces := ["medieval_brick", "plaster", "timber", "roof_tiles"]
	library.prewarm_surfaces(surfaces, "balanced")
	var failure := ""
	if library.pending_textures.size() != 4:
		failure = "Expected four owned requests before polling"
	library.clear_cache()
	if not library.pending_textures.is_empty() or not library.texture_cache.is_empty():
		failure = "Retirement retained request/cache ownership"
	library.prewarm_surfaces(surfaces, "balanced")
	var deadline := Time.get_ticks_msec() + 10000
	var status: Error = library.poll_prewarm()
	while status == ERR_BUSY and Time.get_ticks_msec() < deadline:
		await process_frame
		status = library.poll_prewarm()
	if status != OK or library.texture_cache.size() != 4:
		failure = "Retired owner could not prewarm again"
	var cached_texture = library.texture_cache.get("timber_albedo.jpg")
	# Reproduce the old sticky failure/null cache without emitting fake engine errors.
	library.prewarm_failed = true
	library.prewarm_error = "previous attempt"
	library.texture_cache["timber_normal.jpg"] = null
	library.begin_prewarm_attempt()
	library.prewarm_surfaces(["timber"], "quality")
	deadline = Time.get_ticks_msec() + 10000
	status = library.poll_prewarm()
	while status == ERR_BUSY and Time.get_ticks_msec() < deadline:
		await process_frame
		status = library.poll_prewarm()
	if status != OK or library.texture_cache.get("timber_normal.jpg") == null or library.texture_cache.get("timber_albedo.jpg") != cached_texture:
		failure = "Retry failed to recover Quality while retaining valid textures"
	cached_texture = null
	library.clear_cache()
	library.clear_cache()
	library.queue_free()
	# Let queued node deletion complete before ending the fixture.
	for frame in range(12):
		await process_frame
	if failure != "":
		push_error(failure)
	print("MATERIAL PREWARM RETIREMENT: " + ("PASS" if failure == "" else failure))
	call_deferred("quit", 0 if failure == "" else 1)
