extends Node

## Optional presentation owned by StoryActivities. StoryState retains durable facts.
const Cast = preload("res://scripts/story_cast_profile.gd")
const Presence = preload("res://scripts/character_presence.gd")
const Scenes = preload("res://scripts/story_world_scenes.gd")
var host
var content: Dictionary = {}
var social_cooldowns: Dictionary = {}
var joinable: Dictionary = {}
var personal_offer_generation := 0
var personal_offers: Dictionary = {}
var ecology: Array[Dictionary] = []
var decision_elapsed := 0.0
var pending_assets: Dictionary = {}
var work: Dictionary = {}
var meal: Dictionary = {}
var presentation: Node
var keepsake_shelf: Node3D
var surrender_targets: Array[Dictionary]=[]
const FISHING := {
	"greyfen":{"bank":Vector3(-8,0,8),"water":Vector3(-8,0.08,5.1)},
	"wychwood":{"bank":Vector3(-7,0,3.6),"water":Vector3(-7,0.08,0.8)},
	"marsh_crossing":{"bank":Vector3(-5.8,0,7.3),"water":Vector3(-8,0.05,8.4)}
}
const MEALS := ["grilled_fish", "fish_broth", "bread_supper"]

static func current(game) -> Node:
	return game.zone_root.get_node_or_null("StoryActivities/EverydayLife") if is_instance_valid(game.zone_root) else null

static func install(game, parent: Node) -> void:
	if parent.get_node_or_null("EverydayLife") != null: return
	var owner = load("res://scripts/everyday_life.gd").new()
	owner.name = "EverydayLife"
	owner.host = game
	parent.add_child(owner)
	owner.configure()

func configure() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/everyday_life.json"))
	if parsed is Dictionary: content = parsed
	host.vendor_service.clock = host.day_night
	if host.runtime_packs != null:
		host.runtime_packs.pack_ready.connect(_assets_ready)
		host.runtime_packs.pack_failed.connect(_assets_failed)
	for scene: Dictionary in Scenes.data().get("scenes", []):
		if str(scene.zone) != str(host.current_zone_id) or not scene.has("activity_point"): continue
		var point: Array = scene.activity_point
		point_action("work:" + str(scene.id), str(scene.activity_prompt), Vector3(point[0], point[1], point[2]))
	if str(host.current_zone_id) in ["greyfen", "wychwood", "old_mill", "bandit_road", "vargan_approach", "ruins"]:
		point_action("stone", "Take a loose stone", Vector3(-3.8, 0, 10.4), true)
	if str(host.current_zone_id) in ["greyfen", "old_mill"]:
		point_action("kitchen", "Prepare a meal at the kitchen", Vector3(-1,0,7.6) if str(host.current_zone_id) == "greyfen" else Vector3(-5.6,0,10.2))
	if FISHING.has(str(host.current_zone_id)):
		point_action("fish","Borrow the bank rod",FISHING[str(host.current_zone_id)].bank)
	if str(host.current_zone_id) == "greyfen":
		keepsake_shelf = point_action("keepsakes","Arrange keepsakes",Vector3(-2.2,0,11.8))
		box(keepsake_shelf,Vector3(1.65,0.1,0.48),Vector3(0,0.76,0),Color(0.28,0.20,0.13),true)
		for x in [-0.7,0.7]: box(keepsake_shelf,Vector3(0.09,0.72,0.09),Vector3(x,0.36,0.1))
		for index in 6:
			var slot := point_action("keepsake_slot:"+str(index),"Arrange keepsake "+str(index+1),keepsake_shelf.position+Vector3((index%3-1)*0.48,0.78,-0.12+0.24*(index/3)))
			slot.set_meta("slot",index)
			box(slot,Vector3(0.4,0.015,0.18),Vector3.ZERO,Color(0.24,0.29,0.25))
	presentation = load("res://scripts/everyday_world_presentation.gd").new()
	add_child(presentation)
	presentation.configure(self)
	if is_instance_valid(keepsake_shelf) and not host.story_state.get_flag("everyday_display",{}).is_empty():
		if OS.has_feature("web") and not host.runtime_packs.is_ready("leisure"):
			host.runtime_packs.request_pack("leisure",30)
	preload("res://scripts/regional_meet.gd").install(self)
	for enemy in host.active_enemies:
		if not is_instance_valid(enemy) or not bool(enemy.get_meta("ordinary_surrender_eligible",false)):continue
		var area:Node3D=point_action("surrender","Accept surrender",enemy.global_position)
		area.reparent(enemy,true)
		area.position=Vector3.ZERO
		area.set_meta("interaction_collision_owner",NodePath(".."))
		area.set_interaction_enabled(false)
		surrender_targets.append({"enemy":weakref(enemy),"area":weakref(area)})
	for area in host.interaction_focus.registered_nearby(host.player.global_position, host.zone_root, 500.0):
		if area.has_meta("design_ecology"):
			ecology.append({"actor":weakref(area), "elapsed":0.0, "phase":-1, "visible_time":0.0, "event_clip":"", "event_phase":-1.0})
			var ambient: Node = area.find_child("NpcAmbient", true, false)
			if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED

