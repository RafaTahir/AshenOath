extends RefCounted

## The hit query and ground presentation share these existing attack shapes.
## EnemyAI retains range, obstruction, damage and timing authority.
const PROFILES := {
	"wing_blast": {"kind": "cone", "forward_dot": 0.32},
	"ash_breath": {"kind": "cone", "forward_dot": 0.48},
	"swoop": {"kind": "cone", "forward_dot": 0.48},
	"counter_lunge": {"kind": "cone", "forward_dot": 0.809},
	"senn_lunge": {"kind": "cone", "forward_dot": 0.78},
	"senn_guard": {"kind": "cone", "forward_dot": 0.48},
	"parry_test": {"kind": "cone", "forward_dot": 0.50},
	"bog_reach": {"kind": "cone", "forward_dot": 0.60},
	"antler_sweep": {"kind": "cone", "forward_dot": 0.035},
	"root_lanes": {"kind": "lanes", "period": 2.35, "near_edge": 0.62, "far_edge": 1.72}
}
const ARC_SEGMENTS := 64

static func contains(attack_id: String, local_offset: Vector3) -> bool:
	var profile: Dictionary = PROFILES.get(attack_id, {})
	var flat := Vector3(local_offset.x, 0.0, local_offset.z)
	if flat.length_squared() <= 0.01:
		return true
	if str(profile.get("kind", "radial")) == "cone":
		return Vector3.FORWARD.dot(flat.normalized()) >= float(profile.forward_dot)
	if str(profile.get("kind", "radial")) == "lanes":
		var lane := fmod(absf(flat.x), float(profile.period))
		return lane < float(profile.near_edge) or lane > float(profile.far_edge)
	return true

static func footprint_triangles(attack_id: String, radius: float) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	if not is_finite(radius) or radius <= 0.0:
		return vertices
	var profile: Dictionary = PROFILES.get(attack_id, {})
	if str(profile.get("kind", "radial")) == "lanes":
		for interval: Vector2 in lane_intervals(radius):
			var steps := maxi(4, ceili((interval.y - interval.x) / radius * ARC_SEGMENTS))
			for step in steps:
				var left := lerpf(interval.x, interval.y, float(step) / steps)
				var right := lerpf(interval.x, interval.y, float(step + 1) / steps)
				var left_depth := sqrt(maxf(0.0, radius * radius - left * left))
				var right_depth := sqrt(maxf(0.0, radius * radius - right * right))
				var a := Vector3(left, 0.0, -left_depth)
				var b := Vector3(right, 0.0, -right_depth)
				var c := Vector3(right, 0.0, right_depth)
				var d := Vector3(left, 0.0, left_depth)
				vertices.append_array(PackedVector3Array([a, c, b, a, d, c]))
		return vertices
	var half_angle := acos(float(profile.forward_dot)) if str(profile.get("kind", "radial")) == "cone" else PI
	for segment in ARC_SEGMENTS:
		var a := lerpf(-half_angle, half_angle, float(segment) / ARC_SEGMENTS)
		var b := lerpf(-half_angle, half_angle, float(segment + 1) / ARC_SEGMENTS)
		vertices.append_array(PackedVector3Array([Vector3.ZERO,
			Vector3(sin(b) * radius, 0.0, -cos(b) * radius),
			Vector3(sin(a) * radius, 0.0, -cos(a) * radius)]))
	return vertices

static func lane_intervals(radius: float) -> Array[Vector2]:
	# Preserve the original occupied central band and the two flanking gaps.
	if not is_finite(radius) or radius <= 0.0:
		return []
	var profile: Dictionary = PROFILES.root_lanes
	var period := float(profile.period)
	var near_edge := float(profile.near_edge)
	var far_edge := float(profile.far_edge)
	var intervals: Array[Vector2] = [Vector2(-minf(radius, near_edge), minf(radius, near_edge))]
	for index in range(1, ceili(radius / period) + 2):
		var left := (index - 1) * period + far_edge
		var right := index * period + near_edge
		if left >= radius:
			break
		right = minf(right, radius)
		intervals.append(Vector2(left, right))
		intervals.append(Vector2(-right, -left))
	return intervals
