extends CanvasLayer

signal finished
var pivot: Node3D
var drag := false
var scroll: ScrollContainer
var viewport: SubViewport
var host
var root: Control

func open(game, definition: Dictionary) -> bool:
	host = game
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	var scene := load("res://assets/everyday/" + str(definition.asset) + ".glb") as PackedScene
	if scene == null: return false
	root = ColorRect.new()
	root.color = Color(0.035, 0.044, 0.041, 0.98)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = 12
	box.offset_bottom = -12
	root.add_child(box)
	var heading := Label.new()
	heading.text = str(definition.title)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size.y = 100
	container.gui_input.connect(_orbit)
	box.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	var object := scene.instantiate() as Node3D
	pivot.add_child(object)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0.12, 0.7)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.8
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 65
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.35
	box.add_child(scroll)
	var text := Label.new()
	text.text = str(definition.text)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	for choice in [["Left", -0.4], ["Right", 0.4], ["Turn over", PI], ["Return", 0.0]]:
		var button := Button.new()
		button.text = str(choice[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = touch_height()
		controls.add_child(button)
		if str(choice[0]) == "Return":
			button.pressed.connect(close)
			button.grab_focus()
		else:
			button.pressed.connect(func():
				pivot.rotate_y(float(choice[1]))
				viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	host.get_tree().paused = true
	host.audio.set_game_paused(true)
	return true

func touch_height() -> float:
	var display: Dictionary = host.hud.get("_display_metrics") if host.hud.get("_display_metrics") is Dictionary else {}
	var layout: Dictionary = preload("res://scripts/hud_layout_policy.gd").resolve(get_viewport().get_visible_rect().size, display, 1.0, "touch" if bool(display.get("coarse_pointer", false)) else "keyboard")
	return maxf(48.0, float(layout.button_min_height))

func _orbit(event: InputEvent) -> void:
	if event is InputEventMouseButton: drag = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventMouseMotion and drag: _rotate(event.relative)
	if event is InputEventScreenDrag: _rotate(event.relative)

func _rotate(amount: Vector2) -> void:
	pivot.rotate_y(amount.x * 0.009)
	pivot.rotation.x = clampf(pivot.rotation.x + amount.y * 0.009, -1.5, 1.5)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	finished.emit()
	queue_free()
