extends RefCounted

## Builder-only proof: never trust a GLTF extra as ambient-animation authority.
const CLIPS := ["Idle", "Investigate", "Feed", "Sleep"]

static func _clear_unverified_tags(node: Node) -> void:
	for tag: String in ["authored_creature_ambient", "authored_creature_ambient_source_sha256", "authored_creature_ambient_clips", "authored_creature_ambient_morphs", "authored_creature_water_probes"]:
		if node.has_meta(tag):
			node.remove_meta(tag)
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

static func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, result)

static func _water_probes(visual: Node3D, required: Array) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_meshes(visual, meshes)
	var probes: Array[Dictionary] = []
	var evidence: Array[Dictionary] = []
	for bone_name: String in required:
		var best_distance := -1.0
		var best_offset := Vector3.ZERO
		var proof: Dictionary = {}
		for mesh: MeshInstance3D in meshes:
			var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
			if skeleton == null or mesh.skin == null or mesh.mesh == null:
				continue
			var bone := skeleton.find_bone(bone_name)
			if bone < 0:
				continue
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if vertices.is_empty() or bones.is_empty() or weights.size() != bones.size() or bones.size() % vertices.size() != 0:
					continue
				var influences := int(bones.size() / vertices.size())
				for index in vertices.size():
					for influence in influences:
						var offset := index * influences + influence
						if weights[offset] < 0.9999:
							continue
						var binding := bones[offset]
						if binding < 0 or binding >= mesh.skin.get_bind_count():
							return {"error": "Retained water probe skin binding is invalid"}
						var bind_name := str(mesh.skin.get_bind_name(binding))
						var bound_bone := skeleton.find_bone(bind_name) if not bind_name.is_empty() else mesh.skin.get_bind_bone(binding)
						if bound_bone != bone:
							continue
						# Skin bind poses map this actual retained mesh vertex into
						# its owning bone's rest frame, independent of importer axes.
						var local := mesh.skin.get_bind_pose(binding) * vertices[index]
						if not local.is_finite():
							return {"error": "Retained water probe is nonfinite"}
						if local.length_squared() > best_distance:
							best_distance = local.length_squared()
							best_offset = local
							proof = {"mesh_path": str(visual.get_path_to(mesh)), "surface": surface, "vertex": index,
								"skin_bind": binding, "weight": weights[offset], "bone_name": bone_name}
		if proof.is_empty():
			return {"error": "Missing actual retained fin-tip geometry: " + bone_name}
		probes.append({"bone_name": bone_name, "offset": [best_offset.x, best_offset.y, best_offset.z]})
		evidence.append(proof)
	return {"probes": probes, "evidence": evidence}

static func apply_to(visual: Node3D, source: String) -> Dictionary:
	return _apply_to(visual, source, source)

static func apply_candidate(visual: Node3D, asset: String, candidate_folder: String = "") -> Dictionary:
	# Source-review fixtures import the already verified carrier directly. This
	# never rewrites production sources or bypasses the same native track gates.
	if asset.length() != 3 or not asset.begins_with("M") or not asset.substr(1).is_valid_int() or int(asset.substr(1)) < 1 or int(asset.substr(1)) > 20:
		return {"error":"Unknown creature candidate identity"}
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures").path_join(asset)
	if not candidate_folder.is_empty(): folder = candidate_folder
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("authoring.json")))
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/design_pack_assets.json"))
	if not authored is Dictionary or not registry is Dictionary or not registry.get("assets", {}).has(asset):
		return {"error":"Missing candidate authoring identity"}
	var source := str(registry.assets[asset].path)
	if str(authored.get("production_resource", "")) != source or FileAccess.get_sha256(folder.path_join(asset + "_retained_input.glb")) != str(authored.get("production_sha256", "")):
		return {"error":"Candidate retained source identity changed"}
	var result := _apply_to(visual, source, folder.path_join(asset + "_living_candidate.glb"), candidate_folder)
	if result.is_empty():
		return {"error":"Candidate has no matching verified source contract"}
	result["candidate_only"] = true
	return result

static func _apply_to(visual: Node3D, source: String, bytes_path: String, candidate_folder: String = "") -> Dictionary:
	_clear_unverified_tags(visual)
	if not source.begins_with("res://assets_external/design_pack_v1/creatures/M"):
		return {}
	var asset := source.get_file().substr(0, 3)
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures").path_join(asset)
	if not candidate_folder.is_empty(): folder = candidate_folder
	var receipt_path := folder.path_join("source_contract.json")
	if not FileAccess.file_exists(receipt_path):
		return {}
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not receipt is Dictionary:
		return {"error": "Malformed creature ambient receipt: " + asset}
	var source_hash := FileAccess.get_sha256(bytes_path)
	# A source candidate may be reviewed beside unchanged production. It must
	# not activate the new runtime owner until the exact verified bytes ship.
	if str(receipt.get("candidate_sha256", "")) != source_hash:
		return {}
	if str(receipt.get("status", "")) != "source_contract_pass" or not bool(receipt.get("protected_action_bytes_equal", false)) or not bool(receipt.get("retained_export_base_bytes_equal", false)) or not bool(receipt.get("retained_materials_skin_hierarchy_equal", false)) or str(receipt.get("asset", "")) != asset:
		return {"error": "Unverified creature action contract: " + asset}
	var player := _player(visual)
	if player == null:
		return {"error": "Verified creature lost its AnimationPlayer: " + asset}
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return {"error": "Creature animation root cannot resolve: " + asset}
	var required_morphs: Array = receipt.get("required_morphs", [])
	var binding_report: Dictionary = {}
	var morph_bindings: Dictionary = {}
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
				if shape in required_morphs:
					var mesh := target as MeshInstance3D
					var neutral := mesh.get_blend_shape_value(mesh.find_blend_shape_by_name(shape))
					if not is_finite(neutral):
						return {"error": "Nonfinite retained neutral morph weight: " + asset + "/" + shape}
					var mesh_path := str(visual.get_path_to(mesh))
					morph_bindings[mesh_path + ":" + shape] = {"node_path": mesh_path, "shape_name": shape, "neutral_weight": neutral}
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
	visual.set_meta("authored_creature_ambient_morphs", morph_bindings.values())
	var water_bones: Array = receipt.get("water_probe_bones", [])
	if asset == "M18" and (not water_bones.has("Fin1_2") or not water_bones.has("Fin-1_2")):
		return {"error": "Shroud Swimmer source lacks both measured fin-tip bindings"}
	var water := _water_probes(visual, water_bones)
	if water.has("error"):
		return water
	visual.set_meta("authored_creature_water_probes", water.probes)
	return {"verified": true, "source_sha256": source_hash, "receipt_sha256": FileAccess.get_sha256(receipt_path),
		"native_binding_report": binding_report, "morph_bindings": morph_bindings.values(),
		"water_probes": water.probes, "water_probe_evidence": water.evidence, "visual_accepted": false}
