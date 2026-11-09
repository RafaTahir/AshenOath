extends RefCounted

const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
const CharacterIdentityProfile = preload("res://scripts/character_identity_profile.gd")
const StoryWardrobe = preload("res://scripts/story_wardrobe.gd")
const CharacterSilhouette = preload("res://scripts/systems/character_silhouette.gd")
const Craft = preload("res://scripts/prop_craft_geometry.gd")
const HeldProps = preload("res://scripts/held_prop_geometry.gd")
const CLERIC_STAFF_PATH := "res://assets_external/design_pack_v1/C01_ash_staff.glb"
const FORGE_HAMMER_PATH := "res://assets/characters/forge_hammer.tscn"
const OPENING_OCCUPATION_PROP_PATHS := [
	"res://assets_external/environment/props/Bucket_Wooden_1.fbx",
	"res://assets_external/environment/props/Book_Simplified_Single.fbx",
	CLERIC_STAFF_PATH,
	"res://assets_external/environment/props/Axe_Bronze.fbx",
]
static var _activity_meshes: Dictionary = {}
static var _activity_materials: Dictionary = {}

static func make_hart_witness(helper: Node, position: Vector3) -> Node3D:
	var visual: Node3D = helper.spawn_visual_role("white_hart_boss", "enemies")
	if visual == null:
		push_error("Required White Hart witness could not be loaded")
		return null
	helper.apply_normalized_scale(visual, 1.08)
	# The wrapper owns placement; the child retains imported grounding/centering.
	var root := Node3D.new()
	root.name = "WhiteHartWitnessDisplay"
	root.position = position + Vector3.UP * preload("res://scripts/character_role_spec.gd").ground_offset("white_hart_boss")
	root.rotation_degrees.y = 180.0
	root.set_meta("focal_creature", true)
	root.add_child(visual)
	var driver = load("res://scripts/character_animation_driver.gd").new()
	driver.name = "HartWitnessAnimation"
	visual.add_child(driver)
	if not driver.configure(visual, {"idle":"Idle", "dialogue":"Interact"}):
		push_error("White Hart witness requires native idle animation")
		root.free()
		return null
	driver.set_update_rate_hz(12.0)
	return root

static func attach_activity_tool(owner: Node3D, style: String) -> Node3D:
	var existing := owner.find_child("OccupationEquipment", true, false) as Node3D
	if existing != null:
		var hammer := existing.find_child("OccupationProp_blacksmith_tor", true, false) != null or existing.find_child("OccupationProp_forge_helper", true, false) != null
		var book := existing.find_child("OccupationProp_walker_board", true, false) != null
		if (style == "hammer" and hammer) or (style == "book" and book):
			return existing
	var skeleton := _find_skeleton(owner)
	if skeleton == null:
		return null
	var free_care_hand := style == "cloth" and uses_fitted_anwen_staff(skeleton, owner)
	var hand_aliases: Array[String] = []
	hand_aliases.assign(["hand_l", "LeftHand", "Hand.L", "left_hand"] if free_care_hand else ["hand_r", "RightHand", "Hand.R", "right_hand"])
	var bone := _find_bone_index(skeleton, hand_aliases)
	if bone < 0:
		return null
	var hand := BoneAttachment3D.new()
	hand.name = "CastActivityTool"
	hand.set_meta("life_generated_activity_tool", true)
	hand.bone_name = skeleton.get_bone_name(bone)
	hand.bone_idx = bone
	skeleton.add_child(hand)
	var grip := Node3D.new()
	hand.add_child(grip)
	var inherited := skeleton.global_basis.get_scale().abs()
	grip.scale = Vector3(1.0/maxf(inherited.x,0.001),1.0/maxf(inherited.y,0.001),1.0/maxf(inherited.z,0.001))
	if style in ["hammer", "book"]:
		var prop := _instantiate_prop(FORGE_HAMMER_PATH if style == "hammer" else OPENING_OCCUPATION_PROP_PATHS[1])
		if prop != null:
			grip.add_child(prop)
			prop.rotation_degrees.z = 90.0 if style == "hammer" else 0.0
			prop.scale *= 0.65 if style == "book" else 1.0
		return hand
	if not _activity_meshes.has(style):
		var mesh: Mesh
		if style == "rope":
			mesh = HeldProps.rope()
		elif style == "bread":
			# A low oval flatbread retains the former board's exact fitting box.
			var loaf := SphereMesh.new()
			loaf.radius = 0.5
			loaf.height = 1.0
			loaf.radial_segments = 32
			loaf.rings = 12
			var arrays := loaf.get_mesh_arrays()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in vertices.size():
				vertices[index] *= Vector3(.20,.025,.32)
				normals[index] = (normals[index] / Vector3(.20,.025,.32)).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			var flatbread := ArrayMesh.new()
			flatbread.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh = flatbread
		elif style == "cloth":
			mesh = HeldProps.cloth()
		else:
			mesh = HeldProps.vessel(.10 if style == "bowl" else .055, .065 if style == "bowl" else .11, .10 if style == "bowl" else .23)
		_activity_meshes[style] = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.55,0.58,0.53) if style == "cloth" else (Color(.47,.28,.13) if style == "bread" else Color(0.36,0.25,0.14))
		material.roughness = 0.95
		_activity_materials[style] = material
	var visual := MeshInstance3D.new()
	visual.mesh = _activity_meshes[style]
	visual.material_override = _activity_materials[style]
	visual.position.y = -0.08
	grip.add_child(visual)
	if style == "bread":
		var scores := MeshInstance3D.new()
		scores.name = "ScoredFlatbreadCrust"
		scores.mesh = HeldProps.bread_scores()
		scores.material_override = _mat(Color(.64,.42,.20),.94)
		visual.add_child(scores)
	var measured: Dictionary = owner.get_meta("activity_prop_grips", {})
	if measured.has(style):
		if not _fit_activity_grip(hand, grip, visual, measured[style]):
			push_error("Measured activity grip could not bind: " + style)
			hand.queue_free()
			return null
	return hand

