extends SceneTree

## Candidate-only pose proof. M15/M16 have their separate actual-morph fixture.
## No world, production import/cache replacement, recalibration or visual claim.
const Driver = preload("res://scripts/character_animation_driver.gd")
const Contract = preload("res://tools/creature_ambient_source_contract.gd")
const NativeEquivalence = preload("res://tools/creature_candidate_native_contract.gd")
const ASSETS := ["M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08", "M09", "M10", "M11", "M12", "M13", "M14", "M17", "M18", "M19", "M20"]
const INTERRUPTIONS := ["movement", "attack", "hit", "dialogue", "cancel", "distance", "death", "restore"]
const STEP := 1.0 / 60.0
const MOTION_EPSILON := 0.000001
var checks := 0
var failures: Array[String] = []
var options: Dictionary = {}
var asset := ""
var source_path := ""
var input_hashes: Dictionary = {}
var proof: Dictionary = {}
var native_equivalence: Dictionary = {}
var authored: Dictionary = {}
var source_contract: Dictionary = {}
var declared_bones: Dictionary = {}
var samples: Array[Dictionary] = []
var interruption_samples: Array[Dictionary] = []
var root_transform := Transform3D.IDENTITY

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=", true, 1)
			options[pair[0]] = pair[1]
	call_deferred("_run")

func _run() -> void:
	asset = str(options.get("asset", ""))
	if asset not in ASSETS:
		_check(false, "Explicit supported pose candidate required: M01-M14 or M17-M20; M15/M16 use the morph fixture")
		_finish(null)
		return
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures").path_join(asset)
	source_path = folder.path_join(asset + "_living_candidate.glb")
	for name: String in [asset + "_living_candidate.glb", asset + "_retained_input.glb", "authoring.json", "source_contract.json"]:
		var path := folder.path_join(name)
		_check(FileAccess.file_exists(path), "Required exact candidate input exists: " + path)
		if FileAccess.file_exists(path): input_hashes[path] = FileAccess.get_sha256(path)
	if not failures.is_empty():
		_finish(null)
		return
	var raw_authoring: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("authoring.json")))
	var raw_contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("source_contract.json")))
	if not raw_authoring is Dictionary or not raw_contract is Dictionary:
		_check(false, "Authoring and source contract are JSON objects")
		_finish(null)
		return
	authored = raw_authoring
	source_contract = raw_contract
	_check(str(authored.get("asset", "")) == asset and str(source_contract.get("asset", "")) == asset, "Both receipts identify the requested candidate")
	_check(str(authored.get("candidate_sha256", "")) == str(input_hashes[source_path]), "Authoring receipt identifies the exact candidate bytes")
	_check(source_contract.get("required_morphs", null) is Array and source_contract.get("required_morphs", ["missing"]).is_empty(), "Pose-only candidate declares no required morph ownership")
	if not failures.is_empty():
		_finish(null)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(source_path, state)
	_check(error == OK, "Exact candidate GLTF imports without production cache replacement")
	if error != OK:
		_finish(null)
		return
	var visual := document.generate_scene(state) as Node3D
	_check(visual != null, "Candidate produces its retained native scene")
	if visual == null:
		_finish(null)
		return
	root.add_child(visual)
	root_transform = visual.transform
	native_equivalence = NativeEquivalence.compare(visual, folder.path_join(asset + "_retained_input.glb"))
	_check(bool(native_equivalence.get("verified", false)), "Retained raw native frames/rests/actual bounds match: " + str(native_equivalence.get("errors", [])))
	if not failures.is_empty():
		_finish(visual)
		return
	proof = Contract.apply_candidate(visual, asset)
	_check(bool(proof.get("verified", false)) and bool(proof.get("candidate_only", false)) and not proof.has("error"), "Exact source/clip/native bindings pass: " + str(proof.get("error", "")))
	_check(str(proof.get("source_sha256", "")) == str(input_hashes[source_path]), "Native proof identifies the imported bytes")
	if not failures.is_empty():
		_finish(visual)
		return
	var player := Contract._player(visual)
	var original_clips := _clip_fingerprints(player)
	var protected_clips := _protected_fingerprints(original_clips)
	var original_rests := _bone_rests(visual)
	_check(not protected_clips.is_empty(), "Protected retained clips are fingerprinted before driver ownership")
	var driver := Driver.new()
	visual.add_child(driver)
	_check(driver.configure(visual, {"idle":"Idle", "walk":"Walking", "run":"Running", "attack":"Attack", "hit":"HitReact", "dialogue":"Interact", "death":"Death"}), "Retained driver binds actual candidate rig: " + str(driver.contract_errors))
	if not driver.is_valid():
		_finish(visual)
		return
	driver.set_external_tick(true)
	var rest: Array[Transform3D] = []
	for bone in driver.skeleton.get_bone_count(): rest.append(driver.skeleton.get_bone_rest(bone))
	for clip: String in Contract.CLIPS:
		declared_bones[clip] = _bind_declared_bones(driver, clip)
	if not failures.is_empty():
		_finish(visual)
		return
	for clip: String in Contract.CLIPS:
		_measure_clip(driver, visual, clip)
	# Every ambient clip must yield and reacquire through every existing owner.
	# This verifies graph authority, not a fictitious neutral combat pose.
	for clip: String in Contract.CLIPS:
		for interruption: String in INTERRUPTIONS:
			_exercise_interruption(driver, visual, clip, interruption)
	_check(interruption_samples.size() == Contract.CLIPS.size() * INTERRUPTIONS.size(), "All 32 clip/owner interruption cases ran")
	_check(visual.transform.is_equal_approx(root_transform), "Lifecycle preserves the retained visual root")
	for bone in rest.size():
		_check(driver.skeleton.get_bone_rest(bone).is_equal_approx(rest[bone]), "Retained bone rest unchanged: " + str(bone))
	_check(_bone_rests(visual) == original_rests, "Driver configuration and lifecycle preserve every imported skeleton rest")
	_check(_clip_fingerprints(driver.animation_player) == original_clips, "Every imported animation curve remains unchanged")
	_check(_protected_fingerprints(_clip_fingerprints(driver.animation_player)) == protected_clips, "Protected clip fingerprints remain unchanged")
	for path: String in input_hashes:
		_check(FileAccess.get_sha256(path) == str(input_hashes[path]), "Candidate input bytes remain unchanged: " + path.get_file())
	driver.free()
	_check(_clip_fingerprints(player) == original_clips, "Driver teardown preserves imported animation curves")
	_finish(visual)

