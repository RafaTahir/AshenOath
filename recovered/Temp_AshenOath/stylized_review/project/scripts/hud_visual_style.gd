extends RefCounted

const IVORY := Color("e9e6db")
const SILVER := Color("babebd")
const GOLD := Color("cbb778")
const MUTED := Color("a5a69f")
const INK := Color("101214")
static var _bar_styles: Dictionary = {}
static var _choice_styles: Dictionary = {}
static var _subtitle_lines: Dictionary = {}
static var _contrast_panel: StyleBoxFlat

static func apply_bar(bar: ProgressBar, kind: String, high_contrast: bool = false) -> void:
	var red: bool = kind != "stamina"
	var top: String = "dd4f42" if red else "e1cb77"
	var base: String = "8c191b" if red else "9b7737"
	var low: String = "430b10" if red else "4d361a"
	if high_contrast:
		top = "ff8372" if red else "fff0a3"
		base = "d54235" if red else "e3bd55"
	var rim: String = "eceee9" if high_contrast else "9fa4a1"
	var background_svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="28" viewBox="0 0 480 28"><path d="M1 2 H457 L478 14 L457 26 H1 Z" fill="#101214" fill-opacity=".88" stroke="#' + rim + '" stroke-width="1.3"/><path d="M3 4 H456 L473 14" fill="none" stroke="#dadbd2" stroke-opacity=".35"/><path d="M4 25 H456" stroke="#000" stroke-opacity=".75"/></svg>'
	var fill_svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="28" viewBox="0 0 480 28"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#' + top + '"/><stop offset=".3" stop-color="#' + base + '"/><stop offset="1" stop-color="#' + low + '"/></linearGradient></defs><path d="M2 4 H455 L472 14 L455 24 H2 Z" fill="url(#g)"/><path d="M3 5 H454 L467 13" fill="none" stroke="#fff" stroke-opacity=".24"/></svg>'
	bar.add_theme_stylebox_override("background", _svg_style(background_svg))
	bar.add_theme_stylebox_override("fill", _svg_style(fill_svg))

static func _svg_style(source: String) -> StyleBoxTexture:
	if _bar_styles.has(source):
		return _bar_styles[source]
	var image: Image = Image.new()
	image.load_svg_from_string(source)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = 2.0
	style.texture_margin_right = 24.0
	style.texture_margin_top = 2.0
	style.texture_margin_bottom = 2.0
	_bar_styles[source] = style
	return style

static var _dialogue_scrims: Dictionary = {}

static func dialogue_panel(high_contrast: bool, opacity: float = 0.55) -> StyleBox:
	if not high_contrast:
		var key := snappedf(opacity, 0.01)
		if not _dialogue_scrims.has(key):
			var image := Image.new()
			var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="768" height="320" viewBox="0 0 768 320"><defs><radialGradient id="shade" cx="50%%" cy="55%%" r="66%%"><stop offset="0" stop-color="#080a0c" stop-opacity="%s"/><stop offset=".55" stop-color="#080a0c" stop-opacity="%s"/><stop offset="1" stop-color="#080a0c" stop-opacity="0"/></radialGradient></defs><rect width="768" height="320" fill="url(#shade)"/></svg>' % [str(key), str(key * 0.75)]
			image.load_svg_from_string(svg)
			var scrim := StyleBoxTexture.new()
			scrim.texture = ImageTexture.create_from_image(image)
			scrim.content_margin_left = 12
			scrim.content_margin_right = 12
			scrim.content_margin_top = 8
			scrim.content_margin_bottom = 8
			_dialogue_scrims[key] = scrim
		return _dialogue_scrims[key]
	if _contrast_panel != null:
		return _contrast_panel
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.029, 0.032, 0.98 if high_contrast else opacity)
	panel.border_color = Color.WHITE if high_contrast else Color(0.67, 0.64, 0.51, 0.65)
	panel.set_border_width_all(0)
	panel.border_width_top = 2 if high_contrast else 1
	panel.border_width_bottom = 1
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 12
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	_contrast_panel = panel
	return panel

static func dialogue_choice(button: Button, high_contrast: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var key := state + str(high_contrast)
		if not _choice_styles.has(key):
			var style := StyleBoxFlat.new()
			var selected := state in ["hover", "pressed", "focus"]
			style.bg_color = Color(0.02, 0.025, 0.03, (0.96 if high_contrast else 0.20) if selected else (0.78 if high_contrast else 0.0))
			style.border_color = Color.WHITE if high_contrast else GOLD
			style.border_width_left = 3 if selected else 0
			style.content_margin_left = 14
			style.content_margin_right = 14
			_choice_styles[key] = style
		button.add_theme_stylebox_override(state, _choice_styles[key])
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", Color.WHITE if high_contrast else GOLD)
	for child in button.get_children():
		if child is Label:
			label_color(child, MUTED if button.disabled else IVORY, high_contrast)
	if bool(button.get_meta("wrapped_label", false)):
		for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color", "font_shadow_color", "font_outline_color"]:
			button.add_theme_color_override(key, Color.TRANSPARENT)

static func subtitle_lines(text: String, font: Font, font_size: int, width: float) -> int:
	if font == null or width <= 0.0: return 3
	var key := "%d:%d:%s:%s" % [font.get_instance_id(), font_size, str(width), text]
	if _subtitle_lines.has(key):
		return int(_subtitle_lines[key])
	var count := 0
	for paragraph: String in text.split("\n"):
		var row_width := 0.0
		count += 1
		for word: String in paragraph.split(" ", false):
			var word_width := font.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if row_width > 0.0 and row_width + word_width > width:
				count += 1
				row_width = 0.0
			row_width += word_width
	if _subtitle_lines.size() >= 256:
		_subtitle_lines.erase(_subtitle_lines.keys()[0])
	_subtitle_lines[key] = clampi(count, 2, 4)
	return int(_subtitle_lines[key])

static func label_color(label: Label, color: Color, high_contrast: bool = false) -> void:
	label.add_theme_color_override("font_color", Color.WHITE if high_contrast else color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 3 if high_contrast else 2)
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.026, 0.027, 0.9))
