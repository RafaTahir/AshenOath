extends SceneTree

const Life = preload("res://scripts/greyfen_life_controller.gd")
const Story = preload("res://scripts/story_state.gd")

class CountingStory extends Story:
	var reads := 0
	func get_flag(id: String, fallback: Variant = null) -> Variant:
		reads += 1
		return super.get_flag(id, fallback)

class PolledLife extends Life:
	func _process(delta: float) -> void:
		if host == null or player == null or get_tree().paused or not bool(host.get("game_started")): return
		simulation_tick_accumulator += delta
		if simulation_tick_accumulator < 1.0 / _simulation_hz():
			return
		delta = simulation_tick_accumulator
		simulation_tick_accumulator = 0.0
		line_cooldown = max(line_cooldown - delta, 0.0)
		_sync_story_state(false)
		for entry in actors:
			var actor_node: Node3D = entry.node
			if entry.driver == null and is_instance_valid(actor_node):
				var hydrated_driver = actor_node.find_child("CharacterAnimationDriver", true, false)
				if hydrated_driver != null:
					entry.driver = hydrated_driver
			var render_distance := 8.0 if quality == "potato" else (18.0 if quality == "quality" else 16.0)
			var was_distant := bool(entry.get("distance_suspended", false))
			var distance_limit := render_distance - 0.8 if was_distant else render_distance + 0.8
			var distant := is_instance_valid(actor_node) and actor_node.global_position.distance_to(player.global_position) > distance_limit
			if is_instance_valid(actor_node) and distant != was_distant:
				actor_node.visible = not distant
				var driver = entry.driver
				if driver != null and driver.has_method("set_distance_suspended"):
					driver.set_distance_suspended(distant)
				entry.distance_suspended = distant
			if not distant:
				_update_actor(entry, delta)

class Host extends Node3D:
	var player := Node3D.new()
	var story_state := CountingStory.new()
	var game_started := true
	var spatial_service: Node
	var asset_helper: Node
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
	host.add_child(life)
	life.configure(host, "balanced")
	life.set_process(false)
	var initial := host.story_state.reads
	var started := Time.get_ticks_usec()
	for _index in range(1000):
		life._process(0.125)
	var new_us := Time.get_ticks_usec() - started
	var new_reads := host.story_state.reads - initial
	_check(host.story_state.reads == initial, "Idle simulation still reads unchanged story state")
	var old_script = PolledLife
	if old_script != null:
		var baseline = PolledLife.new()
		baseline.set_meta("staged_population", true)
		host.add_child(baseline)
		baseline.configure(host, "balanced")
		baseline.set_process(false)
		var before_old := host.story_state.reads
		started = Time.get_ticks_usec()
		for _index in range(1000):
			baseline._process(0.125)
		var old_us := Time.get_ticks_usec() - started
		print("ARCH-002 STORY COST: old/new 1000 unchanged ticks us=%d/%d; old reads=%d new reads=%d" % [old_us, new_us, host.story_state.reads - before_old, new_reads])
		_check(host.story_state.reads - before_old == 2000 and new_us < old_us, "Measured story polling cost did not fall")
		baseline.free()
	var actor := Node3D.new()
	actor.position = Vector3(100, 0, 0)
	host.zone_root.add_child(actor)
	var driver := Node.new()
	actor.add_child(driver)
	life.actors.append(life._make_entry("walker_well", actor, [], 1.0, driver, false))
	host.story_state.set_flag("evidence_report", "public")
	host.story_state.set_flag("cemetery_bell_rung", true)
	_check(life.story_dirty, "Changed signal did not invalidate the cached reaction")
	life._process(0.125)
	_check(actor.get_meta("life_story_reaction") == "reported_public_bell_rung" and not life.story_dirty, "Coalesced story update did not reach villagers")
	paused = true
	host.story_state.set_flag("evidence_report", "private")
	life._process(0.125)
	_check(life.story_dirty and actor.get_meta("life_story_reaction") == "reported_public_bell_rung", "Paused scene prematurely consumed its reaction")
	paused = false
	life._process(0.125)
	_check(actor.get_meta("life_story_reaction") == "reported_private_bell_rung", "Resumed scene retained stale reactions")
	life.configure(host, "balanced")
	_check(host.story_state.changed.get_connections().size() == 1, "Reconfiguration duplicated story subscriptions")
	host.queue_free()
	await process_frame
	await process_frame
	print("EVENT DRIVEN LIFE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