func _bind_declared_bones(driver: Node, clip: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var authored_clips: Variant = authored.get("ambient_clips", {})
	var verified_clips: Variant = source_contract.get("clips", {})
	if not authored_clips is Dictionary or not verified_clips is Dictionary or not authored_clips.get(clip) is Dictionary or not verified_clips.get(clip) is Dictionary:
		_check(false, "Both receipts declare " + clip)
		return result
	var expected: Variant = authored_clips[clip].get("bones")
	var active: Variant = verified_clips[clip].get("active_bones")
	if not expected is Array or not active is Array or expected.is_empty() or active.is_empty():
		_check(false, "Authored and verified active bone lists are nonempty: " + clip)
		return result
	var names: Array[String] = []
	var active_names: Array[String] = []
	for value: Variant in expected:
		if not value is String or str(value).is_empty() or str(value) in names:
			_check(false, "Declared bones are unique nonempty strings: " + clip)
			return result
		names.append(str(value))
	for value: Variant in active:
		if not value is String or str(value).is_empty() or str(value) in active_names:
			_check(false, "Verified active bones are unique nonempty strings: " + clip)
			return result
		active_names.append(str(value))
	names.sort()
	active_names.sort()
	_check(names == active_names, "Verified active channels match every authored bone: " + clip)
	var animation := _animation(driver.animation_player, clip)
	if animation == null:
		_check(false, "Declared native clip exists: " + clip)
		return result
	var animation_root := driver.animation_player.get_node_or_null(driver.animation_player.root_node) as Node
	for name: String in names:
		var index: int = driver.skeleton.find_bone(name)
		var tracks: Array[int] = []
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			if path.get_subname_count() != 1 or str(path.get_subname(0)) != name: continue
			var kind := animation.track_get_type(track)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]: continue
			if animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) == driver.skeleton:
				tracks.append(track)
		_check(index >= 0 and not tracks.is_empty(), "Declared channel binds the actual driver skeleton: " + clip + "/" + name)
		if index >= 0 and not tracks.is_empty(): result.append({"name":name, "index":index, "tracks":tracks})
	return result

