extends RefCounted

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
const CharacterIdentityProfile = preload("res://scripts/character_identity_profile.gd")

class WorldOrientedEquipment extends Node3D:
	var actor: Node3D
	# Intentionally has no process callback. This node is a child of a
	# BoneAttachment3D, so the skeleton is authoritative for staff orientation.
	# Reapplying the actor root basis every frame detached the prop from the hand.

static func apply_player(owner: Node3D, visual_root: Node3D) -> void:
	if owner == null or visual_root == null:
		return
	if owner.has_meta("character_presentation_applied"):
		return
	owner.set_meta("character_presentation_applied", true)
	_add_contact_shadow(owner, Vector3(0.92, 0.018, 0.62), 0.0)
	if _has_skeleton(visual_root):
		CharacterVisualContract.remove_proxy_anatomy(visual_root)
		CharacterIdentityProfile.apply(visual_root, "player_kael", "kael")
		return
	# A non-skeletal asset is an emergency fallback only. Do not decorate it with
	# root-mounted anatomy: those parts drift, inflate the neck, and desync from
	# the controller. The fallback body remains deliberately minimal until a
	# complete rigged role is available.
	owner.set_meta("character_overlay_contract", "disabled")

static func apply_npc(owner: Node3D, role_id: String, include_ground_shadow: bool = true) -> void:
	if owner == null:
		return
	var visual_target := _find_character_visual(owner)
	if owner.has_meta("character_presentation_applied"):
		# Interactable actors can be wrapped by an Area3D after their imported
		# visual is created. Repair the child contract if the wrapper was marked
		# first, rather than leaving the real body without its face driver.
		if visual_target != owner and _has_skeleton(visual_target) and visual_target.find_child("CharacterFaceDriver", true, false) == null:
			CharacterIdentityProfile.apply(visual_target, role_id.to_lower(), _variant_seed(owner, role_id))
		if visual_target != owner:
			_copy_identity_contract(owner, visual_target, role_id.to_lower())
		return
	owner.set_meta("character_presentation_applied", true)
	if include_ground_shadow:
		_add_contact_shadow(owner, Vector3(0.72, 0.016, 0.50), 0.0)
	var role = role_id.to_lower()
	if _has_skeleton(visual_target):
		CharacterVisualContract.remove_proxy_anatomy(visual_target)
		CharacterIdentityProfile.apply(visual_target, role, _variant_seed(owner, role))
		if visual_target != owner:
			_copy_identity_contract(owner, visual_target, role)
		# The selected GLTFs are complete authored bodies. Hide native held props
		# when the role does not use them so a villager cannot inherit a staff or
		# sword merely because it shares the same compact source family.
		_set_native_role_equipment_visible(owner, role)
		if role in ["sister_anwen", "sister_anwen_human"]:
			# The Universal body owns its native hand/skin layers. Do not layer a
			# second root-equivalent staff over the validated bone attachment.
			if owner.find_child("Cleric_Staff", true, false) == null:
				_add_anwen_staff(owner)
		_add_castle_role_equipment(owner, role)
		return
	# Non-skeletal bodies are not allowed to acquire fake clothing or facial
	# geometry. Keep the shadow only and let the asset acceptance gate reject the
	# role until a complete shared-rig replacement is installed.
	owner.set_meta("character_overlay_contract", "disabled")

static func _copy_identity_contract(owner: Node3D, visual_target: Node3D, role: String) -> void:
	# Interactable wrappers own the collision and prompt, while the imported
	# visual owns the actual materials and face driver. Mirror the measurable
	# contract so verifiers and save/debug tools inspect the same actor identity.
	for key in [
		"character_identity_profile",
		"character_identity_surfaces",
		"character_face_surfaces",
		"character_face_features",
		"character_face_contract",
		"character_asset_family",
		"character_composite",
		"character_rig_layer_count",
		"character_role_contract",
		"character_variant_seed",
		"character_variant_recipe"
	]:
		if visual_target.has_meta(key):
			owner.set_meta(key, visual_target.get_meta(key))
	if not owner.has_meta("character_identity_profile"):
		owner.set_meta("character_identity_profile", role)

static func _find_character_visual(owner: Node3D) -> Node3D:
	if owner.get_meta("character_asset_family", "") != "" or bool(owner.get_meta("character_composite", false)):
		return owner
	for child in owner.get_children():
		if child is Node3D:
			var found := _find_character_visual(child as Node3D)
			if found != child or child.get_meta("character_asset_family", "") != "":
				return found
	return owner

