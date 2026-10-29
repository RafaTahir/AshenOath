extends RefCounted

const CharacterFaceDriver = preload("res://scripts/character_face_driver.gd")
const StoryCastProfile = preload("res://scripts/story_cast_profile.gd")
const CharacterMaterialBindings = preload("res://scripts/character_material_bindings.gd")
const CharacterPalette = preload("res://scripts/systems/character_palette.gd")
const RegionShader = preload("res://shaders/character_region_palette.gdshader")
const HUMAN_ROLES := [
	"player", "player_kael", "player_human", "kael", "sister_anwen", "sister_anwen_human", "anwen",
	"mira_human", "mira_herbalist", "rook_human", "rook_smuggler", "villager_human", "villager_female_human",
	"villager_worker_human", "villager_hooded_human", "castle_guard_human", "road_ranger_human",
	"bandit", "bandit_deserter", "bandit_tracker",
	"generic_villager_01", "generic_villager_02", "castle_guard", "road_ranger", "lord_edric", "edric"
]
const MONSTER_ROLES := [
	"ghoulkin", "wychwood_stalker", "wychwood_raider", "wychwood_brute",
	"ghoulkin_skeleton", "bog_wretch", "gravebound_knight", "bell_eater",
	"rootbound_colossus", "ashwing", "halvern_boss", "white_hart_avatar",
	"silt_maw", "millback", "glassmoth", "knell_leech", "hearthscale", "gallows_weaver", "reed_choir", "inkblind", "cairn_mother", "shroud_swimmer"
]

static func apply(root: Node, role_id: String, variant_seed: String = "") -> Dictionary:
	var role := role_id.to_lower()
	var resolved_seed := variant_seed if not variant_seed.is_empty() else role
	var profile := CharacterPalette.colors(role, resolved_seed, str(root.get_meta("character_region", "")))
	var cast := StoryCastProfile.get_profile(role, resolved_seed)
	var recipe := _recipe_for(role, profile, resolved_seed)
	var surfaces := 0
	var face_surfaces := 0
	var prebaked_identity := _contains_prebaked_identity(root)
	if prebaked_identity and not CharacterMaterialBindings.has_textured_identity(root):
		CharacterMaterialBindings.restore(root as Node3D)
		if not CharacterMaterialBindings.has_textured_identity(root):
			push_error("Required character atlas is not bound: %s" % role)
			return {"role": role, "surfaces": 0, "valid": false}
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or (mesh.skin == null and mesh.skeleton == NodePath("")) or str(mesh.name).to_lower().contains("shadow"):
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var source = mesh.get_active_material(index)
			var surface_name := str(mesh.mesh.surface_get_name(index)).to_lower() if mesh.mesh is ArrayMesh else ""
			var material_name := str(source.resource_name).to_lower() if source != null else ""
			var token := "%s %s %s" % [str(mesh.name).to_lower(), surface_name, material_name]
			if not prebaked_identity:
				mesh.set_surface_override_material(index, _identity_material(
					source,
					_color_for(token, role, profile),
					role_is_monster_role(role),
					_wash_strength(token, role)
				))
			elif not role_is_monster_role(role) and not bool(root.get_meta("character_authored_silhouette", false)):
				_apply_regional_cloth(mesh, index, source, profile)
			surfaces += 1
			if token.contains("head") or token.contains("skin") or token.contains("eyes") or token.contains("hair") or token.contains("skull") or token.contains("jaw") or token.contains("mouth") or token.contains("teeth"):
				face_surfaces += 1
	root.set_meta("character_identity_profile", role)
	root.set_meta("character_variant_seed", resolved_seed)
	root.set_meta("character_variant_recipe", recipe)
	if not cast.is_empty():
		root.set_meta("story_cast_identity", str(cast.id))
		root.set_meta("story_cast_profile", cast)
	root.set_meta("character_identity_surfaces", surfaces)
	root.set_meta("character_identity_material_mode", "prebaked_atlas" if prebaked_identity else "runtime_palette")
	root.set_meta("character_palette", {"region":str(profile.region), "identity":str(profile.id), "accent":profile.get("accent", null)})
	# Identity is now carried by the imported mesh materials. Earlier passes
	# attached jaw, hair, eye and clothing primitives to the skeleton; those
	# features were the source of the visible neck hump and could drift during
	# animation. Keep the contract data-only until a role has native face meshes.
	var native_face := _has_native_face_material(root)
	# The retained Skeleton family is a connected, single-surface skinned
	# creature. Its head is part of that authored surface rather than a
	# separately named face mesh, so record the real native surface count instead
	# of treating the absence of a second surface as missing anatomy.
	if native_face and face_surfaces == 0 and (role_is_monster_role(role) or _contains_complete_family(root)):
		face_surfaces = _native_monster_surface_count(root)
		root.set_meta("character_face_surface_contract", "single_connected_skinned_mesh")
	root.set_meta("character_face_surfaces", face_surfaces)
	root.set_meta("character_face_features", "native_mesh" if native_face else "missing_native_face")
	if role_is_monster_role(role) and native_face and face_surfaces > 0:
		root.set_meta("character_face_surface_contract", "single_connected_skinned_mesh")
	if _find_skeleton(root) != null and native_face:
		var face_driver := root.find_child("CharacterFaceDriver", true, false)
		if face_driver == null:
			face_driver = CharacterFaceDriver.new()
			face_driver.name = "CharacterFaceDriver"
			root.add_child(face_driver)
		face_driver.configure(root as Node3D, role)
		face_driver.set_expression(str(cast.get("expression", "neutral")))
		root.set_meta("character_face_contract", face_driver.get_contract_report())
	return {"role": role, "surfaces": surfaces, "face_surfaces": face_surfaces}

