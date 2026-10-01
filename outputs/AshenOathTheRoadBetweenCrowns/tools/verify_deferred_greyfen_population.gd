extends SceneTree

const GreyfenLifeController = preload("res://scripts/greyfen_life_controller.gd")

class DeferredHost extends Node:
	func should_defer_character_role(_role: String, _actor_id: String) -> bool:
		return true

func _initialize() -> void:
	var host := DeferredHost.new()
	root.add_child(host)
	var controller = GreyfenLifeController.new()
	host.add_child(controller)
	controller.host = host
	var actor := Node3D.new()
	actor.name = "Routine_walker_well"
	host.add_child(actor)

	var driver = controller._make_skeletal_villager(actor, "walker_well", 0, 1.0)
	if driver != null:
		_fail("Deferred population constructed an animation driver before pack readiness")
		return
	var marker = actor.find_child("DeferredCharacterVisual_walker_well", false, false)
	if marker == null:
		_fail("Deferred population marker was not created")
		return
	if str(marker.get_meta("deferred_visual_role", "")) != "villager_human":
		_fail("Deferred population marker lost its runtime role")
		return
	if str(marker.get_meta("deferred_visual_category", "")) != "characters":
		_fail("Deferred population marker has the wrong pack category")
		return
	if str(marker.get_meta("deferred_visual_actor_id", "")) != "generic_villager_01":
		_fail("Deferred population marker lost its deterministic identity")
		return
	if actor.find_children("*", "MeshInstance3D", true, false).size() != 0:
		_fail("Deferred population created fallback geometry")
		return

	print("DEFERRED GREYFEN POPULATION: PASS (marker contract; browser hydration remains required)")
	quit(0)

func _fail(reason: String) -> void:
	push_error("DEFERRED GREYFEN POPULATION: FAIL - " + reason)
	quit(1)
