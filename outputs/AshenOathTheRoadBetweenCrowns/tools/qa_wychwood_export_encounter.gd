extends RefCounted

const FOREST := "res://assets_external/environment/forest/"
const ROAD := "main_road_of_crows"
const ANSWER := "wychwood_road_answer"
const SPARED := "wychwood_raider_spared"
const BROKEN := "wychwood_raider_truce_broken"

func inspect_road(q, camera: Camera3D) -> void:
	var objects := {
		"CartersSoundingAxle": FOREST + "Wychwood_CartersAxle.res",
		"OrenCompleteToken": "res://assets_external/environment/village/CarvedCrowToken.res"
	}
	for name: String in objects:
		var mesh := q.game.zone_root.find_child(name, true, false) as MeshInstance3D
		if not _resource(q, mesh, objects[name]): continue
		await _photograph(q, mesh, camera, Vector3(0.25, 0.8, 1.0), name)

func _resource(q, mesh: MeshInstance3D, path: String) -> bool:
	var valid := is_instance_valid(mesh) and mesh.mesh is ArrayMesh and mesh.mesh.resource_path == path and mesh.is_visible_in_tree()
	q._check(valid, "Visible in-level ArrayMesh required: " + path)
	return valid

func _photograph(q, mesh: MeshInstance3D, camera: Camera3D, view: Vector3, label: String) -> void:
	var bounds := mesh.get_aabb()
	var center := mesh.global_transform * bounds.get_center()
	var size := mesh.global_basis * Vector3(bounds.size.x, 0, 0)
	var diameter := maxf(size.length(), maxf((mesh.global_basis.y * bounds.size.y).length(), (mesh.global_basis.z * bounds.size.z).length()))
	var distance := clampf(diameter * 1.7, 0.26, 3.7)
	var old_near := camera.near
	camera.near = 0.02
	camera.global_position = center + view.normalized() * distance
	camera.look_at(center)
	camera.make_current()
	await q._steps(2)
	q._check(camera.is_position_in_frustum(center), "Evidence not framed in clearing: " + label)
	await q._capture(label + "_inspection_camera")
	mesh.visible = false
	await q._capture(label + "_control_inspection_camera")
	mesh.visible = true
	camera.near = old_near

func inspect_tally(q, actor: Node3D, camera: Camera3D) -> void:
	var socket := actor.find_child("CartersWristCord", true, false) as BoneAttachment3D
	var mesh := actor.find_child("NotchedRoadTally", true, false) as MeshInstance3D
	if not _resource(q, mesh, FOREST + "Wychwood_RaiderTally.res"): return
	var rig := socket.get_parent() as Skeleton3D if is_instance_valid(socket) else null
	if rig == null or mesh.get_parent() != socket or socket.bone_name != &"hand_l":
		q._fail("Raider's notched tally is not attached to native hand_l")
		return
	var driver: Node = actor.animation_driver
	var player: AnimationPlayer = driver.get_animation_player()
	var hand := rig.find_bone("hand_l")
	var head := rig.find_bone("Head")
	if hand < 0 or head < 0 or player == null:
		q._fail("Required Raider skeleton landmarks or native animation player missing")
		return
	var old_clip := player.current_animation
	var old_time := player.current_animation_position if player.is_playing() else 0.0
	var old_active := player.active
	var tree: AnimationTree = driver.animation_graph.tree
	var old_graph_active := tree.active
	tree.active = false
	player.active = true
	var hand_points: Array[Vector3] = []
	var samples: Array[Dictionary] = []
	for state: String in ["idle", "attack"]:
		var clip: StringName = driver.get_clip_for_state(state)
		if not player.has_animation(clip):
			q._fail("Raider native clip missing: " + state)
			return
		var time := player.get_animation(clip).length * (0.25 if state == "idle" else 0.62)
		player.play(clip, 0.0)
		player.seek(time, true)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		socket.on_skeleton_update()
		var wrist := rig.global_transform * rig.get_bone_global_pose(hand).origin
		var head_position := rig.global_transform * rig.get_bone_global_pose(head).origin
		var marker := mesh.global_transform * mesh.get_aabb().get_center()
		var binding_error := wrist.distance_to(socket.global_position)
		var wrist_distance := marker.distance_to(wrist)
		var head_distance := marker.distance_to(head_position)
		q._check(binding_error < 0.012 and wrist_distance < head_distance, "Wrist tally detached during " + str(clip))
		hand_points.append(wrist)
		samples.append({"clip":str(clip), "time":time, "socket_error_m":binding_error, "wrist_to_tally_m":wrist_distance, "head_to_tally_m":head_distance})
		if state == "idle":
			var outward := marker - actor.global_position
			outward.y = 0.0
			await _photograph(q, mesh, camera, outward.normalized() - actor.global_basis.z * 0.65 + Vector3.UP * 0.23, "RaiderWristTally")
	q._check(hand_points[0].distance_to(hand_points[1]) > 0.001, "Native Idle/Attack did not produce distinct live wrist poses")
	q.report["raider_tally"] = {"native_samples":samples, "wrist_pose_displacement_m":hand_points[0].distance_to(hand_points[1]), "mesh":mesh.mesh.resource_path}
	player.stop()
	if not old_clip.is_empty():
		player.play(old_clip)
		player.seek(old_time, true)
	player.active = old_active
	tree.active = old_graph_active