func life() -> Node:
	for id: String in ["GreyfenLifeController", "RegionalLifeController"]:
		var controller: Node = host.zone_root.get_node_or_null(id)
		if controller != null: return controller
	return null

func append_topics(actor: Node3D, dialogue: Dictionary) -> void:
	var identity := Cast.canonical_identity(str(actor.get("interaction_id")))
	if identity == "" or not content.get("voices", {}).has(identity): return
	var actions: Array = dialogue.get_or_add("actions", [])
	var controller := life()
	if controller != null:
		var scene: Dictionary = controller.joinable_world_conversation(actor)
		if not scene.is_empty(): joinable[actor.get_instance_id()] = scene
	actions.append({"type":"everyday_action", "operation":"social_menu", "actor":actor.get_instance_id(), "label":"A moment, apart from business."})

func choose(action: Dictionary) -> void:
	host._resume_game()
	if str(action.get("operation", "")) == "cancel_assets":
		pending_assets.clear()
		return
	if str(action.get("operation","")) in ["meet","meet_rematch"]:
		if str(action.operation)=="meet":preload("res://scripts/regional_meet.gd").start(self,str(action.get("region","")))
		else:preload("res://scripts/regional_meet.gd").rematch(self,str(action.get("region","")))
		return
	if str(action.get("operation", "")) in ["cook", "eat", "reflect", "reflection_choice"]:
		choose_rest_activity(action)
		return
	if str(action.get("operation","")) == "fishing":
		var area := instance_from_id(int(action.get("station",0))) as Node3D
		if not safe_station(area) or not FISHING.has(str(host.current_zone_id)): return
		if not ensure_assets(action): return
		var fishing = load("res://scripts/fishing_activity.gd").new()
		add_child(fishing)
		if not fishing.begin(self,area,FISHING[str(host.current_zone_id)].water):
			fishing.queue_free()
			host.hud.toast("Six fresh fish fit in your pack. Cook or sell some before borrowing the rod again.")
		return
	if str(action.get("operation","")) == "keepsake":
		if not is_instance_valid(keepsake_shelf) or keepsake_shelf.global_position.distance_to(host.player.global_position)>3.0: return
		var slot := int(action.get("slot",-1))
		var id := str(action.get("keepsake",""))
		if slot<0 or slot>=6 or (id!="" and not bool(host.story_state.get_flag("everyday_favour:"+id,false))):return
		if not ensure_assets(action):return
		var placed: Dictionary = host.story_state.get_flag("everyday_display",{}).duplicate()
		for key in placed.keys():
			if str(placed[key])==id:placed.erase(key)
		placed[str(slot)]=id
		host.story_state.set_flag("everyday_display",placed)
		presentation.refresh_keepsakes()
		persist()
		return
	var actor := instance_from_id(int(action.get("actor", 0))) as Node3D
	if not valid_actor(actor): return
	var identity := Cast.canonical_identity(str(actor.get("interaction_id")))
	var operation := str(action.get("operation", ""))
	if operation == "favour":
		for favour: Dictionary in content.get("favours",[]):
			if str(favour.id)!=str(action.get("favour","")) or not favour_available(favour,identity):continue
			var supplies: Dictionary = host.inventory.get(str(favour.kind))
			if int(supplies.get(str(favour.item),0))<1:
				host.hud.toast("You do not have that supply to spare.")
				return
			host.story_state.set_flag("everyday_favour:"+str(favour.id),true)
			supplies[str(favour.item)]=int(supplies[str(favour.item)])-1
			host.inventory.changed.emit()
			host.story_state.record_evidence("everyday_keepsake:"+str(favour.id),{"title":favour.title,"kind":"observed","source":identity,"zone":host.current_zone_id,"text":favour.reply})
			speak(actor,"I can spare this for the work.",str(favour.reply),"favour:"+str(favour.id))
			host.hud.toast(str(favour.title)+" kept for the Greyfen shelf. No XP or Honor awarded.")
			persist()
		return
	if operation == "request_scene":
		var scene_id := str(action.get("scene", ""))
		if int(action.get("scene_generation", -1)) != personal_offer_generation or int(personal_offers.get(scene_id, 0)) != actor.get_instance_id(): return
		# Recheck the current actor, conditions and bound props after menu closure.
		# A stale menu cannot claim another actor or a now-unavailable scene.
		var offered: Dictionary = {}
		for scene: Dictionary in Scenes.data().get("scenes", []):
			if str(scene.id) == scene_id and Scenes.requestable_for(scene, host, actor):
				offered = scene
				break
		personal_offers.clear()
		personal_offer_generation += 1
		if offered.is_empty(): return
		var controller := life()
		if controller != null and not controller.request_world_scene(scene_id):
			host.hud.toast("Their work or the road needs attention first. Ask again when they are free.")
		return
	if operation == "social_menu":
		open_social(actor, identity)
		return
	if operation == "inspect":
		if not ensure_assets(action): return
		for object: Dictionary in content.get("objects", []):
			if str(object.id) != str(action.get("object", "")) or str(object.zone) != str(host.current_zone_id) or str(object.actor) != identity: continue
			var viewer = load("res://scripts/object_inspection.gd").new()
			add_child(viewer)
			viewer.finished.connect(func(): host._resume_game())
			if not viewer.open(host, object):
				viewer.queue_free()
				host.hud.toast("This object could not be prepared. Its owner's possessions are unchanged.")
				return
			host.story_state.set_flag("everyday_inspected:" + str(object.id), true)
			persist()
		return
	if operation == "join":
		var controller := life()
		if controller != null: controller.join_world_conversation(actor, joinable.get(actor.get_instance_id(), {}))
		return
	if operation == "rumour":
		for rumour: Dictionary in content.get("rumours", []):
			if str(rumour.zone) == str(host.current_zone_id) and str(rumour.actor) == identity:
				host.story_state.record_evidence("everyday_rumour:" + str(rumour.id), {"title":"An unconfirmed account", "kind":"testimony", "source":identity, "zone":host.current_zone_id, "text":rumour.claim})
				speak(actor, "What have you heard?", str(rumour.claim), "rumour:" + str(rumour.id))
				persist()
		return
	var voices: Dictionary = content.get("voices", {}).get(identity, {})
	if not voices.has(operation): return
	if operation == "apology":
		var controller := life()
		if controller == null or not controller.repair_minor_friction(actor):
			host.hud.toast("Give them room and lower the weapon first.")
			return
	var openings := {"greet":"Good to see you.", "reassure":"Could you use some company?", "joke":"Is there any good news?", "work":"What are you working on?", "apology":"I was in your way. I'm sorry."}
	speak(actor, str(openings.get(operation, "")), str(voices[operation]), operation)

