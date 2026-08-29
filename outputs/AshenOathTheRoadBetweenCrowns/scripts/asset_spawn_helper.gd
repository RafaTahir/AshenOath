extends Node

const AssetDatabase = preload("res://scripts/asset_database.gd")
const CharacterVisualContract = preload("res://scripts/character_visual_contract.gd")
const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const CharacterRoleContract = preload("res://scripts/character_role_contract.gd")
const CharacterAnimationFusion = preload("res://scripts/character_animation_fusion.gd")

var database
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var resource_cache: Dictionary = {}

func clear_runtime_caches() -> void:
	# Cache ownership ends with the host game. Clear references after the
	# owning scene roots have been retired so imported resources can release
	# without detaching live meshes from the renderer.
	mesh_cache.clear()
	material_cache.clear()
	resource_cache.clear()

func _ready() -> void:
	if database == null:
		database = AssetDatabase.new()
		add_child(database)

func setup(asset_database) -> void:
	database = asset_database
	if database != null and database.has_method("reload"):
		database.reload()

func spawn_for_role(role_name: String, fallback_category: String = "props") -> Node3D:
	_ensure_database()
	var entry: Dictionary = database.get_asset_for_role(role_name)
	return _spawn_from_entry(entry, role_name, fallback_category)

func spawn_visual_role(role_name: String, fallback_category: String = "props") -> Node3D:
	_ensure_database()
	if not database.has_method("get_visual_asset_for_role"):
		return null
	var entry: Dictionary = database.get_visual_asset_for_role(role_name)
	return _spawn_from_entry(entry, role_name, fallback_category)

func has_visual_role(role_name: String) -> bool:
	_ensure_database()
	if not database.has_method("has_visual_asset_for_role"):
		return false
	return database.has_visual_asset_for_role(role_name)

func _spawn_from_entry(entry: Dictionary, role_name: String, fallback_category: String) -> Node3D:
	var path: String = str(entry.get("path", ""))
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var resource = _load_cached_resource(path)
		var spawned: Node3D = _instantiate_resource(resource)
		if spawned != null:
			spawned = _compose_player_body(spawned, path, role_name)
			spawned.name = role_name
			_prepare_spawned_asset(spawned,path,role_name,fallback_category)
			return spawned
		var fallback: Node3D = _instantiate_source_file(path)
		if fallback != null:
			fallback = _compose_player_body(fallback, path, role_name)
			fallback.name = role_name
			_prepare_spawned_asset(fallback,path,role_name,fallback_category)
			return fallback
	push_warning("Using primitive placeholder for asset role: %s" % role_name)
	return _placeholder(role_name, fallback_category)

