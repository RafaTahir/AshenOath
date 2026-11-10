extends SceneTree

## Authoring-only carriers of the existing runtime's actual settled poses.
## No duplicate arm math, production resources, save data or animation owners.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Driver = preload("res://scripts/character_animation_driver.gd")
const Fusion = preload("res://scripts/character_animation_fusion.gd")
const SkinEquivalence = preload("activity_pose_skin_equivalence.gd")
const WeightTransport = preload("activity_pose_weight_transport.gd")
const ROLES := {"C01":"sister_anwen_human", "C02":"rook_human", "C03":"mira_human", "C04":"blacksmith_tor", "C05":"widow_elna", "C06":"farmer_toma", "C07":"captain_senn", "C08":"edric", "C09":"vargan_record_keeper", "C10":"vargan_steward", "C11":"nessa", "C12":"saga_nera"}
const HZ := 120.0
const EAT_PERIOD := TAU / 0.9
var helper: Node
var placement: Node3D
var visual: Node3D
var driver: Node
var failures: Array[String] = []
var records: Array[Dictionary] = []
var retained_visible_meshes: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--asset")
	if index < 0 or index+1 >= args.size() or not ROLES.has(args[index+1]):
		_fail("Select exactly one retained cast actor with --asset Cxx")
		return
	var identity := args[index+1]
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	var prepared := ""
	var source := ""
	for key: String in catalog:
		if key.begins_with(str(ROLES[identity])+"|") and ("/"+identity+"_") in str(catalog[key].source):
			prepared = str(catalog[key].path)
			source = str(catalog[key].source)
			break
	if prepared.is_empty() or not ResourceLoader.exists(prepared):
		_fail("Exact prepared actor is unavailable: "+identity)
		return
	helper = Helper.new()
	root.add_child(helper)
	visual = helper.spawn_visual_role(ROLES[identity],"characters")
	if visual == null:
		_fail("Actual runtime actor construction failed: "+identity)
		return
	if str(visual.get_meta("runtime_asset_path",""))!=source or bool(visual.get_meta("runtime_fallback_used",true)) or visual.scene_file_path!=prepared:
		visual.free()
		_fail("Runtime role did not resolve the exact selected prepared source: "+identity)
		return
	placement = Node3D.new()
	placement.name = "ActivityPose_"+identity
	root.add_child(placement)
	placement.add_child(visual)
	Presentation.apply_npc(visual,ROLES[identity],false)
	var visual_frame := visual.transform
	driver = Driver.new()
	visual.add_child(driver)
	if not driver.configure(visual,{"idle":"Idle","walk":"Walking","run":"Running","dialogue":"Interact","hit":"HitReact","death":"Death"}):
		_fail("Actual driver configuration failed: "+str(driver.contract_errors))
		return
	driver.set_external_tick(true)
	# All automatic modifier callbacks are disabled on this disposable actor.
	# Each sample explicitly evaluates the graph, then its existing life owner.
	for modifier: SkeletonModifier3D in visual.find_children("*","SkeletonModifier3D",true,false): modifier.active=false
	var player: AnimationPlayer = driver.animation_player
	var skeleton: Skeleton3D = driver.skeleton
	var root_node := player.get_node(player.root_node)
	var skeleton_path := str(root_node.get_path_to(skeleton))
	var original_clips := _clip_fingerprints(player)
	var rests: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): rests.append(skeleton.get_bone_rest(bone))
	var inputs := _inputs(source,prepared)
	if inputs.is_empty():
		_fail("A required authoring input is missing")
		return
	var signature := JSON.stringify(inputs).sha256_text()
	var directory := ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/equipment/activity_poses").simplify_path().path_join(identity).path_join(signature)
	var destination := directory.path_join(identity+"_activity_poses.glb")
	var raw_destination := directory.path_join(identity+"_activity_poses_raw.glb")
	var manifest_path := directory.path_join("retained_skin_manifest.json")
	var receipt_path := directory.path_join("receipt.json")
	if FileAccess.file_exists(destination) or FileAccess.file_exists(raw_destination) or FileAccess.file_exists(manifest_path) or FileAccess.file_exists(receipt_path):
		var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
		if prior is Dictionary and FileAccess.file_exists(destination) and FileAccess.file_exists(raw_destination) and FileAccess.file_exists(manifest_path) and prior.get("inputs",{})==inputs and str(prior.get("carrier_sha256",""))==FileAccess.get_sha256(destination) and str(prior.get("raw_carrier_sha256",""))==FileAccess.get_sha256(raw_destination) and str(prior.get("retained_skin_manifest_sha256",""))==FileAccess.get_sha256(manifest_path) and prior.get("status","")=="authoring_pose_exported":
			print("ACTIVITY_POSE_INPUT_RETAINED ",identity," ",destination)
			_dispose()
			quit(0)
			return
		_fail("Existing authoring carrier is incomplete or changed; preserve and inspect: "+directory)
		return
	var recipes: Array[Dictionary] = [{"name":"Authoring_Eat","activity":"eat","style":"bread","moving":false,"duration":EAT_PERIOD}]
	if identity not in ["C09","C10"]:
		recipes.append({"name":"Authoring_Carry_Idle","activity":"carry","style":"supply","moving":false,"duration":player.get_animation(driver.get_clip_for_state("idle")).length})
		# The retained graph normalizes Walking to one cycle at walk_speed.
		recipes.append({"name":"Authoring_Carry_Walking","activity":"carry","style":"supply","moving":true,"duration":1.0})
	var library := AnimationLibrary.new()
	for recipe: Dictionary in recipes:
		var clip := _bake(recipe,skeleton_path,identity)
		if clip==null or not failures.is_empty():
			_fail("Actual activity pose sampling failed: "+str(recipe.name))
			return
		library.add_animation(str(recipe.name),clip)
	if not visual.transform.is_equal_approx(visual_frame) or not placement.transform.is_equal_approx(Transform3D.IDENTITY):
		_fail("Sampling moved the retained wrapper/normalized visual")
		return
	for bone in rests.size():
		if not skeleton.get_bone_rest(bone).is_equal_approx(rests[bone]): failures.append("Sampling altered retained bone rest: "+str(bone))
	if original_clips!=_clip_fingerprints(player): failures.append("Sampling altered a retained animation resource")
	if not failures.is_empty():
		_fail("Retained source invariants changed")
		return
	var skeleton_frame := _frame(placement.global_transform.affine_inverse()*skeleton.global_transform)
	# The uncalibrated generic bread/vessel belongs to its separate mesh input.
	# Remove only generated sockets; keep the actual fitted staff and belt kit.
	driver.free()
	driver=null
	for generated: Node in visual.find_children("CastActivityTool*","",true,false):
		if bool(generated.get_meta("life_generated_activity_tool",false)): generated.free()
	# GLTF does not supply a universal hidden-node contract. Do not turn a
	# stowed/invisible occupation prop into a phantom clearance obstacle.
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if is_instance_valid(mesh) and str(visual.get_path_to(mesh)) not in retained_visible_meshes: mesh.free()
	for modifier: Node in visual.find_children("*","SkeletonModifier3D",true,false): modifier.free()
	for animation_library: StringName in player.get_animation_library_list(): player.remove_animation_library(animation_library)
	player.add_animation_library("",library)
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	var captured := WeightTransport.capture(placement)
	if not bool(captured.get("verified",false)):
		_fail("Cannot capture exact retained skin weights: "+str(captured))
		return
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		_fail("Cannot create authoring-only output directory")
		return
	var manifest_file := FileAccess.open(manifest_path,FileAccess.WRITE)
	if manifest_file==null:
		_fail("Cannot preserve original skin manifest")
		return
	manifest_file.store_string(JSON.stringify(captured.manifest,"\t")+"\n")
	manifest_file.close()
	var manifest_sha256 := FileAccess.get_sha256(manifest_path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.bake_fps=HZ
	var error := document.append_from_scene(placement,state)
	if error==OK: error=document.write_to_filesystem(state,raw_destination)
	if error!=OK:
		_fail("Cannot export actual runtime pose carrier: "+str(error))
		return
	# The engine normalizes already packed weights on export/import. Retain the
	# raw file, then encode only its weight bytes inside the original u16 cells.
	# The subsequent actual import must still pass the unchanged skin/pose gate.
	var transport := WeightTransport.patch(raw_destination,destination,captured.manifest)
	if not bool(transport.get("verified",false)):
		var transport_failure := FileAccess.open(directory.path_join("failed_receipt.json"),FileAccess.WRITE)
		if transport_failure!=null:
			transport_failure.store_string(JSON.stringify({"status":"weight_transport_failed","asset":identity,"inputs":inputs,"raw_carrier_path":raw_destination,"raw_carrier_sha256":FileAccess.get_sha256(raw_destination),"retained_skin_manifest_path":manifest_path,"retained_skin_manifest_sha256":FileAccess.get_sha256(manifest_path),"sample_hz":HZ,"clips":records,"weight_transport":transport,"grip_verified":false,"body_clearance_verified":false,"visual_accepted":false},"\t")+"\n")
			transport_failure.close()
		_fail("Cannot preserve exact original skin through GLTF: "+str(transport))
		return
	var file := FileAccess.open(destination,FileAccess.READ)
	var size := file.get_length() if file!=null else 0
	file=null
	if size<=0 or size>=100*1024*1024:
		_fail("Authoring carrier violates per-file size limit")
		return
	var roundtrip := _roundtrip(destination,player,skeleton,identity)
	if not bool(roundtrip.get("verified",false)):
		var failure_file := FileAccess.open(directory.path_join("failed_receipt.json"),FileAccess.WRITE)
		if failure_file!=null:
			failure_file.store_string(JSON.stringify({"status":"roundtrip_failed","asset":identity,"inputs":inputs,"carrier_path":destination,"carrier_sha256":FileAccess.get_sha256(destination),"raw_carrier_path":raw_destination,"raw_carrier_sha256":FileAccess.get_sha256(raw_destination),"retained_skin_manifest_path":manifest_path,"retained_skin_manifest_sha256":FileAccess.get_sha256(manifest_path),"weight_transport":transport,"sample_hz":HZ,"clips":records,"roundtrip":roundtrip,"grip_verified":false,"body_clearance_verified":false,"visual_accepted":false},"\t")+"\n")
			failure_file.close()
		_fail("Authoring carrier failed actual GLTF reimport pose/staff equivalence: "+str(roundtrip))
		return
	if FileAccess.get_sha256(raw_destination)!=str(transport.raw_sha256) or FileAccess.get_sha256(destination)!=str(transport.corrected_sha256) or FileAccess.get_sha256(manifest_path)!=manifest_sha256:
		_fail("An exported carrier or original weight manifest changed during reimport proof")
		return
	for path: String in inputs:
		if FileAccess.get_sha256(path)!=str(inputs[path]):
			_fail("A sampled input changed during authoring export: "+path)
			return
	var receipt := {"schema_version":1,"status":"authoring_pose_exported","asset":identity,"role":ROLES[identity],"inputs":inputs,"input_signature":signature,"carrier_path":destination,"carrier_sha256":FileAccess.get_sha256(destination),"carrier_bytes":size,"sample_hz":HZ,"frame_convention":"Godot Y-up metres; [basis_x,basis_y,basis_z,origin] columns relative to identity placement wrapper","normalized_visual_frame":_frame(visual_frame),"skeleton_frame":skeleton_frame,"retained_visible_mesh_paths":retained_visible_meshes,"clips":records,"roundtrip":roundtrip,"retained_animation_fingerprints":original_clips,"source_animations_changed":false,"grip_verified":false,"body_clearance_verified":false,"visual_accepted":false,"runtime_output":false,"scope":"Actual settled runtime modifier over fresh retained graph samples; full eating period, standing Idle and normalized Walking supply cycles. Generic prop geometry/fit is a separate input. No seated meal, arbitrary gait/meal phase cross-product, entrance/exit or gameplay acceptance is asserted."}
	receipt.merge({"raw_carrier_path":raw_destination,"raw_carrier_sha256":FileAccess.get_sha256(raw_destination),"retained_skin_manifest_path":manifest_path,"retained_skin_manifest_sha256":FileAccess.get_sha256(manifest_path),"retained_skin_capture":captured.report,"weight_transport":transport})
	file=FileAccess.open(receipt_path,FileAccess.WRITE)
	if file==null:
		_fail("Cannot write immutable authoring pose receipt")
		return
	file.store_string(JSON.stringify(receipt,"\t")+"\n")
	file.close()
	print("ACTIVITY_POSE_INPUT_EXPORTED ",identity," ",destination)
	_dispose()
	quit(0)

func _bake(recipe: Dictionary, skeleton_path: String, identity: String) -> Animation:
	driver.reset_for_journey_restore()
	var skeleton: Skeleton3D = driver.skeleton
	var speed: float = driver.animation_graph.walk_speed if bool(recipe.moving) else 0.0
	driver.set_locomotion_motion(driver.get_visible_forward()*speed,true)
	if bool(recipe.moving): driver.set_carried_activity(str(recipe.activity))
	else: driver.set_life_activity(str(recipe.activity))
	driver.set_activity_prop(str(recipe.style))
	for tick in 60: driver.advance_external(1.0/HZ)
	if not driver.activity_prop_pose_ready() or driver.life_clip!=StringName():
		failures.append("Retained closed-hand gait must own the settled activity")
		return null
	driver.animation_graph.playback.start("locomotion",true)
	driver.animation_graph.gait_phase=0.0
	var modifier: Node = driver.life_modifier
	modifier.pose_weight=1.0
	modifier.ambient_weight=0.0 if bool(recipe.moving) else 1.0
	modifier.staff_weight=1.0
	modifier.staff_planted=false
	var clip := Animation.new()
	clip.length=float(recipe.duration)
	clip.loop_mode=Animation.LOOP_NONE
	for bone in skeleton.get_bone_count():
		for type: int in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
			var track := clip.add_track(type)
			clip.track_set_path(track,NodePath(skeleton_path+":"+skeleton.get_bone_name(bone)))
	var frames := ceili(clip.length*HZ)
	var previous_time := 0.0
	var hand_samples: Array[Dictionary] = []
	var hand_name := "hand_l" if identity=="C01" else "hand_r"
	var hand := skeleton.find_bone(hand_name)
	if hand<0:
		failures.append("Actual required hand bone missing")
		return null
	for frame in frames+1:
		var time := minf(float(frame)/HZ,clip.length)
		# Explicit base reset prevents direct modifier calls accumulating their
		# previous offsets on bones whose native clips omit constant channels.
		skeleton.reset_bone_poses()
		driver.advance_external(time-previous_time)
		modifier.elapsed=time-minf(float(modifier.get_process_delta_time()),0.05)
		modifier._process_modification()
		if absf(float(modifier.elapsed)-time)>0.000001:
			failures.append("Actual modifier sample clock differs from requested authoring time")
			return null
		if not is_instance_valid(modifier.tool) or not modifier.tool.visible or str(modifier.tool.bone_name)!=hand_name:
			failures.append("Actual activity prop is not visibly owned by its intended hand")
			return null
		if frame==0 or frame==frames:
			var visible_meshes := _visible_geometry()
			if retained_visible_meshes.is_empty(): retained_visible_meshes=visible_meshes
			if visible_meshes.is_empty() or retained_visible_meshes!=visible_meshes:
				failures.append("Retained body/equipment visibility differs between sampled activities")
				return null
		for bone in skeleton.get_bone_count():
			var pose := skeleton.get_bone_pose(bone)
			if not pose.is_finite():
				failures.append("Nonfinite actual runtime bone pose")
				return null
			clip.position_track_insert_key(bone*3,time,pose.origin)
			clip.rotation_track_insert_key(bone*3+1,time,pose.basis.orthonormalized().get_rotation_quaternion())
			clip.scale_track_insert_key(bone*3+2,time,pose.basis.get_scale())
		var sample := {"time":time,"gait_phase":float(driver.animation_graph.gait_phase),"native_position":driver.animation_graph.playback.get_current_play_position(),"hand_frame":_frame(placement.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(hand))}
		if identity=="C01":
			if not is_instance_valid(modifier.staff_equipment) or not modifier.staff_equipment.visible:
				failures.append("Anwen's actual fitted right staff lost ownership")
				return null
			sample["staff_hand_frame"]=_frame(placement.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")))
			sample["staff_tip"]=_vector(modifier.staff_tip)
		hand_samples.append(sample)
		previous_time=time
	records.append({"clip":recipe.name,"activity":recipe.activity,"prop":recipe.style,"hand":hand_name,"moving":recipe.moving,"speed_mps":speed,"duration":clip.length,"frames":frames+1,"hand_samples":hand_samples,"native_closed_hand_ready":true,"generic_prop_fit_verified":false})
	return clip

func _visible_geometry() -> Array[String]:
	var result: Array[String] = []
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
		var node: Node = mesh
		var generated := false
		while node!=null and node!=visual:
			generated=generated or bool(node.get_meta("life_generated_activity_tool",false))
			node=node.get_parent()
		if not generated: result.append(str(visual.get_path_to(mesh)))
	result.sort()
	return result

func _inputs(source: String, prepared: String) -> Dictionary:
	var paths: Array[String] = [source,prepared,Fusion.ANIMATION_LIBRARY_PATH,str(driver.life_library_path),str(get_script().resource_path),"res://scripts/asset_spawn_helper.gd","res://scripts/character_animation_driver.gd","res://scripts/character_life_modifier.gd","res://scripts/character_presentation.gd","res://scripts/character_animation_fusion.gd","res://scripts/story_cast_profile.gd","res://scripts/systems/character_animation_graph.gd","res://data/prepared_actors.json","res://runtime_asset_manifest.json"]
	paths.append(str(get_script().resource_path).get_base_dir().path_join("activity_pose_skin_equivalence.gd"))
	paths.append(str(get_script().resource_path).get_base_dir().path_join("activity_pose_weight_transport.gd"))
	if driver.life_modifier.anwen_staff_pose: paths.append(Presentation.CLERIC_STAFF_PATH)
	var scanned := {}
	var pending: Array[String] = paths.duplicate()
	var script_references := RegEx.new()
	script_references.compile("(?:preload|load)\\s*\\(\\s*[\"'](res://[^\"']+\\.gd)[\"']\\s*\\)")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if scanned.has(path): continue
		scanned[path]=true
		if not paths.has(path): paths.append(path)
		# Script preloads are not consistently reported by get_dependencies.
		# Follow their literal script edges, including presentation helpers.
		if path.ends_with(".gd"):
			for match_result: RegExMatch in script_references.search_all(FileAccess.get_file_as_string(path)):
				pending.append(match_result.get_string(1))
		# Raw production geometry identifies provenance; the actually sampled
		# resources come from the exact prepared scene and its dependency graph.
		if path==source or path.ends_with(".json"): continue
		for encoded: String in ResourceLoader.get_dependencies(path):
			var dependency := ""
			for component: String in encoded.split("::"):
				if component.begins_with("res://"): dependency=component
				elif component.is_absolute_path() and component.simplify_path().begins_with(str(get_script().resource_path).get_base_dir().simplify_path()+"/"):
					dependency=component.simplify_path()
			if dependency.is_empty() and encoded.begins_with("uid://"):
				var uid := ResourceUID.text_to_id(encoded.get_slice("::",0))
				if ResourceUID.has_id(uid): dependency=ResourceUID.get_id_path(uid)
			if dependency.is_empty():
				failures.append("Unresolved actual prepared dependency: "+encoded)
				return {}
			pending.append(dependency)
	paths.sort()
	var result := {}
	for path: String in paths:
		if path.is_empty() or not FileAccess.file_exists(path): return {}
		result[path]=FileAccess.get_sha256(path)
	return result

func _roundtrip(path: String, original_player: AnimationPlayer, original_skeleton: Skeleton3D, identity: String) -> Dictionary:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.bake_fps=HZ
	var error := document.append_from_file(path,state)
	if error!=OK: return {"error":"Cannot directly reimport authoring carrier","code":error}
	# generate_scene overrides state.bake_fps; its default30Hz would discard
	# the actual120Hz samples exported above before this fidelity comparison.
	var imported := document.generate_scene(state,HZ) as Node3D
	if imported==null: return {"error":"Imported carrier has no scene"}
	root.add_child(imported)
	var imported_players := imported.find_children("*","AnimationPlayer",true,false)
	var imported_skeletons := imported.find_children("*","Skeleton3D",true,false)
	if imported_players.size()!=1 or imported_skeletons.size()!=1:
		imported.free()
		return {"error":"Expected exactly one retained player and rig"}
	var replay: AnimationPlayer = imported_players[0]
	var rig: Skeleton3D = imported_skeletons[0]
	# Driver configuration disables the original player in favor of its tree.
	# That tree is now gone: both isolated players explicitly evaluate manually.
	original_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	original_player.active=true
	replay.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	replay.active=true
	var result := {"verified":true,"frames":0,"bone_samples":0,"max_bone_position_error_m":0.0,"max_bone_basis_error":0.0,"max_hand_telemetry_error_m":0.0,"max_staff_vertex_error_m":0.0,"position_tolerance_m":0.0001,"basis_tolerance":0.0001}
	if rig.get_bone_count()!=original_skeleton.get_bone_count(): result["error"]="Retained bone count changed"
	var mapping: Array[int] = []
	for bone in original_skeleton.get_bone_count():
		var target := rig.find_bone(original_skeleton.get_bone_name(bone))
		mapping.append(target)
		if target<0: result["error"]="Retained bone name lost"
	var skin := SkinEquivalence.prepare(placement,imported)
	if not bool(skin.get("verified",false)):
		result["error"]="Retained body skin/geometry contract failed: "+str(skin.get("error",""))
		result["skin_geometry"]={"verified":false,"error":skin.get("error",""),"detail":skin.get("detail",{})}
	else:
		result["skin_geometry"]=skin.report
		result["skin_samples"]=[]
	for record: Dictionary in records:
		var name := str(record.clip)
		if result.has("error"): break
		if not replay.has_animation(name):
			result["error"]="Actual baked clip missing after GLTF import: "+name
			break
		original_player.play(name)
		replay.play(name)
		var sample_index := 0
		var staff_frames: Array[int] = [0,floori(float(record.frames-1)*0.25),floori(float(record.frames-1)*0.5),floori(float(record.frames-1)*0.75),int(record.frames)-1]
		for sample: Dictionary in record.hand_samples:
			original_skeleton.reset_bone_poses()
			rig.reset_bone_poses()
			original_player.seek(float(sample.time),true)
			replay.seek(float(sample.time),true)
			original_player.advance(0.0)
			replay.advance(0.0)
			original_skeleton.force_update_all_bone_transforms()
			rig.force_update_all_bone_transforms()
			for bone in mapping.size():
				var expected := original_skeleton.global_transform*original_skeleton.get_bone_global_pose(bone)
				var actual := rig.global_transform*rig.get_bone_global_pose(mapping[bone])
				var position_error := expected.origin.distance_to(actual.origin)
				if position_error>float(result.max_bone_position_error_m):
					result.max_bone_position_error_m=position_error
					result["worst_bone_position"]={"clip":name,"time":sample.time,"bone":original_skeleton.get_bone_name(bone),"expected":_vector(expected.origin),"actual":_vector(actual.origin)}
				for axis in 3:
					var basis_error := (expected.basis[axis]-actual.basis[axis]).length()
					if basis_error>float(result.max_bone_basis_error):
						result.max_bone_basis_error=basis_error
						result["worst_bone_basis"]={"clip":name,"time":sample.time,"bone":original_skeleton.get_bone_name(bone),"axis":axis}
				result.bone_samples+=1
			var hand_frame := rig.global_transform*rig.get_bone_global_pose(rig.find_bone(str(record.hand)))
			var expected_hand: Array = sample.hand_frame[3]
			var hand_error := hand_frame.origin.distance_to(Vector3(expected_hand[0],expected_hand[1],expected_hand[2]))
			if hand_error>float(result.max_hand_telemetry_error_m):
				result.max_hand_telemetry_error_m=hand_error
				result["worst_hand_telemetry"]={"clip":name,"time":sample.time,"bone":record.hand,"expected":expected_hand,"actual":_vector(hand_frame.origin)}
			if sample_index in staff_frames:
				# Preserve bounded native surface references for the separate Blender
				# import/clearance proof; native reimport alone cannot establish it.
				var skin_sample := SkinEquivalence.sample(skin,true)
				skin_sample["clip"]=name
				skin_sample["time"]=sample.time
				result.skin_samples.append(skin_sample)
				if not bool(skin_sample.get("verified",false)):
					result["error"]=str(skin_sample.get("error","Actual weighted body differs after GLTF import"))
					break
			if identity=="C01" and sample_index in staff_frames:
				var staff := _staff_equivalence(placement,imported)
				if staff.has("error"):
					result["error"]=staff.error
					break
				result.max_staff_vertex_error_m=maxf(float(result.max_staff_vertex_error_m),float(staff.max_error))
			result.frames+=1
			sample_index+=1
		if float(result.max_bone_position_error_m)>0.0001 or float(result.max_bone_basis_error)>0.0001 or float(result.max_hand_telemetry_error_m)>0.0001 or float(result.max_staff_vertex_error_m)>0.0001:
			result["error"]="Exported bone/hand/staff frames differ from actual sampled runtime"
	result.verified=not result.has("error")
	skin.clear()
	imported.free()
	return result

func _staff_equivalence(expected_root: Node3D, actual_root: Node3D) -> Dictionary:
	var expected := expected_root.find_child("AnwenStaffModeled",true,false) as Node3D
	var actual := actual_root.find_child("AnwenStaffModeled",true,false) as Node3D
	if expected==null or actual==null: return {"error":"Actual retained staff was omitted by GLTF export"}
	var expected_meshes: Array[Node] = expected.find_children("*","MeshInstance3D",true,false)
	var actual_meshes: Array[Node] = actual.find_children("*","MeshInstance3D",true,false)
	if expected is MeshInstance3D: expected_meshes.push_front(expected)
	if actual is MeshInstance3D: actual_meshes.push_front(actual)
	if expected_meshes.is_empty() or expected_meshes.size()!=actual_meshes.size(): return {"error":"Retained staff mesh ownership changed"}
	var max_error := 0.0
	for index in expected_meshes.size():
		var a := expected_meshes[index] as MeshInstance3D
		var b := actual_meshes[index] as MeshInstance3D
		if a.mesh==null or b.mesh==null or a.name!=b.name: return {"error":"Retained staff mesh identity changed"}
		var first := a.mesh.get_faces()
		var second := b.mesh.get_faces()
		if first.size()!=second.size(): return {"error":"Retained staff triangle topology changed"}
		var frame := _socket_mesh_frame(a)
		for vertex in first.size(): max_error=maxf(max_error,(frame*first[vertex]).distance_to(b.global_transform*second[vertex]))
	return {"max_error":max_error}

func _socket_mesh_frame(mesh: MeshInstance3D) -> Transform3D:
	var cursor: Node3D = mesh
	var local := Transform3D.IDENTITY
	while cursor!=null and not cursor is BoneAttachment3D:
		local=cursor.transform*local
		cursor=cursor.get_parent() as Node3D
	if cursor is BoneAttachment3D:
		var socket := cursor as BoneAttachment3D
		var skeleton := socket.get_parent() as Skeleton3D
		if skeleton!=null and socket.bone_idx>=0:
			return skeleton.global_transform*skeleton.get_bone_global_pose(socket.bone_idx)*local
	return mesh.global_transform

func _clip_fingerprints(player: AnimationPlayer) -> Dictionary:
	var result := {}
	for name: StringName in player.get_animation_list():
		var animation := player.get_animation(name)
		var values: Array = [animation.length,animation.loop_mode]
		for track in animation.get_track_count():
			values.append([animation.track_get_type(track),str(animation.track_get_path(track))])
			for key in animation.track_get_key_count(track): values.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key)])
		result[str(name)]=var_to_str(values).sha256_text()
	return result

func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _frame(value: Transform3D) -> Array:
	return [_vector(value.basis.x),_vector(value.basis.y),_vector(value.basis.z),_vector(value.origin)]

func _dispose() -> void:
	if is_instance_valid(placement): placement.free()
	if is_instance_valid(helper): helper.free()

func _fail(message: String) -> void:
	for failure: String in failures: printerr("ACTIVITY_POSE_INPUT_ERROR ",failure)
	printerr("ACTIVITY_POSE_INPUT_ERROR ",message)
	_dispose()
	quit(1)