func valid_actor(actor: Node3D) -> bool:
	return is_instance_valid(actor) and host.zone_root.is_ancestor_of(actor) and actor.is_visible_in_tree() and actor.global_position.distance_to(host.player.global_position) <= 4.0 and Presence.can_see(host.player, actor, 4.0) and not host._story_has_active_combat() and not host.zone_transition_pending

func open_social(actor: Node3D, identity: String) -> void:
	if not valid_actor(actor): return
	personal_offer_generation += 1
	personal_offers.clear()
	var actions: Array = []
	var labels := {"greet":"Greet", "reassure":"Offer company", "joke":"Share a lighter moment", "work":"Ask about work", "apology":"Apologize for crowding them"}
	var controller := life()
	for favour: Dictionary in content.get("favours",[]):
		if favour_available(favour,identity):
			actions.append({"type":"everyday_action","operation":"favour","actor":actor.get_instance_id(),"favour":favour.id,"label":favour.request})
	for kind: String in labels:
		if not content.voices[identity].has(kind): continue
		if kind == "apology" and (controller == null or not controller.has_minor_friction(actor)): continue
		if kind in ["joke", "reassure"] and bool(host.story_state.honor_view(identity).get("grievance", false)): continue
		actions.append({"type":"everyday_action", "operation":kind, "actor":actor.get_instance_id(), "label":labels[kind]})
	if controller != null and joinable.has(actor.get_instance_id()):
		actions.append({"type":"everyday_action", "operation":"join", "actor":actor.get_instance_id(), "label":"Join their conversation"})
	for rumour: Dictionary in content.get("rumours", []):
		if str(rumour.zone) == str(host.current_zone_id) and str(rumour.actor) == identity:
			actions.append({"type":"everyday_action", "operation":"rumour", "actor":actor.get_instance_id(), "label":"Ask what has been heard locally"})
	for object: Dictionary in content.get("objects", []):
		if str(object.zone) == str(host.current_zone_id) and str(object.actor) == identity:
			actions.append({"type":"everyday_action", "operation":"inspect", "actor":actor.get_instance_id(), "object":object.id, "label":"May I look at " + str(object.title) + "?"})
	for scene: Dictionary in Scenes.data().get("scenes", []):
		if not Scenes.requestable_for(scene, host, actor): continue
		var scene_labels := {"everyday_mira_outing":"Walk the gathering bank together", "everyday_rook_outing":"Inspect the supplies together", "everyday_nera_outing":"Check the crossing together", "everyday_performance_rook":"Hear a short story", "everyday_performance_tor":"Watch the pin demonstration", "everyday_performance_table":"Share the table's tune"}
		personal_offers[str(scene.id)] = actor.get_instance_id()
		actions.append({"type":"everyday_action", "operation":"request_scene", "scene":scene.id, "scene_generation":personal_offer_generation, "actor":actor.get_instance_id(), "label":str(scene.get("offer_label", scene_labels.get(str(scene.id), "Spend a moment together")))})
	actions.append({"type":"close", "label":"Leave them to their work"})
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":Cast.display_name(identity), "pages":[{"speaker":Cast.display_name(identity), "speaker_id":str(actor.get("interaction_id")), "text":"A moment between jobs."}], "actions":actions})

