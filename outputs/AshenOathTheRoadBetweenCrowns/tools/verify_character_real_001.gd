extends SceneTree

const CharacterRoleSpec = preload("res://scripts/character_role_spec.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const EXPECTED := {
	"player_human":"res://assets_external/characters_universal/Male_Peasant.gltf",
	"sister_anwen_human":"res://assets_external/characters_universal/Female_Peasant.gltf",
	"villager_human":"res://assets_external/characters_universal/Male_Peasant.gltf",
	"villager_female_human":"res://assets_external/characters_universal/Female_Peasant.gltf",
	"castle_guard_human":"res://assets_external/characters_universal/Male_Peasant.gltf",
	"road_ranger_human":"res://assets_external/characters_ranger/Male_Ranger_Runtime.gltf"
}
var failures := 0

func _initialize() -> void:
	var database = load("res://scripts/asset_database.gd").new()
	root.add_child(database)
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	for role in EXPECTED:
		var entry: Dictionary = database.get_visual_asset_for_role(role)
		check(str(entry.get("path", "")) == EXPECTED[role], "%s does not use its calibrated runtime model" % role)
		await _verify_runtime_role(helper, role)
		check(is_equal_approx(CharacterRoleSpec.visual_forward_degrees(role), 180.0), "%s is missing the +Z-to--Z facing calibration" % role)
	for path in [
		"res://assets_external/enemies/Skeleton.fbx",
		"res://assets_external/enemies/Dragon.fbx",
		"res://assets_external/enemies/Wolf.fbx"
	]:
		_verify_scene(path,path.get_file())
	if failures == 0:
		print("CHARACTER-REAL-001 VERIFIER: PASS")
		quit(0)
	else:
		push_error("CHARACTER-REAL-001 VERIFIER: %d failure(s)" % failures)
		quit(1)

func _verify_scene(path: String, label: String) -> void:
	check(ResourceLoader.exists(path),"%s resource missing" % label)
	if not ResourceLoader.exists(path): return
	var scene = load(path)
	check(scene is PackedScene,"%s is not a scene" % label)
	if not (scene is PackedScene): return
	var node = scene.instantiate()
	root.add_child(node)
	check(_find_type(node,"Skeleton3D") != null,"%s has no skeleton" % label)
	check(_find_type(node,"AnimationPlayer") != null,"%s has no animations" % label)
	_verify_skinned_identity(node, label)
	check(not _has_fragment(node,"faceplane") and not _has_fragment(node,"facialidentity"),"%s contains proxy/billboard anatomy" % label)
	node.queue_free()

func _verify_runtime_role(helper: Node, role: String) -> void:
	var path: String = EXPECTED[role]
	check(FileAccess.file_exists(path) or ResourceLoader.exists(path), "%s runtime source is missing" % role)
	var visual: Node3D = helper.spawn_visual_role(role, "characters")
	check(visual != null, "%s did not instantiate through AssetSpawnHelper" % role)
	if visual == null:
		return
	root.add_child(visual)
	await process_frame
	_verify_skinned_identity(visual, role)
	check(_find_type(visual, "AnimationPlayer") != null, "%s shared animation library was not attached" % role)
	check(not _has_fragment(visual, "faceplane") and not _has_fragment(visual, "facialidentity"), "%s contains proxy/billboard anatomy" % role)
	visual.queue_free()

func _verify_skinned_identity(node: Node, label: String) -> void:
	var skeleton := _find_type(node, "Skeleton3D")
	check(skeleton != null, "%s has no Skeleton3D" % label)
	var player := _find_type(node, "AnimationPlayer")
	check(player != null, "%s has no AnimationPlayer" % label)
	var skinned_count := 0
	var material_count := 0
	var combined := AABB()
	var has_bounds := false
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if mesh_instance.skin != null:
			skinned_count += 1
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(surface_index) != null or mesh_instance.get_surface_override_material(surface_index) != null:
				material_count += 1
		# Imported FBX/GLTF scenes frequently keep the authored size on the
		# MeshInstance transform while the mesh resource itself is tiny. Measure
		# the rendered bounds in the verifier's scene space, just like runtime
		# grounding does, instead of rejecting a valid imported character.
		var bounds := _transformed_aabb(mesh_instance)
		if not has_bounds:
			combined = bounds
			has_bounds = true
		else:
			combined = combined.merge(bounds)
	check(skinned_count > 0, "%s has no skinned body mesh" % label)
	check(material_count > 0, "%s has no imported surface materials" % label)
	check(has_bounds and combined.size.y > 0.9 and combined.size.x > 0.2 and combined.size.z > 0.2, "%s does not have a complete grounded body bound" % label)

func _transformed_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local_box := mesh_instance.mesh.get_aabb()
	var world_box := AABB()
	var initialized := false
	for corner_index in range(8):
		var corner := Vector3(
			local_box.position.x + (local_box.size.x if corner_index & 1 else 0.0),
			local_box.position.y + (local_box.size.y if corner_index & 2 else 0.0),
			local_box.position.z + (local_box.size.z if corner_index & 4 else 0.0)
		)
		var transformed := mesh_instance.global_transform * corner
		if not initialized:
			world_box = AABB(transformed, Vector3.ZERO)
			initialized = true
		else:
			world_box = world_box.expand(transformed)
	return world_box

func _verify_consolidated_anatomy(node: Node, label: String) -> void:
	var skinned_mesh: MeshInstance3D
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.skin != null:
			skinned_mesh = mesh_instance
			break
	check(skinned_mesh != null, "%s has no skinned body mesh" % label)
	if skinned_mesh == null or skinned_mesh.mesh == null:
		return
	var surface_bounds := {}
	for surface_index in range(skinned_mesh.mesh.get_surface_count()):
		var material := skinned_mesh.mesh.surface_get_material(surface_index)
		var material_name := str(material.resource_name if material != null else "").to_lower()
		var arrays := skinned_mesh.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var bounds := AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			bounds = bounds.expand(vertex)
		surface_bounds[material_name.get_slice(".", 0)] = bounds
	for required_material in ["skin", "eyewhite", "eyes", "lips", "leather"]:
		check(surface_bounds.has(required_material), "%s lacks %s anatomy material" % [label, required_material])
	if not surface_bounds.has("skin") or not surface_bounds.has("leather"):
		return
	var skin: AABB = surface_bounds.skin
	var leather: AABB = surface_bounds.leather
	check(skin.end.y >= 1.75 and skin.end.z >= 0.15, "%s lacks modeled head and nose depth" % label)
	check(skin.size.x >= 1.4, "%s lacks complete modeled hands" % label)
	check(leather.position.y <= 0.06 and leather.end.z >= 0.24, "%s lacks grounded modeled feet" % label)
	if surface_bounds.has("eyes"):
		var eyes: AABB = surface_bounds.eyes
		check(eyes.end.y >= 1.68 and eyes.size.x >= 0.10, "%s eye geometry is not positioned on the face" % label)

func _find_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name: return node
	for child in node.get_children():
		var found := _find_type(child,type_name)
		if found != null: return found
	return null

func _has_fragment(node: Node, fragment: String) -> bool:
	if str(node.name).to_lower().contains(fragment): return true
	for child in node.get_children():
		if _has_fragment(child,fragment): return true
	return false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