func _begin(driver: Node, clip: String) -> bool:
	driver.set_distance_suspended(false)
	driver.reset_for_journey_restore()
	driver.set_locomotion_motion(Vector3.ZERO, true)
	if not driver.set_observation_clip(clip): return false
	return _settle_clip(driver, clip)

func _settle_clip(driver: Node, clip: String) -> bool:
	var expected := "ecology_" + str(abs(str(driver.observation_clip).hash()))
	for tick in 180:
		var playback: AnimationNodeStateMachinePlayback = driver.animation_graph.playback
		var before := str(playback.get_current_node())
		# The evaluation that clears the fade still mixes the outgoing pose at epsilon.
		var fade_free_before := str(playback.get_fading_from_node()).is_empty()
		driver.advance_external(STEP)
		driver.skeleton.force_update_all_bone_transforms()
		var sample: Dictionary = driver.observation_motion_sample()
		if fade_free_before and before == expected and str(playback.get_current_node()) == expected and not sample.is_empty() and str(sample.clip).get_file() == clip and float(sample.time) > 0.10 and str(playback.get_fading_from_node()).is_empty() and playback.get_travel_path().is_empty():
			return true
	return false

func _measure_clip(driver: Node, visual: Node3D, clip: String) -> void:
	_check(_begin(driver, clip), "Native clip becomes fully evaluated without outgoing ownership: " + clip)
	var sample: Dictionary = driver.observation_motion_sample()
	if sample.is_empty(): return
	var duration := float(sample.duration)
	if not is_finite(duration) or duration <= 0.0 or duration > 120.0:
		_check(false, "Native clip duration is finite and within fixture deadline: " + clip)
		return
	_check(absf(duration - float(source_contract.durations[clip])) <= 0.00001, "Actual native duration matches its source contract: " + clip)
	var initial := _poses(driver.skeleton, declared_bones[clip])
	var deltas: Dictionary = {}
	for row: Dictionary in declared_bones[clip]: deltas[row.name] = 0.0
	var root_poses: Dictionary = {}
	for bone in driver.skeleton.get_bone_count():
		if driver.skeleton.get_bone_parent(bone) < 0: root_poses[bone] = driver.skeleton.get_bone_pose(bone)
	var ticks := ceili(duration * 2.0 / STEP)
	for tick in ticks:
		driver.advance_external(STEP)
		driver.skeleton.force_update_all_bone_transforms()
		var actual: Dictionary = driver.observation_motion_sample()
		_check(not actual.is_empty() and str(actual.get("clip", "")).get_file() == clip, "Actual native branch remains authoritative: " + clip)
		_check(visual.transform.is_equal_approx(root_transform), "Ambient sampling leaves the visual root fixed: " + clip)
		for bone: int in root_poses:
			_check(driver.skeleton.get_bone_pose(bone).is_equal_approx(root_poses[bone]), "Ambient sampling keeps the skeleton root anchored: " + clip)
		for row: Dictionary in declared_bones[clip]:
			var pose: Transform3D = driver.skeleton.get_bone_pose(int(row.index))
			_check(pose.is_finite(), "Finite actual native pose: " + clip + "/" + str(row.name))
			deltas[row.name] = maxf(float(deltas[row.name]), _pose_delta(initial[row.name], pose))
	for name: String in deltas:
		_check(float(deltas[name]) > MOTION_EPSILON, "Declared bone actually moves after the fade settles: " + clip + "/" + name)
	samples.append({"clip":clip, "duration":duration, "rate_hz":60, "cycles":2, "ticks":ticks, "declared_bones":declared_bones[clip], "actual_pose_component_deltas":deltas})

