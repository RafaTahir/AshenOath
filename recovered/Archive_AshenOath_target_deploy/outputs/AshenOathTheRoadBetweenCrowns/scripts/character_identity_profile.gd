extends RefCounted

const CharacterFaceDriver = preload("res://scripts/character_face_driver.gd")

class FeatureScaleNormalizer extends Node:
	func _process(_delta: float) -> void:
		var attachment := get_parent() as BoneAttachment3D
		if attachment == null or not is_instance_valid(attachment):
			queue_free()
			return
		var inherited_scale := attachment.global_transform.basis.get_scale()
		var largest := maxf(absf(inherited_scale.x), maxf(absf(inherited_scale.y), absf(inherited_scale.z)))
		var smallest := minf(absf(inherited_scale.x), minf(absf(inherited_scale.y), absf(inherited_scale.z)))
		if largest >= 2.0 or smallest <= 0.5:
			var compensation := Node3D.new()
			compensation.name = "FeatureScaleCompensation"
			compensation.scale = Vector3(
				1.0 / maxf(absf(inherited_scale.x), 0.001),
				1.0 / maxf(absf(inherited_scale.y), 0.001),
				1.0 / maxf(absf(inherited_scale.z), 0.001)
			)
			attachment.add_child(compensation)
			for child in attachment.get_children().duplicate():
				if child == self or child == compensation:
					continue
				attachment.remove_child(child)
				compensation.add_child(child)
			attachment.set_meta("feature_scale_normalized", true)
		queue_free()

const KAEL := {
	"skin": Color("a9785f"), "hair": Color("241914"), "eyes": Color("171412"),
	"primary": Color("202a25"), "secondary": Color("30362d"), "linen": Color("b8ad99"),
	"leather": Color("4a2d1c"), "boots": Color("2b1d17"), "metal": Color("8e784b")
}
const ANWEN := {
	"skin": Color("a98270"), "hair": Color("b8b4aa"), "eyes": Color("292525"),
	"primary": Color("28334b"), "secondary": Color("43475d"), "linen": Color("d2cab8"),
	"leather": Color("3a2929"), "boots": Color("332428"), "metal": Color("a1854e")
}
const HUMAN_ROLES := [
	"player", "player_kael", "player_human", "kael", "sister_anwen", "sister_anwen_human", "anwen",
	"mira_human", "mira_herbalist", "rook_human", "rook_smuggler", "villager_human", "villager_female_human",
	"villager_worker_human", "villager_hooded_human", "castle_guard_human", "road_ranger_human",
	"generic_villager_01", "generic_villager_02", "castle_guard", "road_ranger", "lord_edric", "edric"
]
const MONSTER_ROLES := ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton", "bog_wretch", "gravebound_knight"]

static func apply(root: Node, role_id: String) -> Dictionary:
	var role := role_id.to_lower()
	var profile := _profile_for(role)
	var surfaces := 0
	var face_surfaces := 0
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or (mesh.skin == null and mesh.skeleton == NodePath("")) or str(mesh.name).to_lower().contains("shadow"):
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var source = mesh.get_surface_override_material(index)
			if source == null:
				source = mesh.mesh.surface_get_material(index)
			var surface_name := str(mesh.mesh.surface_get_name(index)).to_lower() if mesh.mesh is ArrayMesh else ""
			var material_name := str(source.resource_name).to_lower() if source != null else ""
			var token := "%s %s %s" % [str(mesh.name).to_lower(), surface_name, material_name]
			mesh.set_surface_override_material(index, _identity_material(source, _color_for(token, role, profile)))
			surfaces += 1
			if token.contains("head") or token.contains("skin") or token.contains("eyes") or token.contains("hair") or token.contains("skull") or token.contains("jaw") or token.contains("mouth") or token.contains("teeth"):
				face_surfaces += 1
	root.set_meta("character_identity_profile", role)
	root.set_meta("character_identity_surfaces", surfaces)
	root.set_meta("character_face_surfaces", face_surfaces)
	# Identity is now carried by the imported mesh materials. Earlier passes
	# attached jaw, hair, eye and clothing primitives to the skeleton; those
	# features were the source of the visible neck hump and could drift during
	# animation. Keep the contract data-only until a role has native face meshes.
	var native_face := _has_native_face_material(root)
	root.set_meta("character_face_features", "native_mesh" if native_face else "missing_native_face")
	if _find_skeleton(root) != null and native_face:
		var face_driver := root.find_child("CharacterFaceDriver", true, false)
		if face_driver == null:
			face_driver = CharacterFaceDriver.new()
			face_driver.name = "CharacterFaceDriver"
			root.add_child(face_driver)
		face_driver.configure(root as Node3D, role)
		root.set_meta("character_face_contract", face_driver.get_contract_report())
	return {"role": role, "surfaces": surfaces, "face_surfaces": face_surfaces}

