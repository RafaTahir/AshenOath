class_name InputBindingModel
extends RefCounted
const Frame = preload("res://scripts/core/input_frame.gd")
const Defaults = preload("res://scripts/core/input_defaults.gd")
const CONTEXT_MENU: String = Defaults.CONTEXT_MENU
const CONTEXT_GAMEPLAY: String = Defaults.CONTEXT_GAMEPLAY
const CONTEXT_DIALOGUE: String = Defaults.CONTEXT_DIALOGUE
const CONTEXT_PAUSE: String = Defaults.CONTEXT_PAUSE
const ACTION_BITS: Dictionary = {"run":1,"jump":2,"light_attack":4,"dodge":8,"heavy_attack":16,"block":32,"oathfire_beam":64,"aim_bow":256,"fire_bow":512,"bow_cancel":1024}
var bindings: Dictionary = {}
var contexts: Array[String] = [CONTEXT_MENU]
var generation: int = 0

func normalize_context(value: String) -> String:
	var key: String = value.strip_edges().to_lower()
	return key if key in Defaults.UI_CONTEXTS or key == CONTEXT_GAMEPLAY else CONTEXT_MENU

func context() -> String:
	return contexts.back()

func set_context(value: String) -> bool:
	var normalized: String = normalize_context(value)
	if context() == normalized: return false
	contexts[contexts.size()-1] = normalized
	generation += 1
	return true

func push_context(value: String) -> void:
	contexts.append(normalize_context(value))
	generation += 1

func pop_context() -> String:
	if contexts.size() > 1:
		contexts.pop_back()
		generation += 1
	return context()

func allows_action(action: String) -> bool:
	return action.begins_with("ui_") or context() == CONTEXT_GAMEPLAY

static func can_share(first: String, second: String, family: String) -> bool:
	var pairs: Array = {"mouse":[["light_attack","fire_bow"],["heavy_attack","aim_bow"]],"joy_motion":[["heavy_attack","fire_bow"],["oathfire_beam","aim_bow"],["camera_left","target_previous"],["camera_right","target_next"]],"joy_button":[["cycle_arrow","camera_zoom_in"],["companion_command","camera_zoom_out"]]}.get(family,[])
	for pair: Array in pairs:
		if first in pair and second in pair: return true
	return false

static func valid_record(value: Variant) -> bool:
	if not value is Dictionary: return false
	match str(value.get("type","")):
		"key": return int(value.get("keycode",0)) > 0
		"mouse": return int(value.get("button",0)) > 0 and int(value.button) <= 9
		"joy_button": return int(value.get("button",-1)) >= 0 and int(value.button) < 128
		"joy_motion": return int(value.get("axis",-1)) >= 0 and int(value.axis) < 16 and is_finite(float(value.get("value",0.0))) and absf(float(value.value)) >= 0.5 and absf(float(value.value)) <= 1.0
	return false

func load_bindings(source: Dictionary) -> void:
	bindings.clear()
	for action: String in source:
		if not source[action] is Array: continue
		var records: Array[Dictionary] = []
		for raw: Variant in source[action]:
			if valid_record(raw): records.append(raw.duplicate(true))
		bindings[action] = records

func save_bindings() -> Dictionary:
	return bindings.duplicate(true)

func conflicts(action: String, record: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for other: String in bindings:
		if other == action or other.begins_with("ui_") or can_share(action,other,str(record.get("type",""))): continue
		for existing: Dictionary in bindings[other]:
			var same: bool = existing == record
			if str(record.get("type","")) == "joy_motion" and str(existing.get("type","")) == "joy_motion":
				same = int(existing.axis) == int(record.axis) and signf(float(existing.value)) == signf(float(record.value))
			if same:
				found.append(other)
				break
	return found

func remap(action: String, record: Dictionary) -> Dictionary:
	if not bindings.has(action): return {"ok":false,"reason":"unknown_action"}
	if not valid_record(record): return {"ok":false,"reason":"unsupported_event"}
	var collision: Array[String] = conflicts(action,record)
	if collision.size() > 1: return {"ok":false,"reason":"multiple_conflicts","conflicts":collision,"message":"This control already serves several actions. Choose another control or move those actions first."}
	var family: String = str(record.type)
	var displaced: Dictionary = {}
	for prior: Dictionary in bindings[action]:
		if str(prior.type) == family:
			displaced = prior.duplicate(true)
			break
	var other: String = collision[0] if not collision.is_empty() else ""
	for key: String in [action,other]:
		if key == "": continue
		var remaining: Array[Dictionary] = []
		for prior: Dictionary in bindings[key]:
			if str(prior.type) != family: remaining.append(prior)
		bindings[key] = remaining
	if other != "" and not displaced.is_empty(): bindings[other].append(displaced)
	bindings[action].append(record.duplicate(true))
	generation += 1
	return {"ok":true,"conflict":other}

func emit_frame(tick: int, movement: Vector2, look: Vector2, snapshot: Dictionary, selected: int = 0) -> Frame:
	var frame: Frame = Frame.new()
	frame.tick = tick
	if context() != CONTEXT_GAMEPLAY: return frame
	var move: Vector2 = movement.limit_length(1.0)
	frame.move_x = move.x
	frame.move_y = move.y
	frame.aim_yaw_delta = look.x
	frame.aim_pitch_delta = look.y
	frame.selected_slot = selected
	for action: String in ACTION_BITS:
		if bool(snapshot.get(action,{}).get("held",false)) or bool(snapshot.get(action,{}).get("pressed",false)):
			frame.buttons |= int(ACTION_BITS[action])
	return frame
