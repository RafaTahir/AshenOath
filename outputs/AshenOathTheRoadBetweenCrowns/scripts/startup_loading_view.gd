extends Control

signal retry_requested

const MENU_FONT = preload("res://assets/ui/fonts/Spectral-Medium.ttf")
const BACKDROP = preload("res://assets_external/ui/greyfen_menu_stylized.png")
const ATLAS_PATH := "res://assets/ui/story_chapters_atlas.png"
const IVORY := Color("e7e0d0")
const GOLD := Color("c6a66d")
var reduced_motion := false
var high_contrast := false
var _art: TextureRect
var _next_art: TextureRect
var _content: VBoxContainer
var _title: Label
var _phase: Label
var _bar: ProgressBar
var _retry: Button
var _atlas: Texture2D
var _atlas_requested := false
var _slide := 0
var _slide_elapsed := 0.0
var _crossfade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_art = _make_art()
	_art.texture = BACKDROP
	_next_art = _make_art()
	_next_art.modulate.a = 0.0
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.018, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.resized.connect(_place_content)
	_title = Label.new()
	_title.text = "ASHEN OATH"
	_title.add_theme_font_override("font", MENU_FONT)
	_title.add_theme_color_override("font_color", IVORY)
	_content.add_child(_title)
	_phase = Label.new()
	_phase.text = "Preparing the road..."
	_phase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase.add_theme_color_override("font_color", IVORY)
	_content.add_child(_phase)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 4.0
	_bar.show_percentage = false
	_bar.indeterminate = true
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.8, 0.8, 0.8, 0.2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	_content.add_child(_bar)
	_retry = Button.new()
	_retry.text = "Retry"
	_retry.custom_minimum_size.y = 48.0
	_retry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_retry.add_theme_font_override("font", MENU_FONT)
	for key in ["normal", "hover", "pressed", "disabled"]:
		_retry.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = GOLD
	focus.border_width_bottom = 2
	_retry.add_theme_stylebox_override("focus", focus)
	_retry.add_theme_color_override("font_color", IVORY)
	_retry.add_theme_color_override("font_hover_color", GOLD)
	_retry.add_theme_color_override("font_focus_color", GOLD)
	_retry.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_retry.pressed.connect(func():
		_retry.hide()
		retry_requested.emit()
	)
	_retry.hide()
	_content.add_child(_retry)
	# The already-exported journal atlas is optional decoration, never a gate.
	_atlas_requested = ResourceLoader.load_threaded_request(ATLAS_PATH, "Texture2D") == OK
	resized.connect(_layout)
	_layout()

func _make_art() -> TextureRect:
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	return art

func update_progress(message: String, fraction: float = -1.0, failed: bool = false) -> void:
	_phase.text = message
	_bar.indeterminate = fraction < 0.0 and not failed and not reduced_motion
	_bar.value = clampf(fraction * 100.0, 0.0, 99.0)
	_bar.visible = not failed
	var was_failed := _retry.visible
	_retry.visible = failed
	if failed and not was_failed:
		_retry.grab_focus()
	call_deferred("_place_content")

func apply_accessibility(motion: bool, contrast: bool) -> void:
	reduced_motion = motion
	high_contrast = contrast
	_phase.add_theme_color_override("font_color", Color.WHITE if contrast else IVORY)
	if motion and _crossfade != null and _crossfade.is_valid():
		_crossfade.kill()
		_art.texture = _next_art.texture
		_next_art.modulate.a = 0.0
	if motion:
		_bar.indeterminate = false

func apply_layout(policy: Dictionary) -> void:
	set_meta("safe_rect", policy.safe_rect)
	set_meta("layout_policy", policy)
	_layout()

func _layout() -> void:
	if _content == null:
		return
	var safe: Rect2 = get_meta("safe_rect", Rect2(Vector2.ZERO, size))
	var policy: Dictionary = get_meta("layout_policy", {})
	var unit: float = float(policy.get("unit_scale", 1.0))
	var fonts: Dictionary = policy.get("fonts", {})
	var padding := minf(40.0 * unit, maxf(16.0 * unit, safe.size.x * 0.04))
	var content_height := maxf(180.0 * unit, _content.get_combined_minimum_size().y)
	_content.position = safe.position + Vector2(padding, maxf(padding, safe.size.y - content_height - padding))
	_content.size = Vector2(minf(480.0 * unit, maxf(0.0, safe.size.x - padding * 2.0)), 0.0)
	_content.add_theme_constant_override("separation", maxi(1, roundi(14.0 * unit)))
	_title.add_theme_font_size_override("font_size", int(fonts.get("heading", 32)))
	_phase.add_theme_font_size_override("font_size", int(fonts.get("caption", 18)))
	_retry.add_theme_font_size_override("font_size", int(fonts.get("button", 22)))
	_retry.custom_minimum_size.y = maxf(48.0 * unit, float(policy.get("button_min_height", 48.0)))
	_bar.custom_minimum_size.y = 4.0 * unit
	call_deferred("_place_content")

func _place_content() -> void:
	if _content == null:
		return
	var safe: Rect2 = get_meta("safe_rect", Rect2(Vector2.ZERO, size))
	var unit: float = float(Dictionary(get_meta("layout_policy", {})).get("unit_scale", 1.0))
	var padding := minf(40.0 * unit, maxf(16.0 * unit, safe.size.x * 0.04))
	_content.position.y = maxf(safe.position.y + padding, safe.end.y - padding - _content.size.y)

func _process(delta: float) -> void:
	if _atlas_requested and _atlas == null:
		var status := ResourceLoader.load_threaded_get_status(ATLAS_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_atlas = ResourceLoader.load_threaded_get(ATLAS_PATH) as Texture2D
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_atlas_requested = false
	_slide_elapsed += delta
	if _slide_elapsed < 8.0 or _atlas == null:
		return
	_slide_elapsed = 0.0
	var image := AtlasTexture.new()
	image.atlas = _atlas
	var tile := _atlas.get_size() / 2.0
	image.region = Rect2(Vector2(_slide % 2, _slide >> 1) * tile, tile)
	_slide = (_slide + 1) % 4
	if reduced_motion:
		_art.texture = image
		return
	_next_art.texture = image
	_next_art.modulate.a = 0.0
	_crossfade = create_tween()
	_crossfade.tween_property(_next_art, "modulate:a", 1.0, 0.3)
	_crossfade.tween_callback(func():
		_art.texture = image
		_next_art.modulate.a = 0.0
	)
