extends RefCounted

## Pure presentation budgets. Display lengths are CSS pixels on Web; callers
## supply native window lengths elsewhere. Rectangles and font sizes returned
## below are canvas coordinates. This policy never changes a render target.
const FALLBACK_CANVAS := Vector2(1280.0, 720.0)
const MAX_DISPLAY_DIMENSION := 32768.0

static func resolve(canvas_size: Vector2, display: Dictionary, text_scale: float = 1.0, input_device: String = "keyboard") -> Dictionary:
	var valid: bool = _positive(canvas_size.x) and _positive(canvas_size.y)
	var canvas: Vector2 = canvas_size if valid else FALLBACK_CANVAS
	var width: float = _number(display.get("width", canvas.x), canvas.x)
	var height: float = _number(display.get("height", canvas.y), canvas.y)
	if not _positive(width) or not _positive(height) or width > MAX_DISPLAY_DIMENSION or height > MAX_DISPLAY_DIMENSION:
		valid = false
		width = canvas.x
		height = canvas.y
	var display_size: Vector2 = Vector2(width, height)
	var display_factor: float = minf(width / canvas.x, height / canvas.y)
	var unit_scale: float = 1.0 / display_factor
	var fitted_size: Vector2 = canvas * display_factor
	var display_origin: Vector2 = (display_size - fitted_size) * 0.5
	var left: float = clampf(_number(display.get("inset_left", 0.0), 0.0), 0.0, width)
	var top: float = clampf(_number(display.get("inset_top", 0.0), 0.0), 0.0, height)
	var right: float = clampf(_number(display.get("inset_right", 0.0), 0.0), 0.0, width)
	var bottom: float = clampf(_number(display.get("inset_bottom", 0.0), 0.0), 0.0, height)
	var safe_display: Rect2 = Rect2(Vector2(left, top), Vector2(maxf(0.0, width - left - right), maxf(0.0, height - top - bottom)))
	var fitted_display: Rect2 = Rect2(display_origin, fitted_size)
	safe_display = safe_display.intersection(fitted_display)
	var safe_rect: Rect2 = Rect2((safe_display.position - display_origin) * unit_scale, safe_display.size * unit_scale)
	var usable: Vector2 = safe_display.size
	valid = valid and usable.x > 0.0 and usable.y > 0.0
	var scale: float = clampf(_number(text_scale, 1.0), 0.9, 1.5)
	var coarse: bool = bool(display.get("coarse_pointer", false)) or input_device == "touch"
	var wide_inner_width: float = minf(1440.0, maxf(0.0, usable.x - 48.0)) - 48.0
	var wide: bool = usable.x >= 1040.0 and usable.y >= 600.0 and wide_inner_width >= 480.0 * scale + 280.0 * scale + 16.0
	var compact: bool = not wide
	var margin_display: float = 12.0 if compact else 24.0
	margin_display = minf(margin_display, maxf(0.0, minf(usable.x, usable.y) * 0.05))
	var padding_display: float = 16.0 if compact else 24.0
	padding_display = minf(padding_display, maxf(0.0, minf(usable.x, usable.y) * 0.1))
	var gap_display: float = 12.0 if compact else 16.0
	var font_display: Dictionary = {
		"body": maxf(18.0, roundf(20.0 * scale)),
		"button": maxf(18.0, roundf(20.0 * scale)),
		"caption": maxf(16.0, roundf(16.0 * scale)),
		"subtitle": maxf(22.0, roundf(24.0 * scale)),
		"subtitle_bold": maxf(24.0, roundf(26.0 * scale)),
		"heading": maxf(22.0, roundf(26.0 * scale)),
		"title": roundf((40.0 if compact else 64.0) * minf(scale, 1.25))
	}
	var fonts: Dictionary = {}
	for key: String in font_display:
		fonts[key] = maxi(1, ceili(float(font_display[key]) * unit_scale))
	var button_display: float = maxf(48.0 if coarse else 44.0, ceilf(float(font_display.button) * 1.25 + 20.0))
	var metrics: Dictionary = {
		"valid": valid,
		"mode": "compact" if compact else "wide",
		"compact": compact,
		"canvas_size": canvas,
		"safe_rect": safe_rect,
		"unit_scale": unit_scale,
		"display_size": display_size,
		"display_usable_size": usable,
		"display_origin": display_origin,
		"text_scale": scale,
		"coarse_pointer": coarse,
		"revision": int(_number(display.get("revision", 0), 0.0)),
		"margin": margin_display * unit_scale,
		"padding": padding_display * unit_scale,
		"gap": gap_display * unit_scale,
		"button_min_height": button_display * unit_scale,
		"fonts": fonts
	}
	metrics["journal"] = _journal_layout(metrics)
	metrics["menu"] = _menu_layout(metrics)
	metrics["loading"] = _loading_layout(metrics)
	metrics["dialogue"] = dialogue_layout(metrics, false, 1)
	return metrics

