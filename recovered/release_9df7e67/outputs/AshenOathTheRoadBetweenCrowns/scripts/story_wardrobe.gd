extends RefCounted

const CastProfile = preload("res://scripts/story_cast_profile.gd")

static func attach(owner: Node3D, role: String, seed: String = "") -> void:
	var profile := CastProfile.get_profile(role, seed)
	if profile.is_empty() or owner.find_child("StoryKeepsake", true, false) != null:
		return
	var skeleton: Skeleton3D
	for candidate in owner.find_children("*", "Skeleton3D", true, false):
		skeleton = candidate as Skeleton3D
		break
	if skeleton == null:
		return
	var index := -1
	for alias in ["pelvis", "Hips", "hips", "DEF-hips"]:
		index = skeleton.find_bone(alias)
		if index >= 0:
			break
	if index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "StoryKeepsake"
	attachment.bone_idx = index
	attachment.bone_name = skeleton.get_bone_name(index)
	skeleton.add_child(attachment)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.19, -0.06, 0.085)
	attachment.add_child(pivot)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(str(profile.accent))
	material.roughness = 0.91
	var token := str(profile.token)
	# Small, deliberate story objects follow the actual pelvis socket. They do
	# not alter anatomical silhouettes or require another skinned mesh/material.
	if token in ["broken_oath", "road_knot", "root"]:
		var ribbon := BoxMesh.new()
		ribbon.size = Vector3(0.044, 0.23 if token == "broken_oath" else 0.15, 0.018)
		_piece(pivot, ribbon, material, Vector3(0, -0.09, 0), Vector3(0, 0, 0.15))
		if token == "road_knot":
			_piece(pivot, ribbon, material, Vector3(0.026, -0.07, 0.02), Vector3(0, 0, -0.3))
	elif token in ["seal", "bell", "iron"]:
		var medal := CylinderMesh.new()
		medal.top_radius = 0.047
		medal.bottom_radius = 0.055 if token == "bell" else 0.047
		medal.height = 0.07 if token == "bell" else 0.018
		medal.radial_segments = 8
		_piece(pivot, medal, material, Vector3(0, -0.03, 0), Vector3(PI * 0.5, 0, 0))
	else:
		var packet := BoxMesh.new()
		packet.size = Vector3(0.11, 0.14, 0.033)
		_piece(pivot, packet, material, Vector3(0, -0.04, 0), Vector3(0, 0, -0.12))
	attachment.set_meta("story_owner", str(profile.id))
	attachment.set_meta("story_object", token)
	owner.set_meta("story_cast_identity", str(profile.id))

static func _piece(parent: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 14.0
	parent.add_child(instance)
