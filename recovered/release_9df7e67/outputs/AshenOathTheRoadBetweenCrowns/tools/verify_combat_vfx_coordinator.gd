extends SceneTree

const Coordinator = preload("res://scripts/combat_vfx_coordinator.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var zone := Node3D.new()
	root.add_child(zone)
	zone.position = Vector3(10, 0, 5)
	var coordinator := Coordinator.new()
	var other := Coordinator.new()
	var origin := Vector3(2, 1, 3)
	var endpoint := Vector3(2, 1, -3)
	coordinator.make_oathfire_beam(zone, origin, origin, 1.0, true)
	_check(coordinator.active_beam_count() == 0, "Degenerate beam created resources")
	coordinator.make_oathfire_beam(zone, origin, endpoint, 1.0, true)
	_check(coordinator.active_beam_count() == 1, "Balanced beam ownership missing")
	var effect := zone.get_child(0) as Node3D
	_check(effect.get_child_count() == 3 and effect.global_position.is_equal_approx(origin.lerp(endpoint, 0.5)), "Balanced geometry or world-space origin changed")
	_check((-effect.global_basis.z).normalized().dot(origin.direction_to(endpoint)) > 0.999, "Beam direction differs from its clipped endpoint")
	var core := effect.get_node("OathfireBeamCore") as MeshInstance3D
	_check(core != null and is_equal_approx((core.mesh as CylinderMesh).height, 6.0), "Core no longer reaches its authored endpoint")
	other.make_oathfire_beam(zone, origin, endpoint, 0.0, false)
	var simple := zone.get_child(1) as Node3D
	_check(simple.get_child_count() == 1, "Potato beam geometry changed")
	coordinator.clear_oathfire_effects()
	coordinator.clear_oathfire_effects()
	await process_frame
	await process_frame
	_check(coordinator.active_beam_count() == 0 and other.active_beam_count() == 1, "Cancellation removed another owner's effect")
	await create_timer(0.55).timeout
	_check(other.active_beam_count() == 0 and get_nodes_in_group("oathfire_runtime_effect").is_empty(), "Natural recovery retained effects")
	coordinator.make_oathfire_beam(zone, origin, endpoint, 0.5, true)
	coordinator.make_arrow_trail(zone, origin, endpoint, Color(0.92, 0.70, 0.34))
	_check(get_nodes_in_group("arrow_runtime_effect").size() == 1, "Arrow trail was not published")
	zone.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	coordinator.clear_oathfire_effects()
	_check(coordinator.active_beam_count() == 0 and get_nodes_in_group("arrow_runtime_effect").is_empty() and get_processed_tweens().is_empty(), "Zone retirement retained an effect or its tween")
	coordinator = null
	other = null
	print("COMBAT VFX COORDINATOR: %s (geometry, endpoint, quality, isolated cancellation, natural recovery, zone retirement)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
