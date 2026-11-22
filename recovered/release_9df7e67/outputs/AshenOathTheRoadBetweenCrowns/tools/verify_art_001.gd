extends SceneTree

const AssetSpawnHelperScript = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationFusion = preload("res://scripts/character_animation_fusion.gd")

var failures := 0

func _initialize() -> void:
	var file := FileAccess.open("res://art_audition_manifest.json", FileAccess.READ)
	check(file != null, "ART-001 manifest is missing")
	if file == null:
		quit(1)
		return
	var manifest = JSON.parse_string(file.get_as_text())
	check(typeof(manifest) == TYPE_DICTIONARY, "ART-001 manifest is invalid JSON")
	if typeof(manifest) != TYPE_DICTIONARY:
		quit(1)
		return
	check(str(manifest.get("direction", "")) == "grounded_stylized_dark_fantasy", "Visual direction is not locked")
	var expected_decisions := {
		"kael": "selected_for_char_restore_001",
		"sister_anwen": "selected_for_char_restore_001",
		"ghoulkin": "selected_retained_source_for_char_restore_001"
	}
	for role_id in ["kael", "sister_anwen", "ghoulkin"]:
		var role: Dictionary = manifest.get("roles", {}).get(role_id, {})
		check(str(role.get("decision", "")) == expected_decisions[role_id], "%s audition decision is not recorded truthfully" % role_id)
		await verify_character_candidate(role_id, str(role.get("candidate", "")))
	check(str(manifest.get("greyfen", {}).get("decision", "")) == "components_selected_for_asset_001_composition_rejected", "Greyfen component decision is missing")
	var helper := AssetSpawnHelperScript.new()
	root.add_child(helper)
	await process_frame
	for path in manifest.get("greyfen", {}).get("required_assets", []):
		var source_path := str(path)
		check(FileAccess.file_exists(source_path), "Greyfen audition asset file is unavailable: %s" % source_path)
		if FileAccess.file_exists(source_path):
			var instance = helper.call("_instantiate_source_file", source_path)
			check(instance is Node3D, "Greyfen audition asset cannot instantiate: %s" % source_path)
			if instance is Node3D:
				instance.free()
	check(manifest.get("rejected_patterns", []).size() >= 7, "Rejected visual patterns are incomplete")
	print("ART-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func verify_character_candidate(role_id: String, path: String) -> void:
	check(path != "" and ResourceLoader.exists(path), "%s candidate is unavailable: %s" % [role_id, path])
	if path == "" or not ResourceLoader.exists(path):
		return
	var resource = load(path)
	check(resource is PackedScene, "%s candidate is not an imported scene" % role_id)
	if not resource is PackedScene:
		return
	var instance = resource.instantiate()
	root.add_child(instance)
	await process_frame
	check(instance.find_children("*", "Skeleton3D", true, false).size() > 0, "%s candidate has no Skeleton3D" % role_id)
	check(instance.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s candidate has no mesh" % role_id)
	var animation_players: Array = instance.find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		# Universal body and retained monster source files are intentionally mesh-
		# only. The runtime attaches the shared, root-motion-free library before
		# the actor becomes visible; validate that same production path here.
		var fused_player := CharacterAnimationFusion.attach_shared_library(instance)
		check(fused_player != null, "%s candidate could not receive the shared animation library" % role_id)
		animation_players = instance.find_children("*", "AnimationPlayer", true, false)
	check(animation_players.size() > 0, "%s candidate has no runtime AnimationPlayer" % role_id)
	if animation_players.size() > 0:
		var runtime_player := animation_players[0] as AnimationPlayer
		check(runtime_player != null and not runtime_player.get_animation_list().is_empty(), "%s candidate has no runtime animation clips" % role_id)
	for mesh in instance.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.material_override
			if material == null:
				material = mesh.get_surface_override_material(surface)
			if material == null:
				material = mesh.mesh.surface_get_material(surface)
			check(material != null, "%s has a null material on %s" % [role_id, mesh.name])
	instance.queue_free()
	await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
