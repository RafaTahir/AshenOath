extends VBoxContainer

const Manifest = preload("res://scripts/world_sector_manifest.gd")
const Routes = preload("res://scripts/story_route_catalog.gd")
var current := ""
var discovered: Dictionary = {}
var detail: Label
var chart: Control
var scroll: ScrollContainer
var model: Dictionary

func configure(zone: String, known: Dictionary) -> void:
	current = Manifest.canonical(zone)
	discovered = known.duplicate()
	discovered[current] = true
	model = Manifest.atlas()
	var legend := Label.new(); legend.text = "ASHEN OATH | ROAD ATLAS\nRoad crossings: solid | Journey transfers: dashed | Not to scale"
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
		if id == current: focus = button
	detail = Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.custom_minimum_size.y = 72; add_child(detail)
	_select(current)
	if focus != null: scroll.call_deferred("ensure_control_visible",focus)

func _select(id: String) -> void:
	var names: Array[String] = []
	for link: Dictionary in model.links:
		var other := ""
		if str(link.source) == id: other = str(link.target)
		elif str(link.target) == id and bool(link.get("return",false)): other = str(link.source)
		if other != "": names.append(str(Routes.ZONE_NAMES.get(other,other)) + (" (journey transfer)" if bool(link.journey) else ""))
	var suffix := "Current location." if id == current else ("Visited." if discovered.has(id) else "Not yet visited; no encounters or secrets revealed.")
	if model.get("districts",{}).has(id): suffix += " A district within Greyfen, not a separate world."
	if model.get("phases",{}).has(id): suffix += " Greyfen's civic assembly, after the last witness is heard."
	detail.text = "%s | %s\nOutward routes (some story-gated): %s" % [str(Routes.ZONE_NAMES.get(id,id)),suffix,", ".join(names)]

func _draw_routes() -> void:
	for link: Dictionary in model.links:
		var a: Array = model.positions.get(str(link.source),[])
		var b: Array = model.positions.get(str(link.target),[])
		if a.size() != 2 or b.size() != 2: continue
		var from := Vector2(float(a[0]),float(a[1])); var to := Vector2(float(b[0]),float(b[1]))
		var ink := Color(0.55,0.62,0.49,0.8)
		if bool(link.journey): chart.draw_dashed_line(from,to,Color(0.64,0.50,0.30),2,9,true)
		else: chart.draw_line(from,to,ink,2,true)
		if not bool(link.get("return",false)):
			var direction := from.direction_to(to)
			var tip := from.lerp(to,0.60)
			var wing := direction.orthogonal()*6.0
			chart.draw_polyline(PackedVector2Array([tip-direction*10+wing,tip,tip-direction*10-wing]),ink,2,true)
