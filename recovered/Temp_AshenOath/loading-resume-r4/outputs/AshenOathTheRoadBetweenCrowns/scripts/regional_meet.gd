extends RefCounted

const Cast=preload("res://scripts/story_cast_profile.gd")
const DEFINITIONS := {
	"greyfen":{"game":"tic_tac_toe","actor":"rook","name":"Greyfen Three Marks","point":Vector3(-5.4,0,12.6)},
	"wychwood":{"game":"archery","actor":"toma","name":"Wychwood steady hands","point":Vector3(6.8,0,12.7)},
	"old_mill":{"game":"draughts","actor":"tor","name":"The mill workers' draughts","point":Vector3(-4.5,0,11.8)},
	"bandit_road":{"game":"archery","actor":"rook","name":"Long Road marks","point":Vector3(6.8,0,12.7)},
	"vargan_approach":{"game":"chess","actor":"merrow","name":"The waiting-room chess meet","point":Vector3(-4.4,0,10.6)},
	"ruins":{"game":"draughts","actor":"mira","name":"The stoneworkers' draughts","point":Vector3(-1.2,0,5.8)}
}

static func install(service) -> void:
	var zone:=str(service.host.current_zone_id)
	if not DEFINITIONS.has(zone):return
	var definition:Dictionary=DEFINITIONS[zone]
	if str(definition.game)=="archery":
		load("res://scripts/greyfen_archery_range.gd").install_regional(service.host)
	else:
		var marker:Node3D=service.point_action("meet",str(definition.name),definition.point)
		service.box(marker,Vector3(0.7,0.06,0.7),Vector3(0,0.72,0),Color(0.28,0.20,0.13),true)
		for x in [-0.28,0.28]:
			for z in [-0.28,0.28]:service.box(marker,Vector3(0.06,0.7,0.06),Vector3(x,0.35,z))
		for x in 6:
			for z in 6:service.box(marker,Vector3(0.09,0.01,0.09),Vector3((x-2.5)*0.1,0.76,(z-2.5)*0.1),Color(0.63,0.59,0.43) if (x+z)%2==0 else Color(0.16,0.21,0.2))

static func open(service) -> void:
	var host=service.host
	var zone:=str(host.current_zone_id)
	if not DEFINITIONS.has(zone) or host._story_has_active_combat():return
	var data:Dictionary=host.story_state.get_flag("regional_meet:"+zone,{"round":0,"wins":0})
	var round_index:=clampi(int(data.get("round",0)),0,3)
	var actions:Array=[{"type":"close","label":"Leave the meet"}]
	if round_index<3:actions.push_front({"type":"everyday_action","operation":"meet","label":"Play round %d of three"%[round_index+1],"region":zone})
	else:actions.push_front({"type":"everyday_action","operation":"meet_rematch","label":"Start a new three-round meet","region":zone})
	service.show_actions(str(DEFINITIONS[zone].name),"No entry fee. Three rounds, with increasing difficulty. Two coin for the first completed meet, two more for the first series victory. No other table prizes, XP or Honor.\n\nRounds finished: %d. Wins: %d."%[round_index,int(data.get("wins",0))],actions)

static func start(service,region:String) -> void:
	var host=service.host
	if region!=str(host.current_zone_id) or not DEFINITIONS.has(region) or host._story_has_active_combat():return
	var definition:Dictionary=DEFINITIONS[region]
	if host.player.global_position.distance_to(definition.point)>3.0:return
	var data:Dictionary=host.story_state.get_flag("regional_meet:"+region,{"round":0,"wins":0})
	var round_index:=int(data.get("round",0))
	if round_index<0 or round_index>=3:return
	if str(definition.game)=="archery":
		var range_node:Node=host.zone_root.get_node_or_null("GreyfenArcheryRange")
		if range_node!=null:range_node.start_meet(region,round_index)
		return
	var actor:Node3D=Cast.registered_actor(host.zone_root,str(definition.actor))
	if not is_instance_valid(actor) or not actor.is_visible_in_tree():
		host.hud.toast("The opponent is not available in this state of the region. Your rounds are kept.")
		return
	var controller:Node=service.life()
	if controller!=null:controller.request_table_visit(str(actor.get("interaction_id")),definition.point+Vector3(0,0,-0.85))
	if actor.global_position.distance_to(definition.point)>3.5:
		host.hud.toast("They are walking to the table. Speak at the marker when they arrive.")
		return
	var person:=str({"tor":"blacksmith_tor"}.get(str(definition.actor),str(definition.actor)))
	host.minigames.open_game(str(definition.game),person,region,round_index)

static func record_result(host,region:String,round_index:int,outcome:String) -> void:
	if not DEFINITIONS.has(region) or outcome not in ["win","loss","draw"]:return
	var key:="regional_meet:"+region
	var data:Dictionary=host.story_state.get_flag(key,{"round":0,"wins":0}).duplicate(true)
	if int(data.get("round",0))!=round_index or round_index>=3:return
	data.round=round_index+1
	data.wins=int(data.get("wins",0))+(1 if outcome=="win" else 0)
	host.story_state.set_flag(key,data)
	if int(data.round)==3:
		for reward:String in (["complete","victory"] if int(data.wins)>=2 else ["complete"]):
			var claim:="regional_meet:"+reward+":"+region
			if not bool(host.story_state.get_flag(claim,false)):
				host.story_state.set_flag(claim,true)
				host.inventory.add_reward({"coin":2})
		host.hud.toast("Meet complete: %d of three won. The once-only prize is recorded."%[int(data.wins)])
	else:host.hud.toast("Round recorded. Return to the meet marker for the next round.")
	host.story_save_pending=true
	host.call_deferred("_persist_story_action")

static func rematch(service,region:String) -> void:
	var host=service.host
	if region!=str(host.current_zone_id) or not DEFINITIONS.has(region) or host._story_has_active_combat():return
	if host.player.global_position.distance_to(DEFINITIONS[region].point)>3.0:return
	if int(host.story_state.get_flag("regional_meet:"+region,{}).get("round",0))<3:return
	for round_index in 3:host.minigames.sessions.erase("meet:"+region+":"+str(round_index))
	host.story_state.set_flag("regional_meet:"+region,{"round":0,"wins":0})
	service.persist()
	open(service)
