extends SceneTree

const Quest = preload("res://scripts/quest_manager.gd")
const Story = preload("res://scripts/story_state.gd")
const Atlas = preload("res://scripts/world_sector_manifest.gd")
const Codec = preload("res://scripts/models/save_payload_codec.gd")
const Fields = preload("res://scripts/models/save_payload_fields.gd")
const Novel = preload("res://scripts/core/novel/novel_campaign.gd")
const Scenes = preload("res://scripts/views/novel/novel_scenes.gd")
const Accounts = preload("res://scripts/core/novel/road_account.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
var failures: Array[String] = []
var checks := 0

func expect(truth: bool, description: String) -> void:
	checks += 1
	if not truth:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	var quests := Quest.new()
	quests.load_quests("res://data/quests.json")
	var state := Story.new()
	state.set_flag("campaign_revision",2)
	state.set_flag("novel_edition",1)
	expect(quests.configure_campaign_revision(2,true),"new edition quest projection")
	var chapters: Dictionary = {0:true}
	var ids: Dictionary = {}
	var options := 0
	var steps := 0
	for act in range(1,5):
		var rows := Scenes._book(act)
		expect(not rows.is_empty(),"mounted act "+str(act))
		for scene: Dictionary in rows:
			expect(not ids.has(scene.id),"unique scene "+scene.id)
			ids[scene.id]=scene
			chapters[int(scene.chapter)]=true
			check_gates(scene.get("when",{}),quests.quest_defs)
			for i in scene.beats.size():
				var beat: Dictionary=scene.beats[i]
				expect(str(beat.zone) in Atlas.all_ids(),"mapped sector "+str(beat.zone))
				expect(beat.has("actor") != beat.has("at"),"one physical or living actor anchor "+scene.id)
				check_gates(beat.get("when",{}),quests.quest_defs)
				for choice: Dictionary in beat.get("choices",[]):
					options += 1
					check_gates(choice.get("when",{}),quests.quest_defs)
				state.set_flag("novel_step_"+str(scene.id),i)
				var route := Scenes.route(state,"novel_"+str(scene.id))
				expect(route.get("next_action")==beat.prompt and route.get("destination_zone")==beat.zone,"guidance "+str(scene.id)+" "+str(i))
				steps += 1
	expect(chapters.size()==38,"the full literary span is represented")
	for q: String in Novel.REQUIRED:
		var listed: Array=quests.quest_defs[q].objectives.map(func(o):return o.id)
		for id: String in Novel.REQUIRED[q]:
			expect(ids.has(id) and listed.count("novel_"+id)==1,"required scene belongs once to an existing quest: "+id)
	expect(quests.quest_defs.saga_var_q03.title=="Three Marks at the Garden Gate","Toma petitions for the workers")
	expect(quests.configure_campaign_revision(2),"existing expansion remains loadable")
	expect(quests.quest_defs.saga_var_q03.title=="The Prisoner's Garden","older garden account")
	expect(not str(quests.quest_defs.main_ash_at_the_mill.objectives).contains("novel_tor_wrist"),"existing expansion has original objectives")
	expect(quests.configure_campaign_revision(1),"classic edition remains loadable")
	expect(not quests.quest_defs.has("main_empty_tables"),"classic graph preserved")
	for zone: String in Atlas.all_ids():
		var local := Vector3(1.375,1.0,-3.25)
		var a := Fields._local_to_world([local.x,local.y,local.z],zone)
		expect(Atlas.world_to_local(zone,Vector3(a[0],a[1],a[2])).is_equal_approx(local),"save position round-trip "+zone)
	for zone: String in ["assembly","hearthward","lantern_reach"]:
		var legacy := [49.0,1.0,402.0] if zone=="assembly" else [1.0,1.0,2.0]
		var data := {"version":14,"zone":zone,"world_sector":zone,"world_position":legacy,"player_position":[1.0,1.0,2.0],"story_state":{"flags":{"campaign_revision":2}}}
		var decoded := Codec.migrate(data)
		expect(decoded.world_position==Fields._local_to_world(data.player_position,zone),"released save recovery "+zone)
		expect(not Novel.saved_edition(decoded),"migration creates no literary history")
		var distinct := legacy.duplicate()
		distinct[0]+=2.0
		data.world_position=distinct
		expect(Codec.migrate(data).world_position==distinct,"nonmatching coordinates retained "+zone)
	state.set_flag("novel_private_letter","sealed")
	var echo := Story.new()
	echo.load_state(state.save_state())
	expect(echo.get_flag("novel_private_letter")=="sealed","private custody survives save")
	expect(not echo.has_evidence("novel:archive_wire"),"save does not invent a later comparison")
	var first := Accounts.detail(echo,"vargan_wire",{})
	echo.record_evidence("novel:archive_wire",{"kind":"observed"})
	var late := Accounts.detail(echo,"vargan_wire",{})
	expect(first.sections[1].body != late.sections[1].body,"wire interpretation changes only with later proof")
	for ending: String in ["witness","mercy","duty","ash","concord","open_road"]:
		var spring: Dictionary=ids.get("spring_"+ending,{})
		expect(not spring.is_empty() and spring.when.flags.final_covenant==ending and spring.when.flags.final_choice_completed==true,"spring gates on enacted "+ending)
	print("NOVEL MODEL checks=%d scenes=%d steps=%d choices=%d chapters=%d failures=%d"%[checks,ids.size(),steps,options,chapters.size(),failures.size()])
	state.free()
	echo.free()
	quests.free()
	quit(0 if failures.is_empty() else 1)

func check_gates(gates: Dictionary,defs: Dictionary) -> void:
	for quest: String in gates.get("complete",[])+gates.get("before",[])+([gates.quest] if gates.has("quest") else []):
		expect(defs.has(quest),"existing quest gate "+quest)
	for pair: Array in gates.get("objectives",[]):
		expect(defs.has(pair[0]) and defs[pair[0]].objectives.any(func(o):return o.id==pair[1]),"existing objective "+str(pair))
