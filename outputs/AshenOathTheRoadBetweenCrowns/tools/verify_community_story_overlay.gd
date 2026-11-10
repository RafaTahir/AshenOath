extends SceneTree

const Overlay = preload("res://scripts/campaign_story_overlay.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
const State = preload("res://scripts/story_state.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Dialogue = preload("res://scripts/dialogue_manager.gd")
const Journal = preload("res://scripts/story_journal.gd")
const Text = preload("res://scripts/source_text.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var state = State.new()
	var quests = Quests.new()
	quests.load_quests("res://data/quests.json")
	quests.configure_campaign_revision(2)
	state.set_flag("campaign_revision",2)
	Overlay._data.clear()
	Text._community_loaded=false
	Text._community_strings.clear(); Text._community_ids.clear()
	var authored_community: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/community_campaign.json"))
	var ambient_text: String=str(authored_community.ending_ambient.concord.text)
	_check(Text.source_id(ambient_text)=="" and not Text._community_loaded,"Initial source localization does not decode community prose")
	_check(not Overlay.required_for("greyfen",state.flags,{}),"Initial expanded Greyfen has no community dependency")
	_check(Overlay.scene("white_hart",state,quests).is_empty() and Overlay._data.is_empty(),"Initial dialogue does not even decode the mounted overlay")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_campaign.json"))
	var base := Overlay.base_catalog(original)
	_check(Overlay.catalog(base,state)==base and Overlay._data.is_empty(),"Initial journal keeps compact graph without loading prose")
	for zone: String in ["greyfen","assembly","hart_glade","old_mill","undercroft","lantern_reach","hearthward"]:
		_check(Overlay.required_for(zone,{"campaign_revision":2},{"main_ash_at_the_mill":true}),"Expanded earned arrival requests story: "+zone)
		_check(not Overlay.required_for(zone,{}, {"main_ash_at_the_mill":true}),"Missing marker never infers expansion from earned content: "+zone)
		_check(not Overlay.required_for(zone,{"campaign_revision":1},{"main_empty_tables":true}),"Explicit legacy never requests overlay: "+zone)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Overlay.PATH))
	_check(Overlay.valid_payload(payload),"Generated complete overlay is valid")
	for key: String in ["scenes","catalog","ending_rituals","ending_cards","ending_ambient"]:
		var broken := payload.duplicate(true)
		broken[key]={}
		_check(not Overlay.valid_payload(broken),"Missing story section fails before journey mutation: "+key)
	for id: String in Overlay.SCENES:
		var broken := payload.duplicate(true)
		broken.scenes.erase(id)
		_check(not Overlay.valid_payload(broken),"Missing deferred scene fails readiness: "+id)
	state.set_flag("ashwing_defeated",true)
	quests.completed["main_ash_at_the_mill"]=true
	for id: String in Revision.NEW_CHAPTERS: quests.completed[id]=true
	state.set_flag("community_keeper_consent",{"anwen":true,"nessa":true,"vale":true})
	state.set_flag("community_route_ready",true)
	state.set_flag("community_refuge_ready",true)
	var before: Dictionary=quests.save_state().duplicate(true)
	var dialogue = Dialogue.new()
	dialogue.setup(state,quests)
	dialogue.load_dialogue("res://data/campaign_dialogue.json")
	dialogue.load_dialogue("res://data/interaction_scenes.json")
	_check(dialogue.get_dialogue("white_hart").actions.size()==6,"Ready expanded owner resolves six eligible choices")
	_check(dialogue.has_dialogue("aftermath_names_concord"),"Deferred aftermath becomes available after readiness")
	_check(Overlay.catalog(base,state)==original,"Journal overlay reconstructs exact authored catalog")
	_check(Text.source_id(ambient_text)=="community_campaign.ending_ambient.concord.text","Mounted story supplies stable deferred localization identity")
	_check(Overlay.ambient("concord","shrine_pilgrim",state)==ambient_text and Overlay.ambient("concord","mira",state)=="","Ambient text keeps its actual speaker contract")
	var projected := Overlay.scene("white_hart",state,quests)
	projected.actions.clear()
	_check(Overlay.scene("white_hart",state,quests).actions.size()==6,"Consumer cannot mutate the cached authoritative overlay")
	state.set_flag("campaign_revision",1)
	_check(dialogue.get_dialogue("white_hart").actions.size()==4,"Same manager returns original four after legacy restore")
	_check(not dialogue.has_dialogue("aftermath_names_concord"),"Mounted expansion scene is invisible to a legacy journey")
	_check(Overlay.catalog(base,state)==base,"Legacy journal never reuses expanded prose")
	_check(Journal.campaign_for(state).chapters.size()==10 and Journal.campaign_for(state).endings.size()==4,"Actual journal owner projects the original catalog")
	state.set_flag("campaign_revision",2)
	_check(dialogue.get_dialogue("white_hart").actions.size()==6,"Returning to expanded journey is idempotent")
	_check(quests.save_state()==before,"Story projection does not alter active/completed/objective state")
	dialogue.free(); state.free(); quests.free()
	print("COMMUNITY_STORY_OVERLAY %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		push_error(message)
