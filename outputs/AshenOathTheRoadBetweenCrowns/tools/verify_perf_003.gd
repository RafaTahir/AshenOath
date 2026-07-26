extends SceneTree

const SettingsManager = preload("res://scripts/settings_manager.gd")

const MONSTER_ASSETS := [
	"res://assets_external/characters_real/GhoulGaunt_Real.glb",
	"res://assets_external/characters_real/GhoulStalker_Real.glb",
	"res://assets_external/characters_real/GhoulBrute_Real.glb",
]

var failures := 0

func _initialize() -> void:
	var settings := SettingsManager.new()
	settings.name = "PerformanceSettings"
	root.add_child(settings)
	await process_frame
	settings.loaded_user_settings = false
	settings.apply_platform_defaults(true)
	check(str(settings.settings.quality_preset) == "potato", "First-run touch devices do not select the safe mobile preset")
	check(is_equal_approx(float(settings.settings.resolution_scale), 1.0), "Mobile preset left the native ANGLE-safe render scale")
	check(int(settings.settings.shadow_quality) == 0, "Mobile preset enables dynamic shadows")
	check(int(settings.settings.foliage_density) == 0, "Mobile preset exceeds the foliage budget")
	settings.loaded_user_settings = true
	settings.set_quality_preset("balanced")
	settings.apply_platform_defaults(true)
	check(str(settings.settings.quality_preset) == "balanced", "Platform defaults overwrite an existing user choice")
	for path in MONSTER_ASSETS:
		var scene := load(path) as PackedScene
		check(scene != null, "Optimized monster asset is missing: %s" % path)
		if scene == null:
			continue
		var actor := scene.instantiate()
		root.add_child(actor)
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		var skinned_meshes: Array[MeshInstance3D] = []
		for raw_mesh in meshes:
			var mesh := raw_mesh as MeshInstance3D
			if mesh.skin != null:
				skinned_meshes.append(mesh)
		check(skinned_meshes.size() == 1, "%s has %d skinned render bodies instead of one" % [path.get_file(), skinned_meshes.size()])
		check(skeletons.size() == 1, "%s lost its animation skeleton" % path.get_file())
		if not skinned_meshes.is_empty():
			var mesh := skinned_meshes[0]
			check(mesh.skin != null, "%s consolidated mesh is not skinned" % path.get_file())
			check(mesh.mesh != null and mesh.mesh.get_surface_count() <= 6, "%s exceeds the six-surface monster budget" % path.get_file())
		actor.queue_free()
	await process_frame
	print("PERF-003 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
