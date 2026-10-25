extends SceneTree

class IsolatedManager extends "res://scripts/runtime_pack_manager.gd":
	var started: Array[String] = []
	func _start_download(id: String) -> void:
		if has_embedded_content(id):
			super._start_download(id)
			return
		started.append(id)
		requests[id]["state"] = "downloading"
		active_downloads[id] = true
	func complete(id: String) -> void:
		active_downloads.erase(id)
		requests[id]["state"] = "verified"
		_start_pending_downloads()
	func _mount_cached_pack(id: String, _path: String) -> bool:
		if not _dependencies_ready(id):
			return false
		_mark_mounted(id, "fixture://" + id)
		return true

var failures: Array[String] = []

func _initialize() -> void:
	if "--destination-queue-only" in OS.get_cmdline_user_args():
		_verify_destination_queue()
		_finish()
		return
	var manager := _manager()
	_check(manager.request_pack("c"), "Diamond request rejected")
	_check(manager.started == ["a", "b", "c"], "Required downloads did not use the bounded parallel slots")
	_check(manager.get_state("c") == "downloading" and not manager.is_ready("c"), "Dependent became ready before prerequisites")
	manager.complete("c")
	_check(manager.get_state("c") == "verified" and not manager.is_ready("c"), "Verified dependent mounted before prerequisites")
	manager.complete("b")
	_check(manager.get_state("c") == "verified" and not manager.is_ready("c"), "Dependent mounted with one prerequisite missing")
	manager.complete("a")
	_check(manager.started == ["a", "b", "c"], "Dependency completion duplicated a download")
	_check(manager.is_ready("c"), "Completed dependency chain not ready")
	manager.free()

	manager = _manager()
	manager.request_pack("c")
	manager._on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "a")
	_check(manager.get_state("c") == "failed", "Dependency failure did not propagate")
	_check(not manager.active_downloads.has("c"), "Failed dependency left the dependent transfer running")
	_check(manager.get_state("b") == "downloading", "Shared sibling was incorrectly cancelled")
	_check(manager.retry_pack("c"), "Dependent retry rejected")
	_check(manager.started.count("a") == 2 and int(manager.requests["a"]["attempt"]) == 1, "Failed prerequisite was not retried with a bounded count")
	manager.complete("a")
	manager.complete("b")
	_check(manager.get_state("c") == "downloading", "Dependent retry did not resume")
	manager.free()

	manager = _manager()
	manager.request_pack("c")
	manager.cancel_request("a")
	_check(manager.get_state("c") == "failed", "Cancelled dependency left its dependent waiting forever")
	manager.free()

	manager = _manager()
	manager.request_pack("c")
	manager.cancel_request("c")
	manager.complete("a")
	manager.complete("b")
	_check(manager.get_state("c") == "cancelled" and manager.started.count("c") == 1, "Cancelled dependent restarted")
	manager.free()

	manager = _manager()
	manager.request_pack("c")
	manager.request_pack("extra")
	manager.retire_unneeded_packs(["c"])
	_check(manager.get_state("a") == "downloading" and manager.get_state("b") == "downloading", "Retirement removed retained dependencies")
	_check(not manager.requests.has("extra"), "Unrelated pending pack was retained")
	manager.free()

	for invalid in [{"dependencies": ["c"]}, {"dependencies": ["missing"]}, {"dependencies": "base"}]:
		manager = _manager()
		manager.manifest["packs"]["a"] = invalid
		_check(not manager.request_pack("c") and manager.started.is_empty(), "Invalid graph started partial downloads")
		manager.free()

	manager = _manager()
	manager.pack_ready.connect(func(id: String):
		if id == "base":
			manager.request_pack("extra")
	)
	manager.request_pack("c")
	_check(manager.active_downloads.size() == 3 and manager.get_state("extra") == "queued", "Reentrant request exceeded bounded transfer slots")
	manager.complete("a")
	_check(manager.active_downloads.size() == 3 and manager.started.count("extra") == 1, "Reentrant request was lost or duplicated after a slot became available")
	var started_before_clear := manager.started.size()
	manager.clear_requests()
	_check(manager.requests.is_empty() and manager.active_downloads.is_empty(), "Clear retained active requests")
	_check(manager.started.size() == started_before_clear, "Clear started queued downloads while cancelling")
	manager.free()
	_verify_destination_queue()
	_finish()

func _verify_destination_queue() -> void:
	var manager := IsolatedManager.new()
	manager.manifest = JSON.parse_string(FileAccess.get_file_as_string("res://runtime_pack_manifest.json"))
	manager._mark_embedded_ready("base")
	manager._mark_mounted("opening", "fixture://opening")
	manager.prioritize_zone("wychwood")
	var queued := manager.request_zone_packs("wychwood", [], true)
	_check(queued, "Current Wychwood Continue dependency set was rejected: " + str(manager.requests))
	_check("adjacent" in manager.started and "characters" in manager.started, "Current destination did not schedule its required ownership")
	_check(_request_from_dynamic_owner(manager), "Dynamic Continue owner rejected the destination pack request")
	manager.free()

func _finish() -> void:
	for failure in failures:
		printerr("PACK DEPENDENCIES: " + failure)
	print("PACK DEPENDENCIES: %s (native scheduler/state proof; network/mount completion isolated)" % ["PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func _manager() -> IsolatedManager:
	var manager := IsolatedManager.new()
	manager.manifest = {"packs": {
		"base": {"url": "", "status": "embedded_current_pck", "dependencies": []},
		"a": {"url": "https://example.invalid/a.pck", "dependencies": ["base"]},
		"b": {"url": "https://example.invalid/b.pck", "dependencies": ["base"]},
		"c": {"url": "https://example.invalid/c.pck", "dependencies": ["a", "b"]},
		"extra": {"url": "https://example.invalid/extra.pck", "dependencies": []},
	}}
	return manager

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _request_from_dynamic_owner(manager: Variant) -> bool:
	var encounter_packs: Array[String] = []
	return manager.request_zone_packs("wychwood", encounter_packs, true)
