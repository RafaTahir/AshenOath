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
	return {"role": role, "surfaces": surfaces, "face_surfaces": face_surfaces}

static func _profile_for(role: String) -> Dictionary:
	if role in ["player", "player_kael", "player_human", "kael"]:
		return KAEL
	if role in ["sister_anwen", "sister_anwen_human", "anwen"]:
		return ANWEN
	var seed := absi(role.hash())
	var skins := [Color("8d604c"), Color("a97559"), Color("bc876b"), Color("76503f")]
	var hairs := [Color("241a15"), Color("4a3020"), Color("71604e"), Color("302523")]
	var cloth := [Color("3b4430"), Color("4a3430"), Color("303e49"), Color("4a422e")]
	return {
		"skin": skins[seed % skins.size()], "hair": hairs[int(seed / 3) % hairs.size()], "eyes": Color("1b1816"),
		"primary": cloth[int(seed / 5) % cloth.size()], "secondary": cloth[(int(seed / 7) + 1) % cloth.size()].lightened(0.08),
		"linen": Color("b5aa91"), "leather": Color("4b3020"), "boots": Color("2d211a"), "metal": Color("786742")
	}

static func _color_for(token: String, role: String, profile: Dictionary) -> Color:
	if role in ["ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute", "ghoulkin_skeleton"]:
		return {
			"wychwood_stalker": Color("596451"), "wychwood_raider": Color("665b4e"),
			"wychwood_brute": Color("4b5145"), "ghoulkin": Color("626052")
		}.get(role, Color("626052"))
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
