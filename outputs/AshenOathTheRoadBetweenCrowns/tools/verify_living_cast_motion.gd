extends SceneTree

## Actual prepared people and their Blender-authored libraries. No game world,
## journey or save manager is constructed; all animation clocks are explicit.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")
const Profile = preload("res://scripts/story_cast_profile.gd")
const Stations = preload("res://scripts/living_cast_stations.gd")
const Routine = preload("res://scripts/greyfen_life_controller.gd")
const Player = preload("res://scripts/player_controller.gd")
const CASES := {
	"sister_anwen_human":"care", "blacksmith_tor":"forge", "mira_human":"sort_herbs", "rook_human":"check_supplies",
	"nessa":"bake", "widow_elna":"fold_cloth", "farmer_toma":"tend", "saga_nera":"check_rope",
	"captain_senn":"watch", "vargan_record_keeper":"read", "vargan_steward":"check_supplies", "edric":"review_dispatch"
}
var failures: Array[String] = []
var checks := 0
var helper: Node
var station_host: StationHost
var validate_equipment := true

class StationHost extends Node3D:
	var zone_root := Node3D.new()
	func validate_walkable_position(point: Vector3) -> Vector3: return point

class IsolatedPlayer extends Player:
	func _ready() -> void:
		set_physics_process(false)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var selected: Array[String] = []
	selected.assign(CASES.keys())
	var include_player := true
	for argument in OS.get_cmdline_user_args():
		if argument == "--skip-player": include_player = false
		elif argument == "--motion-only": validate_equipment = false
		elif argument.begins_with("--roles="):
			selected.clear()
			for role: String in argument.trim_prefix("--roles=").split(",", false):
				if not CASES.has(role) or selected.has(role):
					printerr("LIVING CAST MOTION: unknown or duplicate requested role " + role)
					quit(1)
					return
				selected.append(role)
	if selected.is_empty():
		printerr("LIVING CAST MOTION: role subset must not be empty")
		quit(1)
		return
	print("LIVING CAST SCOPE: " + JSON.stringify({"roles":selected,"player":include_player,"equipment_validation_deferred":not validate_equipment,"complete_cast":selected.size()==CASES.size() and include_player and validate_equipment}))
	helper = Helper.new()
	root.add_child(helper)
	station_host = StationHost.new()
	root.add_child(station_host)
	station_host.add_child(station_host.zone_root)
	_build_stations(selected)
	for role: String in selected:
		await _actor(role, CASES[role])
	if include_player: await _player_idle()
	helper.free()
	station_host.free()
	for failure in failures:
		printerr("LIVING CAST MOTION: " + failure)
	print("LIVING CAST MOTION: %s checks=%d actors=%d player=%s equipment_validation_deferred=%s complete_cast=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, selected.size(),str(include_player),str(not validate_equipment),str(selected.size()==CASES.size() and include_player and validate_equipment)])
	quit(0 if failures.is_empty() else 1)

func _player_idle() -> void:
	var visual: Node3D = helper.spawn_visual_role("player_human","characters")
	_check(visual != null,"P01 actual retained player loads")
	if visual == null: return
	var controller := IsolatedPlayer.new()
	root.add_child(controller)
	controller.visual_root=Node3D.new()
	controller.add_child(controller.visual_root)
	controller.visual_root.add_child(visual)
	controller._mapped_body=visual
	controller.asset_helper=helper
	var driver := Driver.new()
	visual.add_child(driver)
	controller.animation_driver=driver
	var configured := driver.configure(visual,controller._animation_map_for_visual(visual))
	_check(configured and driver.life_idle_only,"P01 binds only the two authored relaxation clips")
	if not configured:
		controller.free()
		return
	driver.set_external_tick(true)
	var before := visual.transform
	var attacks: Dictionary = {}
	for state: String in ["attack_light","attack_heavy","draw","sheath","hit","death"]:
		attacks[state]=driver.get_clip_for_state(state)
	driver.set_relaxed_idle(true)
	var first := driver.life_clip
	for tick in 180: driver.advance_external(0.05)
	_check(first != driver.life_clip and str(driver.life_clip).begins_with("life/Life_Idle_"),"P01 alternates complete idle performances only at a loop boundary")
	_check(visual.transform.is_equal_approx(before),"P01 relaxation retains the actual locomotion root")
	driver.set_relaxed_idle(false)
	_check(driver.life_clip == StringName(),"drawing equipment restores retained player animation ownership")
	for state: String in attacks:
		_check(driver.get_clip_for_state(state)==attacks[state],"P01 relaxation never remaps "+state)
	_check(driver.trigger_action("attack_light",1.0,0.10,true,0.34),"P01 retains its actual light attack")
	driver.set_relaxed_idle(true)
	_check(driver.action_active and driver.life_clip==StringName() and is_equal_approx(driver.action_duration,0.34),"relaxation cannot replace or retime an attack")
	driver.set_dead()
	driver.set_relaxed_idle(true)
	_check(driver.dead and driver.life_clip==StringName(),"terminal P01 cannot restart relaxation")
	driver.reset_for_journey_restore()
	_check(not driver.dead and driver.life_clip==StringName(),"player restoration clears relaxed presentation")
	controller._build_bow_visual()
	_verify_bow_size(controller)
	controller.free()
	await process_frame

func _verify_bow_size(player: Node3D) -> void:
	var hand_model := player.bow_visual.get_node_or_null("KaelBowModeled") as Node3D if player.bow_visual != null else null
	var back_model := player.bow_back_visual.get_child(0) as Node3D if player.bow_back_visual != null and player.bow_back_visual.get_child_count()>0 else null
	_check(hand_model != null and back_model != null,"actual retained bow exists in both hand and back owners")
	if hand_model == null or back_model == null: return
	var back_span := _projected_extent(back_model,player.bow_back_visual.global_basis.y.normalized())
	player.equipment_loadout.set_active_weapon("bow")
	_check(player.weapon_mode=="bow" and player.is_bow_pose_active() and player.equipment_left_arm_ik!=null and player.bow_presentation!=null,"bow size regression exercises the real transfer and archery owners")
	if player.equipment_left_arm_ik==null or player.bow_presentation==null: return
	for weight: float in [0.0,0.5,1.0]:
		var frame: Transform3D = player._equipment_anchor_world(player.bow_back_visual)
		player._update_bow_equipment_reach({"position":frame.origin,"basis":frame.basis.orthonormalized(),"weight":weight})
		var span := _projected_extent(hand_model,player.bow_visual.global_basis.y.normalized())
		_check(absf(span-back_span)<0.001,"retained bow keeps physical size through transfer weight "+str(weight))
	player.equipment_left_arm_ik.stop()
	player.bow_presentation._process_modification()
	_check(player.bow_pose_valid,"actual archery pose ran before measuring its displayed bow")
	var active_span := _projected_extent(hand_model,player.bow_visual.global_basis.y.normalized())
	_check(absf(active_span-back_span)<0.001,"active archery cannot resize the bow after the draw handoff")
	_check(not player.equipment_loadout.is_transitioning(),"visual size correction does not start an equipment transaction")

func _projected_extent(node: Node3D, axis: Vector3) -> float:
	var low := INF
	var high := -INF
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or str(mesh.name).to_lower().contains("arrow"): continue
		for point: Vector3 in mesh.mesh.get_faces():
			var projected := (mesh.global_transform*point).dot(axis)
			low=minf(low,projected); high=maxf(high,projected)
	return high-low if is_finite(low) and is_finite(high) else 0.0

func _actor(role: String, occupation: String) -> void:
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	_check(visual != null, role + " actual prepared actor loads")
	if visual == null: return
	root.add_child(visual)
	Presentation.apply_npc(visual, role, false)
	var driver := Driver.new()
	driver.name = "CharacterAnimationDriver"
	visual.add_child(driver)
	var configured := driver.configure(visual, {"idle":"Idle", "walk":"Walking", "run":"Running", "dialogue":"Interact", "hit":"HitReact", "death":"Death"})
	_check(configured, role + " real motion owner binds: " + str(driver.contract_errors))
	if not configured:
		visual.free()
		return
	driver.set_external_tick(true)
	print("LIVING CAST ACTOR: " + JSON.stringify({"role":role, "bones":driver.skeleton.get_bone_count(), "source":visual.get_meta("prepared_actor_source", ""), "fitted_staff":driver.life_modifier.anwen_staff_pose}))
	var workstation := _workstation(role, occupation)
	if driver.life_requires_station and workstation.is_empty():
		# The failed station assertion is authoritative. Sampling the fallback
		# idle here would misdiagnose missing geometry as a native Work defect.
		visual.free()
		return
	if not workstation.is_empty():
		visual.global_position = workstation.stand
		var forward: Vector3 = workstation.get("look", workstation.point) - visual.global_position
		forward.y = 0.0
		visual.rotate_y(driver.get_visible_forward().signed_angle_to(forward.normalized(), Vector3.UP))
	if role == "sister_anwen_human":
		var staff_socket := visual.find_child("AnwenStaffSocket", true, false) as BoneAttachment3D
		_check(staff_socket != null and str(staff_socket.bone_name) == "hand_r", "Anwen staff owns the actual right hand on the retained rig")
		var care_tool := Presentation.attach_activity_tool(visual, "cloth") as BoneAttachment3D
		_check(care_tool != null and str(care_tool.bone_name) == "hand_l", "Anwen care cloth uses the free left hand while her right hand owns the staff")
		if care_tool != null: care_tool.free()
	var original_root := visual.transform
	if not workstation.is_empty():
		driver.set_life_activity(occupation)
		driver.set_life_workstation(workstation)
		for tick in 40: driver.advance_external(0.05)
		driver.life_modifier.pose_weight = 1.0
		driver.life_modifier._process_modification()
		for side: String in ["l", "r"]:
			if role == "sister_anwen_human" and side == "r" or role == "blacksmith_tor" and side == "l": continue
			var sample: Dictionary = driver.life_modifier.last_contact_samples.get("left" if side == "l" else "right", {})
			var expected := "cloth" if role == "sister_anwen_human" else ("hammer" if role == "blacksmith_tor" else "palm")
			print("LIVING CAST CONTACT: " + JSON.stringify({"role":role, "side":side, "sample":sample}))
			_check(str(sample.get("kind", "")) == expected, "%s %s contact measures the actual %s probe" % [role, side, expected])
			_check(float(sample.get("error", INF)) <= 0.06, "%s native %s %s reaches actual supported contact: %.4fm" % [role, side, expected, float(sample.get("error", INF))])
			if expected == "palm":
				_check(float(sample.get("error", INF)) <= 0.006, "%s native %s calibrated palm meets the physical surface within 6mm: %.4fm" % [role, side, float(sample.get("error", INF))])
		if role in ["mira_human", "rook_human"]:
			_check(not is_instance_valid(driver.life_modifier.tool) or not driver.life_modifier.tool.visible, role + " uses real station objects without an intersecting generic held prop")
		if role == "sister_anwen_human":
			_verify_staff(visual, driver)
		if role == "blacksmith_tor":
			var repair_station := workstation.duplicate()
			repair_station.activity="repair"
			repair_station.surface_prop="SupportedRepairBeam"
			repair_station.held_tool=true
			driver.set_life_workstation(repair_station)
			driver.set_life_activity("repair")
			for tick in 40: driver.advance_external(0.05)
			driver.life_modifier.pose_weight=1.0
			driver.life_modifier._process_modification()
			var repair_sample: Dictionary = driver.life_modifier.last_contact_samples.get("right",{})
			_check(is_instance_valid(driver.life_modifier.tool) and driver.life_modifier.tool.visible,"Tor keeps the actual hammer when repairing a supported beam")
			_check(str(repair_sample.get("kind",""))=="hammer" and float(repair_sample.get("error",INF))<=0.06,"repair alias measures the retained hammer head, not the wrist")
		driver.clear_life_activity()
	var rest_poses: Array[Transform3D] = []
	for index in driver.skeleton.get_bone_count():
		rest_poses.append(driver.skeleton.get_bone_rest(index))
	for name: String in ["Life_Idle_A", "Life_Idle_B", "Life_Work", "Life_Listen", "Life_Speak"]:
		_check(driver.animation_player.has_animation("life/" + name), role + " owns " + name)
		_check(int(driver.bound_track_counts.get("life/" + name, 0)) > 0, role + " has bound native tracks for " + name)
	if driver.life_library_path == "":
		_check(false, role + " required performance library was not loaded")
		visual.free()
		return
	for hz: float in [20.0, 30.0, 60.0, 144.0]:
		driver.clear_life_activity()
		driver.set_life_workstation(workstation)
		driver.set_life_activity(occupation)
		var poses: Array = []
		for sample in range(int(hz * 4.0)):
			driver.advance_external(1.0 / hz)
			if sample % maxi(1, int(hz)) == 0: poses.append(_pose(driver.skeleton))
		var clock := driver.life_motion_sample()
		_check(not clock.is_empty() and absf(float(clock.get("elapsed", -1.0)) - 4.0) < 0.002, role + " work clock independent of update rate " + str(hz))
		_check(poses.size() >= 4 and poses[0] != poses[1] and poses[1] != poses[2], role + " native work has distinct anticipation/contact/recovery poses " + str(hz))
		_check(visual.transform.is_equal_approx(original_root), role + " native work never translates/turns the root")
	driver.set_life_activity("idle")
	var first_idle := driver.life_clip
	for tick in 200: driver.advance_external(0.05)
	_check(driver.life_clip != first_idle, role + " alternates two authored idles at cycle boundaries")
	driver.set_life_workstation(workstation)
	driver.set_life_activity(occupation)
	driver.advance_external(0.25)
	var before_suspend := driver.life_elapsed
	driver.set_distance_suspended(true)
	driver.advance_external(3.0)
	_check(is_equal_approx(driver.life_elapsed, before_suspend), role + " distance suspension freezes native work clock")
	driver.set_distance_suspended(false)
	driver.advance_external(0.25)
	_check(is_equal_approx(driver.life_elapsed, before_suspend + 0.25), role + " native work resumes without catch-up contacts")
	if role == "sister_anwen_human" or Profile.canonical_identity(role) in Stations.STAGE_TWO or role == "captain_senn":
		driver.clear_life_activity()
		driver.set_life_activity("sleep")
		driver.advance_external(0.25)
		var stand := visual.global_position
		var seat := stand - driver.get_visible_forward() * 0.64 + Vector3.UP * 0.54
		driver.set_life_rest_anchor({"stand":stand, "seat":seat, "kind":"seated"})
		driver.life_modifier.pose_weight = 1.0
		driver.life_modifier._pose_supported_sleep(driver.skeleton)
		var pelvis := driver.skeleton.find_bone("pelvis")
		_check(driver.life_modifier._world(driver.skeleton, pelvis).distance_to(seat + Vector3.UP * 0.12) < 0.025, "supported dozing hips rest above the real seat")
		for leg: Dictionary in driver.life_modifier.seated_legs:
			var foot: Vector3 = driver.life_modifier._world(driver.skeleton, int(leg.foot))
			print("LIVING CAST REST: " + JSON.stringify({"side":leg.side,"foot":foot,"expected_height":stand.y + 0.095}))
			_check(absf(foot.y - (stand.y + 0.095)) < 0.025, "supported dozing retains grounded foot height " + str(leg.side))
		_check(visual.transform.is_equal_approx(original_root), "supported dozing never moves the locomotion root")
	driver.set_dialogue_pose(true)
	_check(driver.life_clip == StringName() and driver.life_modifier.station.is_empty() and driver.life_modifier.rest_anchor.is_empty(), role + " dialogue clears work clip, station and seated support")
	for gesture: String in Driver.LIFE_STORY_GESTURES:
		driver.stop_action()
		driver.set_dialogue_pose(true)
		driver.play_story_gesture(gesture)
		_check(driver.action_active, role + " native body gesture " + gesture)
		driver.advance_external(0.2)
		if role == "sister_anwen_human":
			driver.life_modifier._process_modification()
			_verify_staff(visual, driver)
	if role == "vargan_steward":
		_check(driver.supports_story_prop("cup"), "Merrow cup requires actual measured grip and native drink clip")
		_check(driver.set_story_prop("cup"), "Merrow binds actual cup to a valid hand socket")
		driver.stop_action()
		driver.set_dialogue_pose(true)
		driver.play_story_gesture("drink",1.0)
		_check(driver.action_active and driver.active_action_clip == &"life/Life_Drink", "Merrow uses authored sip, never a generic gesture")
		for tick in 240:
			driver.advance_external(0.01)
			if driver.animation_graph.playback.get_current_node()==&"story_drink" and driver.animation_graph.playback.get_current_play_position()>=2.0-0.00001: break
		_check(absf(driver.animation_graph.playback.get_current_play_position()-2.0)<0.011,"Merrow contact check samples the actual sip phase")
		_verify_story_cup(driver)
		var cup: Node3D = driver.story_prop
		driver.set_distance_suspended(true)
		_check(not is_instance_valid(driver.story_prop) and not cup.visible, "distance interruption removes the action-owned cup immediately")
		driver.set_distance_suspended(false)
	if role == "vargan_record_keeper":
		# Bind the real routine owner and physical station rather than allowing
		# this extra cue merely because an animation exists in the library.
		visual.reparent(station_host.zone_root, true)
		var scene_owner := Routine.new()
		scene_owner.host = station_host
		station_host.zone_root.add_child(scene_owner)
		scene_owner.set_process(false)
		scene_owner.set_physics_process(false)
		scene_owner.actors = [{"id":"vargan_record_keeper", "node":visual, "driver":driver}]
		driver.set_story_workstation_owner(scene_owner)
		_check(driver.supports_story_workstation("vale"), "Vale's cue requires its actual source-verified station ledger")
		driver.stop_action()
		driver.set_dialogue_pose(true)
		driver.play_story_gesture("settle_ledger", 1.0)
		_check(driver.action_active and driver.active_action_clip == &"life/Life_Settle_Ledger", "Vale owns the authored desk-ledger transition")
		for tick in 240:
			driver.advance_external(0.01)
			if driver.animation_graph.playback.get_current_node() == &"story_settle_ledger" and driver.animation_graph.playback.get_current_play_position() >= 2.0-0.00001: break
		_check(absf(driver.animation_graph.playback.get_current_play_position()-2.0)<0.011, "Vale's supported cue check samples its actual authored contact phase")
		driver.skeleton.force_update_all_bone_transforms()
		for side: String in ["left", "right"]:
			var bone: int = driver.skeleton.find_bone("hand_l" if side == "left" else "hand_r")
			var probe: Vector3 = driver.life_contact_probes.get(side,Vector3.INF)
			_check(bone >= 0 and probe.is_finite(), "Vale's cue resolves the source-measured open " + side + " palm")
			if bone < 0 or not probe.is_finite(): continue
			var palm: Vector3 = driver.skeleton.global_transform * driver.skeleton.get_bone_global_pose(bone) * probe
			var error := palm.distance_to(workstation[side])
			print("LIVING CAST LEDGER: " + JSON.stringify({"side":side,"native_time":driver.animation_graph.playback.get_current_play_position(),"error":error}))
			_check(error <= 0.006, "Vale's native " + side + " palm settles on the physical ledger within 6mm: " + str(error))
		driver.set_story_workstation_owner(null)
		scene_owner.actors.clear()
		scene_owner.free()
	driver.stop_story_gesture()
	if driver.life_requires_station:
		driver.set_life_workstation({})
		driver.set_life_activity(occupation)
		_check(driver.life_clip != &"life/Life_Work", role + " waits without miming work when its station is unavailable")
		driver.set_life_workstation(workstation)
		_check(driver.life_clip == &"life/Life_Work", role + " acquiring its real station starts the native sequence")
	driver.set_life_activity(occupation)
	driver.set_locomotion_motion(Vector3(1, 0, 0), true)
	_check(driver.life_clip == StringName() and driver.presentation_state == "", role + " actual locomotion interrupts planted work")
	driver.set_dead()
	driver.set_life_activity(occupation)
	_check(driver.dead and driver.life_clip == StringName(), role + " death prevents life restarting")
	driver.reset_for_journey_restore()
	_check(not driver.dead and driver.life_clip == StringName(), role + " journey restoration clears transient native work")
	_verify_held_grips(visual,driver,role)
	for index in driver.skeleton.get_bone_count():
		_check(driver.skeleton.get_bone_rest(index).is_equal_approx(rest_poses[index]), role + " retains bone rest " + str(index))
	visual.free()
	await process_frame

func _verify_story_cup(driver: Node) -> void:
	var socket: BoneAttachment3D = driver.story_prop
	_check(is_instance_valid(socket) and socket.get_child_count()==1,"native cup has one action-owned visual")
	if not is_instance_valid(socket) or socket.get_child_count()!=1: return
	var visual := socket.get_child(0) as Node3D
	var grip := visual.get_node_or_null("ActualHandleGrip") as Marker3D
	var rim := visual.get_node_or_null("ActualDrinkingRim") as Marker3D
	var lip: Dictionary = visual.get_meta("lip_probe",{})
	var grip_probe: Dictionary = visual.get_meta("grip_probe",{})
	_check(grip!=null and rim!=null and not lip.is_empty() and not grip_probe.is_empty(),"native cup exposes source-measured physical handle, closed palm, rim and lip probes")
	if grip==null or rim==null or lip.is_empty() or grip_probe.is_empty(): return
	var skeleton: Skeleton3D = driver.skeleton
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)
	var cup_frame := hand * socket.transform * visual.transform
	var actual_grip := cup_frame * grip.position
	var actual_rim := cup_frame * rim.position
	var palm: Vector3 = grip_probe.get("point",Vector3.INF)
	var bone := skeleton.find_bone(str(lip.get("bone","")))
	var cup_hand_matches := str(grip_probe.get("bone","")) == str(socket.bone_name)
	_check(bone>=0 and palm.is_finite() and cup_hand_matches,"cup contact resolves its own closed-palm hand and retained head bones")
	if bone<0 or not palm.is_finite() or not cup_hand_matches: return
	var actual_lip: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * (lip.point as Vector3)
	var handle_error := actual_grip.distance_to(hand*palm)
	var rim_error := actual_rim.distance_to(actual_lip)
	print("LIVING CAST CUP: "+JSON.stringify({"native_time":driver.animation_graph.playback.get_current_play_position(),"handle_error":handle_error,"rim_error":rim_error,"actual_scale":cup_frame.basis.get_scale()}))
	_check(handle_error<=0.002,"native cup handle meets the measured palm within 2mm: "+str(handle_error))
	_check(rim_error<=0.004,"native cup rim meets the measured head-local lip within 4mm: "+str(rim_error))
	_check(cup_frame.basis.get_scale().is_equal_approx(Vector3.ONE),"native cup retains its physical dimensions through the actual hand ancestry")
	_check(driver.owns_authored_head_pose(),"native sip protects its calibrated head inclination at contact")