func _compose_player_body(outfit_root: Node3D, outfit_path: String, role_name: String) -> Node3D:
	var normalized_path := outfit_path.replace("\\", "/").to_lower()
	var is_ranger_runtime := normalized_path.contains("assets_external/characters_ranger/") and normalized_path.ends_with("male_ranger_runtime.gltf")
	if is_ranger_runtime:
		# Ranger is already a complete skinned Quaternius-compatible body. Mark it
		# as a single authored layer so the character gates and runtime diagnostics
		# do not confuse it with the retired multi-GLTF composite path.
		outfit_root.set_meta("character_composite", true)
		outfit_root.set_meta("character_rig_layer_count", 1)
		outfit_root.set_meta("character_identity", role_name.to_lower())
		outfit_root.set_meta("character_base_path", outfit_path)
		outfit_root.set_meta("character_outfit_path", outfit_path)
		outfit_root.set_meta("character_asset_family", "quaternius_ranger")
		outfit_root.set_meta("character_animation_family", "universal_animation_library_2")
		return outfit_root
	var is_fullbody_male := normalized_path.ends_with("superhero_male_fullbody.gltf")
	var is_fullbody_female := normalized_path.ends_with("superhero_female_fullbody.gltf")
	if is_fullbody_male or is_fullbody_female:
		# These sources already contain one connected head, body, hair and
		# skeleton. Wrap the imported scene only to keep the existing character
		# composition contract stable; do not add a second head or costume layer.
		var composite := Node3D.new()
		composite.name = "%sCompleteHumanoid" % ("Male" if is_fullbody_male else "Female")
		composite.add_child(outfit_root)
		composite.set_meta("character_composite", true)
		composite.set_meta("character_rig_layer_count", 1)
		composite.set_meta("character_identity", "unified_male" if is_fullbody_male else "unified_female")
		composite.set_meta("character_base_path", outfit_path)
		composite.set_meta("character_outfit_path", outfit_path)
		return composite
	var is_kael := role_name in ["player_human", "player_kael"] and normalized_path.ends_with("male_peasant.gltf")
	var is_anwen := role_name in ["sister_anwen_human", "sister_anwen"] and normalized_path.ends_with("female_peasant.gltf")
	var is_shared_male := normalized_path.ends_with("male_peasant.gltf")
	var is_shared_female := normalized_path.ends_with("female_peasant.gltf")
	if not is_kael and not is_anwen and not is_shared_male and not is_shared_female:
		return outfit_root
	var base_path := "res://assets_external/characters_universal/Male_Head.gltf" if (is_kael or is_shared_male) else "res://assets_external/characters_universal/Female_Head.gltf"
	var base := _instantiate_resource(_load_cached_resource(base_path))
	if base == null:
		return outfit_root
	var hair_path := _hair_path_for_role(role_name, is_shared_male)
	var hair := _instantiate_resource(_load_cached_resource(hair_path))
	var composite := Node3D.new()
	var label := "Kael" if is_kael else ("Anwen" if is_anwen else role_name.capitalize())
	composite.name = "%sSharedHumanoidComposite" % label
	base.name = "%sNativeHead" % label
	outfit_root.name = "%sPeasantOutfit" % label
	composite.add_child(base)
	composite.add_child(outfit_root)
	if hair != null:
		hair.name = "%sNativeHair" % label
		composite.add_child(hair)
	var merged_layers := _merge_shared_rig_layers(outfit_root, [base, hair])
	composite.set_meta("character_composite", true)
	composite.set_meta("character_rig_layer_count", 1 if merged_layers else 3)
	composite.set_meta("character_identity", "kael" if is_kael else role_name.to_lower())
	composite.set_meta("character_base_path", base_path)
	composite.set_meta("character_outfit_path", outfit_path)
	composite.set_meta("character_hair_path", hair_path)
	# Universal body/head/hair layers are merged onto one shared skeleton. Keep
	# the family marker on the composite root so all runtime and QA contracts
	# inspect the same authored source instead of mistaking it for a legacy
	# direct-body mapping.
	composite.set_meta("character_asset_family", "quaternius_animated_humanoid")
	composite.set_meta("character_animation_family", "universal_animation_library_2")
	return composite

func _merge_shared_rig_layers(outfit_root: Node3D, layers: Array) -> bool:
	var shared_skeleton := _find_skeleton(outfit_root)
	if shared_skeleton == null:
		return false
	for layer in layers:
		if layer == null:
			continue
		var layer_skeleton := _find_skeleton(layer)
		if layer_skeleton == null or not _skeletons_match(shared_skeleton, layer_skeleton):
			return false
	for layer in layers:
		if layer == null:
			continue
		var layer_node := layer as Node
		var meshes: Array[Node] = layer_node.find_children("*", "MeshInstance3D", true, false)
		for raw_mesh in meshes:
			var mesh := raw_mesh as MeshInstance3D
			mesh.owner = null
			mesh.reparent(shared_skeleton, false)
			mesh.skeleton = NodePath("..")
		layer_node.free()
	return true

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _skeletons_match(first: Skeleton3D, second: Skeleton3D) -> bool:
	if first.get_bone_count() != second.get_bone_count():
		return false
	for index in range(first.get_bone_count()):
		if first.get_bone_name(index) != second.get_bone_name(index):
			return false
	return true

func _hair_path_for_role(role_name: String, male: bool) -> String:
	var role := role_name.to_lower()
	if role in ["sister_anwen_human", "sister_anwen"] or not male:
		return "res://assets_external/characters_universal/Hair_Buns.gltf"
	if role.contains("hooded") or role.contains("ranger") or role.contains("patrol") or role.contains("guard"):
		return "res://assets_external/characters_universal/Hair_Buzzed.gltf"
	return "res://assets_external/characters_universal/Hair_SimpleParted.gltf"

func spawn_character(role_name: String) -> Node3D:
	return spawn_for_role(role_name, "characters")

