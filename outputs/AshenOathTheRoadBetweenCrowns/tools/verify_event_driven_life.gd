extends SceneTree

const Life = preload("res://scripts/greyfen_life_controller.gd")
const Story = preload("res://scripts/story_state.gd")

class CountingStory extends Story:
	var reads := 0
	func get_flag(id: String, fallback: Variant = null) -> Variant:
		reads += 1
		return super.get_flag(id, fallback)

class Host extends Node3D:
	var player := Node3D.new()
	var story_state := CountingStory.new()
	var game_started := true
	var spatial_service: Node
	var asset_helper: Node
	var quests: Node
	var day_night: Node
	var audio: Node
	var current_zone_id := "greyfen"
	var encounter_spatial_index = preload("res://scripts/actor_spatial_index.gd").new()
	var zone_root := Node3D.new()
	func _ready() -> void:
		add_child(player)
		add_child(story_state)
		add_child(zone_root)
	func river_safe_path(points: Array, _margin: float = 0.9) -> Array:
		return points

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Host.new()
	root.add_child(host)
	var life := Life.new()
	life.set_meta("staged_population", true)
	host.zone_root.add_child(life)
	life.configure(host, "balanced")
	life.set_physics_process(false)
	# Isolate reaction invalidation from independent scene and daily-clock owners.
	life.world_scene_clock = INF
	life.routine_minute = 990
	var initial := host.story_state.reads
	for index in range(12):
		life._physics_process(1.0 / 30.0)
	_check(host.story_state.reads == initial, "Unchanged reaction state was polled again")
	var actor := Node3D.new()
	actor.position = Vector3(100, 0, 0)
	host.zone_root.add_child(actor)
	life.actors.append(life._make_entry("walker_well", actor, [], 1.0, null, false))
	host.story_state.set_flag("evidence_report", "public")
	host.story_state.set_flag("cemetery_bell_rung", true)
	_check(life.story_dirty, "Changed signal did not invalidate the cached reaction")
	_tick(life)
	_check(actor.get_meta("life_story_reaction", "") == "reported_public_bell_rung" and not life.story_dirty, "Coalesced story update did not reach villagers")
	paused = true
	host.story_state.set_flag("evidence_report", "private")
	_tick(life)
	_check(life.story_dirty and actor.get_meta("life_story_reaction", "") == "reported_public_bell_rung", "Paused scene prematurely consumed its reaction")
	paused = false
	_tick(life)
	_check(actor.get_meta("life_story_reaction", "") == "reported_private_bell_rung", "Resumed scene retained stale reactions")
	life.configure(host, "balanced")
	_check(host.story_state.changed.get_connections().size() == 1, "Reconfiguration duplicated story subscriptions")
	host.free()
	await process_frame
	print("EVENT DRIVEN LIFE: %s (reaction invalidation, pause and resubscription; no timing benchmark)" % ("PASS" if failures.is_empty() else "FAIL"))
	call_deferred("quit", 0 if failures.is_empty() else 1)

func _tick(life: Node) -> void:
	for index in range(4):
		life._physics_process(1.0 / 30.0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
