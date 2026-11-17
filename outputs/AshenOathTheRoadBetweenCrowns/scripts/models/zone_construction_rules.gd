extends RefCounted

static func palette_color(key: String) -> Color:
	const COLORS = {
		"rock": Color(0.17, 0.18, 0.16),
		"trunk": Color(0.16, 0.095, 0.055),
		"leaves": Color(0.055, 0.15, 0.075),
		"roof": Color(0.13, 0.055, 0.035),
		"wall": Color(0.30, 0.22, 0.15),
		"grave": Color(0.30, 0.31, 0.30),
		"shrine": Color(0.37, 0.38, 0.35),
		"ground": Color(0.11, 0.10, 0.07),
		"wood": Color(0.16, 0.09, 0.045),
		"metal": Color(0.44, 0.44, 0.42),
		"cloth": Color(0.11, 0.12, 0.13),
		"skin": Color(0.66, 0.52, 0.40),
		"monster": Color(0.15, 0.20, 0.14)
	}
	return COLORS.get(key, Color(0.24, 0.24, 0.22))
## Deterministic construction classifications; no scene or story mutation.
static func _visual_role_for_legacy_character(role_name: String, authored_role: String = "") -> String:
	if authored_role != "":
		return authored_role
	var roles = {
		"player_kael": "player_human",
		"sister_anwen": "sister_anwen_human",
		"mira_herbalist": "mira_human",
		"rook_smuggler": "rook_human",
		"widow_elna": "villager_female_human",
		"blacksmith_tor": "villager_worker_human",
		"generic_villager_01": "villager_human",
		"lord_edric": "castle_guard_human",
		"castle_guard": "castle_guard_human",
		"vargan_gate_guard": "castle_guard_human",
		"vargan_record_keeper": "villager_worker_human",
		"vargan_steward": "villager_worker_human",
		"vargan_servant": "villager_female_human",
		"vargan_patrol": "road_ranger_human",
		"edric_castle": "castle_guard_human",
		"edric_campaign": "castle_guard_human",
		"halvern_boss": "halvern_boss",
		"road_ranger": "road_ranger_human"
	}
	return str(roles.get(role_name, ""))
static func _role_for_interactable(id: String, authored_role: String = "") -> String:
	if id.begins_with("design_ecology:"):
		return id.trim_prefix("design_ecology:")
	if authored_role != "":
		return authored_role
	var roles = {
		"sister_anwen": "sister_anwen",
		"mira": "mira_herbalist",
		"rook": "rook_smuggler",
		"widow_elna": "widow_elna",
		"blacksmith_tor": "blacksmith_tor",
		"farmer_toma": "generic_villager_01",
		"returned_soldier": "returned_soldier",
		"edric": "castle_guard",
		"vargan_gate_guard": "castle_guard",
		"vargan_record_keeper": "castle_guard",
		"vargan_steward": "vargan_steward",
		"vargan_servant": "vargan_servant",
		"vargan_patrol": "vargan_patrol",
		"edric_castle": "edric_castle",
		"edric_campaign": "edric_campaign",
		"captain_senn": "road_ranger",
		"halvern": "halvern_boss",
		"white_hart": "white_hart_avatar",
		"witness_-7": "mira_herbalist",
		"witness_-3": "rook_smuggler",
		"witness_3": "sister_anwen"
	}
	return str(roles.get(id, ""))
static func _world_prop_spec(id: String) -> Dictionary:
	return {
		"notice_board": {"kind": "notice_board", "state_key": "greyfen_prop:notice_board"},
		"village_well": {"kind": "well", "state_key": "greyfen_well_state"},
		"forge_corner": {"kind": "forge", "state_key": "greyfen_prop:forge_corner"},
		"shrine_prayer": {"kind": "shrine", "state_key": "shrine_prayer_state"},
		"common_table": {"kind": "table", "state_key": "common_table_state"},
		"barrel_board": {"kind": "table", "state_key": "barrel_board_state"},
		"vargan_ledger_choice": {"kind": "ledger", "state_key": "vargan_ledger_state"},
	}.get(id, {})
static func _prop_requires_collision(lower_name: String) -> bool:
	return lower_name.contains("wall") or lower_name.contains("fence") or lower_name.contains("rail") \
		or lower_name.contains("post") or lower_name.contains("door") or lower_name.contains("gate") \
		or lower_name.contains("tower") or lower_name.contains("stable") or lower_name.contains("house") \
		or lower_name.contains("building") or lower_name.contains("bridge") or lower_name.contains("berm")
static func _is_first_route_clearance(zone_id: String, pos: Vector3, radius: float = 0.0) -> bool:
	if zone_id == "greyfen":
		if abs(pos.x) < 2.85 + radius and pos.z > -15.8 and pos.z < 13.4:
			return true
		if pos.x > 1.2 - radius and pos.x < 7.0 + radius and pos.z > -8.8 - radius and pos.z < -3.8 + radius:
			return true
	elif zone_id == "wychwood":
		if abs(pos.x) < 3.15 + radius and pos.z > -13.2 and pos.z < 14.2:
			return true
		if abs(pos.x) < 4.4 + radius and pos.z > -9.8 and pos.z < -3.0:
			return true
	return false
static func _keep_performance_light(name: String) -> bool:
	return name in ["Village Warmth", "Shrine Beacon", "Wychwood Gate Lantern", "Moon Shaft", "Trail Threat", "ClearingColdSpot", "SpawnWarmRead", "AshMillFacadeFill", "BanditWarmLantern", "LedgerTableLight", "RecordHallNavigationFill", "RecordHallEntryFill", "RecordHallArchiveFill", "HartWitnessLight", "HartAftermathLight", "UndercroftNavigationFill", "UndercroftHalvernFill"]
static func _first_route_palette_key(combined: String) -> String:
	if combined.contains("roof"):
		return "roof"
	if combined.contains("house") or combined.contains("wall") or combined.contains("plaster"):
		return "wall"
	if combined.contains("tree") or combined.contains("trunk"):
		return "trunk"
	if combined.contains("leaf") or combined.contains("leaves") or combined.contains("crown"):
		return "leaves"
	if combined.contains("rock") or combined.contains("rubble") or combined.contains("stone") or combined.contains("pathstone"):
		return "rock"
	if combined.contains("grave"):
		return "grave"
	if combined.contains("shrine"):
		return "shrine"
	if combined.contains("fence") or combined.contains("wood") or combined.contains("cart") or combined.contains("crate") or combined.contains("barrel") or combined.contains("torch"):
		return "wood"
	if combined.contains("road") or combined.contains("mud") or combined.contains("ground") or combined.contains("berm"):
		return "ground"
	if combined.contains("cloth") or combined.contains("cloak") or combined.contains("robe"):
		return "cloth"
	if combined.contains("skin") or combined.contains("face") or combined.contains("sister") or combined.contains("npc") or combined.contains("villager"):
		return "skin"
	if combined.contains("ghoul") or combined.contains("monster") or combined.contains("enemy"):
		return "monster"
	if combined.contains("metal") or combined.contains("sword") or combined.contains("blade"):
		return "metal"
	return ""