func speak(actor: Node3D, opening: String, reply: String, key: String) -> void:
	var controller := life()
	if controller == null: return
	var identity := Cast.canonical_identity(str(actor.get("interaction_id")))
	var cooldown_key := identity + ":" + key
	if Time.get_ticks_msec() < int(social_cooldowns.get(cooldown_key, 0)): return
	var turns: Array = [["player", "Kael", opening], [str(actor.get("interaction_id")), Cast.display_name(identity), reply]]
	if controller.play_optional_exchange(actor, turns, "everyday:" + cooldown_key):
		social_cooldowns[cooldown_key] = Time.get_ticks_msec() + 30000

func persist() -> void:
	host.story_save_pending = true
	host.call_deferred("_persist_story_action")

func point_action(id: String, prompt: String, position: Vector3, stone: bool = false) -> Node3D:
	var area = preload("res://scripts/interactable.gd").new()
	area.setup("everyday:" + id, "story_activity", prompt)
	area.position = host.river_safe_position(position, 0.6)
	area.build_collision(0.65)
	host.zone_root.add_child(area)
	area.set_meta("everyday_action", id)
	host._connect_interactable(area)
	if stone:
		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.11
		mesh.height = 0.15
		mesh.radial_segments = 10
		mesh.rings = 5
		visual.mesh = mesh
		visual.position.y = 0.06
		visual.material_override = host._mat(Color(0.32,0.34,0.30))
		area.add_child(visual)
	return area

func favour_available(favour: Dictionary, identity: String) -> bool:
	if str(favour.actor)!=identity or str(favour.zone)!=str(host.current_zone_id) or bool(host.story_state.get_flag("everyday_favour:"+str(favour.id),false)):return false
	return not favour.has("requires_scene") or bool(host.story_state.get_flag("world_scenes_heard",{}).get(str(favour.requires_scene),false))

