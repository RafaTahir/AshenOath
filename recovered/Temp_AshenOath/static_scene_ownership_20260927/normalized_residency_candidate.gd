extends "D:/Temp/AshenOath/static_scene_ownership_20260927/mesh_residency_candidate.gd"

const Neutral = preload("D:/Temp/AshenOath/static_scene_ownership_20260927/neutral_material_family.gd")
const NormalizedWorld = preload("D:/Temp/AshenOath/static_scene_ownership_20260927/normalized_world_materials.gd")

func _ready() -> void:
	super._ready()
	var original_cache: Dictionary = world_materials.material_cache
	var original_textures: Dictionary = world_materials.texture_cache
	var original_pending: Dictionary = world_materials.pending_textures
	var original_failed: bool = world_materials.prewarm_failed
	var original_fallback: StandardMaterial3D = world_materials.fallback_material
	world_materials.set_script(NormalizedWorld)
	world_materials.material_cache = original_cache
	world_materials.texture_cache = original_textures
	world_materials.pending_textures = original_pending
	world_materials.prewarm_failed = original_failed
	world_materials.fallback_material = original_fallback

func _mat(color: Color) -> StandardMaterial3D:
	return Neutral.normalize(super._mat(color)) as StandardMaterial3D

func _valid_material_or_fallback(material: Material) -> Material:
	return Neutral.normalize(super._valid_material_or_fallback(material))

func _ensure_mesh_surface_materials(mesh: Mesh, fallback: Material) -> int:
	var repaired := super._ensure_mesh_surface_materials(mesh, fallback)
	if mesh != null:
		for surface in mesh.get_surface_count():
			Neutral.normalize(mesh.surface_get_material(surface))
	return repaired

func _make_role_visual(role_name: String, category: String, scale_value: Vector3) -> Node3D:
	var visual := super._make_role_visual(role_name, category, scale_value)
	if visual == null:
		return null
	var meshes := visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D:
		meshes.push_front(visual)
	for node in meshes:
		Neutral.normalize(node.material_override)
		if node.mesh == null:
			continue
		for surface in node.mesh.get_surface_count():
			Neutral.normalize(node.mesh.surface_get_material(surface))
			Neutral.normalize(node.get_surface_override_material(surface))
	return visual

func _material_key(material: Material) -> Array:
	# Canonical effective inputs: white sampling and zero emission are neutral.
	if material is StandardMaterial3D:
		var normalized := material.duplicate(false) as StandardMaterial3D
		if normalized.albedo_texture == Neutral.white_texture:
			normalized.albedo_texture = null
		if normalized.emission_texture == null and normalized.emission.r == 0.0 and normalized.emission.g == 0.0 and normalized.emission.b == 0.0:
			normalized.emission_enabled = false
		return super._material_key(normalized)
	return super._material_key(material)
