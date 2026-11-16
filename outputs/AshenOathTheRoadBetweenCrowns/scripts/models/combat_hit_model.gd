extends RefCounted

const Bow = preload("res://scripts/models/bow_aim_release_model.gd")

static func arrow_damage(effect: Dictionary, draw_ratio: float) -> float:
	return float(effect.get("damage", 28.0)) * float(Bow.release_values(draw_ratio, effect).damage_mult)

static func beam_damage(charge_ratio: float) -> float:
	return lerpf(35.0, 70.0, clampf(charge_ratio, 0.0, 1.0))
