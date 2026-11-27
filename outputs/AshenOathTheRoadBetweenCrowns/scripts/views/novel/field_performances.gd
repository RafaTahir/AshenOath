extends Node3D
## Called at the end of NovelScenes.refresh, after the source stations and burden
## have been reconciled. Reads the current beat and its clock; owns only visuals.
const Artist = preload("res://scripts/views/novel/field_cast.gd")
const ActorMark = preload("res://scripts/views/novel/field_actor_mark.gd")
const Stage = preload("res://scripts/views/novel/field_stage.gd")
const ART := "res://assets/narrative_props/field/"
const SCENES := {"willow_frame":"willow", "tor_wrist":"gallery", "culvert":"culvert"}
const WAKE_DISTANCE := 26.0

var layer: Node
var ground: Stage
var anchor: Node3D
var ground_key := ""
var ground_index := -1
var ground_generation := Vector3.INF
var carry: Node3D
var carry_key := ""
var holder: Node3D
var hidden_work: Node3D
var hidden_bench: Node3D
var hidden_burden: Array[Node3D] = []
var leases: Dictionary[String, Artist] = {}
var requested_packs := {}
var rescan := 0.0
var work_position := -1.0
var front_pose: Artist.Pose

static func project(owner_layer: Node) -> void:
	var active := false
	for key: String in SCENES:
		if owner_layer.turns.has(key): active = true
	var burden := _carried_frame(owner_layer.game.player)
	var aftermath := _in_washroom(owner_layer)
	var field := owner_layer.get_node_or_null("FieldPerformances")
	if not active and not aftermath and burden == null:
		if field != null: field.retire()
		return
	if field == null:
		field = new()
		field.name = "FieldPerformances"
		field.layer = owner_layer
		owner_layer.add_child(field)
	field.reconcile(burden, aftermath)

static func _carried_frame(player: Node3D) -> Node3D:
	if not is_instance_valid(player): return null
	var prop := player.get_node_or_null("NovelBurden") as Node3D
	if prop == null or prop.is_in_group(&"novel_burden_load"): return null
	if prop.is_in_group(&"novel_burden_frame"): return prop
	# Earlier scene controllers identified the same transient prop with a tag.
	return prop if player.read_presentation_tag(prop, &"kind", "") == "frame" else null

static func _in_washroom(owner_layer: Node) -> bool:
	if owner_layer.zone != "vargan_approach": return false
	var state = owner_layer.game.story_state
	return int(state.get_flag("novel_step_culvert", 0)) >= 4 and not state.get_flag("novel_done_counterpart", false) and not owner_layer.game.quests.is_completed("main_blood_under_stone")

