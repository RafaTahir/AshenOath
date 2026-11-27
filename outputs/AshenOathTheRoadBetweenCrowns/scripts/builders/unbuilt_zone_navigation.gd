extends RefCounted

## Before a sector has a live navigation service, apply the same river and bounds rules.
const Spatial = preload("res://scripts/zone_spatial_service.gd")

static func validator(zone: String, river: float, bounds: Vector2) -> Spatial:
	var spatial := Spatial.new()
	spatial.configure(zone,river,bounds)
	return spatial

static func position(zone: String, river: float, bounds: Vector2, point: Vector3, margin: float) -> Vector3:
	var spatial := validator(zone,river,bounds)
	var safe := spatial.validate_position(point,margin,spatial.bank_for(point))
	spatial.free()
	return safe

static func path(zone: String, river: float, bounds: Vector2, points: Array, margin: float) -> Array:
	var spatial := validator(zone,river,bounds)
	var safe := spatial.validate_path(points,margin)
	spatial.free()
	return safe
