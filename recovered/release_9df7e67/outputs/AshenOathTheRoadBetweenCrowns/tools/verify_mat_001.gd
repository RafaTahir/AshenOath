extends SceneTree

const MaterialLibrary = preload("res://scripts/world_material_library.gd")

var failures := 0

func _initialize() -> void:
	var library = MaterialLibrary.new()
	root.add_child(library)
	var ids: Array[String] = library.surface_ids()
	check(library.pbr_surface_ids().size() == 7, "Expected seven authored PBR world surfaces")
	for surface_id in library.pbr_surface_ids():
		check(library.has_complete_texture_set(surface_id), "%s lacks albedo, normal, or ORM texture" % surface_id)
		var potato: StandardMaterial3D = library.get_material(surface_id, "potato")
		var balanced: StandardMaterial3D = library.get_material(surface_id, "balanced")
		var quality: StandardMaterial3D = library.get_material(surface_id, "quality")
		check(potato.albedo_texture != null, "%s Potato material lacks albedo" % surface_id)
		check(not potato.normal_enabled and potato.roughness_texture == null, "%s Potato material exceeds its texture budget" % surface_id)
		check(balanced.albedo_texture != null, "%s Balanced material lacks authored albedo" % surface_id)
		check(
			not balanced.normal_enabled and balanced.roughness_texture == null and not balanced.uv1_triplanar,
			"%s Balanced material exceeds the native-720p ANGLE texture budget" % surface_id
		)
		check(quality.normal_enabled and quality.normal_texture != null, "%s Quality material lacks normal detail" % surface_id)
		check(quality.roughness_texture != null, "%s Quality material lacks roughness detail" % surface_id)
		check(quality.uv1_triplanar, "%s Quality material lacks world triplanar projection" % surface_id)
		check(quality.ao_enabled and quality.ao_texture != null, "%s Quality material lacks AO detail" % surface_id)
		check(quality == library.get_material(surface_id, "quality"), "%s cache returned a duplicate material" % surface_id)
	var wet := library.get_material("wet_mud", "balanced", Color.WHITE, 1.0)
	var dry := library.get_material("wet_mud", "balanced", Color.WHITE, 0.0)
	check(wet.roughness < dry.roughness, "Wetness does not lower surface roughness")
	check(library.get_material("unknown_surface", "invalid") == library.get_material("forest_ground", "balanced"), "Fallback surface or quality normalization is unstable")
	check(library.get_fallback_material() == library.get_fallback_material(), "Fallback material is not cache-stable")
	check(library.get_grass_material("balanced").albedo_texture != null, "Grass material lacks its alpha texture")
	var stats: Dictionary = library.cache_stats()
	check(int(stats.textures) == 22, "Texture cache should contain 21 PBR maps plus grass")
	library.queue_free()
	print("MAT-001 VERIFIER: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