func reconcile(burden: Node3D, aftermath: bool) -> void:
	var key := ""
	var index := -1
	var site: Node3D
	var position_at := Vector3.ZERO
	for candidate: String in SCENES:
		if layer.turns.has(candidate):
			var turn: Dictionary = layer.turns[candidate]
			key = candidate
			index = int(turn.index)
			site = layer.stations.get("novel_%s_%d" % [key, index])
			if is_instance_valid(site): position_at = site.global_position
			break
	if key.is_empty() and aftermath:
		key = "culvert"
		index = 4
		site = layer.stations.get("novel_culvert_3")
		if is_instance_valid(site):
			position_at = site.global_position
		else:
			# A fresh arrival has no station for the already-completed deposition.
			for scene: Dictionary in layer._book(3):
				if scene.id == "culvert":
					var at: Array = scene.beats[3].at
					position_at = layer.game.river_safe_position(Vector3(at[0], 0.0, at[1]), 0.8)
					break
	if ground_key != key or ground_index != index or ground_generation != position_at or (anchor != site):
		_clear_ground()
		if not key.is_empty() and (is_instance_valid(site) or aftermath):
			ground = _instance(SCENES[key]) as Stage
			if ground != null:
				ground_key = key
				ground_index = index
				ground_generation = position_at
				anchor = site
				add_child(ground)
				ground.global_position = position_at
				ground.set_beat(index)
				if is_instance_valid(site) and not (key == "culvert" and index == 4):
					var generic := site.get_node_or_null("Workpiece") as Node3D
					if generic != null and generic.visible:
						hidden_work = generic
						generic.hide()
	if ground_key == "tor_wrist":
		var bench := layer.get_node_or_null("WorkAftermath/measuring_bench") as Node3D
		if bench != null and bench.visible:
			hidden_bench = bench
			bench.hide()
	var carried := ""
	if is_instance_valid(burden):
		if int(layer.game.story_state.get_flag("novel_step_culvert", 0)) == 3: carried = "culvert"
		elif int(layer.game.story_state.get_flag("novel_step_willow_frame", 0)) in [2,3]: carried = "willow"
	if carry_key != carried or holder != burden or (not carried.is_empty() and not is_instance_valid(carry)):
		_clear_carry()
		if not carried.is_empty():
			carry = _instance(carried + "_carry")
			if carry != null:
				holder = burden
				carry_key = carried
				for item in burden.get_children():
					if item is Node3D and item.visible:
						hidden_burden.append(item)
						item.hide()
				layer.game.player.add_child(carry)
				_place_carry(0.0)
				_bind_front_grip()
	rescan = 0.0
	set_physics_process(is_instance_valid(ground) or is_instance_valid(carry) or not leases.is_empty())

func _instance(asset: String) -> Node3D:
	var scene := load(ART + asset + ".tscn") as PackedScene
	return scene.instantiate() as Node3D if scene != null else null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(layer.game.zone_root) or layer.owner_director.get_parent() != layer.game.zone_root:
		retire()
		return
	var pending: Dictionary = layer.pending
	var progress := 0.0
	if is_instance_valid(ground) and pending.get("key", "") == ground_key and int(pending.get("index", -1)) == ground_index:
		var seconds := float(layer.turns[ground_key].beat.get("seconds", 0.0))
		if seconds > 0: progress = clampf(float(layer.elapsed) / seconds, 0.0, 1.0)
	if not is_equal_approx(progress, work_position):
		work_position = progress
		if is_instance_valid(ground):
			ground.set_work(progress)
	if is_instance_valid(carry):
		_place_carry(progress)
		for lease in leases.values():
			if is_instance_valid(lease.mark) and carry.is_ancestor_of(lease.mark) and lease.mark.pose == "carry":
				lease.follow_bearer(layer.game.player.global_position.y, delta)
	rescan -= delta
	if rescan <= 0.0:
		rescan = 0.24
		_reconcile_people()

func _place_carry(progress: float) -> void:
	if not is_instance_valid(carry): return
	var player: Node3D = layer.game.player
	var forward := -player.global_basis.z.normalized()
	if is_instance_valid(player.animation_driver):
		var visible: Vector3 = player.animation_driver.get_visible_forward()
		if not visible.is_zero_approx(): forward = visible
	var facing := Basis.looking_at(forward, Vector3.UP)
	# For Oren, the near rail bears on Kael's shoulder while Mira holds
	# the far end at waist height. Rook travels on a level two-hand litter.
	var grip := Transform3D(facing, player.global_position + facing * Vector3(0, 0.92, 0.12))
	if carry_key == "willow":
		grip = Transform3D(facing * Basis(Vector3.RIGHT, 0.254), player.global_position + facing * Vector3(-0.46, 1.45, -0.14))
	var stand: Marker3D
	if is_instance_valid(ground): stand = ground.get_node_or_null("SetDown") as Marker3D
	if progress > 0.0 and stand != null and stand.visible:
		grip = grip.interpolate_with(stand.global_transform, smoothstep(0.0, 1.0, progress))
	carry.global_transform = grip

