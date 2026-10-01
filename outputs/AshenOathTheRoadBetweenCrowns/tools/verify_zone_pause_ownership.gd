extends SceneTree

const Residency = preload("res://scripts/zone_residency_service.gd")
const Enemy = preload("res://scripts/enemy_ai.gd")

class ClockProbe extends Node:
	var ticks := 0
	func _physics_process(_delta: float) -> void:
		ticks += 1

var failures: Array[String] = []

func _initialize() -> void:
	var coordinator := Node3D.new()
	coordinator.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(coordinator)
	var menu_clock := ClockProbe.new()
	coordinator.add_child(menu_clock)
	var residency := Residency.new()
	coordinator.add_child(residency)
	var zone := Node3D.new()
	coordinator.add_child(zone)
	var actor_clock := ClockProbe.new()
	zone.add_child(actor_clock)
	var enemy := Enemy.new()
	zone.add_child(enemy)
	var animation := AnimationPlayer.new()
	enemy.add_child(animation)
	# This is an ownership/system fixture, not real-input or combat acceptance.
	residency._cache_route_zone("greyfen", zone, [], 0, true, false, false)
	await _check_pause(coordinator, zone, actor_clock, menu_clock, enemy, animation, "covered menu cache")
	paused = false
	residency._cache_route_zone("greyfen", zone, [], 0)
	var stopped := actor_clock.ticks
	await _frames(5)
	_check(actor_clock.ticks == stopped, "inactive cached world still ticks")
	zone = residency._activate_cached_zone("greyfen")
	await _check_pause(coordinator, zone, actor_clock, menu_clock, enemy, animation, "reactivated world")
	paused = false
	coordinator.free()
	await process_frame
	print("ZONE PAUSE OWNERSHIP: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _check_pause(coordinator: Node, zone: Node, actor_clock: ClockProbe, menu_clock: ClockProbe, enemy: Node, animation: Node, label: String) -> void:
	paused = false
	var previous := actor_clock.ticks
	await _frames(4)
	_check(actor_clock.ticks > previous, "%s world cannot resume" % label)
	paused = true
	previous = actor_clock.ticks
	var menu_previous := menu_clock.ticks
	await _frames(5)
	_check(actor_clock.ticks == previous, "%s world advances while paused" % label)
	_check(not zone.can_process() and not enemy.can_process() and not animation.can_process(), "%s actor hierarchy ignores pause" % label)
	_check(coordinator.can_process() and menu_clock.ticks > menu_previous, "%s menu coordinator was frozen" % label)

func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
