extends "res://tools/verify_face_terminal_state.gd"

## Real face/motion/dialogue owners on an in-memory native rig. No saves/world.
const Head = preload("res://scripts/story_head_modifier.gd")
const StoryDelivery = preload("res://scripts/story_performance.gd")
const LifeScenes = preload("res://scripts/greyfen_life_controller.gd")

class FixtureSceneState extends RefCounted:
	func get_flag(_key: String, fallback: Variant = null) -> Variant:
		return fallback

class SceneHost extends Node3D:
	var hud: Node
	var audio: Node
	var story_state := FixtureSceneState.new()

var checks := 0

func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport_size
		await _attention_case()
	_expression_and_gesture_cases()
	for failure: String in failures:
		printerr("FACE ATTENTION: " + failure)
	print("FACE ATTENTION: %s checks=%d (explicit intent, real dialogue restoration, terminal/combat/visibility; two viewports; no gameplay claim)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _attention_case() -> void:
	var actor := Node3D.new()
	actor.name = "Nessa"
	root.add_child(actor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Head")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)))
	for control: String in Head.FACE_CONTROLS:
		var index := skeleton.get_bone_count()
		skeleton.add_bone("Face_" + control)
		skeleton.set_bone_parent(index, 0)
	actor.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.name = "NativeHeadBody"
	mesh.mesh = BoxMesh.new()
	actor.add_child(mesh)
	var animator := AnimationPlayer.new()
	animator.root_node = NodePath("..")
	actor.add_child(animator)
	var library := AnimationLibrary.new()
	for clip_name in ["Idle", "Attack", "Death"]:
		library.add_animation(clip_name, _clip(Quaternion.IDENTITY))
	animator.add_animation_library("", library)
	var face := FaceDriver.new()
	face.name = "CharacterFaceDriver"
	actor.add_child(face)
	_check(face.configure(actor, "saga_nessa"), "Fixture face must configure")
	var motion := FixtureMotion.new()
	motion.name = "CharacterAnimationDriver"
	actor.add_child(motion)
	motion.set_external_tick(true)
	_check(motion.configure(actor, {"idle":"Idle", "attack":"Attack", "death":"Death"}), "Fixture motion must configure")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.5, 4)
	camera.current = true
	var player := Node3D.new()
	root.add_child(player)
	player.add_to_group("player")
	player.position = Vector3(2, 0, -2)
	await process_frame
	face.screen_refresh_remaining = 0.0
	face._refresh_screen_budget(0.0)
	face.update_timer.stop()
	face.set_attention("auto")
	_tick_face(face, 6)
	_check(face.focus_target == player, "Auto attention must discover the player")
	face.set_attention("neutral")
	_tick_face(face, 35)
	_check(face.focus_target == null and absf(face.look_offset) < 0.003, "Neutral attention must settle without acquiring/scanning toward player")
	var work_point := Vector3(-2, 0.9, -2)
	_check(face.set_focus_point(work_point), "Finite workstation focus must be accepted")
	_tick_face(face, 25)
	_check(face.focus_target == null and face.look_offset < -0.1 and face.head_modifier.look_pitch > 0, "Workstation attention must face its point rather than player")
	_check(face.head_modifier.attention_pitch > 0.05 and face.head_modifier.attention_pitch <= 0.28, "Explicit lower work point must tilt the native head within bounds")
	var requested_pitch := -atan2(work_point.y - 1.55, Vector2(work_point.x, work_point.z).length())
	_check(is_equal_approx(face.head_modifier.attention_pitch + face.head_modifier.look_pitch, requested_pitch), "Head and eyes must share target pitch, not apply it twice")
	for frame in 15:
		await process_frame
		motion.advance_external(1.0 / 60.0)
		face.head_modifier._process_modification()
	_check(skeleton.get_bone_pose_rotation(0).get_euler().x > 0.01, "Actual native head bone must pitch down toward its workstation")
	face.set_attention("auto")
	_tick_face(face, 1)
	_check(face.head_modifier.attention_pitch == 0.0, "Auto attention must retain original eye-only pitch")
	face.set_focus_point(work_point)
	_check(not face.set_focus_point(Vector3(NAN, 0, 0)), "Nonfinite workstation point must be rejected")
	_check(face.attention_mode == "point" and face.focus_point == work_point, "Invalid focus must preserve current intent")
	var temporary := Node3D.new()
	root.add_child(temporary)
	face.set_focus_target(temporary)
	var lost_target := face.capture_attention()
	temporary.free()
	_tick_face(face, 30)
	_check(not is_instance_valid(face.focus_target), "Explicit freed target must not acquire player")
	_check(face.restore_attention(lost_target) and face.attention_mode == "neutral", "Restoring a freed explicit target must become neutral")
	var performance := StoryDelivery.new()
	performance.name = "StoryPerformance"
	actor.add_child(performance)
	for mode: String in ["point", "neutral", "sleep", "actor", "auto"]:
		face.set_attention(mode, player if mode == "actor" else null, work_point)
		face.set_expression("warm")
		_tick_face(face, 10)
		var before := face.capture_attention()
		performance.start(actor, player, null)
		_check(performance.active and face.attention_mode == "actor" and face.focus_target == player, "Dialogue must own listener attention from " + mode)
		performance.present_page({"speaker_id":"nessa", "performance":{"gesture":"reassure", "emotion":"concerned"}})
		performance._process(0.3)
		performance.stop()
		_check(face.attention_mode == mode and face.expression == "warmth", "Dialogue must restore intent and normalized expression for " + mode)
		var after := face.capture_attention()
		for key: String in ["point", "distance_suspended", "conversation_active", "focus_refresh_remaining", "attention_elapsed", "look_offset", "update_accumulator", "blink_remaining", "next_blink", "head"]:
			_check(before[key] == after[key], "Dialogue lost " + mode + " field " + key)
	_shared_scene_cases(actor, motion, face, player, performance, work_point)
	face.set_sleeping(true)
	_tick_face(face, 20)
	_check(face.head_modifier.blink_closure == 1.0, "Sleep must close authored eyelids")
	face.set_speech_amount(1.0)
	face.play_story_gesture("explain")
	_check(face.head_modifier.speech_amount == 0.0 and face.head_modifier.gesture_time == 0.0, "Sleep must reject speech and gesture")
	face.set_sleeping(false)
	_check(face.head_modifier.blink_closure == 0.0, "Wake must release closed eyelids")
	motion.trigger_action("attack", 1.0, 0.0)
	face._reconcile_face_eligibility()
	_check(not face.head_modifier.active and not face.update_timer.paused, "Combat must own pose while keeping visibility polling")
	motion.stop_action()
	face._reconcile_face_eligibility()
	_check(face.head_modifier.active, "Face must resume after combat")
	face.set_distance_suspended(true)
	var suspended := face.capture_attention()
	performance.start(actor, player, null)
	performance.stop()
	_check(face.distance_suspended and not face.head_modifier.active, "Dialogue must restore distance suspension")
	face.set_distance_suspended(false)
	actor.visible = false
	_check(face.restore_attention(suspended) and not face.head_modifier.active, "Snapshot restoration cannot override visibility")
	actor.visible = true
	face.set_distance_suspended(false)
	performance.start(actor, player, null)
	var stale := face.capture_attention()
	motion.set_dead()
	performance.stop()
	_check(not face.restore_attention(stale) and not face.head_modifier.active, "Old attention cannot wake death")
	motion.reset_for_journey_restore()
	_check(not face.restore_attention(stale) and face.attention_mode == "auto", "Old dialogue snapshot cannot overwrite restored journey")
	actor.free()
	player.free()
	camera.free()
	await process_frame

func _shared_scene_cases(actor: Node3D, motion: Node, face: Node, player: Node3D, performance: Node, work_point: Vector3) -> void:
	var host := SceneHost.new()
	var life := LifeScenes.new()
	life.host = host
	var peer := Node3D.new()
	root.add_child(peer)
	var entry := {"id":"nessa", "node":actor, "driver":motion, "face":face,
		"activity_active":true, "station":"fixture", "profile":{"activity":"sort_herbs"},
		"social_time":0.0, "motion_speed":0.0, "route":[], "pause":0.0}
	var other := {"id":"peer", "node":peer, "driver":null, "face":null,
		"activity_active":false, "station":"", "profile":{"activity":"idle"},
		"social_time":0.0, "motion_speed":0.0, "route":[], "pause":0.0}
	var selected: Array[Dictionary] = [entry, other]
	var scene := {"id":"synthetic_scene", "kind":"exchange", "turns":[["nessa", "Nessa", "Fixture line"]]}
	for world: bool in [false, true]:
		for mode: String in ["point", "neutral", "sleep"]:
			face.set_attention(mode, null, work_point)
			face.set_expression("warmth")
			_tick_face(face, 5)
			var before: Dictionary = face.capture_attention()
			entry.activity_active = true
			if world:
				life._start_world_scene(scene, selected)
			else:
				life._social_pair(entry, other, [{"speaker":"nessa", "text":"Fixture line"}])
			_check(not life.social_scene.is_empty(), "Shared scene must acquire its cast")
			_check(life.social_scene.actors[0].attention.mode == mode, "Shared scene must capture before releasing " + mode)
			face.set_focus_target(peer)
			face.set_expression("concerned")
			face.play_story_gesture("explain")
			life._end_social_exchange()
			var after: Dictionary = face.capture_attention()
			for key: String in ["mode", "point", "expression", "conversation_active", "distance_suspended", "attention_elapsed", "look_offset", "blink_remaining", "next_blink", "head"]:
				_check(before[key] == after[key], "Shared scene lost " + mode + " field " + key)
	# A genuine higher-priority dialogue cancels the scene before capturing its
	# own snapshot, so ending that dialogue restores the original task focus.
	face.set_focus_point(work_point)
	entry.activity_active = true
	life._start_world_scene(scene, selected)
	performance.start(actor, player, null)
	_check(life.social_scene.is_empty() and performance.active and face.focus_target == player, "Dialogue must interrupt shared scene and own attention")
	performance.stop()
	_check(face.attention_mode == "point" and face.focus_point == work_point, "Nested handoff must return to the original work point")
	# Late cleanup must not touch a protected owner which has already arrived.
	life._start_world_scene(scene, selected)
	actor.set_meta("cast_dialogue_owner", 9876)
	face.set_focus_target(player)
	face.set_conversation_active(true)
	life._end_social_exchange()
	_check(face.attention_mode == "actor" and face.focus_target == player and face.conversation_active, "Late shared cleanup must preserve a newer protected owner")
	actor.remove_meta("cast_dialogue_owner")
	face.set_conversation_active(false)
	# Claim failure must not release an earlier actor's work or point attention.
	face.set_focus_point(work_point)
	entry.activity_active = true
	peer.set_meta("cast_work_owner", "fixture")
	life._start_world_scene(scene, selected)
	_check(life.social_scene.is_empty() and entry.activity_active and face.attention_mode == "point", "Partial cast claim must leave the earlier activity intact")
	peer.remove_meta("cast_work_owner")
	# Journey restoration invalidates the entire old scene snapshot.
	life._start_world_scene(scene, selected)
	motion.set_dead()
	life._end_social_exchange()
	_check(face.terminal_dead and not face.head_modifier.active, "Shared scene cleanup cannot revive a dead face")
	motion.reset_for_journey_restore()
	face.set_focus_point(work_point)
	life._start_world_scene(scene, selected)
	motion.reset_for_journey_restore()
	life._end_social_exchange()
	_check(face.attention_mode == "auto" and not face.conversation_active, "Stale shared scene cannot overwrite restored journey attention")
	life.free()
	host.free()
	peer.free()

func _tick_face(face: Node, count: int) -> void:
	for index in count:
		face._on_update_timer_timeout()
	face.update_timer.stop()

func _expression_and_gesture_cases() -> void:
	var head := Head.new()
	for expression_name: String in Head.EXPRESSIONS:
		_check(head.set_expression(expression_name), "Declared expression unsupported: " + expression_name)
	for alias: String in Head.EXPRESSION_ALIASES:
		_check(head.set_expression(alias) and head.emotion == Head.EXPRESSION_ALIASES[alias], "Expression alias failed: " + alias)
	var retained := head.emotion
	_check(not head.set_expression("not_authored") and head.emotion == retained, "Unknown expression must not erase current emotion")
	var signatures := {}
	for kind: String in ["acknowledge", "disagree", "recall", "reassure", "guarded_listening", "offer", "explain"]:
		var signature: Array[Vector3] = []
		_check(head.gesture(kind), "Authored gesture rejected: " + kind)
		for index in range(21):
			var offset := Head.gesture_offset(kind, float(index) / 20.0)
			_check(offset.is_finite() and offset.length() <= 0.13, "Gesture exceeds bounded head envelope: " + kind)
			signature.append(offset)
		_check(signature.front().is_zero_approx() and signature.back().is_zero_approx(), "Gesture must return smoothly to rest: " + kind)
		_check(not signatures.has(str(signature)), "Gesture duplicated another motion: " + kind)
		signatures[str(signature)] = kind
	_check(not head.gesture("not_authored"), "Unknown gesture must be rejected")
	head.free()

func _check(valid: bool, detail: String) -> void:
	checks += 1
	super._check(valid, detail)
