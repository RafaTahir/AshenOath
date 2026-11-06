extends Node

const Cast = preload("res://scripts/story_cast_profile.gd")
const Held = preload("res://scripts/held_prop_geometry.gd")
const Surface = preload("res://scripts/spatial_surface_contract.gd")
const WEAR_SHADER = preload("res://shaders/everyday_wear.gdshader")
const TRAILS := {
	"greyfen":{"name":"A loaded cart's passage","points":[Vector3(-4,0,12),Vector3(-4,0,10),Vector3(-3,0,8)],"text":"The parallel compressed marks lead to the kitchen's unloading place. They establish a load's approach, not who owned it."},
	"wychwood":{"name":"Water-edge prints","points":[Vector3(9,0,-6),Vector3(8.5,0,-5),Vector3(7.7,0,-3.6)],"text":"Broad prints turn along the bank, not into the working beds. The watercourse signs can be inspected independently."},
	"deep_wood":{"name":"Roots under strain","points":[Vector3(-3,0,11),Vector3(-4,0,9),Vector3(-5,0,7)],"text":"Scraped soil stops outside the guardian's boundary. The ordinary path is not an invitation to enter it."},
	"old_mill":{"name":"Ash on the wind","points":[Vector3(8,0,11),Vector3(6.5,0,9.5),Vector3(5.3,0,8)],"text":"Dark flakes increase toward the windward post. The worker exit and ventilation belong to the existing mill encounter."},
	"bandit_road":{"name":"A halted supply load","points":[Vector3(-7,0,11),Vector3(-6,0,9),Vector3(-5.7,0,7)],"text":"A wheel slipped where the load stopped. These marks lead to the stored checkpoint equipment, not proof of a distant order."},
	"hart_glade":{"name":"Measured hoofprints","points":[Vector3(-7,0,12),Vector3(-7.2,0,10),Vector3(-7,0,8)],"text":"The steps slow where the glade opens. Their presence does not prove the Hart is still here or consent to any covenant."}
}
var service
var host
var wear: Array[Dictionary]=[]
var cursor := 0
var accumulator := 0.0
var stock: Array[Dictionary]=[]
var keepsakes: Array[Node3D]=[]
var active_seconds := 0.0

func configure(owner_service) -> void:
	service=owner_service
	host=service.host
	host.day_night.weather_changed.connect(weather_changed)
	weather_changed(str(host.day_night.current_weather))
	_collect_wear(host.player,"player")
	var controller: Node=service.life()
	if controller!=null:
		for entry: Dictionary in controller.actors:
			_collect_wear(entry.node,Cast.canonical_identity(str(entry.id)))
	var zone:=str(host.current_zone_id)
	if zone in ["greyfen","old_mill","vargan_approach","ruins"]:
		var point: Vector3=Vector3(8.8,0,-6.1) if zone=="greyfen" else service.get_parent().REST_PLACES[zone].position+Vector3(0.8,0,0)
		var wash: Node3D=service.point_action("clean","Rinse boots and brush the road dust away",point)
		vessel(wash,Vector3(0,0.18,0),Color(0.35,0.28,0.20),0.3)
	if zone in ["old_mill","vargan_approach","ruins"]:
		var point: Vector3=service.get_parent().REST_PLACES[zone].position
		var bench:=Node3D.new()
		host.zone_root.add_child(bench)
		bench.position=host.river_safe_position(point+Vector3(0,0,0.32),0.4)
		service.box(bench,Vector3(1.3,0.12,0.42),Vector3(0,0.43,0),Color(0.31,0.27,0.21),true)
		for x in [-0.5,0.5]: service.box(bench,Vector3(0.12,0.4,0.3),Vector3(x,0.2,0))
	if TRAILS.has(zone):
		var trail:Dictionary=TRAILS[zone]
		for index in trail.points.size():
			var area: Node3D=service.point_action("trail:"+str(index),"Examine "+str(trail.name).to_lower(),trail.points[index])
			for step in 3:
				var mesh:=MeshInstance3D.new()
				var oval:=SphereMesh.new()
				oval.radius=0.09
				oval.height=0.018
				oval.radial_segments=8
				oval.rings=3
				mesh.mesh=oval
				mesh.scale=Vector3(0.65,1,1.5)
				mesh.material_override=host._mat(Color(0.19,0.18,0.15))
				area.add_child(mesh)
				mesh.position=Vector3(0.12 if step%2==0 else -0.12,0.015,step*0.22)
	_build_work_objects()
	if zone=="greyfen":
		for definition in [["tor_forge",Vector3(9.3,0,-2.6)],["mira_apothecary",Vector3(-7,0,-3.3)],["nessa_kitchen",Vector3(-1,0,8.3)]]:
			var area:Node3D=service.point_action("stock:"+str(definition[0]),"Browse "+str(host.vendor_service.get_vendor(definition[0]).name),definition[1])
			service.box(area,Vector3(0.9,0.06,0.42),Vector3(0,0.74,0))
			for x in [-0.35,0.35]:service.box(area,Vector3(0.06,0.7,0.06),Vector3(x,0.35,0.08))
			stock.append({"area":area,"vendor":str(definition[0]),"objects":[]})
		host.vendor_service.changed.connect(refresh_stock)
		refresh_stock()
	refresh_keepsakes()

