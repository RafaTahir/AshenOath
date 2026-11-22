extends RefCounted
## Stateless narrow-phase queries for the actual finite, low creature bodies.
## Capsules retain their existing combat path in CombatManager.

static func aim_point_for(actor: Node3D) -> Vector3:
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled and (child.shape is CapsuleShape3D or child.shape is CylinderShape3D):
			return child.global_position
	var bounds: AABB = actor.get_meta("camera_subject_bounds", AABB(Vector3.ZERO, Vector3(0, 1.84, 0)))
	return actor.global_transform * bounds.get_center()

static func cylinder_for(actor: Node3D) -> CollisionShape3D:
	for child: Node in actor.get_children():
		if child is CollisionShape3D and child.shape is CylinderShape3D and not child.disabled:
			return child
	return null

static func segment_hit(collider: CollisionShape3D, start: Vector3, finish: Vector3, width: float) -> Dictionary:
	if collider == null or collider.disabled or not collider.shape is CylinderShape3D:
		return {}
	var transform := collider.global_transform
	var scale := transform.basis.get_scale().abs()
	if minf(scale.x, minf(scale.y, scale.z)) < 0.000001:
		return {}
	var inverse := transform.affine_inverse()
	var origin: Vector3 = inverse * start
	var direction: Vector3 = inverse * finish - origin
	var shape: CylinderShape3D = collider.shape
	# World attack width is the only expansion. Use the smaller radial scale
	# conservatively for nonuniform X/Z bases; never add body radius above a cap.
	var radius := shape.radius + maxf(width, 0.0) / minf(scale.x, scale.z)
	var half_height := shape.height * 0.5 + maxf(width, 0.0) / scale.y
	var enter := 0.0
	var leave := 1.0
	if absf(direction.y) < 0.000001:
		if absf(origin.y) > half_height:
			return {}
	else:
		var lower := (-half_height - origin.y) / direction.y
		var upper := (half_height - origin.y) / direction.y
		enter = maxf(enter, minf(lower, upper))
		leave = minf(leave, maxf(lower, upper))
	var radial_a := direction.x * direction.x + direction.z * direction.z
	var radial_c := origin.x * origin.x + origin.z * origin.z - radius * radius
	if radial_a < 0.000001:
		if radial_c > 0.0:
			return {}
	else:
		var radial_b := 2.0 * (origin.x * direction.x + origin.z * direction.z)
		var discriminant := radial_b * radial_b - 4.0 * radial_a * radial_c
		if discriminant < 0.0:
			return {}
		var root := sqrt(discriminant)
		enter = maxf(enter, (-radial_b - root) / (2.0 * radial_a))
		leave = minf(leave, (-radial_b + root) / (2.0 * radial_a))
	if enter > leave:
		return {}
	var point := start.lerp(finish, enter)
	var world_body_point := _closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, point)
	var limit := maxf(width, 0.0) * maxf(width, 0.0)
	if point.distance_squared_to(world_body_point) > limit:
		# Radius/height expansion is only a broad phase: its squared cap corners
		# can be farther than the permitted Euclidean attack width. Distance to a
		# convex finite cylinder is convex along the segment. Locate its minimum,
		# then the first qualifying point; rejecting the broad entry alone would
		# incorrectly lose later valid cap grazes. Ordinary side/cap hits skip this.
		var low := enter
		var high := leave
		const GOLDEN := 0.61803398875
		var left := high - (high - low) * GOLDEN
		var right := low + (high - low) * GOLDEN
		var p_left := start.lerp(finish, left)
		var p_right := start.lerp(finish, right)
		var d_left := p_left.distance_squared_to(_closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, p_left))
		var d_right := p_right.distance_squared_to(_closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, p_right))
		for index in 28:
			if d_left <= d_right:
				high = right
				right = left
				d_right = d_left
				left = high - (high - low) * GOLDEN
				p_left = start.lerp(finish, left)
				d_left = p_left.distance_squared_to(_closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, p_left))
			else:
				low = left
				left = right
				d_left = d_right
				right = low + (high - low) * GOLDEN
				p_right = start.lerp(finish, right)
				d_right = p_right.distance_squared_to(_closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, p_right))
		var minimum := left if d_left <= d_right else right
		if minf(d_left, d_right) > limit:
			return {}
		low = enter
		high = minimum
		for index in 22:
			var middle := (low + high) * 0.5
			var candidate := start.lerp(finish, middle)
			if candidate.distance_squared_to(_closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, candidate)) <= limit:
				high = middle
			else:
				low = middle
		enter = high
		point = start.lerp(finish, enter)
		world_body_point = _closest_body_point(transform, inverse, scale, shape.radius, shape.height * 0.5, point)
	return {"point": point, "body_point": world_body_point, "distance": point.distance_to(world_body_point), "fraction": enter}

