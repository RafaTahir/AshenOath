extends SceneTree

const ROOT := "res://assets_external/environment/forest/"
const BODY := "res://assets_external/characters_universal/runtime/Villager_Male_Atlas.gltf"
const LIBRARY := "res://assets_external/animations/AnimationLibrary_Godot_Opening.tres"
const Fusion = preload("res://scripts/character_animation_fusion.gd")
const COLORS := {"leather": Color(0.34, 0.20, 0.13), "paper": Color(0.73, 0.63, 0.44), "feather": Color(0.08, 0.10, 0.09), "thread": Color(0.46, 0.12, 0.10), "bone": Color(0.57, 0.50, 0.35), "iron": Color(0.30, 0.33, 0.30), "mud": Color(0.16, 0.12, 0.08)}
var parts: Dictionary = {}
var body_mesh: ArrayMesh

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	body_mesh = await _bake_body()
	if body_mesh == null:
		quit(1)
		return
	for id in ["corpse", "black_feathers", "oren_token", "claw_marks", "tracks"]:
		parts.clear()
		var mesh := body_mesh.duplicate() as ArrayMesh if id == "corpse" else ArrayMesh.new()
		match id:
			"corpse":
				_box("leather", Vector3(0.24, 0.025, 0.18), Vector3(0.50, 0.045, -0.37), -0.35)
				_box("paper", Vector3(0.21, 0.012, 0.16), Vector3(0.50, 0.061, -0.37), -0.35)
				for line in 4:
					_box("leather", Vector3(0.11, 0.002, 0.003), Vector3(0.49, 0.068, -0.42 + line * 0.025), -0.35)
			"black_feathers":
				for i in 5:
					var position := Vector3(-0.19 + i * 0.085, 0.006, sin(i * 1.73) * 0.16)
					_feather(position, 0.24 + i * 0.017, i * 0.73)
				for i in 8:
					_beam("thread", Vector3(-0.17 + i * 0.04, 0.017, sin(i * 0.77) * 0.03), Vector3(-0.13 + i * 0.04, 0.017, sin((i + 1) * 0.77) * 0.03), 0.013)
			"oren_token":
				_disc("bone", Vector3(0, 0.022, 0), Vector2(0.13, 0.16), 0.025)
				for i in 3:
					_beam("iron", Vector3(-0.06 + i * 0.035, 0.049, -0.042), Vector3(-0.042 + i * 0.035, 0.049, 0.05), 0.006)
				for i in 8:
					var a := TAU * i / 8.0
					var b := TAU * (i + 1) / 8.0
					_beam("thread", Vector3(0.14 + cos(a) * 0.06, 0.014, sin(a) * 0.09), Vector3(0.14 + cos(b) * 0.06, 0.014, sin(b) * 0.09), 0.009)
			"claw_marks":
				for i in 11:
					var a := float(i) / 11.0
					var b := float(i + 1) / 11.0
					_beam("iron", Vector3(-0.33 + a * 0.66, 0.025 + sin(a * PI) * 0.035, cos(a * TAU) * 0.09), Vector3(-0.33 + b * 0.66, 0.025 + sin(b * PI) * 0.035, cos(b * TAU) * 0.09), 0.024)
				for i in 3:
					_box("leather", Vector3(0.055, 0.018, 0.20 + i * 0.033), Vector3(-0.17 + i * 0.17, 0.015, 0.03), -0.25 + i * 0.15)
			"tracks":
				for i in 6:
					_disc("mud", Vector3(-0.18 if i % 2 == 0 else 0.18, 0.002, -0.70 + i * 0.27), Vector2(0.095, 0.19), 0.002)
		for group in parts:
			var tool: SurfaceTool = parts[group]
			tool.index()
			tool.commit(mesh)
			var surface := mesh.get_surface_count() - 1
			mesh.surface_set_name(surface, group)
			var material := StandardMaterial3D.new()
			material.albedo_color = COLORS[group]
			material.roughness = 0.95
			if group == "iron":
				material.metallic = 0.4
			mesh.surface_set_material(surface, material)
		mesh.set_meta("clue_identity", id)
		mesh.set_meta("source_sha256", {BODY: FileAccess.get_sha256(BODY), LIBRARY: FileAccess.get_sha256(LIBRARY)})
		var output := ROOT + "Wychwood_%s_Evidence.res" % id
		if ResourceSaver.save(mesh, output, ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Cannot save Wychwood evidence: " + id)
			quit(1)
			return
		print("WYCHWOOD EVIDENCE %s bytes=%d surfaces=%d triangles=%d bounds=%s" % [id, FileAccess.get_file_as_bytes(output).size(), mesh.get_surface_count(), mesh.get_faces().size() / 3, mesh.get_aabb()])
	body_mesh = null
	parts.clear()
	print("WYCHWOOD EVIDENCE BAKE: PASS")
	quit(0)

func _bake_body() -> ArrayMesh:
	var scene := load(BODY) as PackedScene
	var actor := scene.instantiate() as Node3D if scene != null else null
	if actor == null:
		push_error("Required complete A-set body is missing")
		return null
	root.add_child(actor)
	var rest_bounds := AABB()
	var first_rest := true
	for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = node.global_transform * node.mesh.get_aabb()
		rest_bounds = part if first_rest else rest_bounds.merge(part)
		first_rest = false
	if first_rest or rest_bounds.size.y <= 0.01:
		push_error("Complete body has no finite height")
		actor.free()
		return null
	actor.scale *= 1.72 / rest_bounds.size.y
	var animation := Fusion.attach_shared_library(actor)
	var rigs := actor.find_children("*", "Skeleton3D", true, false)
	if animation == null or not animation.has_animation("Death01") or rigs.size() != 1:
		push_error("Required complete-body Death01 rig is missing")
		actor.free()
		return null
	var skeleton := rigs[0] as Skeleton3D
	animation.play("Death01")
	animation.seek(animation.get_animation("Death01").length, true)
	skeleton.force_update_all_bone_transforms()
	var vertices: Array[PackedVector3Array] = []
	var normal_sets: Array[PackedVector3Array] = []
	var sources: Array[Dictionary] = []
	var bounds := AABB()
	var first := true
	for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if node.skin == null:
			continue
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var posed := PackedVector3Array()
			var posed_normals := PackedVector3Array()
			var stride := joints.size() / points.size()
			for index in points.size():
				var point := Vector3.ZERO
				var normal := Vector3.ZERO
				for channel in stride:
					var slot := index * stride + channel
					if weights[slot] <= 0.0:
						continue
					var bind := joints[slot]
					var name := node.skin.get_bind_name(bind)
					var bone := skeleton.find_bone(name) if not name.is_empty() else node.skin.get_bind_bone(bind)
					if bone < 0:
						push_error("Corpse skin has an unresolved named bind")
						actor.free()
						return null
					var pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * node.skin.get_bind_pose(bind)
					point += (pose * points[index]) * weights[slot]
					normal += (pose.basis.inverse().transposed() * normals[index]) * weights[slot]
				posed.append(point)
				posed_normals.append(normal.normalized())
				bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
				first = false
			vertices.append(posed)
			normal_sets.append(posed_normals)
			sources.append({"arrays": arrays, "material": node.get_active_material(surface)})
	# Ground the complete authored death pose, not a stand-in capsule or limbs.
	if bounds.size.y > 0.65 or maxf(bounds.size.x, bounds.size.z) < 1.2:
		push_error("Death pose was not applied: " + str(bounds))
		actor.free()
		return null
	var shift := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var result := ArrayMesh.new()
	for index in sources.size():
		var arrays: Array = sources[index].arrays.duplicate()
		for point in vertices[index].size():
			vertices[index][point] -= shift
		arrays[Mesh.ARRAY_VERTEX] = vertices[index]
		arrays[Mesh.ARRAY_NORMAL] = normal_sets[index]
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(index, sources[index].material)
		result.surface_set_name(index, "BramCompleteBody_%d" % index)
	actor.free()
	await process_frame
	return result

func _surface(id: String) -> SurfaceTool:
	if not parts.has(id):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[id] = tool
	return parts[id]

func _triangle(id: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var tool := _surface(id)
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x, point.z))
		tool.add_vertex(point)

