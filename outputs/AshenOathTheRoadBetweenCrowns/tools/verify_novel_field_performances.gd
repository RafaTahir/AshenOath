extends "res://tools/verify_novel_cast_performance.gd"
## Run with the prepared native cast on disk. All story flags and stations
## are disposable. Set FIELD_EVIDENCE to an existing directory for a JSON receipt.
const Fields = preload("res://scripts/views/novel/field_performances.gd")
const Profiles = preload("res://scripts/story_cast_profile.gd")
const Presence = preload("res://scripts/character_presence.gd")
const ArmIK = preload("res://scripts/views/character_arm_ik.gd")
const HAND_BONES := {"LeftHand": "hand_l", "RightHand": "hand_r"}

class Pawn extends CharacterBody3D:
	var animation_driver: Node

	func read_presentation_tag(node: Node, key: StringName, fallback: Variant = null) -> Variant:
		return node.get_meta(key, fallback)

	func write_presentation_tag(node: Node, key: StringName, value: Variant) -> void:
		node.set_meta(key, value)

class Quests extends Node:
	func is_completed(_id: String) -> bool:
		return false

class Packs extends Node:
	var requested: Array[String] = []

	func actor_pack(role: String) -> String:
		return "actor_c10" if role == "castle_guard_human" else "monsters"

	func get_pack(id: String) -> Dictionary:
		return {"contents": ["res://synthetic-patrol.scn"]} if id == "actor_c10" else {}

	func request_pack(id: String, _priority: int) -> bool:
		requested.append(id)
		return true

class Services extends Node:
	var zone_root: Node3D
	var player: Pawn
	var story_state: Node
	var asset_helper: Node
	var construction: Node
	var quests := Quests.new()
	var runtime_packs := Packs.new()
	var zone_transition_pending := false
	var danger := false

	func _story_has_active_combat() -> bool:
		return danger

	func _configure_npc_animation(visual: Node3D, id: String) -> bool:
		return construction._configure_npc_animation(visual, id)

	func river_safe_position(point: Vector3, _margin: float) -> Vector3:
		return point

class StageLayer extends Node:
	var game: Services
	var owner_director: Node
	var zone := ""
	var turns := {}
	var stations := {}
	var pending := {}
	var elapsed := 0.0

	func _book(act: int) -> Array:
		var path := "res://data/novel/act_%d.json" % act
		var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		return book.scenes

var services := Services.new()
var layer: StageLayer
var field: Node
var observations: Array[Dictionary] = []
var contacts: Array[Dictionary] = []

