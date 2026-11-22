extends "res://tools/verify_community_world_input.gd"

const FACE_NAMES := ["Face_Jaw", "Face_Mouth_L", "Face_Mouth_R", "Face_Eye_L", "Face_Eye_R", "Face_LidUpper_L", "Face_LidUpper_R", "Face_LidLower_L", "Face_LidLower_R", "Face_Brow_L", "Face_Brow_R"]
const SAMPLE_NAMES := ["Face_Jaw", "Face_Mouth_L", "Face_Mouth_R", "Head", "Face_Eye_L"]
var diagnostic_actors: Array[Dictionary] = []
var pose_rows: Array[Dictionary] = []
var signal_counts: Dictionary = {}
var current_actor := ""
var current_phase := ""
var close_camera: Camera3D
var gameplay_camera: Camera3D

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair: PackedStringArray = argument.substr(2).split("=", true, 1)
			options[pair[0]] = pair[1]
	output = str(options.get("output", ""))
	case_id = str(options.get("case", ""))
	start_ms = Time.get_ticks_msec()
	if output.is_empty() or case_id != "lower_face_diagnostic" or not _configure_input_mode() or not _background_rendered_ready() or not _mount_verified_candidate():
		_fail("One rendered lower-face diagnostic requires the isolated published candidate")
		await _finish_diagnostic()
		return
	rules = load("res://scripts/community_campaign.gd")
	topology = load("res://scripts/world_sector_manifest.gd")
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		_fail("Published main scene is unavailable")
		await _finish_diagnostic()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game = main_scene.instantiate()
	root.add_child(game)
	await _frames(4)
	await _button("New Game")
	await _ready("greyfen")
	region = "greyfen"
	if not failures.is_empty():
		await _finish_diagnostic()
		return
	gameplay_camera = root.get_camera_3d()
	var anwen: Node3D = game.zone_root.find_child("sister_anwen", true, false) as Node3D
	var tor: Node3D = game.zone_root.find_child("blacksmith_tor", true, false) as Node3D
	_register_actor("Kael", game.player, game.player.animation_driver)
	_register_actor("Anwen", anwen, anwen.find_child("CharacterAnimationDriver", true, false) if anwen != null else null)
	_register_actor("Tor", tor, tor.find_child("CharacterAnimationDriver", true, false) if tor != null else null)
	if not failures.is_empty():
		await _finish_diagnostic()
		return
	for row: Dictionary in diagnostic_actors:
		if row.id != "Kael" and failures.is_empty():
			gameplay_camera.make_current()
			await _approach_actor(row.actor)
			await _release()
			await _frames(45)
		# Keep the remaining actors' diagnostic evidence even if an approach fails.
		row["geometry"] = _select_geometry(row.driver.character_root, row.skeleton)
		_set_close_camera(row)
		current_actor = str(row.id)
		current_phase = "normal"
		await _frames(16)
		await _snapshot(str(row.id).to_lower() + "_normal", {"diagnostic_phase":"normal"})
		_flush_diagnostic()
		var face: Node = row.face
		var head: Node = row.modifier
		var saved: Dictionary = _save_face_pose(row.skeleton)
		var previous_enabled: bool = head.enabled
		var previous_active: bool = head.active
		var previous_mode: int = face.process_mode
		var previous_timer_paused: bool = face.update_timer.paused if is_instance_valid(face.update_timer) else false
		face.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(face.update_timer): face.update_timer.paused = true
		head.enabled = false
		head.active = false
		_reset_face_to_rest(row.skeleton)
		current_phase = "modifier_disabled_restored"
		await _frames(16)
		await _snapshot(str(row.id).to_lower() + "_modifier_disabled_restored", {"diagnostic_phase":current_phase})
		_flush_diagnostic()
		current_phase = ""
		_restore_face_pose(row.skeleton, saved)
		head.enabled = previous_enabled
		head.active = previous_active
		face.process_mode = previous_mode
		if is_instance_valid(face.update_timer): face.update_timer.paused = previous_timer_paused
		gameplay_camera.make_current()
		close_camera.queue_free()
		close_camera = null
		await _frames(4)
	await _finish_diagnostic()