static func grip_record_error(skeleton: Skeleton3D, raw: Variant) -> String:
	if not raw is Dictionary or not bool(raw.get("verified", false)): return "grip lacks a verified source receipt"
	var bone := str(raw.get("bone", ""))
	if bone not in ["hand_l", "hand_r"] or skeleton.find_bone(bone) < 0: return "grip hand is missing"
	var palm: Variant = raw.get("palm")
	var anchor: Variant = raw.get("anchor")
	var basis: Variant = raw.get("basis")
	if not palm is Vector3 or not palm.is_finite() or palm.length() < 0.005 or palm.length() > 0.18: return "grip palm is not calibrated"
	if not anchor is Vector3 or not anchor.is_finite() or anchor.length() > 1.5: return "grip surface anchor is invalid"
	if not basis is Basis or not basis.x.is_finite() or not basis.y.is_finite() or not basis.z.is_finite(): return "grip orientation is invalid"
	if not basis.is_equal_approx(basis.orthonormalized()) or not is_equal_approx(basis.determinant(),1.0): return "grip orientation would distort the retained prop"
	var source_hash := str(raw.get("source_sha256", ""))
	if source_hash.length()!=64 or not source_hash.is_valid_hex_number(false): return "grip source hash is invalid"
	var frame := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	if _uniform_hand_scale(frame.basis) <= 0.0: return "retained hand frame is nonuniform or sheared"
	return ""

static func _uniform_hand_scale(basis: Basis) -> float:
	if not basis.x.is_finite() or not basis.y.is_finite() or not basis.z.is_finite() or basis.determinant() <= 0.0: return 0.0
	var scale := basis.get_scale().abs()
	if scale.x <= 0.001 or absf(scale.x-scale.y)>0.0001 or absf(scale.x-scale.z)>0.0001: return 0.0
	var unit := basis.scaled(Vector3.ONE/scale.x)
	return scale.x if unit.is_equal_approx(unit.orthonormalized()) else 0.0

static func _fit_activity_grip(socket: BoneAttachment3D, grip: Node3D, visual: MeshInstance3D, record: Dictionary) -> bool:
	var skeleton := socket.get_parent() as Skeleton3D
	if skeleton==null or grip_record_error(skeleton,record)!="" or str(record.bone)!=str(socket.bone_name): return false
	# Sample the actual hand branch, not a stale BoneAttachment transform or
	# skeleton-root scale; imported bone transforms may carry their own scale.
	var hand_frame := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)
	var scale := _uniform_hand_scale(hand_frame.basis)
	if scale <= 0.0: return false
	var anchor: Vector3 = record.anchor
	var nearest := INF
	for point: Vector3 in visual.mesh.get_faces(): nearest=minf(nearest,point.distance_to(anchor))
	if nearest>0.001: return false
	grip.scale=Vector3.ONE/scale
	visual.basis=record.basis
	visual.position=(record.palm as Vector3)*scale-visual.basis*anchor
	socket.set_meta("measured_grip",record.duplicate(true))
	return true