static func _set_native_role_equipment_visible(owner: Node3D, role: String) -> void:
	var keeps_staff := role in ["sister_anwen", "sister_anwen_human"] or role.contains("cleric") or role.contains("pilgrim")
	var native_staff := owner.find_child("Cleric_Staff", true, false)
	if native_staff != null:
		native_staff.visible = keeps_staff
	var keeps_sword := role.contains("guard") or role.contains("edric") or role.contains("halvern") or role.contains("knight")
	var native_sword := owner.find_child("Warrior_Sword", true, false)
	if native_sword != null:
		native_sword.visible = keeps_sword

static func apply_enemy(owner: Node3D, scale_value: Vector3 = Vector3(0.78, 0.014, 0.58)) -> void:
	if owner == null or owner.has_meta("character_grounding_applied"):
		return
	owner.set_meta("character_grounding_applied", true)
	_add_contact_shadow(owner, scale_value, 0.0)
	if _has_skeleton(owner):
		CharacterVisualContract.remove_proxy_anatomy(owner)
		var enemy_role = str(owner.get("enemy_id")) if owner.get("enemy_id") != null else "ghoulkin"
		CharacterIdentityProfile.apply(owner, enemy_role, _variant_seed(owner, enemy_role))
		return
	# No root-mounted monster anatomy. A non-skeletal enemy is a temporary
	# fallback and must remain visibly honest rather than wearing fake limbs.
	owner.set_meta("character_overlay_contract", "disabled")

static func _variant_seed(owner: Node, fallback: String) -> String:
	if owner != null and owner.has_meta("character_variant_seed"):
		var stored := str(owner.get_meta("character_variant_seed", ""))
		if not stored.is_empty():
			return stored
	return fallback

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

static func _add_anwen_staff(owner: Node3D) -> void:
	# Anwen's identity is carried by a real prop socket rather than a root
	# mounted silhouette. The staff follows the imported hand bone through
	# dialogue and locomotion, and its equipment parent is excluded from body
	# bounds and character material validation.
	if owner.find_child("AnwenStaffEquipment", true, false) != null:
		return
	var skeleton := _find_skeleton(owner)
	if skeleton == null:
		return
	var hand_index := _find_bone_index(skeleton, ["LeftHand", "Hand.L", "hand_l", "left_hand"])
	if hand_index < 0:
		hand_index = _find_bone_index(skeleton, ["RightHand", "Hand.R", "hand_r", "right_hand"])
	if hand_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "AnwenStaffSocket"
	attachment.bone_idx = hand_index
	attachment.bone_name = skeleton.get_bone_name(hand_index)
	skeleton.add_child(attachment)
	var equipment := WorldOrientedEquipment.new()
	equipment.name = "AnwenStaffEquipment"
	equipment.actor = owner
	equipment.position = Vector3.ZERO
	attachment.add_child(equipment)
	var staff := MeshInstance3D.new()
	staff.name = "AnwenStaffWood"
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.018
	staff_mesh.bottom_radius = 0.027
	staff_mesh.height = 1.02
	staff_mesh.radial_segments = 8
	staff.mesh = staff_mesh
	staff.position = Vector3(0.0, -0.52, 0.0)
	staff.material_override = _mat(Color("4f392c"), 0.82)
	equipment.add_child(staff)
	var crest := MeshInstance3D.new()
	crest.name = "AnwenStaffCrest"
	var crest_mesh := SphereMesh.new()
	crest_mesh.radius = 0.058
	crest_mesh.height = 0.116
	crest_mesh.radial_segments = 12
	crest.mesh = crest_mesh
	crest.position = Vector3(0.0, -0.02, 0.0)
	var crest_material := _mat(Color("a1854e"), 0.30)
	crest_material.metallic = 0.62
	crest.material_override = crest_material
	equipment.add_child(crest)
	var inlay := MeshInstance3D.new()
	inlay.name = "AnwenStaffInlay"
	var inlay_mesh := CylinderMesh.new()
	inlay_mesh.top_radius = 0.045
	inlay_mesh.bottom_radius = 0.045
	inlay_mesh.height = 0.014
	inlay_mesh.radial_segments = 8
	inlay.mesh = inlay_mesh
	inlay.position = Vector3(0.0, -0.02, -0.075)
	inlay.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var inlay_material := _mat(Color("d7b66d"), 0.28)
	inlay_material.emission_enabled = true
	inlay_material.emission = Color("6e4d25")
	inlay_material.emission_energy_multiplier = 0.38
	inlay.material_override = inlay_material
	equipment.add_child(inlay)

