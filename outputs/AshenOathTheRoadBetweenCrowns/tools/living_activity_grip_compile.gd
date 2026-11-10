extends RefCounted

const EQUIPMENT_EVIDENCE := "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/equipment"
const PRESENTATION := "res://scripts/character_presentation.gd"
const GEOMETRY := "res://scripts/held_prop_geometry.gd"

## Read actor-owned, measured generic prop fits during motion-library compilation.
## Missing receipts are allowed while working on a candidate. Malformed or stale
## receipts fail before a library is saved.

static func apply(library: AnimationLibrary, skeleton: Skeleton3D, repository: String, actor_folder: String,
		asset: String, motion_sha256: String, model_path: String, prepared_path: String,
		base_player: AnimationPlayer, required: bool = false) -> Dictionary:
	var path := actor_folder.path_join("activity_grips.json")
	if not FileAccess.file_exists(path):
		return _error(asset, "release requires measured activity grips") if required else {}
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not receipt is Dictionary or int(receipt.get("schema_version", 0)) != 1 \
			or receipt.get("asset", "") != asset or receipt.get("motion_sha256", "") != motion_sha256 \
			or receipt.get("model_sha256", "") != FileAccess.get_sha256(model_path):
		return _error(asset, "receipt does not match the actor and motion sources")
	var fits: Variant = receipt.get("fits")
	if not fits is Dictionary or fits.is_empty():
		return _error(asset, "receipt has no measured grip records")
	if required:
		var expected := ["bread"] if asset in ["C09", "C10"] else ["bread", "supply"]
		if fits.size() != expected.size() or expected.any(func(style: String) -> bool: return not fits.has(style)):
			return _error(asset, "release receipt is missing a required grip style")
	var records := {}
	for key: Variant in fits:
		if key not in ["bread", "supply"] or not fits[key] is Dictionary:
			return _error(asset, "unknown or malformed generic grip")
		var style := str(key)
		var record := _read_fit(repository, asset, style, fits[key], skeleton)
		if not record.has("error"):
			var error := _check_provenance(repository, asset, style, fits[key], record, model_path,
				prepared_path, base_player, library)
			if not error.is_empty():
				return _error(asset, style + " " + error)
		if record.has("error"):
			return record
		records[style] = record.grip
	library.set_meta("activity_prop_grips", records)
	return {"sha256": FileAccess.get_sha256(path)}


static func _read_fit(repository: String, asset: String, style: String, source: Dictionary, skeleton: Skeleton3D) -> Dictionary:
	var path := _art_path(repository, source.get("evidence", ""))
	var digest := _digest(path)
	if digest.is_empty() or digest != source.get("evidence_sha256", ""):
		return _error(asset, style + " evidence path or hash differs")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not proof is Dictionary or proof.get("asset", "") != asset or not proof.get("fits") is Dictionary:
		return _error(asset, style + " evidence belongs to a different actor")
	var fit: Variant = proof.fits.get(style)
	if not fit is Dictionary or fit.get("surface_clearance_verified") != true \
			or fit.get("closed_component_containment_verified") != true or not fit.get("proposal") is Dictionary:
		return _error(asset, style + " lacks measured clearance and contact")
	var frames: Variant = fit.get("verified_frames")
	var expected: Variant = fit.get("expected_frames")
	if typeof(frames) not in [TYPE_INT, TYPE_FLOAT] or frames <= 0 or frames != expected or floor(frames) != frames:
		return _error(asset, style + " does not cover its complete measured trajectory")
	var proposal: Dictionary = fit.proposal
	var contact: Variant = proposal.get("maximum_contact_error_m")
	if typeof(contact) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(contact)) or contact < 0.0 or contact > 0.001:
		return _error(asset, style + " contact error exceeds one millimetre")
	var editable: Variant = fit.get("editable_scene")
	if not editable is Dictionary:
		return _error(asset, style + " has no editable source scene")
	var scene_name := str(editable.get("path", ""))
	var scene_path := path.get_base_dir().path_join(scene_name)
	if scene_name != scene_name.get_file() or not scene_name.ends_with(".blend") or not FileAccess.file_exists(scene_path) \
			or FileAccess.get_sha256(scene_path) != str(editable.get("sha256", "")):
		return _error(asset, style + " editable scene hash differs")
	var bone := "hand_l" if asset == "C01" else "hand_r"
	if proposal.get("bone", "") != bone or skeleton.find_bone(bone) < 0:
		return _error(asset, style + " does not bind the retained activity hand")
	var palm := _vector(proposal.get("palm"))
	var anchor := _vector(proposal.get("anchor"))
	var columns: Variant = proposal.get("basis")
	if not palm.is_finite() or palm.length() < 0.005 or palm.length() > 0.18 \
			or not anchor.is_finite() or anchor.length() > 1.5 or not columns is Array or columns.size() != 3:
		return _error(asset, style + " has an invalid palm, anchor or basis")
	var x := _vector(columns[0])
	var y := _vector(columns[1])
	var z := _vector(columns[2])
	if not x.is_finite() or not y.is_finite() or not z.is_finite():
		return _error(asset, style + " basis is nonfinite")
	var basis := Basis(x, y, z)
	if not is_equal_approx(basis.determinant(), 1.0) or not basis.is_equal_approx(basis.orthonormalized()):
		return _error(asset, style + " basis would distort the prop")
	return {
		"grip": {"verified": true, "bone": bone, "palm": palm, "anchor": anchor, "basis": basis, "source_sha256": digest},
		"frames": int(frames),
		"by_clip": fit.get("verified_by_clip", {}),
		"placement_sha256": fit.get("placement_sha256", ""),
		"socket_frames": fit.get("native_socket_frames", 0),
		"maximum_socket_error": fit.get("maximum_native_socket_frame_error_m", INF),
		"inputs": proof.get("source_sha256", proof.get("input_sha256", {})),
	}


