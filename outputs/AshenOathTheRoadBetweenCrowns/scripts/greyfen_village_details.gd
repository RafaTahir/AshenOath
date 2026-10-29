extends Node3D

## Greyfen's finite prop/staging extension, installed by StoryActivityDirector.
## Cosmetic state is isolated; quest work and secret claims keep their owners.
const Guidance = preload("res://scripts/greyfen_guidance.gd")
const Interactable = preload("res://scripts/interactable.gd")
const Prop = preload("res://scripts/interactive_world_prop.gd")
const Presence = preload("res://scripts/character_presence.gd")
const Work = preload("res://scripts/saga_work_presentation.gd")
const OWNER := "GreyfenVillageDetails"
const WOOD := Color(0.29, 0.21, 0.13)
const IRON := Color(0.23, 0.25, 0.24)
const LINEN := Color(0.64, 0.67, 0.58)
const DUMMY := Vector3(7.5, 0, 15.0)
var game
var props: Dictionary = {}
var _tick := 0.0
var _last_position := Vector3.INF
var _walked := 0.0
var _look_basis := Vector3.ZERO
var _looked := 0.0
var _hint_key := ""
var _attack_id := -1
var _seat: Node3D
var _seat_start := Vector3.ZERO
var _local_motion: Dictionary = {}
var _observed_drawn := false
var _static: Dictionary = {}
var _work: Dictionary = {}
var _lamps: Dictionary = {}

static func install(host) -> void:
	if str(host.current_zone_id) != "greyfen" or host.zone_root.get_node_or_null(OWNER) != null: return
	var details = load("res://scripts/greyfen_village_details.gd").new()
	details.name = OWNER
	details.game = host
	host.zone_root.add_child(details)
	details._build()

static func current(host) -> Node:
	return host.zone_root.get_node_or_null(OWNER) if is_instance_valid(host.zone_root) else null

static func choose(host, action: Dictionary) -> void:
	if str(action.get("operation", "")) == "guide":
		Guidance.set_mode(host, str(action.get("mode", "paused")))
		return
	var details := current(host)
	if details != null and str(action.get("operation", "")) == "preparation":
		Guidance.learn(host, "prepare")
		host._resume_game()
		details._read("Mira - a useful advantage", "Look at the threat before spending your supplies. Steel suits living flesh; the Oathblade answers bindings. Moon Oil can help against the Wretch, but neither oil nor a purchased practice is a road toll. Carry what you can use. The creature notes distinguish what you saw from what someone inferred.")

func _build() -> void:
	var guide := _point("guide", "Read Before You Take the Road", Vector3(-1.7,0,11.7), "guide", "Nessa: Bread first, heroics after. Rook: Preferably someone else's heroics. Take a hand with the cart, try the southern range, then see who needs you across the bridge. You can take the road now; none of this is an obligation.")
	var book: Node3D = preload("res://scripts/campaign_record_presentation.gd").make_visual("register_mira")
	if book != null:
		guide.add_child(book)
		book.position.y = 0.82
		book.scale *= 0.65
	_table(guide, Vector3.ZERO, Vector3(0.72,0.78,0.48))
	_build_kitchen()
	_build_well()
	_build_forge()
	_build_homes()
	_build_care()
	_build_bell()
	_build_common()
	_build_cemetery()
	_build_edges()
	_bind_lamps()
	var dummy := _point("dummy", "Inspect the southern practice dummy", DUMMY, "dummy", "Tor has wrapped this old target for blade contact. Practice light and committed strikes, then make room for the recovery. The ring range is alongside, not behind it. Oathfire can be directed here without an enemy, reward or spent practice point.")
	_model(dummy, "Dummy.obj", 1.75, Vector3.ZERO)
	_flush_static()
	game.story_state.changed.connect(_refresh)
	_refresh()

func _point(id: String, prompt: String, position_value: Vector3, kind: String, words: String) -> Node3D:
	var area = Interactable.new()
	area.setup("greyfen_detail:" + id, "story_activity", prompt)
	if absf(position_value.z - 4.5) < 2.8:
		position_value.z = 4.5 + (-2.9 if position_value.z < 4.5 else 2.9)
	area.position = position_value
	area.build_collision(0.65)
	var heights := {"container":0.55,"bucket":0.55,"bellows":0.63,"mechanism":0.8,"shutter":1.36,"knock":1.1,"seat":0.45}
	area.set_meta("interaction_anchor", Vector3(0,float(heights.get(kind,0.9)),0))
	area.set_meta("interaction_reach", 2.2)
	area.set_meta("strict_interaction_visibility", true)
	area.set_meta("detail_kind", kind)
	area.set_meta("detail_text", words)
	add_child(area)
	area.add_to_group("story_activity")
	game._connect_interactable(area)
	var component = Prop.new()
	component.name = "PropState"
	area.add_child(component)
	component.configure(id, kind, "greyfen_prop:" + id, "closed", game.story_state)
	component.set_meta("reduced_motion", bool(game.settings.settings.get("reduced_motion", false)))
	props[id] = area
	if kind == "record" and id != "cemetery_return":
		var record: Node3D = preload("res://scripts/campaign_record_presentation.gd").make_visual("register_mira")
		if record != null:
			area.add_child(record)
			record.scale *= 0.4
			record.position.y = 0.84
		_box(area,Vector3(0,0.4,0),Vector3(0.06,0.8,0.06))
		_box(area,Vector3(0,0.82,0),Vector3(0.36,0.04,0.30))
	return area

