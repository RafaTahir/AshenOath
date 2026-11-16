class_name SeededRng
extends RefCounted

var _generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 1

func _init(seed_value: int = 1) -> void:
	_seed = seed_value & 0xffffffff
	if _seed == 0:
		_seed = 1
	_generator.seed = _seed

func get_seed() -> int:
	return _seed

func get_state() -> int:
	return _generator.state

func set_state(value: int) -> void:
	_generator.state = value

func next_u32() -> int:
	return _generator.randi()

func next_float() -> float:
	return _generator.randf()

func range_float(lo: float, hi: float) -> float:
	assert(is_finite(lo) and is_finite(hi) and lo <= hi)
	return _generator.randf_range(lo, hi)

func range_int(lo: int, hi: int) -> int:
	assert(lo <= hi)
	return _generator.randi_range(lo, hi)

func chance(probability: float) -> bool:
	assert(is_finite(probability))
	var draw: float = next_float()
	return probability >= 1.0 or (probability > 0.0 and draw < probability)