func _exercise_interruption(driver: Node, visual: Node3D, clip: String, interruption: String) -> void:
	var label := clip + "/" + interruption
	_check(_begin(driver, clip), "Native ambient starts before interruption: " + label)
	var active_delta := _wait_for_pose_change(driver, clip)
	_check(active_delta > MOTION_EPSILON, "Actual native bones move before ownership interruption: " + label)
	var before: Dictionary = driver.observation_motion_sample().duplicate(true)
	if before.is_empty(): return
	var before_pose := _poses(driver.skeleton, declared_bones[clip])
	var before_time: float = driver.animation_graph.playback.get_current_play_position()
	var action_length := 0.0
	match interruption:
		"movement": driver.set_locomotion_motion(Vector3.RIGHT, true)
		"attack", "hit":
			var protected: StringName = driver.get_clip_for_state(interruption)
			action_length = driver.animation_player.get_animation(protected).length
			_check(driver.trigger_action(interruption), "Protected action takes ownership: " + label)
			_check(is_equal_approx(driver.action_duration, action_length), "Original protected action duration is unchanged: " + label)
		"dialogue": driver.set_dialogue_pose(true)
		"cancel": driver.clear_observation_clip()
		"distance": driver.set_distance_suspended(true)
		"death": driver.set_dead()
		"restore": driver.reset_for_journey_restore()
	_check(driver.observation_motion_sample().is_empty(), "Ambient observation yields immediately: " + label)
	var owner_published := false
	var published_node := ""
	# Stay within short protected actions; require their actual evaluated branch.
	var delta := minf(STEP, action_length / 32.0) if action_length > 0.0 else STEP
	for tick in 12:
		var previous_node := str(driver.animation_graph.playback.get_current_node())
		driver.advance_external(delta)
		driver.skeleton.force_update_all_bone_transforms()
		var playback: AnimationNodeStateMachinePlayback = driver.animation_graph.playback
		var current := str(playback.get_current_node())
		if previous_node == current and _owner_matches(driver, interruption, current):
			owner_published = true
			published_node = current
		_check(driver.observation_motion_sample().is_empty(), "Outgoing ambient cannot reacquire during interruption: " + label)
		_check(visual.transform.is_equal_approx(root_transform), "Interruption preserves visual root: " + label)
		for row: Dictionary in declared_bones[clip]:
			_check(driver.skeleton.get_bone_pose(int(row.index)).is_finite(), "Protected owner evaluates finite bone pose: " + label + "/" + str(row.name))
		if interruption == "distance":
			_check(is_equal_approx(playback.get_current_play_position(), before_time), "Distance suspension freezes the evaluated native clock: " + label)
			for row: Dictionary in declared_bones[clip]:
				_check(driver.skeleton.get_bone_pose(int(row.index)).is_equal_approx(before_pose[row.name]), "Distance suspension freezes the actual pose: " + label + "/" + str(row.name))
	_check(owner_published, "Expected existing owner actually publishes in the graph: " + label)
	driver.sample_pose()
	_check(driver.observation_motion_sample().is_empty(), "Direct pose evaluation cannot revive stale ambient ownership: " + label)
	var reacquired := _resume_after_interruption(driver, clip, interruption)
	_check(reacquired, "Native ambient reacquires through its existing owner release: " + label)
	var reacquired_delta := _wait_for_pose_change(driver, clip) if reacquired else 0.0
	_check(reacquired_delta > MOTION_EPSILON, "Actual native bone motion resumes after interruption: " + label)
	interruption_samples.append({"clip":clip, "interruption":interruption, "before":before, "pre_interrupt_pose_delta":active_delta, "published_node":published_node, "owner_published":owner_published, "original_action_duration":action_length, "reacquired":reacquired, "reacquired_pose_delta":reacquired_delta, "after":driver.observation_motion_sample()})

func _resume_after_interruption(driver: Node, clip: String, interruption: String) -> bool:
	match interruption:
		"movement": driver.set_locomotion_motion(Vector3.ZERO, true)
		"attack", "hit":
			var duration: float = driver.action_duration
			if not is_finite(duration) or duration <= 0.0 or duration > 120.0: return false
			for tick in ceili(duration / STEP) + 2:
				if not driver.action_active: break
				driver.advance_external(STEP)
			if driver.action_active: return false
		"dialogue": driver.set_dialogue_pose(false)
		"distance": driver.set_distance_suspended(false)
		"death": driver.reset_for_journey_restore()
	# Cancel and restore have already released their owner. Only terminal death
	# needs journey restoration; ordinary reacquisition must not hide stale state.
	if not driver.set_observation_clip(clip): return false
	return _settle_clip(driver, clip)

