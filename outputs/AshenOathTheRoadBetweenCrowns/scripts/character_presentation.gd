extends RefCounted

static func apply_player(owner: Node3D, visual_root: Node3D) -> void:
	if owner == null or visual_root == null:
		return
	if owner.has_meta("character_presentation_applied"):
		return
	owner.set_meta("character_presentation_applied", true)
	_add_contact_shadow(owner, Vector3(0.92, 0.018, 0.62), 0.0)
	var quality = _quality_details_enabled(owner)
	_add_cloak_panel(visual_root, "PlayerCloakSilhouette", Vector3(-0.16, 0.96, 0.31), Vector3(0.24, 0.88, 0.080), Color(0.050, 0.058, 0.052), -8.0)
	_add_cloak_panel(visual_root, "PlayerCloakSilhouette", Vector3(0.16, 0.96, 0.31), Vector3(0.24, 0.88, 0.080), Color(0.060, 0.066, 0.056), -8.0)
	_add_box(visual_root, "PlayerChestRead", Vector3(0, 1.27, -0.22), Vector3(0.62, 0.46, 0.14), Color(0.105, 0.112, 0.102))
	_add_box(visual_root, "PlayerLeatherHarness", Vector3(-0.16, 1.24, -0.315), Vector3(0.08, 0.54, 0.035), Color(0.23, 0.145, 0.070), Vector3(0, 0, -14))
	_add_box(visual_root, "PlayerLeatherHarness", Vector3(0.16, 1.24, -0.315), Vector3(0.08, 0.54, 0.035), Color(0.23, 0.145, 0.070), Vector3(0, 0, 14))
	_add_box(visual_root, "PlayerBeltRead", Vector3(0, 0.92, -0.20), Vector3(0.68, 0.085, 0.13), Color(0.30, 0.20, 0.10))
	_add_box(visual_root, "PlayerSwordScabbard", Vector3(-0.38, 0.98, 0.22), Vector3(0.09, 0.09, 1.12), Color(0.075, 0.044, 0.026), Vector3(18, 0, -10))
	_add_box(visual_root, "PlayerBootReadLeft", Vector3(-0.18, 0.36, -0.10), Vector3(0.18, 0.36, 0.18), Color(0.055, 0.040, 0.030))
	_add_box(visual_root, "PlayerBootReadRight", Vector3(0.18, 0.36, -0.10), Vector3(0.18, 0.36, 0.18), Color(0.055, 0.040, 0.030))
	_add_head_detail(visual_root, "Player", Color(0.68, 0.55, 0.43), Color(0.76, 0.72, 0.58), true)
	_add_shoulders(visual_root, "Player", Color(0.30, 0.29, 0.24), 0.43)
	if quality:
		_add_box(visual_root, "PlayerQualityFurCollar", Vector3(0, 1.48, 0.04), Vector3(0.70, 0.14, 0.22), Color(0.090, 0.080, 0.065))
		_add_box(visual_root, "PlayerQualityGloveLeft", Vector3(-0.42, 1.03, -0.18), Vector3(0.12, 0.30, 0.12), Color(0.050, 0.036, 0.026))
		_add_box(visual_root, "PlayerQualityGloveRight", Vector3(0.42, 1.03, -0.18), Vector3(0.12, 0.30, 0.12), Color(0.050, 0.036, 0.026))
		_add_box(visual_root, "PlayerQualityArmorPlate", Vector3(0, 1.24, -0.335), Vector3(0.34, 0.30, 0.028), Color(0.22, 0.22, 0.20))