static func _closest_body_point(transform: Transform3D, inverse: Transform3D, scale: Vector3,
		radius: float, half_height: float, point: Vector3) -> Vector3:
	var local: Vector3 = inverse * point
	var radial_length := Vector2(local.x, local.z).length()
	if radial_length <= radius and absf(local.y) <= half_height:
		# Preserve exact zero distance inside the solid; a transform/inverse
		# round trip introduces float noise for rotated zero-width rays.
		return point
	var body := Vector3(local.x, clampf(local.y, -half_height, half_height), local.z)
	if radial_length > radius:
		if is_equal_approx(scale.x, scale.z):
			body.x *= radius / radial_length
			body.z *= radius / radial_length
		else:
			# Exact closest point on a scaled elliptical cross section. Runtime
			# colliders use unit scale, so this bounded branch serves transformed
			# fixtures and keeps width meaningful under a nonuniform global basis.
			var a := radius * scale.x
			var b := radius * scale.z
			var x := local.x * scale.x
			var z := local.z * scale.z
			var low := 0.0
			var high := a * absf(x) + b * absf(z)
			for index in 32:
				var middle := (low + high) * 0.5
				var normalized := pow(a * x / (middle + a * a), 2.0) + pow(b * z / (middle + b * b), 2.0)
				if normalized > 1.0:
					low = middle
				else:
					high = middle
			body.x = a * a * x / (high + a * a) / scale.x
			body.z = b * b * z / (high + b * b) / scale.z
	return transform * body

static func cast_hit(collider: CollisionShape3D, start: Vector3, finish: Vector3, width: float) -> Dictionary:
	var hit := segment_hit(collider, start, finish, width)
	var length := start.distance_to(finish)
	if hit.is_empty() or length < 0.000001:
		return {}
	var forward := (finish - start) / length
	# Padding may overlap the origin or a wall-clipped endpoint while the real
	# body is wholly beyond either plane. Test the actual cylinder's support
	# interval, not its expanded entry point; a genuinely straddling body is valid.
	var front := _support(collider, forward)
	var back := _support(collider, -forward)
	var upper := (front - start).dot(forward)
	var lower := (back - start).dot(forward)
	if upper < 0.0 or lower > length:
		return {}
	var body_point: Vector3 = hit.body_point
	var along := (body_point - start).dot(forward)
	# Convex interpolation keeps this contact inside the real body and inside
	# the cast planes, including caps/grazes and an origin inside the padding.
	if along < 0.0:
		body_point = body_point.lerp(front, -along / maxf(upper - along, 0.000001))
	elif along > length:
		body_point = body_point.lerp(back, (along - length) / maxf(along - lower, 0.000001))
	if body_point.distance_squared_to(hit.point) > pow(maxf(width, 0.0) + 0.000001, 2.0):
		return {}
	hit["body_point"] = body_point
	hit["along"] = clampf((body_point - start).dot(forward), 0.0, length)
	return hit

static func _support(collider: CollisionShape3D, direction: Vector3) -> Vector3:
	var shape: CylinderShape3D = collider.shape
	var transform := collider.global_transform
	var local := transform.basis.transposed() * direction
	var radial := Vector2(local.x, local.z).normalized() * shape.radius
	return transform * Vector3(radial.x, signf(local.y) * shape.height * 0.5, radial.y)

static func sweep_hit(collider: CollisionShape3D, previous_base: Vector3, previous_tip: Vector3,
		blade_base: Vector3, blade_tip: Vector3, width: float) -> Dictionary:
	var best: Dictionary = {}
	for segment: Array in [[previous_base, previous_tip], [blade_base, blade_tip],
			[previous_base, blade_base], [previous_tip, blade_tip],
			[previous_base, blade_tip], [previous_tip, blade_base]]:
		var hit := segment_hit(collider, segment[0], segment[1], width)
		if not hit.is_empty() and (best.is_empty() or float(hit.distance) < float(best.distance)):
			best = hit
	return best