func _bind_lamps() -> void:
	var lights: Array[Node] = game.zone_root.find_children("*","OmniLight3D",true,false)
	for glow: Node3D in game.zone_root.find_children("*", "MeshInstance3D", true, false):
		if str(glow.get_meta("visual_name","")) != "LanternGlow": continue
		var point: Vector3 = game.zone_root.to_local(glow.global_position) - Vector3(0,1.17,0)
		var id := "lamp_" + str(snappedi(point.x*100,1)) + "_" + str(snappedi(point.z*100,1))
		var area := _point(id,"Use the sheltered lantern",point,"lantern","A sheltered wick, kept clear of hanging linen. Turning this lamp off changes its flame and existing light, not the world's time or the shrine.")
		area.set_meta("interaction_anchor",Vector3(0,1.17,0))
		var lamp: Light3D
		for light: Node3D in lights:
			if light.global_position.distance_to(glow.global_position) < 0.6: lamp = light as Light3D
		_lamps[id] = {"flame":weakref(glow),"light":weakref(lamp) if lamp != null else null}
		glow.set_meta("world_prop_id",id)
		glow.set_meta("world_prop_state_key","greyfen_prop:"+id)
		var component: Node = area.get_node("PropState")
		if game.story_state.get_flag("greyfen_prop:"+id,null) == null: component.set_state("lit",false)
		component.state_changed.connect(_lamp_changed)
		_lamp_changed(id,component.current_state)

func _lamp_changed(id: String, state: String) -> void:
	if not _lamps.has(id): return
	var record: Dictionary = _lamps[id]
	var flame: Node3D = record.flame.get_ref()
	var light: Light3D = record.light.get_ref() if record.light != null else null
	if is_instance_valid(flame): flame.visible = state == "lit"
	if is_instance_valid(light): light.visible = state == "lit"

func open_table(area: Node3D) -> bool:
	var life: Node = game.zone_root.find_child("GreyfenLifeController",true,false)
	if life == null:
		game.hud.toast("The table is here; its opponent is not available yet.")
		return true
	var person := "rook" if str(area.interaction_id) == "common_table" else "blacksmith_tor"
	var arrival := area.get_node_or_null("BoardGameOpponentApproach") as Node3D
	var corner := area.get_node_or_null("BoardGameOpponentCorner") as Node3D
	if arrival == null:
		game.hud.toast("The table's clear approach is not ready yet.")
		return true
	if not life.request_table_visit(person,arrival.global_position,corner.global_position if corner != null else Vector3.INF):
		game.hud.toast(("Rook" if person == "rook" else "Tor") + " is coming over when the work allows. The shop stays open; use the board again when your opponent arrives.",5.0)
		return true
	return false

func _model(parent: Node3D, file: String, height: float, point: Vector3) -> Node3D:
	# Instantiate the imported resource, preserving its authored material slots;
	# the legacy OBJ fallback intentionally flattens surfaces for generic scenery.
	var resource: Resource = game.asset_helper.load_runtime_resource("res://assets_external/environment/props/" + file)
	var node: Node3D = game.asset_helper.instantiate_runtime_resource(resource)
	if node == null:
		push_error("Greyfen required detail unavailable: " + file)
		return null
	# Imported OBJ meshes can have empty slots even when their retained atlas
	# exists. Bind only missing slots; preserve authored materials and surfaces.
	if file.get_extension().to_lower() == "obj":
		var path := "res://assets_external/environment/props/" + file
		for mesh_node: MeshInstance3D in game.asset_helper._collect_meshes(node):
			if mesh_node.mesh == null or mesh_node.material_override != null:
				continue
			for surface in mesh_node.mesh.get_surface_count():
				if mesh_node.get_active_material(surface) == null:
					mesh_node.set_surface_override_material(surface, game.asset_helper._obj_material(path))
	game.asset_helper._normalize_scene_bounds(node, height)
	parent.add_child(node)
	node.position += point
	return node

