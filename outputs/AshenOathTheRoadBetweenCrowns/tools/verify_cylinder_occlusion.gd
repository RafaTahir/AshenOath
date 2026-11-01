extends "res://tools/verify_cylinder_combat.gd"

## Additional production-resolver regressions for padded origins and world
## endpoints. Inherits the resource-free geometry fixture and its error logger.

func _verify_occlusion_and_single_hit() -> void:
	await super._verify_occlusion_and_single_hit()
	var before := checks
	_verify_origin_intervals()
	_verify_cap_and_side_grazing()
	_verify_corner_distance()
	await _verify_clipped_endpoint(false)
	await _verify_clipped_endpoint(true)
	await _verify_adjacent_melee_wall(false)
	await _verify_adjacent_melee_wall(true)
	print("CYLINDER OCCLUSION MATRIX: %s checks=%d (production resolvers; padded origins, real body intervals and adjacent walls)" % ["PASS" if failures.is_empty() else "FAIL", checks - before])

func _verify_origin_intervals() -> void:
	var actor := _target("shroud_swimmer")
	var y := BodyQuery.cylinder_for(actor).global_position.y
	for row: Array in [[-0.65, true, "origin inside padding; real body ahead"],
			[0.65, false, "padding contains origin; real body entirely behind"],
			[0.20, true, "center behind origin; real body straddles forward segment"],
			[0.0, true, "origin inside actual body"], [-0.55, true, "origin on actual front cap"]]:
		actor.position.z = float(row[0])
		_check(bool(_shot(actor, y).hit) == bool(row[1]), "Arrow interval: " + str(row[2]))
		_check((_beam(actor, y).size() == 1) == bool(row[1]), "Beam interval: " + str(row[2]))
	actor.free()

func _verify_cap_and_side_grazing() -> void:
	var actor := _target("shroud_swimmer")
	var collider := BodyQuery.cylinder_for(actor)
	var cap: float = collider.global_position.y + collider.shape.height * 0.5
	_check(bool(_shot(actor, cap + 0.20).hit), "Arrow retains allowed finite-cap grazing")
	_check(not bool(_shot(actor, cap + 0.35).hit), "Arrow cannot exceed finite cap plus its width")
	_check(_beam(actor, cap + 0.20).size() == 1, "Beam retains allowed finite-cap grazing")
	_check(_beam(actor, cap + 0.26).is_empty(), "Beam cannot exceed finite cap plus its width")
	_check(_beam(actor, collider.global_position.y, collider.shape.radius + 0.20).size() == 1, "Endpoint guard must preserve lateral width")
	actor.free()

func _wall_at(front: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.10)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(0, 1, front - 0.05)
	stage.add_child(wall)
	return wall

func _corner_target() -> Target:
	var actor := Target.new()
	actor.collision_layer = 2
	actor.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.4
	collider.shape = shape
	actor.add_child(collider)
	stage.add_child(actor)
	actor.position = Vector3(0, 1, -4)
	return actor

func _verify_corner_distance() -> void:
	var actor := _corner_target()
	for arrow: bool in [true, false]:
		var width := 0.34 if arrow else 1.2
		# Arrow: radial gap .30 and cap gap .30 => true distance .424,
		# outside width .34 despite lying in both independently padded bounds.
		var far_gap := 0.30 if arrow else width * 0.80
		var near_gap := width * 0.60
		for gap: float in [far_gap, near_gap]:
			var origin := Vector3(0.5 + gap, 1.2 + gap, 0)
			var cast := {"origin":origin, "endpoint":origin + Vector3.FORWARD * 8,
				"direction":Vector3.FORWARD, "width":width, "damage":10.0, "report_miss":false}
			var before_hits := actor.hits
			var hit: bool = bool(combat.resolve_arrow_shot([actor], cast).hit) if arrow else not combat.resolve_oathfire_cast([actor], cast).is_empty()
			var expected := gap == near_gap
			_check(hit == expected, ("Arrow" if arrow else "Beam") + ": diagonal finite-cap corner must obey true width, including nearby valid grazing")
			if not expected:
				_check(actor.hits == before_hits, "Rejected diagonal cast must not apply hidden damage")
	actor.position.z = -1.5
	for heavy: bool in [false, true]:
		var width := 0.78 if heavy else 0.66
		for gap: float in [width * 0.80, width * 0.60]:
			var x := 0.5 + gap
			var y := 1.2 + gap
			attack_id += 1
			var contact := {"attack_id":attack_id, "blade_id":"steel", "damage":10.0, "reach":2.0, "heavy":heavy,
				"base":Vector3(x,y,-0.9), "tip":Vector3(x,y,-2.0),
				"previous_base":Vector3(x,y,-0.9), "previous_tip":Vector3(x,y,-2.0)}
			var before_hits := actor.hits
			var hit: bool = bool(combat.resolve_player_blade_contact(player, [actor], contact, "").hit)
			var expected := gap < width * 0.70
			_check(hit == expected, "Melee diagonal cap corner must not clamp a true distance outside strike width; nearby grazing must hit")
			if not expected:
				_check(actor.hits == before_hits, "Rejected diagonal melee must not apply hidden damage")
	actor.free()