func spawn_enemy(role_name: String) -> Node3D:
	return spawn_for_role(role_name, "enemies")

func spawn_prop(role_name: String) -> Node3D:
	return spawn_for_role(role_name, "props")

func spawn_environment(role_name: String) -> Node3D:
	return spawn_for_role(role_name, "environment")

func _ensure_database() -> void:
	if database == null:
		database = AssetDatabase.new()
		add_child(database)
		if database.has_method("reload"):
			database.reload()

func _instantiate_resource(resource) -> Node3D:
	if resource == null:
		return null
	if resource is PackedScene:
		var node = resource.instantiate()
		if node is Node3D:
			return node
		var wrapper = Node3D.new()
		wrapper.add_child(node)
		return wrapper
	if resource is Mesh:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = resource
		return mesh_instance
	return null

func _instantiate_source_file(path: String) -> Node3D:
	var ext: String = path.get_extension().to_lower()
	if ext == "obj":
		return _instantiate_obj(path)
	if ext == "glb" or ext == "gltf" or ext == "fbx" or ext == "dae":
		return _instantiate_resource(_load_cached_resource(path))
	return null

func _load_cached_resource(path: String):
	if resource_cache.has(path):
		return resource_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var resource = ResourceLoader.load(path)
	if resource != null:
		resource_cache[path] = resource
	return resource

func _instantiate_obj(path: String) -> Node3D:
	var mesh: ArrayMesh = _load_obj_mesh(path)
	if mesh == null:
		return null
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _obj_material(path)
	return mesh_instance

func _load_obj_mesh(path: String) -> ArrayMesh:
	if mesh_cache.has(path):
		return mesh_cache[path]
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var source_vertices: Array[Vector3] = []
	var source_uvs: Array[Vector2] = []
	var source_normals: Array[Vector3] = []
	var face_tokens: Array = []
	var min_bounds = Vector3(999999.0, 999999.0, 999999.0)
	var max_bounds = Vector3(-999999.0, -999999.0, -999999.0)
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("v "):
			var parts: PackedStringArray = line.split(" ", false)
			if parts.size() >= 4:
				var vertex = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
				source_vertices.append(vertex)
				min_bounds = Vector3(min(min_bounds.x, vertex.x), min(min_bounds.y, vertex.y), min(min_bounds.z, vertex.z))
				max_bounds = Vector3(max(max_bounds.x, vertex.x), max(max_bounds.y, vertex.y), max(max_bounds.z, vertex.z))
		elif line.begins_with("vt "):
			var uv_parts: PackedStringArray = line.split(" ", false)
			if uv_parts.size() >= 3:
				source_uvs.append(Vector2(float(uv_parts[1]), 1.0 - float(uv_parts[2])))
		elif line.begins_with("vn "):
			var normal_parts: PackedStringArray = line.split(" ", false)
			if normal_parts.size() >= 4:
				source_normals.append(Vector3(float(normal_parts[1]), float(normal_parts[2]), float(normal_parts[3])).normalized())
		elif line.begins_with("f "):
			var parts_face: PackedStringArray = line.split(" ", false)
			var parsed_face: Array = []
			for i: int in range(1, parts_face.size()):
				var token: Dictionary = _parse_face_token(str(parts_face[i]), source_vertices.size(), source_uvs.size(), source_normals.size())
				if int(token.get("v", -1)) >= 0:
					parsed_face.append(token)
			if parsed_face.size() >= 3:
				face_tokens.append(parsed_face)
	if source_vertices.is_empty() or face_tokens.is_empty():
		return null

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	var center = Vector3((min_bounds.x + max_bounds.x) * 0.5, min_bounds.y, (min_bounds.z + max_bounds.z) * 0.5)
	var raw_size: Vector3 = max_bounds - min_bounds
	var longest: float = max(max(raw_size.x, raw_size.y), raw_size.z)
	var target_height: float = _target_height_for_path(path)
	var scale_factor: float = target_height / max(raw_size.y, longest * 0.25, 0.01)
	scale_factor = clamp(scale_factor, 0.01, 8.0)
	for face in face_tokens:
		for i: int in range(1, face.size() - 1):
			var triangle: Array = [face[0], face[i], face[i + 1]]
			var first_index: int = vertices.size()
			for token_dict in triangle:
				var vi: int = int(token_dict.get("v", -1))
				var ti: int = int(token_dict.get("t", -1))
				var ni: int = int(token_dict.get("n", -1))
				var transformed: Vector3 = (source_vertices[vi] - center) * scale_factor
				vertices.append(transformed)
				if ti >= 0 and ti < source_uvs.size():
					uvs.append(source_uvs[ti])
				else:
					uvs.append(Vector2.ZERO)
				if ni >= 0 and ni < source_normals.size():
					normals.append(source_normals[ni])
				else:
					normals.append(Vector3.ZERO)
				indices.append(vertices.size() - 1)
			if normals[first_index] == Vector3.ZERO:
				var a: Vector3 = vertices[first_index]
				var b: Vector3 = vertices[first_index + 1]
				var c: Vector3 = vertices[first_index + 2]
				var normal: Vector3 = (b - a).cross(c - a).normalized()
				normals[first_index] = normal
				normals[first_index + 1] = normal
				normals[first_index + 2] = normal
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_cache[path] = mesh
	return mesh