func _verify_held_grips(visual: Node3D, driver: Node, role: String) -> void:
	if role in ["nessa","widow_elna","farmer_toma","saga_nera"]:
		var records: Dictionary = visual.get_meta("activity_prop_grips",{})
		if not validate_equipment:
			var missing: Array[String] = []
			for style: String in ["rope","bowl","bread","cloth"]:
				if not records.has(style): missing.append(style)
			print("LIVING CAST EQUIPMENT PENDING: " + JSON.stringify({"role":role,"missing_calibrations":missing,"accepted":false}))
			return
		for style: String in ["rope","bowl","bread","cloth"]:
			_check(records.has(style),role+" has a source-verified "+style+" grip")
			if not records.has(style): continue
			var socket := Presentation.attach_activity_tool(visual,style) as BoneAttachment3D
			_check(socket!=null and socket.has_meta("measured_grip"),role+" binds the measured "+style+" surface")
			if socket==null: continue
			var grip := socket.get_child(0) as Node3D
			var prop := grip.get_child(0) as MeshInstance3D
			var record: Dictionary = records[style]
			var frame: Transform3D = driver.skeleton.global_transform*driver.skeleton.get_bone_global_pose(socket.bone_idx)
			var physical := frame*grip.transform*prop.transform
			var error := (physical*(record.anchor as Vector3)).distance_to(frame*(record.palm as Vector3))
			print("LIVING CAST HELD GRIP: "+JSON.stringify({"role":role,"style":style,"error":error,"scale":physical.basis.get_scale()}))
			_check(error<=0.001 and physical.basis.get_scale().is_equal_approx(Vector3.ONE),role+" "+style+" reaches its real palm without scaling the retained mesh")
			socket.free()

