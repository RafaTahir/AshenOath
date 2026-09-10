extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

var failures: Array[String] = []
var helper: Node
var spawned_nodes: Array[Node3D] = []

func _initialize() -> void:
	helper = AssetSpawnHelper.new()
	helper.name = "RuntimeAssetPolicyVerifier"
	root.add_child(helper)
	await process_frame
	await _verify_approved_role()
	await _verify_diagnostic_fallback()
	_finish()

func _verify_approved_role() -> void:
	var visual := helper.spawn_visual_role("player_human", "characters", "policy-test-kael") as Node3D
	_check(visual != null, "approved player_human role did not instantiate")
	if visual == null:
		return
	root.add_child(visual)
	spawned_nodes.append(visual)
	await process_frame
	_check(str(visual.get_meta("runtime_role_state", "")) == "approved",
		"approved player_human role has unexpected runtime state: %s" % str(visual.get_meta("runtime_role_state", "")))
	_check(not bool(visual.get_meta("runtime_fallback_used", true)),
		"approved player_human role reported fallback usage")
	_check(str(visual.get_meta("runtime_asset_path", "")).to_lower().ends_with("male_peasant.gltf"),
		"approved player_human role selected an unexpected asset: %s" % str(visual.get_meta("runtime_asset_path", "")))

func _verify_diagnostic_fallback() -> void:
	var visual := helper.spawn_for_role("ghoulkin", "enemies") as Node3D
	_check(visual != null, "diagnostic ghoulkin role did not instantiate")
	if visual == null:
		return
	root.add_child(visual)
	spawned_nodes.append(visual)
	await process_frame
	_check(str(visual.get_meta("runtime_role_state", "")) == "diagnostic_fallback",
		"ghoulkin role did not expose diagnostic_fallback state")
	_check(bool(visual.get_meta("runtime_fallback_used", false)),
		"ghoulkin role did not expose fallback usage")
	_check(str(visual.get_meta("runtime_asset_path", "")).to_lower().ends_with("skeleton.fbx"),
		"ghoulkin role selected an unexpected fallback asset: %s" % str(visual.get_meta("runtime_asset_path", "")))
	var diagnostics: Dictionary = helper.get_runtime_diagnostics() if helper.has_method("get_runtime_diagnostics") else {}
	var record: Dictionary = diagnostics.get("enemies:ghoulkin", {})
	_check(not record.is_empty(), "ghoulkin diagnostic record was not captured")
	_check(str(record.get("fallback_mode", "")) == "diagnostic_only",
		"ghoulkin diagnostic record has unexpected fallback mode: %s" % str(record.get("fallback_mode", "")))
	_check(int(record.get("spawn_count", 0)) == 1,
		"ghoulkin diagnostic spawn count is not one: %s" % str(record.get("spawn_count", 0)))

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _finish() -> void:
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	if helper != null and is_instance_valid(helper):
		if helper.has_method("clear_runtime_caches"):
			helper.clear_runtime_caches()
		if helper.has_method("clear_runtime_diagnostics"):
			helper.clear_runtime_diagnostics()
		helper.queue_free()
	await process_frame
	RenderingServer.force_sync()
	await process_frame
	RenderingServer.force_sync()
	if failures.is_empty():
		print("RUNTIME ASSET POLICY: PASS - approved roles and diagnostic fallback metadata are explicit")
	else:
		print("RUNTIME ASSET POLICY: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
