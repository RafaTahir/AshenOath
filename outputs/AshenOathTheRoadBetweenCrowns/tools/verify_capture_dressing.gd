extends "res://tools/capture_slice_screenshots.gd"

class CaptureFixture extends Node:
	var current_zone_id := "greyfen"
	var zone_root := Node3D.new()

func _initialize() -> void:
	call_deferred("_run_fixture")

func _run_fixture() -> void:
	var fixture := CaptureFixture.new()
	root.add_child(fixture)
	fixture.add_child(fixture.zone_root)
	assert(await _wait_for_zone_dressing(fixture, "greyfen"), "Full roots do not require staged-opening metadata")
	fixture.zone_root.set_meta("opening_build_profile", "opening_boot")
	_complete_staged_fixture(fixture)
	assert(await _wait_for_zone_dressing(fixture, "greyfen"))
	assert(bool(fixture.zone_root.get_meta("opening_detail_complete", false)), "Staged roots must finish before capture")
	var marker := Node.new()
	marker.name = "DeferredVisualRole_fixture"
	fixture.zone_root.add_child(marker)
	fixture.zone_root.set_meta("deferred_visual_roles_pending", true)
	_complete_role_fixture(fixture, marker)
	assert(await _wait_for_zone_dressing(fixture, "greyfen"))
	assert(not bool(fixture.zone_root.get_meta("deferred_visual_roles_pending")), "Deferred actors must finish before capture")
	fixture.free()
	print("CAPTURE DRESSING CONTRACT: PASS - full, staged, and deferred-role roots")
	quit(0)

func _complete_staged_fixture(fixture: Node) -> void:
	await process_frame
	await process_frame
	fixture.zone_root.set_meta("opening_detail_complete", true)

func _complete_role_fixture(fixture: Node, marker: Node) -> void:
	await process_frame
	await process_frame
	marker.free()
	fixture.zone_root.set_meta("deferred_visual_roles_pending", false)