func _register_actor(id: String, actor: Node3D, driver: Node) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(driver):
		_fail("Actual main-scene actor or driver is missing: " + id)
		return
	var skeleton: Skeleton3D = driver.get_skeleton()
	var owner_ref: WeakRef = skeleton.get_meta("character_face_owner") if skeleton != null and skeleton.has_meta("character_face_owner") else null
	var face: Node = owner_ref.get_ref() if owner_ref != null else actor.find_child("CharacterFaceDriver", true, false)
	var head: Node = face.head_modifier if is_instance_valid(face) else null
	if skeleton == null or not is_instance_valid(face) or not is_instance_valid(head):
		_fail("Actual face skeleton/modifier is missing: " + id)
		return
	var row: Dictionary = {"id":id, "actor":actor, "driver":driver, "skeleton":skeleton, "face":face, "modifier":head, "geometry":[]}
	var after_head: Callable = _record_pose.bind(row, "head_modifier_processed")
	var after_skeleton: Callable = _record_pose.bind(row, "skeleton_updated")
	head.modification_processed.connect(after_head)
	skeleton.skeleton_updated.connect(after_skeleton)
	row["head_callback"] = after_head
	row["skeleton_callback"] = after_skeleton
	diagnostic_actors.append(row)

func _approach_actor(actor: Node3D) -> void:
	var best := Vector3.INF
	var distance := INF
	for index: int in range(8):
		var angle: float = float(index) * TAU / 8.0
		var point: Vector3 = _ground_point(actor.global_position + Vector3(sin(angle), 0, cos(angle)) * 1.6)
		if not point.is_finite() or game.spatial_service.is_position_occupied(point, 0.36, 1.65): continue
		var candidate_distance: float = point.distance_squared_to(game.player.global_position)
		if candidate_distance < distance:
			best = point
			distance = candidate_distance
	if not best.is_finite():
		_fail("No live normal-input approach to " + str(actor.name))
		return
	await _walk_to(best)
	await _ready("greyfen")

func _set_close_camera(row: Dictionary) -> void:
	var skeleton: Skeleton3D = row.skeleton
	var index: int = skeleton.find_bone("Head")
	var center: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(index).origin if index >= 0 else row.actor.global_position + Vector3.UP * 1.55
	var front: Vector3 = row.driver.get_visible_forward()
	close_camera = Camera3D.new()
	close_camera.name = "LowerFaceDiagnosticCamera"
	close_camera.fov = 34.0
	close_camera.near = 0.02
	root.add_child(close_camera)
	close_camera.global_position = center + front * 0.95 + Vector3.UP * 0.015
	close_camera.look_at(center + Vector3.UP * 0.025, Vector3.UP)
	close_camera.make_current()