func _run() -> void:
	OS.add_logger(error_log)
	game = Game.new()
	game.add_child(game.zone_residency)
	story = Story.new()
	helper = Helper.new()
	root.add_child(story)
	root.add_child(helper)
	game.story_state = story
	game.asset_helper = helper
	root.add_child(services)
	services.add_child(services.quests)
	services.add_child(services.runtime_packs)
	services.story_state = story
	services.asset_helper = helper
	services.player = Pawn.new()
	root.add_child(services.player)
	_check_pack_requests()
	story.set_flag("novel_edition", 1)
	if _add_kael():
		await _willow()
		await _gallery()
		await _culvert()
	if is_instance_valid(zone):
		zone.free()
	services.player.free()
	services.free()
	game.free()
	helper.free()
	story.free()
	await _settle(2)
	OS.remove_logger(error_log)
	failures.append_array(error_log.errors)
	var summary := {"checks": checks, "failures": failures, "states": observations, "contacts": contacts}
	var output := OS.get_environment("FIELD_EVIDENCE")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("field-runtime.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(summary, "  "))
			file.close()
		else:
			failures.append("Cannot write field fixture receipt in " + output)
	print("NOVEL FIELD PERFORMANCES ", JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)

func _check_pack_requests() -> void:
	var requested := {}
	for attempt in range(3):
		Fields.Artist.request_missing_actor(services, "castle_guard_human", "res://synthetic-patrol.scn", requested)
	Fields.Artist.request_missing_actor(services, "unknown_role", "res://unknown.scn", requested)
	_check(services.runtime_packs.requested == ["actor_c10"], "Repeated scans request only the manifest owner")

func _add_kael() -> bool:
	var visual: Node3D = helper.spawn_visual_role("player_human", "characters")
	if not _check(visual != null, "Kael's prepared visual is available"):
		return false
	services.player.add_child(visual)
	var setup_actor := preload("res://scripts/player_controller.gd").new()
	var body_view := preload("res://scripts/views/player_character_view.gd").new(setup_actor)
	var driver := preload("res://scripts/character_animation_driver.gd").new()
	visual.add_child(driver)
	driver.forward_only_locomotion = true
	var ready := _check(driver.configure(visual, body_view._animation_map_for_visual(visual)), "Kael uses the native player animation map")
	Presentation.apply_player(services.player, visual)
	services.player.animation_driver = driver
	setup_actor.free()
	return ready

func _stage_region(region: String) -> void:
	_zone(region)
	services.zone_root = zone
	services.construction = facade
	var director := Node.new()
	zone.add_child(director)
	layer = StageLayer.new()
	layer.game = services
	layer.owner_director = director
	layer.zone = region
	director.add_child(layer)
	services.player.position = Vector3(0.1, 0, 5.5)

func _stage_beat(key: String, index: int, origin: Vector3 = Vector3.ZERO) -> void:
	var station := Node3D.new()
	station.name = "novel_%s_%d" % [key, index]
	zone.add_child(station)
	station.global_position = origin
	var work := Node3D.new()
	work.name = "Workpiece"
	station.add_child(work)
	layer.stations[str(station.name)] = station
	layer.turns.clear()
	layer.turns[key] = {"index": index, "beat": {"seconds": 2.0}}
	layer.pending.clear()
	layer.elapsed = 0.0
	story.set_flag("novel_step_" + key, index)
	_refresh_field()

func _refresh_field() -> void:
	Fields.project(layer)
	field = layer.get_node_or_null("FieldPerformances")
	if field != null:
		field._physics_process(0.25)
		field.set_physics_process(false)

func _settle(count: int = 3) -> void:
	for frame in count:
		await process_frame

func _observe_state(label: String, expected: Array) -> bool:
	await _settle(4)
	var people := {}
	if is_instance_valid(field):
		for id: String in field.leases:
			var lease = field.leases[id]
			if is_instance_valid(lease.actor):
				people[id] = {
					"role": lease.mark.role, "pose": lease.mark.pose,
					"bones": lease.driver.skeleton.get_bone_count(),
					"injury": str(lease.driver.novel_injury), "temporary": lease.temporary,
				}
	observations.append({"name": label, "people": people})
	return _check(people.size() == expected.size() and people.has_all(expected), label + " has the expected participants")

func _give_frame() -> Node3D:
	var frame := Node3D.new()
	frame.name = "NovelBurden"
	frame.add_to_group("novel_burden_frame")
	services.player.add_child(frame)
	var original := Node3D.new()
	original.name = "Original"
	frame.add_child(original)
	return frame

func _check_grip(actor: String, rig: Skeleton3D, markers: Marker3D) -> void:
	for side: String in HAND_BONES:
		var marker := markers.get_node_or_null(NodePath(side)) as Marker3D
		if marker == null:
			continue
		var wrist := ArmIK.world(rig, rig.find_bone(HAND_BONES[side]))
		var gap := wrist.distance_to(marker.global_position)
		contacts.append({"frame": field.carry_key, "actor": actor, "marker": side, "distance_m": gap})
		_check(gap < 0.03, "%s reaches %s on the %s frame" % [actor, side, field.carry_key])

func _check_carry(rear_id: String) -> void:
	var front = field.front_pose
	if not _check(is_instance_valid(front) and front.mark.has_node("LeftHand"), "Kael has a front grip"):
		return
	_check(front.mark.has_node("RightHand") == (field.carry_key == "culvert"), "Kael supports Oren on his shoulder and takes the coat litter in both hands")
	front._process_modification()
	_check_grip("Kael", front.get_skeleton(), front.mark)
	var rear = field.leases[rear_id]
	_check(rear.mark.has_node("LeftHand") and rear.mark.has_node("RightHand"), "The rear bearer has two handholds")
	rear.follow_bearer(services.player.global_position.y, 0.016)
	rear.pose._process_modification()
	_check_grip(rear_id, rear.driver.skeleton, rear.mark)

func _willow() -> void:
	_stage_region("wychwood")
	var person := _actor("mira", "mira", "mira_human")
	if person.is_empty():
		return
	var mira: Node3D = person.area
	mira.position = Vector3(5, 0.1, 2.1)
	Profiles.register_actor(zone, mira, "mira")
	var original := mira.transform
	_stage_beat("willow_frame", 0)
	if not await _observe_state("Oren line", ["mira"]):
		return
	var lease = field.leases.mira
	_check(lease.actor == mira and not lease.temporary, "Mira uses the resident")
	_refresh_field()
	_check(field.leases.mira == lease, "Repeated refresh retains Mira's claim")
	_check(Presence.claim(mira, "dialogue", 9020), "Dialogue preempts the field performance")
	field._reconcile_people()
	_check(not is_instance_valid(lease.pose) and lease.interrupted, "Mira yields the field pose for dialogue")
	Presence.release(mira, "dialogue", 9020)
	_refresh_field()
	_stage_beat("willow_frame", 1)
	await _observe_state("Oren recovery", ["mira"])
	layer.pending = {"key": "willow_frame", "index": 1}
	layer.elapsed = 1.0
	field._physics_process(0.1)
	_check(is_equal_approx(field.work_position, 0.5), "Lift follows the action owner's clock")
	layer.pending.clear()
	field._physics_process(0.1)
	_check(is_zero_approx(field.work_position), "Cancellation resets the lift")
	var frame := _give_frame()
	_stage_beat("willow_frame", 2)
	if await _observe_state("Oren carried", ["mira"]):
		_check(field.carry != null and not frame.get_node("Original").visible and field.leases.mira.actor == mira,
			"A group-only frame carries Oren and keeps one Mira")
		_check_carry("mira")
		var start: Vector3 = field.carry.global_position
		services.player.position.x += 2.0
		field._physics_process(0.1)
		_check(absf(field.carry.global_position.x - start.x - 2.0) < 0.03, "Frame follows Kael")
		layer.pending = {"key": "willow_frame", "index": 2}
		layer.elapsed = 1.95
		field._physics_process(0.1)
		_check(absf(mira.global_position.y - services.player.position.y) < 0.03, "Rear bearer's feet stay grounded during lowering")
		frame.remove_from_group("novel_burden_frame")
		frame.add_to_group("novel_burden_load")
		_refresh_field()
		_check(field.carry == null and frame.get_node("Original").visible, "Ordinary loads keep their own visual")
		frame.remove_from_group("novel_burden_load")
		frame.set_meta("kind", "frame")
		_refresh_field()
		_check(is_instance_valid(field.carry), "A legacy frame can reconstruct its carrying scene")
	layer.pending.clear()
	layer.turns.clear()
	story.set_flag("novel_step_willow_frame", 5)
	frame.free()
	_refresh_field()
	await _settle()
	_check(mira.transform.is_equal_approx(original) and not mira.has_meta("cast_work_owner"), "Mira's transform and claim are restored")

func _gallery() -> void:
	_stage_region("old_mill")
	_stage_beat("tor_wrist", 0)
	if not await _observe_state("Gallery before shoring", ["blacksmith_tor", "wheelkeeper"]):
		return
	var tor_mark: Marker3D = field.leases.blacksmith_tor.mark
	services.danger = true
	field._reconcile_people()
	await _settle()
	_check(field.leases.is_empty(), "Combat releases the mill performers")
	services.danger = false
	services.player.global_position = tor_mark.global_position
	field._reconcile_people()
	_check(not field.leases.has("blacksmith_tor"), "Player footprint defers Tor")
	services.player.position = Vector3(0, 0, 5)
	field._reconcile_people()
	_check(field.leases.has("blacksmith_tor"), "Tor appears once the footprint clears")
	_stage_beat("tor_wrist", 1)
	await _observe_state("Tor on bench", ["blacksmith_tor", "mira"])
	story.set_flag("novel_tor_braced", true)
	_stage_beat("tor_wrist", 2)
	if await _observe_state("Tor directs Nera", ["blacksmith_tor", "saga_nera"]):
		var tor = field.leases.blacksmith_tor.driver
		_check(tor.novel_injury == TOR and tor.skeleton.find_children("TorLeftWristBrace", "Node3D", true, false).size() == 1,
			"Tor wears exactly one approved left wrist brace")
	layer.turns.clear()
	_refresh_field()
	await _settle()
	_check(field.leases.is_empty() and field.get_child_count() == 0, "Mill scene releases the temporary actors")

func _culvert() -> void:
	_stage_region("marsh_crossing")
	_stage_beat("culvert", 1)
	if await _observe_state("Culvert casualties", ["patrolman", "saga_nera", "rook"]):
		_check(field.leases.rook.driver.skeleton != field.leases.patrolman.driver.skeleton, "Rook and the patrolman use distinct rigs")
	story.set_flag("novel_rook_ribs", true)
	_stage_beat("culvert", 2)
	if await _observe_state("Rook on litter", ["patrolman", "mira", "rook"]):
		_check(field.leases.rook.driver.novel_injury == ROOK, "Rook uses the saved injury")
	_stage_region("vargan_approach")
	var frame := _give_frame()
	_stage_beat("culvert", 3, Vector3(-3.3, 0, 9))
	if await _observe_state("Arrival", ["rook", "widow_elna", "mira", "saga_nera"]):
		_check_carry("widow_elna")
		_check(field.carry.is_ancestor_of(field.leases.rook.mark), "Rook arrives on the moving litter")
	frame.free()
	story.set_flag("novel_step_culvert", 4)
	layer.turns.clear()
	_refresh_field()
	if await _observe_state("Rook on the cot", ["rook", "mira", "saga_nera"]):
		_check(field.carry == null and field.ground.is_ancestor_of(field.leases.rook.mark), "The casualty transfers from the litter to the cot")
	# Simulate a re-entry after set-down; the previous physical station is gone.
	_stage_region("vargan_approach")
	_refresh_field()
	if await _observe_state("Guarded room", ["rook", "mira", "saga_nera"]):
		_check(field.ground_index == 4 and field.ground.is_ancestor_of(field.leases.rook.mark), "Rook occupies the cot after re-entry")
		_check(field.ground.global_position.is_equal_approx(Vector3(-3.3, 0, 9)), "The washroom uses the authored arrival site")
	story.set_flag("novel_done_counterpart", true)
	_refresh_field()
	await _settle()
	_check(field.leases.is_empty() and not field.is_physics_processing(), "The resolved washroom releases everyone")
