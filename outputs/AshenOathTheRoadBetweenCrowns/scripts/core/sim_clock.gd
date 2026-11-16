class_name SimClock
extends RefCounted

const TICK_HZ: int = 60
const TICK_DT: float = 1.0 / 60.0
const RULESET_VERSION: String = "ashen-sim-v1"
var accumulator: float = 0.0
var tick: int = 0

func consume(delta: float, max_steps: int = 4) -> int:
	if not is_finite(delta) or delta <= 0.0 or max_steps <= 0:
		return 0
	accumulator += delta
	var steps: int = mini(floori((accumulator + 1.0e-10) / TICK_DT), max_steps)
	accumulator = maxf(0.0, accumulator - steps * TICK_DT)
	tick += steps
	return steps
