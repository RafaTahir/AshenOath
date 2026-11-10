extends SceneTree

const Grips = preload("res://tools/living_activity_grip_compile.gd")
const EVIDENCE := "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/equipment/bread_grips_r1/Anwen/fit_receipt.json"
const FUSION = preload("res://scripts/character_animation_fusion.gd")
const NATIVE := "art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/equipment/bread_grips_r1/Anwen/pose_receipt.json"
const MODEL := "res://assets_external/design_pack_v1/humans/C01_Anwen.glb"
const PREPARED := "res://assets_external/characters_prepared/opening/389b6010725c3e16267ca9af.scn"
const LIFE := "res://assets_external/characters_prepared/animations/life_C01.res"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var repository := ""
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("--repository="):
			repository = option.trim_prefix("--repository=")
	if repository.is_empty() or not FileAccess.file_exists(repository.path_join(EVIDENCE)) \
			or not FileAccess.file_exists(repository.path_join(NATIVE)):
		push_error("Supply the repository containing the measured Anwen grip evidence")
		quit(1)
		return
	var folder := ProjectSettings.globalize_path("user://activity_grip_compile_fixture")
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Use a fresh disposable activity grip fixture profile")
		quit(1)
		return
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("hand_l")
	var library := (load(LIFE) as AnimationLibrary).duplicate(true) as AnimationLibrary
	var actor := (load(PREPARED) as PackedScene).instantiate() as Node3D
	var player := FUSION.attach_shared_library(actor)
	var motion_hash := str(library.get_meta("source_sha256"))
	_check(Grips.apply(library, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).is_empty(),
		"optional missing source does not alter the retained library")
	_check(not library.has_meta("activity_prop_grips"), "missing evidence installs no grip")
	var path := folder.path_join("activity_grips.json")
	var record := {
		"schema_version": 1,
		"asset": "C01",
		"motion_sha256": motion_hash,
		"model_sha256": FileAccess.get_sha256(MODEL),
		"fits": {"bread": {"evidence": EVIDENCE, "evidence_sha256": FileAccess.get_sha256(repository.path_join(EVIDENCE)), "native_pose_evidence": NATIVE}},
	}
	_write_json(path, record)
	var result := Grips.apply(library, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player)
	_check(result.get("sha256", "") == FileAccess.get_sha256(path), "compiled library binds the exact authored receipt")
	var grips: Dictionary = library.get_meta("activity_prop_grips", {})
	_check(grips.keys() == ["bread"], "only the measured style is compiled")
	var grip: Dictionary = grips.get("bread", {})
	_check(grip.get("verified") == true and grip.get("bone") == "hand_l", "Anwen uses her free left hand")
	_check(grip.get("palm") is Vector3 and grip.get("anchor") is Vector3 and grip.get("basis") is Basis,
		"compiler writes the existing runtime metadata types")
	var resource_path := "user://activity_grip_compile_fixture/proof.res"
	_check(ResourceSaver.save(library, resource_path) == OK, "compiled metadata serializes with the library")
	var reloaded := ResourceLoader.load(resource_path, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	_check(reloaded != null and reloaded.get_meta("activity_prop_grips", {}) == grips, "saved metadata reopens without a conversion")
	var unapproved := library.duplicate(true) as AnimationLibrary
	unapproved.remove_meta("activity_prop_grips")
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", "", MODEL, PREPARED, player).has("error"), "stale motion source fails")
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, "", PREPARED, player).has("error"), "stale body source fails")
	var other := Skeleton3D.new()
	other.add_bone("hand_r")
	_check(Grips.apply(unapproved, other, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).has("error"), "missing retained hand fails")
	other.free()
	var evidence: Dictionary = record.fits.bread
	var digest := str(evidence.evidence_sha256)
	evidence.evidence_sha256 = FileAccess.get_sha256(MODEL)
	_write_json(path, record)
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).has("error"), "stale fit bytes fail")
	evidence.evidence_sha256 = digest
	evidence.native_pose_evidence = EVIDENCE
	_write_json(path, record)
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).has("error"),
		"fit must bind the exact native pose evidence")
	evidence.native_pose_evidence = NATIVE
	_write_json(path, record)
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, MODEL, MODEL, player).has("error"),
		"same actor evidence cannot replace the measured prepared scene")
	var altered := unapproved.get_animation("Life_Idle_A")
	altered.length += 0.125
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).has("error"),
		"changing sampled life animation rejects a re-signed receipt")
	evidence.evidence = "art_source/../" + EVIDENCE
	_write_json(path, record)
	_check(Grips.apply(unapproved, skeleton, repository, folder, "C01", motion_hash, MODEL, PREPARED, player).has("error"), "evidence traversal fails")
	_check(not unapproved.has_meta("activity_prop_grips"), "failed calibration never installs a partial grip")
	skeleton.free()
	actor.free()
	for failure: String in failures:
		printerr(failure)
	print("ACTIVITY GRIP COMPILE: %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _write_json(path: String, data: Dictionary) -> void:
	var stream := FileAccess.open(path, FileAccess.WRITE)
	if stream == null:
		_check(false, "cannot write disposable fixture receipt")
		return
	stream.store_string(JSON.stringify(data) + "\n")
	stream.close()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
