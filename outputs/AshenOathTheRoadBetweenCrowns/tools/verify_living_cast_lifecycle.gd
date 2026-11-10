extends SceneTree

## Real motion/presentation owners on a tiny synthetic rig. No model packs,
## gameplay world, filesystem saves or external libraries are required.
const Driver = preload("res://scripts/character_animation_driver.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
var failures: Array[String] = []
var checks := 0

class WorkstationOwner extends Node:
	var available := false
	func story_workstation_for(_driver: Node, identity: String) -> Dictionary:
		return {"verified_fixture":true} if available and identity == "vale" else {}

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
	driver.life_requires_station = true
	driver.set_life_activity("forge")
	var initial_contacts: Array = []
	var initial_listener := func(event: String, _point: Vector3) -> void: initial_contacts.append(event)
	driver.activity_contact.connect(initial_listener)
	driver.set_life_workstation({"activity":"forge","surface_prop":"VerifiedFixtureSurface","contact_event":"fixture_contact","point":Vector3(0,1,0)})
	_check(driver.life_motion_sample().is_empty() and is_zero_approx(driver.life_elapsed), "a queued native work branch cannot publish a detached contact clock")
	driver.life_modifier.pose_weight=1.0
	driver.life_modifier._process_modification()
	_check(initial_contacts.is_empty(), "queued native work cannot emit a procedural fallback contact")
	var selected_before_evaluation := false
	var premature_native_sample := false
	for index in 24:
		var previous_node: StringName = driver.animation_graph.playback.get_current_node()
		driver.advance_external(0.05)
		if driver.animation_graph.playback.get_current_node()!=previous_node and str(driver.animation_graph.playback.get_current_node())=="ecology_"+str(abs("life/Life_Work".hash())):
			selected_before_evaluation = true
			premature_native_sample = not driver.life_motion_sample().is_empty()
	_check(selected_before_evaluation and not premature_native_sample,"a newly selected but not yet evaluated native branch cannot claim time or contact ownership")
	_check(not driver.life_motion_sample().is_empty() and absf(driver.life_elapsed-driver.animation_graph.playback.get_current_play_position())<0.002 and driver.life_elapsed<1.2, "native work clock excludes queued transition time and matches the evaluated pose")
	driver.activity_contact.disconnect(initial_listener)
	driver.life_requires_station = false
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
	driver.set_activity_prop("supply")
	driver.life_modifier._process_modification()
	_check(not is_instance_valid(driver.life_modifier.tool),"missing support cannot create a substitute vessel from the authored work prop")
	driver.set_life_activity("carry")
	_check(_settle_graph_branch(driver,"locomotion"), "carry fixture reaches the real locomotion branch after queued work transitions")
	driver.life_modifier._process_modification()
	var carried_supply: Node3D = driver.life_modifier.tool
	_print_prop_graph(driver,"carry_complete")
	_check(is_instance_valid(carried_supply) and carried_supply.visible,"a genuine scheduled carry retains its supply prop")
	driver.set_life_activity("forge")
	driver.life_modifier._process_modification()
	_check(is_instance_valid(carried_supply) and not carried_supply.visible,"blocked work hides a previously carried vessel instead of silently reusing it")
	driver.set_activity_prop("")
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
	driver.life_idle_variant=1
	driver.set_life_activity("idle")
	for tick in 10: driver.advance_external(0.025)
	driver.set_activity_prop("bread")
	driver.life_modifier._process_modification()
	_check(not driver.activity_prop_pose_ready() and not driver.life_modifier.tool.visible,"an authored open-hand idle cannot expose a calibrated closed-palm prop")
	driver.set_life_activity("eat")
	for tick in 2: driver.advance_external(0.025)
	driver.life_modifier._process_modification()
	_print_prop_graph(driver,"meal_fading")
	_check(not driver.activity_prop_pose_ready() and not driver.life_modifier.tool.visible,"outgoing life-idle crossfade keeps the meal prop hidden until its fingers release ownership")
	for tick in 10: driver.advance_external(0.025)
	driver.life_modifier._process_modification()
	_print_prop_graph(driver,"meal_complete")
	_check(driver.activity_prop_pose_ready() and driver.life_modifier.tool.visible,"completed native transition enables the meal prop without a detached timer")
	driver.clear_life_activity()
	driver.life_work_kinds.append("watch")
	driver.set_life_activity("watch")
	_check(driver.life_clip == &"life/Life_Work", "Senn's contact-free observation can use authored work without a fabricated tool")
	_settle_graph_branch(driver,"ecology_"+str(abs("life/Life_Work".hash())))
	var watch_start: float = driver.life_elapsed
	for tick in 180: driver.advance_external(0.05)
	_check(driver.life_clip == &"life/Life_Work" and absf(driver.life_elapsed-watch_start-9.0)<0.002 and driver.life_native_cycle>=2, "contact-free observation retains its native survey through actual loop wraps")
	driver.set_life_activity("rest")
	var idle_before: StringName = driver.life_clip
	var completed_idle := false
	for tick in 200:
		var before: float = driver.life_elapsed
		driver.advance_external(0.025)
		if driver.life_clip != idle_before:
			completed_idle=before+0.025 >= 4.0-0.00001
			break
	_check(driver.life_clip != idle_before and str(driver.life_clip).begins_with("life/Life_Idle_"), "ordinary authored rest still alternates its two idle variations")
	_check(completed_idle,"idle variation waits for the complete evaluated native clip rather than its queued wall time")
	_check(not driver.supports_story_prop("cup"), "cup eligibility fails without the native drink clip even on a valid hand rig")
	_verify_story_station_owner(driver,actor)
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
	# Prior public activity/dialogue changes can queue several transitions.
	# Observe their actual completion instead of assuming one fixed fade time.
	_check(_settle_graph_branch(driver,"ecology_"+str(abs("life/Life_Idle_A".hash()))), "observation fixture reaches its actual native branch after prior owners release")
	var observation: Dictionary = driver.observation_motion_sample()
	_check(not observation.is_empty() and observation.clip == "life/Life_Idle_A" and is_equal_approx(float(observation.duration),4.0), "observation samples identify the actual playing native branch")
	_check(not observation.is_empty() and is_equal_approx(float(observation.time),driver.animation_graph.playback.get_current_play_position()) and is_equal_approx(float(observation.phase),float(observation.time)/4.0), "observation phase comes from the graph clock")
	var observation_time := float(observation.get("time",0.0))
	driver.set_observation_clip("Life_Idle_A")
	driver.advance_external(0.25)
	_check(absf(float(driver.observation_motion_sample().get("time",0.0))-observation_time-0.25)<0.002, "repeated ambient selection preserves native clip progress: before=%s after=%s node=%s travel=%s" % [observation_time,driver.observation_motion_sample(),driver.animation_graph.playback.get_current_node(),driver.animation_graph.playback.get_travel_path()])
	observation_time = float(driver.observation_motion_sample().get("time",0.0))
	driver.clear_observation_clip()
	driver.set_observation_clip("Life_Idle_A")
	driver.advance_external(0.05)
	_check(not driver.observation_motion_sample().is_empty(), "same-frame ambient release and reacquire cancels the older queued locomotion request")
	_check(absf(float(driver.observation_motion_sample().get("time",0.0))-observation_time-0.05)<0.002, "reclaiming the current ambient branch preserves native time rather than seeking or restarting")
	var suspended_native_time: float = driver.animation_graph.playback.get_current_play_position()
	var suspended_native_node: StringName = driver.animation_graph.playback.get_current_node()
	driver.set_distance_suspended(true)
	_check(not driver.set_observation_clip("Life_Idle_B"), "distance-suspended creatures cannot select a new ambient pose")
	_check(driver.observation_motion_sample().is_empty(), "suspended ambient poses emit no visible event samples")
	driver.advance_external(3.0)
	driver.animation_graph.advance(3.0)
	_check(not driver.is_evaluation_scheduled() and not driver.animation_graph.scheduled() and is_equal_approx(driver.animation_graph.playback.get_current_play_position(),suspended_native_time),"both scheduled and direct manual graph advances are frozen during distance suspension")
	driver.set_distance_suspended(false)
	_check(driver.animation_graph.playback.get_current_node()==suspended_native_node and is_equal_approx(driver.animation_graph.playback.get_current_play_position(),suspended_native_time),"reactivation preserves the evaluated native branch and position without an internal reset")
	driver.advance_external(0.25)
	_check(absf(float(driver.observation_motion_sample().get("time",-1.0))-suspended_native_time-0.25)<0.002,"resumed native observation advances only its new scheduled time")
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
	var fresh_supply := Presentation.attach_activity_tool(actor,"supply")
	_check(is_instance_valid(fresh_supply) and not permanent.visible and not permanent.is_queued_for_deletion(), "first scheduled carry releases an existing same-hand hammer without deleting it")
	if is_instance_valid(fresh_supply): fresh_supply.free()
	permanent_socket.bone_name = "hand_l"
	permanent.visible = true
	var opposite_supply := Presentation.attach_activity_tool(actor,"supply")
	_check(is_instance_valid(opposite_supply) and permanent.visible, "activity attachment preserves equipment owned by the opposite hand")
	if is_instance_valid(opposite_supply): opposite_supply.free()
	permanent_socket.bone_name = "hand_r"
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
	_verify_measured_grips()
	await _verify_authored_head()
	_finish(actor)

func _verify_story_station_owner(driver: Node, actor: Node3D) -> void:
	var owner := WorkstationOwner.new()
	actor.add_child(owner)
	driver.set_story_workstation_owner(owner)
	owner.available = true
	_check(not driver.supports_story_workstation("vale"), "physical ledger eligibility alone cannot replace a missing native settle clip")
	driver.resolved_clip_map["story_settle_ledger"] = &"life/Life_Work"
	_check(driver.supports_story_workstation("vale"), "a bound native cue consults the existing routine's physical station owner")
	driver.clear_life_activity()
	_check(driver.supports_story_workstation("vale"), "dialogue can release the ambient pose without losing station availability")
	owner.available = false
	_check(not driver.supports_story_workstation("vale"), "busy or removed station geometry disables the native personal cue")
	owner.available = true
	_check(not driver.supports_story_workstation("merrow"), "another actor's task cannot authorize a ledger gesture")
	driver.distance_suspended = true
	_check(not driver.supports_story_workstation("vale"), "distance-suspended actors cannot acquire physical story work")
	driver.distance_suspended = false
	driver.dead = true
	_check(not driver.supports_story_workstation("vale"), "terminal actors cannot acquire physical story work")
	driver.dead = false
	owner.free()
	_check(not driver.supports_story_workstation("vale"), "a destroyed routine owner cannot leave a stale station capability")
	driver.set_story_workstation_owner(null)
	driver.resolved_clip_map.erase("story_settle_ledger")

func _verify_authored_head() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	actor.add_child(skeleton)
	for bone: String in ["Head","hand_r"]: skeleton.add_bone(bone)
	var head_script := preload("res://scripts/story_head_modifier.gd")
	for control: String in head_script.FACE_CONTROLS:
		skeleton.add_bone("Face_"+control)
		skeleton.set_bone_parent(skeleton.get_bone_count()-1,0)
	var mesh := MeshInstance3D.new()
	mesh.name = "NativeHeadBody"
	mesh.mesh = BoxMesh.new()
	actor.add_child(mesh)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var native_head := Quaternion.from_euler(Vector3(-0.16,0.08,0.04))
	var library := AnimationLibrary.new()
	for name: String in ["Idle","Life_Drink","Life_Cup_Hold"]:
		var clip := Animation.new()
		clip.length = 4.0
		clip.loop_mode = Animation.LOOP_NONE if name == "Life_Drink" else Animation.LOOP_LINEAR
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath("Skeleton3D:Head"))
		clip.rotation_track_insert_key(track,0.0,native_head)
		clip.rotation_track_insert_key(track,4.0,native_head)
		library.add_animation(name,clip)
	player.add_animation_library("life",library)
	var driver := Driver.new()
	actor.add_child(driver)
	_check(driver.configure(actor,{"idle":"life/Idle","death":"life/Idle","story_drink":"life/Life_Drink","story_cup_hold":"life/Life_Cup_Hold"}),"sip ownership fixture binds a native head clip")
	driver.set_external_tick(true)
	driver.life_extra_clips = {"drink":"Life_Drink","cup_hold":"Life_Cup_Hold"}
	var face := preload("res://scripts/character_face_driver.gd").new()
	actor.add_child(face)
	_check(face.configure(actor,"synthetic_merrow"),"sip ownership fixture binds the actual face owner")
	face.set_conversation_active(true)
	face.set_focus_point(Vector3(2,1,-2))
	face.set_expression("concerned")
	var attention := face.capture_attention()
	driver.set_dialogue_pose(true)
	driver.play_story_gesture("drink")
	_check(not driver.owns_authored_head_pose(),"an unbound cup cannot acquire the native head")
	_bind_fixture_cup(driver,skeleton)
	driver.play_story_gesture("drink")
	_check(driver.owns_authored_head_pose(),"the actual bound cup and native sip acquire head rotation")
	await process_frame
	face.update_timer.stop()
	var head: Node = face.head_modifier
	head.current_yaw = 0.22
	head.current_pitch = 0.27
	head.current_roll = 0.09
	head.look_yaw = 0.24
	head.attention_pitch = 0.2
	head.blink_closure = 0.8
	head.speech_amount = 0.25
	head.gesture("disagree")
	skeleton.set_bone_pose_rotation(0,native_head)
	head._process_modification()
	_check(skeleton.get_bone_pose_rotation(0).is_equal_approx(native_head),"gaze, mood and a concurrent gesture cannot move the calibrated sip head")
	_check(skeleton.get_bone_pose_position(skeleton.find_bone("Face_LidUpper_L")).y<0.0,"blink remains eligible during a native sip")
	_check(head.expression_weights.length()>0.0 and head.current_speech>0.0,"expression and jaw delivery remain eligible during a native sip")
	_check(face.attention_mode==attention.mode and face.focus_point==attention.point and face.expression==attention.expression,"native head ownership leaves the complete attention intent intact")
	for tick in 100: driver.advance_external(0.05)
	_check(not driver.owns_authored_head_pose() and driver._holding_story_cup(),"sip completion releases the head while retaining the scene's cup hold")
	skeleton.set_bone_pose_rotation(0,native_head)
	head.current_yaw = 0.2
	head._process_modification()
	_check(not skeleton.get_bone_pose_rotation(0).is_equal_approx(native_head),"ordinary additive attention resumes after the sip")
	for interruption: String in ["cancel","distance","death","restore"]:
		driver.set_distance_suspended(false)
		driver.reset_for_journey_restore()
		driver.set_dialogue_pose(true)
		_bind_fixture_cup(driver,skeleton)
		driver.play_story_gesture("drink")
		_check(driver.owns_authored_head_pose(),"sip reacquires before "+interruption)
		match interruption:
			"cancel": driver.stop_story_gesture()
			"distance": driver.set_distance_suspended(true)
			"death": driver.set_dead()
			"restore": driver.reset_for_journey_restore()
		_check(not driver.owns_authored_head_pose(),interruption+" immediately releases native head ownership")
	actor.free()