func _bind_front_grip() -> void:
	var driver = layer.game.player.animation_driver
	if not is_instance_valid(driver) or not driver.is_valid(): return
	var point := ActorMark.new()
	point.name = "KaelGrip"
	point.pose = "front_carry"
	carry.add_child(point)
	var left := Marker3D.new()
	left.name = "LeftHand"
	point.add_child(left)
	if carry_key == "willow":
		left.position = Vector3(0.25, 0.025, 0.05)
	else:
		left.position = Vector3(-0.34, 0.022, 0.05)
		var right := Marker3D.new()
		right.name = "RightHand"
		point.add_child(right)
		right.position = Vector3(0.34, 0.022, 0.05)
	front_pose = Artist.Pose.new()
	driver.skeleton.add_child(front_pose)
	front_pose.bind(point, driver)

func _reconcile_people() -> void:
	var desired: Dictionary[String, ActorMark] = {}
	var game = layer.game
	if is_instance_valid(game.player) and not game.zone_transition_pending and not game._story_has_active_combat():
		if is_instance_valid(ground) and ground.global_position.distance_squared_to(game.player.global_position) <= WAKE_DISTANCE * WAKE_DISTANCE:
			_collect(ground, desired)
		if is_instance_valid(carry):
			_collect(carry, desired)
	for id: String in leases.keys():
		var lease = leases[id]
		var point: ActorMark = desired.get(id)
		if lease.interrupted and is_instance_valid(lease.actor) and Artist.Presence.has_protected_owner(lease.actor):
			desired.erase(id)
			continue
		var resident := Artist.resident(game.zone_root, id) if lease.temporary else null
		if point != null and is_instance_valid(lease.mark) and point == lease.mark and is_instance_valid(lease.actor) and is_instance_valid(lease.driver) and not lease.interrupted and resident == null and not lease.driver.dead and lease.actor.is_visible_in_tree():
			desired.erase(id)
			continue
		lease.release()
		leases.erase(id)
	for id: String in desired:
		var mark: ActorMark = desired[id]
		var offset: Vector3 = mark.global_position - game.player.global_position
		if absf(offset.y) < 1.9 and Vector2(offset.x, offset.z).length_squared() < 0.84 * 0.84:
			continue
		var lease := Artist.new()
		var role := mark.role
		if carry_key == "willow" and layer.zone == "greyfen" and mark.name == &"RearBearer":
			role = "sister_anwen_human"
		if lease.take(game, self, mark, id, role, requested_packs): leases[id] = lease

func _collect(art: Node3D, desired: Dictionary[String, ActorMark]) -> void:
	var markers := art.get_node_or_null("Actors")
	if markers == null: return
	for mark in markers.get_children():
		if mark is ActorMark and mark.is_visible_in_tree():
			var id: String = mark.identity
			if art == carry and carry_key == "willow" and layer.zone == "greyfen" and mark.name == &"RearBearer":
				id = "sister_anwen"
			desired[id] = mark

func _clear_ground() -> void:
	if is_instance_valid(hidden_work): hidden_work.show()
	hidden_work = null
	if is_instance_valid(hidden_bench) and is_instance_valid(layer) and is_instance_valid(layer.game) and layer.game.story_state.get_flag("novel_tor_braced", false):
		hidden_bench.show()
	hidden_bench = null
	if is_instance_valid(ground):
		ground.hide()
		ground.queue_free()
	ground = null
	anchor = null
	ground_key = ""
	ground_index = -1
	ground_generation = Vector3.INF
	work_position = -1.0

func _clear_carry() -> void:
	if is_instance_valid(front_pose):
		front_pose.active = false
		front_pose.free()
	if is_instance_valid(carry):
		carry.hide()
		carry.queue_free()
	for item in hidden_burden:
		if is_instance_valid(item): item.show()
	hidden_burden.clear()
	carry = null
	holder = null
	carry_key = ""
	work_position = -1.0

func retire() -> void:
	_clear_ground()
	_clear_carry()
	for lease in leases.values(): lease.release()
	leases.clear()
	requested_packs.clear()
	set_physics_process(false)

func _exit_tree() -> void:
	retire()
