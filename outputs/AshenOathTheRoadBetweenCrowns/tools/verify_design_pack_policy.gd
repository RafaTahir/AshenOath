extends SceneTree
## Actual database decisions only; no character/model instantiation or imports.
const Database = preload("res://scripts/asset_database.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var database := Database.new()
	root.add_child(database)
	for role: String in ["player_human", "ghoulkin_creature", "bracken_companion"]:
		var acceptance: Dictionary = database.get_runtime_acceptance(role)
		var before := acceptance.duplicate(true)
		var policy: Dictionary = database.get_runtime_policy(role, "characters")
		_check(policy.inclusion_authorized and database.is_release_eligible(role) and not policy.release_blocked, "Current registered role lost explicit inclusion: " + role)
		_check(not policy.visual_reviewed and not acceptance.approved and not acceptance.user_accepted, "Current candidate inclusion claimed visual/user approval")
		_check(database.get_runtime_acceptance(role) == before, "Database mutated source acceptance metadata")
	var role := "design_policy_fixture"
	var candidate := {"source_pack":"AshenOath_32_Asset_Design_Pack_v1", "model":"res://assets_external/design_pack_v1/humans/P01_Kael.glb",
		"approved":false, "visual_reviewed":false, "user_accepted":false, "inclusion_authorized":true, "export_eligible":true,
		"authorization_kind":"user_requested_live_roster_release", "status":"user_authorized_release_candidate"}
	for kind: String in ["user_requested_blender_cast_replacement", "user_requested_live_roster_release"]:
		var accepted := candidate.duplicate(true)
		accepted.authorization_kind = kind
		database.runtime_acceptance.roles[role] = accepted
		var policy: Dictionary = database.get_runtime_policy(role, "enemies")
		_check(policy.inclusion_authorized and policy.approved and not policy.release_blocked, "Valid design authorization kind was rejected")
		_check(not policy.visual_reviewed and not accepted.approved and not accepted.user_accepted, "Eligible candidate was relabelled visually approved")
	for change: Array in [["inclusion_authorized",false],["inclusion_authorized","true"],["inclusion_authorized",1],
			["export_eligible",false],["export_eligible","true"],["export_eligible",1],
			["authorization_kind",""],["authorization_kind","unregistered"],["source_pack","other"],
			["approved","false"],["visual_reviewed",1],
			["model","res://assets_external/characters/Old.glb"], ["model","res://assets_external/design_pack_v1/../Other.glb"],
			["model","res://assets_external/design_pack_v1/humans/./Other.glb"], ["model","res://assets_external/design_pack_v1//Other.glb"],
			["model","res://assets_external/design_pack_v1/Other.fbx"]]:
		var rejected := candidate.duplicate(true)
		rejected[change[0]] = change[1]
		database.runtime_acceptance.roles[role] = rejected
		var policy: Dictionary = database.get_runtime_policy(role, "enemies")
		_check(policy.release_blocked and not database.is_release_eligible(role), "Invalid design authorization escaped its guard: " + str(change))
	_check(database.get_runtime_policy("missing_required_fixture", "enemies").release_blocked, "Unknown required role became eligible")
	database.free()
	for failure in failures:
		printerr("DESIGN PACK POLICY: " + failure)
	print("DESIGN PACK POLICY: %s checks=%d (actual database; no art/world; visual review remains pending)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures.append(label)
