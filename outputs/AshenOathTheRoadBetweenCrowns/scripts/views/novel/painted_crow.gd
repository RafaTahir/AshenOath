extends CanvasLayer

## Sella's memory is presented at the scale of her hands. Its cursor and
## keepsake never write evidence to Kael's journal.
const SCENERY := "res://assets/narrative_props/prologue/"
const CROW := "res://assets/narrative_props/crow/"
const SHOTS := [
	{"setting": "yard", "form": "OrenPaintedCrow", "light": Color("#f1dfc5"), "energy": 0.88},
	{"setting": "basin", "form": "OrenPaintedCrow", "light": Color("#d9e4ef"), "energy": 0.62},
	{"setting": "shrine", "form": "OrenShrineCrow", "light": Color("#efe2cb"), "energy": 0.75},
	{"setting": "gate", "form": "OrenWrappedCrow", "light": Color("#c7d5e2"), "energy": 0.68},
]
const CAPTIONS := [
	["Beneath Bram’s wagon", "Sella finds her good black paint in the dust. Oren has left a pinprick of bare brass for the crow’s eye."],
	["At the washbasin", "The water darkens. Oren shows his mother the four letters he scratched clear beneath the bird. AVEL."],
	["At the shrine", "Sella gave Oren the larger piece of onion pastry. Now Anwen winds grey thread over Sella’s knot. “You can still see the crow,” he says."],
	["At the gate", "Oren’s damp coat stays by the shrine fire. In its place he has Anwen’s shawl. At the wagon, Sella checks the knot once more."]
]
const VERBS := ["Turn the crow to the light","Tie Sella’s red cord","Wrap the crow for the road","Lift the latch"]

var game
var view: SubViewport
var stage: Node3D
var token: Node3D
var setting: Node3D
var daylight: DirectionalLight3D
var title: Label
var subtitle: Label
var next: Button
var previous_mouse: int
var cursor := 0
var done := false

static func present(host: Node) -> bool:
	if host.story_state.get_flag("novel_edition",0) != 1 or host.story_state.get_flag("novel_prologue_closed", false): return false
	if host.get_node_or_null("PaintedCrowMemory") != null: return true
	var memory = load("res://scripts/views/novel/painted_crow.gd").new()
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
	daylight = DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-52, -32, 0)
	daylight.shadow_enabled = true
	daylight.shadow_bias = 0.025
	daylight.shadow_normal_bias = 0.7
	daylight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	stage.add_child(daylight)

func _redraw() -> void:
	view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _show_frame() -> void:
	if is_instance_valid(setting):
		stage.remove_child(setting)
		setting.queue_free()
	token = null
	var shot: Dictionary = SHOTS[cursor]
	var scene := load(SCENERY + shot.setting + ".tscn") as PackedScene
	if scene != null:
		setting = scene.instantiate() as Node3D
		stage.add_child(setting)
		var camera: Camera3D = setting.get_node("Shot")
		camera.make_current()
		var seat: Marker3D = setting.get_node("TokenSeat")
		daylight.directional_shadow_max_distance = maxf(0.55, 2.5 * camera.global_position.distance_to(seat.global_position))
		daylight.light_color = shot.light
		daylight.light_energy = shot.energy
		_place_token(seat, shot.form)
	else:
		push_error("Missing prologue setting: " + shot.setting)
	title.text = CAPTIONS[cursor][0]
	subtitle.text = CAPTIONS[cursor][1]
	next.text = VERBS[cursor]
	_redraw()

func _place_token(seat: Marker3D, form: String) -> void:
	var path := CROW + form + ".tscn"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Missing prologue crow: " + path)
		return
	token = scene.instantiate() as Node3D
	seat.add_child(token)
	# The original mesh faces +Z. Lay its actual back on the authored seat.
	var body: MeshInstance3D = token.get_node("FoldedGreyCloth" if cursor == 3 else "Token")
	token.rotation.x = -PI / 2.0
	token.position.y = -(body.transform * body.get_aabb()).position.z
	if cursor < 2:
		token.get_node("RedCord").hide()

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
