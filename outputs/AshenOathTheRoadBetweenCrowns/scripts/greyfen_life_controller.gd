extends Node

const CharacterPresentation = preload("res://scripts/character_presentation.gd")

const AMBIENT_LINES := {
	"greyfen_road_quiet":"Road's quiet today. That's worse.",
	"greyfen_bell_dawn":"Bell rang before dawn. Nobody touched it.",
	"greyfen_shrine_voice":"Keep your voice low near the shrine.",
	"greyfen_anwen_sleep":"Anwen has not slept.",
	"greyfen_crows_fat":"Crows came back fat.",
	"greyfen_woods_stare":"Don't stare at the woods. It stares back.",
	"greyfen_forge_night":"Tor worked the forge through the night.",
	"greyfen_well_iron":"Water tastes of iron again.",
	"greyfen_cart_light":"Cart came back lighter than it left.",
	"greyfen_roots_bitter":"Mira says the roots are bitter this year.",
	"greyfen_north_smoke":"No smoke from the north road.",
	"greyfen_keep_working":"We keep working. What else is there?"
}

var host: Node
var player: Node3D
var actors: Array = []
var line_cooldown := 5.0
var quality := "balanced"
var rng := RandomNumberGenerator.new()

func configure(game: Node, quality_preset: String) -> void:
	host = game
	player = game.player
	quality = quality_preset
	rng.seed = 44017
	_build_population()
	_enroll_named_npcs()

func actor_count() -> int:
	return actors.size()

func routine_ids() -> Array:
	return actors.map(func(entry): return str(entry.id))

func _process(delta: float) -> void:
	if host == null or player == null or get_tree().paused: return
	line_cooldown = max(line_cooldown - delta, 0.0)
	for entry in actors:
		_update_actor(entry, delta)

func _build_population() -> void:
	var population := 6 if quality == "potato" else (10 if quality == "quality" else 8)
	var definitions := [
		{"id":"walker_well","path":[Vector3(-12,0,8),Vector3(-5,0,5),Vector3(-8,0,-1)],"speed":1.05},
		{"id":"walker_board","path":[Vector3(-11,0,-4),Vector3(-4,0,7),Vector3(1,0,8)],"speed":0.92},
		{"id":"shrine_pilgrim","path":[Vector3(-4,0,-9),Vector3(2,0,-8),Vector3(4.6,0,-6.6)],"speed":0.72},
		{"id":"forge_helper","path":[Vector3(7,0,7),Vector3(10,0,5),Vector3(8,0,2)],"speed":0.82},
		{"id":"herb_helper","path":[Vector3(-9,0,-4),Vector3(-7,0,-2),Vector3(-10,0,1)],"speed":0.78},
		{"id":"worried_villager","path":[Vector3(4,0,10),Vector3(1,0,5),Vector3(3,0,1)],"speed":0.68},
		{"id":"young_villager","path":[Vector3(-12,0,5),Vector3(-8,0,3),Vector3(-10,0,0)],"speed":1.32,"scale":0.82},
		{"id":"water_carrier","path":[Vector3(-14,0,-2),Vector3(-9,0,-1),Vector3(-6,0,3)],"speed":0.86},
		{"id":"quality_sweeper","path":[Vector3(6,0,8),Vector3(4,0,5),Vector3(7,0,2)],"speed":0.62},
		{"id":"quality_mourner","path":[Vector3(10,0,11),Vector3(12,0,9),Vector3(10,0,7)],"speed":0.58}
	]
	for i in range(population):
		var definition: Dictionary = definitions[i]
		var actor := Node3D.new()
		actor.name = "Routine_%s" % definition.id
		actor.position = definition.path[0]
		host.zone_root.add_child(actor)
		var limbs := _make_lightweight_villager(actor,i,float(definition.get("scale",1.0)))
		actors.append({"id":definition.id,"node":actor,"path":definition.path,"target":1,"speed":definition.speed,"pause":rng.randf_range(0.4,2.4),"driver":null,"named":false,"limbs":limbs,"phase":rng.randf()*TAU,"base_y":actor.position.y})

