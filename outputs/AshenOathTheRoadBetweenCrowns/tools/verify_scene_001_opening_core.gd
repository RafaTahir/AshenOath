extends SceneTree

const RiverSection = preload("res://scripts/zones/river_section.gd")
const VisualDirector = preload("res://scripts/visual_director.gd")
const ZoneBuildContext = preload("res://scripts/zone_build_context.gd")
const ZoneSceneCatalog = preload("res://scripts/zone_scene_catalog.gd")
const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")

const GREYFEN_CORE_PATH := "res://scenes/runtime/greyfen_gameplay_core.tscn"

var failures: Array[String] = []

class RiverHost extends Node:
	var zone_root: Node3D

	func _recover_from_river(_body: Node, _center_z: float, _span: float) -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := RiverHost.new()
	root.add_child(host)
	host.zone_root = Node3D.new()
	host.zone_root.name = "greyfen"
	host.add_child(host.zone_root)

	var packed := load(GREYFEN_CORE_PATH) as PackedScene
	_check(packed != null, "authored Greyfen gameplay core did not load")
	var core: Node3D
	if packed != null:
		core = packed.instantiate() as Node3D
		host.zone_root.add_child(core)
	_check(core != null, "authored Greyfen gameplay core did not instantiate")
	if core != null:
		_check(bool(core.get_meta("authored_gameplay_core", false)), "authored core metadata is missing")
		_check(str(core.get_meta("ticket", "")) == "SCENE-001", "authored core ticket metadata is wrong")
		_check(_count_type(core, MeshInstance3D) >= 16, "authored core is still a marker-only scene")
		_check(_count_type(core, StaticBody3D) >= 19, "authored core lacks physical gameplay geometry")
		_check(_count_type(core, CollisionShape3D) >= 19, "authored core lacks collision shapes")
		_check(core.find_child("PavedRoadMain", true, false) != null, "authored core lacks the main road")
		_check(core.find_child("SpawnAnchor", true, false) != null, "authored core lacks spawn anchor")
		_check(core.find_child("AnwenAnchor", true, false) != null, "authored core lacks Anwen interaction anchor")
		_check(core.find_child("WychwoodGateAnchor", true, false) != null, "authored core lacks Wychwood route anchor")
		_check(core.find_child("DeepWoodGateAnchor", true, false) != null, "authored core lacks Deep Wood route anchor")
		_check(core.find_child("CastleGateAnchor", true, false) != null, "authored core lacks Castle route anchor")
		var bridge := core.find_child("RiverBridgeContinuousSurface", true, false) as StaticBody3D
		_check(bridge != null, "authored core lacks continuous bridge surface")
		if bridge != null:
			var bridge_shape := bridge.find_child("CollisionShape3D", false, false) as CollisionShape3D
			_check(bridge_shape != null and bridge_shape.shape is BoxShape3D, "authored bridge shape is invalid")
			if bridge_shape != null and bridge_shape.shape is BoxShape3D:
				var size := (bridge_shape.shape as BoxShape3D).size
				_check(is_equal_approx(size.x, BridgeSurfaceContract.DECK_WIDTH), "authored bridge width diverges from shared contract")
				_check(is_equal_approx(size.z, 34.0), "authored bridge corridor does not span both approaches")

	var authored_context := ZoneBuildContext.new(host, "greyfen", "opening_boot")
	_check(authored_context.register_authored_gameplay_core(), "build context did not accept authored core")
	_check(authored_context.ground_count == 1, "authored ground contract was not registered exactly once")
	_check(authored_context.bounds_count == 1, "authored bounds contract was not registered exactly once")
	_check(authored_context.authored_anchor_position("AnwenAnchor", Vector3.ZERO).is_equal_approx(Vector3(2.0, 0.0, -5.0)), "Anwen anchor did not resolve from authored core")

	if core != null:
		core.queue_free()
		await process_frame
	var first_attach := ZoneSceneCatalog.attach("greyfen", host.zone_root, ["gameplay"])
	_check(bool(first_attach.get("ok", false)), "scene catalog could not attach Greyfen gameplay core")
	_check(first_attach.get("attached", []).count("gameplay") == 1, "scene catalog did not report gameplay attachment")
	var core_count := _count_authored_cores(host.zone_root)
	var second_attach := ZoneSceneCatalog.attach("greyfen", host.zone_root, ["gameplay"])
	_check(bool(second_attach.get("ok", false)), "idempotent gameplay attachment failed")
	_check(_count_authored_cores(host.zone_root) == core_count, "scene catalog duplicated authored gameplay core")

	var context := ZoneBuildContext.new(host, "greyfen", "opening_boot")
	var result := RiverSection.new().build(context, 4.5, 42.0, 3.4, true)
	var river := result.get("root") as Node3D
	_check(river != null, "collision-only river root was not built")
	if river != null:
		_check(bool(river.get_meta("opening_boot_collision_only", false)), "boot river was not marked collision-only")
		_check(_count_type(river, GeometryInstance3D) == 0, "boot river created render geometry")
		_check(_count_type(river, AudioStreamPlayer3D) == 0, "boot river created audio")
		_check(river.find_child("RiverMotionController", true, false) == null, "boot river created motion controller")
		_check(_count_named(river, "BridgeSafetyRail_") == 2, "boot river did not retain two bridge safety rails")
		_check(_count_named(river, "RiverBankBarrier_") == 4, "boot river did not retain four bank barriers")
		_check(_count_named(river, "RiverRecoveryVolume_") == 2, "boot river did not retain two recovery volumes")
		var collision_count := _count_type(river, CollisionShape3D)
		RiverSection.new().hydrate_visuals(river, 4.5, 42.0, 3.4)
		_check(bool(river.get_meta("river_visuals_ready", false)), "river hydration did not publish readiness")
		_check(_count_type(river, GeometryInstance3D) > 0, "river hydration did not create presentation geometry")
		_check(_count_type(river, AudioStreamPlayer3D) == 1, "river hydration did not create exactly one audio player")
		_check(river.find_child("RiverMotionController", true, false) != null, "river hydration did not create motion controller")
		_check(_count_type(river, CollisionShape3D) == collision_count, "river hydration changed authoritative collision count")
		var hydrated_children := river.get_child_count()
		RiverSection.new().hydrate_visuals(river, 4.5, 42.0, 3.4)
		_check(river.get_child_count() == hydrated_children, "river hydration was not idempotent")
		var river_audio := river.find_child("RiverCurrentAudio", true, false) as AudioStreamPlayer3D
		if river_audio != null:
			river_audio.stop()
			river_audio.stream = null

	var visual := VisualDirector.new()
	root.add_child(visual)
	await process_frame
	visual.apply_zone("greyfen")
	visual.set_opening_boot_budget(true)
	visual.set_time(720.0, "day", 0)
	_check(visual.is_opening_boot_budget_active(), "visual boot budget did not activate")
	_check(not visual.sun_disc.visible and not visual.cloud_layer.visible and not visual.star_field.visible, "boot budget left celestial geometry visible")
	visual.set_opening_boot_budget(false)
	_check(not visual.is_opening_boot_budget_active(), "visual boot budget did not deactivate")
	_check(visual.sun_disc.visible, "daylight sun did not restore after boot budget")
	_check(visual.cloud_layer.visible, "cloud layer did not restore after boot budget")

	host.free()
	visual.free()
	call_deferred("_finish")

func _finish() -> void:
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SCENE-001 OPENING CORE: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SCENE-001 OPENING CORE: FAIL (%d)" % failures.size())
		quit(1)

func _count_type(node: Node, type_value: Variant) -> int:
	var count := 0
	for descendant in node.find_children("*", "", true, false):
		if is_instance_of(descendant, type_value):
			count += 1
	return count

func _count_named(node: Node, prefix: String) -> int:
	var count := 0
	for descendant in node.find_children("*", "", true, false):
		if str(descendant.name).begins_with(prefix):
			count += 1
	return count

func _count_authored_cores(node: Node) -> int:
	var count := 0
	for descendant in node.find_children("*", "", true, false):
		if bool(descendant.get_meta("authored_gameplay_core", false)):
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
