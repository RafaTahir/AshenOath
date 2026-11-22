extends RefCounted

const MAX_WEB_DELTA := 1.0 / 30.0

static func simulation_delta(delta: float) -> float:
	return minf(maxf(delta, 0.0), MAX_WEB_DELTA) if OS.has_feature("web") else maxf(delta, 0.0)

static func slide(body: CharacterBody3D, delta: float) -> void:
	# move_and_slide reads the engine delta, not the caller's bounded delta.
	# Scale only this move, then restore collision-adjusted gameplay velocity.
	var engine_delta := body.get_physics_process_delta_time()
	var scale := clampf(delta / maxf(engine_delta, 0.000001), 0.000001, 1.0)
	body.velocity *= scale
	body.move_and_slide()
	body.velocity /= scale
