extends SceneTree

## Small actual-renderer proof, not game or asset acceptance. Never focuses,
## moves or manipulates a desktop window; the launcher owns its private desktop.
class InputProbe extends Node:
	var events := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.physical_keycode == KEY_G: events += 1

var options := {}
var failures: Array[String] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var parts := argument.substr(2).split("=",true,1)
			options[parts[0]] = parts[1]
	call_deferred("_run")

func _run() -> void:
	var output := str(options.get("output",""))
	var size := Vector2i(960,540) if str(options.get("viewport","desktop"))=="touch" else Vector2i(1280,720)
	if output=="" or DisplayServer.get_name().to_lower()=="headless" \
			or not OS.get_environment("ASHENOATH_CAPTURE_DESKTOP").begins_with("AshenOathCapture_") \
			or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS):
		push_error("Background rendering probe requires the isolated native launcher")
		quit(1)
		return
	root.size = size
	Engine.max_fps = 30
	var world := Node3D.new()
	root.add_child(world)
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1,0.85,0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material_override = material
	world.add_child(cube)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,0,3)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var input_probe := InputProbe.new()
	root.add_child(input_probe)
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_G
		event.keycode = KEY_G
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	if first.get_size()!=size: failures.append("viewport dimensions differ")
	var center := first.get_pixel(size.x >> 1,size.y >> 1)
	if center.g<0.5 or center.b<0.4: failures.append("3D cube was not visibly rendered")
	if first.save_png(output.path_join("frame_a.png"))!=OK: failures.append("first frame could not be saved")
	cube.rotation = Vector3(0.2,0.65,0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	if first.get_data()==second.get_data(): failures.append("animated 3D frames are identical")
	if second.save_png(output.path_join("frame_b.png"))!=OK: failures.append("second frame could not be saved")
	if input_probe.events!=2: failures.append("internal key press/release did not reach the input owner")
	var file := FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"pass" if failures.is_empty() else "fail", "failures":failures,
		"desktop":OS.get_environment("ASHENOATH_CAPTURE_DESKTOP"),"no_focus":true,"headless":false,
		"renderer":RenderingServer.get_current_rendering_method(),"viewport":[size.x,size.y],
		"internal_input_events":input_probe.events,"asset_acceptance":false,"gameplay_acceptance":false},"\t"))
	file.close()
	world.free()
	input_probe.free()
	print("BACKGROUND RENDERING: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
