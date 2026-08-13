extends Control

## Lightweight 2D sky layer rendered behind the 3D world. It keeps celestial
## landmarks visible in the browser even when the Compatibility renderer does
## not present the distant billboard geometry reliably.

var daylight := 0.0
var twilight := 0.0
var night := 1.0
var world_minutes := 60.0
var quality := "balanced"
var zone_id := "greyfen"
var reduced_motion := false
var outdoor := true
var overlay_only := false
var palette: Dictionary = {}
var _stars: Array[Vector2] = []
var _star_sizes: Array[float] = []
var _star_alpha: Array[float] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_star_points()

func set_state(
		new_daylight: float,
		new_twilight: float,
		new_night: float,
		minutes: float,
		new_quality: String,
		new_zone_id: String,
		motion_reduced: bool,
		new_palette: Dictionary,
		is_outdoor: bool = true
	) -> void:
	daylight = clampf(new_daylight, 0.0, 1.0)
	twilight = clampf(new_twilight, 0.0, 1.0)
	night = clampf(new_night, 0.0, 1.0)
	world_minutes = fposmod(minutes, 1440.0)
	quality = new_quality
	zone_id = new_zone_id
	reduced_motion = motion_reduced
	palette = new_palette
	outdoor = is_outdoor
	visible = outdoor
	queue_redraw()

func set_overlay_only(enabled: bool) -> void:
	overlay_only = enabled
	queue_redraw()

func get_sky_state() -> Dictionary:
	return {
		"outdoor": outdoor,
		"sun_visible": outdoor and (daylight + twilight) > 0.05,
		"moon_visible": outdoor and night > 0.05 and (daylight + twilight) <= 0.05,
		"stars_visible": outdoor and night > 0.20,
		"clouds_visible": outdoor,
		"quality": quality,
		"zone": zone_id,
	}

func get_visible_cloud_count() -> int:
	if not outdoor:
		return 0
	return 2 if quality == "potato" else (6 if quality == "quality" else 4)

func get_visible_star_count() -> int:
	if not outdoor or night <= 0.20:
		return 0
	return 28 if quality == "potato" else (96 if quality == "quality" else 62)

func _build_star_points() -> void:
	for index in range(96):
		var x := fposmod(float(index * 47 + 13), 997.0) / 997.0
		var y := 0.08 + fposmod(float(index * 83 + 29), 601.0) / 601.0 * 0.47
		_stars.append(Vector2(x, y))
		_star_sizes.append(0.9 + float(index % 4) * 0.45)
		_star_alpha.append(0.62 + float(index % 5) * 0.09)

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0 or not outdoor:
		return
	if overlay_only:
		if night > 0.20 and daylight + twilight <= 0.08:
			_draw_stars()
		return
	var colors := _sky_colors()
	var band_count := 28
	for band in range(band_count):
		var top := float(band) / float(band_count)
		var bottom := float(band + 1) / float(band_count)
		draw_rect(Rect2(0.0, top * size.y, size.x, (bottom - top) * size.y + 1.0), _sample_sky_color(colors, top))
	_draw_horizon_haze(colors.horizon, colors.horizon_alpha)
	if night > 0.20 and daylight + twilight <= 0.08:
		_draw_stars()
		_draw_moon()
	else:
		_draw_sun()
	_draw_clouds(colors.cloud, colors.cloud_shadow, colors.cloud_alpha)

func _sky_colors() -> Dictionary:
	var day_top: Color = palette.get("day_top", Color(0.12, 0.25, 0.45))
	var day_horizon: Color = palette.get("day_horizon", Color(0.56, 0.57, 0.54))
	var dusk_top: Color = palette.get("dusk_top", Color(0.16, 0.11, 0.24))
	var dusk_horizon: Color = palette.get("dusk_horizon", Color(0.72, 0.30, 0.18))
	var night_top: Color = palette.get("night_top", Color(0.008, 0.018, 0.055))
	var night_horizon: Color = palette.get("night_horizon", Color(0.08, 0.15, 0.24))
	var top := night_top.lerp(dusk_top, twilight).lerp(day_top, daylight)
	var horizon := night_horizon.lerp(dusk_horizon, twilight).lerp(day_horizon, daylight)
	var cloud_alpha := clampf(daylight * 0.62 + twilight * 0.48 + night * 0.12, 0.0, 0.68)
	var cloud: Color = palette.get("cloud_day", Color(0.90, 0.92, 0.94)).lerp(palette.get("cloud_dusk", Color(0.78, 0.40, 0.28)), twilight)
	if night > 0.45:
		cloud = Color(0.19, 0.25, 0.37)
	return {
		"top": top,
		"horizon": horizon,
		"horizon_alpha": clampf(daylight * 0.20 + twilight * 0.28 + night * 0.12, 0.08, 0.34),
		"cloud": cloud,
		"cloud_shadow": cloud.darkened(0.34),
		"cloud_alpha": cloud_alpha,
	}

