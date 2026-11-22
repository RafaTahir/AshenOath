extends RefCounted

const HudLayoutPolicy = preload("res://scripts/hud_layout_policy.gd")
const SWORD_ACTIONS := [
	["jump", "JUMP", 0, 0], ["heavy_attack", "HEAVY", 1, 0], ["oathfire_beam", "OATH", 2, 0],
	["block", "GUARD", 0, 1], ["light_attack", "STRIKE", 1, 1], ["dodge", "DODGE", 2, 1]
]
const BOW_ACTIONS := [
	["jump", "JUMP", 0, 0], ["target_lock", "LOCK", 1, 0], ["cycle_arrow", "ARROWS", 2, 0],
	["aim_bow", "AIM", 0, 1], ["fire_bow", "FIRE", 1, 1], ["dodge", "DODGE", 2, 1]
]

static func build(canvas_size: Vector2, display: Dictionary = {}, weapon_mode: String = "sword") -> Dictionary:
	var common: Dictionary = HudLayoutPolicy.resolve(canvas_size, display, 1.0, "touch")
	var unit: float = maxf(float(common.get("unit_scale", 1.0)), 0.001)
	var safe: Rect2 = common.get("safe_rect", Rect2(Vector2.ZERO, canvas_size))
	var shown: Vector2 = common.get("display_size", canvas_size)
	var usable: Vector2 = common.get("display_usable_size", safe.size / unit)
	# The fitted game remains 16:9 in a portrait browser. Its own aspect must
	# never override the orientation of the actual display supplied by root.
	var landscape: bool = shown.x / maxf(shown.y, 1.0) >= 1.28
	var compact: bool = usable.x < 620.0 or usable.y < 360.0
	var move_width: float = 112.0 if compact else 164.0
	var controls_width: float = 172.0 if compact else 200.0
	var controls_height: float = 120.0 if compact else 144.0
	# Reserve a full 48px Use target between the stick and combat controls.
	var playable: bool = bool(common.get("valid", false)) and landscape and usable.x >= move_width + controls_width + 76.0 and usable.y >= 200.0
	var actions: Array[Dictionary] = []
	var reserved: Array[Rect2] = []
	var nav_edge: float = 32.0 if compact else 36.0
	var nav_radius: float = 24.0 if compact else 26.0
	var nav_y: float = safe.position.y + minf(nav_edge * unit, safe.size.y * 0.5)
	var nav_spacing: float = minf((56.0 if compact else 64.0) * unit, maxf(0.0, (safe.size.x - nav_edge * 2.0 * unit) * 0.5))
	var pause_center: Vector2 = Vector2(safe.end.x - minf(nav_edge * unit, safe.size.x * 0.5), nav_y)
	for nav: Dictionary in [{"id": "pause", "label": "II", "center": pause_center}, {"id": "open_inventory", "label": "BOOK", "center": pause_center - Vector2(nav_spacing, 0)}, {"id": "touch_more", "label": "MORE", "center": pause_center - Vector2(nav_spacing * 2.0, 0)}]:
		var center: Vector2 = nav["center"]
		actions.append({"id": str(nav["id"]), "label": str(nav["label"]), "center": center, "radius": nav_radius * unit})
		reserved.append(Rect2(center - Vector2.ONE * (nav_radius + 4.0) * unit, Vector2.ONE * (nav_radius + 4.0) * 2.0 * unit))
	var move_center: Vector2 = Vector2(safe.position.x + (56.0 if compact else 72.0) * unit, safe.end.y - (64.0 if compact else 76.0) * unit)
	var move_region: Rect2 = Rect2()
	var look_region: Rect2 = Rect2()
	var center_rect := Rect2()
	var prompt_rect := Rect2()
	var message_rect := Rect2()
	var controls_rect := Rect2()
	var shared_message_prompt: bool = false
	if playable:
		var action_spacing: float = 56.0 if compact else 64.0
		for definition: Array in (BOW_ACTIONS if weapon_mode == "bow" else SWORD_ACTIONS):
			var center: Vector2 = Vector2(safe.end.x - ((144.0 if compact else 164.0) - float(definition[2]) * action_spacing) * unit, safe.end.y - ((92.0 if compact else 108.0) - float(definition[3]) * action_spacing) * unit)
			var primary: bool = str(definition[0]) in ["light_attack", "fire_bow"]
			var radius: float = ((26.0 if primary else 24.0) if compact else (28.0 if primary else 26.0)) * unit
			actions.append({"id": str(definition[0]), "label": str(definition[1]), "center": center, "radius": radius})
		var move_height: float = 128.0 if compact else 164.0
		move_region = Rect2(Vector2(safe.position.x, safe.end.y - move_height * unit), Vector2(move_width, move_height) * unit)
		controls_rect = Rect2(safe.end - Vector2(controls_width, controls_height) * unit, Vector2(controls_width, controls_height) * unit)
		center_rect = Rect2(Vector2(move_region.end.x + 8.0 * unit, safe.position.y), Vector2(maxf(0.0, controls_rect.position.x - move_region.end.x - 16.0 * unit), safe.size.y))
		var text_width: float = minf(360.0 * unit, center_rect.size.x)
		prompt_rect = Rect2(Vector2(center_rect.get_center().x - text_width * 0.5, safe.end.y - (128.0 if compact else 140.0) * unit), Vector2(text_width, 68.0 * unit))
		var message_top: float = (72.0 if compact else 84.0) * unit
		message_rect = Rect2(Vector2(prompt_rect.position.x, safe.position.y + message_top), Vector2(text_width, maxf(0.0, prompt_rect.position.y - safe.position.y - message_top - 6.0 * unit)))
		shared_message_prompt = compact and message_rect.size.y < 68.0 * unit
		if shared_message_prompt:
			message_rect = prompt_rect
		var use_center := Vector2(center_rect.get_center().x, safe.end.y - (32.0 if compact else 38.0) * unit)
		actions.append({"id":"interact", "label":"USE", "center":use_center, "radius":nav_radius * unit})
		var look_top: float = (64.0 if compact else 72.0) * unit
		look_region = Rect2(Vector2(safe.position.x + safe.size.x * 0.4, safe.position.y + look_top), Vector2(safe.size.x * 0.6, maxf(safe.size.y - look_top, 0.0)))
		reserved.append(move_region)
		reserved.append(controls_rect)
		reserved.append(Rect2(use_center - Vector2.ONE * (nav_radius + 4.0) * unit, Vector2.ONE * (nav_radius + 4.0) * 2.0 * unit))
	return {
		"valid": bool(common.get("valid", false)), "safe_rect": safe, "unit_scale": unit,
		"display_size": shown, "display_usable_size": usable, "landscape": landscape,
		"playable": playable, "compact": compact, "reason": "" if playable else ("Rotate device to landscape" if not landscape else "More space is needed for touch play"), "weapon_mode":weapon_mode,
		"actions": actions, "move_center": move_center, "move_radius": (44.0 if compact else 58.0) * unit,
		"move_travel": (32.0 if compact else 44.0) * unit, "move_knob_radius": (20.0 if compact else 24.0) * unit,
		"move_region": move_region, "look_region": look_region, "reserved_rects": reserved,
		"controls_rect":controls_rect, "center_rect":center_rect, "prompt_rect":prompt_rect, "message_rect":message_rect,
		"shared_message_prompt": shared_message_prompt,
		"bottom_reserved_display": controls_height if playable else 0.0
	}
