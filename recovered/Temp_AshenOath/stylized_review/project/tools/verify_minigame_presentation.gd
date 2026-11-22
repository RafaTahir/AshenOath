extends SceneTree

const SpatialSurfaceContract = preload("res://scripts/spatial_surface_contract.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture and DisplayServer.get_name().to_lower() == "headless":
		_check(false, "Board capture requires graphical rendering")
		_finish()
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene is unavailable")
	if packed == null:
		_finish()
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	if not await preload("res://tools/runtime_fixture.gd").start(game):
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (game.zone_root == null or not bool(game.zone_root.get_meta("opening_detail_complete", false))):
		await process_frame
	_check(game.zone_root != null and bool(game.zone_root.get_meta("opening_detail_complete", false)), "Board presentation requires the complete opening scene")
	if "--solid-furniture" in OS.get_cmdline_user_args():
		await _verify_solidity(game)
		await preload("res://tools/runtime_fixture.gd").shutdown(game)
		_finish()
		return
	var camera: Camera3D
	if capture:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		game.hud.hide()
		camera = Camera3D.new()
		root.add_child(camera)
		camera.current = true
	for id in ["common_table", "barrel_board"]:
		var area: Node = game.zone_root.find_child(id, true, false)
		_check(area != null, "physical board table is missing: %s" % id)
		if area == null:
			continue
		var chairs: Array = []
		for candidate in area.find_children("*", "", true, false):
			if str(candidate.name).begins_with("BoardGameChair"):
				chairs.append(candidate)
		_check(chairs.size() >= 2, "board table lacks two chairs: %s" % id)
		var furniture := area.find_child("GreyfenSocialFurniture", true, false) as MeshInstance3D
		_check(furniture != null and furniture.mesh != null, "Board table lacks complete authored furniture: " + id)
		if furniture != null and furniture.mesh != null:
			_check(furniture.mesh.get_surface_count() == 2, "Authored seating and table surfaces are incomplete: " + id)
			_check(furniture.mesh.get_aabb().position.y >= -0.002, "Furniture is not grounded: " + id)
			var footprint := furniture.mesh.get_aabb()
			for local_x in [footprint.position.x, footprint.end.x]:
				for local_z in [footprint.position.z, footprint.end.z]:
					var corner := furniture.to_global(Vector3(local_x, 0.0, local_z))
					_check(not SpatialSurfaceContract.is_river_excluded("greyfen", corner, 0.0), "Social seating crosses the Greyfen river: %s %s" % [id, corner])
			_check(furniture.mesh.get_faces().size() / 3 == 1978, "Native chair/table geometry was removed: " + id)
			var sources: Dictionary = furniture.mesh.get_meta("source_sha256", {})
			for source in ["Table_Large.obj", "Chair_1.obj"]:
				_check(sources.get(source, "") == FileAccess.get_sha256("res://assets_external/environment/props/" + source), "Native furniture source identity drift: " + source)
		var person := "rook" if id == "common_table" else "blacksmith_tor"
		var opponent: Node = game.zone_root.find_child(person, true, false)
		_check(opponent != null, "board table lacks its named opponent: %s" % id)
		_check(area.find_child("BoardGameBeckoningGesture", true, false) == null, "board opponent still has a proxy hand: %s" % id)
		var invitation: Node = opponent.find_child("CharacterAnimationDriver", true, false) if opponent != null else null
		var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
		_check(invitation != null and invitation.is_valid() and life != null and life.has_method("request_table_visit"), "named board opponent lacks skeletal performance or table-visit ownership: %s" % id)
		var squares := 0
		for batch in area.find_children("%s_BoardSquares*" % id, "MultiMeshInstance3D", true, false):
			squares += batch.multimesh.instance_count
		_check(squares == (9 if id == "common_table" else 36), "physical board lost squares: %s" % id)
		if capture:
			var dimensions := Vector3(2.8, 0.85, 1.8) if id == "common_table" else Vector3(2.2, 0.85, 1.5)
			var columns := 3 if id == "common_table" else 6
			var board := Vector2(dimensions.x * 0.70, dimensions.z * 0.68)
			var occupied: Dictionary = {}
			for parity in range(2):
				var batch := area.find_child("%s_BoardSquares_%d" % [id, parity], true, false) as MultiMeshInstance3D
				_check(batch != null, "physical board color batch missing")
				if batch == null:
					continue
				for index in range(batch.multimesh.instance_count):
					var transform := batch.multimesh.get_instance_transform(index)
					var column := int(round((transform.origin.x + board.x * 0.5) / (board.x / columns) - 0.5))
					var row := int(round((transform.origin.z + board.y * 0.5) / (board.y / columns) - 0.5))
					var cell := Vector2i(column, row)
					_check(column >= 0 and column < columns and row >= 0 and row < columns and (row + column) % 2 == parity, "board square misplaced or wrong parity")
					_check(not occupied.has(cell), "board squares overlap")
					occupied[cell] = true
					_check(is_equal_approx(transform.origin.y, dimensions.y + 0.14), "board square has incorrect height")
					_check(transform.basis.get_scale().is_equal_approx(Vector3(board.x / columns - 0.018, 0.018, board.y / columns - 0.018)), "board square dimensions changed")
			_check(occupied.size() == columns * columns, "rendered board cells incomplete")
			game.player.global_position = area.global_position + Vector3(0, 0.1, 3.0)
			camera.global_position = area.global_position + Vector3(2.5, 2.6, 3.8)
			camera.look_at(area.global_position + Vector3(0, 0.9, 0))
			var approach := area.get_node("BoardGameOpponentApproach") as Node3D
			var corner := area.get_node_or_null("BoardGameOpponentCorner") as Node3D
			var invitation_deadline := Time.get_ticks_msec() + 90000
			while opponent != null and not life.request_table_visit(person, approach.global_position, corner.global_position if corner != null else Vector3.INF) and Time.get_ticks_msec() < invitation_deadline:
				await process_frame
			_check(opponent != null and opponent.global_position.distance_to(area.global_position) < 2.5, "named opponent did not arrive at the table: " + id)
			await _frames(12)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			_check(image.get_size() == Vector2i(1280, 720), "board capture dimensions incorrect")
			_check(image.save_png("D:/Temp/AshenOath/board_%s_batch.png" % id) == OK, "board screenshot failed: " + id)
	var minigames: Node = game.minigames
	minigames.open_game("draughts")
	await _frames(2)
	_check(minigames.board_grid.get_child_count() == 36, "draughts board did not render 36 squares")
	minigames.call("_on_draughts_square", 6)
	_check(not minigames.draughts_legal_targets.is_empty(), "draughts selection has no highlighted legal destinations")
	minigames.close_game()
	game.prepare_resource_shutdown()
	if camera != null:
		camera.queue_free()
	await _frames(20)
	game.queue_free()
	await _frames(8)
	_finish()

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _verify_solidity(game: Node) -> void:
	# Subsystem physics probes, not a normal-input gameplay or performance pass.
	game.seamless_world.cancel_preparation()
	game.player.set_physics_process(false)
	var life: Node = game.zone_root.find_child("GreyfenLifeController", true, false)
	life.set_physics_process(false)
	await physics_frame
	await process_frame
	var capsule: CollisionShape3D
	for child in game.player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule = child
	_check(capsule != null, "Physical player capsule missing")
	if capsule == null:
		return
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var cases := 0
	for id: String in ["common_table", "barrel_board"]:
		var area: Node3D = game.zone_root.find_child(id, true, false)
		var body := area.get_node_or_null("SolidFurniture") as StaticBody3D
		_check(body != null and body.collision_layer == 1, "Missing construction-owned solid furniture: " + id)
		if body == null:
			continue
		var visual := area.get_node("GreyfenSocialFurniture") as MeshInstance3D
		var shape := body.get_node("FittedTableAndChairs") as CollisionShape3D
		_check(shape.shape is ConcavePolygonShape3D and shape.shape.get_faces() == visual.mesh.get_faces(), "Collision does not fit the actual furniture: " + id)
		_check(not bool(body.get_meta("walkable_support", true)), "Furniture can be selected as an arrival floor")
		# Exclude unrelated scenery only in the table-shape probe; real-world
		# approach, seat and NPC route checks below retain all world collisions.
		var excluded: Array[RID] = [game.player.get_rid()]
		for other in game.zone_root.find_children("*", "StaticBody3D", true, false):
			if other != body:
				excluded.append(other.get_rid())
		var dimensions := Vector2(2.8,1.8) if id == "common_table" else Vector2(2.2,1.5)
		var starts: Array[Vector3] = [Vector3(dimensions.x*0.5+0.4,0,0), Vector3(-dimensions.x*0.5-0.4,0,0), Vector3(0.9,0,dimensions.y*0.5+0.4), Vector3(0.9,0,-dimensions.y*0.5-0.4)]
		for x: float in [-1.0,1.0]:
			for z: float in [-1.0,1.0]:
				starts.append(Vector3(x*(dimensions.x*0.5+0.35),0,z*(dimensions.y*0.5+0.35)))
		for start: Vector3 in starts:
			if "--approaches-only" in OS.get_cmdline_user_args():
				break
			for travel: float in [0.8,3.0]:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule.shape
				query.transform = Transform3D(Basis.IDENTITY, area.to_global(start)+Vector3.UP*0.08) * capsule.transform
				query.motion = -Vector3(start.x,0,start.z).normalized() * travel
				query.collision_mask = 1
				query.exclude = excluded
				var fractions := space.cast_motion(query)
				_check(fractions.size() == 2 and fractions[0] > 0 and fractions[0] < 1, "Player capsule passes furniture or begins embedded: %s %s distance=%s fractions=%s" % [id,start,travel,fractions])
				cases += 1
		var arrival := area.get_node("BoardGameOpponentApproach") as Node3D
		_check(not game.spatial_service.is_position_occupied(arrival.global_position,0.34,1.65), "Opponent arrival is obstructed: " + id)
		if id == "common_table" and "--tor-only" in OS.get_cmdline_user_args():
			continue
		var person := "rook" if id == "common_table" else "blacksmith_tor"
		var entry: Dictionary = life._world_actor(person)
		var corner := area.get_node_or_null("BoardGameOpponentCorner") as Node3D
		life.request_table_visit(person,arrival.global_position,corner.global_position if corner != null else Vector3.INF)
		var route: Array = entry.route
		print("FURNITURE ROUTE ", person, " ", route)
		_check(route.size() >= 2, "Opponent has no clear approach route: " + person)
		for index in range(1,route.size()):
			_check(game.spatial_service.validate_runtime_segment(route[index-1],route[index],0.58), "Opponent route hits real scenery: %s leg %d" % [person,index])
	var details := preload("res://scripts/greyfen_village_details.gd").current(game)
	var seat: Node3D = details.props.get("common_seat")
	_check(seat != null and not game.spatial_service.is_position_occupied(seat.global_position,0.34,1.65), "Common bench is inside solid furniture")
	var pieces: Node3D = details.props.get("game_pieces")
	_check(pieces != null and (pieces.get_meta("interaction_anchor") as Vector3).y >= 1.03, "Game pieces' Use anchor is below the solid tabletop")
	var houses: Array[Node] = game.zone_root.find_children("HouseCollision", "StaticBody3D", true, false)
	_check(houses.size() == 4, "Representative house wall/door boundary collision missing")
	_check(bool(game.zone_root.get_meta("greyfen_boundary_complete",false)) and game.spatial_service.half_extents == SpatialSurfaceContract.zone_half_extents("greyfen"), "Authored boundary readiness/spatial extent contract missing")
	print("SOLID FURNITURE PHYSICS: cases=", cases, " failures=", failures.size(), " (no FPS or normal-input claim)")
	life.set_physics_process(true)
	if failures.is_empty():
		for id: String in ["common_table", "barrel_board"]:
			if id == "common_table" and "--tor-only" in OS.get_cmdline_user_args():
				continue
			var area: Node3D = game.zone_root.find_child(id,true,false)
			var arrival := area.get_node("BoardGameOpponentApproach") as Node3D
			var corner := area.get_node_or_null("BoardGameOpponentCorner") as Node3D
			var person := "rook" if id == "common_table" else "blacksmith_tor"
			# Isolated fixture arrangement: request from a clear table-side position,
			# not from the bridge centre where the actor must yield to the player.
			var standing := arrival.global_position + Vector3(0,0.08,1.2)
			_check(not game.spatial_service.is_position_occupied(standing,0.34,1.65), "Fixture table-side standing point is obstructed")
			game.player.global_position = standing
			var deadline := Time.get_ticks_msec()+90000
			var next_note := Time.get_ticks_msec()+15000
			var ready := false
			while not ready and Time.get_ticks_msec() < deadline:
				ready = life.request_table_visit(person,arrival.global_position,corner.global_position if corner != null else Vector3.INF)
				if Time.get_ticks_msec() >= next_note:
					var entry: Dictionary = life._world_actor(person)
					print("FURNITURE APPROACH ",person," position=",entry.node.global_position," speed=",entry.motion_speed," route=",entry.route," index=",entry.route_index," pause=",entry.pause," activity=",entry.activity_active," reaction=",entry.get("reaction_time",0)," protected=",preload("res://scripts/character_presence.gd").protected(entry.node)," corner=",entry.get("table_approach",null)," seconds=",entry.get("table_seconds",0))
					if float(entry.motion_speed) < 0.01:
						for nearby: Dictionary in life._crowd_index.nearby(entry.node.global_position,1.62):
							if nearby != entry:
								print("FURNITURE NEIGHBOUR ", nearby.id, " ",nearby.node.global_position)
					next_note += 15000
				await physics_frame
			_check(ready, "Actual opponent never reaches solid table: " + person)
			if ready:
				var entry: Dictionary = life._world_actor(person)
				_check(entry.node.global_position.distance_to(area.global_position) < 2.5, "Opponent reports arrival before reaching the table")
				print("FURNITURE ARRIVED ",person," ",entry.node.global_position)
				game.minigames.open_game("tic_tac_toe" if id == "common_table" else "draughts",person)
				game.minigames._switch_game(2)
				await _frames(2)
				_check(game.minigames.active_game == "chess" and game.minigames.board_grid.get_child_count() == 64, "Chess selector failed at " + id)
				game.minigames.close_game()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)

func _finish() -> void:
	print("MINIGAME PRESENTATION VERIFIER: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
