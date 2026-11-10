extends RefCounted

const EQUIPMENT_EVIDENCE := "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/equipment"
const PRESENTATION := "res://scripts/character_presentation.gd"
const GEOMETRY := "res://scripts/held_prop_geometry.gd"

## Read actor-owned, measured generic prop fits during motion-library compilation.
## Missing receipts are allowed while working on a candidate. Malformed or stale
## receipts fail before a library is saved.

static func apply(library: AnimationLibrary, skeleton: Skeleton3D, repository: String, actor_folder: String,
		asset: String, motion_sha256: String, model_path: String, prepared_path: String,
		base_player: AnimationPlayer) -> Dictionary:
	var path := actor_folder.path_join("activity_grips.json")
	if not FileAccess.file_exists(path):
		return {}
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not receipt is Dictionary or int(receipt.get("schema_version", 0)) != 1 \
			or receipt.get("asset", "") != asset or receipt.get("motion_sha256", "") != motion_sha256 \
			or receipt.get("model_sha256", "") != FileAccess.get_sha256(model_path):
		return _error(asset, "receipt does not match the actor and motion sources")
	var fits: Variant = receipt.get("fits")
	if not fits is Dictionary or fits.is_empty():
		return _error(asset, "receipt has no measured grip records")
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
		"inputs": proof.get("source_sha256", proof.get("input_sha256", {})),
	}


static func _check_provenance(repository: String, asset: String, style: String, source: Dictionary, fit: Dictionary,
		model_path: String, prepared_path: String, base_player: AnimationPlayer, library: AnimationLibrary) -> String:
	var inputs: Variant = fit.inputs
	if not inputs is Dictionary or inputs.is_empty():
		return "fit has no frozen input identities"
	var native_path := _art_path(repository, source.get("native_pose_evidence", ""))
	var native_digest := _digest(native_path)
	if native_digest.is_empty() or not native_digest in inputs.values():
		return "native pose evidence was not used by the fit"
	var native: Variant = JSON.parse_string(FileAccess.get_file_as_string(native_path))
	if not native is Dictionary or native.get("asset") != asset or native.get("status") != "authoring_pose_exported" \
			or native.get("sample_hz") != 120 or not native.get("inputs") is Dictionary \
			or not native.get("clips") is Array or not native.get("retained_animation_fingerprints") is Dictionary \
			or not native.get("roundtrip") is Dictionary or native.roundtrip.get("verified") != true:
		return "native pose evidence has a different actor or sample contract"
	if model_path == prepared_path or not prepared_path.begins_with("res://assets_external/characters_prepared/") \
			or prepared_path.get_extension() not in ["scn", "tscn"]:
		return "prepared scene path does not identify the sampled actor"
	for path: String in [model_path, prepared_path]:
		var digest := _digest(path)
		if digest.is_empty() or native.inputs.get(path) != digest:
			return "retained model or prepared scene differs from the sampled actor"
	var sample_count := 0
	for clip: Variant in native.clips:
		if not clip is Dictionary:
			return "native pose evidence has malformed sample clips"
		if clip.get("prop") == style:
			var count: Variant = clip.get("frames")
			if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or count <= 0 or count != floor(count):
				return "native pose evidence has an invalid frame count"
			sample_count += int(count)
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
	if not prop is Dictionary or prop.get("style") != style or prop.get("presentation_sha256") != _digest(PRESENTATION) \
			or prop.get("geometry_sha256") != _digest(GEOMETRY) or not prop.get("native_roundtrip") is Dictionary \
			or prop.native_roundtrip.get("verified") != true:
		return "retained prop source changed after fitting"
	return ""


static func _clip_fingerprint(animation: Animation) -> String:
	var values: Array = [animation.length, animation.loop_mode]
	for track in animation.get_track_count():
		values.append([animation.track_get_type(track), str(animation.track_get_path(track))])
		for key in animation.track_get_key_count(track):
			values.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key)])
	return var_to_str(values).sha256_text()


static func _art_path(repository: String, relative: Variant) -> String:
	if not relative is String or not relative.begins_with("art_source/") or not relative.ends_with(".json") or "\\" in relative:
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