static func _has_native_face_material(root: Node) -> bool:
	var matches := 0
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var token := str(mesh.name).to_lower()
		if token.contains("head") or token.contains("face") or token.contains("eye") or token.contains("hair") or token.contains("skin"):
			matches += 1
		elif role_is_monster(root) and (mesh.skin != null or mesh.skeleton != NodePath("")) and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			matches += 1
	return matches >= 1

static func role_is_monster(root: Node) -> bool:
	return str(root.get_meta("character_identity_profile", "")) in MONSTER_ROLES

static func _profile_for(role: String) -> Dictionary:
	if role in ["player", "player_kael", "player_human", "kael"]:
		return KAEL
	if role in ["sister_anwen", "sister_anwen_human", "anwen"]:
		return ANWEN
	if role.contains("blacksmith") or role.contains("forge"):
		return _occupation_profile(role, Color("2f2925"), Color("5b3522"), Color("a88a6c"))
	if role.contains("widow") or role.contains("mourner"):
		return _occupation_profile(role, Color("272634"), Color("3b394d"), Color("a47a66"))
	if role.contains("pilgrim") or role.contains("shrine"):
		return _occupation_profile(role, Color("343b32"), Color("5a5540"), Color("99705b"))
	if role.contains("guard") or role.contains("vargan") or role.contains("edric"):
		return _occupation_profile(role, Color("30363d"), Color("4d2424"), Color("a2765e"))
	if role.contains("ranger") or role.contains("senn") or role.contains("rook"):
		return _occupation_profile(role, Color("26342d"), Color("44372a"), Color("8f664f"))
	var seed := absi(role.hash())
	var skins := [Color("8d604c"), Color("a97559"), Color("bc876b"), Color("76503f")]
	var hairs := [Color("241a15"), Color("4a3020"), Color("71604e"), Color("302523")]
	var cloth := [Color("3b4430"), Color("4a3430"), Color("303e49"), Color("4a422e")]
	return {
		"skin": skins[seed % skins.size()], "hair": hairs[int(seed / 3) % hairs.size()], "eyes": Color("1b1816"),
		"primary": cloth[int(seed / 5) % cloth.size()], "secondary": cloth[(int(seed / 7) + 1) % cloth.size()].lightened(0.08),
		"linen": Color("b5aa91"), "leather": Color("4b3020"), "boots": Color("2d211a"), "metal": Color("786742")
	}

static func _occupation_profile(role: String, primary: Color, secondary: Color, skin: Color) -> Dictionary:
	var seed := absi(role.hash())
	var hair_options := [Color("241a15"), Color("4a3020"), Color("71604e"), Color("302523")]
	return {
		"skin": skin, "hair": hair_options[seed % hair_options.size()], "eyes": Color("1b1816"),
		"primary": primary, "secondary": secondary, "linen": Color("b5aa91"),
		"leather": Color("4b3020"), "boots": Color("2d211a"), "metal": Color("786742")
	}

