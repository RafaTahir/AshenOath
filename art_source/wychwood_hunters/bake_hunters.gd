extends SceneTree
## After the Blender pass, run Godot --headless --path PROJECT --script THIS -- GLB_FOLDER.
## Garments use skin bind *names*. Animations retain the exact imported track paths.

const OUTFOLDER := "res://assets/characters/wychwood_hunters/"
const BODIES := ["167225684a08f30a29e2ea17", "9b917237c5f1da73cb1ee634"]
const IMPORTS := ["M01_BurialShroud", "M02_SplinterMantle"]
const GARMENTS := ["m01_shroud.res", "m02_vanes.res"]
const MOTIONS := ["m01_motion.res", "m02_motion.res"]
const M01 := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTFOLDER))
	for id in BODIES.size():
		var scene := load("res://assets_external/characters_prepared/monsters/" + BODIES[id] + ".scn") as PackedScene
		var body := scene.instantiate()
		var mesh := body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var ok := bake_garment(id, args[0], mesh) and bake_motion(id, mesh, player)
		body.free()
		if not ok:
			quit(1)
			return
	quit()

func bake_garment(id: int, folder: String, actor_mesh: MeshInstance3D) -> bool:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	if gltf.append_from_file(folder.path_join(IMPORTS[id] + ".glb"), state) != OK: return false
	var imported := gltf.generate_scene(state)
	var garment := imported.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var surfaces: ArrayMesh = garment.mesh
	assert(surfaces.get_surface_count() == 1)
	var arrays := surfaces.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var imported_rig := garment.get_node(garment.skeleton) as Skeleton3D
	var binds := {}
	for i in actor_mesh.skin.get_bind_count():
		binds[actor_mesh.skin.get_bind_name(i)] = i
	for i in bones.size():
		if weights[i] <= 0:
			bones[i] = 0
			continue
		var bone_name := garment.skin.get_bind_name(bones[i])
		if bone_name == &"": bone_name = imported_rig.get_bone_name(garment.skin.get_bind_bone(bones[i]))
		if not binds.has(bone_name):
			push_error("Unknown named garment binding " + str(bone_name))
			imported.free()
			return false
		bones[i] = binds[bone_name]
	arrays[Mesh.ARRAY_BONES] = bones
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var pigment: StandardMaterial3D = surfaces.surface_get_material(0)
	pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not pigment.vertex_color_use_as_albedo:
		push_error("Missing the garment's authored per-corner paint")
		return false
	mesh.surface_set_material(0, pigment)
	mesh.resource_name = IMPORTS[id]
	mesh.surface_set_name(0, IMPORTS[id])
	print("GARMENT ", id, " vertices=", positions.size(), " bounds=", mesh.get_aabb(), " material=", pigment.resource_name)
	var result := ResourceSaver.save(mesh, OUTFOLDER + GARMENTS[id], ResourceSaver.FLAG_COMPRESS) == OK
	imported.free()
	return result