static func fit_carried_equipment(owner: Node3D, record: Dictionary) -> bool:
	var equipment := owner.find_child("CastleRoleEquipment",true,false) as Node3D
	if equipment==null or str(record.get("kind",""))!="book": return false
	var socket := equipment.get_parent() as BoneAttachment3D
	var skeleton := socket.get_parent() as Skeleton3D if socket!=null else null
	if skeleton==null or grip_record_error(skeleton,record)!="" or str(record.bone)!=str(socket.bone_name): return false
	var book := equipment.get_node_or_null("VarganRecordBook") as MeshInstance3D
	var clasp := equipment.get_node_or_null("VarganRecordBookClasp") as MeshInstance3D
	if book==null or clasp==null or not book.basis.is_equal_approx(record.basis): return false
	# This is the actual retained spine's outer edge, not the book's centre.
	if not (record.anchor as Vector3).is_equal_approx(Vector3(-0.13,0,0)): return false
	var spine := book.get_node_or_null("RecordBoundSpine") as MeshInstance3D
	if spine==null or spine.mesh==null: return false
	var spine_anchor := spine.transform.affine_inverse()*(record.anchor as Vector3)
	var spine_bounds := spine.mesh.get_aabb()
	if not spine_bounds.grow(0.00001).has_point(spine_anchor) or absf(spine_anchor.x-spine_bounds.position.x)>0.001: return false
	var frame := skeleton.global_transform * skeleton.get_bone_global_pose(socket.bone_idx)
	if _uniform_hand_scale(frame.basis)<=0.0: return false
	var parent_frame := frame*equipment.transform
	if _uniform_hand_scale(parent_frame.basis)<=0.0: return false
	var palm := parent_frame.affine_inverse() * (frame*(record.palm as Vector3))
	var offset := palm-book.basis*(record.anchor as Vector3)-book.position
	book.position+=offset
	clasp.position+=offset
	equipment.set_meta("measured_grip",record.duplicate(true))
	return true

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
		StoryWardrobe.attach(visual_root, "player_kael", "kael")
		CharacterSilhouette.apply(visual_root, "player_kael", "kael")
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
		StoryWardrobe.attach(visual_target, role_id.to_lower(), _variant_seed(owner, role_id))
		CharacterSilhouette.apply(visual_target, role_id.to_lower(), _variant_seed(owner, role_id))
		if visual_target != owner:
			_copy_identity_contract(owner, visual_target, role_id.to_lower())
		if role_id.to_lower() in ["sister_anwen", "sister_anwen_human"]:
			_add_anwen_staff(owner)
		return
	owner.set_meta("character_presentation_applied", true)
	if include_ground_shadow:
		_add_contact_shadow(owner, Vector3(0.72, 0.016, 0.50), 0.0)
	var role = role_id.to_lower()
	if _has_skeleton(visual_target):
		CharacterVisualContract.remove_proxy_anatomy(visual_target)
		CharacterIdentityProfile.apply(visual_target, role, _variant_seed(owner, role))
		StoryWardrobe.attach(visual_target, role, _variant_seed(owner, role))
		if visual_target != owner:
			_copy_identity_contract(owner, visual_target, role)
		# The selected GLTFs are complete authored bodies. Hide native held props
		# when the role does not use them so a villager cannot inherit a staff or
		# sword merely because it shares the same compact source family.
		_set_native_role_equipment_visible(owner, role)
		_add_occupation_equipment(owner, role)
		if role in ["sister_anwen", "sister_anwen_human"]:
			# The imported female source can carry a root-authored Cleric_Staff.
			# Hide that duplicate and use one compact staff on the validated hand
			# socket so the prop cannot read as a floating pole in dialogue.
			var native_anwen_staff := owner.find_child("Cleric_Staff", true, false)
			if native_anwen_staff != null:
				native_anwen_staff.visible = false
			_add_anwen_staff(owner)
		if not bool(visual_target.get_meta("character_authored_silhouette", false)):
			_add_castle_role_equipment(owner, role)
		CharacterSilhouette.apply(visual_target, role, _variant_seed(owner, role))
		if visual_target != owner:
			_copy_identity_contract(owner, visual_target, role)
		return
	# Non-skeletal bodies are not allowed to acquire fake clothing or facial
	# geometry. Keep the shadow only and let the asset acceptance gate reject the
	# role until a complete shared-rig replacement is installed.
	owner.set_meta("character_overlay_contract", "disabled")