static func _check_provenance(repository: String, asset: String, style: String, source: Dictionary, fit: Dictionary,
		model_path: String, prepared_path: String, base_player: AnimationPlayer, library: AnimationLibrary) -> String:
	var inputs: Variant = fit.inputs
	if not inputs is Dictionary or inputs.is_empty():
		return "fit has no frozen input identities"
	var native_path := _art_path(repository, source.get("native_pose_evidence", ""))
	var native: Variant = _native_pose(native_path, inputs, asset, model_path, prepared_path)
	if native == null:
		return "native pose evidence, actor model or prepared scene differs"
	var route_path := _art_path(repository, source.get("route_pose_evidence", ""))
	if source.has("route_pose_evidence") and (route_path.is_empty() or asset != "C11" or style != "supply"):
		return "only the measured Nessa supply route has a composite fit"
	var sample_count := 0
	var goals := {}
	for clip: Variant in native.clips:
		if not clip is Dictionary:
			return "native pose evidence has malformed sample clips"
		if clip.get("prop") == style and (route_path.is_empty() or clip.get("clip") == "Authoring_Carry_Idle"):
			var count: Variant = clip.get("frames")
			if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or count <= 0 or count != floor(count):
				return "native pose evidence has an invalid frame count"
			sample_count += int(count)
			var mode := "moving" if clip.get("moving", false) else "standing"
			var goal := _wrist_goal(repository, style, source, native.inputs, clip, int(count))
			if not goal.is_finite() or goal.length() > 0.15 or (goals.has(mode) and goals[mode] != goal):
				return "fit does not bind a single measured wrist goal per pose"
			goals[mode] = goal
	if not goals.has("standing"):
		return "fit does not cover a native standing trajectory"
	if not route_path.is_empty():
		for pose_path: String in [native_path, route_path]:
			var inspection := _digest(pose_path.get_base_dir().path_join("import_fidelity.json"))
			if inspection.is_empty() or not inspection in inputs.values():
				return "supply fit lacks a measured Blender import"
		var route: Variant = _native_pose(route_path, inputs, asset, model_path, prepared_path)
		var checked := _checked_supply_route(route, fit, sample_count)
		if checked.is_empty() or route.get("retained_animation_fingerprints") != native.retained_animation_fingerprints:
			return "supply fit does not bind the measured reveal and route"
		var moving: Vector2 = goals.standing + Vector2(float(checked.forward), 0.0)
		if not moving.is_finite() or moving.length() > 0.15:
			return "measured moving wrist goal exceeds its bound"
		goals["moving"] = moving
		fit.grip["moving_route"] = "greyfen:saga_nessa:baker_day:4:work_to_errand"
		sample_count += int(checked.frames)
	if fit.frames != sample_count:
		return "fit does not cover the native trajectory"
	if base_player == null or library.get_animation_list().is_empty():
		return "retained animation binding is missing"
	var fingerprints: Dictionary = native.retained_animation_fingerprints
	for name: String in ["Idle", "Walk"]:
		if not base_player.has_animation(name) or fingerprints.get(name) != _clip_fingerprint(base_player.get_animation(name)):
			return "retained locomotion changed after fitting"
	for name: StringName in library.get_animation_list():
		if fingerprints.get("life/" + str(name)) != _clip_fingerprint(library.get_animation(name)):
			return "authored life clips changed after fitting"
	var prop_path := repository.path_join(EQUIPMENT_EVIDENCE).path_join("retained_" + style + ".json")
	var prop_digest := _digest(prop_path)
	if prop_digest.is_empty() or not prop_digest in inputs.values():
		return "retained prop evidence was not used by the fit"
	var prop: Variant = JSON.parse_string(FileAccess.get_file_as_string(prop_path))
	if not prop is Dictionary or prop.get("style") != style or prop.get("geometry_sha256") != _digest(GEOMETRY) \
			or not prop.get("native_roundtrip") is Dictionary or prop.native_roundtrip.get("verified") != true \
			or not _presentation_compatible(repository, style, prop_digest, prop):
		return "retained prop source changed after fitting"
	fit.grip["wrist_goals"] = goals
	return ""


