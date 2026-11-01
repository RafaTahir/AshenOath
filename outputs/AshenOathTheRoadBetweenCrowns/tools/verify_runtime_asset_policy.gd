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
	await _verify_included_roles()
	await _verify_diagnostic_fallback()
	_finish()

func _verify_included_roles() -> void:
	for selection: Array in [["player_human", "characters"], ["ghoulkin_creature", "enemies"]]:
		var acceptance: Dictionary = helper.database.get_runtime_acceptance(selection[0])
		var before := acceptance.duplicate(true)
		var visual := helper.spawn_visual_role(selection[0], selection[1], "policy-test") as Node3D
		_check(visual != null, "included role did not instantiate: " + str(selection[0]))
		if visual == null:
			continue
		root.add_child(visual)
		spawned_nodes.append(visual)
		await process_frame
		var expected := "approved" if bool(acceptance.get("visual_reviewed", false)) else "authorized_pending_review"
		_check(str(visual.get_meta("runtime_role_state", "")) == expected, "role must retain inclusion/visual-review distinction: " + str(selection[0]))
		_check(not bool(visual.get_meta("runtime_fallback_used", true)), "included role reported fallback usage")
		_check(str(visual.get_meta("runtime_asset_path", "")) == str(acceptance.get("model", "")), "included role selected a different current model")
		_check(bool(visual.get_meta("runtime_visual_approved", true)) == bool(acceptance.get("visual_reviewed", false)), "inclusion manufactured visual review")
		_check(helper.database.get_runtime_acceptance(selection[0]) == before, "runtime inclusion mutated source approval metadata")

func _verify_diagnostic_fallback() -> void:
	# Deliberately reject a copied in-memory policy. A production role must not
	# remain unapproved merely to supply this negative test fixture.
	var acceptance_key := "bell_eater_boss" if helper.database.runtime_acceptance.roles.has("bell_eater_boss") else "bell_eater"
	var accepted: Dictionary = helper.database.runtime_acceptance.roles[acceptance_key].duplicate(true)
	var rejected: Dictionary = accepted.duplicate(true)
	rejected.approved = false
	rejected.export_eligible = false
	rejected.fallback_mode = "diagnostic_only"
	rejected.fallback = rejected.model
	rejected.blocked_reason = "Injected policy rejection for verifier negative coverage"
	helper.database.runtime_acceptance.roles[acceptance_key] = rejected
	var visual := helper.spawn_visual_role("bell_eater_boss", "enemies") as Node3D
	helper.database.runtime_acceptance.roles[acceptance_key] = accepted
	_check(visual != null, "diagnostic bell_eater_boss role did not instantiate")
	if visual == null:
		return
	root.add_child(visual)
	spawned_nodes.append(visual)
	await process_frame
	_check(str(visual.get_meta("runtime_role_state", "")) == "diagnostic_fallback",
		"bell_eater_boss role did not expose diagnostic_fallback state")
	_check(bool(visual.get_meta("runtime_fallback_used", false)),
		"bell_eater_boss role did not expose fallback usage")
	_check(str(visual.get_meta("runtime_asset_path", "")) == str(rejected.model),
		"bell_eater_boss role selected an unexpected fallback asset: %s" % str(visual.get_meta("runtime_asset_path", "")))
	var diagnostics: Dictionary = helper.get_runtime_diagnostics() if helper.has_method("get_runtime_diagnostics") else {}
	var record: Dictionary = diagnostics.get("enemies:bell_eater_boss", {})
	_check(not record.is_empty(), "bell_eater_boss diagnostic record was not captured")
	_check(str(record.get("fallback_mode", "")) == "diagnostic_only",
		"bell_eater_boss diagnostic record has unexpected fallback mode: %s" % str(record.get("fallback_mode", "")))
	_check(int(record.get("spawn_count", 0)) == 1,
		"bell_eater_boss diagnostic spawn count is not one: %s" % str(record.get("spawn_count", 0)))

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
		print("RUNTIME ASSET POLICY: PASS - included roles, pending visual review and diagnostic fallback metadata are explicit")
	else:
		print("RUNTIME ASSET POLICY: FAIL (%d)" % failures.size())
		for failure in failures:
			print("- %s" % failure)
	quit(0 if failures.is_empty() else 1)
