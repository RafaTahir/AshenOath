extends RefCounted

## Explicit user comparisons, not hidden quality changes or automatic presets.
const PARAMETERS := {"alpha_batches": "opt_alpha", "static_bounds": "opt_bounds", "interior_occlusion": "opt_occlusion"}
static var _values: Dictionary = {}

static func enabled(feature: String) -> bool:
	if not PARAMETERS.has(feature):
		return false
	if not _values.has(feature):
		var value := bool(ProjectSettings.get_setting("ashen/performance/" + feature, false))
		if OS.has_feature("web"):
			value = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get(%s) === '1'" % JSON.stringify(PARAMETERS[feature])))
		else:
			value = value or ("--" + str(PARAMETERS[feature])) in OS.get_cmdline_user_args()
		_values[feature] = value
	return bool(_values[feature])
