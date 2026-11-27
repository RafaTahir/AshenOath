extends SceneTree
## Integration of the campaign graph, real scene receipts and save codec.
## World actions enter as objective receipts. Rendered input has a separate driver.
const Quest = preload("res://scripts/quest_manager.gd")
const Story = preload("res://scripts/story_state.gd")
const Edition = preload("res://scripts/novel/novel_campaign.gd")
const Scenes = preload("res://scripts/novel/novel_scenes.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
const Codec = preload("res://scripts/models/save_payload_codec.gd")
const Ending = preload("res://scripts/community_ending.gd")
var catalog: Dictionary = {}
var failures: Array[String] = []
var checks := 0
var saves := 0

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	for act in range(1,5):
		for scene: Dictionary in Scenes._book(act): catalog[scene.id]=scene
	for route: String in ["witness","mercy","duty","ash","concord","open_road"]:
		replay(route,["mercy","ash","open_road"].has(route))
	print("NOVEL JOURNEYS: 6 route projections, %d codec restores, %d checks, %d failures"%[saves,checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func perform(id: String, quests: Node, state: Node, alternate: bool) -> void:
	var scene: Dictionary = catalog[id]
	if not Scenes.matches_rule(scene.when,state,quests):
		expect(false,"closed entry into "+id)
		return
	for i in scene.beats.size():
		var beat := Scenes.resolve_beat(scene.beats[i],state,quests)
		if not Scenes.matches_rule(beat.get("when",{}),state,quests):
			expect(false,"closed step "+id+" "+str(i))
			return
		var options: Array = []
		for option: Dictionary in beat.get("choices",[]):
			if Scenes.matches_rule(option.get("when",{}),state,quests): options.append(option)
		var selected: Dictionary = {} if options.is_empty() else options[-1 if alternate else 0]
		expect(Edition.record_step(state,quests,scene,beat,selected,i),"performed "+id+" "+str(i))
		expect(not Edition.record_step(state,quests,scene,beat,selected,i),"duplicate ignored "+id)
	expect(state.get_flag("novel_done_"+id,false),"result "+id)

func restore(quests: Node, state: Node, zone: String) -> void:
	var raw := {"version":Codec.CURRENT_VERSION,"zone":zone,"player_position":[1.0,1.0,2.0],"quests":quests.save_state(),"story_state":state.save_state()}
	var decoded := Codec.migrate(JSON.parse_string(JSON.stringify(raw)))
	if decoded.is_empty():
		expect(false,"codec rejected "+zone)
		return
	var resumed := Story.new()
	resumed.load_state(decoded.story_state)
	var resumed_quests := Quest.new()
	resumed_quests.load_quests("res://data/quests.json")
	resumed_quests.configure_campaign_revision(Revision.from_save(decoded),Edition.saved_edition(decoded))
	resumed_quests.load_state(decoded.quests)
	var before: Dictionary = JSON.parse_string(JSON.stringify(state.save_state().flags))
	var after: Dictionary = JSON.parse_string(JSON.stringify(resumed.save_state().flags))
	if before != after:
		for key: String in before.merged(after):
			if before.get(key) != after.get(key): print("RESTORE DIFFERENCE ",key," ",before.get(key)," -> ",after.get(key))
	expect(after==before,"retained facts in "+zone)
	expect(resumed_quests.completed==quests.completed and resumed_quests.active.keys()==quests.active.keys(),"retained chapter and successors")
	state.load_state(resumed.save_state())
	quests.load_state(resumed_quests.save_state())
	resumed.free()
	resumed_quests.free()
	saves+=1

func replay(route: String, alternate: bool) -> void:
	var state := Story.new()
	var quests := Quest.new()
	quests.load_quests("res://data/quests.json")
	quests.configure_campaign_revision(2,true)
	state.set_flag("campaign_revision",2)
	state.set_flag("novel_edition",1)
	expect(quests.start_quest("main_road_of_crows"),"new journey")
	for chapter: String in Revision.EXPANDED_CHAPTERS:
		if not quests.is_active(chapter):
			expect(false,route+" failed to unlock "+chapter)
			break
		if chapter == "main_road_of_crows": state.set_flag("evidence_report","private" if alternate else "public")
		if chapter == "main_soldier_without_banner": state.set_flag("senn_fate","exile" if alternate else "testimony")
		if chapter == "main_last_witness": state.set_flag("halvern_fate","released" if alternate else "witness")
		for objective: Dictionary in quests.quest_defs[chapter].objectives:
			if objective.id.begins_with("novel_") or objective.get("optional",false): continue
			if quests.is_choice_objective(chapter,objective.id): quests.complete_choice(chapter,objective.id)
			else: quests.complete_objective(chapter,objective.id)
		for id: String in Edition.REQUIRED.get(chapter,{}):
			expect(quests.is_active(chapter),"chapter waits for "+id)
			expect(not quests.complete_evidence(chapter,"novel_"+id),"discovery cannot perform "+id)
			perform(id,quests,state,alternate)
		expect(quests.is_completed(chapter),"completed "+chapter)
		if chapter in ["main_teeth_in_rain","main_ash_at_the_mill","main_house_many_names"]:
			restore(quests,state,"greyfen")
	expect(Ending.chooses_to_stay("rook",state),"Rook controls his own departure")
	# Boundary between the established ending enactment and the new spring projection.
	# The two ferry acceptance fixtures exercise Open Road's physical enactment.
	state.set_flag("final_covenant",route)
	for ending: String in ["witness","mercy","duty","ash","concord","open_road"]:
		expect(not Scenes.matches_rule(catalog["spring_"+ending].when,state,quests),"spring waits for actual completion")
	state.set_flag("final_choice_completed",true)
	for ending: String in ["witness","mercy","duty","ash","concord","open_road"]:
		expect(Scenes.matches_rule(catalog["spring_"+ending].when,state,quests)==(ending==route),"exclusive spring "+ending)
	perform("spring_"+route,quests,state,alternate)
	expect(state.get_flag("novel_spring_route")==route,"spring identity "+route)
	expect(not Scenes.matches_rule(catalog.old_gate_memory.when,state,quests),"a departed witness cannot be recalled")
	quests.free()
	state.free()
