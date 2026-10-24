extends Button

var piece := ""
var brass := true

func _draw() -> void:
	if piece.is_empty(): return
	var ink := Color(0.92, 0.72, 0.37) if brass else Color(0.83, 0.86, 0.82)
	var edge := Color(0.18, 0.12, 0.065)
	var scale_size := minf(size.x, size.y) / 64.0
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0.0, Vector2.ONE * scale_size)
	if piece in ["mark", "disc", "crown"]:
		draw_circle(Vector2.ZERO, 19, edge)
		draw_circle(Vector2(0,-2), 17, ink)
		draw_arc(Vector2(0,-2), 12, 0, TAU, 24, edge, 1.5, true)
		if piece == "crown":
			draw_polyline(PackedVector2Array([Vector2(-9,1),Vector2(-10,-8),Vector2(-3,-3),Vector2(0,-11),Vector2(4,-3),Vector2(10,-8),Vector2(9,1),Vector2(-9,1)]),edge,2,true)
		return
	var outline: PackedVector2Array
	match piece.to_lower():
		"p": outline = PackedVector2Array([Vector2(-13,15),Vector2(-9,7),Vector2(-5,2),Vector2(-5,-7),Vector2(5,-7),Vector2(5,2),Vector2(9,7),Vector2(13,15)])
		"r": outline = PackedVector2Array([Vector2(-13,15),Vector2(-9,5),Vector2(-9,-10),Vector2(-13,-10),Vector2(-13,-20),Vector2(-7,-20),Vector2(-7,-15),Vector2(-3,-15),Vector2(-3,-20),Vector2(3,-20),Vector2(3,-15),Vector2(7,-15),Vector2(7,-20),Vector2(13,-20),Vector2(13,-10),Vector2(9,-10),Vector2(9,5),Vector2(13,15)])
		"n": outline = PackedVector2Array([Vector2(-14,15),Vector2(-10,5),Vector2(-2,-4),Vector2(-11,-1),Vector2(-15,-7),Vector2(-5,-20),Vector2(-4,-26),Vector2(3,-20),Vector2(9,-16),Vector2(12,-4),Vector2(8,8),Vector2(14,15)])
		"b": outline = PackedVector2Array([Vector2(-13,15),Vector2(-8,7),Vector2(-5,-1),Vector2(-10,-9),Vector2(-7,-17),Vector2(0,-26),Vector2(7,-17),Vector2(10,-9),Vector2(5,-1),Vector2(8,7),Vector2(13,15)])
		"q": outline = PackedVector2Array([Vector2(-14,15),Vector2(-9,7),Vector2(-13,-17),Vector2(-5,-10),Vector2(0,-23),Vector2(5,-10),Vector2(13,-17),Vector2(9,7),Vector2(14,15)])
		_: outline = PackedVector2Array([Vector2(-14,15),Vector2(-9,7),Vector2(-6,-7),Vector2(-10,-15),Vector2(-3,-18),Vector2(-3,-24),Vector2(3,-24),Vector2(3,-18),Vector2(10,-15),Vector2(6,-7),Vector2(9,7),Vector2(14,15)])
	draw_colored_polygon(outline, ink)
	var closed := outline.duplicate(); closed.append(outline[0])
	draw_polyline(closed, edge, 1.5, true)
	draw_rect(Rect2(-16,15,32,5),ink)
	draw_line(Vector2(-16,20),Vector2(16,20),edge,2,true)
	if piece.to_lower() == "p": draw_circle(Vector2(0,-14),8,ink)
	if piece.to_lower() == "n": draw_circle(Vector2(-2,-13),1.8,edge)
	if piece.to_lower() == "b": draw_line(Vector2(1,-20),Vector2(-4,-11),edge,2,true)