func box(parent: Node3D, size: Vector3, point: Vector3, color: Color = Color(0.28,0.20,0.13), solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = preload("res://scripts/prop_craft_geometry.gd").box(size)
	mesh.material_override = preload("res://scripts/prop_craft_geometry.gd").material(color)
	mesh.position=point
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer=1
		body.set_meta("walkable_support",false)
		parent.add_child(body)
		body.position=point
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=size
		collision.shape=shape
		body.add_child(collision)
	return mesh

func activate(area: Node3D) -> void:
	if not host.zone_root.is_ancestor_of(area) or area.global_position.distance_to(host.player.global_position) > 2.8: return
	var id := str(area.get_meta("everyday_action", ""))
	if id == "surrender":
		host.accept_ordinary_surrender(area.get_parent())
		area.set_interaction_enabled(false)
	elif id == "meet":
		preload("res://scripts/regional_meet.gd").open(self)
	elif id == "fish":
		choose({"operation":"fishing","station":area.get_instance_id()})
	elif id == "keepsakes" or id.begins_with("keepsake_slot:"):
		var slot := int(area.get_meta("slot",0))
		var actions: Array=[]
		for favour: Dictionary in content.get("favours",[]):
			if bool(host.story_state.get_flag("everyday_favour:"+str(favour.id),false)):
				actions.append({"type":"everyday_action","operation":"keepsake","slot":slot,"keepsake":favour.id,"label":favour.title})
		actions.append({"type":"everyday_action","operation":"keepsake","slot":slot,"keepsake":"","label":"Leave the space empty"})
		actions.append({"type":"close","label":"Step away"})
		show_actions("Kept along the road", "Space %d of six. These are gifts, not essential evidence or borrowed possessions."%[slot+1],actions)
	elif id == "clean":
		presentation.clean_wear()
		host.audio.play_event("cloth")
	elif id.begins_with("trail:"):
		presentation.inspect_trail(area)
	elif id.begins_with("stock:"):
		presentation.browse_stock(area)
	elif id == "kitchen":
		if not safe_station(area): return
		var actions: Array = []
		for item: String in MEALS:
			var quote: Dictionary = host.inventory.recipe_status(item, true)
			actions.append({"type":"everyday_action", "operation":"cook", "item":item, "station":area.get_instance_id(), "label":"Prepare " + host.inventory.get_item_name(item), "available":quote.craftable, "unavailable_reason":quote.reason})
		actions.append({"type":"close", "label":"Leave the kitchen"})
		show_actions("The kitchen", "A fish for the grill; a fish and bitterleaf for broth; bread and bitterleaf for supper. Meals are for resting, not battle.", actions)
	elif id == "stone":
		if host.inventory.owned_count("loose_stone") >= 1:
			host.hud.toast("One loose stone is enough to carry.")
			return
		host.inventory.add_item("loose_stone", 1)
		host.hud.toast("Loose stone packed. Select it in the field-tool slot to throw.")
		persist()
	elif id.begins_with("work:"):
		var controller := life()
		var scene_id := id.trim_prefix("work:")
		if controller == null or controller.social_scene.is_empty() or str(controller.social_scene.get("world", {}).get("id", "")) != scene_id or int(controller.social_scene.get("index", 0)) != 2: return
		if bool(host.story_state.get_flag("everyday_work:" + scene_id, false)): return
		cancel_meal()
		if not Presence.claim(host.player,"work",get_instance_id()):return
		host.player.set_meta("cast_work_cancel",cancel_work)
		work = {"scene":scene_id, "area":weakref(area), "start":host.player.global_position, "elapsed":0.0}
		host.player._request_equipment(host.player.weapon_mode, host.player.get_selected_blade_id(), false)
		host.hud.toast(str(area.prompt))

func tick_work(delta: float) -> void:
	if work.is_empty(): return
	var area := work.area.get_ref() as Node3D
	var controller := life()
	if not is_instance_valid(area) or host.player.global_position.distance_to(work.start) > 0.35 or host._story_has_active_combat() or controller == null or controller.social_scene.is_empty():
		cancel_work()
		return
	if host.player.equipment_loadout.is_transitioning() or host.player.equipment_loadout.is_drawn(): return
	var activity:="sort_herbs" if str(work.scene).contains("mira") else "check_rope"
	host.player.animation_driver.set_life_activity(activity)
	host.player.animation_driver.set_life_workstation({"activity":activity,"point":area.global_position+Vector3.UP*0.38,"left":area.global_position+Vector3(-0.12,0.38,0),"right":area.global_position+Vector3(0.12,0.38,0),"lift":0.04})
	work.elapsed = float(work.elapsed) + delta
	if float(work.elapsed) < 3.0: return
	host.story_state.set_flag("everyday_work:" + str(work.scene), true)
	if host.world_vfx != null: host.world_vfx.pulse_interaction(area.global_position)
	host.audio.play_event("wood_contact")
	var binding:=area.get_node_or_null("WorkBinding") as Node3D
	if binding!=null:binding.rotation.y=0.0
	cancel_work()
	persist()

func cancel_work() -> void:
	work.clear()
	if is_instance_valid(host) and is_instance_valid(host.player) and host.player.get_meta("cast_work_owner",0)==get_instance_id():
		host.player.animation_driver.clear_life_activity()
		Presence.release(host.player,"work",get_instance_id())

func show_actions(title: String, words: String, actions: Array) -> void:
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":title, "pages":[{"speaker":"", "speaker_id":"narrator", "text":words}], "actions":actions})

func safe_station(area: Node3D) -> bool:
	return is_instance_valid(area) and host.zone_root.is_ancestor_of(area) and area.global_position.distance_to(host.player.global_position) <= 2.8 and get_parent()._rest_unavailable(area) == ""

func append_rest_actions(area: Node3D, actions: Array) -> void:
	for item: String in MEALS:
		if host.inventory.owned_count(item) > 0:
			actions.insert(actions.size()-1, {"type":"everyday_action", "operation":"eat", "item":item, "station":area.get_instance_id(), "label":"Sit and eat " + host.inventory.get_item_name(item)})
	actions.insert(actions.size()-1, {"type":"everyday_action", "operation":"reflect", "station":area.get_instance_id(), "label":"Put a thought in the journal"})

func choose_rest_activity(action: Dictionary) -> void:
	var area := instance_from_id(int(action.get("station", 0))) as Node3D
	if not safe_station(area):
		host.hud.toast("Come back to a safe resting or cooking place.")
		return
	var operation := str(action.get("operation", ""))
	if operation in ["reflect", "reflection_choice"]:
		reflect(action, area)
		return
	var item := str(action.get("item", ""))
	if item not in MEALS: return
	if operation == "cook" and str(area.get_meta("everyday_action", "")) != "kitchen": return
	if operation == "eat" and str(area.get("interaction_id")) != str(get_parent().REST_PLACES.get(str(host.current_zone_id), {}).get("id", "")): return
	if operation == "eat" and host.player.global_position.distance_to(area.global_position) > 0.65:
		host.hud.toast("Come close to the clear seat before sitting down.")
		return
	if not ensure_assets(action): return
	cancel_work()
	if not Presence.claim(host.player, "work", get_instance_id()): return
	host.player.set_meta("cast_work_cancel", cancel_meal)
	host.player._request_equipment(host.player.weapon_mode, host.player.get_selected_blade_id(), false)
	meal = {"operation":operation, "item":item, "area":weakref(area), "start":host.player.global_position, "elapsed":0.0, "posed":false}

func tick_meal(delta: float) -> void:
	if meal.is_empty(): return
	var area := meal.area.get_ref() as Node3D
	if not safe_station(area) or host.player.global_position.distance_to(meal.start) > 0.25:
		cancel_meal()
		return
	if host.player.equipment_loadout.is_transitioning(): return
	if host.player.equipment_loadout.is_drawn():
		cancel_meal()
		return
	if not bool(meal.posed):
		meal.posed = true
		host.player.animation_driver.set_life_activity("seated_eat" if str(meal.operation) == "eat" else "bake")
		var packed := load("res://assets/everyday/cooking_pot.glb") as PackedScene
		if packed != null:
			var pot := packed.instantiate() as Node3D
			area.add_child(pot)
			pot.position = Vector3(0.5,0.2,0.3)
			meal["pot"] = weakref(pot)
	meal.elapsed = float(meal.elapsed) + delta
	if float(meal.elapsed) < 4.0: return
	var item := str(meal.item)
	var result: Dictionary
	if str(meal.operation) == "cook":
		result = host.crafting.cook_result(item, func(): return safe_station(area))
	else:
		var effect: Dictionary = host.inventory.item_defs[item].effect
		var hp := minf(float(effect.get("heal",0)), maxf(0.0,host.player.health_component.max_health-host.player.health_component.health))
		var stamina := minf(float(effect.get("stamina",0)), maxf(0.0,host.player.stamina_component.max_stamina-host.player.stamina_component.stamina))
		result = {"ok":false, "message":"You need no recovery. The meal stays packed."}
		if (hp > 0 or stamina > 0) and host.inventory.can_consume(item):
			# One synchronous save boundary: inventory observers see the completed recovery.
			host.inventory.items[item] = host.inventory.owned_count(item)-1
			host.player.health_component.heal(hp)
			host.player.stamina_component.restore(stamina)
			host.inventory.changed.emit()
			result = {"ok":true, "message":"The meal restores %d health and %d stamina." % [int(hp),int(stamina)]}
			var controller := life()
			if controller != null:
				for entry: Dictionary in controller.actors:
					if valid_actor(entry.node):
						speak(entry.node, "A little company with supper?", "For a moment. The work will still be there afterward.", "meal")
						break
	cancel_meal()
	host.hud.toast(str(result.message))
	if bool(result.get("ok",false)): persist()

func cancel_meal() -> void:
	if not meal.is_empty() and meal.has("pot"):
		var pot: Node = meal.pot.get_ref()
		if is_instance_valid(pot): pot.queue_free()
	meal.clear()
	if is_instance_valid(host.player):
		if host.player.get_meta("cast_work_owner",0)==get_instance_id() and is_instance_valid(host.player.animation_driver): host.player.animation_driver.clear_life_activity()
		Presence.release(host.player, "work", get_instance_id())

func reflect(action: Dictionary, area: Node3D) -> void:
	var available := Scenes.reflections(host.story_state)
	var id := str(action.get("reflection", ""))
	if str(action.operation) == "reflection_choice":
		if not available.any(func(entry): return str(entry.id) == id): return
		var options := ["I want to remember the useful work.", "I am not ready to settle what this means.", "I want to listen before making another promise.", "Leave unwritten"]
		var index := int(action.get("choice", -1))
		if index < 0 or index >= options.size(): return
		host.story_state.set_flag("everyday_reflection:" + id, options[index])
		persist()
		return
	var actions: Array = []
	for entry: Dictionary in available:
		if str(action.get("reflection", "")) == "":
			actions.append({"type":"everyday_action", "operation":"reflect", "reflection":entry.id, "station":area.get_instance_id(), "label":entry.title})
		elif str(entry.id) == id:
			var options := ["Remember the useful work", "Leave the meaning unsettled", "Listen before promising", "Leave unwritten"]
			for index in options.size(): actions.append({"type":"everyday_action", "operation":"reflection_choice", "reflection":id, "choice":index, "station":area.get_instance_id(), "label":options[index]})
	actions.append({"type":"close", "label":"Close the journal"})
	show_actions("A page of your own", "Only what you have actually encountered belongs on these pages. No thought is required.", actions)

func ensure_assets(action: Dictionary) -> bool:
	if not OS.has_feature("web") or host.runtime_packs.is_ready("leisure"): return true
	pending_assets = action.duplicate(true)
	if host.runtime_packs.get_state("leisure") == "failed": host.runtime_packs.retry_pack("leisure")
	else: host.runtime_packs.request_pack("leisure", 0)
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	host.hud.show_dialogue({"name":"Preparing the activity", "pages":[{"speaker":"", "text":"The optional activity's objects are being prepared. Your journey is kept."}], "actions":[{"type":"everyday_action", "operation":"cancel_assets", "label":"Return to the road"}]})
	return false

func _assets_ready(id: String) -> void:
	if id != "leisure" or get_parent().get_parent() != host.zone_root: return
	if is_instance_valid(presentation): presentation.refresh_keepsakes()
	if pending_assets.is_empty(): return
	var action := pending_assets.duplicate(true)
	pending_assets.clear()
	choose(action)

func _assets_failed(id: String, reason: String) -> void:
	if id != "leisure" or pending_assets.is_empty() or get_parent().get_parent() != host.zone_root: return
	var retry := pending_assets.duplicate(true)
	retry["type"] = "everyday_action"
	retry["label"] = "Retry activity"
	host.hud.show_dialogue({"name":"Activity unavailable", "pages":[{"speaker":"", "text":reason}], "actions":[retry, {"type":"everyday_action", "operation":"cancel_assets", "label":"Return to the road"}]})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host.player) or get_parent().get_parent() != host.zone_root or not host.game_started or host.zone_transition_pending or not host.player.can_control: return
	if host.day_night != null: host.day_night.active_play_seconds += delta
	tick_work(delta)
	tick_meal(delta)
	# The existing activity owner cancels wildlife presentation on the first
	# combat frame, without waiting for the low-frequency ambient decision.
	var combat: bool = host._story_has_active_combat()
	if combat:
		for entry: Dictionary in ecology:
			if int(entry.phase) == -2: continue
			var actor := entry.actor.get_ref() as Node3D
			if not is_instance_valid(actor): continue
			var driver := actor.find_child("CharacterAnimationDriver", true, false)
			if driver != null:
				driver.clear_observation_clip()
				driver.set_creature_presence("", "", 0.0)
			entry.phase = -2
			entry.event_phase = -1.0
			entry.visible_time = 0.0
	decision_elapsed += delta
	if decision_elapsed < 0.25: return
	var step := decision_elapsed
	decision_elapsed = 0.0
	for entry:Dictionary in surrender_targets:
		var enemy:Node=entry.enemy.get_ref()
		var area:Node=entry.area.get_ref()
		if is_instance_valid(enemy) and is_instance_valid(area):area.set_interaction_enabled(bool(enemy.surrender_offer) and not enemy.dead)
	for entry: Dictionary in ecology:
		var actor := entry.actor.get_ref() as Node3D
		if not is_instance_valid(actor): continue
		var sighting: Dictionary = actor.get_meta("design_ecology", {})
		var driver := actor.find_child("CharacterAnimationDriver", true, false)
		if driver == null: continue
		var distant: bool = actor.global_position.distance_squared_to(host.player.global_position) > 225.0 or not actor.is_visible_in_tree()
		driver.set_distance_suspended(distant)
		if distant or combat:
			entry.event_phase = -1.0
			entry.visible_time = 0.0
			continue
		entry.elapsed = float(entry.elapsed) + step
		var near := actor.global_position.distance_to(host.player.global_position) < 3.0
		var phase := 0 if near else (1 if fmod(float(entry.elapsed), 14.0) < 7.0 else 2)
		if int(entry.phase) != phase:
			entry.phase = phase
			var clips: Array = sighting.get("ambient_clips", [str(sighting.get("clip", "Idle")), "Idle"])
			var selected := "Investigate" if near else str(clips[(phase - 1) % clips.size()])
			if not driver.set_observation_clip(selected): driver.set_observation_clip("Idle")
			driver.set_creature_presence(str(sighting.role), "attentive" if phase == 0 else ("feeding" if phase == 1 else "watching"), 0.65)
		var camera: Camera3D = host.get_viewport().get_camera_3d()
		var visible: bool = camera != null and actor.is_visible_in_tree() and not camera.is_position_behind(actor.global_position) and host.get_viewport().get_visible_rect().has_point(camera.unproject_position(actor.global_position)) and Presence.can_see(host.player, actor, 12.0)
		_tick_ecology_contact(entry, sighting, actor, driver, visible and not near)
		entry.visible_time = float(entry.visible_time) + step if visible and phase != 0 else 0.0
		if float(entry.visible_time) >= 4.0 and not host.story_state.evidence.has(str(actor.interaction_id)):
			host.story_state.record_evidence(str(actor.interaction_id), {"zone":host.current_zone_id, "kind":"observed", "title":sighting.title, "text":sighting.observation})
			host.hud.toast("Observed: " + str(sighting.name))
			persist()

