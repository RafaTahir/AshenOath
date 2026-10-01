extends SceneTree

class FixtureManager extends "res://scripts/runtime_pack_manager.gd":
	var scratch: String
	func _cache_path(id: String) -> String:
		return scratch.path_join(id + ".pck")
	func _ensure_cache_directory() -> void:
		DirAccess.make_dir_recursive_absolute(scratch)
	func _load_cache_index() -> void:
		cache_index = {}
		var path := scratch.path_join("index.json")
		if FileAccess.file_exists(path):
			cache_index = JSON.parse_string(FileAccess.get_file_as_string(path))
	func _save_cache_index() -> void:
		_ensure_cache_directory()
		var file := FileAccess.open(scratch.path_join("index.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(cache_index))
		file.close()

var failures: Array[String] = []
var fixture_manifest: Dictionary
var scratch: String
var prefix: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].replace("\\", "/").begins_with("D:/Temp/AshenOath/"):
		printerr("PACK HTTP: fixture root under D:/Temp/AshenOath and loopback URL required")
		quit(1)
		return
	scratch = args[0].replace("\\", "/").path_join("cache")
	prefix = "res://" + args[0].get_file() + "/"
	fixture_manifest = {"packs": {"base": {"status": "embedded_current_pck", "url": "", "dependencies": []}}}
	for id in ["foundation", "dependent", "retry", "corrupt", "interrupted", "cancel", "gzip", "decoded"]:
		var source := args[0].path_join(id + ".txt")
		var file := FileAccess.open(source, FileAccess.WRITE)
		file.store_string(id.repeat(32768) if id == "cancel" else "verified:" + id)
		file.close()
		var destination := args[0].path_join(id + ".pck")
		var packer := PCKPacker.new()
		_check(packer.pck_start(destination) == OK, "Fixture pack start failed")
		_check(packer.add_file(prefix + id + ".txt", source) == OK, "Fixture resource add failed")
		_check(packer.flush() == OK, "Fixture pack flush failed")
		fixture_manifest["packs"][id] = {
			"status": "external", "url": args[1] + "/" + id + ".pck",
			"sha256": FileAccess.get_sha256(destination), "bytes": FileAccess.get_file_as_bytes(destination).size(),
			"dependencies": ["foundation"] if id == "dependent" else ["base"],
		}
	var manager := _manager()
	DirAccess.make_dir_recursive_absolute(scratch)
	DirAccess.copy_absolute(args[0].path_join("foundation.pck"), scratch.path_join("base.pck"))
	var ready_order: Array[String] = []
	manager.pack_ready.connect(func(id: String): ready_order.append(id))
	_check(manager.request_pack("dependent"), "Dependency request rejected")
	await _wait_terminal(manager, "dependent")
	_check(manager.is_ready("dependent"), "Dependency HTTP chain failed: " + manager.get_last_error("dependent"))
	_check(not manager.mounted.has("base"), "Embedded base mounted a stale disk cache")
	_check(ready_order.find("foundation") >= 0 and ready_order.find("foundation") < ready_order.find("dependent"), "HTTP dependency ready order incorrect")
	_check(FileAccess.get_file_as_string(prefix + "dependent.txt") == "verified:dependent", "Mounted dependency resource unavailable")
	_check(manager._downloader_for("gzip").accept_gzip, "Native gzip decoding was disabled")
	manager.request_pack("gzip")
	await _wait_terminal(manager, "gzip")
	_check(manager.is_ready("gzip"), "Native compressed response failed: " + manager.get_last_error("gzip"))
	# Simulate Fetch's decoded bytes with the retained Content-Encoding header.
	manager._downloader_for("decoded").accept_gzip = false
	manager.request_pack("decoded")
	await _wait_terminal(manager, "decoded")
	_check(manager.is_ready("decoded"), "Already-decoded browser response failed: " + manager.get_last_error("decoded"))
	_check(FileAccess.get_file_as_string(prefix + "decoded.txt") == "verified:decoded", "Decoded response did not expose the hash-verified resource")
	for id in ["retry", "interrupted"]:
		manager.request_pack(id)
		await _wait_terminal(manager, id)
		_check(manager.get_state(id) == "failed" and not manager.is_ready(id), "Broken response was accepted: " + id)
		_check(manager.retry_pack(id), "Real HTTP retry rejected: " + id)
		await _wait_terminal(manager, id)
		_check(manager.is_ready(id), "Real HTTP retry failed: " + id)
		_check(FileAccess.get_file_as_string(prefix + id + ".txt") == "verified:" + id, "Retry did not expose verified resource: " + id)
	manager.request_pack("corrupt")
	await _wait_terminal(manager, "corrupt")
	_check(manager.get_state("corrupt") == "failed" and manager.get_last_error("corrupt").contains("SHA-256"), "Same-size corrupt response not rejected by hash")
	_check(not FileAccess.file_exists(manager.get_cache_path("corrupt")), "Corrupt final cache file retained")
	_check(not FileAccess.file_exists(manager.get_cache_path("corrupt") + ".part"), "Corrupt temporary cache file retained")
	manager.request_pack("cancel")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and manager.get_state("cancel") == "downloading":
		var downloader: HTTPRequest = manager.downloaders.get("cancel")
		if downloader != null and downloader.get_downloaded_bytes() > 0:
			break
		await process_frame
	_check(manager.get_state("cancel") == "downloading", "Cancellation fixture finished before cancellation")
	manager.cancel_request("cancel")
	_check(manager.get_state("cancel") == "cancelled" and not manager.is_ready("cancel"), "Real transfer cancellation failed")
	manager.clear_requests()
	manager.queue_free()
	await process_frame
	await process_frame
	# A new manager reloads the on-disk index and validates both cached packs.
	manager = _manager()
	manager.set_pack_source("foundation", "http://127.0.0.1:1/offline")
	manager.set_pack_source("dependent", "http://127.0.0.1:1/offline")
	_check(manager.cache_index.has("dependent"), "Cache index did not survive manager recreation")
	_check(manager.request_pack("dependent") and manager.is_ready("dependent"), "Offline verified dependency cache did not mount synchronously")
	_check(manager.active_downloads.is_empty(), "Offline cache attempted a download")
	manager.clear_requests()
	manager.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		printerr("PACK HTTP: " + failure)
	print("PACK HTTP INTEGRATION: %s" % ["PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func _manager() -> FixtureManager:
	var manager := FixtureManager.new()
	manager.scratch = scratch
	root.add_child(manager)
	manager.manifest = fixture_manifest.duplicate(true)
	return manager

func _wait_terminal(manager: FixtureManager, id: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while manager.get_state(id) not in ["ready", "failed", "cancelled"] and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(manager.get_state(id) in ["ready", "failed", "cancelled"], "Transfer timed out: " + id)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
