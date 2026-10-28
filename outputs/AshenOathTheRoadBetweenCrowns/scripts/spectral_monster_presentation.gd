extends RefCounted
## Asset-only binding. No gameplay ticks, light nodes or physics queries.
const PROFILES := "res://data/spectral_monster_profiles.json"
const VEIL := preload("res://shaders/spectral_veil.gdshader")
const Bindings := preload("res://scripts/character_material_bindings.gd")
static var profiles: Dictionary = {}
static var materials: Dictionary = {}

static func prepare(root: Node3D, source: String) -> void:
	if not source.contains("/spectral/"): return
	if profiles.is_empty() and FileAccess.file_exists(PROFILES):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
		if parsed is Dictionary: profiles = parsed.get("assets", {})
	var profile: Dictionary = profiles.get(source, {})
	if profile.is_empty():
		push_error("Spectral asset has no canonical rig profile: " + source)
		return
	if str(profile.enemy_id) == "gravebound_knight": _restore_native_knight(root)
	var bounds: Dictionary = profile.normalization_bounds
	var p: Array = bounds.position
	var s: Array = bounds.size
	root.set_meta("prepared_source_bounds", AABB(Vector3(p[0],p[1],p[2]),Vector3(s[0],s[1],s[2])))
	if profile.has("legacy_normalization_scale"):
		root.set_meta("spectral_legacy_normalization_scale", float(profile.legacy_normalization_scale))
	_bind(root, profile)
	# Boss setup can apply a whole-body material after instantiation. Rebind the
	# explicitly authored veil once after setup; no recurring process is added.
	if root.is_inside_tree():
		_queue_binding(weakref(root), source)
	else:
		root.ready.connect(_queue_binding.bind(weakref(root), source), CONNECT_ONE_SHOT)

static func _restore_native_knight(root: Node3D) -> void:
	if root.has_meta("spectral_native_rig_restored"): return
	var packed := load("res://assets_external/enemies/Skeleton.fbx") as PackedScene
	var native := packed.instantiate() as Node3D
	var original := native.find_child("Skeleton3D", true, false) as Skeleton3D
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var native_player := native.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if original == null or skeleton == null or player == null or native_player == null:
		push_error("Native spectral knight binding is incomplete")
		native.free()
		return
	var native_mesh: MeshInstance3D
	for raw in native.find_children("*", "MeshInstance3D", true, false):
		if raw.skin != null:
			native_mesh = raw
			break
	var slots: Dictionary = {}
	for bind in native_mesh.skin.get_bind_count():
		var name := str(native_mesh.skin.get_bind_name(bind))
		if name.is_empty(): name = str(original.get_bone_name(native_mesh.skin.get_bind_bone(bind)))
		slots[name.replace(".","_")] = bind
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null: continue
		var converted := mesh.skin
		var rebuilt := ArrayMesh.new()
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for i in bones.size():
				var key := str(converted.get_bind_name(bones[i])).replace(".","_")
				if key.is_empty(): key = str(skeleton.get_bone_name(converted.get_bind_bone(bones[i]))).replace(".","_")
				if weights[i] > 0.0 and not slots.has(key): push_error("Unexpected weighted knight helper bone: " + key)
				bones[i] = int(slots.get(key,0))
			arrays[Mesh.ARRAY_BONES] = bones
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			rebuilt.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
		mesh.mesh = rebuilt
		mesh.skin = native_mesh.skin
	for bone in original.get_bone_count():
		skeleton.set_bone_name(bone, original.get_bone_name(bone))
		skeleton.set_bone_rest(bone, original.get_bone_rest(bone))
	skeleton.reset_bone_poses()
	for key in player.get_animation_library_list(): player.remove_animation_library(key)
	for key in native_player.get_animation_library_list():
		var library := native_player.get_animation_library(key).duplicate(true) as AnimationLibrary
		var animation_root := player.get_node(player.root_node)
		var path := str(animation_root.get_path_to(skeleton))
		for clip in library.get_animation_list():
			var animation := library.get_animation(clip)
			for track in animation.get_track_count():
				var old := str(animation.track_get_path(track))
				if old.contains(":"): animation.track_set_path(track, NodePath(path + ":" + old.get_slice(":",1)))
		player.add_animation_library(key, library)
	root.set_meta("spectral_native_rig_restored", true)
	native.free()

static func _queue_binding(reference: WeakRef, source: String) -> void:
	var root := reference.get_ref() as Node3D
	if is_instance_valid(root) and root.is_inside_tree():
		root.get_tree().process_frame.connect(_after_setup.bind(reference, source), CONNECT_ONE_SHOT)

static func _after_setup(reference: WeakRef, source: String) -> void:
	var root := reference.get_ref() as Node3D
	if not is_instance_valid(root) or root.is_queued_for_deletion(): return
	_bind(root, profiles[source])
	Bindings.capture(root, source)

static func _bind(root: Node3D, profile: Dictionary) -> void:
	for raw in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw as MeshInstance3D
		if not str(mesh.name).contains("SpectralVeil") or mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null or original.albedo_texture == null: continue
			var key := str(profile.palette) + "|" + original.albedo_texture.resource_path + "|" + str(profile.raw_height)
			if not materials.has(key):
				var material := ShaderMaterial.new()
				material.shader = VEIL
				material.set_shader_parameter("authored_atlas", original.albedo_texture)
				var c: Array = profile.palette
				material.set_shader_parameter("spectral_color", Color(c[0],c[1],c[2]))
				material.set_shader_parameter("local_amplitude", minf(float(profile.raw_height) * 0.002, 0.01))
				materials[key] = material
			mesh.material_override = null
			mesh.set_surface_override_material(surface, materials[key])