static func _contains_prebaked_identity(root: Node) -> bool:
	if bool(root.get_meta("character_prebaked_identity", false)):
		return true
	for child in root.get_children():
		if _contains_prebaked_identity(child):
			return true
	return false

static func _has_native_face_material(root: Node) -> bool:
	var matches := 0
	var approved_complete_family := _contains_complete_family(root)
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var token := str(mesh.name).to_lower()
		if token.contains("head") or token.contains("face") or token.contains("eye") or token.contains("hair") or token.contains("skin"):
			matches += 1
		elif approved_complete_family and (mesh.skin != null or mesh.skeleton != NodePath("")) and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			# Monk and Ranger bodies intentionally keep facial anatomy in the
			# connected skinned body mesh instead of a separate Head node. These
			# families are accepted only after the complete-body asset contract has
			# already validated their skeleton, materials, and normalized bounds.
			matches += 1
		elif role_is_monster(root) and (mesh.skin != null or mesh.skeleton != NodePath("")) and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			matches += 1
	return matches >= 1

static func _native_monster_surface_count(root: Node) -> int:
	var count := 0
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or str(mesh.name).to_lower().contains("shadow"):
			continue
		if mesh.skin == null and mesh.skeleton == NodePath(""):
			continue
		for index in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_surface_override_material(index)
			if material == null:
				material = mesh.mesh.surface_get_material(index)
			if material != null:
				count += 1
	return count

static func _contains_complete_family(root: Node) -> bool:
	if str(root.get_meta("character_asset_family", "")) in ["quaternius_animated_humanoid", "quaternius_ranger", "ashen_design_pack_monster"]:
		return true
	for child in root.get_children():
		if _contains_complete_family(child):
			return true
	return false

static func role_is_monster(root: Node) -> bool:
	return str(root.get_meta("character_identity_profile", "")) in MONSTER_ROLES

static func _profile_for(role: String, variant_seed: String = "") -> Dictionary:
	return CharacterPalette.colors(role, variant_seed)

static func _apply_regional_cloth(mesh: MeshInstance3D, surface: int, source: Material, palette: Dictionary) -> void:
	if str(palette.id) in ["kael", "anwen"]:
		return
	if source is ShaderMaterial and (source as ShaderMaterial).shader == RegionShader:
		return
	if not source is StandardMaterial3D:
		return
	var original := source as StandardMaterial3D
	var texture := original.albedo_texture
	if texture == null or not texture.resource_path.get_file().contains("_Atlas"):
		return
	var key := var_to_str([texture, original.albedo_color, palette.primary])
	if not _regional_materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = RegionShader
		material.set_shader_parameter("authored_atlas", texture)
		material.set_shader_parameter("authored_tint", original.albedo_color)
		material.set_shader_parameter("regional_cloth", palette.primary)
		_regional_materials[key] = material
	mesh.set_surface_override_material(surface, _regional_materials[key])

static func _stable_seed(value: String) -> int:
	var result := 17
	for index in range(value.length()):
		result = abs((result * 31 + value.unicode_at(index)) % 2147483647)
	return result

static func _recipe_for(role: String, profile: Dictionary, variant_seed: String = "") -> Dictionary:
	var female := role.contains("female") or role.contains("anwen") or role.contains("mira") or role.contains("widow") or role.contains("servant")
	var skin: Color = profile.get("skin", Color.WHITE)
	var hair: Color = profile.get("hair", Color.WHITE)
	var primary: Color = profile.get("primary", Color.WHITE)
	var seed := _stable_seed(variant_seed if not variant_seed.is_empty() else role)
	var hair_styles := ["parted", "cropped", "tied", "braided"]
	var builds := ["slender", "steady", "broad", "rangy"]
	var clothing_styles := ["worker", "traveler", "guard", "pilgrim"]
	return {
		"body_family": "universal_female" if female else "universal_male",
		"complexion": skin.to_html(false),
		"hair_tint": hair.to_html(false),
		"clothing_tint": primary.to_html(false),
		"hair_style": hair_styles[seed % hair_styles.size()],
		"body_build": builds[int(seed / 3) % builds.size()],
		"clothing_style": clothing_styles[int(seed / 7) % clothing_styles.size()]
	}

static func _wash_strength(token: String, role: String) -> float:
	if role_is_monster_role(role):
		return 0.42
	# Imported Universal textures are shared and bright. The previous single
	# 10% wash made every crowd member read as the same white-haired mannequin.
	# Semantic washes keep the source texture detail while making each stable
	# recipe visible at gameplay distance.
	if token.contains("hair"):
		return 0.64
	if token.contains("eyes") or token.contains("eyebrow"):
		return 0.78
	if token.contains("skin") or token.contains("head"):
		return 0.26
	if token.contains("shirt") or token.contains("pants") or token.contains("green") or token.contains("cloth") or token.contains("leather") or token.contains("brown") or token.contains("white"):
		return 0.34
	return 0.24

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

static var _palette_materials: Dictionary = {}
static var _regional_materials: Dictionary = {}

static func clear_material_cache() -> void:
	_palette_materials.clear()
	_regional_materials.clear()

static func _identity_material(source, color: Color, monster := false, wash_override: float = -1.0) -> StandardMaterial3D:
	var source_key: Variant = source if source is Material else "untextured"
	var variants: Dictionary = _palette_materials.get(source_key, {})
	var recipe := var_to_str([color, monster, wash_override])
	# Boss phase/flash materials stay private. Human identity washes are immutable.
	if not monster and variants.has(recipe):
		return variants[recipe]
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
		if wash_override >= 0.0:
			wash = wash_override
		material.albedo_color = Color.WHITE.lerp(color, wash)
	else:
		material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.04 if color.get_luminance() > 0.42 else 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not monster:
		variants[recipe] = material
		_palette_materials[source_key] = variants
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