func _box(parent: Node3D, point: Vector3, size: Vector3, color: Color = WOOD, moving: bool = false) -> MeshInstance3D:
	if moving:
		return Work._plank(game, parent, point, size, color)
	var key := str(color)
	if not _static.has(key): _static[key] = {"color":color, "transforms":[]}
	# These assemblies are direct children or descendants of this untransformed
	# extension. Capture their full local frame once, then batch immutable pieces.
	var transform := global_transform.affine_inverse() * parent.global_transform * Transform3D(Basis.IDENTITY.scaled(size), point)
	_static[key].transforms.append(transform)
	return null

func _flush_static() -> void:
	for entry: Dictionary in _static.values():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var batches: Dictionary = {}
		for transform: Transform3D in entry.transforms:
			var cell := Vector2i(floori(transform.origin.x / 8.0), floori(transform.origin.z / 8.0))
			if not batches.has(cell): batches[cell] = []
			batches[cell].append(transform)
		for transforms: Array in batches.values():
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = mesh
			batch.multimesh.instance_count = transforms.size()
			batch.material_override = game._mat(entry.color)
			add_child(batch)
			for index in transforms.size(): batch.multimesh.set_instance_transform(index, transforms[index])
	_static.clear()

func _table(parent: Node3D, point: Vector3, size: Vector3) -> void:
	_box(parent, point + Vector3(0,size.y,0), Vector3(size.x,0.06,size.z))
	for x in [-size.x*0.4,size.x*0.4]:
		_box(parent, point + Vector3(x,size.y*0.5,0), Vector3(0.07,size.y,size.z*0.8))

func _build_kitchen() -> void:
	var stock := _point("kitchen_stock", "Open the kitchen stock box", Vector3(-4.35,0,6.95), "container", "Household portions, not a hunter's supply chest. The sealed deliveries belong to Nessa's grain account; lifting a lid cannot settle it.")
	_chest(stock,Vector3(0.70,0.52,0.55))
	var lid := _box(stock, Vector3(0,0.55,0), Vector3(0.70,0.045,0.55), WOOD, true)
	stock.get_node("PropState").bind_visual(lid,"position",lid.position,lid.position + Vector3(0,0.22,-0.30))
	for x in [-0.18,0.0,0.18]: Work._rod(game,stock,Vector3(x,0.47,0),0.065,0.06,Color(0.57,0.40,0.22))
	var pot := _point("kitchen_lid", "Lift the kitchen pot lid", Vector3(-3.05,0,7.35), "container", "Warm broth, a clean ladle, and enough set aside for the late arrivals. Nothing here is a repeatable source of provisions.")
	pot.set_meta("interaction_anchor",Vector3(0,0.98,0))
	_table(pot,Vector3.ZERO,Vector3(0.75,0.72,0.55))
	_model(pot,"Pot_1.obj",0.24,Vector3(0,0.75,0))
	var cover := _model(pot,"Pot_1_Lid.obj",0.07,Vector3(0,0.98,0))
	if cover != null: pot.get_node("PropState").bind_visual(cover,"position",cover.position,cover.position + Vector3(0.28,0.14,0))
	var ties := _point("cart_ties", "Check Rook's food-cart ties", Vector3(-5.85,0,9.55), "mechanism", "The food cart has sacks tied low to keep its axle steady. Maren's relief load carries a marked brace and covered medicine: a different arrival, with a different account.")
	var knot := Work._rod(game,ties,Vector3(0,0.8,0),0.07,0.08,LINEN)
	ties.get_node("PropState").bind_visual(knot,"rotation:z",0.0,0.35)
	_point("delivery_slips","Read the kitchen delivery slips",Vector3(-4.0,0,8.15),"record","Nessa counts households, not promises: three evening measures, one reserved for a late traveler. Rook's flour and Maren's relief supplies have separate entries. A copied figure is an observation; discovering who altered it belongs to the grain investigation.")

func _build_well() -> void:
	var well := _point("well_bucket","Lower the well bucket",Vector3(-7.0,0,-0.5),"bucket","The rope runs over the beam. A scored rim marks where the bucket rests. A loose cover is part of this well, not a second cache somewhere on the road.")
	well.set_meta("interaction_anchor",Vector3(-0.75,0.78,0))
	var bucket := _model(well,"Bucket_Wooden_1.fbx",0.31,Vector3(-0.75,0.78,0))
	var rope := Work._rod(game,well,Vector3(-0.75,1.25,0),0.014,0.66,LINEN)
	if bucket != null: well.get_node("PropState").bind_visual(bucket,"position:y",0.78,0.18)
	well.get_node("PropState").bind_visual(rope,"scale:y",1.0,2.75)
	well.get_node("PropState").bind_visual(rope,"position:y",1.25,0.95)
	var cover := _point("well_cover","Check the well's loose cover",Vector3(-8.6,0,-0.2),"container","Water has worn a pale edge beneath this loose cover. Follow the existing well-side savings clue; the lid itself grants nothing.")
	var board := _box(cover,Vector3(0,0.94,0),Vector3(0.48,0.045,0.35),WOOD,true)
	cover.get_node("PropState").bind_visual(board,"rotation:z",0.0,-0.28)

