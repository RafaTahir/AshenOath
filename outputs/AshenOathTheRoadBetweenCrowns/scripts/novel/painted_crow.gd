extends CanvasLayer

## Sella's memory is presented at the scale of her hands. Its cursor and
## keepsake never write evidence to Kael's journal.
const Tabletop = preload("res://scripts/novel/tabletop.gd")
const CROW := "res://assets/narrative_props/crow/"
const FORMS := ["OrenPaintedCrow","OrenPaintedCrow","OrenShrineCrow","OrenWrappedCrow"]
const CAPTIONS := [
	["The cart · before Greyfen","Oren has borrowed the black paint. He has left a little circle of bare brass. “So it can see,” he tells his mother."],
	["Sella","Four letters scratched into the brass. Oren mouths them. The lamp guttering beside the basin is suddenly the loudest thing in the room."],
	["At the shrine","Sella has tied the red cord. Anwen winds grey burial thread over it. Bram breaks the last onion pastry into three pieces."],
	["At the gate","The latch sticks. Anwen lends Sella a brown shawl with a yellow edge. “I’ll come behind you.” The boy’s coat stays on its peg."]
]
const VERBS := ["Turn the crow to the light","Tie Sella’s red cord","Wrap the crow for the road","Lift the latch"]

var game
var view: SubViewport
var stage: Node3D
var token: Node3D
var flame: OmniLight3D
var title: Label
var subtitle: Label
var next: Button
var previous_mouse: int
var cursor := 0
var done := false

static func present(host) -> bool:
	if host.story_state.get_flag("novel_edition",0) != 1 or host.story_state.get_flag("novel_prologue_closed", false): return false
	if host.get_node_or_null("PaintedCrowMemory") != null: return true
	var memory = load("res://scripts/novel/painted_crow.gd").new()
	memory.name = "PaintedCrowMemory"
	memory.game = host
	memory.process_mode = Node.PROCESS_MODE_ALWAYS
	memory.layer = 105
	host.add_child(memory)
	memory.begin()
	return true

func begin() -> void:
	previous_mouse = Input.mouse_mode
	game.input_router.begin_context("dialogue")
	game.get_tree().paused = true
	game.audio.set_game_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shade := ColorRect.new()
	shade.color = Color("#181a19")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	shade.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_right = -16
	layout.offset_top = 8
	layout.offset_bottom = -10
	var image := SubViewportContainer.new()
	image.stretch = true
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(image)
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	image.add_child(view)
	_make_stage()
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("#e1c68e"))
	layout.add_child(title)
	subtitle = Label.new()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(buttons)
	next = Button.new()
	next.custom_minimum_size.y = 48
	next.pressed.connect(_advance)
	buttons.add_child(next)
	var skip := Button.new()
	skip.text = "Continue to Greyfen"
	skip.custom_minimum_size.y = 48
	skip.pressed.connect(_close.bind(true))
	buttons.add_child(skip)
	cursor = clampi(int(game.story_state.get_flag("novel_prologue_cursor",0)),0,CAPTIONS.size()-1)
	_show_frame()
	next.grab_focus()
	image.resized.connect(_redraw)

func _make_stage() -> void:
	stage = Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202925")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d1cdc1")
	environment.environment.ambient_light_energy = 0.55
	stage.add_child(environment)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,0.22,0.46)
	camera.look_at(Vector3(0,0.05,0),Vector3.UP)
	camera.near = 0.015
	camera.fov = 32
	camera.current = true
	for i in 5:
		Tabletop.box(stage,Vector3((i-2)*0.135,-0.03,0),Vector3(0.133,0.05,0.72),Color(0.31+i*0.014,0.21,0.14))
	var daylight := DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-47,-30,0)
	daylight.light_color = Color("#e8d2ad")
	stage.add_child(daylight)
	flame = OmniLight3D.new()
	flame.position = Vector3(-0.16,0.12,0.10)
	flame.light_color = Color("#ffab59")
	flame.omni_range = 1.1
	stage.add_child(flame)

func _redraw() -> void:
	view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _show_frame() -> void:
	if is_instance_valid(token):
		stage.remove_child(token)
		token.queue_free()
	var path := CROW + str(FORMS[cursor]) + ".tscn"
	var scene := ResourceLoader.load(path) as PackedScene
	if scene != null:
		token = scene.instantiate()
		stage.add_child(token)
		token.position.y = 0.067
		token.rotation_degrees = Vector3(-20,18 if cursor == 0 else -12,-6)
	else:
		push_error("Missing prologue crow: " + path)
	flame.light_energy = 0.82 if cursor == 0 else 0.13
	title.text = CAPTIONS[cursor][0]
	subtitle.text = CAPTIONS[cursor][1]
	next.text = VERBS[cursor]
	_redraw()

func _advance() -> void:
	if done: return
	if cursor+1 >= CAPTIONS.size():
		_close(false)
		return
	cursor += 1
	game.story_state.set_flag("novel_prologue_cursor",cursor)
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	_show_frame()

func _close(skipped: bool) -> void:
	if done: return
	done = true
	game.story_state.set_flag("novel_prologue_closed",true)
	game.story_state.set_flag("novel_prologue_presentation","skipped" if skipped else "witnessed")
	game.story_save_pending = true
	game.call_deferred("_persist_story_action")
	game._resume_game()
	Input.mouse_mode = previous_mouse
	queue_free()