func _verify_clipped_endpoint(arrow: bool) -> void:
	var actor := _target("shroud_swimmer")
	var y := BodyQuery.cylinder_for(actor).global_position.y
	var wall := _wall_at(-3.20 if arrow else -3.0)
	await physics_frame
	await physics_frame
	var origin := Vector3(0, y, 0)
	var ray := PhysicsRayQueryParameters3D.create(origin, Vector3(0, y, -8), 1)
	ray.exclude = [player.get_rid(), actor.get_rid()]
	var clipped := stage.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(clipped.get("collider") == wall, "Fixture must clip against a real world wall")
	var endpoint: Vector3 = clipped.get("position", Vector3(0, y, -3))
	var cast := {"origin":origin, "endpoint":endpoint, "direction":Vector3.FORWARD,
		"width":0.34 if arrow else 1.2, "damage":10.0, "report_miss":false}
	if arrow:
		_check(not bool(combat.resolve_arrow_shot([actor], cast).hit), "Arrow width must not reach a real body wholly past the clipped wall endpoint")
	else:
		_check(combat.resolve_oathfire_cast([actor], cast).is_empty(), "Oathfire width must not reach a real body wholly past the clipped wall endpoint")
	_check(actor.hits == 0, "Wall-adjacent cast must not apply hidden damage")
	wall.free()
	await physics_frame
	cast.endpoint = Vector3(0, y, -8)
	if arrow:
		_check(bool(combat.resolve_arrow_shot([actor], cast).hit), "Arrow control reaches the same body without the wall")
	else:
		_check(combat.resolve_oathfire_cast([actor], cast).size() == 1, "Oathfire control reaches the same body without the wall")
	actor.free()

func _wall_adjacent_contact(y: float, heavy: bool) -> Dictionary:
	attack_id += 1
	return {"attack_id":attack_id, "blade_id":"steel", "damage":10.0, "reach":2.0, "heavy":heavy,
		"base":Vector3(0.10, y, -0.10), "tip":Vector3(0.10, y, -0.55),
		"previous_base":Vector3(-0.10, y, -0.10), "previous_tip":Vector3(-0.10, y, -0.55)}

func _verify_adjacent_melee_wall(heavy: bool) -> void:
	var actor := _target("shroud_swimmer")
	actor.position.z = -1.50
	var y := BodyQuery.cylinder_for(actor).global_position.y
	var wall := _wall_at(-0.70)
	await physics_frame
	await physics_frame
	_check(not bool(combat.resolve_player_blade_contact(player, [actor], _wall_adjacent_contact(y, heavy), "").hit), "Melee LOS must reach the real body beyond an adjacent wall, not stop at padded blade contact")
	_check(actor.hits == 0, "Adjacent melee wall must prevent hidden damage")
	wall.free()
	await physics_frame
	_check(bool(combat.resolve_player_blade_contact(player, [actor], _wall_adjacent_contact(y, heavy), "").hit), "Same melee padding contact must work when the wall is removed")
	actor.free()