static func _add_occupation_equipment(owner: Node3D, role: String) -> void:
	var definitions := {
		"walker_well": {
			"path": OPENING_OCCUPATION_PROP_PATHS[0],
			"hand": "left", "scale": 0.96,
			"position": Vector3(0.14, -0.16, 0.04), "rotation": Vector3(0.0, 25.0, 0.0),
		},
		"walker_board": {
			"path": OPENING_OCCUPATION_PROP_PATHS[1],
			"hand": "left", "scale": 1.28,
			"position": Vector3(0.12, -0.10, 0.05), "rotation": Vector3(0.0, 90.0, 90.0),
		},
		"shrine_pilgrim": {
			"path": OPENING_OCCUPATION_PROP_PATHS[2],
			"hand": "left", "scale": 0.27,
			"position": Vector3(0.18, -0.28, 0.02), "rotation": Vector3(180.0, 0.0, 0.0),
		},
		"forge_helper": {
			"path": FORGE_HAMMER_PATH,
			"hand": "right", "scale": 1.0,
			"position": Vector3(0.02, -0.03, 0.0), "rotation": Vector3(0.0, 0.0, 90.0),
		},
		"blacksmith_tor": {
			"path": FORGE_HAMMER_PATH,
			"hand": "right", "scale": 1.0,
			"position": Vector3(0.02, -0.03, 0.0), "rotation": Vector3(0.0, 0.0, 90.0),
		},
	}
	var definition: Dictionary = definitions.get(role, {})
	if definition.is_empty() or owner.find_child("OccupationEquipment", true, false) != null:
		return
	var skeleton := _find_skeleton(owner)
	if skeleton == null:
		return
	var aliases: Array[String] = []
	if str(definition.get("hand", "left")) == "left":
		aliases.assign(["LeftHand", "Hand.L", "hand_l", "left_hand"])
	else:
		aliases.assign(["RightHand", "Hand.R", "hand_r", "right_hand"])
	var hand_index := _find_bone_index(skeleton, aliases)
	if hand_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "OccupationEquipmentSocket"
	attachment.bone_idx = hand_index
	attachment.bone_name = skeleton.get_bone_name(hand_index)
	skeleton.add_child(attachment)
	var equipment := Node3D.new()
	equipment.name = "OccupationEquipment"
	equipment.position = definition.get("position", Vector3.ZERO)
	equipment.rotation_degrees = definition.get("rotation", Vector3.ZERO)
	attachment.add_child(equipment)
	var prop := _instantiate_prop(str(definition.get("path", "")))
	if prop == null:
		attachment.queue_free()
		return
	prop.name = "OccupationProp_%s" % role
	prop.scale = Vector3.ONE * float(definition.get("scale", 1.0))
	equipment.add_child(prop)
	owner.set_meta("character_occupation_equipment", role)