static func _color_for(token: String, role: String, profile: Dictionary) -> Color:
	if role in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton"]:
		var monster_skin: Color = {
			"wychwood_stalker": Color("667462"), "wychwood_raider": Color("716957"),
			"wychwood_brute": Color("5b6255"), "ghoulkin": Color("7b765f")
		}.get(role, Color("626052"))
		if token.contains("eye"):
			return Color("d98a37") if role != "wychwood_brute" else Color("b94d32")
		if token.contains("teeth") or token.contains("mouth") or token.contains("lip"):
			return Color("b6a27c") if role != "wychwood_stalker" else Color("8f8065")
		if token.contains("bone") or token.contains("rib") or token.contains("horn"):
			return Color("9b9272")
		if token.contains("leather") or token.contains("cloth") or token.contains("shirt"):
			return monster_skin.darkened(0.28)
		return monster_skin
	if token.contains("skin"):
		return profile.skin
	if token.contains("hair"):
		return profile.hair
	if token.contains("eyes") or (token.contains("head") and token.contains("brown")):
		return profile.eyes
	if token.contains("gold") or token.contains("metal"):
		return profile.metal
	if token.contains("white") or token.contains("socks"):
		return profile.linen
	if token.contains("feet") or token.contains("shoes") or token.contains("brown_02"):
		return profile.boots
	if token.contains("brown2") or token.contains("leather"):
		return profile.leather
	if token.contains("red"):
		return profile.hair if token.contains("head") else profile.boots
	if token.contains("lightgreen") or token.contains("shirt") or token.contains("limegreen"):
		return profile.primary
	if token.contains("green") or token.contains("pants"):
		return profile.secondary
	return profile.primary

