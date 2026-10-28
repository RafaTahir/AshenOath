extends SceneTree
## User-authorized runtime inclusion must not manufacture visual review.
const Database = preload("res://scripts/asset_database.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var database := Database.new()
	root.add_child(database)
	_check(database.get_runtime_policy("ghoulkin_creature", "enemies").approved, "existing approved monster remains eligible")
	var role := "spectral_policy_fixture"
	var candidate := {"source_pack":"ashenoath_spectral_bestiary", "model":"res://assets_external/characters_universal/runtime/spectral/Ghoulkin_Spectral_Atlas.gltf", "approved":false, "visual_reviewed":false, "inclusion_authorized":true, "export_eligible":true, "authorization_kind":"user_requested_creation_and_in_game_application", "status":"spectral_inclusion_authorized_visual_review_pending"}
	database.runtime_acceptance.roles[role] = candidate
	var policy: Dictionary = database.get_runtime_policy(role, "enemies")
	_check(policy.approved and policy.inclusion_authorized and database.is_release_eligible(role), "explicit authorized spectral candidate is eligible")
	_check(not policy.visual_reviewed and not candidate.approved, "eligibility does not assert visual approval")
	candidate.inclusion_authorized = false
	_check(database.get_runtime_policy(role, "enemies").release_blocked and not database.is_release_eligible(role), "candidate without user inclusion stays blocked")
	candidate.inclusion_authorized = true
	candidate.export_eligible = false
	_check(database.get_runtime_policy(role, "enemies").release_blocked and not database.is_release_eligible(role), "export rejection is retained")
	candidate.export_eligible = true
	candidate.authorization_kind = ""
	_check(database.get_runtime_policy(role, "enemies").release_blocked, "missing explicit authorization kind stays blocked")
	candidate.authorization_kind = "user_requested_creation_and_in_game_application"
	candidate.source_pack = "unregistered_pack"
	_check(database.get_runtime_policy(role, "enemies").release_blocked, "unrelated source cannot borrow spectral authorization")
	candidate.source_pack = "ashenoath_spectral_bestiary"
	candidate.model = "res://assets_external/enemies/Skeleton.fbx"
	_check(database.get_runtime_policy(role, "enemies").release_blocked, "old source path cannot borrow spectral authorization")
	var unknown: Dictionary = database.get_runtime_policy("missing_policy_fixture", "enemies")
	_check(not unknown.known and unknown.release_blocked and not database.is_release_eligible("missing_policy_fixture"), "unknown required role remains blocked")
	database.free()
	print("SPECTRAL ASSET POLICY: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