func _build_forge() -> void:
	var bellows := _point("bellows","Work the forge bellows",Vector3(11.9,0,-2.0),"bellows","Tor: Short strokes. Feed the coals, not the whole roof. The old iron on my bench has its own history; working these bellows decides none of it.")
	var leather := _box(bellows,Vector3(0,0.63,0),Vector3(0.55,0.18,0.28),Color(0.31,0.25,0.22),true)
	_box(bellows,Vector3(0,0.51,0),Vector3(0.64,0.05,0.32))
	bellows.get_node("PropState").bind_visual(leather,"scale:y",1.0,0.3)
	var quench := _point("quench","Check the quenching bucket",Vector3(10.0,0,-2.0),"bucket","The black water carries scale from Tor's work. A clean bucket waits for drinking water. The metal cooling here is ordinary forge work, not newly recovered chapel evidence.")
	_model(quench,"Bucket_Wooden_1.fbx",0.38,Vector3.ZERO)
	var tongs := _box(quench,Vector3(0.07,0.55,0),Vector3(0.025,0.45,0.035),IRON,true)
	quench.get_node("PropState").bind_visual(tongs,"position:y",0.55,0.20)
	_point("forge_marks","Inspect Tor's current maker's marks",Vector3(9.15,0,-1.25),"record","A working maker's mark shows whose hammer shaped a piece. It does not show who ordered it, when it was taken, or whom it harmed. The blackened chapel iron must actually be found before anyone can call it recovered.")
	var tools := _point("forge_tools","Set Tor's tools in their rack",Vector3(11.9,0,-0.55),"mechanism","The tongs lie beside the quench; the repair hammer stays within Tor's reach. Putting a tool straight changes no restitution decision.")
	for index in range(3):
		_box(tools,Vector3(-0.18+index*0.18,0.50,0),Vector3(0.045,0.45,0.045))
		_box(tools,Vector3(-0.18+index*0.18,0.72,0),Vector3(0.14,0.055,0.06),IRON)

func _build_homes() -> void:
	var homes := [
		["west",Vector3(-5,0,-3),8.0,"The west-lane household", "A voice from inside: Leave the wet boots by the step. We have just got that floor dry.",Color(0.38,0.48,0.39)],
		["east",Vector3(5.6,0,-1),0.0,"The east-lane household", "A latch lifts, then settles. From inside: Supper is on. Leave any message with the kitchen.",Color(0.55,0.38,0.32)],
		["south",Vector3(-10,0,11),24.0,"The southern household", "Someone taps back twice. A child's small boots are drying beside the threshold.",Color(0.43,0.48,0.58)],
		["north",Vector3(14,0,-8.4),-42.0,"The northern household", "From behind the shutter: We heard you. The door stays closed after dark; that is not an invitation to force it.",Color(0.56,0.51,0.31)]
	]
	for home: Array in homes:
		var frame := Node3D.new()
		frame.position = home[1]
		frame.rotation.y = deg_to_rad(float(home[2]))
		add_child(frame)
		var entry := _point("knock_"+str(home[0]),"Knock at " + str(home[3]).to_lower(),frame.position + frame.basis * Vector3(-0.05,0,-2.1),"knock",str(home[4]))
		entry.rotation.y = frame.rotation.y
		entry.set_meta("interaction_anchor",Vector3(0,1.1,0))
		var latch := _box(entry,Vector3(0.28,0.92,0.02),Vector3(0.18,0.035,0.035),IRON,true)
		entry.get_node("PropState").bind_visual(latch,"rotation:z",0.0,0.16)
		var shutter := _point("shutter_"+str(home[0]),"Check the household shutter",frame.position + frame.basis * Vector3(-1.42,0,-2.06),"shutter","The shutter opens onto a close linen backing. This is a lived-in boundary, not an entrance into an unfinished room.")
		shutter.rotation.y = frame.rotation.y
		_box(shutter,Vector3(0,1.36,-0.02),Vector3(0.55,0.62,0.04),home[5])
		var panel := _box(shutter,Vector3(0,1.36,0.03),Vector3(0.55,0.62,0.04),WOOD,true)
		shutter.get_node("PropState").bind_visual(panel,"rotation:y",0.0,0.55)
		for index in range(3):
			var position_value: Vector3 = frame.position + frame.basis * Vector3(1.75,0.08,float(index)*0.3-0.3)
			_box(self,position_value,Vector3(0.22,0.12,0.25),home[5])
		_box(frame,Vector3(0,0.025,-2.3),Vector3(1.4,0.04,0.38),Color(0.37,0.39,0.34))
		for index in range(3): _box(frame,Vector3(2.1,0.05,-0.4+index*0.32),Vector3(0.3,0.06,0.27),Color(0.18,0.22,0.13))