static func _identity_material(source, color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = source.duplicate() as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()
	# Preserve the imported face/clothing atlas. Role identity is a restrained
	# palette wash over the source texture, not a replacement solid color.
	if material.albedo_texture != null:
		material.albedo_color = Color.WHITE.lerp(color, 0.10)
	else:
		material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.04 if color.get_luminance() > 0.42 else 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func _add_monster_eye_details(root: Node, role: String) -> void:
	if root.has_meta("monster_eye_details_applied"):
		return
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return
	var head_index := -1
	for index in range(skeleton.get_bone_count()):
		var bone_key := skeleton.get_bone_name(index).to_lower().replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
		if bone_key == "head" or bone_key.ends_with("head"):
			head_index = index
			break
	if head_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "MonsterHeadFeatures"
	attachment.bone_idx = head_index
	attachment.position = Vector3.ZERO
	skeleton.add_child(attachment)
	var iris_color := Color("d58a30")
	if role == "wychwood_stalker":
		iris_color = Color("b9c65a")
	elif role == "wychwood_brute":
		iris_color = Color("b94432")
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "MonsterEyeDetail_%s" % ("L" if side < 0.0 else "R")
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		eye.mesh = sphere
		eye.position = Vector3(0.145 * side, 0.02, -0.25)
		eye.scale = Vector3(0.78, 0.82, 0.42)
		var material := StandardMaterial3D.new()
		material.albedo_color = iris_color
		material.emission_enabled = true
		material.emission = iris_color
		material.emission_energy_multiplier = 0.42
		material.roughness = 0.34
		eye.material_override = material
		attachment.add_child(eye)
	_add_feature_sphere(attachment, "MonsterJaw", Vector3(0, -0.07, -0.19), Vector3(0.18, 0.12, 0.16), _feature_material(Color("4b4a3e"), 0.86))
	_add_feature_box(attachment, "MonsterMouth", Vector3(0, -0.065, -0.235), Vector3(0.16, 0.035, 0.022), _feature_material(Color("241614"), 0.60))
	_add_feature_box(attachment, "MonsterToothLine", Vector3(0, -0.045, -0.25), Vector3(0.11, 0.018, 0.012), _feature_material(Color("b9aa80"), 0.55))
	_schedule_feature_scale_normalization(root, attachment)
	root.set_meta("monster_eye_details_applied", true)
	root.set_meta("character_face_features", "bone_attached")

static func _add_human_face_details(root: Node, role: String, profile: Dictionary) -> void:
	if root.has_meta("human_face_details_applied"):
		return
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return
	var head_index := _find_bone_index(skeleton, ["head", "head_end", "neck"])
	if head_index < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HeadFeatureSocket"
	attachment.bone_idx = head_index
	attachment.bone_name = skeleton.get_bone_name(head_index)
	skeleton.add_child(attachment)
	# These are small, bone-bound features rather than root-mounted face cards.
	# The body and imported skin remain the primary visual; this pass only restores
	# readable eyes, brows, nose, mouth, hairline, and Kael's scar at conversation distance.
	var skin: Color = profile.get("skin", Color("a9785f"))
	var eye_color: Color = profile.get("eyes", Color("171412"))
	var hair: Color = profile.get("hair", Color("241914"))
	_add_feature_sphere(attachment, "HeadFeatureJaw", Vector3(0, -0.01, -0.145), Vector3(0.18, 0.15, 0.15), _feature_material(skin, 0.78))
	for side in [-1.0, 1.0]:
		var x: float = 0.078 * float(side)
		_add_feature_sphere(attachment, "EyeWhite_%s" % ("L" if side < 0.0 else "R"), Vector3(x, 0.035, -0.205), Vector3(0.040, 0.027, 0.018), _feature_material(Color(0.82, 0.80, 0.72), 0.44))
		_add_feature_sphere(attachment, "Iris_%s" % ("L" if side < 0.0 else "R"), Vector3(x, 0.035, -0.224), Vector3(0.015, 0.015, 0.008), _feature_material(eye_color, 0.32))
		_add_feature_box(attachment, "Brow_%s" % ("L" if side < 0.0 else "R"), Vector3(x, 0.095, -0.215), Vector3(0.073, 0.014, 0.018), _feature_material(hair, 0.86), Vector3(0, 0, -8.0 * side))
	_add_feature_sphere(attachment, "NoseBridge", Vector3(0, 0.005, -0.222), Vector3(0.032, 0.045, 0.044), _feature_material(skin.darkened(0.05), 0.76))
	_add_feature_box(attachment, "MouthLine", Vector3(0, -0.072, -0.211), Vector3(0.095, 0.012, 0.014), _feature_material(Color("4b2625"), 0.62))
	_add_feature_sphere(attachment, "Hairline", Vector3(0, 0.115, -0.055), Vector3(0.205, 0.095, 0.155), _feature_material(hair, 0.84))
	if role in ["player", "player_kael", "player_human", "kael"]:
		_add_feature_box(attachment, "KaelScar", Vector3(0.115, 0.002, -0.23), Vector3(0.016, 0.105, 0.012), _feature_material(Color("7f4038"), 0.72), Vector3(0, 0, 18.0))
	_schedule_feature_scale_normalization(root, attachment)
	root.set_meta("human_face_details_applied", true)
	root.set_meta("character_face_features", "bone_attached")

static func _schedule_feature_scale_normalization(root: Node, attachment: BoneAttachment3D) -> void:
	if root == null or attachment == null:
		return
	# Imported character rigs may carry centimeter-scale bone transforms even
	# after the visible body has been normalized. Compensate the feature socket
	# once after the first pose update so eyes, hair, and mouths stay human-sized.
	var normalizer := FeatureScaleNormalizer.new()
	normalizer.name = "FeatureScaleNormalizer"
	attachment.add_child(normalizer)

static func _find_bone_index(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for index in range(skeleton.get_bone_count()):
		var normalized := skeleton.get_bone_name(index).to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
		for alias in aliases:
			var wanted := alias.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
			if normalized == wanted or normalized.ends_with(wanted):
				return index
	return -1

static func _feature_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Preserve the imported Quaternius atlas. Applying a dark role fallback to
	# textured surfaces erased the authored face, skin, hair, and cloth.
	material.albedo_color = Color.WHITE.lerp(color, 0.10) if material.albedo_texture != null else color
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

static func _add_feature_sphere(parent: Node3D, node_name: String, position: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	node.mesh = sphere
	node.position = position
	node.scale = scale_value
	node.material_override = material
	parent.add_child(node)
	return node

static func _add_feature_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.material_override = material
	parent.add_child(node)
	return node

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
