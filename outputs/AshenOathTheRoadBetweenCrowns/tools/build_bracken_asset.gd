extends SceneTree

## Asset packaging only: no game scene, camera, playback review or test fixture.
const SOURCE := "res://assets_external/enemies/Dog.fbx"
const OUTPUT := "res://assets/companions/bracken.scn"

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var source := load(SOURCE) as PackedScene
	if source == null:
		push_error("Bracken requires the retained animated Dog source.")
		quit(1)
		return
	var visual := source.instantiate() as Node3D
	visual.scene_file_path = ""
	var assembly := Node3D.new()
	assembly.name = "BrackenVisual"
	root.add_child(assembly)
	assembly.add_child(visual)
	var animation_player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if animation_player == null or skeletons.is_empty():
		_fail(assembly, "Bracken source must retain its skeleton and animation player.")
		return
	var clips: Dictionary = {}
	for clip: StringName in animation_player.get_animation_list():
		var suffix: String = str(clip).get_slice("|", 1).to_lower()
		if suffix == "":
			suffix = str(clip).to_lower()
		if suffix in ["idle", "walking"]:
			var animation := animation_player.get_animation(clip).duplicate(true) as Animation
			animation.loop_mode = Animation.LOOP_LINEAR
			for track in range(animation.get_track_count()):
				if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or animation.track_get_key_count(track) == 0:
					continue
				var path: NodePath = animation.track_get_path(track)
				var is_root: bool = path.get_subname_count() == 0
				if not is_root:
					var skeleton := skeletons[0] as Skeleton3D
					var bone: int = skeleton.find_bone(str(path.get_subname(0)))
					is_root = bone >= 0 and skeleton.get_bone_parent(bone) < 0
				if is_root:
					var first_position: Vector3 = animation.track_get_key_value(track, 0)
					for key in range(animation.track_get_key_count(track)):
						var position: Vector3 = animation.track_get_key_value(track, key)
						animation.track_set_key_value(track, key, Vector3(first_position.x, position.y, first_position.z))
			var library_name: StringName = StringName(str(clip).get_slice("/", 0)) if "/" in str(clip) else StringName()
			var local_name := StringName(str(clip).get_slice("/", str(clip).get_slice_count("/") - 1))
			var library := animation_player.get_animation_library(library_name)
			library.remove_animation(local_name)
			library.add_animation(local_name, animation)
			clips["idle" if suffix == "idle" else "walk"] = str(clip)
	if not clips.has("idle") or not clips.has("walk"):
		_fail(assembly, "Bracken source needs its native Idle and Walking clips.")
		return
	animation_player.root_motion_track = NodePath()
	var materials: Array[Dictionary] = []
	var bounds := AABB()
	var first := true
	for mesh_node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var original := mesh_instance.get_active_material(surface) as StandardMaterial3D
			var material := original.duplicate(true) as StandardMaterial3D if original != null else StandardMaterial3D.new()
			var color := material.albedo_color
			var detail: bool = material.resource_name.to_lower().contains("eye") or material.resource_name.to_lower().contains("teeth") or material.resource_name.to_lower().contains("tongue")
			if material.resource_name.to_lower() == "dog":
				material.albedo_color = Color(0.14, 0.15, 0.16)
			elif not detail and not (color.r > 0.5 and color.g < 0.15 and color.b < 0.15):
				material.albedo_color = Color(0.14, 0.15, 0.16) if color.s > 0.10 or color.v < 0.75 else Color(0.42, 0.43, 0.44)
			material.metallic = 0.0
			material.roughness = 0.86
			mesh_instance.set_surface_override_material(surface, material)
			materials.append({"name": material.resource_name, "source_color": color.to_html(), "runtime_color": material.albedo_color.to_html()})
		var local_bounds: AABB = assembly.global_transform.affine_inverse() * mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	if first or bounds.size.y <= 0.001:
		_fail(assembly, "Bracken source has no complete renderable body.")
		return
	var factor: float = 0.78 / bounds.size.y
	visual.scale *= factor
	visual.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	assembly.set_meta("companion_id", "bracken")
	assembly.set_meta("animation_clips", clips)
	assembly.set_meta("target_height_m", 0.78)
	assembly.set_meta("source", SOURCE)
	assembly.set_meta("license", "CC0-1.0")
	assembly.set_meta("source_forward_positive_z", true)
	_set_owner(assembly, assembly)
	var packed := PackedScene.new()
	var result := packed.pack(assembly)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if result == OK:
		result = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if result != OK:
		_fail(assembly, "Bracken asset packaging failed: " + str(result))
		return
	var ledger := {"source": SOURCE, "source_sha256": FileAccess.get_sha256(SOURCE), "output": OUTPUT, "output_sha256": FileAccess.get_sha256(OUTPUT), "animations": clips, "materials": materials, "target_height_m": 0.78, "license": "CC0-1.0", "user_visual_acceptance": "pending"}
	var file := FileAccess.open("res://assets/companions/bracken_build.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(ledger, "\t") + "\n")
	file.close()
	assembly.free()
	print("Bracken runtime asset packaged: ", JSON.stringify(ledger))
	quit(0)

func _set_owner(node: Node, owner_root: Node) -> void:
	if node != owner_root:
		node.owner = owner_root
	for child: Node in node.get_children():
		_set_owner(child, owner_root)

func _fail(assembly: Node, reason: String) -> void:
	assembly.free()
	push_error(reason)
	quit(1)
