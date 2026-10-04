extends Control

## A north-up local schematic. Geometry and marker knowledge come from the
## gameplay coordinator; this surface invents neither terrain nor discoveries.
var _snapshot: Dictionary = {}
var _high_contrast := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)

func set_snapshot(snapshot: Dictionary) -> void:
	if snapshot == _snapshot:
		return
	_snapshot = snapshot.duplicate(true)
	tooltip_text = str(snapshot.get("zone_label", ""))
	queue_redraw()

func set_high_contrast(enabled: bool) -> void:
	if _high_contrast == enabled:
		return
	_high_contrast = enabled
	queue_redraw()

func _draw() -> void:
	var span: float = minf(size.x, size.y)
	if span < 24.0:
		return
	var scale: float = span / 170.0
	var center: Vector2 = size * 0.5
	var radius: float = span * 0.5 - 12.0 * scale
	var silver: Color = Color(0.91, 0.93, 0.89) if _high_contrast else Color(0.64, 0.66, 0.61)
	var brass: Color = Color(1.0, 0.83, 0.37) if _high_contrast else Color(0.66, 0.53, 0.30)
	draw_circle(center + Vector2(0, 3.0 * scale), radius + 9.0 * scale, Color(0, 0, 0, 0.48))
	draw_circle(center, radius + 7.0 * scale, Color(0.045, 0.049, 0.044, 0.97))
	draw_circle(center, radius, Color(0.045, 0.058, 0.046, 0.97))
	var clip: PackedVector2Array = _circle_polygon(center, radius)
	var has_position: bool = not _snapshot.is_empty() and _snapshot.get("player_xz") is Vector2
	if has_position:
		var player: Vector2 = _snapshot.get("player_xz", Vector2.ZERO)
		var metres: float = maxf(float(_snapshot.get("radius_m", 22.0)), 1.0)
		var factor: float = radius / metres
		for raw_shape: Variant in _snapshot.get("terrain", []):
			if not raw_shape is Dictionary:
				continue
			var raw_points: Variant = raw_shape.get("points", PackedVector2Array())
			if not raw_points is PackedVector2Array or raw_points.size() < 3:
				continue
			var projected: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in raw_points:
				projected.append(center + (point - player) * factor)
			var kind: String = str(raw_shape.get("kind", "ground"))
			var color: Color = _terrain_color(kind)
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(projected, clip):
				if polygon.size() < 3:
					continue
				draw_colored_polygon(polygon, color)
				if kind in ["bridge", "obstacle"]:
					var outline: PackedVector2Array = polygon.duplicate()
					outline.append(polygon[0])
					draw_polyline(outline, Color(0.66, 0.63, 0.46, 0.65) if kind == "bridge" else Color(0.37, 0.38, 0.31, 0.8), maxf(0.75, scale), true)
		for raw_marker: Variant in _snapshot.get("markers", []):
			if raw_marker is Dictionary and raw_marker.get("position") is Vector2:
				_draw_marker(raw_marker, center, radius, player, factor, scale, brass)
		var forward: Vector2 = _snapshot.get("player_forward", Vector2.UP)
		if forward.length_squared() < 0.001:
			forward = Vector2.UP
		forward = forward.normalized()
		var side: Vector2 = Vector2(-forward.y, forward.x)
		var arrow: PackedVector2Array = PackedVector2Array([center + forward * 8.0 * scale, center - forward * 5.0 * scale + side * 5.0 * scale, center - forward * 2.0 * scale, center - forward * 5.0 * scale - side * 5.0 * scale])
		draw_circle(center, 10.0 * scale, Color(0.025, 0.029, 0.025, 0.7))
		draw_colored_polygon(arrow, Color(0.96, 0.95, 0.86))
	draw_arc(center, radius, 0, TAU, 96, brass, maxf(1.0, 1.2 * scale), true)
	draw_arc(center, radius + 5.0 * scale, 0, TAU, 96, silver, maxf(1.0, 1.5 * scale), true)
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0 - PI * 0.5
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var length: float = 5.0 if index % 6 == 0 else 2.0
		draw_line(center + direction * (radius + 1.0 * scale), center + direction * (radius + length * scale), silver, maxf(0.8, scale), true)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(10, int(12.0 * scale))
	var north_width: float = font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var north_position: Vector2 = center + Vector2(-north_width * 0.5, -radius - 1.0 * scale)
	draw_circle(center + Vector2(0, -radius - 5.0 * scale), 8.0 * scale, Color(0.045, 0.049, 0.044, 1.0))
	draw_string(font, north_position, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, silver)

func _terrain_color(kind: String) -> Color:
	var colors: Dictionary = {
		"ground": Color(0.18, 0.205, 0.145, 1.0),
		"road": Color(0.36, 0.315, 0.20, 1.0),
		"water": Color(0.085, 0.17, 0.18, 1.0),
		"bridge": Color(0.48, 0.39, 0.25, 1.0),
		"obstacle": Color(0.09, 0.10, 0.078, 1.0)
	}
	var color: Color = colors.get(kind, colors["ground"])
	if _high_contrast and kind in ["road", "bridge"]:
		color = color.lightened(0.2)
	return color

func _circle_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(64):
		var angle: float = TAU * float(index) / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw_marker(marker: Dictionary, center: Vector2, radius: float, player: Vector2, factor: float, scale: float, brass: Color) -> void:
	var position: Vector2 = marker.get("position", player)
	var offset: Vector2 = (position - player) * factor
	var rim: float = maxf(radius - 9.0 * scale, 1.0)
	var off_map: bool = offset.length() > rim
	var shown: Vector2 = center + offset.limit_length(rim)
	var points: PackedVector2Array
	if off_map:
		var direction: Vector2 = offset.normalized()
		var side: Vector2 = Vector2(-direction.y, direction.x)
		points = PackedVector2Array([shown + direction * 6.0 * scale, shown - direction * 4.0 * scale + side * 4.0 * scale, shown - direction * 4.0 * scale - side * 4.0 * scale])
	else:
		points = PackedVector2Array([shown + Vector2(0, -5) * scale, shown + Vector2(5, 0) * scale, shown + Vector2(0, 5) * scale, shown + Vector2(-5, 0) * scale])
	draw_circle(shown, 7.0 * scale, Color(0.03, 0.026, 0.019, 0.88))
	draw_colored_polygon(points, brass.lightened(0.2))
	if str(marker.get("kind", "")) == "passage" and not off_map:
		draw_circle(shown, 1.8 * scale, Color(0.075, 0.067, 0.047))