func _sample_sky_color(colors: Dictionary, t: float) -> Color:
	var top: Color = colors.top
	var horizon: Color = colors.horizon
	# A small nonlinear lift at the horizon keeps nighttime paths readable
	# without turning the whole sky into daytime blue.
	return top.lerp(horizon, smoothstep(0.10, 0.88, t))

func _draw_horizon_haze(color: Color, alpha: float) -> void:
	var haze := Color(color.r, color.g, color.b, alpha)
	draw_rect(Rect2(0.0, size.y * 0.58, size.x, size.y * 0.20), haze)

func _draw_stars() -> void:
	var fade := clampf((night - 0.12) / 0.70, 0.0, 1.0)
	var count := get_visible_star_count()
	for index in range(count):
		var point := Vector2(_stars[index].x * size.x, _stars[index].y * size.y)
		var twinkle := 1.0 + sin(world_minutes * 0.021 + float(index) * 1.73) * 0.12
		var alpha := _star_alpha[index] * fade * twinkle
		var color := Color(0.72, 0.84, 1.0, alpha)
		draw_circle(point, _star_sizes[index], color)

func _draw_sun() -> void:
	var arc := clampf((world_minutes - 330.0) / 870.0, 0.0, 1.0)
	var sun_height := sin(clampf((world_minutes - 420.0) / 690.0, 0.0, 1.0) * PI)
	var position := Vector2(lerpf(size.x * 0.12, size.x * 0.88, arc), size.y * (0.62 - sun_height * 0.34))
	var alpha := clampf(daylight + twilight * 0.72, 0.0, 1.0)
	for radius in [42.0, 31.0, 23.0]:
		var ring_alpha := alpha * (0.035 if radius > 31.0 else (0.055 if radius > 23.0 else 0.10))
		draw_circle(position, radius, Color(1.0, 0.60, 0.28, ring_alpha))
	draw_circle(position, 12.0, Color(1.0, 0.92, 0.72, 0.96 * alpha))
	draw_circle(position + Vector2(-2.0, -2.0), 7.5, Color(1.0, 0.98, 0.88, 0.96 * alpha))

func _draw_moon() -> void:
	var night_t := fposmod(world_minutes + 330.0, 1440.0) / 1440.0
	var position := Vector2(size.x * (0.18 + fposmod(night_t * 1.7, 1.0) * 0.64), size.y * 0.24)
	for radius in [42.0, 31.0, 22.0]:
		draw_circle(position, radius, Color(0.40, 0.58, 0.86, 0.025 if radius > 31.0 else (0.04 if radius > 22.0 else 0.065)))
	draw_circle(position, 14.0, Color(0.76, 0.84, 0.94, 0.94))
	# Small crater marks give the disc a natural face without a texture import.
	draw_circle(position + Vector2(-4.0, -3.0), 2.0, Color(0.58, 0.67, 0.80, 0.35))
	draw_circle(position + Vector2(3.5, 4.0), 1.5, Color(0.55, 0.64, 0.77, 0.30))
	draw_circle(position + Vector2(5.0, -5.0), 1.2, Color(0.59, 0.68, 0.80, 0.28))

func _draw_clouds(color: Color, shadow: Color, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var count := get_visible_cloud_count()
	for index in range(count):
		var travel := 0.0 if reduced_motion else fmod(world_minutes * 0.13 + float(index) * 224.0, size.x + 260.0) - 130.0
		var centre := Vector2(travel, size.y * (0.16 + float(index % 3) * 0.085))
		var scale := 0.82 + float(index % 4) * 0.12
		var shadow_alpha := alpha * (0.20 if night < 0.4 else 0.12)
		draw_colored_polygon(_ellipse(centre + Vector2(10.0, 11.0), Vector2(92.0, 18.0) * scale, 0.0), Color(shadow.r, shadow.g, shadow.b, shadow_alpha))
		var lobes := [
			[Vector2(-56.0, 3.0), Vector2(42.0, 14.0)],
			[Vector2(-20.0, -7.0), Vector2(53.0, 23.0)],
			[Vector2(24.0, -2.0), Vector2(64.0, 18.0)],
			[Vector2(66.0, 7.0), Vector2(34.0, 12.0)],
		]
		for lobe in lobes:
			var centre_offset: Vector2 = lobe[0]
			var radii: Vector2 = lobe[1]
			draw_colored_polygon(_ellipse(centre + centre_offset * scale, radii * scale, 0.0), Color(color.r, color.g, color.b, alpha * 0.72))

func _ellipse(centre: Vector2, radii: Vector2, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(rotation))
	return points
