extends RefCounted

## Private to one synchronous query owner; never shared between actors.
var _ray := PhysicsRayQueryParameters3D.new()
var _shape := PhysicsShapeQueryParameters3D.new()

func ray(from: Vector3, to: Vector3, mask: int = 1) -> PhysicsRayQueryParameters3D:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = mask
	_ray.exclude = []
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_ray.hit_from_inside = false
	_ray.hit_back_faces = true
	return _ray

func shape_query(shape: Shape3D) -> PhysicsShapeQueryParameters3D:
	_shape.shape = shape
	_shape.transform = Transform3D.IDENTITY
	_shape.motion = Vector3.ZERO
	_shape.margin = 0.0
	_shape.collision_mask = 1
	_shape.exclude = []
	_shape.collide_with_areas = false
	_shape.collide_with_bodies = true
	return _shape