func _build_care() -> void:
	var herbs := _point("herb_jars","Read Mira's drying-jar labels",Vector3(-6.0,0,-2.15),"record","Dry stems: shelf above the damp floor. Bitter roots: Mira's measure, not a free dose. Patient parcels: names turned inward. Sorting permitted herbs is useful work; handling these labels cannot disclose a patient's account.")
	_table(herbs,Vector3.ZERO,Vector3(0.9,0.72,0.35))
	for index in range(3):
		Work._rod(game,herbs,Vector3(-0.26+index*0.26,0.82,0),0.07,0.18,Color(0.35,0.43,0.34))
	var linen := _point("care_linen","Fold the clean care linen",Vector3(3.25,0,-5.8),"mechanism","Anwen: Clean side in. No, the other clean side. Thank you. The traveler's cup and Oren's coat still need their own hands, not another promise.")
	linen.set_meta("interaction_anchor",Vector3(0,0.65,0))
	_table(linen,Vector3.ZERO,Vector3(0.7,0.6,0.4))
	var cloth := _box(linen,Vector3(0,0.65,0),Vector3(0.55,0.025,0.28),LINEN,true)
	linen.get_node("PropState").bind_visual(cloth,"scale:x",1.0,0.5)

func _build_bell() -> void:
	var bell := _point("bell_rope","Demonstrate Jory's warning rhythm",Vector3(-10.3,0,-6.65),"mechanism","Three short strokes, then a pause. Jory has cut the same rhythm into the board for anyone who cannot hear it. A warning mechanism does not decide a grave's fate.")
	var rope := Work._rod(game,bell,Vector3(0,0.80,0),0.014,0.9,LINEN)
	bell.get_node("PropState").bind_visual(rope,"position:y",0.80,0.62)
	for index in range(3): _box(bell,Vector3(-0.14+index*0.10,0.40,0.06),Vector3(0.035,0.11,0.025),LINEN)
	_box(bell,Vector3(0.25,0.36,0.06),Vector3(0.18,0.025,0.025),LINEN)
	var catch := _point("bell_catch","Examine the bell-frame catch",Vector3(-11.45,0,-6.8),"mechanism","A newer pin holds the brake; the older catch has a concealed seam. Jory's existing bell-founder clue concerns that seam. Demonstrating the rope neither completes the repair nor claims the compartment.")
	var pin := Work._rod(game,catch,Vector3(0,0.85,0),0.018,0.12,IRON)
	catch.get_node("PropState").bind_visual(pin,"rotation:z",0.0,0.35)

func _build_common() -> void:
	var pieces := _point("game_pieces","Set out the common-table pieces",Vector3(-5.8,0,11.05),"mechanism","Rook: The dark ones are yours if you like. Winning is optional; accusing the cups is traditional. The proper game board keeps its own result.")
	pieces.set_meta("interaction_anchor", Vector3(0,1.04,0))
	for index in range(6):
		var piece := Work._rod(game,pieces,Vector3(-0.2+index*0.08,1.07,0),0.027,0.025,IRON if index%2==0 else LINEN)
		pieces.get_node("PropState").bind_visual(piece,"position:z",0.0,float(index%2)*0.12)
	var seat := _point("common_seat","Sit beside the common table",Vector3(-3.0,0,13.0),"seat","A seat kept clear of the bridge road. Stand whenever you choose; nobody owes the table a game or a confidence.")
	seat.rotation.y = PI * 0.5
	_model(seat,"Bench.obj",0.45,Vector3.ZERO)
	_point("challenges","Read the southern range challenges",Vector3(6.1,0,13.7),"record","Rook: steady hand, eight arrows. Tor: watch a complete pendulum swing. Elna: every distance counts. The untimed practice uses range arrows; your own equipment and ammunition are kept. Losses buy no grievance.")

func _build_cemetery() -> void:
	_point("grave_offerings","Inspect the household grave offerings",Vector3(12.6,0,10.6),"record","A child's thread, a repaired handle, three different ribbons: people left what belonged to the dead, not matching tokens for a ceremony. The chapel scars are physical marks. They cannot tell you who consented.")
	for index in range(3):
		var point := Vector3(12.7+index*1.3,0.07,10.3)
		_box(self,point,Vector3(0.22,0.014,0.08),[LINEN,Color(0.49,0.32,0.29),Color(0.36,0.45,0.51)][index])
	var memorial := _point("cemetery_return","Read the cemetery's kept account",Vector3(12.4,0,11.1),"record","")
	_box(memorial,Vector3(0,0.42,0),Vector3(0.42,0.84,0.12),Color(0.41,0.42,0.38))

