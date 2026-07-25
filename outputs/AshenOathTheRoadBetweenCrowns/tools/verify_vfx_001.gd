extends SceneTree

const WorldVFXController = preload("res://scripts/world_vfx_controller.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")

var failures := 0

func _initialize() -> void:
	var potato := WorldVFXController.new()
	root.add_child(potato)
	potato.configure("greyfen", "potato")
	check(int(potato.budget_snapshot().motes) == 4, "Potato weather budget is incorrect")
	var balanced := WorldVFXController.new()
	root.add_child(balanced)
	await process_frame
	balanced.configure("wychwood", "balanced")
	check(int(balanced.budget_snapshot().motes) == 8, "Balanced weather budget is incorrect")
	balanced.pulse_interaction(Vector3.ZERO)
	check(int(balanced.budget_snapshot().active_pulses) == 1, "Interaction feedback did not spawn")
	var target := Node3D.new()
	root.add_child(target)
	var warning = CombatFeedback.warning_marker(target, target)
	check(warning != null and warning.mesh is PrismMesh, "Enemy warning remains a debug disc")
	check(warning.position.z < -0.4, "Enemy warning is not aligned to its strike lane")
	await create_timer(0.35).timeout
	check(int(balanced.budget_snapshot().active_pulses) == 0, "Interaction feedback did not clean itself up")
	print("VFX-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
