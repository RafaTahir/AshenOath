extends RefCounted

## Normalized controller metadata shared by input, HUD, and save-safe settings.
## Godot/SDL supplies the physical mapping; this contract supplies identity,
## deadzones, glyph language, and guarded feedback policy.

const FAMILY_XBOX := "xbox"
const FAMILY_PLAYSTATION := "playstation"
const FAMILY_NINTENDO := "nintendo"
const FAMILY_GENERIC := "generic"

static func from_device(device_id: int, device_name: String, connected: bool, settings: Dictionary) -> Dictionary:
	var family := family_for_name(device_name)
	return {
		"device_family": family,
		"glyph_theme": glyph_theme_for_family(family),
		"id": device_id,
		"name": device_name,
		"connected": connected,
		"deadzones": {
			"left_stick": float(settings.get("gamepad_deadzone", 0.16)),
			"right_stick": float(settings.get("gamepad_deadzone", 0.16)),
			"triggers": 0.08,
		},
		"axis_inversion": {
			"x": bool(settings.get("gamepad_invert_x", false)),
			"y": bool(settings.get("gamepad_invert_y", settings.get("invert_y", false))),
		},
		"sensitivity": float(settings.get("gamepad_look_sensitivity", 1.0)),
		"vibration_capability": connected and device_id >= 0,
		"rumble_strength": float(settings.get("gamepad_rumble_strength", 1.0)),
		"bindings": {
			"interact": "A/Cross/B",
			"dodge": "B/Circle/A",
			"light_attack": "RB/R1/R",
			"heavy_attack": "RT/R2/ZR",
			"block": "LB/L1/L",
			"oathfire_beam": "LT/L2/ZL",
		},
	}

static func family_for_name(device_name: String) -> String:
	var lowered := device_name.to_lower()
	if lowered.contains("xbox") or lowered.contains("xinput"):
		return FAMILY_XBOX
	if lowered.contains("dualshock") or lowered.contains("dualsense") or lowered.contains("playstation"):
		return FAMILY_PLAYSTATION
	if lowered.contains("nintendo") or lowered.contains("switch") or lowered.contains("pro controller"):
		return FAMILY_NINTENDO
	return FAMILY_GENERIC

static func glyph_theme_for_family(family: String) -> String:
	match family:
		FAMILY_PLAYSTATION:
			return "playstation"
		FAMILY_NINTENDO:
			return "nintendo"
		FAMILY_XBOX:
			return "xbox"
		_:
			return "generic"
