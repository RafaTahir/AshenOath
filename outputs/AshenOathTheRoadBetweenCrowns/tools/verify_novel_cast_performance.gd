extends SceneTree
## Run against imported source with the real C04 and C02 prepared packs present.
## All saved state is in memory. No campaign, zone streaming or save slots are opened.
const Game = preload("res://scripts/game.gd")
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Story = preload("res://scripts/story_state.gd")
const Context = preload("res://scripts/zone_build_context.gd")
const Area = preload("res://scripts/interactable.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Life = preload("res://scripts/greyfen_life_controller.gd")
const RookPerformance = preload("res://scripts/views/novel_rook_performance.gd")
const TOR := &"novel_tor_braced"
const ROOK := &"novel_rook_ribs"
const ROOK_JOKE := "everyday:rook:joke:3841"

class ErrorLog extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

class FlatRoute extends Node3D:
	var zone_root: Node3D
	var story_state: Node
	var audio: Node
	var quests: Node
	var day_night: Node
	func validate_walkable_position(point: Vector3) -> Vector3: return point
	func river_safe_path(points: Array, _margin: float = 0.9) -> Array: return points

var error_log := ErrorLog.new()
var checks := 0
var failures: Array[String] = []
var game: Node3D
var helper: Node
var story: Node
var zone: Node3D
var facade: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.add_logger(error_log)
	# Its normal services are constructed. Keeping Game detached skips its boot scene.
	game = Game.new()
	# Session.start_session normally adopts this service during boot.
	game.add_child(game.zone_residency)
	story = Story.new()
	helper = Helper.new()
	root.add_child(story)
	root.add_child(helper)
	game.story_state = story
	game.asset_helper = helper
	_zone("greyfen")
	var tor := _actor("blacksmith_tor", "blacksmith_tor", "blacksmith_tor")
	var rook := _actor("rook", "rook", "rook_human")
	if not tor.is_empty() and not rook.is_empty():
		_check(_state(tor) == &"" and _state(rook) == &"", "ordinary fresh state")
		_hammer(tor, true)
		_forge(tor)
		story.set_flag(TOR, true)
		_check(_state(tor) == TOR and _state(rook) == &"", "Tor's flag changes only Tor")
		_brace(tor, true)
		var healthy_speed := await _walk(rook, false)
		story.set_flag(ROOK, true)
		_check(_state(rook) == ROOK, "Rook responds on the existing instance")
		var hurt_speed := await _walk(rook, true)
		_check(healthy_speed > 0 and absf(hurt_speed / healthy_speed - 0.68) < 0.015, "injured Rook moves more slowly")
		await _walk(rook, true, true)
		var saved: Dictionary = story.save_state()
		_hammer(tor, false)
		story.set_flag(TOR, false)
		_brace(tor, false)
		_hammer(tor, true)
		story.load_state(saved)
		_brace(tor, true)
		_check(_state(rook) == ROOK, "Rook survives saved-state restoration")
		_check(facade._configure_npc_animation(tor.visual, "blacksmith_tor"), "rehydrating the same Tor succeeds")
		_brace(tor, true)
		for pair: Array in [["forge_helper","blacksmith_tor"],["saga_dain","blacksmith_tor"],["vargan_patrol","rook_human"],["saga_tavin","rook_human"]]:
			var extra := _actor(pair[0], pair[0], pair[1])
			if not extra.is_empty():
				_check(_state(extra) == &"", str(pair[0]) + " is a different person on the same rig")
				_brace(extra, false)
				extra.area.free()
		var anonymous := _actor("", "blacksmith_tor", "blacksmith_tor")
		if not anonymous.is_empty():
			_check(_state(anonymous) == &"", "Tor's anonymous mill escort stays healthy")
			_brace(anonymous, false)
		_zone("lantern_reach")
		var returned_tor: Dictionary = {}
		for row: Array in [["rook","rook","rook_human",ROOK],["blacksmith_tor","blacksmith_tor","blacksmith_tor",TOR],["board_rook","board_rook","rook_human",ROOK],["board_tor","board_tor","blacksmith_tor",TOR],["witness_-3","rook","rook_human",ROOK]]:
			var returned := _actor(row[0],row[1],row[2], true)
			if returned.is_empty(): continue
			_check(_state(returned) == row[3], str(row[0]) + " starts with the saved condition")
			if row[3] == TOR: _brace(returned, true)
			if row[0] == "blacksmith_tor":
				_hammer(returned, false)
				returned_tor = returned
		var restored := _actor("rook", "rook", "rook_human")
		story.load_state({"flags": {}})
		if not returned_tor.is_empty():
			_brace(returned_tor, false)
			_hammer(returned_tor, true)
		if not restored.is_empty():
			_check(_state(restored) == &"", "legacy save clears the condition on a live actor")
			_check(is_equal_approx(await _walk(restored, false), healthy_speed), "uninjured cadence returns")
		await _spring_continuity(saved, healthy_speed, hurt_speed)
	zone.free()
	game.free()
	helper.free()
	story.free()
	await process_frame
	await process_frame
	OS.remove_logger(error_log)
	failures.append_array(error_log.errors)
	print("NOVEL CAST PERFORMANCE ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _spring_continuity(hurt_save: Dictionary, normal_speed: float, injured_speed: float) -> void:
	_zone("hearthward")
	story.load_state(hurt_save)
	var tor := _actor("blacksmith_tor", "blacksmith_tor", "blacksmith_tor")
	var rook := _actor("rook", "rook", "rook_human")
	if tor.is_empty() or rook.is_empty(): return
	_check(_state(rook) == ROOK and _state(tor) == TOR, "Before spring both conditions still apply")
	await _laugh(rook, false)
	story.set_flag("novel_season", "spring")
	_check(_state(rook) == ROOK, "The season label alone does not complete the spring visit")
	story.set_flag("novel_spring_route", "open_road")
	_check(_state(tor) == &"novel_tor_stiff_wrist" and _state(rook) == &"novel_rook_healed", "The spring visit updates both actors in place")
	_brace(tor, false)
	await _laugh(rook, true)
	_check(is_equal_approx(await _walk(rook, false), normal_speed), "After the visit Rook walks his whole route at his normal pace")
	_hammer(tor, false)
	var spring_save: Dictionary = story.save_state()
	_check(spring_save.flags.get(TOR) == true and spring_save.flags.get(ROOK) == true, "Spring preserves both injuries in the saved history")
	rook.driver.set_dialogue_pose(true)
	_check(RookPerformance.try_laugh(rook.driver, ROOK_JOKE, true), "Rook starts a spring reply before rewinding")
	story.load_state(hurt_save)
	_check(rook.driver.current_state != RookPerformance.LAUGH, "Restoring winter cancels an in-flight spring laugh")
	rook.driver.set_dialogue_pose(false)
	_brace(tor, true)
	_check(_state(tor) == TOR and _state(rook) == ROOK, "Restoring the winter save reinstates the earlier performances on live actors")
	_check(is_equal_approx(await _walk(rook, true), injured_speed), "Rook returns to his guarded winter cadence and breather")
	rook.driver.set_life_activity(RookPerformance.REST)
	_check(rook.driver.presentation_state == "life:" + RookPerformance.REST, "Rook is resting before the spring restore")
	spring_save.flags.erase("novel_season")
	story.load_state(spring_save)
	_check(rook.driver.presentation_state != "life:" + RookPerformance.REST, "Restoring spring clears an in-flight winter breather")
	_check(is_equal_approx(await _walk(rook, false), normal_speed), "Restoring spring clears the winter cadence and breather on the same Rook")
	var spring_tor_state := _state(tor)
	_zone("lantern_reach")
	var returned_rook := _actor("board_rook", "board_rook", "rook_human", true)
	var returned_tor := _actor("board_tor", "board_tor", "blacksmith_tor", true)
	if returned_rook.is_empty() or returned_tor.is_empty(): return
	_check(is_equal_approx(await _walk(returned_rook, false), normal_speed), "A late-mounted regional Rook uses the restored spring gait")
	_brace(returned_tor, false)
	_check(_state(returned_tor) == spring_tor_state, "A late-mounted regional Tor uses his restored wrist condition")
	_check(story.get_flag(TOR, false) and story.get_flag(ROOK, false), "Late actor mounting preserves injury history")
	for route: String in ["witness", "mercy", "duty", "ash", "concord"]:
		story.set_flag("novel_spring_route", route)
		_check(_state(returned_rook) == &"novel_rook_healed" and _state(returned_tor) == spring_tor_state,
			"The completed %s spring visit retains both actors' spring performances" % route)
	story.load_state({"flags": {"novel_spring_route": "open_road"}})
	_check(_state(returned_rook) == &"" and _state(returned_tor) == &"", "Spring alone never invents an earlier injury")
	_brace(returned_tor, false)

func _zone(id: String) -> void:
	if is_instance_valid(facade): facade.free()
	if is_instance_valid(zone): zone.free()
	zone = Node3D.new()
	zone.name = id
	root.add_child(zone)
	game.zone_root = zone
	game.current_zone_id = id
	var context := Context.new(game, id)
	facade = context.construction_host()
	_check(is_instance_valid(facade), id + " construction owner exists")

func _actor(owner_id: String, performance_id: String, role: String, presentation_last: bool = false) -> Dictionary:
	var actor: Node3D
	if owner_id.is_empty():
		actor = Node3D.new()
		actor.name = "MillWorkerBody0"
		actor.set_meta("locomotion_owner", "mill_escort")
	else:
		actor = Area.new()
		actor.setup(owner_id, "dialogue", "Speak")
	zone.add_child(actor)
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	if not _check(visual != null and visual.find_child("*",true,false) != null and not str(visual.name).ends_with("_placeholder"), "prepared visual loads: " + role): return {}
	actor.add_child(visual)
	if not presentation_last: Presentation.apply_npc(actor, performance_id, false)
	if not _check(facade._configure_npc_animation(visual, performance_id), "production animation binding: " + performance_id): return {}
	if presentation_last: Presentation.apply_npc(actor, performance_id, false)
	var driver := visual.get_node("CharacterAnimationDriver")
	driver.set_external_tick(true)
	return {"area":actor,"visual":visual,"driver":driver}

func _hammer(actor: Dictionary, expected_visible: bool) -> void:
	var hammer: Node3D = actor.visual.find_child("OccupationProp_blacksmith_tor", true, false)
	if _check(is_instance_valid(hammer), "Tor uses his authored forge hammer"):
		_check(hammer.visible == expected_visible, "%s/%s hammer visibility expected %s, got %s" % [zone.name, actor.area.name, expected_visible, hammer.visible])

func _state(actor: Dictionary) -> StringName:
	return actor.driver.novel_injury

func _brace(actor: Dictionary, attached: bool) -> void:
	var braces: Array = actor.visual.find_children("TorLeftWristBrace", "Node3D", true, false)
	_check(braces.size() == (1 if attached else 0), "exact left wrist brace count")
	if attached and braces.size() == 1:
		var socket: Node = braces[0].get_parent()
		while socket != null and not socket is BoneAttachment3D: socket = socket.get_parent()
		if _check(socket is BoneAttachment3D, "brace has an actual moving bone attachment"):
			_check(socket.get_parent() == actor.driver.skeleton and socket.get_bone_idx() >= 0 and socket.bone_name == &"lowerarm_l", "attachment resolves to Tor's left-side bone on this skeleton")

func _forge(actor: Dictionary) -> void:
	var forge := MeshInstance3D.new()
	forge.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
	var definition: Dictionary = Life.CastProfile.WORKSTATIONS.blacksmith_tor
	forge.name = definition.node
	zone.add_child(forge)
	var world := FlatRoute.new()
	world.zone_root = zone
	root.add_child(world)
	var life := Life.new()
	world.add_child(life)
	life.set_physics_process(false)
	life.host = world
	var path: Array = [forge.to_global(definition.stand)]
	var profile := {"station": definition, "activities": ["forge"], "activity": "forge", "prop": "hammer"}
	life._bind_workstation(profile, path)
	if _check(forge.mesh != null and not profile.workstation.is_empty(), "Tor's routine resolves the authored anvil"):
		var person: Node3D = actor.area
		var driver: Node = actor.driver
		var original := person.transform
		person.global_position = path[0]
		var facing: Vector3 = profile.workstation.look - person.global_position
		facing.y = 0
		person.rotate_y(driver.get_visible_forward().signed_angle_to(facing.normalized(), Vector3.UP))
		var entry: Dictionary = life._make_entry("blacksmith_tor", person, path, 1.0, driver, true)
		entry.profile = profile
		life._begin_activity(entry)
		_check(entry.activity_active and driver.life_clip == &"life/Life_Work", "Tor reserves the anvil and begins his native forge sequence")
		var contacts: Array[String] = []
		var listener := func(event: String, _point: Vector3): contacts.append(event)
		driver.activity_contact.connect(listener)
		var initial_story: Dictionary = story.save_state()
		for phase: String in ["acute", "spring", "uninjured"]:
			var limited := phase != "uninjured"
			story.set_flag(TOR, limited)
			story.set_flag("novel_spring_route", "open_road" if phase == "spring" else "")
			driver.life_modifier.pose_weight = 1.0
			var correct_clip := true
			# One full four-second hammer cycle plus the queued state transition.
			for tick in 440:
				driver.advance_external(0.01)
				driver.life_modifier._process_modification()
				correct_clip = correct_clip and (driver.life_clip == &"life/Life_Work") == (not limited)
			_check(entry.activity_active and driver.presentation_state == "life:forge" and correct_clip,
				"Tor keeps his station and selects the correct %s work clip" % phase)
			_check(contacts.is_empty() if limited else contacts == ["forge_hammer"],
				"Tor only strikes the anvil with an uninjured wrist, phase=%s events=%s" % [phase, contacts])
			contacts.clear()
		driver.activity_contact.disconnect(listener)
		story.load_state(initial_story)
		life._release_activity(entry)
		person.transform = original
	world.free()
	forge.free()

func _walk(actor: Dictionary, injury_expected: bool, interrupt_rest: bool = false) -> float:
	var world := FlatRoute.new()
	var person: Node3D = actor.area
	var driver: Node = actor.driver
	var before := person.global_transform
	world.zone_root = zone
	world.story_state = story
	root.add_child(world)
	var player := CharacterBody3D.new()
	world.add_child(player)
	player.position = Vector3(70, 0, 70)
	var life := Life.new()
	world.add_child(life)
	life.set_physics_process(false)
	life.host = world
	life.player = player
	var facing: Vector3 = driver.get_visible_forward()
	facing.y = 0
	var stop := person.global_position + facing.normalized() * 4.0
	var entry: Dictionary = life._make_entry("rook", person, [person.global_position,stop], 1.2, driver, true)
	entry.pause = 0.0
	entry.profile = {"activity":"idle","activities":["idle","idle"],"activity_seconds":5.0}
	entry.route = [stop]
	entry.route_index = 0
	var max_speed := 0.0
	var rested := false
	var still := true
	var held := 0.0
	var reached := false
	print("ROOK WALK injury=", injury_expected)
	for step in range(260):
		var last := person.global_position
		life._update_actor(entry, 0.05)
		driver.advance_external(0.05)
		max_speed = maxf(max_speed, person.global_position.distance_to(last) / 0.05)
		if driver.presentation_state == "life:rook_catch_breath":
			if not rested: _check(person.global_position.distance_to(stop) < 0.3, "breather occurs at the destination")
			rested = true
			held += 0.05
			if not interrupt_rest and is_equal_approx(held, 1.2):
				await _check_rook_hands(driver)
			still = still and last.distance_to(person.global_position) < 0.005
			if interrupt_rest: break
		if entry.activity_active:
			reached = true
			break
	_check(rested if injury_expected else (reached and not rested), "arrival chooses the appropriate rest")
	if rested:
		_check(still, "breather holds Rook in place")
	if injury_expected and not interrupt_rest:
		_check(reached and absf(held - 2.4) < 0.075, "Rook finishes his short breather and resumes his errand")
	if rested and interrupt_rest:
		var last := person.global_position
		_check(life.Presence.claim(person, "dialogue", get_instance_id()), "conversation takes priority")
		driver.set_dialogue_pose(true)
		life._update_actor(entry, 0.05)
		driver.advance_external(0.05)
		_check(driver.presentation_state != "life:rook_catch_breath" and person.global_position.is_equal_approx(last), "dialogue interrupts the ambient breather")
		driver.set_dialogue_pose(false)
		life.Presence.release(person, "dialogue", get_instance_id())
	driver.clear_life_activity()
	driver.set_working(false)
	driver.set_locomotion(0, Vector3.ZERO, true)
	person.global_transform = before
	world.free()
	print("ROOK WALK speed=", max_speed, " rest_seconds=", held)
	return max_speed

func _laugh(rook: Dictionary, healed: bool) -> void:
	var driver: Node = rook.driver
	driver.set_dialogue_pose(true)
	_check(not RookPerformance.try_laugh(driver, "everyday:rook:chat:3841", true), "Ordinary speech never triggers the rib touch")
	_check(not RookPerformance.try_laugh(driver, ROOK_JOKE, false), "Listening to Kael's joke never triggers the rib touch")
	var started := RookPerformance.try_laugh(driver, ROOK_JOKE, true)
	_check(started == healed, "The brief laugh is available only after Rook's ribs heal")
	if started:
		driver.advance_external(0.60)
		var laughing: Array[Vector4] = await _sample_rook_hands(driver, false)
		_check(laughing.size() >= 3 and laughing.all(_palm_at_ribs), "Rook touches the healed ribs during his laugh")
		for tick in 18: driver.advance_external(0.05)
		_check(driver.current_state != RookPerformance.LAUGH and not driver.has_active_action(), "Rook returns to conversation after laughing")
		var released: Array[Vector4] = await _sample_rook_hands(driver, false)
		_check(released.size() >= 3 and not released.any(_palm_at_ribs), "Rook releases his ribs when the laugh ends")
	driver.set_dialogue_pose(false)

func _palm_at_ribs(span: Vector4) -> bool:
	return span.y > -0.70 and span.y < 0.10 and absf(span.w) < 0.32 and span.z > 0.09 and span.z < 0.65

func _sample_rook_hands(driver: Node, breathing: bool) -> Array[Vector4]:
	var rig: Skeleton3D = driver.skeleton
	var bones: Dictionary = {}
	for bone: String in ["spine_02", "upperarm_l", "upperarm_r", "hand_l", "middle_01_l", "hand_r"]:
		bones[bone] = rig.find_bone(bone)
		if not _check(bones[bone] >= 0, "Rook has the pose probe " + bone): return []
	var samples: Array[Vector4] = []
	# Skeleton3D restores the base pose after its modifiers run. Sample while
	# the final evaluated bones are available, as they are for the skinned mesh.
	var capture := func() -> void:
		if breathing and driver.life_modifier.pose_weight < 0.9: return
		var points: Dictionary = {}
		for bone: String in bones:
			points[bone] = rig.to_global(rig.get_bone_global_pose(bones[bone]).origin)
		var width: Vector3 = (points.upperarm_r - points.upperarm_l).slide(Vector3.UP)
		var side := width.normalized()
		var palm: Vector3 = points.hand_l.lerp(points.middle_01_l, 0.60) - points.spine_02
		var free: Vector3 = points.hand_r - points.spine_02
		samples.append(Vector4(free.y, palm.dot(side), palm.dot(Vector3.UP.cross(side)), palm.y) / width.length())
	rig.skeleton_updated.connect(capture)
	if breathing: driver.life_modifier.pose_weight = 1.0
	for tick in 20:
		driver.advance_external(1.0 / 60.0)
		await process_frame
		if samples.size() >= 5: break
	rig.skeleton_updated.disconnect(capture)
	return samples

func _check_rook_hands(driver: Node) -> void:
	var samples: Array[Vector4] = await _sample_rook_hands(driver, true)
	if not _check(samples.size() >= 3, "Rook's evaluated breath pose was sampled"): return
	print("ROOK HANDS wrist height, palm side/front/height (shoulder spans) ", samples)
	var relaxed := true
	var guarding := true
	for span: Vector4 in samples:
		relaxed = relaxed and span.x < -0.32
		guarding = guarding and _palm_at_ribs(span)
	_check(relaxed, "Rook's free right wrist hangs below his ribs throughout the settled breath")
	_check(guarding, "Rook's left palm stays over the near side of his ribcage")

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("NOVEL CAST: " + label)
	return ok