func _enroll_named_npcs() -> void:
	var named := {
		"blacksmith_tor":{"path":[Vector3(9.5,0,3),Vector3(10.4,0,4.7),Vector3(8.7,0,4.4)],"speed":0.55},
		"mira":{"path":[Vector3(-6.8,0,-2.3),Vector3(-8.5,0,-1.2),Vector3(-7.7,0,-4.1)],"speed":0.52},
		"rook":{"path":[Vector3(-7.8,0,8.5),Vector3(-6.2,0,6.8),Vector3(-3.8,0,8.6)],"speed":0.62}
	}
	for id in named:
		var node = host.zone_root.find_child(id,true,false)
		if node == null: continue
		var ambient = node.find_child("NpcAmbient",true,false)
		if ambient != null: ambient.process_mode = Node.PROCESS_MODE_DISABLED
		actors.append({"id":id,"node":node,"path":named[id].path,"target":1,"speed":named[id].speed,"pause":rng.randf_range(1.0,3.0),"driver":node.find_child("CharacterAnimationDriver",true,false),"named":true,"phase":rng.randf()*TAU,"base_y":node.position.y})

func _update_actor(entry: Dictionary, delta: float) -> void:
	var node: Node3D = entry.node
	if not is_instance_valid(node): return
	var distance_to_player := node.global_position.distance_to(player.global_position)
	if distance_to_player < 2.1:
		entry.pause = max(float(entry.pause), 1.2)
		_face(node, player.global_position, delta)
		_set_motion(entry,0.0)
		if line_cooldown <= 0.0 and not bool(entry.named):
			line_cooldown = 8.0
			var lines: Array = AMBIENT_LINES.values()
			host.hud.toast(str(lines[rng.randi_range(0,lines.size()-1)]))
		return
	if float(entry.pause) > 0.0:
		entry.pause = float(entry.pause) - delta
		_set_motion(entry,0.0)
		return
	var target: Vector3 = entry.path[int(entry.target)]
	var offset := target - node.position
	offset.y = 0.0
	if offset.length() < 0.18:
		entry.target = (int(entry.target) + 1) % entry.path.size()
		entry.pause = rng.randf_range(1.4,3.8) * (1.4 if str(entry.id) == "shrine_pilgrim" else 1.0)
		_set_motion(entry,0.0)
		return
	var direction := offset.normalized()
	node.position += direction * float(entry.speed) * delta
	_face(node,node.global_position + direction,delta)
	_set_motion(entry,float(entry.speed))

func _set_motion(entry: Dictionary, speed: float) -> void:
	var driver = entry.driver
	if driver != null and driver.has_method("set_locomotion"):
		driver.set_locomotion(clampf(speed / 1.3,0.0,1.0),Vector3.ZERO,true)
	elif entry.has("limbs"):
		entry.phase = float(entry.phase) + get_process_delta_time() * (1.2 + speed * 3.0)
		var swing := sin(float(entry.phase)) * (0.48 if speed > 0.05 else 0.04)
		entry.limbs[0].rotation.x = swing
		entry.limbs[1].rotation.x = -swing
		entry.node.position.y = float(entry.base_y) + abs(sin(float(entry.phase)*2.0)) * (0.025 if speed > 0.05 else 0.008)

func _face(node: Node3D, target: Vector3, delta: float) -> void:
	var offset := target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted := atan2(-offset.x,-offset.z)
	node.rotation.y = lerp_angle(node.rotation.y,wanted,min(delta*3.0,1.0))

func _make_lightweight_villager(parent: Node3D, index: int, scale_value: float) -> Array:
	var cloth_colors := [Color(0.25,0.20,0.15),Color(0.18,0.24,0.20),Color(0.26,0.17,0.16),Color(0.20,0.20,0.27)]
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = cloth_colors[index % cloth_colors.size()]; cloth.roughness = 0.92
	var skin := StandardMaterial3D.new(); skin.albedo_color = Color(0.54,0.39,0.29); skin.roughness = 0.9
	var torso := MeshInstance3D.new(); var torso_mesh := CapsuleMesh.new(); torso_mesh.radius = 0.30; torso_mesh.height = 1.05; torso.mesh = torso_mesh; torso.position.y = 1.15; torso.scale = Vector3.ONE*scale_value; torso.material_override = cloth; parent.add_child(torso)
	var head := MeshInstance3D.new(); var head_mesh := SphereMesh.new(); head_mesh.radius = 0.23; head_mesh.height = 0.46; head.mesh = head_mesh; head.position.y = 1.88*scale_value; head.scale = Vector3.ONE*scale_value; head.material_override = skin; parent.add_child(head)
	var limbs: Array = []
	for side in [-1.0,1.0]:
		var leg := MeshInstance3D.new(); var leg_mesh := CapsuleMesh.new(); leg_mesh.radius = 0.10; leg_mesh.height = 0.70; leg.mesh = leg_mesh; leg.position = Vector3(side*0.15,0.48,0)*scale_value; leg.scale = Vector3.ONE*scale_value; leg.material_override = cloth; parent.add_child(leg); limbs.append(leg)
	return limbs
