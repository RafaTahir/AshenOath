extends SceneTree

const MaterialLibrary = preload("res://scripts/world_material_library.gd")

const EXPECTED_SURFACES := [
	"forest_ground", "wet_mud", "cobblestone", "plaster", "timber", "roof_tiles", "medieval_brick",
	"water", "foliage", "metal", "blood", "ash", "emissive_window",
]
const QUALITIES := ["potato", "balanced", "quality"]

var failures: Array[String] = []

func _initialize() -> void:
	var library = MaterialLibrary.new()
	root.add_child(library)
	await process_frame

	for surface_id in EXPECTED_SURFACES:
		_assert(library.has_surface(surface_id), "%s is not registered" % surface_id)
		var profile: Dictionary = library.surface_profile(surface_id)
		var kind := str(profile.get("kind", "pbr"))
		_assert(float(profile.get("scale", 0.0)) > 0.0, "%s has no valid UV scale" % surface_id)
		if kind == "pbr":
			_assert(library.has_complete_texture_set(surface_id), "%s lacks a complete PBR texture set" % surface_id)
		else:
			_assert(str(profile.get("stem", "")) != "" or kind in ["procedural", "emissive"], "%s has no source or procedural contract" % surface_id)
		for quality in QUALITIES:
			var material: StandardMaterial3D = library.get_material(surface_id, quality)
			_assert(material != null, "%s/%s did not create a material" % [surface_id, quality])
			if material == null:
				continue
			var contract: Dictionary = library.material_contract(surface_id, quality)
			_assert(str(contract.get("id", "")) == surface_id, "%s contract normalized incorrectly" % surface_id)
			if kind == "pbr":
				_assert(bool(contract.get("has_albedo", false)), "%s/%s contract has no albedo" % [surface_id, quality])
				_assert(bool(contract.get("has_normal", false)), "%s/%s contract has no normal" % [surface_id, quality])
				_assert(bool(contract.get("has_orm", false)), "%s/%s contract has no ORM" % [surface_id, quality])
			_assert(material.albedo_color != Color.WHITE or material.albedo_texture != null, "%s/%s resolved to a blank material" % [surface_id, quality])

	var water := library.get_material("water", "balanced")
	_assert(water.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Water is not alpha blended")
	_assert(water.cull_mode == BaseMaterial3D.CULL_DISABLED, "Water is single-sided")
	var foliage := library.get_material("foliage", "balanced")
	_assert(foliage.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "Foliage is not alpha-scissored")
	var window := library.get_material("emissive_window", "balanced")
	_assert(window.emission_enabled, "Window role has no emission")
	_assert(window.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Window emission is not lightweight")
	var metal := library.get_material("metal", "balanced")
	_assert(metal.metallic > 0.5, "Metal role is not metallic")
	var blood := library.get_material("blood", "balanced")
	_assert(blood.albedo_color != library.get_material("forest_ground", "balanced").albedo_color, "Blood reused ground color")
	var fallback := library.get_material("unknown_surface", "invalid")
	_assert(fallback == library.get_material("forest_ground", "balanced"), "Unknown surface fallback is unstable")
	var before: int = int(library.cache_stats().materials)
	for surface_id in EXPECTED_SURFACES:
		for quality in QUALITIES:
			library.get_material(surface_id, quality)
	_assert(library.cache_stats().materials == before, "Material cache grew on repeated lookup")
	_assert(library.cache_stats().materials >= EXPECTED_SURFACES.size() * QUALITIES.size(), "Material cache is incomplete")

	if is_instance_valid(library):
		library.free()
	if failures.is_empty():
		print("MAT-003 VERIFIER: PASS - unified PBR and procedural surface contract")
		quit(0)
		return
	print("MAT-003 VERIFIER: FAIL (%d)" % failures.size())
	for failure in failures:
		print("- %s" % failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
