extends Node

const CharacterPresentation = preload("res://scripts/character_presentation.gd")
const AssetSpawnHelper = preload("res://scripts/asset_spawn_helper.gd")
const CharacterAnimationDriver = preload("res://scripts/character_animation_driver.gd")

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
var asset_helper

func configure(game: Node, quality_preset: String) -> void:
	host = game
	player = game.player
	quality = quality_preset
	rng.seed = 44017
	asset_helper = AssetSpawnHelper.new()
	add_child(asset_helper)
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
		var driver = _make_skeletal_villager(actor, str(definition.id), i, float(definition.get("scale",1.0)))
		actors.append({"id":definition.id,"node":actor,"path":definition.path,"target":1,"speed":definition.speed,"pause":rng.randf_range(0.4,2.4),"driver":driver,"named":false,"phase":rng.randf()*TAU,"base_y":actor.position.y})

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
	entry.phase = float(entry.phase) + get_process_delta_time() * (0.8 + speed * 1.7)

func _face(node: Node3D, target: Vector3, delta: float) -> void:
	var offset := target - node.global_position
	offset.y = 0.0
	if offset.length() < 0.05: return
	var wanted := atan2(-offset.x,-offset.z)
	node.rotation.y = lerp_angle(node.rotation.y,wanted,min(delta*3.0,1.0))

func _make_skeletal_villager(parent: Node3D, role_id: String, index: int, scale_value: float):
	var mapped = asset_helper.spawn_visual_role("villager_human", "characters")
	if mapped == null or mapped.name.ends_with("_placeholder"):
		push_error("Rigged villager asset unavailable for %s" % role_id)
		return null
	mapped.name = "%s_rigged_human" % role_id
	mapped.scale = Vector3.ONE * (0.56 * scale_value * (0.97 + 0.025 * float(index % 3)))
	mapped.rotation_degrees.y = 180.0
	parent.add_child(mapped)
	CharacterPresentation.apply_npc(parent, role_id)
	var driver = CharacterAnimationDriver.new()
	driver.name = "CharacterAnimationDriver"
	mapped.add_child(driver)
	driver.configure(mapped, {"idle":"Idle", "walk":"Walk", "run":"Run", "hit":"RecieveHit", "death":"Death"})
	return driver
