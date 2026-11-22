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
		_mark_mounted(id, "fixture://" + id)
		_start_pending_downloads()

var failures: Array[String] = []

func _initialize() -> void:
	var manager := _manager()
	_check(manager.request_pack("c"), "Diamond request rejected")
	_check(manager.started == ["a", "b"], "Independent dependencies did not start together")
	_check(manager.get_state("c") == "queued" and not manager.is_ready("c"), "Dependent became ready before prerequisites")
	manager.complete("b")
	_check(manager.get_state("c") == "queued", "Dependent started with one prerequisite missing")
	manager.complete("a")
	_check(manager.started == ["a", "b", "c"], "Dependent did not start after prerequisites")
	manager.complete("c")
	_check(manager.is_ready("c"), "Completed dependency chain not ready")
	manager.free()

	manager = _manager()
	manager.request_pack("c")
	manager._on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "a")
	_check(manager.get_state("c") == "failed", "Dependency failure did not propagate")
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
	_check(manager.get_state("c") == "cancelled" and not manager.started.has("c"), "Cancelled dependent restarted")
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
	_check(manager.active_downloads.size() == 3 and manager.started.count("extra") == 1, "Reentrant request broke concurrency or scheduling")
	var started_before_clear := manager.started.size()
	manager.clear_requests()
	_check(manager.requests.is_empty() and manager.active_downloads.is_empty(), "Clear retained active requests")
	_check(manager.started.size() == started_before_clear, "Clear started queued downloads while cancelling")
	manager.free()
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
