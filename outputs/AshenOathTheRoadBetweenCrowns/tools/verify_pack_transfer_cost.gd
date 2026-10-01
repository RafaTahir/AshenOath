extends SceneTree

var started := 0
var request: HTTPRequest
var finished := false
var exit_status := 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	request = HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.download_chunk_size = 1024 * 1024
	root.add_child(request)
	request.request_completed.connect(_completed)
	paused = true
	started = Time.get_ticks_msec()
	if request.request("http://127.0.0.1:18763/opening.pck") != OK:
		_finish(false, "request rejected")
		return
	while not finished:
		await process_frame
		if Time.get_ticks_msec() - started > 30000:
			_finish(false, "paused transfer timed out")
	await process_frame
	await process_frame
	quit(exit_status)

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var received := Time.get_ticks_msec()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish(false, "HTTP failure %d/%d" % [result, code])
		return
	var path := "D:/Temp/AshenOath/transfer_cost.part"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_finish(false, "scratch file unavailable")
		return
	file.store_buffer(body)
	file.close()
	var written := Time.get_ticks_msec()
	var manager = load("res://scripts/runtime_pack_manager.gd").new()
	var metadata: Dictionary = {}
	var error: String = manager._validate_artifact("opening", path, true, metadata)
	var verified := Time.get_ticks_msec()
	var mounted := false
	if error == "":
		mounted = ProjectSettings.load_resource_pack(path, false)
	var end := Time.get_ticks_msec()
	manager.free()
	print("PACK COST: bytes=%d transfer_ms=%d write_ms=%d verify_ms=%d mount_ms=%d" % [body.size(), received-started, written-received, verified-written, end-verified])
	# Godot retains the mounted pack until process exit; leave scratch in QA temp.
	_finish(error == "" and mounted, error)

func _finish(ok: bool, message: String) -> void:
	finished = true
	request.cancel_request()
	root.remove_child(request)
	request.queue_free()
	print("PAUSED PACK TRANSFER: %s %s" % ["PASS" if ok else "FAIL", message])
	exit_status = 0 if ok else 1