static func _add_castle_role_equipment(owner: Node3D, role: String) -> void:
	var castle_role := role.to_lower()
	if not (castle_role.contains("vargan") or castle_role.contains("edric") or castle_role in ["castle_guard", "castle_guard_human"]):
		return
	if owner.find_child("CastleRoleEquipment", true, false) != null:
		return
	var skeleton := _find_skeleton(owner)
	if skeleton == null:
		return
	var wants_left := castle_role.contains("guard") or castle_role.contains("record") or castle_role.contains("steward")
	var aliases: Array[String] = []
	if wants_left:
		aliases = ["Hand.L", "Fist.L", "FistL", "hand_l", "left_hand"]
	else:
		aliases = ["Hand.R", "Weapon.R", "WeaponR", "Fist.R", "FistR", "hand_r", "right_hand"]
	var bone_index := _find_bone_index(skeleton, aliases)
	if bone_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "CastleRoleEquipmentSocket"
	attachment.bone_idx = bone_index
	attachment.bone_name = skeleton.get_bone_name(bone_index)
	skeleton.add_child(attachment)
	var equipment := WorldOrientedEquipment.new()
	equipment.name = "CastleRoleEquipment"
	equipment.scale = _inverse_attachment_scale(attachment)
	attachment.add_child(equipment)
	if castle_role.contains("patrol") or castle_role.contains("ranger"):
		_add_spear(equipment)
	elif castle_role.contains("guard"):
		_add_shield(equipment)
	else:
		_add_record_book(equipment, castle_role.contains("steward"))

static func _inverse_attachment_scale(attachment: BoneAttachment3D) -> Vector3:
	var inherited := attachment.global_basis.get_scale()
	return Vector3(1.0 / max(abs(inherited.x), 0.0001), 1.0 / max(abs(inherited.y), 0.0001), 1.0 / max(abs(inherited.z), 0.0001))

static func _add_spear(parent: Node3D) -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = "VarganPatrolSpear"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.018
	shaft_mesh.bottom_radius = 0.028
	shaft_mesh.height = 1.28
	shaft_mesh.radial_segments = 8
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, -0.64, 0.0)
	shaft.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	shaft.material_override = _mat(Color("4b3020"), 0.82)
	parent.add_child(shaft)
	var spearhead := MeshInstance3D.new()
	spearhead.name = "VarganPatrolSpearhead"
	var spear_mesh := PrismMesh.new()
	spear_mesh.size = Vector3(0.10, 0.22, 0.06)
	spearhead.mesh = spear_mesh
	spearhead.position = Vector3(0.13, -0.08, 0.0)
	spearhead.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	spearhead.material_override = _mat(Color("6f624b"), 0.42)
	parent.add_child(spearhead)

static func _add_shield(parent: Node3D) -> void:
	var shield := MeshInstance3D.new()
	shield.name = "VarganGuardShield"
	var shield_mesh := CylinderMesh.new()
	shield_mesh.top_radius = 0.34
	shield_mesh.bottom_radius = 0.34
	shield_mesh.height = 0.075
	shield_mesh.radial_segments = 10
	shield.mesh = shield_mesh
	shield.position = Vector3(0.0, -0.30, -0.02)
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shield.scale = Vector3(1.0, 1.18, 1.0)
	shield.material_override = _mat(Color("3d4852"), 0.55)
	parent.add_child(shield)
	var boss := MeshInstance3D.new()
	boss.name = "VarganGuardShieldBoss"
	var boss_mesh := CylinderMesh.new()
	boss_mesh.top_radius = 0.07
	boss_mesh.bottom_radius = 0.07
	boss_mesh.height = 0.09
	boss_mesh.radial_segments = 8
	boss.mesh = boss_mesh
	boss.position = Vector3(0.0, -0.30, -0.065)
	boss.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	boss.material_override = _mat(Color("9c7845"), 0.45)
	parent.add_child(boss)

static func _add_record_book(parent: Node3D, steward: bool) -> void:
	var book := MeshInstance3D.new()
	book.name = "VarganRecordBook"
	var book_mesh := BoxMesh.new()
	book_mesh.size = Vector3(0.26, 0.055, 0.34 if steward else 0.28)
	book.mesh = book_mesh
	book.position = Vector3(0.0, -0.25, -0.04)
	book.rotation_degrees = Vector3(12.0, 0.0, -18.0)
	book.material_override = _mat(Color("5b281e") if not steward else Color("6c4f29"), 0.72)
	parent.add_child(book)
	var clasp := MeshInstance3D.new()
	clasp.name = "VarganRecordBookClasp"
	var clasp_mesh := BoxMesh.new()
	clasp_mesh.size = Vector3(0.035, 0.065, 0.12)
	clasp.mesh = clasp_mesh
	clasp.position = Vector3(0.11, -0.25, -0.04)
	clasp.rotation_degrees = book.rotation_degrees
	clasp.material_override = _mat(Color("a1854e"), 0.35)
	parent.add_child(clasp)

static func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for index in range(skeleton.get_bone_count()):
		var normalized := skeleton.get_bone_name(index).to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
		for alias in aliases:
			var wanted := alias.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
			if normalized == wanted or normalized.ends_with(wanted):
				return index
	return -1

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

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
