extends RefCounted

## Query probes, character capsules and shapes resized during play stay private.
static var _shapes: Dictionary = {}

static func _key(kind: String, dimensions: Variant, margin: float) -> String:
	return var_to_bytes([kind, dimensions, margin]).hex_encode()

static func _cached(key: String) -> Shape3D:
	var reference: WeakRef = _shapes.get(key)
	return reference.get_ref() as Shape3D if reference != null else null

static func _remember(key: String, shape: Shape3D) -> void:
	# Bodies, not the lookup table, own the shared resource's lifetime.
	if _shapes.size() % 64 == 0:
		for old_key in _shapes.keys():
			if _shapes[old_key].get_ref() == null:
				_shapes.erase(old_key)
	_shapes[key] = weakref(shape)

static func box(size: Vector3, margin: float = 0.04) -> BoxShape3D:
	var key := _key("box", size, margin)
	var shape := _cached(key) as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = size
		shape.margin = margin
		_remember(key, shape)
	return shape

static func sphere(radius: float, margin: float = 0.04) -> SphereShape3D:
	var key := _key("sphere", radius, margin)
	var shape := _cached(key) as SphereShape3D
	if shape == null:
		shape = SphereShape3D.new()
		shape.radius = radius
		shape.margin = margin
		_remember(key, shape)
	return shape

static func cylinder(radius: float, height: float, margin: float = 0.04) -> CylinderShape3D:
	var key := _key("cylinder", [radius, height], margin)
	var shape := _cached(key) as CylinderShape3D
	if shape == null:
		shape = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape.margin = margin
		_remember(key, shape)
	return shape