func _wait_for_pose_change(driver: Node, clip: String) -> float:
	var sample: Dictionary = driver.observation_motion_sample()
	if sample.is_empty(): return 0.0
	var duration := float(sample.duration)
	if not is_finite(duration) or duration <= 0.0 or duration > 120.0: return 0.0
	var first := _poses(driver.skeleton, declared_bones[clip])
	for tick in ceili(duration * 2.0 / STEP):
		driver.advance_external(STEP)
		driver.skeleton.force_update_all_bone_transforms()
		if driver.observation_motion_sample().is_empty(): return 0.0
		for row: Dictionary in declared_bones[clip]:
			var actual: Transform3D = driver.skeleton.get_bone_pose(int(row.index))
			if not actual.is_finite(): return 0.0
			var difference := _pose_delta(first[row.name], actual)
			if difference > MOTION_EPSILON: return difference
	return 0.0

func _owner_matches(driver: Node, interruption: String, current: String) -> bool:
	match interruption:
		"movement", "cancel", "restore": return current in driver.animation_graph.GAITS
		"attack": return current in ["attack", "attack_repeat"] and driver.action_active
		"hit": return current in ["hurt", "hurt_repeat"] and driver.action_active
		"dialogue": return current == "dialogue" and driver.story_dialogue_active
		"death": return current == "death" and driver.dead
		"distance": return driver.distance_suspended and not driver.animation_graph.scheduled()
	return false

func _poses(skeleton: Skeleton3D, bones: Array) -> Dictionary:
	var result := {}
	for row: Dictionary in bones: result[row.name] = skeleton.get_bone_pose(int(row.index))
	return result

func _bone_rests(node: Node, prefix: String = "") -> Dictionary:
	var result := {}
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var rests: Array = []
		for bone in skeleton.get_bone_count(): rests.append([skeleton.get_bone_name(bone), skeleton.get_bone_parent(bone), skeleton.get_bone_rest(bone)])
		result[prefix] = rests
	for child: Node in node.get_children():
		result.merge(_bone_rests(child, prefix + "/" + str(child.name)))
	return result

func _pose_delta(first: Transform3D, second: Transform3D) -> float:
	var maximum := 0.0
	for column in 4:
		var left: Vector3 = first.origin if column == 3 else first.basis[column]
		var right: Vector3 = second.origin if column == 3 else second.basis[column]
		for axis in 3: maximum = maxf(maximum, absf(left[axis] - right[axis]))
	return maximum

func _animation(player: AnimationPlayer, clip: String) -> Animation:
	for name: StringName in player.get_animation_list():
		if str(name).get_file() == clip: return player.get_animation(name)
	return null

func _clip_fingerprints(player: AnimationPlayer) -> Dictionary:
	var result := {}
	for name: StringName in player.get_animation_list():
		var animation := player.get_animation(name)
		var values: Array = [animation.length, animation.loop_mode]
		for track in animation.get_track_count():
			values.append([animation.track_get_type(track), str(animation.track_get_path(track)), animation.track_is_enabled(track), animation.track_get_interpolation_type(track)])
			for key in animation.track_get_key_count(track): values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key)])
		result[str(name)] = var_to_str(values).sha256_text()
	return result

func _protected_fingerprints(all_clips: Dictionary) -> Dictionary:
	var result := {}
	for name: String in all_clips:
		if name.get_file() not in Contract.CLIPS: result[name] = all_clips[name]
	return result

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _finish(visual: Node3D) -> void:
	if is_instance_valid(visual): visual.free()
	var report := {"asset":asset, "candidate_only":true, "status":"pass" if failures.is_empty() else "fail", "checks":checks, "failures":failures,
		"source_path":source_path, "input_sha256":input_hashes, "binding_proof":proof, "native_equivalence":native_equivalence, "declared_bones":declared_bones, "samples":samples,
		"interruption_samples":interruption_samples, "expected_interruption_count":32, "visual_accepted":false, "production_source_changed":false, "attack_profiles_recalibrated":false}
	var output := str(options.get("output", ""))
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null: failures.append("Cannot write requested candidate pose receipt")
		else: file.store_string(JSON.stringify(report, "\t"))
	for failure: String in failures: printerr("CREATURE CANDIDATE POSES: " + failure)
	print("CREATURE CANDIDATE POSES: %s checks=%d candidate_only=true visual_accepted=false" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
