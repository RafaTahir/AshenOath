extends RefCounted

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
const CharacterIdentityProfile = preload("res://scripts/character_identity_profile.gd")

static func apply_player(owner: Node3D, visual_root: Node3D) -> void:
	if owner == null or visual_root == null:
		return
	if owner.has_meta("character_presentation_applied"):
		return
	owner.set_meta("character_presentation_applied", true)
	_add_contact_shadow(owner, Vector3(0.92, 0.018, 0.62), 0.0)
	if _has_skeleton(visual_root):
		CharacterVisualContract.remove_proxy_anatomy(visual_root)
		CharacterIdentityProfile.apply(visual_root, "player_kael")
		return
	# A non-skeletal asset is an emergency fallback only. Do not decorate it with
	# root-mounted anatomy: those parts drift, inflate the neck, and desync from
	# the controller. The fallback body remains deliberately minimal until a
	# complete rigged role is available.
	owner.set_meta("character_overlay_contract", "disabled")

static func apply_npc(owner: Node3D, role_id: String) -> void:
	if owner == null:
		return
	if owner.has_meta("character_presentation_applied"):
		return
	owner.set_meta("character_presentation_applied", true)
	_add_contact_shadow(owner, Vector3(0.72, 0.016, 0.50), 0.0)
	var role = role_id.to_lower()
	if _has_skeleton(owner):
		CharacterVisualContract.remove_proxy_anatomy(owner)
		CharacterIdentityProfile.apply(owner, role)
		return
	# Non-skeletal bodies are not allowed to acquire fake clothing or facial
	# geometry. Keep the shadow only and let the asset acceptance gate reject the
	# role until a complete shared-rig replacement is installed.
	owner.set_meta("character_overlay_contract", "disabled")

static func apply_enemy(owner: Node3D, scale_value: Vector3 = Vector3(0.78, 0.014, 0.58)) -> void:
	if owner == null or owner.has_meta("character_grounding_applied"):
		return
	owner.set_meta("character_grounding_applied", true)
	_add_contact_shadow(owner, scale_value, 0.0)
	if _has_skeleton(owner):
		CharacterVisualContract.remove_proxy_anatomy(owner)
		var enemy_role = str(owner.get("enemy_id")) if owner.get("enemy_id") != null else "ghoulkin"
		CharacterIdentityProfile.apply(owner, enemy_role)
		return
	# No root-mounted monster anatomy. A non-skeletal enemy is a temporary
	# fallback and must remain visibly honest rather than wearing fake limbs.
	owner.set_meta("character_overlay_contract", "disabled")

static func _villager_cloth_color(role: String) -> Color:
	if role.contains("widow"):
		return Color(0.16, 0.15, 0.22)
	if role.contains("blacksmith"):
		return Color(0.23, 0.20, 0.17)
	if role.contains("farmer"):
		return Color(0.26, 0.18, 0.10)
	return Color(0.22, 0.18, 0.13)

static func _add_contact_shadow(owner: Node3D, scale_value: Vector3, y: float) -> void:
	var shadow = MeshInstance3D.new()
	shadow.name = "CharacterContactShadow"
	shadow.set_meta("visual_name", "CharacterContactShadow")
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.018
	mesh.radial_segments = 24
	shadow.mesh = mesh
	shadow.position = Vector3(0, y + 0.028, 0)
	shadow.scale = scale_value
	shadow.material_override = _mat(Color(0.018, 0.014, 0.010), 0.96)
	owner.add_child(shadow)

static func _add_ghoulkin_details(owner: Node3D, quality: bool) -> void:
	var parent = _find_named_node(owner, "visual_root")
	if parent == null:
		parent = owner
	_add_box(parent, "GhoulkinHunchedBackRead", Vector3(0, 1.02, 0.18), Vector3(0.52, 0.28, 0.32), Color(0.16, 0.15, 0.12), Vector3(-12, 0, 0))
	_add_box(parent, "GhoulkinLongArmLeft", Vector3(-0.42, 0.70, -0.18), Vector3(0.11, 0.72, 0.13), Color(0.18, 0.16, 0.13), Vector3(20, 0, -18))
	_add_box(parent, "GhoulkinLongArmRight", Vector3(0.42, 0.70, -0.18), Vector3(0.11, 0.72, 0.13), Color(0.18, 0.16, 0.13), Vector3(20, 0, 18))
	_add_box(parent, "GhoulkinClawLeft", Vector3(-0.51, 0.34, -0.45), Vector3(0.15, 0.045, 0.34), Color(0.49, 0.46, 0.35), Vector3(18, 0, -18))
	_add_box(parent, "GhoulkinClawRight", Vector3(0.51, 0.34, -0.45), Vector3(0.15, 0.045, 0.34), Color(0.49, 0.46, 0.35), Vector3(18, 0, 18))
	_add_fake_light_gem(parent, "GhoulkinEyeLeft", Vector3(-0.07, 1.42, -0.34), Color(0.78, 0.95, 0.58), 0.9)
	_add_fake_light_gem(parent, "GhoulkinEyeRight", Vector3(0.07, 1.42, -0.34), Color(0.78, 0.95, 0.58), 0.9)
	if quality:
		for x in [-0.18, 0.0, 0.18]:
			_add_box(parent, "GhoulkinRibRead", Vector3(x, 0.98, -0.36), Vector3(0.055, 0.28, 0.035), Color(0.41, 0.38, 0.30), Vector3(0, 0, x * 35.0))
		_add_box(parent, "GhoulkinRotStain", Vector3(0, 0.86, -0.39), Vector3(0.36, 0.24, 0.025), Color(0.08, 0.18, 0.10))

