extends RefCounted

## Small physical construction meshes for existing held-prop sockets. Bounds
## remain in their original local frames; no interaction or pose is owned here.
static var _cache: Dictionary = {}

static func vessel(top: float, bottom: float, height: float, wall: float = 0.008, segments: int = 16) -> ArrayMesh:
	var profile := [
		Vector2(0, -height * 0.5), Vector2(bottom, -height * 0.5),
		Vector2(bottom, -height * 0.5 + wall), Vector2(top, height * 0.5 - wall * 0.6),
		Vector2(top - wall * 0.45, height * 0.5), Vector2(top - wall, height * 0.5 - wall * 0.3),
		Vector2(maxf(wall, bottom - wall), -height * 0.5 + wall * 1.8),
		Vector2(0, -height * 0.5 + wall * 1.8),
	]
	return _lathe("vessel:%s:%s:%s:%s:%s" % [top,bottom,height,wall,segments], profile, segments)

static func shield() -> ArrayMesh:
	# Slight dish, supporting rear, and a narrow rim instead of a capped drum.
	return _lathe("shield", [Vector2(0,-0.0275),Vector2(0.18,-0.018),Vector2(0.22,-0.004),Vector2(0.22,0.017),Vector2(0.18,0.0275),Vector2(0,0.0275)], 16)

static func _lathe(key: String, profile: Array, segments: int) -> ArrayMesh:
	if _cache.has(key): return _cache[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size() - 1):
		var a: Vector2 = profile[row]
		var b: Vector2 = profile[row + 1]
		for index in range(segments):
			var angle := TAU * float(index) / segments
			var next := TAU * float(index + 1) / segments
			var points := [Vector3(cos(angle)*a.x,a.y,sin(angle)*a.x),Vector3(cos(next)*a.x,a.y,sin(next)*a.x),Vector3(cos(next)*b.x,b.y,sin(next)*b.x),Vector3(cos(angle)*b.x,b.y,sin(angle)*b.x)]
			var middle := (angle + next) * 0.5
			var normal := Vector3((b.y-a.y)*cos(middle),a.x-b.x,(b.y-a.y)*sin(middle)).normalized()
			_triangle(tool, points[0], points[1], points[2], normal)
			_triangle(tool, points[0], points[2], points[3], normal)
	var mesh := tool.commit()
	mesh.resource_name = "HeldProp_" + key
	_cache[key] = mesh
	return mesh

static func cloth() -> ArrayMesh:
	if _cache.has("cloth"): return _cache.cloth
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for row in range(4):
			for column in range(8):
				var points: Array[Vector3] = []
				for uv: Vector2 in [Vector2(column/8.0,row/4.0),Vector2((column+1)/8.0,row/4.0),Vector2((column+1)/8.0,(row+1)/4.0),Vector2(column/8.0,(row+1)/4.0)]:
					points.append(Vector3((uv.x-.5)*.20,.115-uv.y*.23,.010*sin(uv.x*TAU*2.0)+uv.y*.020+side*.0015))
				var normal := Vector3(0,0,side)
				_triangle(tool, points[0],points[1],points[2],normal)
				_triangle(tool, points[0],points[2],points[3],normal)
	var mesh := tool.commit()
	mesh.resource_name = "HeldFoldedLinen"
	_cache.cloth = mesh
	return mesh

static func bread_scores() -> ArrayMesh:
	if _cache.has("bread_scores"): return _cache.bread_scores
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cut in [-.075,0.0,.075]:
		for segment in range(8):
			var points: Array[Vector3] = []
			for pair: Vector2 in [Vector2(segment,-1),Vector2(segment+1,-1),Vector2(segment+1,1),Vector2(segment,1)]:
				var x := (pair.x / 8.0 - .5) * .11
				var z: float = cut + pair.y * .0015 + x * .15
				var y := .0125 * sqrt(maxf(0.0,1.0-pow(x/.10,2)-pow(z/.16,2))) + .00015
				points.append(Vector3(x,y,z))
			_triangle(tool,points[0],points[1],points[2],Vector3.UP)
			_triangle(tool,points[0],points[2],points[3],Vector3.UP)
	var mesh := tool.commit()
	mesh.resource_name = "FlatbreadScoredCrust"
	_cache.bread_scores = mesh
	return mesh

static func spearhead() -> ArrayMesh:
	if _cache.has("spearhead"): return _cache.spearhead
	var points := [Vector3(0,.11,0),Vector3(-.05,-.015,0),Vector3(0,-.11,0),Vector3(.05,-.015,0),Vector3(0,0,.03),Vector3(0,0,-.03)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [4,5]:
		for index in range(4):
			var a: Vector3 = points[index]
			var b: Vector3 = points[(index+1)%4]
			var c: Vector3 = points[side]
			_triangle(tool,a,b,c,(a+b+c).normalized())
	var mesh := tool.commit()
	mesh.resource_name = "VarganForgedLeafSpearhead"
	_cache.spearhead = mesh
	return mesh

static func rope() -> ArrayMesh:
	if _cache.has("rope"): return _cache.rope
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 40
	const SIDES := 5
	for ply in [0.0,PI]:
		for step in range(STEPS):
			for side in range(SIDES):
				var points: Array[Vector3] = []
				for pair: Vector2i in [Vector2i(step,side),Vector2i(step+1,side),Vector2i(step+1,side+1),Vector2i(step,side+1)]:
					var angle := float(pair.x) / STEPS * TAU
					var twist: float = angle * 8.0 + ply
					var around := float(pair.y) / SIDES * TAU
					var radius := .0875 + .0065*cos(twist) + .0105*cos(around)
					points.append(Vector3(cos(angle)*radius,.0065*sin(twist)+.0105*sin(around),sin(angle)*radius))
				var center := (points[0]+points[1]+points[2]+points[3])*.25
				var ring_center := Vector3(center.x,0,center.z).normalized()*.0875
				var normal := (center-ring_center).normalized()
				_triangle(tool,points[0],points[1],points[2],normal)
				_triangle(tool,points[0],points[2],points[3],normal)
	var mesh := tool.commit()
	mesh.resource_name = "HeldTwistedRopeCoil"
	_cache.rope = mesh
	return mesh

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.length_squared() < 0.000000000001: return
	if normal.dot(hint) < 0.0: normal = -normal
	normal = normal.normalized()
	if (b-a).cross(c-a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for point: Vector3 in [a,b,c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x,point.y))
		tool.add_vertex(point)
