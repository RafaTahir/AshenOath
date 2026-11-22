extends RefCounted

## Hash-bound contact poses; gameplay durations stay owned by EnemyAI.
const PATH := "res://data/native_attack_profiles.json"
const ASSETS := "res://data/design_pack_assets.json"
const POLICY := "native_attack_contact_v1"
const PROCEDURAL_IDS := ["M06", "M07", "M09", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "M17", "M18"]
const UAL_IDS := ["M01", "M03", "M04", "M05", "M19", "M20"]
static var _loaded := false
static var _profiles: Dictionary = {}
static var _hashes: Dictionary = {}

static func for_source(source: String, clip: String, seconds: float) -> Dictionary:
	if not _loaded:
		_loaded = true
		var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		var assets: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS)) if FileAccess.file_exists(ASSETS) else null
		if profiles is Dictionary and profiles.get("schema_version") == 1 and profiles.get("policy") == POLICY and profiles.get("profiles") is Dictionary:
			_profiles = profiles.profiles
		if assets is Dictionary:
			for entry: Dictionary in assets.get("assets", {}).values():
				_hashes[str(entry.path)] = str(entry.sha256)
	var profile: Dictionary = _profiles.get(source, {})
	var expected_hash := str(_hashes.get(source, ""))
	if profile.is_empty() or expected_hash.length() != 64 or str(profile.get("clip", "")) != clip or str(profile.get("source_sha256", "")) != expected_hash:
		return {}
	var fraction := float(profile.get("contact_fraction", 0.0))
	var duration := float(profile.get("duration_seconds", 0.0))
	if not is_finite(fraction) or fraction <= 0.0 or fraction >= 1.0 or not is_finite(duration) or not is_finite(seconds) or seconds <= 0.0 or absf(duration - seconds) > 0.0001:
		return {}
	return profile.duplicate(true)

static func choose_fraction(id: String, seconds: float, samples: Array[Dictionary]) -> Dictionary:
	# Sampling tools supply the actual bound probe in canonical actor space.
	# A static/flat path has an explicit declared policy, never a guessed frame.
	if id in PROCEDURAL_IDS:
		return {"contact_fraction": 0.5, "method": "authored_procedural_apex", "requires_visual_acceptance": false}
	if samples.is_empty() or not is_finite(seconds) or seconds <= 0.0:
		return {}
	var minimum := INF
	var maximum := -INF
	var selected := 0.0
	var first_fraction := float(samples[0].seconds) / seconds
	var last_fraction := float(samples[-1].seconds) / seconds
	var endpoint_tolerance := maxf(0.000001, 0.5 / (120.0 * seconds))
	var first: Vector3 = samples[0].point
	var diameter := 0.0
	for sample: Dictionary in samples:
		var point: Vector3 = sample.point
		var time := float(sample.seconds)
		var distance := point.distance_to(Vector3(0, 1, -1.2))
		if not point.is_finite() or not is_finite(time) or not is_finite(distance):
			return {}
		diameter = maxf(diameter, point.distance_to(first))
		# Quantize metres so equivalent floating-point poses have a stable tie.
		distance = snappedf(distance, 0.000001)
		maximum = maxf(maximum, distance)
		if distance < minimum:
			minimum = distance
			selected = time / seconds
	var flat := diameter < 0.001 or maximum - minimum < 0.001
	var endpoint := selected <= first_fraction + endpoint_tolerance or selected >= last_fraction - endpoint_tolerance
	if flat or endpoint:
		return {"contact_fraction": 0.7, "method": "declared_recovery_boundary_fallback", "requires_visual_acceptance": true, "fallback_reason":"flat_probe" if flat else "endpoint_minimum"}
	return {"contact_fraction": selected, "method": "sampled_earliest_minimum_120hz", "requires_visual_acceptance": false, "minimum_distance_m": minimum}
