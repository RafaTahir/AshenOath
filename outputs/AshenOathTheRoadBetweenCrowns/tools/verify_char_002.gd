extends SceneTree

const AssetDatabase = preload("res://scripts/asset_database.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

const REQUIRED_ROLES := {
	"villager_human": 1.72,
	"villager_female_human": 1.66,
	"villager_worker_human": 1.74,
	"villager_hooded_human": 1.69,
	"castle_guard_human": 1.82,
	"road_ranger_human": 1.75,
}

var failures := 0

func _initialize() -> void:
	var database = AssetDatabase.new()
	var helper = AssetSpawnHelper.new()
	root.add_child(database)
	root.add_child(helper)
	await process_frame
	helper.setup(database)
	var paths: Dictionary = {}
	for role in REQUIRED_ROLES:
		var entry: Dictionary = database.get_visual_asset_for_role(role)
		var path := str(entry.get("path", ""))
		check(ResourceLoader.exists(path), "%s has no loadable model" % role)
		paths[role] = path
		var actor = helper.spawn_visual_role(role, "characters")
		check(actor != null and not actor.name.ends_with("_placeholder"), "%s spawned a placeholder" % role)
		if actor == null:
			continue
		root.add_child(actor)
		check(actor.find_children("*", "Skeleton3D", true, false).size() > 0, "%s has no skeleton" % role)
		check(actor.find_children("*", "AnimationPlayer", true, false).size() > 0, "%s has no animation player" % role)
		check(absf(float(actor.get_meta("normalized_target_height", 0.0)) - float(REQUIRED_ROLES[role])) < 0.02, "%s target height is wrong" % role)
		actor.queue_free()
	check(str(paths.castle_guard_human) != str(paths.road_ranger_human), "Castle guards and road travelers still share one body")
	var crowd_paths := {
		str(paths.villager_human): true,
		str(paths.villager_female_human): true,
		str(paths.villager_worker_human): true,
		str(paths.villager_hooded_human): true,
	}
	check(crowd_paths.size() == 4, "Greyfen crowd does not have four distinct body sources")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://character_role_manifest.json"))
	check(typeof(manifest) == TYPE_DICTIONARY and int(manifest.get("version", 0)) >= 2, "Character role manifest was not upgraded")
	check((manifest as Dictionary).get("role_specs", {}).size() >= 8, "Character role specs are incomplete")
	print("CHAR-002 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
