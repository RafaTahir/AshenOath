extends SceneTree

const AssetDatabaseScript = preload("res://scripts/asset_database.gd")
const AssetSpawnHelperScript = preload("res://scripts/asset_spawn_helper.gd")

var failures := 0

func _initialize() -> void:
	var database = AssetDatabaseScript.new()
	root.add_child(database)
	var helper = AssetSpawnHelperScript.new()
	root.add_child(helper)
	await process_frame
	helper.setup(database)
	var groups := {
		"characters": ["player_kael", "sister_anwen", "mira_herbalist", "rook_smuggler", "generic_villager_01", "castle_guard", "road_ranger"],
		"enemies": ["ghoulkin_skeleton", "bog_wretch", "gravebound_knight", "white_hart_avatar", "bandit"],
		"environment": ["greyfen_house", "tavern", "shrine", "blacksmith_shop", "forest_tree", "forest_rock", "forest_bush", "ruins_pillar", "barrel", "crate", "cart", "fence", "torch"]
	}
	for group in groups:
		for role in groups[group]:
			await verify_spawn(helper, database, role, group)
	var curated_paths := {}
	for group in database.role_mapping.get("roles", {}):
		for entry in database.role_mapping["roles"][group].values():
			curated_paths[str(entry.get("path", ""))] = true
	for role in ["player_human", "sister_anwen_human", "mira_human", "rook_human", "villager_human", "villager_female_human", "castle_guard_human", "road_ranger_human"]:
		var entry: Dictionary = database.get_visual_asset_for_role(role)
		var path := str(entry.get("path", ""))
		check(path != "" and curated_paths.has(path), "Visual role is outside the curated library: %s -> %s" % [role, path])
	print("ASSET-001 INSTANTIATION VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func verify_spawn(helper: Node, database: Node, role: String, group: String) -> void:
	var entry: Dictionary = database.get_asset_for_role(role)
	check(str(entry.get("status", "")) != "placeholder", "Curated role resolves to placeholder: %s" % role)
	var node = helper.spawn_for_role(role, group)
	check(node is Node3D and not node.name.ends_with("_placeholder"), "Curated role cannot instantiate: %s" % role)
	if not node is Node3D:
		return
	root.add_child(node)
	await process_frame
	check(node.find_children("*", "MeshInstance3D", true, false).size() > 0 or node is MeshInstance3D, "Curated role has no visible mesh: %s" % role)
	if group == "characters" or role == "ghoulkin_skeleton":
		check(node.find_children("*", "Skeleton3D", true, false).size() > 0, "Animated role has no Skeleton3D: %s" % role)
	node.queue_free()
	await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
