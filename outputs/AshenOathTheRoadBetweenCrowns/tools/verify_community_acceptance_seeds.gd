extends "res://tools/verify_replay_import_isolation.gd"
## Explicit boundary setup only. Reads the named gate's synthetic seed files,
## imports exclusively into memory, and writes one gate validation receipt.
const Revision=preload("res://scripts/campaign_revision.gd")
const Quests=preload("res://scripts/quest_manager.gd")
var seed_results: Array[Dictionary]=[]

func _run() -> void:
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-manifest="): path=arg.trim_prefix("--seed-manifest=").replace("\\","/").simplify_path()
	if not path.contains("/.release-gate/community-runtime/boundary-seeds-") or path.get_file()!="manifest.json":
		_check(false,"Explicit isolated boundary-seed manifest is required; no profile is consulted")
		quit(1); return
	OS.add_logger(error_log)
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("kind")!="synthetic_boundary_seed_inventory":
		_check(false,"Expected explicit synthetic seed inventory")
	else:
		_check(manifest.seeds.size()==9,"Nine labelled boundary cases")
		for row: Dictionary in manifest.seeds:
			var name := str(row.file)
			if name.contains("/") or name.contains("\\") or not name.ends_with(".json"):
				_check(false,"Seed path cannot leave the named gate"); continue
			_verify_seed(path.get_base_dir().path_join(name),row)
	await process_frame
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(),"No parser/runtime errors")
	var receipt := {"kind":"synthetic_boundary_native_validation","status":"pass" if failures.is_empty() else "fail","checks":checks,"failures":failures,"errors":error_log.errors,"world_loaded":false,"storage":"in_memory","seeds":seed_results,"full_campaign_proof":false}
	var file := FileAccess.open(path.get_base_dir().path_join("native_validation.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(receipt,"\t")); file.close()
	else: _check(false,"Validation receipt writes only beside the explicit seed manifest")
	print("COMMUNITY ACCEPTANCE SEEDS: %s checks=%d storage=in_memory world=none" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _verify_seed(path: String, row: Dictionary) -> void:
	var before := failures.size()
	_check(FileAccess.get_sha256(path)==str(row.sha256),"Exact frozen seed bytes: "+str(row.case))
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(raw.acceptance_fixture.synthetic==true and raw.acceptance_fixture.full_campaign_proof==false,"Synthetic provenance is explicit")
	var manager := MemorySaveManager.new()
	root.add_child(manager)
	_check(manager.import_save_text(JSON.stringify(raw),"manual_1"),"Real save validator accepts boundary seed")
	var loaded: Dictionary=manager._read_slot(manager.slot_path("manual_1")).get("data",{})
	_check(not loaded.is_empty(),"Imported seed is readable from memory")
	if not loaded.is_empty():
		_check(Revision.from_save(loaded)==(1 if str(row.case).begins_with("legacy_") else 2),"Revision retained without inference")
		_check(loaded.story_state.flags.has("campaign_revision")==raw.story_state.flags.has("campaign_revision"),"Missing legacy marker stays missing")
		_check(loaded.journey_id==raw.journey_id and loaded.replay_session==false,"Explicit campaign identity retained")
		_check(loaded.zone==raw.zone and loaded.world_sector==raw.world_sector and loaded.player_position==raw.player_position and loaded.world_position==raw.world_position,"Boundary position retained")
		var loaded_keys: Array=loaded.story_state.flags.keys()
		var source_keys: Array=raw.story_state.flags.keys()
		loaded_keys.sort(); source_keys.sort()
		_check(loaded_keys==source_keys,"Import retains exactly the declared synthetic flags")
		for key: String in raw.story_state.flags:
			var expected: Variant=raw.story_state.flags[key]
			var actual: Variant=loaded.story_state.flags.get(key)
			_check(actual==expected and (typeof(actual) in [TYPE_INT,TYPE_FLOAT] if typeof(expected) in [TYPE_INT,TYPE_FLOAT] else typeof(actual)==typeof(expected)),"Imported flag retains its recorded value: "+key)
		var quests := Quests.new()
		quests.load_quests("res://data/quests.json")
		_check(quests.configure_campaign_revision(Revision.from_save(loaded)),"Actual quest owner accepts this revision")
		quests.load_state(loaded.quests)
		var completed_ids: Array=quests.completed.keys()
		var expected_ids: Array=row.initial_completed.duplicate()
		completed_ids.sort(); expected_ids.sort()
		_check(completed_ids==expected_ids,"Actual quest sanitation preserves exactly the supplied history")
		_check(quests.active.keys()==[str(row.active_chapter)],"Only the expected next chapter is active")
		for objective: Dictionary in quests.active.get(str(row.active_chapter),{}).get("objectives",[]):
			_check(objective.done==false,"The boundary chapter has no pre-earned objective")
		quests.free()
	seed_results.append({"case":row.case,"sha256":row.sha256,"passed":failures.size()==before,"initial_completed":row.initial_completed,"active_chapter":row.active_chapter})
	manager.queue_free()
