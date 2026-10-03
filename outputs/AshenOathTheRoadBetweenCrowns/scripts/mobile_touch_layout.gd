extends RefCounted

const HudLayoutPolicy = preload("res://scripts/hud_layout_policy.gd")
const GAMEPLAY_ACTIONS := [
	["interact", "USE", 0, 0], ["jump", "JUMP", 1, 0], ["oathfire_beam", "OATH", 2, 0],
	["block", "GUARD", 0, 1], ["heavy_attack", "HEAVY", 1, 1], ["light_attack", "STRIKE", 2, 1],
	["use_potion", "POTION", 0, 2], ["throw_bomb", "BOMB", 1, 2], ["dodge", "DODGE", 2, 2]
]

static func build(canvas_size: Vector2, display: Dictionary = {}) -> Dictionary:
	var common: Dictionary = HudLayoutPolicy.resolve(canvas_size, display, 1.0, "touch")
	var unit: float = maxf(float(common.get("unit_scale", 1.0)), 0.001)
	var safe: Rect2 = common.get("safe_rect", Rect2(Vector2.ZERO, canvas_size))
	var shown: Vector2 = common.get("display_size", canvas_size)
	var usable: Vector2 = common.get("display_usable_size", safe.size / unit)
	# The fitted game remains 16:9 in a portrait browser. Its own aspect must
	# never override the orientation of the actual display supplied by root.
	var landscape: bool = shown.x / maxf(shown.y, 1.0) >= 1.28
	var playable: bool = bool(common.get("valid", false)) and landscape and usable.x >= 560.0 and usable.y >= 300.0
	var actions: Array[Dictionary] = []
	var reserved: Array[Rect2] = []
	var nav_y: float = safe.position.y + minf(36.0 * unit, safe.size.y * 0.5)
	var pause_center: Vector2 = Vector2(safe.end.x - minf(36.0 * unit, safe.size.x * 0.5), nav_y)
	var book_center: Vector2 = pause_center - Vector2(60.0 * unit, 0)
	if usable.x < 132.0:
		book_center = pause_center + Vector2(0, 60.0 * unit)
	for nav: Dictionary in [{"id": "pause", "label": "II", "center": pause_center}, {"id": "open_inventory", "label": "BOOK", "center": book_center}]:
		var center: Vector2 = nav["center"]
		actions.append({"id": str(nav["id"]), "label": str(nav["label"]), "center": center, "radius": 24.0 * unit})
		reserved.append(Rect2(center - Vector2.ONE * 30.0 * unit, Vector2.ONE * 60.0 * unit))
	var move_center: Vector2 = Vector2(safe.position.x + 80.0 * unit, safe.end.y - 80.0 * unit)
	var move_region: Rect2 = Rect2()
	var look_region: Rect2 = Rect2()
	if playable:
		for definition: Array in GAMEPLAY_ACTIONS:
			var center: Vector2 = Vector2(safe.end.x - (160.0 - float(definition[2]) * 60.0) * unit, safe.end.y - (160.0 - float(definition[3]) * 60.0) * unit)
			var radius: float = (28.0 if str(definition[0]) == "light_attack" else 24.0) * unit
			actions.append({"id": str(definition[0]), "label": str(definition[1]), "center": center, "radius": radius})
		move_region = Rect2(Vector2(safe.position.x, safe.end.y - 204.0 * unit), Vector2(minf(safe.size.x * 0.4, 204.0 * unit), 204.0 * unit))
		look_region = Rect2(Vector2(safe.position.x + safe.size.x * 0.4, safe.position.y + 72.0 * unit), Vector2(safe.size.x * 0.6, maxf(safe.size.y - 72.0 * unit, 0.0)))
		reserved.append(move_region)
		reserved.append(Rect2(safe.end - Vector2.ONE * 204.0 * unit, Vector2.ONE * 204.0 * unit))
	return {
		"valid": bool(common.get("valid", false)), "safe_rect": safe, "unit_scale": unit,
		"display_size": shown, "display_usable_size": usable, "landscape": landscape,
		"playable": playable, "reason": "" if playable else ("Rotate device to landscape" if not landscape else "More space is needed for touch play"),
		"actions": actions, "move_center": move_center, "move_radius": 56.0 * unit,
		"move_travel": 44.0 * unit, "move_knob_radius": 22.0 * unit,
		"move_region": move_region, "look_region": look_region, "reserved_rects": reserved,
		"bottom_reserved_display": 204.0 if playable else 0.0
	}