static func dialogue_layout(metrics: Dictionary, has_stakes: bool, action_count: int, subtitle_lines: int = 2) -> Dictionary:
	var safe: Rect2 = metrics.get("safe_rect", Rect2(Vector2.ZERO, FALLBACK_CANVAS))
	var unit: float = maxf(0.0001, float(metrics.get("unit_scale", 1.0)))
	var scale: float = float(metrics.get("text_scale", 1.0))
	var padding: float = 10.0 * unit
	var margin: float = float(metrics.get("margin", 12.0 * unit))
	var gap: float = 6.0 * unit
	var button: float = float(metrics.get("button_min_height", 48.0 * unit))
	var fonts: Dictionary = metrics.get("fonts", {})
	var subtitle_font: float = float(fonts.get("subtitle", 24.0 * unit))
	var body_font: float = float(fonts.get("body", 20.0 * unit))
	var heading_font: float = float(fonts.get("heading", 26.0 * unit))
	var header: float = maxf(button, ceilf(heading_font * 1.25))
	var reader_min: float = float(clampi(subtitle_lines, 2, 4)) * ceilf(subtitle_font * 1.35) + 4.0 * unit
	var stakes_min: float = 2.0 * ceilf(body_font * 1.35) + 8.0 * unit if has_stakes else 0.0
	var reader: float = reader_min
	var stakes: float = maxf(stakes_min, 90.0 * scale * unit) if has_stakes else 0.0
	var rows: int = clampi(action_count, 1, 3)
	var choices: float = button * rows + gap * (rows - 1)
	var chrome: float = padding * 2.0 + header + gap * (3.0 if has_stakes else 2.0)
	var desired_height: float = chrome + reader + stakes + choices
	var frame: Rect2 = _frame(safe, Vector2(860.0 * unit, desired_height), margin, true)
	var available: float = maxf(0.0, frame.size.y - chrome)
	var outer_scroll: bool = available < reader_min + stakes_min + button
	if not outer_scroll:
		# Preserve minimum reading and a whole action before offering additional
		# choice rows. Rich text and long choice lists retain their own scroll.
		var excess: float = maxf(0.0, reader + stakes + choices - available)
		var reduction: float = minf(excess, maxf(0.0, choices - button))
		choices -= reduction
		excess -= reduction
		reduction = minf(excess, maxf(0.0, stakes - stakes_min))
		stakes -= reduction
		excess -= reduction
		reader -= minf(excess, maxf(0.0, reader - reader_min))
	return {
		"frame": frame,
		"header_height": header,
		"reader_height": reader,
		"stakes_height": stakes,
		"choices_height": choices,
		"outer_scroll": outer_scroll,
		"content_width": maxf(0.0, frame.size.x - padding * 2.0),
		"body_height": maxf(0.0, frame.size.y - padding * 2.0 - header - gap),
		"padding": padding,
		"gap": gap
	}

