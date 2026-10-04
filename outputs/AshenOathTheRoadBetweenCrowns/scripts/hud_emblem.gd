extends Control

## Original Ashen Oath metalwork. All shapes are authored for this interface.
var motif: String = "hart"
var high_contrast: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func configure(kind: String, contrast: bool = false) -> void:
	motif = kind
	high_contrast = contrast
	queue_redraw()

func _p(point: Vector2) -> Vector2:
	return Vector2(point.x * size.x / 100.0, point.y * size.y / 100.0)

func _line(points: Array[Vector2], color: Color, width: float = 2.0) -> void:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(_p(point))
	draw_polyline(scaled, color, maxf(1.0, width * minf(size.x, size.y) / 100.0), true)

func _poly(points: Array[Vector2], color: Color) -> void:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(_p(point))
	draw_colored_polygon(scaled, color)

func _draw() -> void:
	var silver: Color = Color.WHITE if high_contrast else Color("c1c5c1")
	var shade: Color = Color("42484b")
	var highlight: Color = Color("f1eee2")
	var gold: Color = Color("cbb778")
	var radius: float = minf(size.x, size.y)
	if motif == "hart":
		draw_circle(_p(Vector2(50, 52)), radius * 0.41, Color(0.02, 0.025, 0.03, 0.72))
		draw_arc(_p(Vector2(50, 52)), radius * 0.41, 0.2, TAU - 0.2, 56, shade, maxf(1, radius * 0.025), true)
		draw_arc(_p(Vector2(50, 52)), radius * 0.375, 0.4, TAU - 0.4, 56, silver.darkened(0.28), maxf(1, radius * 0.012), true)
		for side: float in [-1.0, 1.0]:
			var antler: Array[Vector2] = [Vector2(50 + 12 * side, 42), Vector2(50 + 22 * side, 29), Vector2(50 + 27 * side, 12), Vector2(50 + 23 * side, 2)]
			_line(antler, Color.BLACK, 6)
			_line(antler, silver, 3.5)
			_line([Vector2(50 + 21 * side, 31), Vector2(50 + 37 * side, 24), Vector2(50 + 40 * side, 13)], silver, 3)
			_line([Vector2(50 + 26 * side, 18), Vector2(50 + 14 * side, 14), Vector2(50 + 11 * side, 6)], silver, 2.5)
			_line([Vector2(50 + 31 * side, 27), Vector2(50 + 42 * side, 32)], silver, 2)
		_poly([Vector2(50, 30), Vector2(66, 40), Vector2(70, 56), Vector2(60, 69), Vector2(55, 86), Vector2(50, 94), Vector2(45, 86), Vector2(40, 69), Vector2(30, 56), Vector2(34, 40)], silver)
		_poly([Vector2(50, 32), Vector2(50, 89), Vector2(43, 66), Vector2(36, 53), Vector2(38, 42)], shade)
		_poly([Vector2(51, 35), Vector2(62, 43), Vector2(63, 53), Vector2(55, 65), Vector2(51, 85)], highlight)
		_poly([Vector2(34, 42), Vector2(20, 36), Vector2(24, 53), Vector2(36, 57)], silver)
		_poly([Vector2(66, 42), Vector2(80, 36), Vector2(76, 53), Vector2(64, 57)], shade.lightened(0.25))
		_line([Vector2(37, 53), Vector2(43, 56)], Color("19191a"), 3)
		_line([Vector2(63, 53), Vector2(57, 56)], Color("19191a"), 3)
		_poly([Vector2(45, 77), Vector2(55, 77), Vector2(50, 86)], Color("29292a"))
		return
	draw_circle(_p(Vector2(50, 50)), radius * 0.43, Color(0.018, 0.022, 0.024, 0.68 if not high_contrast else 0.97))
	draw_arc(_p(Vector2(50, 50)), radius * 0.43, 0, TAU, 48, silver.darkened(0.32), maxf(1, radius * 0.018), true)
	if motif == "potions":
		_poly([Vector2(40, 23), Vector2(60, 23), Vector2(60, 42), Vector2(70, 54), Vector2(66, 75), Vector2(34, 75), Vector2(30, 54), Vector2(40, 42)], Color("5a2924"))
		_line([Vector2(39, 23), Vector2(61, 23), Vector2(59, 42), Vector2(70, 54), Vector2(66, 75), Vector2(34, 75), Vector2(30, 54), Vector2(41, 42), Vector2(39, 23)], silver, 2.3)
		_line([Vector2(37, 18), Vector2(63, 18)], gold, 5)
		_line([Vector2(37, 58), Vector2(63, 58)], Color("c86d50"), 3)
		_line([Vector2(42, 47), Vector2(38, 58), Vector2(40, 69)], highlight, 1.5)
	elif motif == "bombs":
		draw_circle(_p(Vector2(48, 58)), radius * 0.23, Color("3d4142"))
		draw_arc(_p(Vector2(48, 58)), radius * 0.23, 0, TAU, 32, silver, maxf(1, radius * 0.022), true)
		_line([Vector2(48, 35), Vector2(48, 27), Vector2(62, 24), Vector2(66, 18)], gold, 3)
		_line([Vector2(35, 49), Vector2(41, 43), Vector2(52, 42)], highlight, 2)
		_line([Vector2(30, 67), Vector2(66, 49)], shade.darkened(0.5), 5)
	elif motif == "arrows":
		for offset: float in [-11.0, 7.0]:
			_line([Vector2(30 + offset, 76), Vector2(70 + offset, 24)], silver, 2.5)
			_poly([Vector2(70 + offset, 24), Vector2(55 + offset, 31), Vector2(66 + offset, 40)], silver)
			_line([Vector2(28 + offset, 72), Vector2(27 + offset, 63), Vector2(39 + offset, 67), Vector2(40 + offset, 79)], gold, 2)