func _record_pose(row: Dictionary, signal_name: String) -> void:
	if current_actor != row.id or current_phase.is_empty(): return
	var key: String = "%s/%s/%s" % [row.id, current_phase, signal_name]
	var count: int = int(signal_counts.get(key, 0))
	if count >= 12: return
	signal_counts[key] = count + 1
	var skeleton: Skeleton3D = row.skeleton
	var driver: Node = row.driver
	var head: Node = row.modifier
	var face: Node = row.face
	var bones: Array[Dictionary] = []
	var head_index: int = skeleton.find_bone("Head")
	var head_global: Transform3D = skeleton.get_bone_global_pose(head_index) if head_index >= 0 else Transform3D.IDENTITY
	var names: Array[String] = ["Head"]
	names.append_array(FACE_NAMES)
	for name: String in names:
		var index: int = skeleton.find_bone(name)
		if index < 0:
			bones.append({"name":name, "missing":true})
			continue
		var global_pose: Transform3D = skeleton.get_bone_global_pose(index)
		var control: String = name.trim_prefix("Face_")
		var cached_rest: Variant = head.facial_rest.get(control)
		bones.append({
			"modifier_cached_index":int(head.facial_bones.get(control, -1)),
			"modifier_cached_rest":_transform(cached_rest) if cached_rest is Transform3D else [],
			"name":name, "index":index, "parent":skeleton.get_bone_parent(index),
			"rest":_transform(skeleton.get_bone_rest(index)), "local":_transform(skeleton.get_bone_pose(index)),
			"global":_transform(global_pose), "head_relative":_transform(head_global.affine_inverse() * global_pose),
		})
	var sample: Dictionary = {
		"actor":row.id, "phase":current_phase, "signal":signal_name, "process_frame":Engine.get_process_frames(),
		"physics_frame":Engine.get_physics_frames(), "ticks_usec":Time.get_ticks_usec(),
		"animation_state":driver.current_state, "presentation":driver.presentation_state,
		"action":driver.has_active_action(), "dialogue":driver.story_dialogue_active,
		"face_active":head.active, "face_enabled":head.enabled, "face_eligible":face.face_pose_eligible,
		"face_distance_suspended":face.distance_suspended, "skeleton_world":_transform(skeleton.global_transform),
		"bones":bones,
	}
	if signal_name == "skeleton_updated":
		var geometry: Array[Dictionary] = []
		for vertex: Dictionary in row.geometry:
			geometry.append(_skin_vertex(vertex, skeleton, head_global))
		sample["geometry"] = geometry
	pose_rows.append(sample)

