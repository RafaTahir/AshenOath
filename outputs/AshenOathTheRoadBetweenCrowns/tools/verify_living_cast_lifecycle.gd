extends SceneTree

## Real motion/presentation owners on a tiny synthetic rig. No model packs,
## gameplay world, filesystem saves or external libraries are required.
const Driver = preload("res://scripts/character_animation_driver.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	actor.name = "SyntheticLifeActor"
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	actor.add_child(skeleton)
	for name: String in ["pelvis", "hand_l", "hand_r"]:
		skeleton.add_bone(name)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	actor.add_child(player)
	var base := AnimationLibrary.new()
	base.add_animation("Idle", _clip(4.0))
	player.add_animation_library("", base)
	var authored := AnimationLibrary.new()
	for name: String in ["Life_Work", "Life_Idle_A", "Life_Idle_B"]:
		authored.add_animation(name, _clip(4.0))
	player.add_animation_library("life", authored)
	root.add_child(actor)
	var driver := Driver.new()
	driver.name = "CharacterAnimationDriver"
	actor.add_child(driver)
	_check(driver.configure(actor, {"idle":"Idle", "walk":"Idle", "death":"Idle"}), "synthetic native graph binds")
	if not driver.is_valid():
		_finish(actor)
		return
	driver.set_external_tick(true)
	driver.life_work_kinds = ["forge", "repair", "care"]
	for name: String in ["Life_Work", "Life_Idle_A", "Life_Idle_B"]:
		var key := "life/" + name
		driver.bound_track_counts[key] = driver._bound_bone_tracks(key)
		_check(int(driver.bound_track_counts[key]) > 0, "synthetic native clip binds " + name)
	driver.set_life_activity("forge")
	for index in 24: driver.advance_external(0.05)
	_check(absf(driver.life_elapsed - 1.2) < 0.001, "native contact clock advances to the authored pose")
	driver.set_life_activity("repair")
	driver.advance_external(0.05)
	_check(absf(driver.animation_graph.playback.get_current_play_position() - 0.05) < 0.002, "switching work kind restarts the same native clip: native=%f" % driver.animation_graph.playback.get_current_play_position())
	_check(absf(driver.life_elapsed - driver.animation_graph.playback.get_current_play_position()) < 0.002, "work kind switch keeps contact and native clocks aligned: contact=%f native=%f" % [driver.life_elapsed,driver.animation_graph.playback.get_current_play_position()])
	for index in 12: driver.advance_external(0.05)
	driver.clear_life_activity()
	driver.set_life_activity("forge")
	driver.advance_external(0.05)
	_check(absf(driver.animation_graph.playback.get_current_play_position() - 0.05) < 0.002, "clear and reacquire before graph advance restarts native work: native=%f" % driver.animation_graph.playback.get_current_play_position())
	var phase: float = driver.animation_graph.playback.get_current_play_position()
	driver.animation_graph.ambient_clip("life/Life_Work")
	driver.advance_external(0.05)
	_check(absf(driver.animation_graph.playback.get_current_play_position() - phase - 0.05) < 0.002, "unrelated ambient callers retain their existing non-restarting behavior")
	driver.clear_life_activity()
	driver.life_requires_station = true
	driver.set_life_activity("forge")
	_check(driver.life_clip != &"life/Life_Work", "a required missing station waits in authored idle")
	driver.set_life_workstation({"activity":"forge"})
	_check(driver.life_clip == &"life/Life_Work", "acquiring a task surface starts its native work without changing intent")
	var station := Node3D.new()
	actor.add_child(station)
	driver.set_life_workstation({"activity":"forge","node_ref":weakref(station),"point":Vector3(0,1,-0.4)})
	driver.advance_external(0.25)
	var contact_elapsed: float = driver.life_elapsed
	driver.set_life_workstation({"activity":"forge","node_ref":weakref(station),"point":Vector3(0,1,-0.4)})
	_check(is_equal_approx(driver.life_elapsed,contact_elapsed), "refreshing the same supported station preserves the native contact clock")
	driver.set_life_workstation({"activity":"forge","node_ref":weakref(station),"point":Vector3(0,1,-0.42)})
	_check(is_zero_approx(driver.life_elapsed), "changing a real contact goal restarts the matched native contact clock")
	driver.set_life_workstation({})
	_check(driver.life_clip != &"life/Life_Work", "removing a support interrupts native work immediately")
	driver.set_life_workstation({"activity":"repair"})
	_check(driver.life_clip != &"life/Life_Work", "another activity's station cannot enable the work clip")
	driver.life_requires_station = false
	driver.clear_life_activity()
	driver.life_work_kinds.append("watch")
	driver.set_life_activity("watch")
	_check(driver.life_clip == &"life/Life_Work", "Senn's contact-free observation can use authored work without a fabricated tool")
	_check(not driver.supports_story_prop("cup"), "cup eligibility fails without the native drink clip even on a valid hand rig")
	driver.clear_life_activity()
	driver.life_idle_only = true
	driver.set_relaxed_idle(true)
	_check(str(driver.life_clip).begins_with("life/Life_Idle_"), "eligible stowed-player rest uses the authored idle")
	driver.set_relaxed_idle(false)
	_check(driver.life_clip == StringName(), "equipment or movement ownership releases relaxed idle immediately")
	driver.set_dialogue_pose(true)
	driver.set_relaxed_idle(true)
	_check(driver.life_clip == StringName() and driver.story_dialogue_active, "relaxed idle cannot take a dialogue owner's pose")
	driver.stop_story_gesture()
	driver.life_idle_only = false
	_check(driver.set_observation_clip("Life_Idle_A"), "creature observation can acquire a native ambient clip")
	driver.advance_external(0.25)
	var observation: Dictionary = driver.observation_motion_sample()
	_check(not observation.is_empty() and observation.clip == "life/Life_Idle_A" and is_equal_approx(float(observation.duration),4.0), "observation samples identify the actual playing native branch")
	_check(not observation.is_empty() and is_equal_approx(float(observation.time),driver.animation_graph.playback.get_current_play_position()) and is_equal_approx(float(observation.phase),float(observation.time)/4.0), "observation phase comes from the graph clock")
	var observation_time := float(observation.get("time",0.0))
	driver.set_observation_clip("Life_Idle_A")
	driver.advance_external(0.25)
	_check(absf(float(driver.observation_motion_sample().get("time",0.0))-observation_time-0.25)<0.002, "repeated ambient selection preserves native clip progress")
	driver.set_distance_suspended(true)
	_check(not driver.set_observation_clip("Life_Idle_B"), "distance-suspended creatures cannot select a new ambient pose")
	_check(driver.observation_motion_sample().is_empty(), "suspended ambient poses emit no visible event samples")
	driver.set_distance_suspended(false)
	driver.clear_observation_clip()
	_check(driver.presentation_state=="" and not driver.action_active,"explicit observation release restores locomotion ownership")
	_check(driver.observation_motion_sample().is_empty(), "released observation cannot report a stale native sample")
	driver.set_observation_clip("Life_Idle_A")
	driver.set_locomotion_motion(Vector3(1,0,0),true)
	_check(driver.presentation_state=="" and driver.current_state!="ecology","real movement immediately releases planted ambient presentation")
	driver.set_observation_clip("Life_Idle_A")
	driver.trigger_action("death",1.0,0.1,true)
	driver.clear_observation_clip()
	_check(driver.action_active and driver.current_state=="death","late ambient release cannot restart a newer terminal action")
	_check(driver.observation_motion_sample().is_empty(), "newer terminal actions cannot report ambient contact or call phases")
	driver.stop_action()
	driver.set_locomotion_motion(Vector3.ZERO,true)

	var permanent_socket := BoneAttachment3D.new()
	permanent_socket.bone_name = "hand_r"
	skeleton.add_child(permanent_socket)
	var permanent := Node3D.new()
	permanent.name = "OccupationEquipment"
	permanent.position = Vector3(0.02,-0.03,0)
	permanent.rotation_degrees.z = 90.0
	permanent_socket.add_child(permanent)
	var identity := Node3D.new()
	identity.name = "OccupationProp_blacksmith_tor"
	permanent.add_child(identity)
	var contact := Node3D.new()
	contact.name = "ForgedHead"
	contact.position.y = 0.23
	identity.add_child(contact)
	var life: Node = driver.life_modifier
	life.active = false
	var borrowed_book := Node3D.new()
	borrowed_book.name = "CastleRoleEquipment"
	actor.add_child(borrowed_book)
	var book_mesh := Node3D.new()
	book_mesh.name = "VarganRecordBook"
	borrowed_book.add_child(book_mesh)
	life.station = {"activity":"care","surface_prop":"SupportedDesk"}
	life._update_tool("care",true)
	_check(not borrowed_book.visible and borrowed_book.has_meta("book_visibility_owner"), "supported desk work stows the borrowed carried book")
	life.hide_activity_tool()
	_check(borrowed_book.visible and not borrowed_book.has_meta("book_visibility_owner"), "interruption restores the book's earlier visibility")
	borrowed_book.visible = false
	life._update_tool("care",true)
	life.hide_activity_tool()
	_check(not borrowed_book.visible, "task cleanup preserves a book that another owner had already hidden")
	borrowed_book.visible = true
	borrowed_book.set_meta("book_visibility_owner",weakref(actor))
	life._update_tool("care",true)
	_check(borrowed_book.visible, "task work cannot steal a newer book visibility owner")
	borrowed_book.remove_meta("book_visibility_owner")
	life.station = {}
	life._update_tool("forge", true)
	_check(life.tool == permanent and not life.owns_tool, "authored occupation equipment is borrowed")
	_check(life.tool_contact_local.is_equal_approx(Vector3(-0.21,-0.03,0)), "hammer contact derives its actual fitted grip offset")
	permanent_socket.position += Vector3(1,0,0)
	_check(life._contact_socket_offset(contact).is_equal_approx(Vector3(-0.21,-0.03,0)), "stale socket world transforms cannot change native contact reach")
	life._update_tool("care", true)
	var cloth: Node3D = life.tool
	_check(is_instance_valid(cloth) and life.owns_tool and cloth.get_meta("life_generated_activity_tool", false), "new cloth socket records generated ownership")
	if not is_instance_valid(cloth):
		_finish(actor)
		return
	_check(is_instance_valid(permanent) and not permanent.is_queued_for_deletion() and not permanent.visible, "style change hides rather than deletes borrowed equipment")
	life._update_tool("sort_herbs", true)
	_check(cloth.is_queued_for_deletion() and not cloth.visible, "replaced generated cloth immediately hides and queues deletion")
	await process_frame
	await process_frame
	_check(not is_instance_valid(cloth), "replaced generated sibling socket is removed")
	var bowl: Node3D = life.tool
	driver.set_distance_suspended(true)
	_check(not bowl.visible, "distance suspension hides the tool immediately without waiting for a modifier tick")
	driver.set_distance_suspended(false)
	life._update_tool("sort_herbs", true)
	driver.clear_life_activity()
	_check(not bowl.visible, "activity interruption hides the tool immediately")
	_check(driver.configure(actor, {"idle":"Idle", "walk":"Idle", "death":"Idle"}), "real driver reconfiguration succeeds")
	await process_frame
	await process_frame
	_check(not is_instance_valid(bowl), "driver reconfiguration removes generated sibling props")
	_check(is_instance_valid(permanent) and not permanent.is_queued_for_deletion(), "reconfiguration preserves the authored equipment owner")
	driver.life_modifier._update_tool("forge", true)
	driver.set_dead()
	_check(is_instance_valid(permanent) and not permanent.visible, "death hides borrowed equipment without destroying it")
	driver.reset_for_journey_restore()
	driver.life_modifier._update_tool("care", true)
	var final_tool: Node3D = driver.life_modifier.tool
	driver.free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(final_tool) and is_instance_valid(permanent), "motion-owner teardown cleans generated props and retains borrowed equipment")
	_finish(actor)

func _clip(duration: float) -> Animation:
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Skeleton3D:pelvis"))
	clip.position_track_insert_key(track, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(track, duration * 0.5, Vector3(0.1,0,0))
	clip.position_track_insert_key(track, duration, Vector3.ZERO)
	return clip

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish(actor: Node3D) -> void:
	actor.free()
	for failure in failures: printerr("LIVING CAST LIFECYCLE: " + failure)
	print("LIVING CAST LIFECYCLE: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
