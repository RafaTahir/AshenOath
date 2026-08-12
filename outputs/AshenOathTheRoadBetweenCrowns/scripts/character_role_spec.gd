extends RefCounted

## One source of truth for route-visible character proportions.
## Visual normalization, collision sizing, and screenshot checks should use the
## same role contract instead of multiplying ad-hoc scale values at spawn time.

const DEFAULT_SPEC := {
	"height": 1.72,
	"collision_height": 1.65,
	"collision_radius": 0.32,
	"lod": 14.0,
	"facing_degrees": 0.0,
}

const SPECS := {
	"player_human": {"height": 1.78, "collision_height": 1.65, "collision_radius": 0.32, "lod": 22.0, "facing_degrees": 180.0},
	"player_kael": {"height": 1.78, "collision_height": 1.65, "collision_radius": 0.32, "lod": 22.0, "facing_degrees": 180.0},
	"sister_anwen": {"height": 1.68, "collision_height": 1.58, "collision_radius": 0.30, "lod": 22.0, "facing_degrees": 0.0},
	"sister_anwen_human": {"height": 1.68, "collision_height": 1.58, "collision_radius": 0.30, "lod": 22.0, "facing_degrees": 0.0},
	"mira_human": {"height": 1.66, "collision_height": 1.56, "collision_radius": 0.30, "lod": 14.0, "facing_degrees": 0.0},
	"rook_human": {"height": 1.75, "collision_height": 1.64, "collision_radius": 0.31, "lod": 14.0, "facing_degrees": 0.0},
	"villager_human": {"height": 1.72, "collision_height": 1.62, "collision_radius": 0.31, "lod": 14.0, "facing_degrees": 0.0},
	"villager_female_human": {"height": 1.66, "collision_height": 1.56, "collision_radius": 0.30, "lod": 14.0, "facing_degrees": 0.0},
	"villager_worker_human": {"height": 1.74, "collision_height": 1.64, "collision_radius": 0.31, "lod": 14.0, "facing_degrees": 0.0},
	"villager_hooded_human": {"height": 1.69, "collision_height": 1.59, "collision_radius": 0.30, "lod": 14.0, "facing_degrees": 0.0},
	"castle_guard_human": {"height": 1.82, "collision_height": 1.72, "collision_radius": 0.33, "lod": 16.0, "facing_degrees": 0.0},
	"road_ranger_human": {"height": 1.75, "collision_height": 1.64, "collision_radius": 0.31, "lod": 16.0, "facing_degrees": 0.0},
	"ghoulkin": {"height": 1.72, "collision_height": 1.65, "collision_radius": 0.34, "lod": 18.0, "facing_degrees": 0.0},
	"wychwood_stalker": {"height": 1.66, "collision_height": 1.60, "collision_radius": 0.32, "lod": 18.0, "facing_degrees": 0.0},
	"wychwood_raider": {"height": 1.72, "collision_height": 1.65, "collision_radius": 0.34, "lod": 18.0, "facing_degrees": 0.0},
	"wychwood_brute": {"height": 1.90, "collision_height": 1.80, "collision_radius": 0.40, "lod": 20.0, "facing_degrees": 0.0},
	"bog_wretch": {"height": 1.60, "collision_height": 1.52, "collision_radius": 0.38, "lod": 16.0, "facing_degrees": 0.0},
	"gravebound_knight": {"height": 1.88, "collision_height": 1.78, "collision_radius": 0.38, "lod": 18.0, "facing_degrees": 0.0},
	"white_hart_avatar": {"height": 2.55, "collision_height": 2.25, "collision_radius": 0.58, "lod": 24.0, "facing_degrees": 0.0},
}

static func for_role(role_id: String) -> Dictionary:
	var key := role_id.strip_edges().to_lower()
	var result: Dictionary = DEFAULT_SPEC.duplicate(true)
	if SPECS.has(key):
		result.merge(SPECS[key], true)
	result["role"] = key
	result["known"] = SPECS.has(key)
	return result

static func target_height(role_id: String, fallback: float = 1.72) -> float:
	var spec := for_role(role_id)
	return float(spec.get("height", fallback)) if bool(spec.get("known", false)) else fallback

static func collision_height(role_id: String, fallback: float = 1.65) -> float:
	var spec := for_role(role_id)
	return float(spec.get("collision_height", fallback)) if bool(spec.get("known", false)) else fallback

static func collision_radius(role_id: String, fallback: float = 0.32) -> float:
	var spec := for_role(role_id)
	return float(spec.get("collision_radius", fallback)) if bool(spec.get("known", false)) else fallback

static func lod_distance(role_id: String, fallback: float = 14.0) -> float:
	var spec := for_role(role_id)
	return float(spec.get("lod", fallback)) if bool(spec.get("known", false)) else fallback

static func facing_degrees(role_id: String) -> float:
	return float(for_role(role_id).get("facing_degrees", 0.0))
