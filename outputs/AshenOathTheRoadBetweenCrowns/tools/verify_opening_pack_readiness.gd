extends SceneTree

func _initialize() -> void:
	var manager = load("res://scripts/runtime_pack_manager.gd").new()
	manager.requests = {"base": {"state": "ready", "progress": 1.0}}
	if not manager.startup_packs_ready():
		_fail(manager, "Base must permit minimal opening prewarm")
		return
	manager.requests["opening"] = {"state": "failed", "error": "fixture missing pack"}
	if not manager.startup_pack_failures().is_empty():
		_fail(manager, "Deferred opening failure incorrectly blocks startup")
		return
	if manager.zone_packs_ready("greyfen"):
		_fail(manager, "Greyfen detail/travel permits a missing opening pack")
		return
	manager.requests["opening"] = {"state": "ready", "progress": 1.0}
	if not manager.startup_packs_ready():
		_fail(manager, "Opening and base must allow prewarm without campaign")
		return
	if manager.zone_packs_ready("wychwood"):
		_fail(manager, "Wychwood permits missing monster resources")
		return
	manager.requests["monsters"] = {"state": "ready", "progress": 1.0}
	if not manager.zone_packs_ready("wychwood"):
		_fail(manager, "Wychwood unnecessarily requires campaign characters")
		return
	manager.requests["campaign"] = {"state": "ready", "progress": 1.0}
	if manager.zone_packs_ready("vargan_court"):
		_fail(manager, "Castle permits missing character resources")
		return
	manager.requests["characters"] = {"state": "failed", "error": "fixture"}
	if manager.zone_pack_failures("vargan_court").size() != 1:
		_fail(manager, "Character pack failure is not propagated")
		return
	manager.requests["characters"] = {"state": "ready", "progress": 1.0}
	if not manager.zone_packs_ready("vargan_court"):
		_fail(manager, "Complete Castle content rejected")
		return
	manager.free()
	print("OPENING PACK READINESS: PASS (state contract, not Web download proof)")
	quit(0)

func _fail(manager: Node, reason: String) -> void:
	manager.free()
	printerr("OPENING PACK READINESS: FAIL - " + reason)
	quit(1)