func _wave(game, wave: int) -> Node3D:
	for enemy: Node3D in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.dead and int(enemy.get_meta("wychwood_wave", -1)) == wave:
			return enemy
	return null

func _area(game, id: String) -> Area3D:
	for entry: Area3D in game.zone_root.find_children("*", "Area3D", true, false):
		if entry.has_method("get_context_prompt") and str(entry.interaction_id) == id:
			return entry
	return null

func _place(q, target: Vector3, offset: Vector3) -> void:
	q.game.player.global_position = target + offset
	q.game.player.velocity = Vector3.ZERO
	q.game.player.reset_physics_interpolation()
	q.game.player.face_target(target)
	q.game.camera_rig.yaw = q.game.player.rotation.y
	q.game.camera_rig.reset_follow()
	q.game.camera_rig._update_view(0.0)

func _focus(q, target: Area3D) -> bool:
	for offset: Vector3 in [Vector3(0,0.05,1.1), Vector3(0.86,0.05,0.65), Vector3(-0.9,0.05,0.6), Vector3(0,0.05,-1.1)]:
		_place(q, target.global_position, offset)
		var focused: bool = await q._wait(func() -> bool:
			q.game.get_system("interaction")._update_interaction_focus()
			return q.game.active_interactable == target, 440)
		if focused: return true
	return false

func _press(q, action: String) -> void:
	await q._gameplay_input(action, true)
	await q._steps(2)
	await q._gameplay_input(action, false)

func _visible_button(q, label: String) -> Button:
	for button: Button in q.root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled and button.text == label:
			return button
	return null

func _dialogue_action(q, kind: String, answer := "") -> bool:
	for i in 10:
		await q.process_frame
		for row: Dictionary in q.game.hud.dialogue_session_data.get("actions", []):
			if row.get("type") != kind or (not answer.is_empty() and row.get("answer") != answer): continue
			var choice := _visible_button(q, str(row.get("label", "")))
			if choice != null:
				await q._activate_button(choice, "road_" + (kind if answer.is_empty() else answer))
				return true
		var next := _visible_button(q, "Continue")
		if next != null: await q._activate_button(next, "road_dialogue_continue")
	return false

func _approach_raider(q, raider: Node3D) -> void:
	_place(q, raider.global_position, -raider.global_basis.z.normalized() * 1.05 + Vector3.UP * 0.06)
	await q._steps(4)

func _inspect_wave(q, actor: Node3D, n: int, receipt: Dictionary) -> void:
	var nav = actor.enemy_navigation_view
	if n == 0:
		# Control sight and hearing cooldown to isolate the auditory stimulus.
		var old_sight: bool = actor.can_see_player
		actor.can_see_player = false
		actor.heard_cue_deadline = 0
		var foot: Vector3 = actor.global_position + Vector3(0.74,0,0)
		nav.hear_ghoulkin_footfall(foot)
		receipt["ghoul_heard_position"] = actor.ambient_state == "investigating" and actor.ambient_target.is_equal_approx(foot) and not actor.can_see_player
		q._check(receipt.ghoul_heard_position, "Mounted Ghoulkin failed native footfall investigation")
		actor.can_see_player = old_sight
	if n == 2:
		var old_position: Vector3 = q.game.player.global_position
		var old_yaw: float = q.game.player.rotation.y
		var old_sight: bool = actor.can_see_player
		_place(q, actor.global_position, Vector3(0,0,3.6))
		actor.can_see_player = true
		nav._observe_stalker(0.03, 3.6)
		var circling: bool = nav._stalker_circling
		nav._observe_stalker(1.2, 3.6)
		receipt["stalker_watched_then_committed"] = circling and not nav._stalker_circling
		q._check(receipt.stalker_watched_then_committed, "Mounted Stalker's watched opening did not release")
		actor.can_see_player = old_sight
		q.game.player.global_position = old_position
		q.game.player.rotation.y = old_yaw