func _select_geometry(visual: Node3D, skeleton: Skeleton3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = candidate as MeshInstance3D
		if mesh.mesh == null or mesh.skin == null or mesh.get_node_or_null(mesh.skeleton) != skeleton: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty() or weights.size() != bones.size(): continue
			var stride: int = int(bones.size() / vertices.size())
			for name: String in SAMPLE_NAMES:
				var best_index := -1
				var best_weight := 0.0
				for vertex: int in range(vertices.size()):
					var total := 0.0
					for channel: int in range(stride):
						var offset: int = vertex * stride + channel
						if weights[offset] <= 0.0: continue
						var bind: int = bones[offset]
						if bind < 0 or bind >= mesh.skin.get_bind_count(): continue
						var bone_name: String = str(mesh.skin.get_bind_name(bind))
						if bone_name.is_empty():
							var index: int = mesh.skin.get_bind_bone(bind)
							bone_name = str(skeleton.get_bone_name(index)) if index >= 0 and index < skeleton.get_bone_count() else ""
						if bone_name == name: total += weights[offset]
					if total > best_weight:
						best_index = vertex
						best_weight = total
				if best_index >= 0:
					result.append({"mesh":mesh, "arrays":arrays, "surface":surface, "vertex":best_index, "target":name, "target_weight":best_weight, "stride":stride})
	return result

func _skin_vertex(sample: Dictionary, skeleton: Skeleton3D, head_global: Transform3D) -> Dictionary:
	var mesh: MeshInstance3D = sample.mesh
	var arrays: Array = sample.arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertex: Vector3 = vertices[int(sample.vertex)]
	var normal: Vector3 = normals[int(sample.vertex)] if normals.size() == vertices.size() else Vector3.UP
	var actual := Vector3.ZERO
	var neutral_face := Vector3.ZERO
	var actual_normal := Vector3.ZERO
	var neutral_normal := Vector3.ZERO
	var influences: Array[Dictionary] = []
	for channel: int in range(int(sample.stride)):
		var offset: int = int(sample.vertex) * int(sample.stride) + channel
		var amount: float = weights[offset]
		if amount <= 0.0: continue
		var bind: int = bones[offset]
		var name: StringName = mesh.skin.get_bind_name(bind)
		var bone: int = skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			influences.append({"bind":bind, "bone":bone, "invalid":true})
			continue
		var inverse_bind: Transform3D = mesh.skin.get_bind_pose(bind)
		var evaluated: Transform3D = skeleton.get_bone_global_pose(bone)
		var neutral: Transform3D = head_global * skeleton.get_bone_rest(bone) if str(skeleton.get_bone_name(bone)).begins_with("Face_") else evaluated
		var palette: Transform3D = evaluated * inverse_bind
		var expected: Transform3D = neutral * inverse_bind
		actual += amount * (palette * vertex)
		neutral_face += amount * (expected * vertex)
		actual_normal += amount * (palette.basis * normal)
		neutral_normal += amount * (expected.basis * normal)
		influences.append({"bind":bind, "bone":bone, "name":str(skeleton.get_bone_name(bone)), "weight":amount, "inverse_bind":_transform(inverse_bind)})
	var actual_world: Vector3 = mesh.global_transform * actual
	var expected_world: Vector3 = mesh.global_transform * neutral_face
	return {
		"mesh":str(mesh.get_path()), "surface":sample.surface, "vertex":sample.vertex,
		"target":sample.target, "target_weight":sample.target_weight, "mesh_world":_transform(mesh.global_transform),
		"source_vertex":_vector(vertex), "actual_world":_vector(actual_world), "neutral_face_world":_vector(expected_world),
		"position_delta_m":actual_world.distance_to(expected_world),
		"normal_angle_rad":actual_normal.normalized().angle_to(neutral_normal.normalized()), "influences":influences,
	}

func _save_face_pose(skeleton: Skeleton3D) -> Dictionary:
	var saved: Dictionary = {}
	for name: String in FACE_NAMES:
		var index: int = skeleton.find_bone(name)
		if index >= 0: saved[name] = skeleton.get_bone_pose(index)
	return saved

func _reset_face_to_rest(skeleton: Skeleton3D) -> void:
	for name: String in FACE_NAMES:
		var index: int = skeleton.find_bone(name)
		if index < 0: continue
		var rest: Transform3D = skeleton.get_bone_rest(index)
		skeleton.set_bone_pose_position(index, rest.origin)
		skeleton.set_bone_pose_rotation(index, rest.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index, rest.basis.get_scale())

func _restore_face_pose(skeleton: Skeleton3D, saved: Dictionary) -> void:
	for name: String in saved:
		var index: int = skeleton.find_bone(name)
		var pose: Transform3D = saved[name]
		if index < 0: continue
		skeleton.set_bone_pose_position(index, pose.origin)
		skeleton.set_bone_pose_rotation(index, pose.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index, pose.basis.get_scale())

func _transform(value: Transform3D) -> Array:
	return [_vector(value.basis.x), _vector(value.basis.y), _vector(value.basis.z), _vector(value.origin)]

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _finish_diagnostic() -> void:
	for row: Dictionary in diagnostic_actors:
		if is_instance_valid(row.modifier) and row.modifier.modification_processed.is_connected(row.head_callback):
			row.modifier.modification_processed.disconnect(row.head_callback)
		if is_instance_valid(row.skeleton) and row.skeleton.skeleton_updated.is_connected(row.skeleton_callback):
			row.skeleton.skeleton_updated.disconnect(row.skeleton_callback)
	_flush_diagnostic()
	await _finish()

func _flush_diagnostic() -> void:
	var identities: Array[String] = []
	for row: Dictionary in diagnostic_actors: identities.append(str(row.id))
	report_extra["lower_face_diagnostic"] = {"actors":identities, "samples":pose_rows, "signal_counts":signal_counts, "gameplay_acceptance":false}
	if not output.is_empty():
		var stream: FileAccess = FileAccess.open(output.path_join("lower_face_samples.json"), FileAccess.WRITE)
		if stream != null:
			stream.store_string(JSON.stringify(report_extra["lower_face_diagnostic"], "\t"))
			stream.flush()

func _expected_work() -> Array:
	return []