static func apply_npc(owner: Node3D, role_id: String) -> void:
	if owner == null:
		return
	if owner.has_meta("character_presentation_applied"):
		return
	owner.set_meta("character_presentation_applied", true)
	_add_contact_shadow(owner, Vector3(0.72, 0.016, 0.50), 0.0)
	var role = role_id.to_lower()
	if role == "sister_anwen":
		_add_cloak_panel(owner, "SisterAnwenRobeFall", Vector3(-0.14, 0.88, 0.20), Vector3(0.22, 0.92, 0.075), Color(0.12, 0.14, 0.22), -4.0)
		_add_cloak_panel(owner, "SisterAnwenRobeFall", Vector3(0.14, 0.88, 0.20), Vector3(0.22, 0.92, 0.075), Color(0.10, 0.12, 0.19), -4.0)
		_add_box(owner, "SisterAnwenGoldStole", Vector3(0, 1.12, -0.31), Vector3(0.20, 0.95, 0.040), Color(0.62, 0.53, 0.31))
		_add_box(owner, "SisterAnwenPrayerCord", Vector3(0.23, 0.98, -0.33), Vector3(0.04, 0.62, 0.035), Color(0.72, 0.66, 0.46))
		_add_box(owner, "SisterAnwenStaffRead", Vector3(-0.50, 0.96, -0.05), Vector3(0.052, 1.92, 0.052), Color(0.18, 0.10, 0.052), Vector3(0, 0, -4))
		_add_box(owner, "SisterAnwenStaffCap", Vector3(-0.56, 1.86, -0.06), Vector3(0.25, 0.08, 0.08), Color(0.52, 0.44, 0.27), Vector3(0, 0, -4))
		_add_head_detail(owner, "SisterAnwen", Color(0.78, 0.68, 0.56), Color(0.72, 0.70, 0.62), true)
		_add_shoulders(owner, "SisterAnwen", Color(0.46, 0.42, 0.32), 0.34)
		if _quality_details_enabled(owner):
			_add_fake_light_gem(owner, "SisterAnwenShrineAmulet", Vector3(0, 1.24, -0.35), Color(0.95, 0.72, 0.26), 0.7)
	elif role == "mira":
		_add_cloak_panel(owner, "MiraHerbalistApron", Vector3(0, 0.86, 0.16), Vector3(0.44, 0.68, 0.07), Color(0.10, 0.28, 0.15), -5.0)
		_add_box(owner, "MiraSatchelRead", Vector3(0.37, 0.88, -0.05), Vector3(0.20, 0.28, 0.12), Color(0.28, 0.17, 0.08))
		_add_head_detail(owner, "Mira", Color(0.70, 0.56, 0.45), Color(0.13, 0.075, 0.045), false)
	elif role == "rook":
		_add_cloak_panel(owner, "RookDarkCloak", Vector3(0, 0.88, 0.18), Vector3(0.46, 0.76, 0.07), Color(0.065, 0.065, 0.070), -8.0)
		_add_box(owner, "RookDaggerRead", Vector3(0.35, 0.82, -0.18), Vector3(0.045, 0.045, 0.48), Color(0.50, 0.50, 0.48), Vector3(20, -16, 8))
		_add_head_detail(owner, "Rook", Color(0.62, 0.47, 0.36), Color(0.055, 0.040, 0.030), true)
	else:
		_add_cloak_panel(owner, "VillagerLayeredCloth", Vector3(0, 0.82, 0.16), Vector3(0.42, 0.62, 0.065), _villager_cloth_color(role), -4.0)
		_add_box(owner, "VillagerBeltRead", Vector3(0, 0.78, -0.12), Vector3(0.48, 0.06, 0.08), Color(0.26, 0.16, 0.08))
		if role.contains("blacksmith"):
			_add_box(owner, "BlacksmithApronRead", Vector3(0, 0.98, -0.25), Vector3(0.42, 0.74, 0.050), Color(0.11, 0.095, 0.080))
			_add_box(owner, "BlacksmithGloveRead", Vector3(0.42, 0.95, -0.10), Vector3(0.13, 0.36, 0.13), Color(0.060, 0.050, 0.040))
		elif role.contains("farmer"):
			_add_box(owner, "FarmerSashRead", Vector3(-0.14, 0.96, -0.20), Vector3(0.08, 0.72, 0.040), Color(0.34, 0.22, 0.10), Vector3(0, 0, -12))
		elif role.contains("widow"):
			_add_cloak_panel(owner, "WidowMourningVeil", Vector3(0, 1.32, 0.08), Vector3(0.42, 0.52, 0.06), Color(0.065, 0.062, 0.082), -3.0)
		_add_head_detail(owner, "Villager", Color(0.66, 0.52, 0.40), Color(0.14, 0.09, 0.055), false)

static func apply_enemy(owner: Node3D, scale_value: Vector3 = Vector3(0.78, 0.014, 0.58)) -> void:
	if owner == null or owner.has_meta("character_grounding_applied"):
		return
	owner.set_meta("character_grounding_applied", true)
	_add_contact_shadow(owner, scale_value, 0.0)
	var enemy_id = str(owner.get("enemy_id")) if owner.get("enemy_id") != null else ""
	if enemy_id == "ghoulkin":
		_add_ghoulkin_details(owner, _quality_details_enabled(owner))

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
