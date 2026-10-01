extends SceneTree

class IsolatedManager extends "res://scripts/runtime_pack_manager.gd":
	func _start_pending_downloads() -> void:
		pass # Keep the real request/failure/retry state machine; do not open sockets.

var failures: Array[String] = []

func _initialize() -> void:
	var manager := IsolatedManager.new()
	manager.manifest = {"packs": {
		"retry_fixture": {"url": "https://example.invalid/opening.pck", "version": "retry-fixture", "status": "external"},
		"missing_url": {"url": "", "status": "external"},
		"embedded_fixture": {"url": "", "status": "embedded_current_pck"},
	}}
	_check(manager.request_pack("retry_fixture"), "Initial request rejected")
	for attempt in range(manager.MAX_RETRIES + 1):
		manager._on_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "retry_fixture")
		_check(manager.get_state("retry_fixture") == "failed", "Failed download was not failed")
		_check(not manager.is_ready("retry_fixture"), "Failed download became ready")
		_check(int(manager.requests["retry_fixture"].get("attempt", -1)) == attempt, "Failure reset retry count")
		var accepted := manager.retry_pack("retry_fixture")
		if attempt < manager.MAX_RETRIES:
			_check(accepted and manager.get_state("retry_fixture") == "queued", "Retry did not reconstruct queued request")
			_check(manager.requests["retry_fixture"].get("url") == "https://example.invalid/opening.pck", "Retry lost download URL")
		else:
			_check(not accepted, "Retry limit was bypassed")
	_check(not manager.request_pack("missing_url"), "External pack without URL was accepted")
	_check(not manager.retry_pack("missing_url"), "Retry accepted missing external URL")
	_check(not manager.request_pack("unknown_fixture"), "Unknown pack was accepted")
	_check(not manager.retry_pack("unknown_fixture"), "Retry made unknown pack ready")
	manager.requests["missing_url"] = {"state": "queued"}
	manager._start_download("missing_url")
	_check(not manager.is_ready("missing_url"), "Queue path silently treated external pack as embedded")
	_check(manager.request_pack("embedded_fixture"), "Explicit embedded content was rejected")
	manager._start_download("embedded_fixture")
	_check(manager.is_ready("embedded_fixture"), "Explicit embedded content did not become ready")
	manager.free()
	for failure in failures:
		printerr("PACK RETRY: " + failure)
	print("PACK RETRY: %s (isolated state/failure contract, no network)" % ["PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
