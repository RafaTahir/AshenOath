extends SceneTree

## Compile reviewed Blender carriers to immutable actor-owned motion libraries.
## Does not build a world, mutate source models or claim visual acceptance.
const IDS := ["C11", "C05", "C06", "C12", "C07", "C09", "C10", "C08"]
const IDENTITIES := {"C11": "nessa", "C05": "elna", "C06": "toma", "C12": "nera", "C07": "senn", "C09": "vale", "C10": "merrow", "C08": "edric", "P01": "kael"}
const CLIPS := {"Life_Idle_A": 6.0, "Life_Idle_B": 8.0, "Life_Work": 4.0, "Life_Listen": 4.0, "Life_Speak": 4.0}
const FUSION = preload("res://scripts/character_animation_fusion.gd")
const GRIPS = preload("res://tools/living_activity_grip_compile.gd")
const FACE_REPAIR = preload("res://tools/face_repair_provenance.gd")
const OUTPUT := "res://assets_external/characters_prepared/animations/"

func _initialize() -> void:
	call_deferred("_compile")

func _find(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child: Node in node.get_children():
		var found := _find(child, kind)
		if found != null:
			return found
	return null

func _compile() -> void:
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var source_root := repository.path_join("art_source/art_recovery_v2/models/living_cast_stage2_20261107")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	var requested: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var selected := args.find("--asset")
	if selected >= 0 and selected + 1 < args.size():
		requested.append(args[selected + 1])
	else:
		requested.assign(IDS)
	if requested == ["P01"]:
		source_root = repository.path_join("art_source/art_recovery_v2/models/living_assets_stage3_20261107/player")
	var reports: Array[Dictionary] = []
	var reused_face_repair := false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for id: String in requested:
		if id not in IDS and id != "P01":
			push_error("Unknown living cast asset: " + id)
			quit(1)
			return
		var source := source_root.path_join(id).path_join(id + "_life_review.glb")
		var model_path := ""
		var prepared_path := ""
		for key: String in catalog:
			if ("/" + id + "_") in str(catalog[key].source):
				prepared_path = str(catalog[key].path)
				model_path = str(catalog[key].source)
				break
		if not FileAccess.file_exists(source) or prepared_path.is_empty():
			push_error("Missing authored carrier or prepared actor: " + id)
			quit(1)
			return
		var authoring_path := source_root.path_join(id).path_join("authoring.json")
		var authoring: Variant = JSON.parse_string(FileAccess.get_file_as_string(authoring_path))
		if not authoring is Dictionary or str(authoring.get("review_glb_sha256", "")) != FileAccess.get_sha256(source):
			push_error("Life source receipt no longer matches its carrier/production actor: " + id)
			quit(1)
			return
		var reused := FACE_REPAIR.reuse_library(repository, id, source, model_path, prepared_path, authoring)
		if reused.has("error"):
			push_error(str(reused.error))
			quit(1)
			return
		if not reused.is_empty():
			reports.append(reused.row)
			reused_face_repair = true
			print("LIVING_CAST_LIBRARY_REUSED ", id, " exact retained life library")
			continue
		if str(authoring.get("production_sha256", "")) != FileAccess.get_sha256(model_path):
			push_error("Life source receipt no longer matches its production actor: " + id)
			quit(1)
			return
		var target := (load(prepared_path) as PackedScene).instantiate()
		var target_player := FUSION.attach_shared_library(target)
		var target_skeleton := _find(target, "Skeleton3D") as Skeleton3D
		if target_player == null or target_skeleton == null:
			push_error("Prepared actor has no animation binding: " + id)
			quit(1)
			return
		var target_root := target_player.get_node(target_player.root_node)
		var skeleton_path := str(target_root.get_path_to(target_skeleton))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(source, state)
		if error != OK:
			push_error("Cannot import life carrier: %s (%d)" % [id, error])
			quit(1)
			return
		var carrier := document.generate_scene(state)
		var player := _find(carrier, "AnimationPlayer") as AnimationPlayer
		var carrier_skeleton := _find(carrier, "Skeleton3D") as Skeleton3D
		if player == null or carrier_skeleton == null:
			push_error("Life carrier has no native clips: " + id)
			quit(1)
			return
		var maximum_rest_error := 0.0
		for bone_index in target_skeleton.get_bone_count():
			var name := target_skeleton.get_bone_name(bone_index)
			var source_index := carrier_skeleton.find_bone(name)
			if source_index < 0:
				push_error("Authored carrier lost a retained bone: " + name)
				quit(1)
				return
			var original := target_skeleton.get_bone_rest(bone_index)
			var retained := carrier_skeleton.get_bone_rest(source_index)
			maximum_rest_error = maxf(maximum_rest_error, original.origin.distance_to(retained.origin))
			for axis in 3:
				maximum_rest_error = maxf(maximum_rest_error, original.basis[axis].distance_to(retained.basis[axis]))
		if maximum_rest_error > 0.0001:
			push_error("Authored carrier changed retained rest transforms: %s error=%f" % [id, maximum_rest_error])
			quit(1)
			return
		var library := AnimationLibrary.new()
		library.set_meta("schema_version", 1)
		library.set_meta("actor_identity", str(IDENTITIES[id]))
		library.set_meta("contact_fraction", 0.5)
		library.set_meta("source_sha256", FileAccess.get_sha256(source))
		if id in IDS:
			# Blender may choose a different editable bone-axis basis. Convert
			# measured world-space palm surfaces through the actual imported pose
			# instead of assuming Blender-local probe vectors are Godot-local.
			var surfaces: Dictionary = {}
			var source_hands: Dictionary = {}
			for sample: Dictionary in authoring.clips.Life_Work.sampled_points:
				if is_equal_approx(float(sample.phase), 0.5):
					surfaces = sample.get("world_contact_probes", {})
					source_hands = sample.get("world_points", {})
			if not surfaces.has("l") or not surfaces.has("r"):
				push_error("Missing measured retained palm surfaces: " + id)
				quit(1)
				return
			root.add_child(carrier)
			player.play("Life_Work")
			player.seek(2.0, true)
			player.advance(0.0)
			carrier_skeleton.force_update_all_bone_transforms()
			var probes: Dictionary = {}
			for side: String in ["l", "r"]:
				var measured: Array = surfaces[side]
				var world_point := Vector3(float(measured[0]), float(measured[2]), -float(measured[1]))
				var hand_pose := carrier_skeleton.global_transform * carrier_skeleton.get_bone_global_pose(carrier_skeleton.find_bone("hand_" + side))
				var recorded_hand: Array = source_hands["hand_" + side]
				var expected_hand := Vector3(float(recorded_hand[0]), float(recorded_hand[2]), -float(recorded_hand[1]))
				if hand_pose.origin.distance_to(expected_hand) > 0.002:
					push_error("Imported native contact pose differs from Blender FK: %s/%s" % [id, side])
					quit(1)
					return
				var local_point := hand_pose.affine_inverse() * world_point
				if not local_point.is_finite() or local_point.length() < 0.015 or local_point.length() > 0.15:
					push_error("Invalid retained palm contact probe: %s/%s" % [id, side])
					quit(1)
					return
				probes["left" if side == "l" else "right"] = local_point
			library.set_meta("contact_probes", probes)
			library.set_meta("contact_probe_method", str(authoring.contact_probe_method) + "; converted through imported native Work pose")
			player.stop()
		var clip_report: Dictionary = {}
		var required_clips := CLIPS.duplicate()
		if id == "P01":
			required_clips = {"Life_Idle_A": 6.0, "Life_Idle_B": 8.0}
		if id == "C09":
			required_clips["Life_Settle_Ledger"] = 4.0
		if id == "C10":
			required_clips["Life_Cup_Hold"] = 4.0
			required_clips["Life_Drink"] = 4.0
		for clip: String in required_clips:
			if not player.has_animation(clip):
				push_error("Missing authored clip: %s/%s" % [id, clip])
				quit(1)
				return
			var animation := player.get_animation(clip).duplicate(true) as Animation
			if absf(animation.length - float(required_clips[clip])) > 0.001:
				push_error("Wrong authored duration: %s/%s" % [id, clip])
				quit(1)
				return
			for track in range(animation.get_track_count() - 1, -1, -1):
				var path := animation.track_get_path(track)
				var bone := str(path.get_subname(0)) if path.get_subname_count() == 1 else ""
				# Object transforms remain with physics and face joints with their
				# modifier. Keep the retained static skeletal basis and body poses.
				if bone.is_empty() or bone.begins_with("Face_"):
					animation.remove_track(track)
					continue
				if bone == "root" and animation.track_get_key_count(track) > 1:
					var initial: Variant = animation.track_get_key_value(track, 0)
					for key_index in range(1, animation.track_get_key_count(track)):
						var value: Variant = animation.track_get_key_value(track, key_index)
						var deviation: float = initial.angle_to(value) if initial is Quaternion else initial.distance_to(value) if initial is Vector3 else 1.0
						if float(deviation) > 0.00001:
							push_error("Authored life clip moves its skeletal root: %s/%s" % [id, clip])
							quit(1)
							return
				if target_skeleton.find_bone(bone) < 0:
					push_error("Unbound life bone: %s/%s/%s" % [id, clip, bone])
					quit(1)
					return
				# Blender samples static position/scale channels on every joint.
				# Omit only channels proven equal to the actual target rest value;
				# preserve pelvis offsets and every authored body rotation.
				var type := animation.track_get_type(track)
				if type in [Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
					var rest := target_skeleton.get_bone_rest(target_skeleton.find_bone(bone))
					var reference := rest.origin if type == Animation.TYPE_POSITION_3D else Vector3.ONE
					var constant_rest := true
					for key_index in animation.track_get_key_count(track):
						var value: Vector3 = animation.track_get_key_value(track, key_index)
						if value.distance_to(reference) > 0.000001:
							constant_rest = false
							break
					if constant_rest:
						animation.remove_track(track)
						continue
				animation.track_set_path(track, NodePath(skeleton_path + ":" + bone))
			animation.loop_mode = Animation.LOOP_NONE if clip in ["Life_Drink", "Life_Settle_Ledger"] else Animation.LOOP_LINEAR
			animation.set_meta("universal_rest_baked", true)
			animation.set_meta("authored_life_clip", true)
			animation.set_meta("life_source_sha256", FileAccess.get_sha256(source))
			if clip == "Life_Work":
				animation.set_meta("work_contact_phase", 0.5)
			library.add_animation(clip, animation)
			clip_report[clip] = {"duration": animation.length, "tracks": animation.get_track_count(), "skeleton_path": skeleton_path}
		var grip_receipt := GRIPS.apply(library, target_skeleton, repository, source_root.path_join(id),
				id, str(library.get_meta("source_sha256")), model_path, prepared_path, target_player,
				args.has("--require-activity-grips") and id != "P01")
		if grip_receipt.has("error"):
			push_error(str(grip_receipt.error))
			carrier.free()
			target.free()
			quit(1)
			return
		var output := OUTPUT + "life_" + id + ".res"
		error = ResourceSaver.save(library, output, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Cannot save life library: " + id)
			quit(1)
			return
		var probe_report: Dictionary = {}
		for side: String in library.get_meta("contact_probes", {}):
			var value: Vector3 = library.get_meta("contact_probes")[side]
			probe_report[side] = [value.x, value.y, value.z]
		reports.append({"asset": id, "source": source, "source_sha256": FileAccess.get_sha256(source), "model": model_path, "model_sha256": FileAccess.get_sha256(model_path), "path": output, "sha256": FileAccess.get_sha256(output), "bytes": FileAccess.get_file_as_bytes(output).size(), "maximum_rest_error": maximum_rest_error, "clips": clip_report, "contact_probes": probe_report, "contact_probe_method": str(library.get_meta("contact_probe_method", "not_required")), "runtime_reviewed": false, "user_accepted": false})
		if not grip_receipt.is_empty():
			reports.back()["activity_grip_receipt_sha256"] = str(grip_receipt.sha256)
		carrier.free()
		target.free()
		print("LIVING_CAST_LIBRARY ", id, " ", output, " native clips=", required_clips.size())
	var report_prefix := "library_compile_face_repair_" if reused_face_repair else "library_compile_"
	var report_path := source_root.path_join(report_prefix + "_".join(requested) + ".json")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Cannot save life compile evidence")
		quit(1)
		return
	report_file.store_string(JSON.stringify({"status": "compiled", "libraries": reports}, "\t") + "\n")
	quit(0)
