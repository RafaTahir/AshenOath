extends RefCounted

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
			if token.contains("head") or token.contains("skin") or token.contains("eyes") or token.contains("hair"):
				face_surfaces += 1
	root.set_meta("character_identity_profile", role)
	root.set_meta("character_identity_surfaces", surfaces)
	root.set_meta("character_face_surfaces", face_surfaces)
	if role in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton"] and root.find_child("Orc_Skull", true, false) != null:
		_add_monster_eye_details(root, role)
	return {"role": role, "surfaces": surfaces, "face_surfaces": face_surfaces}

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
	attachment.name = "MonsterFaceDetails"
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
	root.set_meta("monster_eye_details_applied", true)

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
