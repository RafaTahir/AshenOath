extends SceneTree

## Actual prepared people and their Blender-authored libraries. No game world,
## journey or save manager is constructed; all animation clocks are explicit.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")
const Profile = preload("res://scripts/story_cast_profile.gd")
const Stations = preload("res://scripts/living_cast_stations.gd")
const Routine = preload("res://scripts/greyfen_life_controller.gd")
const CASES := {
	"sister_anwen_human":"care", "blacksmith_tor":"forge", "mira_human":"sort_herbs", "rook_human":"check_supplies"
}
var failures: Array[String] = []
var checks := 0
var helper: Node
var station_host: StationHost

class StationHost extends Node3D:
	var zone_root := Node3D.new()
	func validate_walkable_position(point: Vector3) -> Vector3: return point

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	helper = Helper.new()
	root.add_child(helper)
	station_host = StationHost.new()
	root.add_child(station_host)
	station_host.add_child(station_host.zone_root)
	_build_stations()
	for role: String in CASES:
		await _actor(role, CASES[role])
	helper.free()
	station_host.free()
	for failure in failures:
		printerr("LIVING CAST MOTION: " + failure)
	print("LIVING CAST MOTION: %s checks=%d actors=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, CASES.size()])
	quit(0 if failures.is_empty() else 1)

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
		if role in ["mira_human", "rook_human"]:
			_check(not is_instance_valid(driver.life_modifier.tool) or not driver.life_modifier.tool.visible, role + " uses real station objects without an intersecting generic held prop")
		if role == "sister_anwen_human":
			_verify_staff(visual, driver)
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
	driver.set_life_activity(occupation)
	driver.advance_external(0.25)
	var before_suspend := driver.life_elapsed
	driver.set_distance_suspended(true)
	driver.advance_external(3.0)
	_check(is_equal_approx(driver.life_elapsed, before_suspend), role + " distance suspension freezes native work clock")
	driver.set_distance_suspended(false)
	driver.advance_external(0.25)
	_check(is_equal_approx(driver.life_elapsed, before_suspend + 0.25), role + " native work resumes without catch-up contacts")
	if role == "sister_anwen_human":
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
	driver.stop_story_gesture()
	driver.set_life_activity(occupation)
	driver.set_locomotion_motion(Vector3(1, 0, 0), true)
	_check(driver.life_clip == StringName() and driver.presentation_state == "", role + " actual locomotion interrupts planted work")
	driver.set_dead()
	driver.set_life_activity(occupation)
	_check(driver.dead and driver.life_clip == StringName(), role + " death prevents life restarting")
	driver.reset_for_journey_restore()
	_check(not driver.dead and driver.life_clip == StringName(), role + " journey restoration clears transient native work")
	for index in driver.skeleton.get_bone_count():
		_check(driver.skeleton.get_bone_rest(index).is_equal_approx(rest_poses[index]), role + " retains bone rest " + str(index))
	visual.free()
	await process_frame

func _pose(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for name: String in ["spine_03", "upperarm_l", "upperarm_r", "hand_l", "hand_r"]:
		var index := skeleton.find_bone(name)
		if index >= 0: result.append(skeleton.get_bone_pose(index))
	return result

func _build_stations() -> void:
	_check(Stations.add_care_table(station_host.zone_root) != null, "real retained care table loads")
	for id: String in ["mira_apothecary", "common_table"]:
		var area := Node3D.new()
		area.name = id
		station_host.zone_root.add_child(area)
		var visual := MeshInstance3D.new()
		visual.name = "GreyfenSocialFurniture"
		visual.mesh = load("res://assets_external/environment/props/GreyfenSocial_%s.res" % id) as ArrayMesh
		area.add_child(visual)
		_check(visual.mesh != null, id + " actual supporting furniture loads")
		Stations.decorate_place(area, id)
	var forge := MeshInstance3D.new()
	forge.name = "BlacksmithFittedWork"
	forge.mesh = load("res://assets_external/environment/props/GreyfenForgeWork_Authored.res") as ArrayMesh
	station_host.zone_root.add_child(forge)
	_check(forge.mesh != null, "real authored anvil loads")

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
	var id: String = {"sister_anwen_human":"sister_anwen", "blacksmith_tor":"blacksmith_tor", "mira_human":"mira", "rook_human":"rook"}[role]
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
