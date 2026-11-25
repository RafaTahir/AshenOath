extends SceneTree
## Run from the Godot project with the Blender export directory after --.
## Mesh coordinates are the retained model's bind space. The joint manifest and
## baked animation paths come from the prepared actor used in the shipping game.

const SLOTS := "res://assets/characters/"
const ROLES := ["wychwood_raider", "wychwood_brute"]
const CLIPS := ["Idle","Walking","Running","Attack"]

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
	for id: String in ROLES:
		var prepared_path := ""
		for key: String in catalog:
			if key.begins_with(id + "_creature|") and "_Wychwood_" in key:
				prepared_path = catalog[key].path
				break
		if prepared_path.is_empty():
			quit(1)
			return
		var native: Node3D = load(prepared_path).instantiate()
		root.add_child(native)
		var reference: MeshInstance3D = native.find_children("*","MeshInstance3D",true,false)[0]
		var rig := reference.get_node(reference.skeleton) as Skeleton3D
		var animator: AnimationPlayer = native.find_children("*","AnimationPlayer",true,false)[0]
		var ok := bake_wardrobe(id,args[0],reference.skin) and bake_motion(id,rig,animator)
		native.free()
		if not ok:
			push_error("Failed to bake " + id)
			quit(1)
			return
	quit()

func bake_wardrobe(id: String, folder: String, skin: Skin) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(folder.path_join(id + "_regalia.glb"),state) != OK: return false
	var design := doc.generate_scene(state)
	root.add_child(design)
	var slots := {}
	for bind in skin.get_bind_count():
		slots[str(skin.get_bind_name(bind))] = bind
	var materials := {}
	for item: MeshInstance3D in design.find_children("*","MeshInstance3D",true,false):
		var label := str(item.name).get_slice("__",0)
		if not slots.has(label):
			push_error("Missing native skin joint: " + label)
			return false
		for s in item.mesh.get_surface_count():
			var material := item.mesh.surface_get_material(s) as StandardMaterial3D
			if material == null or not material.vertex_color_use_as_albedo:
				push_error("Lost Blender pigment on " + str(item.name))
				return false
			var key := material.resource_name
			if not materials.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(material)
				materials[key] = builder
			var builder: SurfaceTool = materials[key]
			var surface := item.mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = surface[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = surface[Mesh.ARRAY_COLOR]
			if colors.is_empty() or (colors[0].r > .94 and colors[0].g > .94 and colors[0].b > .94):
				push_error("Lost exported Pigment channel on " + str(item.name))
				return false
			var uv: PackedVector2Array = surface[Mesh.ARRAY_TEX_UV] if surface[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var pose := item.global_transform
			var norm := pose.basis.inverse().transposed()
			for index in indices:
				builder.set_bones(PackedInt32Array([slots[label],0,0,0]))
				builder.set_weights(PackedFloat32Array([1,0,0,0]))
				builder.set_color(colors[index])
				builder.set_normal((norm * normals[index]).normalized())
				if not uv.is_empty(): builder.set_uv(uv[index])
				builder.add_vertex(pose * vertices[index])
	design.free()
	var result := ArrayMesh.new()
	for key: String in materials:
		var st: SurfaceTool = materials[key]
		st.index()
		st.commit(result)
		result.surface_set_name(result.get_surface_count()-1,key)
	if result.get_surface_count() != 2: return false
	result.resource_name = id + " fitted travel gear"
	print(id, " gear: ", result.get_faces().size()/3, " faces, ", result.get_surface_count()," draws")
	return ResourceSaver.save(result,SLOTS+id+"_regalia.res",ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK

func bake_motion(id: String, rig: Skeleton3D, animator: AnimationPlayer) -> bool:
	var library := AnimationLibrary.new()
	for cname: String in CLIPS:
		var src := animator.get_animation(cname)
		var posed := src.duplicate() as Animation
		var bones := ["upperarm_l","lowerarm_l","Head"]
		if cname != "Attack":
			bones.append_array(["spine_02","spine_03","upperarm_r","lowerarm_r"])
		else:
			bones.append_array(["thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"])
		var new_tracks := {}
		for bone_name: String in bones:
			var track := -1
			for i in posed.get_track_count():
				if posed.track_get_type(i) == Animation.TYPE_ROTATION_3D and posed.track_get_path(i).get_concatenated_subnames() == StringName(bone_name):
					track = i
					break
			var path := str(src.track_get_path(0)).get_slice(":",0) + ":" + bone_name
			if track >= 0: posed.remove_track(track)
			var added := posed.add_track(Animation.TYPE_ROTATION_3D)
			posed.track_set_path(added,NodePath(path))
		for bone_name: String in bones:
			var path := str(src.track_get_path(0)).get_slice(":",0) + ":" + bone_name
			new_tracks[rig.find_bone(bone_name)] = posed.find_track(NodePath(path),Animation.TYPE_ROTATION_3D)
		animator.play(cname,0)
		var count := maxi(12,ceili(src.length * (120 if cname == "Attack" else 40)))
		for frame in range(count+1):
			var t := float(frame)/count
			rig.reset_bone_poses()
			animator.seek(t*src.length,true)
			animator.advance(0)
			if id == "wychwood_raider":
				ward_pose(rig,cname,t)
			else:
				hauler_pose(rig,cname,t)
			for bone: int in new_tracks:
				posed.rotation_track_insert_key(new_tracks[bone],t*src.length,rig.get_bone_pose_rotation(bone))
		library.add_animation(cname,posed)
		print(id," ",cname,": ",count+1," baked poses")
	return ResourceSaver.save(library,SLOTS+id+"_motion.res",ResourceSaver.FLAG_COMPRESS)==OK

func twist(rig: Skeleton3D, bone_name: String, angles: Vector3) -> void:
	var bone := rig.find_bone(bone_name)
	var g := rig.get_bone_global_pose(bone)
	var delta := Basis.from_euler(angles * PI/180.0)
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.orthonormalized()
	rig.set_bone_pose_rotation(bone,(parent.inverse() * delta * g.basis.orthonormalized()).get_rotation_quaternion())

func aim(rig: Skeleton3D, name: String, child: String, direction: Vector3, fraction: float) -> void:
	var b := rig.find_bone(name)
	var c := rig.find_bone(child)
	var g := rig.get_bone_global_pose(b)
	var from := (rig.get_bone_global_pose(c).origin - g.origin).normalized()
	var rotation := Quaternion.IDENTITY.slerp(Quaternion(from,direction.normalized()),fraction)
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(b)).basis.orthonormalized()
	rig.set_bone_pose_rotation(b,(parent.inverse()*Basis(rotation)*g.basis.orthonormalized()).get_rotation_quaternion())

func place_foot(rig: Skeleton3D, side: String, ankle: Vector3, knee_out: float) -> void:
	# Solve the original limb lengths about a forward-facing knee. Targets are
	# floor-relative in the same local bind coordinates as the native strike.
	var thigh := "thigh_" + side
	var calf := "calf_" + side
	var foot := "foot_" + side
	var hip := rig.get_bone_global_pose(rig.find_bone(thigh)).origin
	var knee := rig.get_bone_global_pose(rig.find_bone(calf)).origin
	var index := rig.find_bone(foot)
	var l1 := knee.distance_to(hip)
	var l2 := rig.get_bone_global_pose(index).origin.distance_to(knee)
	var axis := hip.direction_to(ankle)
	var distance := clampf(hip.distance_to(ankle), absf(l2-l1)+.001, l2+l1-.001)
	var along := (l1*l1-l2*l2+distance*distance)/(2.0*distance)
	var pole := Vector3(knee_out,0,1).slide(axis).normalized()
	var to_knee := along*axis + pole*sqrt(maxf(0,l1*l1-along*along))
	aim(rig,thigh,calf,to_knee,1.0)
	aim(rig,calf,foot,ankle-rig.get_bone_global_pose(rig.find_bone(calf)).origin,1.0)
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(index)).basis.orthonormalized()
	var sole := rig.get_bone_global_rest(index).basis.orthonormalized()
	rig.set_bone_pose_rotation(index,(parent.inverse()*sole).get_rotation_quaternion())

func ward_pose(rig: Skeleton3D, clip: String, t: float) -> void:
	var beat := sin(TAU*t)
	var step := sin(TAU*t-0.4)
	if clip == "Attack":
		# The guard boards roll away from the returning right hand at contact.
		# Keep all ancestors of the calibrated right-hand probe untouched.
		var step_out := smoothstep(.12,.47,t)
		place_foot(rig,"l",Vector3(.22+.055*step_out,.065+.067*sin(PI*step_out),.095+.35*step_out),.29)
		place_foot(rig,"r",Vector3(-.215,.069,-.205),-.23)
		var open := smoothstep(.28,.64,t)*(1.0-smoothstep(.76,1.0,t))
		aim(rig,"upperarm_l","lowerarm_l",Vector3(.37+.54*open,-.68,.72-.65*open),.72)
		aim(rig,"lowerarm_l","hand_l",Vector3(-.30+.60*open,.54-.85*open,.79),.76)
		twist(rig,"Head",Vector3(5.0*open,-9.0*(1.0-open),-3.0*open))
		return
	var traveling := 0.25 if clip=="Idle" else 1.0
	var hurried := 1.0 if clip=="Running" else .44
	twist(rig,"spine_02",Vector3(1.5, -11.0+4.3*step*traveling, 3.0+2.2*beat*traveling))
	twist(rig,"spine_03",Vector3(1.5+2.0*beat,-6.0-2.0*step,1.5))
	twist(rig,"Head",Vector3(2.3+1.5*beat,14+4.0*cos(TAU*t),-3))
	aim(rig,"upperarm_l","lowerarm_l",Vector3(.56,-.78,.20+.22*step*traveling),.83)
	aim(rig,"lowerarm_l","hand_l",Vector3(.05,-.42+.11*beat,.84),.78)
	aim(rig,"upperarm_r","lowerarm_r",Vector3(-.44,-.77,-.26-step*.38*traveling*hurried),.52)
	aim(rig,"lowerarm_r","hand_r",Vector3(.10,-.62,.55-step*.38*traveling),.51)

func hauler_pose(rig: Skeleton3D, clip: String, t: float) -> void:
	var stride := sin(t*TAU)
	var sink := pow(absf(stride),1.5)
	if clip == "Attack":
		# His shoulders descend into the yoke and the lead knee absorbs the
		# lunge while both soles hold ground through the heave and recovery.
		place_foot(rig,"l",Vector3(.32,.08,.33),.41)
		place_foot(rig,"r",Vector3(-.29,.08,-.16),-.48)
		var brace := smoothstep(.03,.47,t)
		var drive := smoothstep(.46,.70,t)
		var recover := smoothstep(.73,1.0,t)
		aim(rig,"upperarm_l","lowerarm_l",Vector3(.49,-.62+.54*brace-.82*drive,-.29+.91*drive),.72-.30*recover)
		aim(rig,"lowerarm_l","hand_l",Vector3(-.09,-.12+.66*brace-1.24*drive,.83),.68-.22*recover)
		twist(rig,"Head",Vector3(15.0*brace-10*drive+4*recover,5*brace-13*drive,-7.5*brace+8*drive))
		return
	var loaded := .23 if clip=="Idle" else 1.0
	var depth := 1.0 if clip=="Running" else .7
	# A loaded shoulder settles after each footfall; the neck pitches separately.
	twist(rig,"spine_02",Vector3(8.0+4.3*sink*loaded,-4.5*stride*loaded,5.5*stride*loaded+2.5))
	twist(rig,"spine_03",Vector3(2.8+2.4*cos(t*TAU),2*stride,-3.4*stride*loaded))
	twist(rig,"Head",Vector3(-8.5+2.3*cos(t*TAU-.4),3.4*stride,2.0))
	for left: bool in [true,false]:
		var sign_dir := 1.0 if left else -1.0
		var side := "l" if left else "r"
		var swing := sign_dir*stride*loaded*depth
		aim(rig,"upperarm_"+side,"lowerarm_"+side,Vector3(sign_dir*.57,-.71,-.23+.36*swing),.63)
		aim(rig,"lowerarm_"+side,"hand_"+side,Vector3(sign_dir*.27,-.65,.55+.45*swing),.68)