static func _copy_identity_contract(owner: Node3D, visual_target: Node3D, role: String) -> void:
	# Interactable wrappers own the collision and prompt, while the imported
	# visual owns the actual materials and face driver. Mirror the measurable
	# contract so verifiers and save/debug tools inspect the same actor identity.
	for key in [
		"character_identity_profile",
		"character_identity_surfaces",
		"character_face_surfaces",
		"character_face_features",
		"character_face_surface_contract",
		"character_face_contract",
		"character_asset_family",
		"character_composite",
		"character_rig_layer_count",
		"character_role_contract",
		"character_variant_seed",
		"character_variant_recipe", "story_cast_identity", "story_cast_profile",
		"character_palette", "character_silhouette", "character_posture"
	]:
		if visual_target.has_meta(key):
			owner.set_meta(key, visual_target.get_meta(key))
	# A wrapper's forward convention includes the imported model's authored
	# rotation. Copying the raw source flag turns a half-turned body away twice.
	var visual_to_owner := Basis.IDENTITY
	var cursor: Node3D = visual_target
	while cursor != null and cursor != owner:
		visual_to_owner = cursor.basis * visual_to_owner
		cursor = cursor.get_parent() as Node3D
	if cursor == owner:
		var source_forward := Vector3.BACK if bool(visual_target.get_meta("source_forward_positive_z", false)) else Vector3.FORWARD
		owner.set_meta("source_forward_positive_z", (visual_to_owner * source_forward).z > 0.0)
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
	var keeps_staff := role.contains("cleric") or role.contains("pilgrim")
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
		if enemy_role != "white_hart_avatar":
			CharacterIdentityProfile.apply(owner, enemy_role, _variant_seed(owner, enemy_role))
			var silhouette_role: String = str(owner.get("visual_role_override")) if owner.get("visual_role_override") != null else str(enemy_role)
			CharacterSilhouette.apply(_find_character_visual(owner), silhouette_role if silhouette_role != "" else enemy_role, _variant_seed(owner, enemy_role))
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
	var skeleton := _find_skeleton(owner)
	if skeleton == null:
		return
	var fitted_staff := uses_fitted_anwen_staff(skeleton, owner)
	var hand_aliases: Array[String] = []
	hand_aliases.assign(["RightHand", "Hand.R", "hand_r", "right_hand"] if fitted_staff else ["LeftHand", "Hand.L", "hand_l", "left_hand"])
	var hand_index := _find_bone_index(skeleton, hand_aliases)
	if hand_index < 0:
		hand_index = _find_bone_index(skeleton, ["RightHand", "Hand.R", "hand_r", "right_hand"])
	if hand_index < 0:
		return
	if owner.find_child("AnwenStaffEquipment", true, false) != null:
		var existing_socket := owner.find_child("AnwenStaffSocket", true, false) as BoneAttachment3D
		if fitted_staff and existing_socket != null:
			existing_socket.bone_idx = hand_index
			existing_socket.bone_name = skeleton.get_bone_name(hand_index)
			var existing_equipment := owner.find_child("AnwenStaffEquipment", true, false) as Node3D
			existing_equipment.position = Vector3(0, 0.045, -0.012)
			existing_equipment.rotation_degrees = Vector3(0, 0, 90)
			var existing_model := existing_equipment.find_child("AnwenStaffModeled", true, false) as Node3D
			if existing_model != null: existing_model.scale.y = 0.93 / 0.86
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
	# The authored staff origin is its grip; WorldOrientedEquipment keeps its
	# upright shaft while the socket supplies the animated hand position.
	equipment.rotation_degrees = Vector3.ZERO
	if fitted_staff:
		equipment.position = Vector3(0, 0.045, -0.012)
		equipment.rotation_degrees.z = 90.0
	attachment.add_child(equipment)
	var modeled_staff := _instantiate_prop(CLERIC_STAFF_PATH)
	if modeled_staff != null:
		modeled_staff.name = "AnwenStaffModeled"
		# Keep the design's carved ashwood and worn bell, at authored scale.
		modeled_staff.scale = Vector3.ONE
		if fitted_staff:
			modeled_staff.scale.y = 0.93 / 0.86
		modeled_staff.position = Vector3.ZERO
		equipment.add_child(modeled_staff)
		return
	# A missing staff source is an explicit runtime warning, not a fabricated
	# replacement. The cleric remains playable and the asset gate reports the
	# missing optional prop for the next build.
	push_warning("Anwen staff source could not be loaded: %s" % CLERIC_STAFF_PATH)

static func uses_fitted_anwen_staff(skeleton: Skeleton3D, owner: Node) -> bool:
	# GLTF armature extras can be attached to Skeleton3D itself. Prepared
	# assemblies also retain their exact source/identity if extras were omitted.
	var node: Node = skeleton
	var retained_c01 := false
	var anwen_identity := false
	while node != null:
		if node.has_meta("anwen_staff_pose"):
			return bool(node.get_meta("anwen_staff_pose"))
		var extras: Variant = node.get_meta("extras", {})
		if extras is Dictionary and extras.has("anwen_staff_pose"):
			return bool(extras.anwen_staff_pose)
		retained_c01 = retained_c01 or str(node.get_meta("prepared_actor_source", "")).ends_with("/humans/C01_Anwen.glb")
		var role := str(node.get_meta("character_identity_profile", node.get_meta("character_visual_role", "")))
		anwen_identity = anwen_identity or preload("res://scripts/story_cast_profile.gd").canonical_identity(role) == "anwen"
		if node == owner:
			break
		node = node.get_parent()
	if not retained_c01 or not anwen_identity or skeleton.get_bone_count() != 76:
		return false
	for bone: String in ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r"]:
		if skeleton.find_bone(bone) < 0: return false
	return true

