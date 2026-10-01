extends SceneTree

const Coordinator = preload("res://scripts/quest_hud_coordinator.gd")
const Interactable = preload("res://scripts/interactable.gd")

class PresentationFixture extends Node:
	var view := {"quest_id": "main_road_of_crows", "objective_id": "speak_anwen", "tracker_text": "Speak with Sister Anwen", "next_action": "Speak with Sister Anwen", "contextual_text": "Speak with Sister Anwen", "compass_text": "Greyfen | Anwen"}
	func get_objective_view_model() -> Dictionary:
		return view

class HudFixture extends Node:
	var tracker_label := Label.new()
	var compass := ""
	var guidance := ""
	func _ready() -> void:
		add_child(tracker_label)
	func set_tracker(text: String) -> void:
		tracker_label.text = text
	func set_compass(text: String) -> void:
		compass = text
	func set_guidance_hint(text: String, _seconds: float) -> void:
		guidance = text

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var presentation := PresentationFixture.new()
	var hud := HudFixture.new()
	var player := Node3D.new()
	var anwen := Interactable.new()
	fixture.add_child(presentation)
	fixture.add_child(hud)
	fixture.add_child(player)
	fixture.add_child(anwen)
	anwen.setup("sister_anwen", "dialogue", "Speak")
	anwen.position = Vector3(3, 0, 0)
	var coordinator := Coordinator.new()
	coordinator.configure(presentation, null)
	coordinator.refresh_tracker(hud, Callable())
	coordinator.show_guidance(hud, 5.0)
	_check(hud.tracker_label.text == "Speak with Sister Anwen" and hud.guidance == "", "Tracker/guidance duplication changed")
	coordinator.update_compass(hud, player, "greyfen", [anwen], "Greyfen")
	_check(hud.compass == "Greyfen | Anwen | 3m", "Anwen's initial objective distance changed")
	_check(not coordinator.needs_refresh(player, "greyfen"), "Idle compass cache was not reused")
	player.position.x = 0.26
	_check(coordinator.needs_refresh(player, "greyfen"), "Quarter-metre movement did not invalidate the cache")
	player.position.x = 0.0
	presentation.view["next_action"] = "Follow the crows"
	_check(coordinator.needs_refresh(player, "greyfen"), "Quest change did not invalidate the cache")
	coordinator.refresh_tracker(hud, func() -> String: return "Refreshed beat")
	_check(hud.tracker_label.text == "Refreshed beat" and coordinator.dirty, "Beat refresh or invalidation was lost")
	coordinator.update_compass(hud, player, "greyfen", [anwen], "Greyfen")
	_check(coordinator.needs_refresh(player, "wychwood"), "Zone change did not invalidate the cache")
	anwen.free()
	coordinator.update_compass(hud, player, "greyfen", [anwen], "Greyfen")
	_check(hud.compass == "Greyfen | Anwen", "Retired target retained a distance or stale reference")
	coordinator.show_guidance(hud, 4.0)
	_check(hud.guidance == "Speak with Sister Anwen", "Contextual guidance was lost when absent from tracker")
	coordinator = null
	fixture.queue_free()
	await process_frame
	await process_frame
	print("QUEST HUD COORDINATOR: %s (tracker, guidance, distance, idle reuse, movement/quest/zone invalidation, retired target)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