func _parse_face_token(raw_token: String, vertex_count: int, uv_count: int, normal_count: int) -> Dictionary:
	var values: PackedStringArray = raw_token.split("/")
	var vertex_index: int = _resolve_obj_index(str(values[0]) if values.size() > 0 else "", vertex_count)
	var uv_index: int = _resolve_obj_index(str(values[1]) if values.size() > 1 else "", uv_count)
	var normal_index: int = _resolve_obj_index(str(values[2]) if values.size() > 2 else "", normal_count)
	return {"v": vertex_index, "t": uv_index, "n": normal_index}

func _resolve_obj_index(raw_value: String, count: int) -> int:
	if raw_value == "":
		return -1
	var parsed: int = int(raw_value)
	if parsed < 0:
		return count + parsed
	return parsed - 1

func _target_height_for_path(path: String) -> float:
	var lowered: String = path.to_lower()
	if "characters" in lowered:
		return 1.78
	if "orcskull" in lowered or "skeleton" in lowered:
		return 1.72
	if "dragon" in lowered:
		return 3.80
	if "slime" in lowered:
		return 0.92
	if "wolf" in lowered:
		return 1.08
	if "tree" in lowered:
		return 4.2
	if "cart" in lowered:
		return 1.35
	if "barrel" in lowered:
		return 1.05
	if "crate" in lowered:
		return 0.82
	if "anvil" in lowered:
		return 0.75
	if "rock" in lowered:
		return 0.9
	if "wall" in lowered or "roof" in lowered:
		return 2.0
	return 1.2

func _target_height_for_role(role_name: String, path: String) -> float:
	var role := role_name.to_lower()
	if role != "":
		var known_height := CharacterRoleSpec.target_height(role, -1.0)
		if known_height > 0.0:
			return known_height
	# Large authored focal creatures are normalized to a human-scale source
	# first, then receive their encounter-specific multiplier in the zone
	# builder. This keeps the Wolf source grounded while giving the Hart the
	# intended supernatural height.
	if role == "white_hart_avatar":
		return 1.72
	if role == "ashwing_creature":
		return 3.80
	if role.contains("ghoul_stalker"):
		return 1.66
	if role.contains("ghoul_brute"):
		return 1.90
	if role.contains("ghoul_gaunt") or role.contains("ghoulkin_creature"):
		return 1.72
	if role in ["player_human", "player_kael"]:
		return 1.78
	if role in ["sister_anwen_human", "sister_anwen"]:
		return 1.68
	if role.contains("villager_female") or role in ["mira_human", "mira_herbalist"]:
		return 1.66
	if role.contains("villager_hooded"):
		return 1.69
	if role.contains("villager_worker"):
		return 1.74
	if role.contains("villager"):
		return 1.72
	if role.contains("castle_guard"):
		return 1.82
	if role.contains("road_ranger") or role.contains("rook"):
		return 1.75
	return _target_height_for_path(path)

func _obj_material(path: String) -> StandardMaterial3D:
	if material_cache.has(path):
		return material_cache[path]
	var material = StandardMaterial3D.new()
	var texture_path: String = _find_texture_for_obj(path)
	if texture_path != "":
		var texture: Texture2D = _load_external_texture(texture_path)
		if texture != null:
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE
	else:
		material.albedo_color = _category_color(path)
	material.roughness = 0.82
	material_cache[path] = material
	return material