static func _add_cloak_panel(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, pitch: float) -> void:
	_add_box(parent, name, pos, size, color, Vector3(pitch, 0, 0))

static func _add_shoulders(parent: Node3D, prefix: String, color: Color, width: float) -> void:
	for side in [-1, 1]:
		_add_box(parent, "%sShoulderRead" % prefix, Vector3(width * side, 1.34, -0.08), Vector3(0.22, 0.14, 0.26), color, Vector3(0, 0, -9 * side))

static func _add_head_detail(parent: Node3D, prefix: String, skin: Color, hair: Color, hood: bool) -> void:
	_add_box(parent, "%sFacePlane" % prefix, Vector3(0, 1.62, -0.31), Vector3(0.22, 0.27, 0.025), skin)
	_add_box(parent, "%sEyeLeft" % prefix, Vector3(-0.055, 1.66, -0.328), Vector3(0.028, 0.018, 0.010), Color(0.018, 0.014, 0.010))
	_add_box(parent, "%sEyeRight" % prefix, Vector3(0.055, 1.66, -0.328), Vector3(0.028, 0.018, 0.010), Color(0.018, 0.014, 0.010))
	var hair_mesh = MeshInstance3D.new()
	hair_mesh.name = "%sHairSilhouette" % prefix
	hair_mesh.set_meta("visual_name", hair_mesh.name)
	var sphere = SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.24
	hair_mesh.mesh = sphere
	hair_mesh.scale = Vector3(0.82, 0.56, 0.66)
	hair_mesh.position = Vector3(0, 1.76, -0.07)
	hair_mesh.material_override = _mat(hair, 0.82)
	parent.add_child(hair_mesh)
	if hood:
		var hood_mesh = MeshInstance3D.new()
		hood_mesh.name = "%sHoodSilhouette" % prefix
		hood_mesh.set_meta("visual_name", hood_mesh.name)
		var hood_sphere = SphereMesh.new()
		hood_sphere.radius = 0.29
		hood_sphere.height = 0.34
		hood_mesh.mesh = hood_sphere
		hood_mesh.scale = Vector3(0.88, 0.74, 0.78)
		hood_mesh.position = Vector3(0, 1.70, -0.02)
		hood_mesh.material_override = _mat(Color(0.10, 0.10, 0.12), 0.9)
		parent.add_child(hood_mesh)

static func _add_fake_light_gem(parent: Node3D, name: String, pos: Vector3, color: Color, energy: float) -> void:
	var node = MeshInstance3D.new()
	node.name = name
	node.set_meta("visual_name", name)
	var sphere = SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.07
	node.mesh = sphere
	node.position = pos
	var material = _mat(color, 0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	node.material_override = material
	parent.add_child(node)

static func _add_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = name
	node.set_meta("visual_name", name)
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = _mat(color, 0.86)
	parent.add_child(node)
	return node

static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _find_named_node(root: Node, node_name: String) -> Node3D:
	if root is Node3D and root.name == node_name:
		return root
	for child in root.get_children():
		var found = _find_named_node(child, node_name)
		if found != null:
			return found
	return null

static func _quality_details_enabled(owner: Node) -> bool:
	if owner == null or owner.get_tree() == null:
		return true
	var settings_node = owner.get_tree().root.find_child("SettingsManager", true, false)
	if settings_node != null:
		var settings_dict = settings_node.get("settings")
		if typeof(settings_dict) == TYPE_DICTIONARY:
			return not bool(settings_dict.get("potato_mode", false))
	return true

static func _has_skeleton(root: Node) -> bool:
	if root is Skeleton3D:
		return true
	for child in root.get_children():
		if _has_skeleton(child):
			return true
	return false

static func _tint_skeletal_materials(root: Node, tint: Color) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.get_surface_override_material(surface_index)
				if source == null:
					source = mesh_instance.mesh.surface_get_material(surface_index)
				if source is StandardMaterial3D:
					var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
					material.albedo_color *= tint
					material.roughness = clamp(material.roughness, 0.48, 0.92)
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					material.metallic = minf(material.metallic, 0.08)
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					mesh_instance.set_surface_override_material(surface_index, material)
	for child in root.get_children():
		_tint_skeletal_materials(child, tint)
