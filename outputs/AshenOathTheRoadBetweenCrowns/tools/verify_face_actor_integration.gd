extends "res://tools/verify_face_terminal_state.gd"

## Model-backed companion to the resource-free terminal-state fixture.
## Reuses its transient-state assertions, never its synthetic actor/motion rig.
## Enemy.setup and Player._ready select the current prepared runtime actors.
## No world, save manager, authored resources or user files are changed.
const Enemy = preload("res://scripts/enemy_ai.gd")
const Player = preload("res://scripts/player_controller.gd")

var checks := 0
var model_cases := 0
var eligible_face_cases := 0
var camera: Camera3D
var attention_target: Node3D

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.3, 5)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
	attention_target = Node3D.new()
	root.add_child(attention_target)
	attention_target.position = Vector3(1, 0, 3)
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	_check(definitions is Dictionary, "Actual enemy definitions could not be read")
	if definitions is Dictionary:
		for role: String in ["bandit", "wychwood_raider"]:
			_check(definitions.get(role) is Dictionary, "Missing actual enemy definition: " + role)
			if definitions.get(role) is Dictionary:
				await _enemy_case(role, definitions[role])
	await _cached_player_case()
	attention_target.free()
	camera.free()
	await _settle(2)
	for failure: String in failures:
		printerr("FACE ACTOR INTEGRATION: " + failure)
	print("FACE ACTOR INTEGRATION: %s checks=%d models=%d eligible_faces=%d (world bandit eligibility control, native raider, cached player; 1280x720 and 960x540; no world/save)" % ["PASS" if failures.is_empty() else "FAIL", checks, model_cases, eligible_face_cases])
	quit(0 if failures.is_empty() else 1)

func _enemy_case(role: String, definition: Dictionary) -> void:
	var actor := Enemy.new()
	actor.name = "FaceFixture_" + role
	# Match the actual bandit-road owner before Enemy.setup selects its visual.
	# bandit_road_section.gd passes this role through ZoneBuildContext.spawn_enemy
	# and ZoneConstructionHost._spawn_enemy; the generic bandit alias is distinct.
	if role == "bandit":
		actor.visual_role_override = "bandit_deserter"
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.setup(role, definition, attention_target)
	var motion: Node = actor.animation_driver
	var face: Node = actor.find_child("CharacterFaceDriver", true, false)
	# The current bandit-road M04 derivative has an imported head but no
	# eligible facial surfaces for role "bandit". Do not manufacture a living
	# face or require a presentation contract the real owner never enables.
	if role == "bandit" and face != null and not face.valid:
		await _ineligible_bandit_case(actor, motion, face)
		await _retire(actor)
		return
	if not _actor_contract(actor, motion, face, role):
		await _retire(actor)
		return
	model_cases += 1
	eligible_face_cases += 1
	motion.set_external_tick(true)
	face.set_conversation_active(true)
	_check(face.head_modifier.active, role + ": live actual face did not own its modifier")
	_prime_transients(face, attention_target)
	var terminal: Array[bool] = []
	motion.terminal_state_changed.connect(func(dead: bool): terminal.append(dead))
	# Exercise HealthComponent -> Enemy._on_died -> the actual bound motion owner.
	actor.health_component.damage(actor.health_component.max_health + 1.0)
	_check(actor.dead and actor.health_component.dead and motion.dead, role + ": actual lethal damage did not enter terminal state")
	_check(face.terminal_dead and not face.head_modifier.active and face.update_timer.paused, role + ": actual death did not release facial pose/timer ownership")
	# Enemy death deliberately changes the animation clock back to an internal
	# timer. Own it only in this fixture to sample the real death deterministically.
	motion.set_external_tick(true)
	var clip: StringName = motion.get_clip_for_state("death")
	var duration: float = motion.animation_player.get_animation(clip).length
	for _index in range(int(ceil((duration + 0.2) / 0.05))):
		motion.advance_external(0.05)
	var skeleton: Skeleton3D = motion.get_skeleton()
	var sampled: Array[Transform3D] = _bone_poses(skeleton)
	var emotion_before: String = face.head_modifier.emotion
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport
		await _settle(2)
		for cycle in range(3):
			actor.health_component.damage(1.0)
			motion.set_dead()
			face.set_conversation_active(true)
			face.set_focus_target(attention_target)
			face.set_distance_suspended(true)
			face.set_distance_suspended(false)
			actor.hide()
			actor.show()
			face.set_expression("stern")
			face.set_speech_amount(1.0)
			face.play_story_gesture("remember")
			face.configure(face.character_root, face.role_id)
			face._on_update_timer_timeout()
			var label := "%s/%s/cycle%d" % [role, viewport, cycle]
			_check(face.terminal_dead and not face.head_modifier.active and face.update_timer.paused, label + ": eligibility setter woke the dead actual face")
			_check(face.head_modifier.emotion == emotion_before and face.head_modifier.speech_amount == 0.0 and face.head_modifier.gesture_time == 0.0, label + ": dead face accepted presentation writes")
			_check(motion.current_state == "death" and motion.active_action_clip == clip, label + ": facial eligibility changed the death clip owner")
			_check(_same_bone_poses(skeleton, sampled), label + ": setter changed the sampled actual skeleton death pose")
			await _settle(2)
			_check(_same_bone_poses(skeleton, sampled), label + ": dead head/face moved on subsequent frames")
	_check(terminal == [true], role + ": repeated death emitted additional terminal changes")
	await _retire(actor)