func _load_external_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		var resource = ResourceLoader.load(texture_path)
		if resource is Texture2D:
			return resource
	var image = Image.new()
	var absolute_path: String = ProjectSettings.globalize_path(texture_path)
	var error: Error = image.load(absolute_path)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)

func _find_texture_for_obj(path: String) -> String:
	var directory: String = path.get_base_dir()
	var base_name: String = path.get_file().get_basename()
	var direct_candidates: Array[String] = [
		"%s/%s_Texture.png" % [directory, base_name],
		"%s/%s.png" % [directory, base_name],
		"%s/%s_Diffuse.png" % [directory, base_name],
		"%s/%s_Albedo.png" % [directory, base_name]
	]
	for candidate: String in direct_candidates:
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			return candidate
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	var lowered_base: String = base_name.to_lower()
	for file_name: String in files:
		var lowered: String = file_name.to_lower()
		if not (lowered.ends_with(".png") or lowered.ends_with(".jpg") or lowered.ends_with(".jpeg")):
			continue
		if lowered.begins_with(lowered_base) and not lowered.contains("normal"):
			return "%s/%s" % [directory, file_name]
	return ""

func _category_color(path: String) -> Color:
	var lowered: String = path.to_lower()
	if "characters" in lowered:
		return Color(0.62, 0.56, 0.48)
	if "enemies" in lowered:
		return Color(0.42, 0.36, 0.30)
	if "forest" in lowered:
		return Color(0.22, 0.36, 0.20)
	if "village" in lowered:
		return Color(0.43, 0.33, 0.24)
	if "props" in lowered:
		return Color(0.38, 0.29, 0.20)
	return Color(0.50, 0.48, 0.43)

func _finalize_asset_root(root: Node3D, role_name: String = "") -> void:
	if role_name != "":
		root.rotation_degrees.y = CharacterRoleSpec.visual_forward_degrees(role_name)
	else:
		root.rotation_degrees.y = 180.0 if root.name.to_lower().contains("character") else root.rotation_degrees.y
	var hero_role := role_name in ["player_human", "player_kael", "sister_anwen_human", "sister_anwen"]
	var focal_creature := role_name in ["white_hart_avatar", "white_hart_boss", "ashwing_creature", "ashwing_boss", "bell_eater_boss", "rootbound_colossus", "rootbound_colossus_boss"]
	var lod_distance := 48.0 if focal_creature else CharacterRoleSpec.lod_distance(role_name, 14.0)
	var lod_bias := 0.50 if hero_role else 0.40
	for mesh_instance in _collect_meshes(root):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.lod_bias = lod_bias
		mesh_instance.visibility_range_end = lod_distance
	root.set_meta("character_role_spec", CharacterRoleSpec.for_role(role_name))
	root.set_meta("source_forward_positive_z", role_name in [
		"player_human", "player_kael", "sister_anwen", "sister_anwen_human",
		"mira_human", "rook_human", "villager_human", "villager_female_human",
		"villager_worker_human", "villager_hooded_human", "castle_guard_human",
		"road_ranger_human"
	])

func _prepare_spawned_asset(root: Node3D, path: String, role_name: String = "", category: String = "") -> void:
	if path.get_extension().to_lower() != "obj":
		_normalize_scene_bounds(root, _target_height_for_role(role_name, path))
	_apply_safe_materials(root, path)
	_finalize_asset_root(root, role_name)
	if CharacterAnimationFusion.is_shared_body(path):
		var fused_player := CharacterAnimationFusion.attach_shared_library(root)
		root.set_meta("shared_animation_library", fused_player != null and fused_player.get_animation_list().size() > 0)
	if "characters" in path.to_lower() and not _has_skeleton(root):
		_apply_character_wrapper(root, root.name)
	if category in ["characters","enemies"] and _has_skeleton(root):
		var report := CharacterVisualContract.validate(root,true)
		root.set_meta("character_visual_contract",report)
		root.set_meta("character_visual_role",role_name)
		root.set_meta("character_role_contract", CharacterRoleContract.inspect(root, role_name))
		if not bool(report.valid):
			push_error("Incomplete skeletal visual for %s: %s" % [role_name,str(report)])

