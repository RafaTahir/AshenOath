extends RefCounted

## Explicit user comparisons, not hidden quality changes or automatic presets.
const PARAMETERS := {"alpha_batches": "opt_alpha", "static_bounds": "opt_bounds", "interior_occlusion": "opt_occlusion"}
static var _values: Dictionary = {}

static func _requested_parameter(parameter: String, default_value: bool) -> bool:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("new URLSearchParams(location.search).get(%s)" % JSON.stringify(parameter))
		return default_value if value == null or str(value) not in ["0", "1"] else str(value) == "1"
	var result := default_value
	for argument in OS.get_cmdline_user_args():
		if argument == "--" + parameter or argument == "--" + parameter + "=1":
			result = true
		elif argument == "--" + parameter + "=0":
			result = false
	return result

static func requested(feature: String) -> bool:
	if not PARAMETERS.has(feature):
		return false
	if not _values.has(feature):
		_values[feature] = _requested_parameter(str(PARAMETERS[feature]), true)
	return bool(_values[feature])

static func supported(feature: String) -> bool:
	# Stock Web templates omit the Embree/raycast occlusion module. Physics
	# raycasts are unrelated and remain available on every supported platform.
	return PARAMETERS.has(feature) and (feature != "interior_occlusion" or not OS.has_feature("web"))

static func enabled(feature: String) -> bool:
	return requested(feature) and supported(feature)

static func states() -> Dictionary:
	var result: Dictionary = {}
	for feature in PARAMETERS:
		result[feature] = {"requested": requested(feature), "supported": supported(feature), "effective": enabled(feature)}
	return result

static func display_enabled() -> bool:
	return _requested_parameter("perf", false)