static func _native_pose(path: String, fit_inputs: Dictionary, asset: String, model: String, prepared: String) -> Variant:
	var digest := _digest(path)
	if digest.is_empty() or not digest in fit_inputs.values():
		return null
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not proof is Dictionary or proof.get("asset") != asset or proof.get("status") != "authoring_pose_exported" \
			or proof.get("sample_hz") != 120 or not proof.get("inputs") is Dictionary \
			or not proof.get("clips") is Array or not proof.get("retained_animation_fingerprints") is Dictionary \
			or not proof.get("roundtrip") is Dictionary or proof.roundtrip.get("verified") != true:
		return null
	if model == prepared or not prepared.begins_with("res://assets_external/characters_prepared/") \
			or prepared.get_extension() not in ["scn", "tscn"]:
		return null
	for resource: String in [model, prepared]:
		var resource_sha := _digest(resource)
		if resource_sha.is_empty() or proof.inputs.get(resource) != resource_sha:
			return null
	return proof


static func _checked_supply_route(proof: Variant, fit: Dictionary, standing_frames: int) -> Dictionary:
	var coverage: Variant = fit.by_clip
	var placement: Variant = fit.placement_sha256
	if not proof is Dictionary or proof.clips.size() != 1 or not coverage is Dictionary \
			or not placement is String or placement.length() != 64 or not placement.is_valid_hex_number(false) \
			or not _bounded_error(fit.maximum_socket_error, 0.0001):
		return {}
	var clip: Variant = proof.clips[0]
	var route_clip := "Authoring_Carry_Scheduler_Route"
	if not clip is Dictionary or clip.get("clip") != route_clip or clip.get("prop") != "supply" \
			or clip.get("hand") != "hand_r" or not clip.get("route") is Dictionary or not clip.get("hand_samples") is Array:
		return {}
	var route: Dictionary = clip.route
	if route.get("intent_key") != "baker_day:4" or route.get("outbound_target_index") != 1 \
			or route.get("actual_controller") != true or route.get("arrival_observed") != true \
			or route.get("braking_observed") != true or route.get("revealed_after_owning_solve") != true \
			or clip.hand_samples.size() != clip.get("frames"):
		return {}
	var moving := 0
	var stationary := 0
	var bonus := 0.0
	for sample: Variant in clip.hand_samples:
		if not sample is Dictionary or not sample.get("prop_visible") is bool:
			return {}
		if not sample.prop_visible:
			continue
		var weight: Variant = sample.get("pose_weight")
		var socket: Variant = sample.get("socket_witness")
		if typeof(weight) not in [TYPE_INT, TYPE_FLOAT] or not is_equal_approx(float(weight), 1.0) \
				or sample.get("current_branch") != "locomotion" or sample.get("fading_from") != "" \
				or not sample.get("paired_goal") is Dictionary or not socket is Dictionary \
				or socket.get("bone") != "hand_r" or socket.get("placement_sha256") != placement \
				or not _bounded_error(socket.get("anchor_error_m"), 0.001):
			return {}
		if sample.paired_goal.is_empty():
			stationary += 1
		else:
			var extra: Variant = sample.paired_goal.get("additional_forward_m")
			if not extra is float or not is_finite(extra) or extra <= 0.0 or (moving > 0 and bonus != extra):
				return {}
			bonus = extra
			moving += 1
	var total := moving + stationary
	if moving <= 0 or stationary <= 0 or fit.socket_frames != total or route.get("visible_moving_frames") != moving \
			or route.get("visible_standing_frames") != stationary or coverage.size() != 2 \
			or coverage.get("Authoring_Carry_Idle") != standing_frames or coverage.get(route_clip) != total:
		return {}
	return {"frames": total, "forward": bonus}