func _bind_fixture_cup(driver: Node, skeleton: Skeleton3D) -> void:
	# Physical calibration belongs to the native asset fixture. This tiny cup
	# exercises the real attachment/action lifetime without loading that pack.
	var cup := BoneAttachment3D.new()
	cup.bone_name = "hand_r"
	cup.bone_idx = skeleton.find_bone("hand_r")
	cup.set_meta("kind","cup")
	skeleton.add_child(cup)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	cup.add_child(mesh)
	driver.story_prop = cup

func _settle_graph_branch(driver: Node, expected: String) -> bool:
	var playback: AnimationNodeStateMachinePlayback = driver.animation_graph.playback
	for tick in 80:
		driver.advance_external(0.025)
		if str(playback.get_current_node()) == expected and str(playback.get_fading_from_node()).is_empty() and playback.get_travel_path().is_empty():
			print("LIVING CAST GRAPH SETTLED: "+JSON.stringify({"expected":expected,"ticks":tick+1,"native_time":playback.get_current_play_position()}))
			return true
	print("LIVING CAST GRAPH UNSETTLED: "+JSON.stringify({"expected":expected,"current":playback.get_current_node(),"from":playback.get_fading_from_node(),"travel":playback.get_travel_path(),"requested":driver.animation_graph.requested,"active":driver.animation_graph.active_state}))
	return false

