extends RefCounted
## One flight contract for aiming, the free range and live ammunition.
const MIN_DRAW_SPEED := 0.65
const MAX_DRAW_SPEED := 1.0
const DEFAULT_VELOCITY := 28.0

static func speed(effect: Dictionary, draw_ratio: float) -> float:
	return maxf(1.0, float(effect.get("velocity", DEFAULT_VELOCITY))) * lerpf(MIN_DRAW_SPEED, MAX_DRAW_SPEED, clampf(draw_ratio, 0.0, 1.0))

static func distance_step(velocity: float, delta: float, remaining: float) -> float:
	# Sweep the whole segment on a late frame rather than teleport through it.
	return minf(maxf(velocity, 1.0) * maxf(delta, 0.0), maxf(remaining, 0.0))