static func _journal_layout(metrics: Dictionary) -> Dictionary:
	var unit: float = float(metrics.unit_scale)
	var scale: float = float(metrics.text_scale)
	var compact: bool = bool(metrics.compact)
	var padding: float = float(metrics.padding)
	var gap: float = float(metrics.gap)
	var button: float = float(metrics.button_min_height)
	var frame: Rect2 = _frame(metrics.safe_rect, Vector2(1440.0, 860.0) * unit, float(metrics.margin))
	var inner_width: float = maxf(0.0, frame.size.x - padding * 2.0)
	var inner_height: float = maxf(0.0, frame.size.y - padding * 2.0)
	var footer_rows: int = 2 if compact and inner_width < (312.0 * scale * unit + gap * 2.0) else 1
	var footer: float = button * footer_rows + gap * (footer_rows - 1)
	var content_height: float = maxf(0.0, inner_height - footer - gap)
	var art: float = 0.0
	var usable: Vector2 = metrics.display_usable_size
	if not compact and usable.y >= 640.0 and scale <= 1.2:
		art = minf(84.0 * unit, content_height * 0.2)
	var fonts: Dictionary = metrics.fonts
	var notice: float = minf(2.0 * ceilf(float(fonts.caption) * 1.3), content_height * 0.2)
	var reader: float = maxf(0.0, content_height - notice - gap - art - (gap if art > 0.0 else 0.0))
	var sidebar: float = inner_width
	if not compact:
		var desired_sidebar: float = minf(420.0 * scale * unit, maxf(280.0 * scale * unit, inner_width * 0.31))
		sidebar = minf(desired_sidebar, maxf(0.0, inner_width - gap - 480.0 * scale * unit))
	var actions: float = minf(button * (2.0 if compact else 1.0) + (gap if compact else 0.0), reader * 0.35)
	return {
		"frame": frame,
		"compact": compact,
		"reader_height": reader,
		"sidebar_width": sidebar,
		"footer_height": footer,
		"art_height": art,
		"notice_height": notice,
		"action_height": actions,
		"content_width": inner_width,
		"content_height": content_height,
		"footer_rows": footer_rows
	}

static func _menu_layout(metrics: Dictionary) -> Dictionary:
	var unit: float = float(metrics.unit_scale)
	var compact: bool = bool(metrics.compact)
	var padding: float = float(metrics.padding)
	var gap: float = float(metrics.gap)
	var frame: Rect2 = _frame(metrics.safe_rect, Vector2(1440.0, 960.0) * unit, float(metrics.margin))
	var inner_width: float = maxf(0.0, frame.size.x - padding * 2.0)
	var footer: float = float(metrics.button_min_height)
	var panel_width: float = inner_width if compact else minf(600.0 * unit, inner_width * 0.44)
	return {
		"frame": frame,
		"compact": compact,
		"panel_width": panel_width,
		"panel_height": maxf(0.0, frame.size.y - padding * 2.0 - footer - gap),
		"content_width": maxf(0.0, panel_width - padding * 2.0),
		"footer_height": footer,
		"outer_scroll": compact,
		"title_width": maxf(0.0, inner_width - panel_width - gap) if not compact else inner_width
	}

static func _loading_layout(metrics: Dictionary) -> Dictionary:
	var unit: float = float(metrics.unit_scale)
	var scale: float = float(metrics.text_scale)
	var padding: float = float(metrics.padding)
	var gap: float = float(metrics.gap)
	var frame: Rect2 = _frame(metrics.safe_rect, Vector2(600.0 * unit, 220.0 * scale * unit), float(metrics.margin))
	var footer: float = float(metrics.button_min_height)
	return {
		"frame": frame,
		"content_width": maxf(0.0, frame.size.x - padding * 2.0),
		"footer_height": footer,
		"body_height": maxf(0.0, frame.size.y - padding * 2.0 - footer - gap)
	}

static func _frame(safe: Rect2, preferred: Vector2, margin: float, align_bottom: bool = false) -> Rect2:
	var available: Vector2 = Vector2(maxf(0.0, safe.size.x - margin * 2.0), maxf(0.0, safe.size.y - margin * 2.0))
	var size: Vector2 = Vector2(minf(maxf(0.0, preferred.x), available.x), minf(maxf(0.0, preferred.y), available.y))
	var position: Vector2 = safe.position + (safe.size - size) * 0.5
	if align_bottom:
		position.y = safe.position.y + safe.size.y - margin - size.y
	return Rect2(position, size)

static func _number(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var numeric: float = float(value)
	return numeric if is_finite(numeric) else fallback

static func _positive(value: float) -> bool:
	return is_finite(value) and value > 0.0
