extends SceneTree
## Canonical export of the retained FBX rig for deterministic mesh authoring.
## No game, saves, gameplay simulation or source modifications.
const SOURCE := "res://assets_external/enemies/Skeleton.fbx"
const OUTPUT := "res://.release-gate/spectral-monsters/Gravebound_Source.glb"

func _initialize() -> void:
	call_deferred("_export")

func _export() -> void:
	var source_hash := FileAccess.get_sha256(SOURCE)
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		push_error("Retained Skeleton FBX could not be loaded")
		quit(1)
		return
	var actor := packed.instantiate() as Node3D
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(actor)
	for raw in actor.find_children("*", "AnimationPlayer", true, false):
		(raw as AnimationPlayer).stop()
	for raw in actor.find_children("*", "Skeleton3D", true, false):
		(raw as Skeleton3D).reset_bone_poses()
		(raw as Skeleton3D).force_update_all_bone_transforms()
	# FBX retains five unweighted helper bones. Include their bind entries so
	# glTF round-tripping keeps the complete original skeleton and clip paths.
	for raw in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw as MeshInstance3D
		if mesh.skin == null: continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null: continue
		mesh.skin = mesh.skin.duplicate() as Skin
		var present: Dictionary = {}
		for index in mesh.skin.get_bind_count():
			var name := mesh.skin.get_bind_name(index)
			present[str(name) if name != &"" else str(skeleton.get_bone_name(mesh.skin.get_bind_bone(index)))] = true
		for bone in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(bone)
			if not present.has(str(name)):
				mesh.skin.add_named_bind(name, skeleton.get_bone_global_rest(bone).affine_inverse())
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(actor, state)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if result == OK:
		result = document.write_to_filesystem(state, ProjectSettings.globalize_path(OUTPUT))
	actor.free()
	if result != OK or FileAccess.get_sha256(SOURCE) != source_hash:
		push_error("Canonical FBX export failed or changed its source: " + error_string(result))
		quit(1)
		return
	print("SPECTRAL FBX SOURCE: PASS source_sha256=" + source_hash + " output_sha256=" + FileAccess.get_sha256(OUTPUT))
	quit(0)
