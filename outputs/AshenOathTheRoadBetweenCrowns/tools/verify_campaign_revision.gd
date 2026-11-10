extends "res://tools/verify_replay_import_isolation.gd"
## Synthetic graph, real value owners and memory-only save storage. No world,
## scene, actor, model, renderer capture, or persistent save is loaded.

const CampaignConfig = preload("res://scripts/campaign_revision.gd")
const Endings = preload("res://scripts/ending_catalog.gd")
const QuestRuntime = preload("res://scripts/quest_manager.gd")
const StoryRuntime = preload("res://scripts/story_state.gd")
const Ritual = preload("res://scripts/covenant_resolution.gd")
const Epilogue = preload("res://scripts/epilogue_resolver.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")
const DialogueRuntime = preload("res://scripts/dialogue_manager.gd")

func _run() -> void:
	OS.add_logger(error_log)
	for wrapped: bool in [false, true]:
		for flag_case: String in ["replay", "campaign", "missing", "malformed"]:
			_verify_import(wrapped, flag_case)
	_verify_revision_saves()
	_verify_graphs()
	_verify_endings()
	await process_frame
	OS.remove_logger(error_log)
	_check(error_log.errors.is_empty(), "No engine or script errors")
	for error: String in error_log.errors:
		print("CAMPAIGN REVISION ENGINE ERROR: " + error)
	print("CAMPAIGN REVISION: %s checks=%d storage=in_memory world=none" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _definitions() -> Dictionary:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for id: String in CampaignConfig.NEW_CHAPTERS:
		var objectives: Array = []
		for key: String in CampaignConfig.OBJECTIVES[id]:
			objectives.append({"id":key, "text":"Synthetic " + key})
		definitions[id] = {"title":"Synthetic " + id, "type":"main", "objectives":objectives, "unlocks":[]}
	return definitions

func _verify_revision_saves() -> void:
	var manager := MemorySaveManager.new()
	root.add_child(manager)
	var legacy := _payload("legacy-marker-missing")
	legacy.quests.active["main_empty_tables"] = {"objectives":[]}
	var original := JSON.stringify(legacy)
	var migrated: Dictionary = manager.migrate_save_data(legacy)
	_check(CampaignConfig.from_save(migrated) == 1, "Missing marker stays legacy even with new chapter name")
	_check(not migrated.story_state.flags.has("campaign_revision"), "Legacy migration does not insert marker or disturb existing Continue payload identity")
	_check(JSON.stringify(legacy) == original, "Migration never mutates source bytes")
	_check(CampaignConfig.new_journey_revision() == (2 if CampaignConfig.EXPANSION_ENABLED else 1), "New Journey revision follows explicit release switch")
	for replay: bool in [false, true]:
		for ending: String in ["share", "depart"]:
			var payload := _payload("expanded-portable")
			payload.story_state.flags.campaign_revision = 2
			payload.replay_session = replay
			payload.zone = "lantern_reach"
			payload.world_sector = "hearthward"
			payload.world_state.pending_ending = Endings.covenant(ending)
			payload.quests.active["main_empty_tables"] = {"objectives":[{"id":"prepare_kitchen", "done":true}]}
			_check(manager.import_save_text(JSON.stringify({"format":"ashen-oath-save", "save":payload}), "manual_1"), "Expanded import accepted")
			var restored: Dictionary = manager._read_slot(manager.slot_path("manual_1")).data
			_check(CampaignConfig.from_save(restored) == 2, "Expanded marker survives import/read/migration")
			_check(restored.replay_session == replay and restored.journey_id == payload.journey_id, "Revision retains replay and identity")
			_check(restored.zone == "lantern_reach" and restored.world_sector == "hearthward", "New regions retained")
			_check(restored.world_state.pending_ending == ending, "New pending ending alias retained")
			_check(restored.quests.active.has("main_empty_tables"), "Expanded active chapter survives migration")
	for value: Variant in [3, "2", true, -1, 1.5]:
		var bad := _payload("invalid-revision")
		bad.story_state.flags.campaign_revision = value
		var before := JSON.stringify(manager.files)
		_check(not manager.import_save_text(JSON.stringify(bad), "manual_1"), "Unsupported revision rejected: " + str(value))
		_check(before == JSON.stringify(manager.files), "Rejected revision preserves existing memory slots")
	manager.queue_free()

func _verify_graphs() -> void:
	var source := _definitions()
	var frozen := JSON.stringify(source)
	_check(CampaignConfig.has_complete_expansion(source), "Exact four objective contracts accepted")
	var missing := source.duplicate(true)
	missing.main_empty_tables.objectives.pop_back()
	_check(not CampaignConfig.has_complete_expansion(missing), "Incomplete required chapter rejected")
	for revision: int in [1, 2]:
		var quests := QuestRuntime.new()
		quests.quest_defs = source.duplicate(true)
		_check(quests.configure_campaign_revision(revision), "Graph configured: " + str(revision))
		var chapters := CampaignConfig.chapter_ids(revision)
		_check(chapters.size() == (14 if revision == 2 else 10), "Journey chapter count")
		_check(quests.start_quest(chapters[0]), "First quest starts")
		for index in chapters.size():
			var id: String = chapters[index]
			_check(quests.is_active(id), "Actual completion owner activated " + id)
			for objective: Dictionary in quests.active[id].objectives:
				objective.done = true
			quests._try_complete_quest(id)
			_check(quests.is_completed(id), "Chapter completed once: " + id)
			if index + 1 < chapters.size():
				_check(quests.is_active(chapters[index + 1]), "Successor follows selected graph")
		for id: String in CampaignConfig.NEW_CHAPTERS:
			_check(quests.quest_defs.has(id) == (revision == 2), "New chapter visibility obeys journey revision")
		var saved := quests.save_state()
		quests.load_state(saved)
		_check(quests.completed.size() == chapters.size(), "All selected chapter IDs survive load sanitization")
		quests.free()
	_check(JSON.stringify(source) == frozen, "Projections leave authored definitions unchanged")
	var unavailable := QuestRuntime.new()
	unavailable.quest_defs = missing
	_check(not unavailable.configure_campaign_revision(2), "Incomplete graph cannot replace current journey projection")
	unavailable.free()

func _verify_endings() -> void:
	var state := StoryRuntime.new()
	var quests := QuestRuntime.new()
	quests.quest_defs = _definitions()
	quests.configure_campaign_revision(2)
	for id: String in CampaignConfig.NEW_CHAPTERS:
		quests.completed[id] = true
	for id: String in Endings.ORIGINAL_IDS:
		_check(Endings.available(id, state, quests), "Original ending remains available to legacy")
	_check(not Endings.available("share", state, quests) and not Endings.available("depart", state, quests), "Legacy does not gain new alternatives")
	state.set_flag("campaign_revision", 2)
	state.set_flag("community_route_ready", true)
	state.set_flag("community_refuge_ready", true)
	_check(Endings.available("depart", state, quests), "Open Road requires completed physical work")
	state.flags["community_refuge_ready"] = "true"
	_check(not Endings.available("depart", state, quests), "Truthy strings are not physical completion")
	state.flags["community_refuge_ready"] = true
	_check(not Endings.record_keeper_consent(state, "sister_anwen", true), "Consent requires canonical participant identity")
	_check(not Endings.available("share", state, quests), "Completed quests never manufacture consent")
	for actor: String in ["anwen", "nera", "vale"]:
		_check(Endings.record_keeper_consent(state, actor, true), "Participant explicitly accepts: " + actor)
		_check(Endings.available("share", state, quests) == (actor == "vale"), "All three keeper groups must be represented")
	_check(Endings.record_keeper_consent(state, "nera", false), "Consent can be withdrawn before lock")
	_check(not Endings.available("share", state, quests), "Withdrawal immediately removes Concord")
	Endings.record_keeper_consent(state, "nessa", true)
	_check(Endings.available("share", state, quests), "Another explicit participant may keep that role")
	var dialogue := DialogueRuntime.new()
	dialogue.setup(state, quests)
	var actions: Array = []
	for id: String in Endings.IDS + ["invented"]:
		actions.append({"type":"ending", "ending":id, "text":"Choose " + id})
	dialogue.dialogues["synthetic_covenant"] = {"name":"Synthetic fixture", "actions":actions}
	_check(dialogue.get_dialogue("synthetic_covenant").actions.size() == 6, "Expanded eligible UI offers six known endings")
	Endings.record_keeper_consent(state, "vale", false)
	_check(dialogue.get_dialogue("synthetic_covenant").actions.size() == 5, "UI rechecks withdrawal")
	Endings.record_keeper_consent(state, "vale", true)
	state.set_flag("campaign_revision", 1)
	_check(dialogue.get_dialogue("synthetic_covenant").actions.size() == 4, "Legacy UI retains original four")
	state.set_flag("campaign_revision", 2)
	dialogue.free()
	quests.completed.erase("main_empty_tables")
	_check(not Endings.available("share", state, quests) and not Endings.available("depart", state, quests), "Both alternatives require all four chapters")
	quests.completed.main_empty_tables = true
	state.set_flag("final_covenant", "concord")
	_check(not Endings.record_keeper_consent(state, "vale", false), "Locked ending preserves its recorded agreement")
	var headings: Dictionary = {}
	for id: String in Endings.IDS:
		_check(Endings.normalize(Endings.covenant(id)) == id, "Six IDs round trip: " + id)
		var cards := Epilogue.resolve(id, state)
		_check(not cards.is_empty(), "Known ending has consequence cards")
		headings[cards[0].split("\n")[0]] = true
		if Endings.is_peaceful(id):
			_check(Ritual.steps_for(id,state).size() == 3, "Peaceful ending has three restorable steps")
			state.set_flag("final_covenant", Endings.covenant(id))
			state.set_flag("covenant_ritual_started", true)
			for step in range(3):
				state.set_flag("covenant_ritual_step", step)
				var guidance := Routes.ending_continuation(state, "hart_glade")
				_check(guidance.target_ids == ["covenant_%s_%d" % [id, step]], "Reload guidance names actual ritual step")
	_check(headings.size() == 6, "Six distinct consequence identities")
	_check(Endings.normalize("invented") == "" and not Endings.available("invented", state, quests), "Unknown ending is rejected")
	_check(Epilogue.resolve("invented", state).is_empty(), "Unknown ending never defaults to Witness")
	state.free()
	quests.free()