func _build_edges() -> void:
	_point("road_sign","Read the northern road sign",Vector3(-1.5,0,-12.3),"record","North: Wychwood, across the village bridge. West: the deeper wood and farmstead road. East: Vargan's approach. The river is crossed on the bridge, not at a painted gap in the bank.")
	for position_value in [Vector3(-2.8,0,12.8),Vector3(8.2,0,9.9),Vector3(-11.9,0,-1.8),Vector3(15.7,0,-6.7)]:
		for index in range(4):
			_box(self,position_value+Vector3(index*0.16,0.08,0),Vector3(0.13,0.16,0.55),Color(0.31,0.33,0.30))
	var storage := _point("yard_storage","Open the repair-yard chest",Vector3(6.8,0,9.0),"container","Offcuts, a spare hinge and a coil kept for tomorrow's work. These are household stock, not free equipment. Elna's repaired door and the relief shares keep their recorded owners.")
	_chest(storage,Vector3(0.64,0.48,0.50))
	var lid := _box(storage,Vector3(0,0.5,0),Vector3(0.64,0.04,0.5),WOOD,true)
	storage.get_node("PropState").bind_visual(lid,"rotation:x",0.0,-0.65)
	for index in range(3): _box(storage,Vector3(-0.16+index*0.15,0.44,0),Vector3(0.1,0.05,0.32))

func _chest(parent: Node3D, size: Vector3) -> void:
	_box(parent,Vector3(0,0.035,0),Vector3(size.x,0.06,size.z))
	for x in [-size.x*0.5,size.x*0.5]: _box(parent,Vector3(x,size.y*0.5,0),Vector3(0.045,size.y,size.z))
	for z in [-size.z*0.5,size.z*0.5]:
		for row in range(4): _box(parent,Vector3(0,size.y*(row+0.5)/4.0,z),Vector3(size.x,size.y/4.0-0.008,0.035))
	for x in [-size.x*0.35,size.x*0.35]: _box(parent,Vector3(x,size.y*0.5,-size.z*0.5-0.02),Vector3(0.025,size.y,0.015),IRON)

func activate(id: String) -> void:
	var key := id.trim_prefix("greyfen_detail:")
	var area: Node3D = props.get(key)
	if not is_instance_valid(area) or not game._interaction_target_valid(area): return
	Guidance.learn(game,"use")
	if key == "guide":
		_read("Before You Take the Road",str(area.get_meta("detail_text")),[{"type":"greyfen_detail_action","operation":"guide","mode":"active","label":"Take the optional village route"},{"type":"greyfen_detail_action","operation":"guide","mode":"dismissed","label":"I will find my own way"}])
		return
	var kind := str(area.get_meta("detail_kind"))
	if kind == "record" or kind == "dummy":
		_read(str(area.display_name),str(area.get_meta("detail_text")))
	elif kind == "seat":
		if _seat == area: _stand()
		elif game.player.velocity.length() < 0.1 and game.player.sword_sheathed and not game.player.bow_aiming and game.player.global_position.distance_to(area.global_position) < 0.35 and Presence.claim(game.player,"work",get_instance_id()):
			_seat = area
			_seat_start = game.player.global_position
			game.player.set_meta("cast_work_cancel",Callable(self,"_stand"))
			game.player.face_target(area.to_global(Vector3(0,0,-1)))
			game.player.animation_driver.set_life_activity("sit")
			game.hud.toast("A moment at the table. Move to stand.",3.0)
		else: game.hud.toast("Come close to the clear seat and put your weapon away.")
	else:
		_begin_work(area,key,kind)

func _begin_work(area: Node3D, key: String, kind: String) -> void:
	var point := area.to_global(area.get_meta("interaction_anchor"))
	if (game.player.global_position + Vector3.UP).distance_to(point) > 1.05:
		game.hud.toast("Come within arm's reach of the fixture.")
		return
	if not game.player.sword_sheathed or game.player.bow_aiming or game._story_has_active_combat():
		game.hud.toast("Put your weapon away before handling the village's things.")
		return
	_cancel_work()
	if not Presence.claim(game.player,"work",get_instance_id()): return
	game.player.set_meta("cast_work_cancel",Callable(self,"_cancel_work"))
	_work = {"area":weakref(area),"key":key,"kind":kind,"start":game.player.global_position,"elapsed":0.0,"contact":false}
	game.player.face_target(Vector3(point.x,game.player.global_position.y,point.z))
	var activity := "check_rope" if kind in ["bucket","mechanism"] else "care"
	game.player.animation_driver.set_life_activity(activity)
	game.player.animation_driver.set_life_workstation({"point":point,"left":point+Vector3(-0.08,0,0),"right":point+Vector3(0.08,0,0),"activity":activity,"period":1.2,"lift":0.04})

