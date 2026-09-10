extends RefCounted
class_name BridgeSurfaceContract

## Shared geometry contract for every legal river crossing.
## The rendered bridge, physical surface, navigation lane, and recovery checks
## must agree on these dimensions.
const DECK_WIDTH := 5.4
const HALF_WIDTH := DECK_WIDTH * 0.5
const RIVER_HALF_SPAN := 2.25
const DECK_COLLISION_TOP := 0.12
const DECK_COLLISION_THICKNESS := 0.12
const APPROACH_LENGTH := 1.8

static func bridge_length(river_span: float) -> float:
	return absf(river_span) + 2.6

static func bridge_half_length(river_span: float) -> float:
	return maxf(absf(river_span) * 0.5 - 0.15, RIVER_HALF_SPAN)

static func contains(position: Vector3, center_z: float, half_length: float, clearance: float = 0.0) -> bool:
	if position.y < -0.25:
		return false
	var width_margin := minf(maxf(clearance, 0.0), 0.35)
	var width_limit := maxf(0.0, HALF_WIDTH - width_margin)
	return absf(position.x) <= width_limit and absf(position.z - center_z) <= half_length + maxf(clearance, 0.0)