static func _instantiate_prop(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		var instance := (resource as PackedScene).instantiate()
		return instance as Node3D
	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		return mesh_instance
	return null

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
		equipment.set_meta("equipment_kind", "spear")
		_add_spear(equipment)
	elif castle_role.contains("guard"):
		equipment.set_meta("equipment_kind", "shield")
		_add_shield(equipment)
	else:
		equipment.set_meta("equipment_kind", "book")
		_add_record_book(equipment, castle_role.contains("steward"))
		var measured: Dictionary = owner.get_meta("carried_equipment_grip",{})
		if not measured.is_empty() and not fit_carried_equipment(owner,measured):
			push_error("Measured carried book grip could not bind: " + castle_role)

static func _inverse_attachment_scale(attachment: BoneAttachment3D) -> Vector3:
	var inherited := attachment.global_basis.get_scale()
	# Imported character roots can carry a very small authored scale. An
	# unbounded inverse turns a hand prop into a giant floating primitive. Keep
	# the correction within the authored equipment range while preserving the
	# skeleton's transform.
	return Vector3(
		clampf(1.0 / max(abs(inherited.x), 0.0001), 0.72, 1.35),
		clampf(1.0 / max(abs(inherited.y), 0.0001), 0.72, 1.35),
		clampf(1.0 / max(abs(inherited.z), 0.0001), 0.72, 1.35)
	)

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
	spearhead.mesh = HeldProps.spearhead()
	spearhead.position = Vector3(0.13, -0.08, 0.0)
	spearhead.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	spearhead.material_override = _mat(Color("6f624b"), 0.42, 0.72)
	parent.add_child(spearhead)

static func _add_shield(parent: Node3D) -> void:
	var shield := MeshInstance3D.new()
	shield.name = "VarganGuardShield"
	shield.mesh = HeldProps.shield()
	# The parent is the actual wrist BoneAttachment3D. Keep the shield close to
	# that socket; a large downward offset follows the hand basis upward on the
	# imported Universal rig and makes the prop float behind the shoulder.
	shield.position = Vector3(0.0, -0.015, -0.045)
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shield.scale = Vector3(1.0, 1.12, 1.0)
	shield.material_override = _mat(Color("3d4852"), 0.55)
	parent.add_child(shield)
	var rim := MeshInstance3D.new()
	rim.name = "VarganGuardShieldBoundRim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = .202
	rim_mesh.outer_radius = .22
	rim_mesh.rings = 16
	rim_mesh.ring_segments = 4
	rim.mesh = rim_mesh
	rim.material_override = _mat(Color("4e5556"),.48,.72)
	shield.add_child(rim)
	var boss := MeshInstance3D.new()
	boss.name = "VarganGuardShieldBoss"
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = .07
	boss_mesh.height = .09
	boss_mesh.radial_segments = 12
	boss_mesh.rings = 5
	boss.mesh = boss_mesh
	boss.position = Vector3(0.0, -0.015, -0.092)
	boss.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	boss.material_override = _mat(Color("9c7845"), 0.45, 0.66)
	parent.add_child(boss)

static func _add_record_book(parent: Node3D, steward: bool) -> void:
	var book := MeshInstance3D.new()
	book.name = "VarganRecordBook"
	var length := .34 if steward else .28
	book.mesh = Craft.box(Vector3(.246,.039,length-.012))
	book.position = Vector3(0.0, -0.25, -0.04)
	book.rotation_degrees = Vector3(12.0, 0.0, -18.0)
	book.material_override = _mat(Color("b2a486"), .94)
	parent.add_child(book)
	var leather := _mat(Color("5b281e") if not steward else Color("6c4f29"), .82)
	for sign_value in [-1.0,1.0]:
		var cover := MeshInstance3D.new()
		cover.name = "RecordLeatherCover"
		cover.mesh = Craft.box(Vector3(.26,.008,length))
		cover.position.y = sign_value * .0235
		cover.material_override = leather
		book.add_child(cover)
	var spine := MeshInstance3D.new()
	spine.name = "RecordBoundSpine"
	spine.mesh = Craft.box(Vector3(.012,.047,length))
	spine.position.x = -.124
	spine.material_override = leather
	book.add_child(spine)
	var clasp := MeshInstance3D.new()
	clasp.name = "VarganRecordBookClasp"
	var clasp_mesh := BoxMesh.new()
	clasp_mesh.size = Vector3(0.035, 0.065, 0.12)
	clasp.mesh = clasp_mesh
	clasp.position = Vector3(0.11, -0.25, -0.04)
	clasp.rotation_degrees = book.rotation_degrees
	clasp.material_override = _mat(Color("a1854e"), 0.35, 0.66)
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

static func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "fitting:%s:%s:%s" % [color.to_html(),roughness,metallic]
	if _activity_materials.has(key): return _activity_materials[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_activity_materials[key] = material
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