func vessel(parent:Node3D,point:Vector3,color:Color,size:float) -> MeshInstance3D:
	var visual:=MeshInstance3D.new()
	visual.mesh=Held.vessel(size,size*0.7,size*0.8)
	visual.material_override=host._mat(color)
	visual.position=point
	parent.add_child(visual)
	return visual

func _build_work_objects() -> void:
	for area in host.interaction_focus.registered_nearby(host.player.global_position,host.zone_root,500.0):
		var id:=str(area.get_meta("everyday_action",""))
		if id.begins_with("work:"):
			service.box(area,Vector3(0.5,0.3,0.35),Vector3(0,0.15,0),Color(0.29,0.24,0.16))
			var binding: MeshInstance3D=service.box(area,Vector3(0.025,0.02,0.4),Vector3(0.09,0.32,0),Color(0.52,0.45,0.28))
			binding.name="WorkBinding"
			binding.rotation.y=0.0 if bool(host.story_state.get_flag("everyday_work:"+id.trim_prefix("work:"),false)) else 0.35
		elif id=="kitchen":
			vessel(area,Vector3(0,0.25,0),Color(0.19,0.2,0.18),0.24)
			for index in 3:service.box(area,Vector3(0.1,0.1,0.55),Vector3(-0.13+index*0.13,0.08,0),Color(0.22,0.2,0.17))
		elif id=="fish":
			service.box(area,Vector3(0.08,0.8,0.08),Vector3(0,0.4,0),Color(0.35,0.29,0.18))
			vessel(area,Vector3(0.3,0.15,0),Color(0.4,0.33,0.2),0.18)

func weather_changed(weather:String) -> void:
	if is_instance_valid(host.world_vfx):host.world_vfx.set_weather(weather,host.player)
	var controller:Node=service.life()
	if controller!=null:controller.story_dirty=true

func _collect_wear(actor:Node3D,id:String) -> void:
	if not is_instance_valid(actor) or id=="":return
	var material:=ShaderMaterial.new()
	material.shader=WEAR_SHADER
	var saved:Dictionary=host.story_state.get_flag("everyday_wear",{}).get(id,{})
	var entry:Dictionary={"actor":weakref(actor),"id":id,"material":material,"meshes":[],"wet":clampf(float(saved.get("wet",0)),0,1),"soil":clampf(float(saved.get("soil",0)),0,1),"last":actor.global_position,"time":active_seconds}
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.material_overlay==null:
			entry.meshes.append(weakref(mesh))
	wear.append(entry)

func _process(delta:float) -> void:
	if service.get_parent().get_parent()!=host.zone_root or not host.game_started or host.zone_transition_pending:return
	accumulator+=delta
	active_seconds+=delta
	if accumulator<0.5:return
	accumulator=0
	if wear.is_empty():return
	cursor=cursor%wear.size()
	var entry:Dictionary=wear[cursor]
	cursor+=1
	var actor:Node3D=entry.actor.get_ref()
	if not is_instance_valid(actor):return
	var seconds:=minf(10,active_seconds-float(entry.time))
	entry.time=active_seconds
	var moving:float=actor.global_position.distance_to(entry.last)
	entry.last=actor.global_position
	var exposed:=str(host.day_night.current_weather)=="rain" and str(host.current_zone_id) not in ["record_hall","undercroft","vargan_court"]
	if exposed:
		var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.8,actor.global_position+Vector3.UP*6,1)
		exposed=actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	entry.wet=clampf(float(entry.wet)+seconds*(0.04 if exposed else -0.008),0,1)
	entry.soil=clampf(float(entry.soil)+moving*(0.012 if exposed else 0.004),0,1)
	entry.material.set_shader_parameter("wetness",entry.wet)
	entry.material.set_shader_parameter("soil",entry.soil)
	entry.material.set_shader_parameter("feet_height",actor.global_position.y)
	var nearby:=actor.global_position.distance_squared_to(host.player.global_position)<256.0
	for reference:WeakRef in entry.meshes:
		var mesh:MeshInstance3D=reference.get_ref()
		if not is_instance_valid(mesh):continue
		if nearby and (float(entry.wet)>0.01 or float(entry.soil)>0.01):
			if mesh.material_overlay==null:mesh.material_overlay=entry.material
		elif mesh.material_overlay==entry.material:mesh.material_overlay=null
	var state:Dictionary=host.story_state.get_flag("everyday_wear",{}).duplicate(true)
	state[str(entry.id)]={"wet":snappedf(float(entry.wet),0.02),"soil":snappedf(float(entry.soil),0.02)}
	host.story_state.set_flag("everyday_wear",state)

