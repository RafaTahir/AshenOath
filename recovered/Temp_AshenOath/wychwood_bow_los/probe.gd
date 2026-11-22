extends SceneTree
const Fixture = preload("res://tools/runtime_fixture.gd")
const Surface = preload("res://scripts/spatial_surface_contract.gd")
var game: Node
var enemy: Node3D
var report := {"status":"STARTING", "failed_seeds":[], "candidates":[], "clear_candidates":[]}
var folder := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[args.find("--output") + 1]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	print("LOS_STAGE actual Game created")
	if not await Fixture.menu(game):
		quit(2)
		return
	game.settings.set_quality_preset("balanced")
	var seed := FileAccess.get_file_as_string(folder.path_join("seed.json"))
	assert(game.save_manager.import_save_text(seed,"manual_1"))
	assert(game.save_manager.load_slot(game,"manual_1"))
	if not await Fixture.ready(game,"wychwood"):
		quit(3)
		return
	for actor: Node in game.active_enemies:
		actor.set_physics_process(false)
		if actor.enemy_id == "wychwood_raider": enemy = actor
	assert(enemy != null and enemy.encounter_active)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.camera_rig.set_process(false)
	game.camera_rig.set_physics_process(false)
	game.player.load_equipment_state({"schema_version":3,"active_weapon":"bow","selected_blade_id":"steel","sword_drawn":false,"bow_drawn":true,"bow_aiming":true,"selected_arrow_id":"standard_arrow"})
	game.player.bow_aiming = true
	for _index in 4: await physics_frame
	report["quality"] = game.settings.settings.duplicate(true)
	report["zone"] = game.current_zone_id
	report["zone_transform"] = str(game.zone_root.global_transform)
	report["enemy_position"] = _v(enemy.global_position)
	report["enemy_active"] = enemy.encounter_active
	report["enemy_health"] = enemy.health_component.health
	print("LOS_STAGE Wychwood ready; quality=",report.quality.quality_preset," enemy=",enemy.global_position)
	for position: Vector3 in [Vector3(3,0,6.2),Vector3(3,0,4.0)]:
		var result: Dictionary = await _probe(position)
		report.failed_seeds.append(result)
		print("LOS_FAILED_SEED ",JSON.stringify(result))
		report.status = "FAILED_SEEDS_RECORDED"
		_save()
	for radius: float in [9.5,10.6,11.6]:
		for index in 12:
			var angle := TAU * float(index) / 12.0
			var candidate := enemy.global_position + Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if absf(candidate.x)>20 or absf(candidate.z)>15.8: continue
			var result: Dictionary = await _probe(candidate)
			report.candidates.append(result)
			if result.valid_floor and result.camera_visible and result.muzzle_clear and result.eye_to_muzzle_clear and result.endpoint_world_overlaps.is_empty():
				report.clear_candidates.append(result)
		print("LOS_STAGE ring ",radius," clear=",report.clear_candidates.size())
		report.status = "SCANNING"
		_save()
	report.status = "RECORDED"
	report["limits"] = "Actual authored Wychwood + native P01/M19; imported disposable replay seed; actors' physics ticks paused after load, colliders/content retained. Native Balanced. Diagnostic repositioning, not browser acceptance."
	_save()
	print("LOS_COMPLETE clear=",report.clear_candidates.size()," output=",folder.path_join("report.json"))
	await Fixture.shutdown(game)
	quit()