func _has_skeleton(root: Node) -> bool:
	if root is Skeleton3D:
		return true
	for child in root.get_children():
		if _has_skeleton(child):
			return true
	return false

func _apply_safe_materials(root: Node3D, path: String) -> void:
	var fallback = _fallback_material_for_path(path)
	for mesh_instance in _collect_meshes(root):
		if mesh_instance.mesh == null:
			continue
		if mesh_instance.mesh.get_surface_count() == 0:
			mesh_instance.material_override = fallback
		else:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.mesh.surface_get_material(surface_index) == null:
					mesh_instance.mesh.surface_set_material(surface_index, fallback)
				var effective := mesh_instance.get_surface_override_material(surface_index)
				if effective == null:
					effective = mesh_instance.mesh.surface_get_material(surface_index)
				if effective == null or _is_default_white_material(effective):
					var replacement := mesh_instance.material_override
					if replacement == null or _is_default_white_material(replacement):
						replacement = fallback
					mesh_instance.set_surface_override_material(surface_index, replacement)
		if mesh_instance.material_override != null and _is_default_white_material(mesh_instance.material_override):
			mesh_instance.material_override = fallback
		mesh_instance.set_meta("validated_material", true)

func cache_stats() -> Dictionary:
	return {
		"meshes": mesh_cache.size(),
		"materials": material_cache.size(),
		"resources": resource_cache.size(),
	}

func _needs_fallback_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override != null:
		return _is_default_white_material(mesh_instance.material_override)
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return true
	var saw_material = false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		saw_material = true
		if not _is_default_white_material(material):
			return false
	return true if not saw_material else true

func _is_default_white_material(material: Material) -> bool:
	if material is StandardMaterial3D:
		var standard = material as StandardMaterial3D
		if standard.albedo_texture != null:
			return false
		var color = standard.albedo_color
		return color.r > 0.86 and color.g > 0.86 and color.b > 0.86
	return false

func _fallback_material_for_path(path: String) -> StandardMaterial3D:
	var key = "fallback:%s" % path
	if material_cache.has(key):
		return material_cache[key]
	var lowered = path.to_lower()
	var color = Color(0.30, 0.28, 0.24)
	var roughness = 0.88
	var metallic = 0.0
	var texture_path = _find_texture_for_obj(path)
	if texture_path != "":
		var textured = StandardMaterial3D.new()
		var texture = _load_external_texture(texture_path)
		if texture != null:
			textured.albedo_texture = texture
			textured.albedo_color = _tint_for_path(lowered)
			textured.roughness = 0.84
			material_cache[key] = textured
			return textured
	if "tree" in lowered or "bush" in lowered or "forest" in lowered:
		color = Color(0.16, 0.28, 0.13) if ("tree" in lowered or "bush" in lowered) else Color(0.20, 0.24, 0.18)
	elif "rock" in lowered or "stone" in lowered or "wall" in lowered or "arch" in lowered:
		color = Color(0.30, 0.30, 0.27)
	elif "roof" in lowered:
		color = Color(0.18, 0.11, 0.065)
	elif "wood" in lowered or "barrel" in lowered or "crate" in lowered or "cart" in lowered or "fence" in lowered:
		color = Color(0.26, 0.16, 0.085)
	elif "torch" in lowered:
		color = Color(0.16, 0.12, 0.09)
		metallic = 0.15
	elif "anvil" in lowered or "metal" in lowered:
		color = Color(0.30, 0.29, 0.27)
		metallic = 0.35
		roughness = 0.64
	elif "skeleton" in lowered or "bone" in lowered:
		color = Color(0.58, 0.52, 0.42)
	elif "slime" in lowered or "wolf" in lowered or "enemies" in lowered:
		color = Color(0.22, 0.17, 0.13)
	elif "universal" in lowered:
		color = Color(0.24, 0.22, 0.19)
	elif "characters" in lowered:
		color = Color(0.25, 0.24, 0.20)
	var material = _mat_with_roughness(color, roughness)
	material.metallic = metallic
	material_cache[key] = material
	return material

func _tint_for_path(lowered_path: String) -> Color:
	if "universal" in lowered_path:
		return Color(0.88, 0.84, 0.76)
	return Color(0.82, 0.80, 0.74)