func _ineligible_bandit_case(actor: Node3D, motion: Node, face: Node) -> void:
	if not _actor_contract(actor, motion, face, "bandit_deserter", false):
		return
	model_cases += 1
	_prime_transients(face, attention_target)
	_check(not face.valid and not face.head_modifier.active and face.update_timer.paused, "Actual ineligible bandit acquired live facial ownership")
	var terminal: Array[bool] = []
	motion.terminal_state_changed.connect(func(dead: bool): terminal.append(dead))
	actor.health_component.damage(actor.health_component.max_health + 1.0)
	_check(actor.dead and motion.dead and face.terminal_dead, "Actual bandit death did not follow its bound animation owner")
	motion.set_external_tick(true)
	var clip: StringName = motion.get_clip_for_state("death")
	var duration: float = motion.animation_player.get_animation(clip).length
	for _index in range(int(ceil((duration + 0.2) / 0.05))):
		motion.advance_external(0.05)
	var skeleton: Skeleton3D = motion.get_skeleton()
	var sampled: Array[Transform3D] = _bone_poses(skeleton)
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport
		face.set_conversation_active(true)
		face.set_focus_target(attention_target)
		face.set_distance_suspended(true)
		face.set_distance_suspended(false)
		actor.hide()
		actor.show()
		face.set_expression("stern")
		face.set_speech_amount(1.0)
		face.play_story_gesture("remember")
		motion.set_dead()
		face._on_update_timer_timeout()
		_check(not face.valid and face.terminal_dead and not face.head_modifier.active and face.update_timer.paused, "Viewport/eligibility setter activated the actual unsupported bandit face")
		_check(motion.current_state == "death" and motion.active_action_clip == clip, "Unsupported bandit face changed the death clip owner")
		await _settle(2)
		_check(_same_bone_poses(skeleton, sampled), "Unsupported bandit face changed its actual sampled death pose")
	_check(terminal == [true], "Repeated actual bandit death emitted additional terminal changes")

