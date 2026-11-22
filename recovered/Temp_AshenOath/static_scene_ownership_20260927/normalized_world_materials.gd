extends "res://scripts/world_material_library.gd"

const Neutral = preload("D:/Temp/AshenOath/static_scene_ownership_20260927/neutral_material_family.gd")

func get_material(surface_id: String, quality: String = "balanced", tint: Color = Color.WHITE, wetness: float = 0.0, triplanar: bool = true) -> StandardMaterial3D:
	return Neutral.normalize(super.get_material(surface_id, quality, tint, wetness, triplanar)) as StandardMaterial3D

func get_fallback_material() -> StandardMaterial3D:
	return Neutral.normalize(super.get_fallback_material()) as StandardMaterial3D

func get_grass_material(quality: String = "balanced") -> StandardMaterial3D:
	return Neutral.normalize(super.get_grass_material(quality)) as StandardMaterial3D
