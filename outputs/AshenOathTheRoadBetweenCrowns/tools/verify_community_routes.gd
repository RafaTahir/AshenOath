extends SceneTree

const Sectors = preload("res://scripts/world_sector_manifest.gd")
const Revision = preload("res://scripts/campaign_revision.gd")
const Router = preload("res://scripts/zone_composition_router.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")
const State = preload("res://scripts/story_state.gd")
const Quests = preload("res://scripts/quest_manager.gd")
const Community = preload("res://scripts/community_campaign.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var legacy := State.new()
	var expanded := State.new()
	expanded.set_flag("campaign_revision",2)
	var quests := Quests.new()
	quests.load_quests("res://data/quests.json")
	quests.configure_campaign_revision(2)
	for pair: Array in [["old_mill","lantern_reach","main_empty_tables"],["undercroft","hearthward","main_house_many_names"]]:
		var source := str(pair[0])
		var target := str(pair[1])
		_check(target not in Sectors.neighbors(source,legacy),"legacy hides neighbor "+target)
		_check(target in Sectors.neighbors(source,expanded),"expanded topology includes "+target)
		for edge: Dictionary in Sectors.connections(source,legacy): _check(str(edge.target)!=target,"legacy geometry excludes branch "+target)
		var edge := Sectors.connection_between(source,target)
		_check(not edge.is_empty(),"registered physical branch "+target)
		_check(not Sectors.edge_available(edge,quests,legacy),"legacy cannot cross authored branch")
		_check(not Sectors.edge_available(edge,quests,expanded),"expanded branch waits for its chapter")
		quests.unlocked[str(pair[2])]=true
		_check(Sectors.edge_available(edge,quests,expanded),"chapter unlock makes route available")
		var reverse := Sectors.connection_between(target,source)
		_check(Sectors.edge_available(reverse,quests,expanded),"return remains available")
		_check(not Sectors.edge_available(reverse,quests,legacy),"legacy cannot enter through reverse side")
		var points := Sectors.connector_points(edge)
		_check(points.size()>=2,"physical route has a centerline")
		for point: Vector3 in points: _check(point.is_finite(),"finite route coordinates")
		_check(Sectors.crossing_transform(reverse)*Sectors.crossing_transform(edge)==Transform3D.IDENTITY or (Sectors.crossing_transform(reverse)*Sectors.crossing_transform(edge)).is_equal_approx(Transform3D.IDENTITY),"two-way crossing transforms round trip")
		_check(Router.resource_paths(target)==[Router.COMMUNITY_BUILDER_PATH],"new destination uses deferred dedicated builder")
		_check(Router.COMMUNITY_BUILDER_PATH not in Router.resource_paths(source),"old builder does not preload expansion")
		var script := load(Router.builder_path(target)) as Script
		var builder = script.new() if script != null and script.can_instantiate() else null
		_check(builder != null and builder.step_count(target) == 5,"dedicated builder has five callable construction steps for "+target)
	var old_atlas := Sectors.atlas(1)
	var new_atlas := Sectors.atlas(2)
	for id: String in Revision.NEW_ZONES:
		_check(not old_atlas.positions.has(id) and new_atlas.positions.has(id),"atlas projects journey identity")
	for edge: Dictionary in old_atlas.links:
		_check(str(edge.source) not in Revision.NEW_ZONES and str(edge.target) not in Revision.NEW_ZONES,"legacy atlas has no expansion link")
	for quest: String in Revision.NEW_CHAPTERS:
		for objective: String in Revision.OBJECTIVES[quest]:
			var route := Routes.for_objective(quest,objective,expanded,quests)
			_check(not route.is_empty() and str(route.destination_zone) in Revision.NEW_ZONES,"authored objective has directions")
	expanded.set_flag("community_route","ferry")
	var route := Routes.for_objective("main_road_kept_open","secure_route",expanded,quests)
	_check(route.target_ids==["community:work:ferry_landing","community:work:ferry_rope","community:work:ferry_load"],"ferry directions stay on selected tasks")
	expanded.set_flag("community_work:ferry_rope",true)
	route=Routes.for_objective("main_road_kept_open","secure_route",expanded,quests)
	_check("community:work:ferry_rope" not in route.target_ids,"completed task drops from navigation")
	expanded.set_flag("community_route_load_carried",true)
	route=Routes.for_objective("main_road_kept_open","open_route",expanded,quests)
	_check(route.target_ids==["community:ferry"],"load asks player to board before delivery")
	expanded.set_flag("community_route_load_crossed",true)
	route=Routes.for_objective("main_road_kept_open","open_route",expanded,quests)
	_check(route.target_ids==["community:delivery"],"crossed load points to actual delivery")
	_check(Revision.from_state(legacy)==Revision.LEGACY,"new-journey switch cannot upgrade legacy saves")
	if "--require-expansion" in OS.get_cmdline_user_args():
		_check(Revision.new_journey_revision()==Revision.EXPANDED,"combined release enables expanded new journeys")
	for actor: String in ["vale","merrow"]:
		var speaker := "vargan_record_keeper" if actor=="vale" else "vargan_steward"
		_check(preload("res://scripts/story_performance.gd").speaker_matches(actor,speaker),"canonical speaker alias drives actual facial delivery")
		_check(not preload("res://scripts/story_performance.gd").speaker_matches(actor,"narrator"),"narrator cannot animate a participant's mouth")
	expanded.set_flag("senn_fate","testimony")
	expanded.set_flag("edric_stance","cooperate")
	expanded.set_flag("escort_abandonment_acknowledged",true)
	var present: Dictionary = {}
	for minutes in [420.0,1079.99,1080.0,419.99]:
		var count := 0
		for actor: String in Community.REGIONAL_ACTORS.hearthward:
			if Community.actor_present(actor,"hearthward",minutes,expanded,quests):
				count+=1
				present[actor]=true
		_check(count<=8,"shift leaves room for Kael and Bracken under ten visible skeletons")
	_check(present.size()==12,"both shifts retain access to all twelve eligible canonical people")
	_check(Community.presence_shift(420)=="morning" and Community.presence_shift(1080)=="evening","existing rest waits land exactly on the intended shift")
	_check(not Community.actor_present("senn","hearthward",1080,legacy,quests),"shift cannot introduce a legacy actor")
	for failure: String in failures: printerr("COMMUNITY ROUTES: "+failure)
	print("COMMUNITY ROUTES: %s checks=%d (graph and builder steps, no world/input claim)" % ["PASS" if failures.is_empty() else "FAIL",checks])
	legacy.free(); expanded.free(); quests.free()
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