func _advance_work() -> void:
	if _work.is_empty(): return
	var area: Node3D = _work.area.get_ref()
	if not is_instance_valid(area) or game.player.global_position.distance_to(_work.start) > 0.18 or game.player.velocity.length() > 0.2 or not game.player.sword_sheathed or Presence.player_threat(game.player) != "" or game._story_has_active_combat():
		_cancel_work()
		return
	_work.elapsed = float(_work.elapsed)+0.1
	var activity := "check_rope" if str(_work.kind) in ["bucket","mechanism"] else "care"
	game.player.animation_driver.set_life_activity(activity)
	if float(_work.elapsed) >= 0.65 and not bool(_work.contact):
		_work.contact = true
		area.get_node("PropState").activate()
		game.hud.toast(str(area.get_meta("detail_text")),5.0)
		if str(_work.kind) == "knock":
			game.audio.play_event("block",0.025)
			_local_motion[str(_work.key)] = 0.7
		if str(_work.key) == "bell_rope": _demonstrate_bell(area)
		game.story_save_pending = true
		game.call_deferred("_persist_story_action")
	if float(_work.elapsed) >= 1.2: _cancel_work()

func _cancel_work() -> void:
	if not _work.is_empty() and is_instance_valid(game.player):
		Presence.release(game.player,"work",get_instance_id())
		if game.player.animation_driver != null: game.player.animation_driver.clear_life_activity()
	_work.clear()

func _read(title: String, text_value: String, actions: Array = []) -> void:
	_cancel_work()
	_stand()
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	game.hud.show_dialogue({"name":title,"pages":[{"speaker":title,"speaker_id":"narrator","text":text_value}],"actions":actions if not actions.is_empty() else [{"type":"close","label":"Continue"}]})

func _demonstrate_bell(area: Node3D) -> void:
	if not game.quests.is_completed("saga_gre_q02"):
		game.hud.toast("Jory: Brake first, pin second. Help finish the warning mechanism before ringing it.",5.0)
		return
	var bell: Node3D = game.zone_root.find_child("WarningBell",true,false)
	var brake: Node3D = game.zone_root.find_child("BellBrake",true,false)
	if brake != null: _pulse(brake,"rotation:z",0.15,0.8)
	if bell != null: _pulse(bell,"rotation:z",0.12,1.2)
	var sequence := create_tween()
	for index in range(3):
		sequence.tween_callback(func():
			if is_instance_valid(game.audio): game.audio.play_spatial_event("shrine_bell",area.global_position,game.player.global_position,14.0,0.08,0.0))
		sequence.tween_interval(0.36)

func _pulse(node: Node3D, property: String, amount: float, seconds: float) -> void:
	var base: float = float(node.get_indexed(NodePath(property)))
	if bool(game.settings.settings.get("reduced_motion",false)): return
	var tween := node.create_tween()
	tween.tween_property(node,property,base+amount,seconds*0.25)
	tween.tween_property(node,property,base,seconds*0.75)

func _refresh() -> void:
	if not is_inside_tree(): return
	var memorial: Node3D = props.get("cemetery_return")
	if is_instance_valid(memorial):
		var resolved := bool(game.story_state.get_flag("bell_eater_defeated",false)) or bool(game.story_state.get_flag("bell_eater_legacy_retired",false))
		var rite := str(game.story_state.get_flag("crow_shrine_state",""))
		memorial.set_meta("detail_text","The bell is still. " + ({"cleansed":"The bindings lie open; ribbons are laid beside the names, not tied around them.","disturbed":"The disturbed names remain. The village has not pretended the damage away.","bound":"The rite still binds. The offerings do not claim anyone chose freely."}.get(rite,"The shrine still awaits a decision.") if resolved else "Clapper scars and disturbed earth interrupt the old path. Anwen's investigation, not a decorative offering, must establish what happened."))
	var cover: Node = props.well_cover.get_node("PropState")
	if str(game.story_state.get_flag("saga_secret_GRE-S02","")) != "" and cover.current_state != "open": cover.set_state("open",false)