func _tick_ecology_contact(entry: Dictionary, sighting: Dictionary, actor: Node3D, driver: Node, visible: bool) -> void:
	var sample: Dictionary = driver.observation_motion_sample()
	if not visible or sample.is_empty():
		entry.event_phase = -1.0
		return
	var clip := str(sample.clip).get_file().to_lower()
	var phase := float(sample.phase)
	var previous := float(entry.event_phase)
	if str(entry.event_clip) != clip: previous = -1.0
	entry.event_clip = clip
	entry.event_phase = phase
	if previous < 0.0: return
	for event: Dictionary in sighting.get("contact_events", []):
		if clip != str(event.clip).to_lower(): continue
		if phase_crossed(previous, phase, float(event.fraction)):
			host.audio.play_spatial_event(str(event.cue), actor.global_position, host.player.global_position, 12.0, float(event.get("cooldown", 6.0)), 0.015)

static func phase_crossed(previous: float, current: float, contact: float) -> bool:
	if not is_finite(previous) or not is_finite(current) or not is_finite(contact): return false
	if previous < 0.0 or previous >= 1.0 or current < 0.0 or current >= 1.0 or contact <= 0.0 or contact >= 1.0: return false
	# No catch-up events after a hitch, suspension or seek. A normal wrap is
	# supported and the same sampled phase can never emit twice.
	var advanced := fposmod(current - previous, 1.0)
	if advanced <= 0.0 or advanced > 0.45: return false
	var to_contact := fposmod(contact - previous, 1.0)
	return to_contact > 0.0 and to_contact <= advanced

func _notification(what:int) -> void:
	if what in [NOTIFICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_EXIT_TREE]:
		cancel_work()
		if not meal.is_empty():cancel_meal()