func _print_prop_graph(driver: Node, stage: String) -> void:
	var playback: AnimationNodeStateMachinePlayback = driver.animation_graph.playback
	print("LIVING CAST PROP GRAPH: "+JSON.stringify({"stage":stage,"current":playback.get_current_node(),"from":playback.get_fading_from_node(),"fade_length":playback.get_fading_length(),"fade_position":playback.get_fading_position(),"eligible":driver.activity_prop_pose_ready()}))

func _verify_measured_grips() -> void:
	var actor := Node3D.new()
	actor.scale=Vector3.ONE*1.25
	root.add_child(actor)
	var skeleton := Skeleton3D.new()
	actor.add_child(skeleton)
	for side: String in ["l","r"]:
		skeleton.add_bone("hand_"+side)
		var bone := skeleton.find_bone("hand_"+side)
		skeleton.set_bone_rest(bone,Transform3D(Basis(Vector3.UP,0.3),Vector3(0.1,0.9,0)))
	skeleton.reset_bone_poses()
	var record := {"verified":true,"source_sha256":"0".repeat(64),"bone":"hand_r","palm":Vector3(0.02,0.04,-0.01),"anchor":Vector3(0,0.115,0.0015),"basis":Basis.IDENTITY}
	actor.set_meta("activity_prop_grips",{"cloth":record})
	var socket := Presentation.attach_activity_tool(actor,"cloth") as BoneAttachment3D
	_check(socket!=null and socket.has_meta("measured_grip"),"measured activity grip binds on a scaled real hand socket")
	if socket!=null:
		var grip := socket.get_child(0) as Node3D
		var visual := grip.get_child(0) as MeshInstance3D
		var frame := skeleton.global_transform*skeleton.get_bone_global_pose(socket.bone_idx)
		var physical := frame*grip.transform*visual.transform
		_check((physical*(record.anchor as Vector3)).distance_to(frame*(record.palm as Vector3))<0.001,"actual cloth surface anchor meets the measured palm")
		_check(physical.basis.get_scale().is_equal_approx(Vector3.ONE),"measured grip does not resize the retained activity mesh")
	var supply := record.duplicate()
	supply.anchor=Vector3(0.0514,0.115,0)
	var library := AnimationLibrary.new()
	library.set_meta("activity_prop_grips",{"supply":supply})
	var owner_driver := Driver.new()
	actor.add_child(owner_driver)
	owner_driver.character_root=actor
	owner_driver.skeleton=skeleton
	owner_driver._bind_equipment_grips(library)
	_check(owner_driver.contract_errors.is_empty() and actor.get_meta("activity_prop_grips",{}).has("supply"),"scheduled supply vessels accept the same verified calibration contract")
	var supply_socket := Presentation.attach_activity_tool(actor,"supply") as BoneAttachment3D
	_check(supply_socket!=null and supply_socket.has_meta("measured_grip"),"supply calibration binds an actual retained vessel surface vertex")
	var invalid := record.duplicate()
	invalid.basis=Basis.IDENTITY.scaled(Vector3(2,1,1))
	_check(Presentation.grip_record_error(skeleton,invalid)!="","calibration cannot introduce prop scaling")
	actor.scale=Vector3(1.25,1.35,1.25)
	_check(Presentation.grip_record_error(skeleton,record)!="","unexpected nonuniform hand ancestry rejects calibration")
	actor.scale=Vector3.ONE*1.25
	Presentation._add_castle_role_equipment(actor,"vargan_record_keeper")
	var equipment := actor.find_child("CastleRoleEquipment",true,false) as Node3D
	var book := equipment.get_node("VarganRecordBook") as MeshInstance3D
	var clasp := equipment.get_node("VarganRecordBookClasp") as Node3D
	var relative_clasp := clasp.position-book.position
	var dimensions := book.mesh.get_aabb().size
	var carried := {"kind":"book","verified":true,"source_sha256":"0".repeat(64),"bone":"hand_l","palm":Vector3(-0.02,0.04,-0.01),"anchor":Vector3(-0.13,0,0),"basis":book.basis}
	_check(Presentation.fit_carried_equipment(actor,carried),"measured carried book attaches its physical spine edge")
	var book_socket := equipment.get_parent() as BoneAttachment3D
	var hand_frame := skeleton.global_transform*skeleton.get_bone_global_pose(book_socket.bone_idx)
	var actual := hand_frame*equipment.transform*book.transform*(carried.anchor as Vector3)
	_check(actual.distance_to(hand_frame*(carried.palm as Vector3))<0.001,"book spine anchor meets the actual hand branch")
	_check(book.mesh.get_aabb().size==dimensions and (clasp.position-book.position).is_equal_approx(relative_clasp),"book fitting retains its dimensions and clasp placement")
	var fitted := book.transform
	_check(Presentation.fit_carried_equipment(actor,carried) and book.transform.is_equal_approx(fitted),"carried book fitting is idempotent")
	actor.free()

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
