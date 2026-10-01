extends RefCounted

## One source of truth for route-visible character proportions.
## Visual normalization, collision sizing, and screenshot checks should use the
## same role contract instead of multiplying ad-hoc scale values at spawn time.

const DEFAULT_SPEC := {
	"height": 1.72,
	"collision_height": 1.65,
	"collision_radius": 0.32,
	"lod": 14.0,
	"ground_offset": 0.0,
	"skeleton_profile": "QuaterniusUniversalHumanoid",
	"animation_profile": "Neutral_shared_retargeted",
	"equipment_sockets": {
		"head": ["head", "Head", "Head_2"],
		"weapon": ["hand_r", "handr", "r_hand", "Hand.R", "Weapon.R", "WeaponR", "Fist.R", "FistR"],
		"offhand": ["hand_l", "handl", "l_hand", "Hand.L", "Fist.L", "FistL"]
	},
	"required_sockets": ["head", "weapon", "offhand"],
	"height_tolerance": 0.08,
	"visual_forward_degrees": 0.0,
}

const SPECS := {
	"player_human": {"height": 1.78, "collision_height": 1.65, "collision_radius": 0.32, "lod": 22.0, "visual_forward_degrees": 180.0},
	"player_kael": {"height": 1.78, "collision_height": 1.65, "collision_radius": 0.32, "lod": 22.0, "visual_forward_degrees": 180.0},
	"sister_anwen": {"height": 1.68, "collision_height": 1.58, "collision_radius": 0.30, "lod": 22.0, "visual_forward_degrees": 180.0},
	"sister_anwen_human": {"height": 1.68, "collision_height": 1.58, "collision_radius": 0.30, "lod": 22.0, "visual_forward_degrees": 180.0},
	"mira_human": {"height": 1.66, "collision_height": 1.56, "collision_radius": 0.30, "lod": 14.0, "visual_forward_degrees": 180.0},
	"rook_human": {"height": 1.75, "collision_height": 1.64, "collision_radius": 0.31, "lod": 14.0, "visual_forward_degrees": 180.0},
	"villager_human": {"height": 1.72, "collision_height": 1.62, "collision_radius": 0.31, "lod": 14.0, "visual_forward_degrees": 180.0},
	"villager_female_human": {"height": 1.66, "collision_height": 1.56, "collision_radius": 0.30, "lod": 14.0, "visual_forward_degrees": 180.0},
	"villager_worker_human": {"height": 1.74, "collision_height": 1.64, "collision_radius": 0.31, "lod": 14.0, "visual_forward_degrees": 180.0},
	"villager_hooded_human": {"height": 1.69, "collision_height": 1.59, "lod": 14.0, "visual_forward_degrees": 180.0},
	"castle_guard_human": {"height": 1.82, "collision_height": 1.72, "collision_radius": 0.33, "lod": 16.0, "visual_forward_degrees": 180.0},
	# Focal road actors must survive the chase camera's offset and wide arrival
	# sightline; the crowd cutoff otherwise leaves visible weapons without bodies.
	"road_ranger_human": {"height": 1.75, "collision_height": 1.64, "collision_radius": 0.31, "lod": 32.0, "visual_forward_degrees": 180.0},
	"bandit_deserter": {"height": 1.75, "collision_height": 1.64, "collision_radius": 0.31, "lod": 32.0, "visual_forward_degrees": 180.0},
	"bandit_tracker": {"height": 1.70, "collision_height": 1.60, "collision_radius": 0.31, "lod": 32.0, "visual_forward_degrees": 180.0},
	"ghoulkin": {"height": 1.72, "collision_height": 1.65, "collision_radius": 0.34, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"ghoulkin_skeleton": {"height": 1.72, "collision_height": 1.65, "collision_radius": 0.34, "lod": 18.0, "skeleton_profile": "QuaterniusAnimatedMonster", "animation_profile": "AnimatedMonster_shared", "required_sockets": [], "visual_forward_degrees": 180.0},
	"wychwood_stalker": {"height": 1.66, "collision_height": 1.60, "collision_radius": 0.32, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"wychwood_raider": {"height": 1.72, "collision_height": 1.65, "collision_radius": 0.34, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"wychwood_brute": {"height": 1.90, "collision_height": 1.80, "collision_radius": 0.40, "lod": 20.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"bog_wretch": {"height": 1.60, "collision_height": 1.52, "collision_radius": 0.38, "lod": 16.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"gravebound_knight": {"height": 1.88, "collision_height": 1.78, "collision_radius": 0.38, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	# The retained Wolf source is authored along +X rather than the humanoid
	# +Z convention. A quarter-turn presents its face toward the actor target.
	"white_hart_avatar": {"height": 2.55, "collision_height": 2.25, "collision_radius": 0.58, "lod": 24.0, "required_sockets": [], "visual_forward_degrees": 180.0},
	# The finale Hart is a landmark creature. Keep the legacy avatar role for
	# old saves and interaction data, but normalize the released boss display to
	# one explicit focal height instead of applying a second runtime multiplier.
	# The Wolf source carries an authored local origin above its visible feet.
	# Preserve the measured source correction after rendered-bounds grounding so
	# the Hart's hooves meet the glade platform rather than floating above it.
	"white_hart_boss": {"height": 3.60, "collision_height": 3.30, "collision_radius": 0.78, "lod": 56.0, "ground_offset": 0.0, "required_sockets": [], "visual_forward_degrees": 180.0},
	"bell_eater": {"height": 2.35, "collision_height": 2.10, "collision_radius": 0.50, "lod": 22.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	# Bell-Eater is a focal creature, not a human-sized Ghoulkin. Its imported
	# cursed-human source is normalized directly to the encounter silhouette so
	# the rendered body and collision capsule stay in the same scale contract.
	"bell_eater_boss": {"height": 3.80, "collision_height": 3.60, "collision_radius": 0.82, "lod": 48.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	# Rootbound is a landmark-scale forest guardian. Normalize its connected
	# source once to the encounter height; identity dressing never multiplies it.
	"rootbound_colossus": {"height": 4.40, "collision_height": 4.10, "collision_radius": 1.05, "lod": 52.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"rootbound_colossus_boss": {"height": 4.40, "collision_height": 4.10, "collision_radius": 1.05, "lod": 52.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"ashwing": {"height": 2.40, "collision_height": 2.10, "collision_radius": 0.56, "lod": 24.0, "required_sockets": [], "visual_forward_degrees": 180.0, "airborne": true},
	"ashwing_boss": {"height": 4.80, "collision_height": 3.80, "collision_radius": 0.90, "lod": 56.0, "required_sockets": [], "visual_forward_degrees": 180.0, "airborne": true},
	"halvern_boss": {"height": 1.88, "collision_height": 1.78, "collision_radius": 0.38, "lod": 20.0, "required_sockets": ["head", "weapon"], "visual_forward_degrees": 180.0},
	"ghoulkin_creature": {"height": 1.72, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"wychwood_stalker_creature": {"height": 1.60, "collision_height": 1.48, "collision_radius": 0.30, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"wychwood_raider_creature": {"height": 2.05, "collision_height": 1.85, "collision_radius": 0.38, "lod": 22.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"wychwood_brute_creature": {"height": 1.92, "collision_height": 1.80, "collision_radius": 0.40, "lod": 22.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"ghoul_stalker_real": {"height": 1.72, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	# The derived cursed-human GLB is authored facing Godot -Z already. Keeping
	# the human 180-degree correction here made bosses turn their backs to Kael.
	"ghoul_brute_real": {"height": 1.90, "lod": 20.0, "required_sockets": ["head"], "visual_forward_degrees": 0.0},
	"bog_wretch_creature": {"height": 1.72, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	# The Gravebound source's visible face is on its imported +Z side. Keep the
	# actor's gameplay yaw authoritative, but rotate this mesh once so Halvern's
	# guard, face, and testimony stance face Kael instead of showing his back.
	"gravebound_knight_creature": {"height": 1.88, "lod": 18.0, "required_sockets": ["head"], "visual_forward_degrees": 180.0},
	"ashwing_creature": {"height": 2.40, "lod": 24.0, "required_sockets": [], "visual_forward_degrees": 180.0, "airborne": true},
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

static func encounter_camera_bounds(role_id: String) -> AABB:
	# Outward-rounded full idle/windup/attack/hit/death envelopes, validated
	# against the retained skinned sources by verify_large_encounter_frame.
	return {
		"rootbound_colossus_boss": AABB(Vector3(-1.94, -0.01, -2.73), Vector3(3.95, 4.42, 2.50)),
		"ashwing_boss": AABB(Vector3(-4.08, -0.09, -2.88), Vector3(7.27, 5.13, 5.17)),
		"white_hart_boss": AABB(Vector3(-2.48, -0.44, -2.73), Vector3(3.04, 3.39, 3.81)),
	}.get(role_id, AABB())

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
	return visual_forward_degrees(role_id)

static func visual_forward_degrees(role_id: String) -> float:
	var spec := for_role(role_id)
	# Keep the legacy accessor above while making the source-facing contract
	# explicit for every new runtime role.
	return float(spec.get("visual_forward_degrees", spec.get("facing_degrees", 0.0)))

static func ground_offset(role_id: String, fallback: float = 0.0) -> float:
	var spec := for_role(role_id)
	return float(spec.get("ground_offset", fallback))

static func is_airborne(role_id: String) -> bool:
	var spec := for_role(role_id)
	return bool(spec.get("airborne", false))

static func skeleton_profile(role_id: String, fallback: String = "unclassified") -> String:
	var spec := for_role(role_id)
	return str(spec.get("skeleton_profile", fallback))

static func animation_profile(role_id: String, fallback: String = "") -> String:
	var spec := for_role(role_id)
	return str(spec.get("animation_profile", fallback))

static func equipment_sockets(role_id: String) -> Dictionary:
	var spec := for_role(role_id)
	return (spec.get("equipment_sockets", {}) as Dictionary).duplicate(true)

static func required_sockets(role_id: String) -> Array[String]:
	var spec := for_role(role_id)
	var result: Array[String] = []
	for socket in spec.get("required_sockets", []):
		result.append(str(socket))
	return result

static func height_tolerance(role_id: String, fallback: float = 0.08) -> float:
	var spec := for_role(role_id)
	return float(spec.get("height_tolerance", fallback))
