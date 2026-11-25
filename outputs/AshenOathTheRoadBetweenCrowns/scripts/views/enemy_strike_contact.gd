extends RefCounted
## Samples the cutting edge only near contact. The strike owner applies damage once.
const Capsule = preload("res://scripts/views/combat_capsule_view.gd")
const EDGE_WINDOW := 0.12
const SAMPLE_STEP := 1.0 / 60.0
const BLADE_THICKNESS := 0.055
var _armed := false
var _edges := PackedVector3Array()

func arm(edge: PackedVector3Array) -> void:
	clear()
	_armed = edge.size() == 2

func clear() -> void:
	_armed = false
	_edges.clear()

func advance_pose(actor: CharacterBody3D, delta: float) -> void:
	var remaining := minf(delta, actor.pending_attack_time)
	if not _armed:
		actor.animation_driver.advance_external(remaining)
		return
	var early := clampf(actor.pending_attack_time - EDGE_WINDOW, 0.0, remaining)
	if early > 0.0:
		actor.animation_driver.advance_external(early)
		remaining -= early
	if remaining <= 0.0:
		return
	if _edges.is_empty():
		_edges.append_array(actor.enemy_equipment_view.weapon_edge())
	while remaining > 0.000001:
		var step := minf(remaining, SAMPLE_STEP)
		actor.animation_driver.advance_external(step)
		_edges.append_array(actor.enemy_equipment_view.weapon_edge())
		remaining -= step

func hit(actor: CharacterBody3D, half_arc_deg: float) -> bool:
	var offset: Vector3 = actor.player.global_position - actor.global_position
	var local := actor.global_basis.inverse() * offset
	local.y = 0.0
	if local.length_squared() > 0.0001 and -local.normalized().z < cos(deg_to_rad(half_arc_deg)):
		return false
	var body := Capsule.body_segment(actor.player)
	if _armed:
		if _edges.is_empty():
			_edges.append_array(actor.enemy_equipment_view.weapon_edge())
		var reach_limit := maxf(actor.attack_range + 2.0, 4.0)
		for i in range(0, _edges.size() - 1, 2):
			var heel := _edges[i]
			var tip := _edges[i + 1]
			if heel.distance_to(actor.global_position) > reach_limit or tip.distance_to(actor.global_position) > reach_limit:
				continue
			var prev_heel := _edges[maxi(i - 2, 0)]
			var prev_tip := _edges[maxi(i - 1, 1)]
			var travel := maxf(prev_heel.distance_to(heel), prev_tip.distance_to(tip))
			if travel > reach_limit:
				prev_heel = heel
				prev_tip = tip
				travel = 0.0
			var subdivisions := maxi(1, ceili(travel / 0.10))
			for sample_index in range(1, subdivisions + 1):
				var t := float(sample_index) / subdivisions
				if _segment_hit(actor, body, prev_heel.lerp(heel, t), prev_tip.lerp(tip, t), float(body.radius) + BLADE_THICKNESS):
					return true
		return false
	# The authored limb radius already includes the player's body allowance.
	return _segment_hit(actor, body, actor.attack_trace_start, actor.attack_trace_end, actor.contact_radius)

func _segment_hit(actor: CharacterBody3D, body: Dictionary, start: Vector3, finish: Vector3, radius: float) -> bool:
	var body_start: Vector3 = body.start
	var body_end: Vector3 = body.end
	var a := start
	var b := body_start
	if start.distance_squared_to(finish) < 0.0000001:
		if body_start != body_end:
			b = Geometry3D.get_closest_point_to_segment(start, body_start, body_end)
	elif body_start == body_end:
		a = Geometry3D.get_closest_point_to_segment(body_start, start, finish)
	else:
		var points := Geometry3D.get_closest_points_between_segments(start, finish, body_start, body_end)
		a = points[0]
		b = points[1]
	actor.last_attack_contact = a
	return a.distance_squared_to(b) <= radius * radius