func _physics_process(delta: float) -> void:
	_tick += delta
	if _tick < 0.1: return
	_tick = 0.0
	if not bool(game.game_started) or not game.player.can_control or str(game.current_zone_id) != "greyfen": return
	_advance_work()
	if game.quests.is_completed("main_road_of_crows") and not bool(game.story_state.get_flag("greyfen_guide_care_closed",false)):
		game.story_state.set_flag("greyfen_guide_care_closed",true)
	if is_instance_valid(_seat):
		if game.player.velocity.length() > 0.1 or game.player.global_position.distance_to(_seat_start) > 0.1 or not game.player.sword_sheathed or game.player.dodge_time > 0:
			_stand()
		else: game.player.animation_driver.set_life_activity("sit")
	for key: String in _local_motion.keys():
		_local_motion[key] = float(_local_motion[key])-0.1
		if float(_local_motion[key]) <= 0:
			props[key].get_node("PropState").set_state("closed")
			_local_motion.erase(key)
	if str(game.story_state.get_flag("greyfen_guide","")) != "active":
		_last_position = Vector3.INF
		if bool(game.story_state.get_flag("greyfen_guide_available",false)) and not bool(game.story_state.get_flag("greyfen_guide_offered",false)):
			game.story_state.set_flag("greyfen_guide_offered",true)
			game.story_save_pending = true
			game.call_deferred("_persist_story_action")
			game.hud.toast("Rook left Before You Take the Road by the arrival yard. An optional village route; resume it from the journal whenever you choose.",8.0)
		return
	var point: Vector3 = game.player.global_position
	if _last_position != Vector3.INF and point.distance_to(_last_position) < 1.0: _walked += point.distance_to(_last_position)
	_last_position = point
	if _walked > 3.0: Guidance.learn(game,"move")
	var forward: Vector3 = game.camera_rig.get_flat_forward()
	if _look_basis != Vector3.ZERO: _looked += absf(_look_basis.signed_angle_to(forward,Vector3.UP))
	_look_basis = forward
	if _looked > 0.7: Guidance.learn(game,"look")
	if point.distance_to(DUMMY) < 3.0:
		if game.player.is_blade_ready():
			_observed_drawn = true
			Guidance.learn(game,"draw")
		if _observed_drawn and game.player.sword_sheathed: Guidance.learn(game,"sheath")
		if game.player.dodge_time > 0.0: Guidance.learn(game,"dodge")
	if game.player.bow_aiming and not game.camera_rig.is_first_person():
		var range_node: Node = game.zone_root.get_node_or_null("GreyfenArcheryRange")
		if range_node != null and range_node.running: Guidance.learn(game,"bow_third")
	if game.quests.is_objective_done("main_road_of_crows","speak_anwen"): Guidance.learn(game,"road")
	var view: Dictionary = Guidance.view(game.story_state,"greyfen")
	var signature := str(view.get("id","")) + str(game.input_router.active_device) + str(game.input_router.get_action_bindings(str(view.get("binding","interact"))))
	if signature != _hint_key:
		_hint_key = signature
		var instruction := str(view.get("action",""))
		if not view.is_empty(): instruction += " - " + game.input_router.action_label(str(view.binding))
		game.hud.set_guidance_hint(instruction,8.0)

func _stand() -> void:
	if not is_instance_valid(_seat): return
	_seat = null
	if is_instance_valid(game.player):
		Presence.release(game.player,"work",get_instance_id())
		if game.player.animation_driver != null: game.player.animation_driver.clear_life_activity()

func blade_contact(contact: Dictionary) -> bool:
	if int(contact.get("attack_id",-1)) == _attack_id or not game.player.is_blade_ready() or game.player.global_position.distance_to(DUMMY) > float(contact.get("reach",2.0))+0.6: return false
	var center := global_transform * (DUMMY+Vector3(0,1,0))
	var base: Vector3 = contact.get("base",Vector3.ZERO)
	var tip: Vector3 = contact.get("tip",base)
	var closest: Vector3 = game.combat._closest_sweep_point(center,contact.get("previous_base",base),contact.get("previous_tip",tip),base,tip)
	if center.distance_to(closest) > 0.52: return false
	var ray := PhysicsRayQueryParameters3D.create(game.player.global_position+Vector3.UP,center,1)
	ray.exclude = [game.player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return false
	_attack_id = int(contact.get("attack_id",-1))
	Guidance.learn(game,"heavy" if bool(contact.get("heavy",false)) else "light")
	_pulse(props.dummy,"rotation:z",0.04,0.3)
	return true

func oathfire_contact(cast: Dictionary) -> void:
	var center := global_transform * (DUMMY+Vector3(0,1,0))
	var point := Geometry3D.get_closest_point_to_segment(center,cast.origin,cast.endpoint)
	if point.distance_to(center) <= 0.65 and float(cast.charge_ratio) > 0.0:
		Guidance.learn(game,"oathfire")
		_pulse(props.dummy,"rotation:z",0.06,0.4)

func _exit_tree() -> void:
	_cancel_work()
	_stand()
