extends RefCounted

const Rules = preload("res://scripts/community_campaign.gd")
const Ending = preload("res://scripts/community_ending.gd")
const FERRY_PATH := "CommunityWork/PublicRoute_ferry/Ferry"
const PASSENGER_SEATS := [Vector3(-0.42,0.25,-0.43), Vector3(0.25,0.25,-0.43), Vector3(-0.42,0.25,0.43), Vector3(0.25,0.25,0.43)]
var director: Node
var game
var zone := ""
var cohort_drivers: Array[Node] = []
var rescue_cast: Node3D
var rescue_visuals: Dictionary = {}

func _ferry_landing(dock: String) -> Vector3:
	return game.zone_root.to_global(Vector3(10.5 if dock=="east" else 3.0,0.02,1.5))

func _novel_rescue_active() -> bool:
	return Ending.novel_departure(game.story_state) and Ending.journey_open(game.story_state)

func _refresh_rescue_cast() -> void:
	var state = game.story_state
	var delivered := Rules._true(state,"open_road_route_delivered")
	var visible := Rules._true(state,"open_road_relocation_started") and ((zone=="lantern_reach" and not delivered) or (zone=="hearthward" and delivered))
	if not visible:
		if is_instance_valid(rescue_cast): rescue_cast.queue_free()
		rescue_cast = null
		return
	var manifest := Ending.departure_manifest(state)
	if manifest.is_empty(): return
	if not is_instance_valid(rescue_cast):
		rescue_cast = Node3D.new()
		rescue_cast.name = "OpenRoadRescue"
		game.zone_root.add_child(rescue_cast)
		for group: Dictionary in manifest.groups:
			var household := Node3D.new()
			household.name = str(group.id)
			rescue_cast.add_child(household)
			for index: int in group.members.size():
				var id := str(group.members[index])
				var role := "villager_human" if id == "siv_father" else "villager_female_human"
				var height := 1.0
				match id:
					"bera_child_1": height = 0.68
					"bera_child_2": height = 0.56
				_add_rescue_actor(household,id,str(group.labels[index]),role,height)
		if zone == "lantern_reach": _add_rescue_actor(rescue_cast,"ferryman","Ferryman","villager_human")
	var boat := game.zone_root.get_node_or_null(FERRY_PATH) as Node3D
	if boat != null and boat.is_in_group("open_road_in_transit"): return
	for group: Dictionary in manifest.groups:
		var household := rescue_cast.get_node(str(group.id)) as Node3D
		var bera := str(group.id) == "bera"
		if zone == "hearthward":
			household.position = Vector3(-8.8,0,3.0) if bera else Vector3(-7.0,0,3.0)
		elif bool(group.arrived):
			household.position = Vector3(11.2,0,-1.3 if bera else 1.1)
		else:
			household.position = Vector3(1.9,0,1.1 if bera else -1.5)
		for index: int in household.get_child_count():
			household.get_child(index).position = Vector3((index % 2)*0.72,0,0.65 if index >= 2 else 0.0)
	var ferryman := rescue_cast.get_node_or_null("ferryman") as Node3D
	if ferryman != null:
		var dock := Ending.departure_dock(state)
		ferryman.position = Vector3(10.4 if dock=="east" else 2.6,0,-0.45)

func _add_rescue_actor(parent: Node3D, id: String, label_text: String, role: String, height: float = 1.0) -> void:
	if not rescue_visuals.has(role):
		rescue_visuals[role] = load("res://scripts/community_presentation.gd").rescue_passenger_visual(game,role)
	var visual: PackedScene = rescue_visuals[role]
	if visual == null: return
	var body := Node3D.new()
	body.name = id
	body.rotation.y = -PI/2.0
	body.scale = Vector3.ONE * height
	parent.add_child(body)
	body.add_child(visual.instantiate())
	var label := Label3D.new()
	label.text = label_text
	label.position.y = 1.92
	label.font_size = 21
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 7.0
	body.add_child(label)

func _rescue_cast_ready() -> bool:
	if not is_instance_valid(rescue_cast): return false
	for group: Dictionary in Ending.NOVEL_GROUPS:
		var household := rescue_cast.get_node_or_null(str(group.id))
		if household == null or household.get_child_count() != int(group.passengers): return false
	return zone != "lantern_reach" or rescue_cast.has_node("ferryman")

func _place_rescue_aboard(boat: Node3D, leg: Dictionary) -> void:
	var ferryman := rescue_cast.get_node("ferryman") as Node3D
	ferryman.global_position = boat.to_global(Vector3(-0.72,0.25,0))
	if int(leg.passengers) == 0: return
	var household := rescue_cast.get_node(str(leg.group)) as Node3D
	household.global_position = boat.global_position
	for index: int in household.get_child_count():
		household.get_child(index).position = PASSENGER_SEATS[index]

func _passage_safe() -> bool:
	return is_instance_valid(game.player) and game.player.can_control and not game.player.transition_locked and float(game.player.health_component.health)>0 and float(game.player.hurt_react_time)<=0 and not game._journey_load_pending() and not game.zone_transition_pending and not game.zone_load_request_pending and game.pending_player_restore.is_empty() and not director._danger_near(game)

static func _position(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _cohort_motion(velocity: Vector3) -> void:
	for driver: Node in cohort_drivers:
		if is_instance_valid(driver): driver.set_locomotion_motion(velocity,true)