func _normalize_scene_bounds(root: Node3D, target_height: float) -> void:
	if bool(root.get_meta("character_normalized", false)):
		# A source may be composed from several shared-rig layers, but the
		# resulting root is normalized exactly once after composition.
		return
	var bounds: AABB = _calculate_node_bounds(root)
	if bounds.size == Vector3.ZERO:
		return
	var height: float = max(bounds.size.y, 0.01)
	var longest: float = max(max(bounds.size.x, bounds.size.y), bounds.size.z)
	var scale_basis := height
	# Character bounds are measured from the complete skinned body. The
	# longest-axis fallback is only for non-character imported props, where a
	# malformed source origin can otherwise create a paper-thin result.
	if not _has_skeleton(root):
		scale_basis = max(height, longest * 0.25)
	var scale_factor: float = target_height / max(scale_basis, 0.01)
	scale_factor = clamp(scale_factor, 0.01, 8.0)
	var center_xz = Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y, bounds.position.z + bounds.size.z * 0.5)
	root.scale *= scale_factor
	root.position -= center_xz * scale_factor
	root.set_meta("character_normalized", true)
	root.set_meta("normalized_target_height", target_height)
	root.set_meta("normalized_scale", root.scale)
	root.set_meta("normalized_position", root.position)
	CharacterRoleContract.mark_normalized(root, bounds, target_height, scale_factor)

func apply_normalized_scale(root: Node3D, multiplier: float) -> void:
	if root == null:
		return
	if bool(root.get_meta("character_role_scale_applied", false)):
		return
	var base_scale: Vector3 = root.get_meta("normalized_scale", root.scale)
	var role_scale := clampf(multiplier, 0.85, 1.50)
	root.scale = base_scale * role_scale
	root.set_meta("character_role_scale", role_scale)
	root.set_meta("character_role_scale_applied", true)

func _calculate_node_bounds(root: Node3D) -> AABB:
	var state: Dictionary = {"has_bounds": false, "bounds": AABB()}
	_accumulate_node_bounds(root, Transform3D.IDENTITY, state)
	if bool(state.get("has_bounds", false)):
		return state.get("bounds", AABB())
	return AABB()

func _accumulate_node_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = current_transform * mesh_instance.mesh.get_aabb()
			if bool(state.get("has_bounds", false)):
				state["bounds"] = (state["bounds"] as AABB).merge(mesh_bounds)
			else:
				state["bounds"] = mesh_bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_accumulate_node_bounds(child, current_transform, state)

func _apply_character_wrapper(root: Node3D, role_name: String) -> void:
	# Legacy OBJ wrappers created detached faces, shoulders, hair and weapons.
	# They are intentionally disabled: incomplete roles must be replaced by a
	# shared rig, never cosmetically disguised with root-mounted geometry.
	root.set_meta("character_overlay_contract", "disabled")

func _mat_with_roughness(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		results.append(root)
	for child in root.get_children():
		results.append_array(_collect_meshes(child))
	return results

func _placeholder(role_name: String, category: String) -> Node3D:
	var root = Node3D.new()
	root.name = "%s_placeholder" % role_name
	var mesh = MeshInstance3D.new()
	mesh.mesh = _placeholder_mesh(category)
	mesh.material_override = _placeholder_material(category)
	root.add_child(mesh)
	if category == "characters" or category == "enemies":
		mesh.position.y = 0.9
		var head = MeshInstance3D.new()
		head.mesh = SphereMesh.new()
		head.scale = Vector3(0.28, 0.28, 0.28)
		head.position.y = 1.75
		head.material_override = _placeholder_material(category)
		root.add_child(head)
	return root

func _placeholder_mesh(category: String) -> Mesh:
	if category == "characters" or category == "enemies":
		var capsule = CapsuleMesh.new()
		capsule.height = 1.5
		capsule.radius = 0.34
		return capsule
	var box = BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	return box

func _placeholder_material(category: String) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = {
		"characters": Color(0.25, 0.30, 0.26),
		"enemies": Color(0.38, 0.18, 0.15),
		"environment": Color(0.23, 0.22, 0.20),
		"props": Color(0.30, 0.22, 0.14)
	}
	material.albedo_color = colors.get(category, Color(0.35, 0.35, 0.35))
	material.roughness = 0.9
	return material
