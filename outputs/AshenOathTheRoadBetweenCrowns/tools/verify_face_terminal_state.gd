extends SceneTree

## Resource-free fixture: one head bone, two in-memory clips and a native mesh.
## Uses the real animation/face drivers; no actor assets or world are loaded.
const FaceDriver = preload("res://scripts/character_face_driver.gd")

class FixtureMotion extends "res://scripts/character_animation_driver.gd":
	func _ensure_life_modifier() -> void:
		pass # Workstation/tool presentation is outside this one-bone fixture.

var failures: Array[String] = []
var terminal_events: Array[bool] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	actor.name = "Bandit"
	root.add_child(actor)
	var visual := Node3D.new()
	visual.name = "VisualRoot"
	actor.add_child(visual)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Head")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)))
	visual.add_child(skeleton)
	var mesh := MeshInstance3D.new()
	mesh.name = "NativeHeadBody"
	mesh.mesh = BoxMesh.new()
	visual.add_child(mesh)
	var player := AnimationPlayer.new()
	player.root_node = NodePath("..")
	visual.add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", _clip(Quaternion.IDENTITY))
	var death_rotation := Quaternion(Vector3.RIGHT, 0.7)
	library.add_animation("Death", _clip(death_rotation))
	player.add_animation_library("", library)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.55, 5)
	camera.current = true
	var face := FaceDriver.new()
	face.name = "CharacterFaceDriver"
	actor.add_child(face)
	_check(face.configure(actor, "bandit"), "Synthetic native face did not configure")
	var motion := FixtureMotion.new()
	motion.name = "CharacterAnimationDriver"
	visual.add_child(motion)
	motion.set_external_tick(true)
	motion.terminal_state_changed.connect(func(dead: bool): terminal_events.append(dead))
	_check(motion.configure(visual, {"idle":"Idle", "death":"Death"}), "Synthetic motion did not configure")
	_check(face.motion_driver == motion and face.head_modifier.active, "Face-before-motion configuration did not bind its terminal owner")
	var connection_count := motion.terminal_state_changed.get_connections().size()
	for _index in range(4):
		face.bind_motion(motion)
		face.configure(actor, "bandit")
	_check(motion.terminal_state_changed.get_connections().size() == connection_count, "Repeated binding duplicated terminal listeners")
	_check(skeleton.find_children("StoryHeadModifier", "", false, false).size() == 1, "Repeated face configuration duplicated its modifier")
	_check(terminal_events == [false], "Successful motion configure did not publish its alive state exactly once")
	# Offscreen live actors retain a polling clock and may attend a conversation.
	camera.position.x = 100
	face.set_conversation_active(false)
	_check(not face.head_modifier.active and not face.update_timer.paused, "Offscreen live face lost its visibility poll or kept pose ownership")
	face.set_conversation_active(true)
	_check(face.head_modifier.active, "Live conversation could not override frustum culling")
	camera.position.x = 0
	face.set_conversation_active(false)
	motion.set_dead()
	for _index in range(10):
		motion.advance_external(0.2)
	var sampled_death := skeleton.get_bone_pose_rotation(0)
	_check(sampled_death.angle_to(death_rotation) < 0.001, "Fixture did not sample its authored death clip")
	_check(face.terminal_dead and not face.head_modifier.active and face.update_timer.paused, "Death did not surrender face pose and timer ownership")
	var emotion_before := face.head_modifier.emotion
	for _index in range(3):
		motion.set_dead()
		face.set_conversation_active(true)
		face.set_distance_suspended(true)
		face.set_distance_suspended(false)
		actor.visible = false
		actor.visible = true
		face.set_expression("stern")
		face.set_speech_amount(1.0)
		face.play_story_gesture("remember")
		face.configure(actor, "bandit")
		face._on_update_timer_timeout()
		_check(not face.head_modifier.active and face.update_timer.paused, "An eligibility setter woke a dead bandit's face")
		_check(skeleton.get_bone_pose_rotation(0).angle_to(sampled_death) < 0.001, "Face update changed the animation owner's sampled death pose")
	_check(terminal_events.count(true) == 1, "Repeated death duplicated terminal state changes")
	_check(face.head_modifier.emotion == emotion_before and face.head_modifier.speech_amount == 0.0 and face.head_modifier.gesture_time == 0.0, "Dead face accepted expression/speech/gesture writes")
	_check(motion.current_state == "death" and motion.active_action_clip == &"Death", "Face reconciliation changed terminal clip authority")
	# A newly attached face must observe an already-dead motion owner immediately.
	face.free()
	face = FaceDriver.new()
	face.name = "CharacterFaceDriver"
	actor.add_child(face)
	_check(face.configure(actor, "player_kael"), "Late-bound cached-player face did not configure")
	_check(face.terminal_dead and not face.head_modifier.active, "Late face binding missed an existing terminal state")
	face.set_distance_suspended(true)
	motion.reset_for_journey_restore()
	_check(not face.terminal_dead and not face.head_modifier.active, "Restore ignored a remaining distance suspension")
	face.set_distance_suspended(false)
	_check(face.head_modifier.active and not face.update_timer.paused, "Restored player did not regain facial updates")
	motion.set_dead()
	actor.visible = false
	motion.reset_for_journey_restore()
	face.set_conversation_active(true)
	_check(not face.head_modifier.active and face.update_timer.paused, "Conversation overrode a hidden restored actor")
	actor.visible = true
	_check(face.head_modifier.active and not face.update_timer.paused, "Visibility return did not resume a restored player's face")
	motion.set_dead()
	_check(motion.configure(visual, {"idle":"Idle", "death":"Death"}), "Cached motion reconfiguration failed")
	_check(not face.terminal_dead and face.head_modifier.active, "Successful motion reconfiguration did not release its terminal face state")
	# Rebinding disconnects the previous authority; its later signal is stale.
	motion._clear_playback()
	var replacement := FixtureMotion.new()
	visual.add_child(replacement)
	replacement.set_external_tick(true)
	_check(replacement.configure(visual, {"idle":"Idle", "death":"Death"}), "Replacement motion did not configure")
	_check(face.motion_driver == replacement, "Face did not bind its replacement animation owner")
	motion.terminal_state_changed.emit(true)
	_check(not face.terminal_dead and face.head_modifier.active, "An old motion owner's signal affected the rebound face")
	_check(not motion.terminal_state_changed.is_connected(face._on_terminal_state_changed), "Face retained its obsolete terminal connection")
	actor.free()
	camera.free()
	await process_frame
	for failure in failures:
		printerr("FACE TERMINAL: " + failure)
	print("FACE TERMINAL: %s (one head bone; death, eligibility, rebinding and restore; no art/world)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _clip(rotation: Quaternion) -> Animation:
	var animation := Animation.new()
	animation.length = 0.5
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("Skeleton3D:Head"))
	animation.track_insert_key(track, 0.0, rotation)
	animation.track_insert_key(track, 0.5, rotation)
	return animation

func _check(valid: bool, detail: String) -> void:
	if not valid:
		failures.append(detail)
