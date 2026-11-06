extends RefCounted

## Builder-only proof: never trust a GLTF extra as ambient-animation authority.
const CLIPS := ["Idle", "Investigate", "Feed", "Sleep"]

static func _clear_unverified_tags(node: Node) -> void:
	if node.has_meta("authored_creature_ambient"):
		node.remove_meta("authored_creature_ambient")
	for child: Node in node.get_children():
		_clear_unverified_tags(child)

static func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result := _player(child)
		if result != null:
			return result
	return null

static func apply_to(visual: Node3D, source: String) -> Dictionary:
	_clear_unverified_tags(visual)
	if not source.begins_with("res://assets_external/design_pack_v1/creatures/M"):
		return {}
	var asset := source.get_file().substr(0, 3)
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures").path_join(asset)
	var receipt_path := folder.path_join("source_contract.json")
	if not FileAccess.file_exists(receipt_path):
		return {}
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not receipt is Dictionary:
		return {"error": "Malformed creature ambient receipt: " + asset}
	var source_hash := FileAccess.get_sha256(source)
	# A source candidate may be reviewed beside unchanged production. It must
	# not activate the new runtime owner until the exact verified bytes ship.
	if str(receipt.get("candidate_sha256", "")) != source_hash:
		return {}
	if str(receipt.get("status", "")) != "source_contract_pass" or not bool(receipt.get("protected_action_bytes_equal", false)) or str(receipt.get("asset", "")) != asset:
		return {"error": "Unverified creature action contract: " + asset}
	var player := _player(visual)
	if player == null:
		return {"error": "Verified creature lost its AnimationPlayer: " + asset}
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return {"error": "Creature animation root cannot resolve: " + asset}
	var required_morphs: Array = receipt.get("required_morphs", [])
	var binding_report: Dictionary = {}
	for clip: String in CLIPS:
		var animation: Animation = null
		for name: StringName in player.get_animation_list():
			if str(name).get_file() == clip:
				animation = player.get_animation(name)
				break
		if animation == null or absf(animation.length - float(receipt.durations[clip])) > 0.00001:
			return {"error": "Creature ambient clip identity/duration changed: " + asset + "/" + clip}
		var actual_morphs: Dictionary = {}
		var bound_bones := 0
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			var target := animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if target == null:
				return {"error": "Unresolved creature ambient target: %s/%s/%s" % [asset, clip, path]}
			var kind := animation.track_get_type(track)
			if kind == Animation.TYPE_BLEND_SHAPE:
				var shape := str(path.get_subname(0)) if path.get_subname_count() == 1 else ""
				if not target is MeshInstance3D or (target as MeshInstance3D).mesh == null or (target as MeshInstance3D).find_blend_shape_by_name(shape) < 0:
					return {"error": "Creature morph does not bind to its actual prepared mesh: %s/%s/%s" % [asset, clip, path]}
				var minimum := INF
				var maximum := -INF
				for key in animation.track_get_key_count(track):
					var value := float(animation.track_get_key_value(track, key))
					if not is_finite(value):
						return {"error": "Nonfinite creature morph: " + asset + "/" + shape}
					minimum = minf(minimum, value)
					maximum = maxf(maximum, value)
				if maximum - minimum > 0.0001:
					actual_morphs[shape] = str(path)
			elif kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D] and path.get_subname_count() == 1:
				if not target is Skeleton3D or (target as Skeleton3D).find_bone(str(path.get_subname(0))) < 0:
					return {"error": "Creature ambient bone is not bound: %s/%s/%s" % [asset, clip, path]}
				bound_bones += 1
		if bound_bones == 0:
			return {"error": "Creature ambient clip has no native bone tracks: " + asset + "/" + clip}
		for shape: String in required_morphs:
			if not actual_morphs.has(shape):
				return {"error": "Creature ambient morph is absent or flat: " + asset + "/" + clip + "/" + shape}
		binding_report[clip] = {"bound_bone_tracks": bound_bones, "morph_tracks": actual_morphs}
	visual.set_meta("authored_creature_ambient", true)
	visual.set_meta("authored_creature_ambient_source_sha256", source_hash)
	visual.set_meta("authored_creature_ambient_clips", CLIPS)
	return {"verified": true, "source_sha256": source_hash, "receipt_sha256": FileAccess.get_sha256(receipt_path),
		"native_binding_report": binding_report, "visual_accepted": false}