static func _bounded_error(value: Variant, limit: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0.0 and value <= limit


static func _presentation_compatible(repository: String, style: String, prop_digest: String, prop: Dictionary) -> bool:
	var current := _digest(PRESENTATION)
	if current == prop.get("presentation_sha256"):
		return true
	var folder := repository.path_join(EQUIPMENT_EVIDENCE)
	var path := folder.path_join("retained_prop_presentation_compatibility.json")
	if not FileAccess.file_exists(path):
		return false
	var bridge: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bridge is Dictionary or bridge.get("schema_version") != 1 or bridge.get("accepted") != true \
			or bridge.get("presentation_sha256") != current or bridge.get("historical_presentation_sha256") != prop.get("presentation_sha256") \
			or bridge.get("geometry_sha256") != prop.get("geometry_sha256") or not bridge.get("props") is Dictionary:
		return false
	var verified: Variant = bridge.props.get(style)
	if not verified is Dictionary or verified.get("retained_receipt_sha256") != prop_digest:
		return false
	for manifest: String in ["mesh_manifest_sha256", "channel_manifest_sha256"]:
		var expected: Variant = prop.get("manifest_sha256" if manifest == "mesh_manifest_sha256" else manifest)
		var filename := "retained_" + style + "_" + manifest.trim_suffix("_sha256") + ".json"
		if verified.get(manifest) != expected or _digest(folder.path_join(filename)) != expected:
			return false
		for mode: String in ["fallback", "measured"]:
			var readback: Variant = verified.get(mode)
			if not readback is Dictionary or readback.get(manifest) != expected or readback.get("measured_grip") != (mode == "measured"):
				return false
	return true


static func _wrist_goal(repository: String, style: String, source: Dictionary, inputs: Dictionary, clip: Dictionary,
		frame_count: int) -> Vector2:
	var goal: Variant = clip.get("goal_trial")
	if goal == null:
		return Vector2.ZERO
	if not goal is Dictionary or goal.get("applications") != frame_count or goal.get("hand") != "hand_r" \
			or goal.get("opposite_hand_preserved") != true or goal.get("right_translation_and_scale_preserved") != true:
		return Vector2.INF
	var forward: Variant = goal.get("forward_m")
	var outward: Variant = goal.get("outward_m")
	if forward == null and outward == null:
		# These Nessa trials stored the offsets in their measured source scripts.
		var script := _measured_script(repository, source.get("legacy_wrist_source"), inputs)
		if style == "bread":
			forward = _source_number(script, "BREAD_FORWARD")
			outward = _source_number(script, "BREAD_OUTWARD")
		elif source.has("route_pose_evidence"):
			var standing := _measured_script(repository, source.get("standing_wrist_source"), inputs)
			forward = _source_number(standing, "FORWARD_WITH_TORSO_CLEARANCE")
			outward = _source_number(script, "SUPPLY_OUTWARD")
	else:
		var error: Variant = goal.get("maximum_goal_error_m")
		if goal.get("selected") != true or typeof(error) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(error)) or error < 0.0 or error > 0.0001:
			return Vector2.INF
	if typeof(forward) not in [TYPE_INT, TYPE_FLOAT] or typeof(outward) not in [TYPE_INT, TYPE_FLOAT]:
		return Vector2.INF
	return Vector2(float(forward), float(outward))


static func _measured_script(repository: String, relative: Variant, inputs: Dictionary) -> String:
	var path := _art_path(repository, relative, ".gd")
	var digest := _digest(path)
	return FileAccess.get_file_as_string(path) if not digest.is_empty() and digest in inputs.values() else ""


static func _source_number(script: String, constant: String) -> float:
	var prefix := "const " + constant + " := "
	var value := INF
	for line: String in script.split("\n"):
		if line.begins_with(prefix):
			var raw := line.trim_prefix(prefix).strip_edges()
			if value != INF or not raw.is_valid_float():
				return INF
			value = raw.to_float()
	return value


static func _clip_fingerprint(animation: Animation) -> String:
	var values: Array = [animation.length, animation.loop_mode]
	for track in animation.get_track_count():
		values.append([animation.track_get_type(track), str(animation.track_get_path(track))])
		for key in animation.track_get_key_count(track):
			values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key)])
	return var_to_str(values).sha256_text()


static func _art_path(repository: String, relative: Variant, extension: String = ".json") -> String:
	if not relative is String or not relative.begins_with("art_source/") or not relative.ends_with(extension) or "\\" in relative:
		return ""
	for segment: String in relative.split("/"):
		if segment in ["", ".", ".."]:
			return ""
	return repository.path_join(relative)


static func _digest(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() and FileAccess.file_exists(path) else ""


static func _vector(raw: Variant) -> Vector3:
	if not raw is Array or raw.size() != 3:
		return Vector3.INF
	for component: Variant in raw:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return Vector3.INF
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _error(asset: String, message: String) -> Dictionary:
	return {"error": "Activity grips " + asset + ": " + message}
