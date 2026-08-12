extends SceneTree

const ZoneStreamingService = preload("res://scripts/zone_streaming_service.gd")
const OathGatePortal = preload("res://scripts/oath_gate_portal.gd")

func _init() -> void:
	var failures: Array[String] = []
	var service := ZoneStreamingService.new()
	service.name = "PortalStreamingVerifier"
	root.add_child(service)
	var portal := OathGatePortal.new()
	portal.name = "VerifierOathGate"
	portal.configure("greyfen", "verifier_gate")
	root.add_child(portal)
	portal.bind_streaming(service)
	portal.begin_preload()
	for _frame in range(60):
		if portal.state == OathGatePortal.PortalState.READY:
			break
		await process_frame
	_check(portal.state == OathGatePortal.PortalState.READY, failures, "embedded destination did not reach READY")
	_check(portal.find_child("OathGateBlackGlass", true, false) != null, failures, "black-glass panel missing")
	_check(portal.find_child("OathGateRunicEdge", true, false) != null, failures, "runic edge missing")
	_check(portal.find_children("OathGateAshMote_*", "MeshInstance3D", true, false).size() >= 5, failures, "ash motes missing")
	portal.mark_traveling()
	_check(portal.state == OathGatePortal.PortalState.TRAVELING, failures, "READY portal did not enter TRAVELING")
	portal.set_state(OathGatePortal.PortalState.ERROR)
	_check(portal.state == OathGatePortal.PortalState.ERROR, failures, "ERROR state is not writable")
	if failures.is_empty():
		print("PORTAL-001 VERIFIER: PASS (visual states, preload, travel, error)")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PORTAL-001 VERIFIER: FAIL")
	quit(1)

func _check(condition: bool, failures: Array[String], message: String) -> void:
	if not condition:
		failures.append(message)
