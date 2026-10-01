extends RefCounted
class_name SpatialSurfaceContract

const BridgeSurfaceContract = preload("res://scripts/bridge_surface_contract.gd")
const NO_RIVER := 999.0
const DEFAULT_BRIDGE_BANK_OFFSET := 3.2

static func support_hit(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3, excluded: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	var rejected: Array[RID] = excluded.duplicate()
	query.exclude = rejected
	# Overhead architecture still collides with actors/cameras, but cannot become
	# the saved actor's floor simply because the grounding ray starts above it.
	for _attempt in range(32):
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var body := hit.get("collider") as CollisionObject3D
		if body == null:
			return {}
		if bool(body.get_meta("walkable_support", true)) and hit.normal.y >= 0.7:
			return hit
		rejected.append(body.get_rid())
		query.exclude = rejected
	return {}

const ZONE_HALF_EXTENTS := {
	"greyfen": Vector2(21.0, 17.0),
	"wychwood": Vector2(22.0, 17.0),
	"bandit_road": Vector2(22.0, 19.0),
	"vargan_approach": Vector2(23.0, 19.0),
	"vargan_court": Vector2(23.0, 19.0),
	"record_hall": Vector2(17.0, 15.0),
	"undercroft": Vector2(18.0, 17.0),
	"assembly": Vector2(21.0, 17.0),
	"hart_glade": Vector2(22.0, 19.0),
}

static func river_center(zone_id: String) -> float:
	match zone_id:
		"greyfen":
			return 4.5
		"wychwood":
			return 0.0
		_:
			return NO_RIVER

static func zone_half_extents(zone_id: String) -> Vector2:
	return ZONE_HALF_EXTENTS.get(zone_id, Vector2(24.0, 21.0))

static func bank_for(zone_id: String, position: Vector3) -> int:
	var center := river_center(zone_id)
	if center >= NO_RIVER:
		return 0
	return -1 if position.z < center else 1

static func is_on_default_bridge(zone_id: String, position: Vector3, clearance: float = 0.0) -> bool:
	var center := river_center(zone_id)
	if center >= NO_RIVER:
		return false
	var half_length := BridgeSurfaceContract.bridge_half_length(DEFAULT_BRIDGE_BANK_OFFSET * 2.0)
	return BridgeSurfaceContract.contains(position, center, half_length, clearance)

static func is_river_excluded(zone_id: String, position: Vector3, margin: float = 0.0) -> bool:
	var center := river_center(zone_id)
	if center >= NO_RIVER or absf(position.z - center) >= BridgeSurfaceContract.RIVER_HALF_SPAN + margin:
		return false
	return not is_on_default_bridge(zone_id, position, margin)
