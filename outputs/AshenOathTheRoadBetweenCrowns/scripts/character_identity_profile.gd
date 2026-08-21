extends RefCounted

const CharacterFaceDriver = preload("res://scripts/character_face_driver.gd")

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
const MONSTER_ROLES := [
	"ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute",
	"ghoulkin_skeleton", "bog_wretch", "gravebound_knight", "bell_eater",
	"rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar"
]

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
			mesh.set_surface_override_material(index, _identity_material(source, _color_for(token, role, profile), role_is_monster_role(role)))
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
	if role in MONSTER_ROLES:
		var monster_skin: Color = {
			"wychwood_stalker": Color("667462"), "wychwood_raider": Color("716957"),
			"wychwood_brute": Color("5b6255"), "ghoulkin": Color("7b765f"),
			"bog_wretch": Color("3f6650"), "gravebound_knight": Color("4e5360"),
			"bell_eater": Color("5d4840"), "rootbound_colossus": Color("405b43"),
			"ashwing": Color("614a3d"), "halvern_boss": Color("434957"),
			"white_hart_avatar": Color("c0c7b3")
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

static func _identity_material(source, color: Color, monster := false) -> StandardMaterial3D:
	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = source.duplicate() as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()
	# Preserve the imported face/clothing atlas. Role identity is a restrained
	# palette wash over the source texture, not a replacement solid color.
	if material.albedo_texture != null:
		# The imported Ghoul meshes share a deliberately restrained atlas. A
		# stronger role wash keeps stalker/raider/brute readable at gameplay
		# distance while preserving the source texture detail.
		var wash := 0.42 if monster else 0.10
		material.albedo_color = Color.WHITE.lerp(color, wash)
	else:
		material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.04 if color.get_luminance() > 0.42 else 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func role_is_monster_role(role: String) -> bool:
	return role in MONSTER_ROLES

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