# Rotation curves are sculpted in the source mesh's facing (+Z), then converted to each
# joint's local bind axes. Native contact ancestry is deliberately untouched in Attack.
func pose(id: int, clip: String, bone: String, t: float) -> Vector3:
	var wave := sin(TAU * t)
	var lift := 0.5 - 0.5 * cos(TAU * t)
	if id == M01:
		if clip == "Attack":
			var brace := lobe(t, 0.0, 0.16, 0.30)
			var wrench := lobe(t, 0.15, 0.37, 0.56)
			var recoil := lobe(t, 0.44, 0.68, 1.0)
			match bone:
				"neck_01": return Vector3(-18 * brace + 26 * wrench - 11 * recoil, -12 * brace + 13 * recoil, 0)
				"Head": return Vector3(11 * wrench, -15 * brace + 19 * wrench, 11 * recoil)
				"upperarm_l": return Vector3(-14 * brace + 23 * wrench, -21 * brace + 17 * recoil, 15 * brace - 26 * wrench)
				"lowerarm_l": return Vector3(12 * wrench - 19 * recoil, 0, -21 * brace + 12 * wrench)
				_: return Vector3.ZERO
		if clip == "Idle":
			# Draw one long breath, raise the listening ear, then collapse inward.
			match bone:
				"spine_02": return Vector3(10 + 4 * lift, -6 + 8 * lift, 7)
				"neck_01": return Vector3(4 - 12 * lift, -8 + 26 * lift, 6 + 9 * wave)
				"Head": return Vector3(6 - 9 * lift, -4 + 17 * lift, 4 + 5 * wave)
				"upperarm_l": return Vector3(-7, 13, -6 - 12 * lift)
				"lowerarm_l": return Vector3(3, -15 - 9 * lift, -8)
				"upperarm_r": return Vector3(10, -4, 5 + 7 * lift)
				_: return Vector3.ZERO
		var run := clip == "Running"
		match bone:
			"spine_02": return Vector3((13.0 if run else 7.0) + 4 * lift, -6 + 8 * wave, 5 + 4 * wave)
			"neck_01": return Vector3(-4 - 4 * lift, (8 if run else 15) * wave, 5)
			"Head": return Vector3(6 * lift, 8 * wave, -3 * wave)
			"upperarm_l": return Vector3(-13 + 9 * wave, 16, -11 - 6 * wave)
			"upperarm_r": return Vector3(9 - 13 * wave, -8, 5)
			_: return Vector3.ZERO
	if clip == "Attack":
		var load_up := lobe(t, 0.0, 0.46, 0.79)
		var snap := lobe(t, 0.64, 0.86, 0.97)
		match bone:
			"Neck": return Vector3(-12 * load_up + 15 * snap, 17 * load_up, -12 * load_up)
			"Head": return Vector3(-7 * load_up + 15 * snap, 18 * load_up, 11 * snap)
			"Jaw1": return Vector3(19 * load_up - 4 * snap, 0, 0)
			"Arm1.L": return Vector3(-19 * load_up + 20 * snap, -13 * load_up + 24 * snap, 14 * load_up)
			"Arm2.L": return Vector3(13 * load_up - 17 * snap, 0, -12 * load_up)
			_: return Vector3.ZERO
	if clip == "Idle":
		match bone:
			"Chest": return Vector3(5 + 4 * lift, 11 + 6 * wave, -8)
			"Neck": return Vector3(-11 + 7 * lift, -11 + 19 * wave, 5 * lift)
			"Head": return Vector3(-4, -3 + 12 * wave, 5 * wave)
			"Jaw1": return Vector3(7 + 5 * lift, 0, 0)
			"Arm1.L": return Vector3(-8, -17, 8)
			_: return Vector3.ZERO
	var gait := sin(TAU * 4.0 * t)
	match bone:
		"Chest": return Vector3(10 + 3 * gait, -13 + 6 * gait, -7 + 4 * gait)
		"Neck": return Vector3(-12 - 4 * gait, 15 + 5 * gait, 5)
		"Head": return Vector3(-6, 5 * gait, 4)
		"Arm1.L": return Vector3(-13 + 8 * gait, -9, 11 + 4 * gait)
		"Arm1.R": return Vector3(10 - 7 * gait, 8, 6)
		_: return Vector3.ZERO

func lobe(t: float, begin: float, peak: float, end: float) -> float:
	if t <= begin or t >= end: return 0.0
	if t < peak: return smoothstep(begin, peak, t)
	return 1.0 - smoothstep(peak, end, t)

func bake_motion(id: int, actor_mesh: MeshInstance3D, player: AnimationPlayer) -> bool:
	var library := AnimationLibrary.new()
	var rig := actor_mesh.get_node(actor_mesh.skeleton) as Skeleton3D
	var bind_basis := {}
	for i in actor_mesh.skin.get_bind_count():
		bind_basis[str(actor_mesh.skin.get_bind_name(i))] = actor_mesh.skin.get_bind_pose(i).basis.inverse().orthonormalized()
	for key: String in ["Idle", "Walking", "Running", "Attack"]:
		var original := player.get_animation(key)
		var clip := original.duplicate(false) as Animation
		var count := 0
		for track in range(original.get_track_count() - 1, -1, -1):
			if original.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
			var path := original.track_get_path(track)
			var bone := str(path.get_subname(0))
			var wanted := pose(id, key, bone, 0.17).length_squared() + pose(id, key, bone, 0.84).length_squared()
			if wanted < 0.01: continue
			if not bind_basis.has(bone) or rig.find_bone(bone) < 0: return false
			clip.remove_track(track)
			var new_track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(new_track, path)
			var base := (bind_basis[bone] as Basis).get_rotation_quaternion()
			var samples := ceili(original.length * 30.0)
			for k in range(samples + 1):
				var t := float(k) / samples
				var seconds := t * original.length
				var native := original.rotation_track_interpolate(track, seconds)
				var offsets := pose(id, key, bone, t) * (PI / 180.0)
				var delta := Quaternion.from_euler(offsets)
				clip.rotation_track_insert_key(new_track, seconds, (native * base.inverse() * delta * base).normalized())
			count += 1
		if count < 3:
			push_error("Unbound authored pose " + key)
			return false
		clip.resource_name = key
		library.add_animation(key, clip)
		print("AUTHORED ", id, " ", key, " tracks=", count, " duration=", clip.length)
	return ResourceSaver.save(library, OUTFOLDER + MOTIONS[id], ResourceSaver.FLAG_COMPRESS) == OK
