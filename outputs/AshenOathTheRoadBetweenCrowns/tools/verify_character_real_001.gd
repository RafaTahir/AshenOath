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
		for fragment in ["head","eye","nose","hand","foot"]:
			check(_has_fragment(node,fragment),"%s lacks modeled %s geometry" % [label,fragment])
	else:
		check(_has_fragment(node,"head") or _has_fragment(node,"female") or _has_fragment(node,"rogue"),"%s lacks modeled facial geometry" % label)
		check(_has_fragment(node,"body") or _has_fragment(node,"female") or _has_fragment(node,"rogue"),"%s lacks a cohesive body mesh" % label)
	check(not _has_fragment(node,"faceplane") and not _has_fragment(node,"facialidentity"),"%s contains proxy/billboard anatomy" % label)
	node.queue_free()

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
