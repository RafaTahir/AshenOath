class_name InputFrame
extends RefCounted

const MOVE_QUANTA: float = 32767.0
const ANGLE_QUANTA: float = 65536.0
var tick: int = 0
var move_x: float = 0.0:
	set(value):
		move_x = _quantize(value, MOVE_QUANTA, 1.0)
var move_y: float = 0.0:
	set(value):
		move_y = _quantize(value, MOVE_QUANTA, 1.0)
var aim_yaw_delta: float = 0.0:
	set(value):
		aim_yaw_delta = _quantize(value, ANGLE_QUANTA, TAU)
var aim_pitch_delta: float = 0.0:
	set(value):
		aim_pitch_delta = _quantize(value, ANGLE_QUANTA, TAU)
var buttons: int = 0
var selected_slot: int = 0

static func _quantize(value: float, quanta: float, limit: float) -> float:
	return roundf(clampf(value, -limit, limit) * quanta) / quanta if is_finite(value) else 0.0

func to_dict() -> Dictionary:
	return {"tick": tick, "move_x": move_x, "move_y": move_y,
		"aim_yaw_delta": aim_yaw_delta, "aim_pitch_delta": aim_pitch_delta,
		"buttons": buttons, "selected_slot": selected_slot}

static func from_dict(data: Dictionary) -> InputFrame:
	var frame: InputFrame = load("res://scripts/core/input_frame.gd").new()
	frame.tick = int(data.get("tick", 0))
	frame.move_x = float(data.get("move_x", 0.0))
	frame.move_y = float(data.get("move_y", 0.0))
	frame.aim_yaw_delta = float(data.get("aim_yaw_delta", 0.0))
	frame.aim_pitch_delta = float(data.get("aim_pitch_delta", 0.0))
	frame.buttons = int(data.get("buttons", 0))
	frame.selected_slot = int(data.get("selected_slot", 0))
	return frame