func _quad(id: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(id, a, b, c)
	_triangle(id, a, c, d)

func _box(id: String, size: Vector3, position: Vector3, yaw: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var tool := _surface(id)
	tool.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, yaw), position))

func _beam(id: String, a: Vector3, b: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = a.distance_to(b)
	mesh.top_radius = radius * 0.5
	mesh.bottom_radius = radius * 0.5
	mesh.radial_segments = 5
	mesh.rings = 0
	_surface(id).append_from(mesh, 0, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5))

func _disc(id: String, position: Vector3, radius: Vector2, thickness: float) -> void:
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		var p := position + Vector3(cos(a) * radius.x, thickness, sin(a) * radius.y)
		var q := position + Vector3(cos(b) * radius.x, thickness, sin(b) * radius.y)
		_triangle(id, position + Vector3.UP * thickness, p, q)
		_quad(id, p, q, q - Vector3.UP * thickness, p - Vector3.UP * thickness)

func _feather(position: Vector3, length: float, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	for side in [-1.0, 1.0]:
		var a := position + turn * Vector3(side * 0.041, 0.014, length * 0.25)
		var b := position + turn * Vector3(side * 0.028, 0.021, length * 0.70)
		var tip := position + turn * Vector3(0, 0.006, length)
		if side < 0:
			_quad("feather", position, tip, b, a)
		else:
			_quad("feather", position, a, b, tip)
	_beam("bone", position, position + turn * Vector3(0, 0.015, length * 0.85), 0.005)