func _probe(requested: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var excluded: Array[RID] = [game.player.get_rid(),enemy.get_rid()]
	var floor := Surface.support_hit(space,requested+Vector3.UP*6,requested-Vector3.UP*12,excluded,game.zone_root)
	var ground := requested
	if not floor.is_empty(): ground.y = float(floor.position.y)+0.00021
	game.player.global_position = ground
	var offset: Vector3 = enemy.global_position-ground
	game.player.rotation.y = atan2(-offset.x,-offset.z)
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = game.player.rotation.y
	game.camera_rig.reset_follow()
	for _index in 3:
		game.player._animate_visuals(1.0/60.0)
		game.camera_rig._process(1.0/60.0)
		await physics_frame
	var camera_rays := []
	for index in 2:
		var origin: Vector3 = ground+Vector3.UP*([1.05,1.48][index])
		var end: Vector3 = enemy.global_position+Vector3.UP*([0.88,1.42][index])
		camera_rays.append({"from":_v(origin),"to":_v(end),"hit":_ray(origin,end,excluded,1)})
	var muzzle: Vector3 = game.player.get_arrow_origin()
	var aim: Vector3 = game.player.locked_bow_aim_point(enemy)
	var muzzle_hit := _ray(muzzle,aim,[game.player.get_rid()],1|128)
	var eye: Vector3 = ground+Vector3.UP*game.player.get_camera_eye_height()
	var eye_hit := _ray(eye,muzzle,[game.player.get_rid()],1)
	var overlaps := []
	for endpoint: Vector3 in [enemy.global_position+Vector3.UP*.88,enemy.global_position+Vector3.UP*1.42,aim]:
		var query := PhysicsPointQueryParameters3D.new()
		query.position = endpoint
		query.collision_mask = 1
		query.exclude = excluded
		query.collide_with_areas = false
		for hit: Dictionary in space.intersect_point(query,16):
			overlaps.append({"point":_v(endpoint),"collider":_describe(hit)})
	var occupied: bool = game.spatial_service.is_position_occupied(ground,0.468,1.65)
	var valid_floor: bool = not floor.is_empty() and not game.spatial_service.is_river_excluded(ground,0.9) and not occupied
	return {"requested":_v(requested),"grounded":_v(ground),"distance":Vector2(offset.x,offset.z).length(),"valid_floor":valid_floor,
		"floor":_describe(floor),"occupied":occupied,"camera_visible":game.camera_rig._target_is_visible_uncached(enemy),"camera_rays":camera_rays,
		"muzzle":_v(muzzle),"eye":_v(eye),"aim_body_center":_v(aim),"muzzle_hit":muzzle_hit,
		"muzzle_clear":muzzle_hit.is_empty() or str(muzzle_hit.get("path",""))==str(enemy.get_path()),
		"eye_to_muzzle_hit":eye_hit,"eye_to_muzzle_clear":eye_hit.is_empty(),"endpoint_world_overlaps":overlaps,
		"actual_bow_solution":str(game.camera_rig.bow_aim_solution(muzzle,game.player.BOW_RANGE))}

func _ray(from: Vector3,to: Vector3,excluded: Array[RID],mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,mask)
	query.exclude = excluded
	query.collide_with_areas = false
	query.hit_from_inside = false
	return _describe(game.get_world_3d().direct_space_state.intersect_ray(query))

func _describe(hit: Dictionary) -> Dictionary:
	if hit.is_empty(): return {}
	var body: Node3D = hit.get("collider") as Node3D
	if body == null: return {"hit":true}
	var result := {"name":str(body.name),"path":str(body.get_path()),"class":body.get_class(),"transform":str(body.global_transform),
		"layer":body.collision_layer,"shape_index":int(hit.get("shape",-1)),"position":_v(hit.get("position",Vector3.ZERO))}
	if body is CollisionObject3D and result.shape_index >= 0:
		var owner_id: int = body.shape_find_owner(result.shape_index)
		var owner: Object = body.shape_owner_get_owner(owner_id)
		result["shape_owner"] = str(owner.get_path()) if owner is Node else str(owner)
		result["shape_transform"] = str(body.global_transform * body.shape_owner_get_transform(owner_id))
		for index in body.shape_owner_get_shape_count(owner_id):
			if body.shape_owner_get_shape_index(owner_id,index)==result.shape_index:
				var shape: Shape3D = body.shape_owner_get_shape(owner_id,index)
				result["shape_class"] = shape.get_class()
				result["shape_data"] = str(shape.size) if shape is BoxShape3D else ("radius=%s height=%s" % [shape.radius,shape.height] if shape is CapsuleShape3D or shape is CylinderShape3D else shape.resource_path)
	return result

func _v(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _save() -> void:
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t",true)+"\n")