func _pose(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for name: String in ["spine_03", "upperarm_l", "upperarm_r", "hand_l", "hand_r"]:
		var index := skeleton.find_bone(name)
		if index >= 0: result.append(skeleton.get_bone_pose(index))
	return result

func _build_stations(selected: Array[String]) -> void:
	if "sister_anwen_human" in selected:
		_check(Stations.add_care_table(station_host.zone_root) != null, "real retained care table loads")
	for id: String in ["mira_apothecary", "common_table"]:
		if ("mira_human" if id == "mira_apothecary" else "rook_human") not in selected: continue
		var area := Node3D.new()
		area.name = id
		station_host.zone_root.add_child(area)
		var visual := MeshInstance3D.new()
		visual.name = "GreyfenSocialFurniture"
		visual.mesh = load("res://assets_external/environment/props/GreyfenSocial_%s.res" % id) as ArrayMesh
		area.add_child(visual)
		_check(visual.mesh != null, id + " actual supporting furniture loads")
		Stations.decorate_place(area, id)
	if "blacksmith_tor" in selected:
		var forge := MeshInstance3D.new()
		forge.name = "BlacksmithFittedWork"
		forge.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
		station_host.zone_root.add_child(forge)
		_check(forge.mesh != null, "real authored anvil loads")
	var identities: Array[String] = []
	for role: String in selected: identities.append(Profile.canonical_identity(role))
	var index := 0
	for identity: String in Stations.STAGE_TWO:
		if identity not in identities:
			index += 1
			continue
		var work := Stations._add_regional_work(station_host, identity, [30.0+float(index)*3.0,0,0], "")
		_check(work != null, identity + " retained table and authored task prop load")
		index += 1

func _verify_staff(actor: Node3D, driver: Node) -> void:
	var modeled := actor.find_child("AnwenStaffModeled", true, false) as Node3D
	var meshes := modeled.find_children("*", "MeshInstance3D", true, false) if modeled != null else []
	if modeled is MeshInstance3D: meshes.push_front(modeled)
	_check(not meshes.is_empty(), "Anwen retains the actual modeled ash staff")
	if meshes.is_empty(): return
	var mesh := meshes[0] as MeshInstance3D
	var local := Transform3D.IDENTITY
	var cursor: Node3D = mesh
	while cursor != null and not cursor is BoneAttachment3D:
		local = cursor.transform * local
		cursor = cursor.get_parent() as Node3D
	var socket := cursor as BoneAttachment3D
	_check(socket != null and str(socket.bone_name) == "hand_r", "staff geometry is rooted in the retained right-hand socket")
	if socket == null: return
	var frame: Transform3D = driver.skeleton.global_transform * driver.skeleton.get_bone_global_pose(socket.bone_idx) * local
	var shaft := frame.basis.y.normalized()
	var bounds := mesh.mesh.get_aabb()
	var tip := frame * Vector3(0, bounds.position.y, 0)
	var grip := frame.origin
	var hand: Vector3 = driver.life_modifier._world(driver.skeleton, socket.bone_idx)
	print("LIVING CAST STAFF: " + JSON.stringify({"state":driver.current_state,"socket":socket.bone_name,"up_dot":shaft.dot(Vector3.UP),"tip_height_error":tip.y-actor.global_position.y,"grip_error":grip.distance_to(hand),"plant_error":tip.distance_to(driver.life_modifier.staff_tip),"tip":tip}))
	_check(shaft.dot(Vector3.UP) > 0.985, "Anwen's sampled staff shaft is upright rather than horizontal")
	_check(absf(tip.y - actor.global_position.y) < 0.025, "Anwen's actual staff tip contacts ground without hovering or penetration")
	_check(grip.distance_to(hand) < 0.065, "Anwen's real shaft grip remains inside the fitted palm socket")
	_check(tip.distance_to(driver.life_modifier.staff_tip) < 0.04, "actual modeled staff tip agrees with the planted support target")

func _workstation(role: String, occupation: String) -> Dictionary:
	if role == "captain_senn": return {}
	var id: String = {"sister_anwen_human":"sister_anwen", "blacksmith_tor":"blacksmith_tor", "mira_human":"mira", "rook_human":"rook", "nessa":"saga_nessa"}.get(role, role)
	var definition: Dictionary = Profile.WORKSTATIONS[id]
	var node := station_host.zone_root.find_child(str(definition.node), true, false) as Node3D
	_check(node != null, role + " real workstation exists")
	if node == null: return {}
	var stand: Vector3 = node.to_global(definition.get("stand", Vector3.ZERO))
	if bool(definition.get("markers", false)):
		stand = (node.get_node("WorkStand") as Marker3D).global_position
	var profile := {"station":definition, "activities":[occupation]}
	var path: Array = [stand]
	var routine := Routine.new()
	routine.host = station_host
	routine._bind_workstation(profile, path)
	routine.free()
	var result: Dictionary = profile.workstation
	_check(not result.is_empty(), role + " retained routine owner accepts physical workstation")
	if not result.is_empty(): result.stand = path[0]
	return result

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