func clean_wear() -> void:
	for entry:Dictionary in wear:
		if str(entry.id)!="player":continue
		entry.soil=0.0
		entry.wet=0.12
		entry.material.set_shader_parameter("soil",0.0)
		entry.material.set_shader_parameter("wetness",0.12)
		var state:Dictionary=host.story_state.get_flag("everyday_wear",{}).duplicate(true)
		state.player={"wet":0.12,"soil":0.0}
		host.story_state.set_flag("everyday_wear",state)
		service.persist()
		host.hud.toast("Road dirt brushed away. Clothing dries naturally; no statistic changes.")

func inspect_trail(area:Node3D) -> void:
	var zone:=str(host.current_zone_id)
	if not TRAILS.has(zone):return
	var index:=str(area.get_meta("everyday_action")).trim_prefix("trail:")
	host.story_state.set_flag("everyday_track:"+zone+":"+index,true)
	var complete:=true
	for part in 3:complete=complete and bool(host.story_state.get_flag("everyday_track:"+zone+":"+str(part),false))
	var text:=str(TRAILS[zone].text) if complete else "One physical mark. The neighboring marks can be followed in either direction; no overlay is needed."
	service.show_actions(str(TRAILS[zone].name),text,[{"type":"close","label":"Look along the ground"}])
	if complete:host.story_state.record_evidence("everyday_trail:"+zone,{"title":TRAILS[zone].name,"text":text,"kind":"observed","zone":zone,"source":"Physical marks on this journey"})
	service.persist()

func browse_stock(area:Node3D) -> void:
	var vendor:=str(area.get_meta("everyday_action")).trim_prefix("stock:")
	var identity:=str({"tor_forge":"tor","mira_apothecary":"mira","nessa_kitchen":"nessa"}.get(vendor,""))
	var actor:Node3D=Cast.registered_actor(host.zone_root,identity)
	if not is_instance_valid(actor) or actor.global_position.distance_to(area.global_position)>8.0 or host._story_has_active_combat():
		host.hud.toast("The display can wait until its owner is nearby and safe.")
		return
	host.get_tree().paused=true
	host.audio.set_game_paused(true)
	host.hud.show_vendor(vendor,host.vendor_service,host.inventory,host.quests,host.story_state)

func refresh_stock() -> void:
	for display:Dictionary in stock:
		for object:Node in display.objects:
			if is_instance_valid(object):object.queue_free()
		display.objects=[]
		var entries:Array=host.vendor_service.list_stock(str(display.vendor),host.inventory,host.story_state,host.quests)
		for index in mini(3,entries.size()):
			var id:=str(entries[index].item_id)
			var point:=Vector3((index-1)*0.26,0.84,0)
			var item:MeshInstance3D
			if id.ends_with("arrow"):
				item=service.box(display.area,Vector3(0.012,0.012,0.35),point,Color(0.45,0.31,0.14))
			elif id=="travel_bread":
				item=service.box(display.area,Vector3(0.18,0.08,0.25),point,Color(0.62,0.41,0.21))
			else:item=vessel(display.area,point,Color(0.27,0.4,0.30),0.065)
			var bought:=int(host.vendor_service.stock_purchases.get(str(display.vendor),{}).get(id,0))
			item.rotation.y=0.15*mini(bought,3)
			item.position.z=0.09 if bought>0 else 0.0
			display.objects.append(item)

func refresh_keepsakes() -> void:
	if not is_instance_valid(service.keepsake_shelf):return
	if OS.has_feature("web") and not host.runtime_packs.is_ready("leisure"):return
	for object:Node in keepsakes:
		if is_instance_valid(object):object.queue_free()
	keepsakes.clear()
	var placed:Dictionary=host.story_state.get_flag("everyday_display",{})
	for slot:String in placed:
		if int(slot)<0 or int(slot)>=6:continue
		for favour:Dictionary in service.content.get("favours",[]):
			if str(favour.id)!=str(placed[slot]) or not bool(host.story_state.get_flag("everyday_favour:"+str(favour.id),false)):continue
			var scene:=load("res://assets/everyday/"+str(favour.asset)+".glb") as PackedScene
			if scene==null:continue
			var object:=scene.instantiate() as Node3D
			service.keepsake_shelf.add_child(object)
			object.position=Vector3((int(slot)%3-1)*0.48,0.82,-0.12+0.24*(int(slot)/3))
			object.scale=Vector3.ONE*0.55
			keepsakes.append(object)

func _exit_tree() -> void:
	for entry:Dictionary in wear:
		for reference:WeakRef in entry.meshes:
			var mesh:MeshInstance3D=reference.get_ref()
			if is_instance_valid(mesh) and mesh.material_overlay==entry.material:mesh.material_overlay=null
