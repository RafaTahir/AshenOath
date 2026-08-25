extends SceneTree

const RuntimePackManager = preload("res://scripts/runtime_pack_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var manager := RuntimePackManager.new()
	manager.name = "Stream003Verifier"
	get_root().add_child(manager)
	await process_frame

	if not manager.request_pack("base"):
		errors.append("embedded base request was rejected")
	await process_frame
	if not manager.is_ready("base") or manager.get_progress("base") < 1.0:
		errors.append("embedded base did not become ready")

	manager.set_pack_source("opening", "http://127.0.0.1:1/missing.pck")
	if not manager.request_pack("opening"):
		errors.append("download request could not be queued")
	await process_frame
	var opening_state := manager.get_state("opening")
	if opening_state not in ["queued", "downloading", "failed"]:
		errors.append("unexpected download state: %s" % opening_state)
	manager.cancel_request("opening")
	if manager.get_state("opening") not in ["cancelled", "failed"]:
		errors.append("cancel did not settle the request")

	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		var external_path := str(user_args[0])
		if not manager.mount_local_pack("base", external_path):
			errors.append("verified external base pack failed to mount: %s" % manager.get_last_error("base"))

	if manager.mount_local_pack("base", "user://does-not-exist.pck"):
		errors.append("missing local pack mounted")
	if manager.get_last_error("base") == "":
		errors.append("missing local pack did not record an error")
	if not manager.deployment_budget_ok(84428916):
		errors.append("verified candidate total exceeded manifest budget")
	manager.retire_unneeded_packs(["base"])

	if errors.is_empty():
		print("STREAM-003 VERIFIER: PASS (cache contract, embedded fallback, queue, cancel, validation)")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		print("STREAM-003 VERIFIER: FAIL")
		quit(1)
