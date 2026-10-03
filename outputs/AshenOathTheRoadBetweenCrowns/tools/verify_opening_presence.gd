extends SceneTree

const Life = preload("res://scripts/greyfen_life_controller.gd")
const Story = preload("res://scripts/story_state.gd")
var failures: Array[String] = []

class Host extends Node:
	var story_state: Node

class Driver extends Node:
	var working := false
	var talking := false
	func set_working(value: bool) -> void: working = value
	func set_dialogue_pose(value: bool) -> void: talking = value
	func set_locomotion(_speed: float, _direction: Vector3, _grounded: bool) -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.story_state = Story.new()
	host.add_child(host.story_state)
	var life := Life.new()
	host.add_child(life)
	life.set_process(false)
	life.host = host
	life.player = Node3D.new()
	host.add_child(life.player)
	life.player.position = Vector3(10, 0, 0)
	var paths := [Vector3(-4, 0, 2), Vector3(-3, 0, 3)]
	for id in ["walker_well", "walker_board", "shrine_pilgrim", "forge_helper", "blacksmith_tor"]:
		var actor := Node3D.new()
		host.add_child(actor)
		var driver := Driver.new()
		actor.add_child(driver)
		life.actors.append(life._make_entry(id, actor, paths.duplicate(), 0.8, driver, id == "blacksmith_tor"))
	life._sync_story_state(true)
	_check("Sella" in life._line_for_actor(life.actors[0]), "Well keeper lost Sella's personal detail")
	_check("Bram" in life._line_for_actor(life.actors[1]), "Board reader lost Bram's personal detail")
	_check("Oren" in life._line_for_actor(life.actors[2]), "Pilgrim lost Oren's personal detail")
	for method in ["public", "private", "retained", ""]:
		host.story_state.set_flag("evidence_report", method)
		life._sync_story_state(true)
		var saved: Dictionary = host.story_state.save_state()
		host.story_state.load_state(saved)
		life._sync_story_state(true)
		for entry in life.actors:
			_check(entry.path == paths, "Report moved an authored routine")
			var original: Dictionary = life.ROUTINE_PROFILES[entry.id]
			_check(is_equal_approx(entry.profile.activity_seconds, original.activity_seconds * (1.0 if method == "" else 1.8)), "Repeated load compounds routine duration")
			life._set_activity_pose(entry, true)
			if method == "public" and entry.id in ["forge_helper", "blacksmith_tor"]:
				_check(entry.driver.talking and not entry.driver.working, "Public report did not interrupt forge work")
				life._set_motion(entry, 0.0)
				_check(not entry.driver.working, "Idle motion restarted forge work during the public aftermath")
			if method == "private" and entry.id == "shrine_pilgrim":
				_check(entry.driver.talking and not entry.driver.working, "Private report did not change shrine attention")
			if method != "":
				_check(life._line_for_actor(entry) in life.POST_REPORT_LINES[method], "Report line disagrees with saved consequence")
			life._set_activity_pose(entry, false)
			_check(not entry.driver.talking and not entry.driver.working, "Activity left a stuck pose")
	var actor: Node3D = life.actors[0].node
	actor.set_meta("dialogue_facing_lock", true)
	var position := actor.position
	life._update_actor(life.actors[0], 0.25)
	_check(actor.position == position, "Dialogue lock did not stop routine movement")
	var helper: Dictionary = life.actors[3]
	life._set_motion(helper, 0.0)
	_check(helper.driver.working, "Normal forge work was lost")
	life.player.position = helper.node.position + Vector3(1, 0, 0)
	life._set_motion(helper, 0.0)
	_check(not helper.driver.working, "Forge helper kept hammering while addressing Kael")
	host.free()
	life = null
	print("OPENING PRESENCE: %s (personal lines, three report outcomes, saved state, route preservation, dialogue ownership)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
