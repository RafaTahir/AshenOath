extends SceneTree

## Bracken keeps the exact imported M13 root. This is not an enemy-role bake.
const SOURCE := "res://assets_external/design_pack_v1/creatures/M13_Hearthscale.glb"
const OUTPUT := "res://assets_external/characters_prepared/companions/bracken.scn"
const RETAINED_SOURCE_SHA256 := "61a92cf7c6db469689cff793548b27c6277b0ef989319b6cf8dcfbd690c42da4"
const AmbientContract = preload("res://tools/creature_ambient_source_contract.gd")
var _error := ""
var _owned: Array[Node] = []

func _initialize() -> void:
	call_deferred("_build")

func _digest(value: Variant) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()

func _find_skeleton(visual: Node) -> Skeleton3D:
	var found := visual.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

func _own(node: Node, scene: Node) -> void:
	node.scene_file_path = ""
	if node != scene:
		node.owner = scene
	for child: Node in node.get_children():
		_own(child, scene)

func _record_nodes(node: Node, visual: Node, rows: Array) -> void:
	var row := {"path":str(visual.get_path_to(node)), "class":node.get_class()}
	if node is Node3D:
		row.transform = (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var surfaces: Array = []
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface) as StandardMaterial3D
			var material_info: Dictionary = {}
			if material != null:
				material_info = {"name":material.resource_name,"albedo":material.albedo_color,"metallic":material.metallic,"roughness":material.roughness,"transparency":material.transparency,"cull":material.cull_mode}
				for channel in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:
					var texture := material.get_texture(channel)
					if texture != null:
						var image := texture.get_image()
						material_info[str(channel)] = _digest([image.get_width(),image.get_height(),image.get_format(),image.get_data()])
			surfaces.append({"arrays":_digest(instance.mesh.surface_get_arrays(surface)),"material":material_info})
		row.surfaces = surfaces
		row.skin = []
		if instance.skin != null:
			for bind in instance.skin.get_bind_count():
				row.skin.append([instance.skin.get_bind_name(bind),instance.skin.get_bind_bone(bind),instance.skin.get_bind_pose(bind)])
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		row.bones = []
		for bone in skeleton.get_bone_count():
			row.bones.append([skeleton.get_bone_name(bone),skeleton.get_bone_parent(bone),skeleton.get_bone_rest(bone),skeleton.get_bone_pose(bone)])
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		row.animation_root = player.root_node
		row.animations = {}
		for clip: StringName in player.get_animation_list():
			var animation := player.get_animation(clip)
			var tracks: Array = []
			for track in animation.get_track_count():
				var keys: Array = []
				for key in animation.track_get_key_count(track):
					keys.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key),animation.track_get_key_transition(track,key)])
				tracks.append([animation.track_get_type(track),animation.track_get_path(track),animation.track_get_interpolation_type(track),animation.track_get_interpolation_loop_wrap(track),animation.track_is_enabled(track),keys])
			row.animations[str(clip)] = _digest([animation.length,animation.loop_mode,tracks])
	rows.append(row)
	for child: Node in node.get_children():
		_record_nodes(child,visual,rows)

func _signature(visual: Node) -> String:
	var rows: Array = []
	_record_nodes(visual,visual,rows)
	return _digest(rows)

func _closure(path: String) -> Array[String]:
	var pending: Array[String] = [path]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		if current.get_extension().to_lower() in ["glb","gltf","fbx","dae"] or (current.begins_with("res://.godot/imported/") and current.ends_with(".scn")):
			_error = "Prepared companion retains a raw imported scene dependency: " + current
			return []
		for encoded: String in ResourceLoader.get_dependencies(current):
			var dependency := ""
			for component: String in encoded.split("::"):
				if component.begins_with("res://"):
					dependency = component
					break
			if dependency.is_empty() and encoded.begins_with("uid://"):
				var uid := ResourceUID.text_to_id(encoded.get_slice("::",0))
				if ResourceUID.has_id(uid):dependency = ResourceUID.get_id_path(uid)
			if dependency.is_empty():
				_error = "Unresolved prepared companion dependency: " + encoded
				return []
			pending.append(dependency)
	var result: Array[String] = []
	result.assign(seen.keys())
	result.erase(path)
	result.sort()
	return result

