extends SceneTree

const EXPECTED := {
	"player_human":"Adventurer_PolyPizza_Quaternius_CC0.glb",
	"sister_anwen_human":"AnimatedWoman_PolyPizza_Quaternius_CC0.glb",
	"villager_human":"Adventurer_PolyPizza_Quaternius_CC0.glb",
	"villager_female_human":"WomanCasual_PolyPizza_Quaternius_CC0.glb",
	"castle_guard_human":"CharacterAnimated_PolyPizza_Quaternius_CC0.glb",
	"road_ranger_human":"HoodedAdventurer_PolyPizza_Quaternius_CC0.glb"
}
var failures := 0

func _initialize() -> void:
	var database = load("res://scripts/asset_database.gd").new()
	root.add_child(database)
	await process_frame
	for role in EXPECTED:
		var entry: Dictionary = database.get_visual_asset_for_role(role)
		check(str(entry.path).ends_with(EXPECTED[role]),"%s does not use its replacement GLB" % role)
		_verify_scene(str(entry.path),role)
	for path in [
		"res://assets_external/characters_real/GhoulGaunt_Real.glb",
		"res://assets_external/characters_real/GhoulStalker_Real.glb",
		"res://assets_external/characters_real/GhoulBrute_Real.glb"
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
	if path.contains("characters_real"):
		_verify_consolidated_anatomy(node, label)
	else:
		check(_has_fragment(node,"head") or _has_fragment(node,"female") or _has_fragment(node,"rogue"),"%s lacks modeled facial geometry" % label)
		check(_has_fragment(node,"body") or _has_fragment(node,"female") or _has_fragment(node,"rogue"),"%s lacks a cohesive body mesh" % label)
	check(not _has_fragment(node,"faceplane") and not _has_fragment(node,"facialidentity"),"%s contains proxy/billboard anatomy" % label)
	node.queue_free()

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
