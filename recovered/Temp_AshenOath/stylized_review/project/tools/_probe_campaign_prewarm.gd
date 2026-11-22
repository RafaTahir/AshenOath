extends SceneTree

const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")

const ROLES := [
	"castle_wall", "castle_arch", "castle_roof", "castle_bookcase",
	"castle_chair", "castle_bench", "castle_table", "castle_weapon_stand",
	"castle_lantern",
]

func _initialize() -> void:
	var helper := AssetSpawnHelper.new()
	root.add_child(helper)
	await process_frame
	for role in ROLES:
		var started := Time.get_ticks_usec()
		var result: Dictionary = helper.prewarm_roles([role])
		print("PREWARM role=%s ms=%.1f result=%s cache=%s" % [
			role, float(Time.get_ticks_usec() - started) / 1000.0,
			result, helper.cache_stats(),
		])
	print("PREWARM PROBE: PASS")
	quit(0)