func _build() -> void:
	var source_hash := FileAccess.get_sha256(SOURCE)
	var proof_stage := "retained_baseline" if source_hash == RETAINED_SOURCE_SHA256 else "authored_ambient_revision"
	var imported := load(SOURCE) as PackedScene
	if imported == null:
		_fail("Bracken requires the current imported M13 source")
		return
	var visual := imported.instantiate() as Node3D
	if visual == null:
		_fail("Bracken's imported root is not a Node3D")
		return
	_owned.append(visual)
	root.add_child(visual)
	var player := visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var skeleton := _find_skeleton(visual)
	if player == null or skeleton == null:
		_fail("Bracken's raw M13 skeleton/AnimationPlayer is absent")
		return
	var clips: Dictionary = {}
	for clip: StringName in player.get_animation_list():
		if str(clip).get_file() == "Idle":clips.idle = str(clip)
		if str(clip).get_file() == "Walking":clips.walk = str(clip)
	var care: Dictionary = {"neck":""}
	for bone in skeleton.get_bone_count():
		var name := str(skeleton.get_bone_name(bone))
		match name.replace("_", "."):
			"Head":care.head = name
			"Neck":care.neck = name
			"Tail0", "Tail.0":care.tail = name
	if clips.size() != 2 or not care.has("head") or not care.has("tail"):
		_fail("Bracken's exact native Idle/Walking/care bindings are incomplete")
		return
	var before := _signature(visual)
	var contract := {"schema_version":1,"source_path":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"raw_root_transform":visual.transform,
		"animation_player_path":str(visual.get_path_to(player)),"skeleton_path":str(visual.get_path_to(skeleton)),"clips":clips,"care_bones":care}
	visual.set_meta("companion_contract",contract)
	var ambient: Dictionary = AmbientContract.apply_to(visual,SOURCE)
	if ambient.has("error"):
		_fail(str(ambient.error))
		return
	if proof_stage == "authored_ambient_revision":
		var source_receipt_path := ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2/models/living_assets_stage3_20261107/creatures/M13/source_contract.json").simplify_path()
		var source_receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_receipt_path))
		if not bool(ambient.get("verified", false)) or not source_receipt is Dictionary or str(source_receipt.get("retained_source_sha256", "")) != RETAINED_SOURCE_SHA256:
			_fail("A revised companion requires the protected-action proof against the retained M13 baseline")
			return
	_own(visual,visual)
	var packed := PackedScene.new()
	if packed.pack(visual) != OK:
		_fail("Cannot pack the exact raw-root companion derivative")
		return
	packed.set_meta("companion_contract",contract)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if ResourceSaver.save(packed,OUTPUT,ResourceSaver.FLAG_COMPRESS) != OK:
		_fail("Cannot save the prepared companion derivative")
		return
	var fresh := ResourceLoader.load(OUTPUT,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if fresh == null:
		_fail("Cannot reload the saved companion derivative")
		return
	var proof := fresh.instantiate() as Node3D
	if proof == null:
		_fail("Saved companion root is not a Node3D")
		return
	_owned.append(proof)
	root.add_child(proof)
	var after := _signature(proof)
	if before != after or proof.get_meta("companion_contract",{}) != contract:
		_fail("Prepared companion changed raw transforms, skin, materials, rig or animation tracks")
		return
	var dependencies := _closure(OUTPUT)
	if not _error.is_empty():
		_fail(_error)
		return
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/companion")
	DirAccess.make_dir_recursive_absolute(folder)
	var output_hash := FileAccess.get_sha256(OUTPUT)
	var archive := folder.path_join("proofs").path_join(source_hash).path_join(output_hash)
	var archived_output := archive.path_join("bracken.scn")
	var archived_receipt := archive.path_join("compiler_receipt.json")
	var receipt := {"schema_version":2,"proof_stage":proof_stage,"source":SOURCE,"source_sha256":source_hash,"retained_source_sha256":RETAINED_SOURCE_SHA256,
		"output":OUTPUT,"output_sha256":output_hash,"compiler_sha256":FileAccess.get_sha256(get_script().resource_path),
		"proof_archive":archive.trim_prefix(repository + "/"),"ambient_source_receipt_sha256":str(ambient.get("receipt_sha256", "")),
		"raw_root_roundtrip_signature":before,"exact_roundtrip_verified":true,"resource_dependencies":dependencies,"clips":clips,"care_bones":care,
		"runtime_scale":0.62,"runtime_yaw":PI,"role_normalization_applied":false,"native_pose_equivalence_verified":false,"visual_accepted":false,"user_accepted":false}
	if DirAccess.make_dir_recursive_absolute(archive) != OK:
		_fail("Cannot create the immutable companion proof archive")
		return
	if FileAccess.file_exists(archived_output):
		if FileAccess.get_sha256(archived_output) != output_hash:
			_fail("Archived companion bytes changed; refusing to replace the original proof")
			return
	elif DirAccess.copy_absolute(ProjectSettings.globalize_path(OUTPUT), archived_output) != OK:
		_fail("Cannot preserve the exact companion derivative bytes")
		return
	if FileAccess.file_exists(archived_receipt):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(archived_receipt))
		if previous != receipt:
			_fail("Archived companion proof differs; preserve it and review the compiler change")
			return
	else:
		var archive_file := FileAccess.open(archived_receipt, FileAccess.WRITE)
		if archive_file == null:
			_fail("Cannot preserve the companion compiler receipt")
			return
		archive_file.store_string(JSON.stringify(receipt,"\t")+"\n")
		archive_file.close()
	var file := FileAccess.open(folder.path_join("prepared_companion.json"),FileAccess.WRITE)
	if file == null:
		_fail("Cannot write the current companion receipt")
		return
	file.store_string(JSON.stringify(receipt,"\t")+"\n")
	file.close()
	_dispose()
	print("PREPARED_COMPANION_RAW_ROOT_PASS ",OUTPUT)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	_dispose()
	quit(1)

func _dispose() -> void:
	for node: Node in _owned:
		if is_instance_valid(node):
			node.free()
	_owned.clear()
