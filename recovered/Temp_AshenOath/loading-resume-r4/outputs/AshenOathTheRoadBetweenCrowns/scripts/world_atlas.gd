extends VBoxContainer

const Manifest = preload("res://scripts/world_sector_manifest.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")
var current := ""
var discovered: Dictionary = {}
var detail: Label
var chart: Control
var scroll: ScrollContainer
var model: Dictionary
var _unit := 1.0
var _buttons: Dictionary = {}
var _legend: Label
var _detail_scroll: ScrollContainer

func configure(zone: String, known: Dictionary) -> void:
	current = Manifest.canonical(zone)
	discovered = known.duplicate()
	discovered[current] = true
	model = Manifest.atlas()
	var legend := Label.new(); legend.text = "ASHEN OATH | ROAD ATLAS\nConnected passages: solid | Legacy return journey: dashed | Not to scale"
	_legend = legend
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(legend)
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.follow_focus = true; add_child(scroll)
	chart = Control.new(); chart.custom_minimum_size = Vector2(790,1040); scroll.add_child(chart)
	chart.draw.connect(_draw_routes)
	var focus: Button
	for id: String in model.get("positions", {}):
		var point: Array = model.positions[id]
		var button := Button.new(); button.position = Vector2(float(point[0])-70,float(point[1])-26); button.size = Vector2(140,52)
		button.text = str(Routes.ZONE_NAMES.get(id,id)); button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = button.text + (" | current" if id == current else (" | visited" if discovered.has(id) else " | not yet visited"))
		button.add_theme_font_size_override("font_size",16)
		var style := StyleBoxFlat.new(); style.bg_color = Color(0.025,0.04,0.035,0.98); style.border_color = Color(0.75,0.65,0.39) if discovered.has(id) else Color(0.25,0.32,0.29); style.set_border_width_all(1)
		if id == current: style.set_border_width_all(3)
		button.add_theme_stylebox_override("normal",style)
		button.pressed.connect(_select.bind(id)); chart.add_child(button)
		_buttons[id] = button
		if id == current: focus = button
	_detail_scroll = ScrollContainer.new(); _detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _detail_scroll.custom_minimum_size.y = 88; add_child(_detail_scroll)
	detail = Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _detail_scroll.add_child(detail)
	_select(current)
	if focus != null: scroll.call_deferred("ensure_control_visible",focus)

func apply_layout(policy: Dictionary) -> void:
	if chart == null: return
	_unit = float(policy.get("unit_scale",1.0))
	chart.custom_minimum_size = Vector2(790,1040)*_unit
	_legend.add_theme_font_size_override("font_size",int(policy.fonts.caption))
	detail.add_theme_font_size_override("font_size",int(policy.fonts.caption))
	_detail_scroll.custom_minimum_size.y = 88*_unit
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var point: Array = model.positions[id]
		button.position = Vector2(float(point[0])-70,float(point[1])-26)*_unit
		button.size = Vector2(140,52)*_unit
		button.add_theme_font_size_override("font_size",int(policy.fonts.caption))
	chart.queue_redraw()

func focus_current() -> void:
	var target: Button = _buttons.get(current)
	if target != null: target.grab_focus()

func _select(id: String) -> void:
	var names: Array[String] = []
	var landmarks: Array[String] = []
	for link: Dictionary in model.links:
		var other := ""
		if str(link.source) == id: other = str(link.target)
		elif str(link.target) == id and bool(link.get("return",false)): other = str(link.source)
		if other != "":
			names.append(str(Routes.ZONE_NAMES.get(other,other)) + (" (legacy journey)" if bool(link.journey) else ""))
			var landmark := Manifest.road_landmark(id, other)
			if not landmark.is_empty(): landmarks.append(str(landmark.name))
	var suffix := "Current location." if id == current else ("Visited." if discovered.has(id) else "Not yet visited; no encounters or secrets revealed.")
	if model.get("districts",{}).has(id): suffix += " A district within Greyfen, not a separate world."
	if model.get("phases",{}).has(id): suffix += " Greyfen's civic assembly, after the last witness is heard."
	detail.text = "%s | %s\nOutward routes (some story-gated): %s" % [str(Routes.ZONE_NAMES.get(id,id)),suffix,", ".join(names)]
	if not landmarks.is_empty(): detail.text += "\nRoad landmarks: " + "; ".join(landmarks)

func _draw_routes() -> void:
	for link: Dictionary in model.links:
		var a: Array = model.positions.get(str(link.source),[])
		var b: Array = model.positions.get(str(link.target),[])
		if a.size() != 2 or b.size() != 2: continue
		var from := Vector2(float(a[0]),float(a[1]))*_unit; var to := Vector2(float(b[0]),float(b[1]))*_unit
		var ink := Color(0.55,0.62,0.49,0.8)
		if bool(link.journey): chart.draw_dashed_line(from,to,Color(0.64,0.50,0.30),2*_unit,9*_unit,true)
		else: chart.draw_line(from,to,ink,2*_unit,true)
		if not bool(link.get("return",false)):
			var direction := from.direction_to(to)
			var tip := from.lerp(to,0.60)
			var wing := direction.orthogonal()*6.0*_unit
			chart.draw_polyline(PackedVector2Array([tip-direction*10*_unit+wing,tip,tip-direction*10*_unit-wing]),ink,2*_unit,true)