func _cached_player_case() -> void:
	root.size = Vector2i(1280, 720)
	var actor := Player.new()
	actor.name = "CachedPlayerFaceFixture"
	root.add_child(actor) # Actual Player._ready constructs its body, rig and gear.
	actor.set_physics_process(false)
	var motion: Node = actor.animation_driver
	var face: Node = actor.find_child("CharacterFaceDriver", true, false)
	if not _actor_contract(actor, motion, face, "player"):
		await _retire(actor)
		return
	model_cases += 1
	eligible_face_cases += 1
	motion.set_external_tick(true)
	var cached_face_id: int = face.get_instance_id()
	var cached_skeleton_id: int = motion.get_skeleton().get_instance_id()
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport
		await _settle(2)
		for constraint: String in ["visible", "hidden", "distance"]:
			actor.show()
			face.set_distance_suspended(false)
			_prime_transients(face, attention_target)
			if constraint == "hidden":
				actor.hide()
			elif constraint == "distance":
				face.set_distance_suspended(true)
			actor.health_component.damage(actor.health_component.max_health + 1.0)
			_check(motion.dead and face.terminal_dead and not face.head_modifier.active, "Cached player actual death did not disable the face")
			# Same object and the actual public restoration path used by journey load.
			# Assert synchronously, before any frame/timer can conceal stale state.
			actor.health_component.load_state({"health":125.0, "max_health":125.0, "dead":false})
			actor.reset_for_journey_restore()
			_check(face.get_instance_id() == cached_face_id and motion.get_skeleton().get_instance_id() == cached_skeleton_id, "Journey restoration replaced the cached real face/skeleton")
			_check_transients_cleared(face)
			_check(not motion.dead and not face.terminal_dead and motion.current_state != "death", "Actual cached-player restore retained terminal ownership")
			if constraint == "visible":
				_check(face.head_modifier.active and not face.update_timer.paused, "Visible cached real player did not resume facial updates")
			else:
				_check(not face.head_modifier.active and face.update_timer.paused, "Cached real player restore bypassed " + constraint)
				face.set_conversation_active(true)
				_check(not face.head_modifier.active and face.update_timer.paused, "Conversation bypassed restored player's " + constraint)
			actor.show()
			face.set_distance_suspended(false)
			face.set_conversation_active(false)
			_check(face.head_modifier.active and not face.update_timer.paused, "Clearing live constraints did not resume cached real face")
	await _retire(actor)

func _actor_contract(actor: Node3D, motion: Node, face: Node, role: String, require_eligible_face: bool = true) -> bool:
	var prepared := _prepared_scene(actor)
	_check(not prepared.is_empty(), role + ": actual actor did not instantiate a current prepared scene")
	_check(motion != null and motion.is_valid(), role + ": actual animation owner is missing/invalid")
	_check(face != null and (face.valid or not require_eligible_face) and face.head_modifier != null, role + ": actual native face/modifier is missing/invalid")
	if motion == null or not motion.is_valid() or face == null or (require_eligible_face and not face.valid) or face.head_modifier == null:
		return false
	var skeleton: Skeleton3D = motion.get_skeleton()
	_check(skeleton != null and skeleton.get_bone_count() > 10, role + ": actual imported hierarchy is missing")
	_check(face.motion_driver == motion and face.head_modifier.get_parent() == skeleton, role + ": real face and motion do not own the same exact skeleton")
	_check(actor.find_children("CharacterFaceDriver", "", true, false).size() == 1, role + ": actual presentation created duplicate face owners")
	var clip: StringName = motion.get_clip_for_state("death")
	var has_death: bool = clip != &"" and motion.animation_player != null and motion.animation_player.has_animation(clip)
	_check(has_death, role + ": actual configured death clip is missing")
	print("FACE ACTOR MODEL role=%s prepared=%s bones=%d face_root=%s motion_root=%s death=%s" % [role, prepared, skeleton.get_bone_count() if skeleton != null else 0, face.character_root.get_path(), motion.character_root.get_path(), clip])
	return skeleton != null and has_death and face.motion_driver == motion

func _prepared_scene(node: Node) -> String:
	if node.scene_file_path.begins_with("res://assets_external/characters_prepared/"):
		return node.scene_file_path
	for child: Node in node.get_children():
		var found := _prepared_scene(child)
		if not found.is_empty():
			return found
	return ""

func _bone_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(index))
	return result

func _same_bone_poses(skeleton: Skeleton3D, expected: Array[Transform3D]) -> bool:
	if skeleton.get_bone_count() != expected.size():
		return false
	for index in skeleton.get_bone_count():
		if not skeleton.get_bone_pose(index).is_equal_approx(expected[index]):
			return false
	return true

func _retire(actor: Node) -> void:
	if actor.asset_helper != null:
		actor.asset_helper.clear_runtime_caches()
	actor.free()
	RenderingServer.force_sync()
	await _settle(3)

func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame

func _check(valid: bool, detail: String) -> void:
	checks += 1
	super._check(valid, detail)