func run(q) -> void:
	var game = q.game
	var answer := "silence" if q.touch else "open_hand"
	var receipt := {"answer":answer, "fixture":"accepted Wychwood destination; quest entry and Oren clue seeded; first three waves take scripted damage through native health owner; character placed near actual interaction and combat targets", "source_fallback":false}
	q.report["road_encounter"] = receipt
	if not game.quests.is_active(ROAD):
		game.quests.unlocked[ROAD] = true
		game.quests.start_quest(ROAD)
	if not game.quests.is_active(ROAD):
		q._fail("Unable to stage active Road of Crows fixture")
		return
	game.story_state.set_flag("road_evidence_oren", true)
	var sign := _area(game, "wychwood_axle_ring")
	if sign == null or not await _focus(q, sign):
		q._fail("Axle ring not found through normal interaction targeting")
		return
	await _press(q, "interact")
	if not await _dialogue_action(q, "wychwood_road_reply", answer):
		q._fail("Axle dialogue did not expose the authored " + answer + " choice")
		return
	if not await _dialogue_action(q, "close"):
		q._fail("Answered axle dialogue did not return control")
		return
	receipt["road_call_gui"] = str(game.story_state.get_flag(ANSWER, "")) == answer and game.story_state.has_evidence("wychwood_road_signal")
	q._check(receipt.road_call_gui, "Axle GUI reply did not save linked road evidence")
	game.wychwood_encounter_started = true
	game.get_system("combat")._ensure_wychwood_wave()
	for n in 3:
		var actor := _wave(game, n)
		if actor == null or not actor.encounter_active:
			q._fail("Expected active mounted Wychwood wave " + str(n))
			return
		_inspect_wave(q, actor, n, receipt)
		actor.apply_damage(actor.health_component.max_health * 2.0, "light")
		await q._steps(4)
	var raider := _wave(game, 3)
	if raider == null or game.wychwood_pack_kills != 3 or not raider.encounter_active:
		q._fail("Real opening wave advancement did not produce the Raider")
		return
	await _approach_raider(q, raider)
	if q.touch:
		var hp: float = raider.health_component.health
		await _press(q, "light_attack")
		if not await q._wait(func() -> bool: return raider.health_component.health < hp, 3500):
			q._fail("Touch combat strike failed to hit the actual Raider")
			return
		receipt["touch_strike_damage"] = hp - raider.health_component.health
		q._check(bool(game.story_state.get_flag(BROKEN, false)), "Touch contact did not close the Raider truce")
		# Only the opening hit is input-driven; conclude the hostile branch
		# through its actual health/death owner to exercise wave persistence.
		raider.apply_damage(raider.health_component.max_health * 2.0, "light")
	else:
		await _press(q, "weapon_sheath")
		var ready: bool = await q._wait(func() -> bool: return raider.surrender_offer and game.player.sword_sheathed and not game.player.equipment_loadout.is_transitioning(), 7000)
		var palm := _area(game, "everyday:road_call")
		if not ready or palm == null or not await _focus(q, palm):
			q._fail("Sheathed player could not focus the active Raider's waiting hand")
			return
		await _press(q, "interact")
		q._check(raider.resolved_nonlethal and not raider.dead and raider.is_visible_in_tree() and not raider.encounter_active, "Physical road answer did not leave the living Raider in peace")
		q._check(game.story_state.has_evidence("creature:wychwood_raider"), "Peace did not record the Raider as observed in the bestiary")
	if not await q._wait(func() -> bool: return game.wychwood_pack_kills == 4, 4000):
		q._fail("Raider encounter did not hand off to the Brute")
		return
	var brute := _wave(game, 4)
	if brute == null or not brute.encounter_active:
		q._fail("Brute failed to enter the final opening wave")
		return
	# Probe the genuine opening windup against a lateral target displacement.
	# Start a native swing without resolving its impact or granting rewards.
	var player_position: Vector3 = game.player.global_position
	if not brute.enemy_strike_view._begin_attack():
		q._fail("Mounted Brute could not start its native windup")
		return
	var start_yaw := brute.rotation.y
	game.player.global_position = brute.global_position + brute.global_basis.x * 1.4
	brute.enemy_strike_view._tick_pending_attack(0.05)
	receipt["brute_planted_windup"] = is_equal_approx(brute.rotation.y, start_yaw) and brute.pending_attack_time > 0.0
	q._check(receipt.brute_planted_windup, "Mounted Brute turned during planted windup")
	brute._cancel_pending_strike()
	game.player.global_position = player_position
	var old_root: int = game.zone_root.get_instance_id()
	if not game.save_manager.save_game(game) or not game.save_manager.load_game(game):
		q._fail("Isolated road-branch save or reload request failed")
		return
	var loaded: bool = await q._wait(func() -> bool: return q._playable("wychwood") and not game.save_manager.is_load_pending() and is_instance_valid(game.zone_root) and game.zone_root.get_instance_id() != old_root, 100000)
	var reloaded_brute := _wave(game, 4) if loaded else null
	receipt["after_reload"] = {"new_world":loaded, "wave":game.wychwood_pack_kills, "answer":game.story_state.get_flag(ANSWER, ""), "spared":game.story_state.get_flag(SPARED, false), "truce_broken":game.story_state.get_flag(BROKEN, false), "brute_active":is_instance_valid(reloaded_brute) and reloaded_brute.encounter_active, "raider_present":is_instance_valid(_wave(game, 3)) if loaded else false}
	var saved: Dictionary = receipt.after_reload
	q._check(saved.new_world and saved.wave == 4 and saved.answer == answer and saved.spared == (not q.touch) and saved.truce_broken == q.touch and saved.brute_active and not saved.raider_present, "Road answer or encounter ownership did not survive real journey reload")
