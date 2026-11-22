extends SceneTree

const MaterialLibrary = preload("res://scripts/world_material_library.gd")
const OUTPUT_PATH := "res://Development_Gallery/screenshots/MAT_003_Unified_Surface_Library.png"
const SURFACES := [
	"forest_ground", "wet_mud", "cobblestone", "plaster", "timber", "roof_tiles", "medieval_brick",
	"water", "foliage", "metal", "blood", "ash", "emissive_window",
]

var failures := 0

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("MAT-003 capture requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Development_Gallery/screenshots"))
	var library = MaterialLibrary.new()
	root.add_child(library)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("0a1015")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("b9c3c8")
	world.ambient_light_energy = 0.72
	environment.environment = world
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -25.0, 0.0)
	key.light_color = Color("ffe4c1")
	key.light_energy = 1.35
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 3.5, 2.0)
	fill.light_color = Color("7893a8")
	fill.light_energy = 2.0
	fill.omni_range = 18.0
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.6, 14.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 42.0
	camera.current = true
	stage.add_child(camera)
	var title := Label.new()
	title.text = "MAT-003  |  UNIFIED WORLD SURFACE LIBRARY"
	title.position = Vector2(34, 24)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("e9dfc9"))
	root.add_child(title)
	for index in range(SURFACES.size()):
		var column := index % 5
		var row := index / 5
		var x := -5.0 + float(column) * 2.5
		var z := -1.0 + float(row) * 2.45
		var swatch := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.05, 1.22, 1.02)
		swatch.mesh = mesh
		swatch.position = Vector3(x, 1.05, z)
		swatch.material_override = library.get_material(str(SURFACES[index]), "quality", Color.WHITE, 0.38)
		stage.add_child(swatch)
		var label := Label3D.new()
		label.text = str(SURFACES[index]).replace("_", " ").to_upper()
		label.position = Vector3(x, 1.82, z - 0.02)
		label.font_size = 32
		label.modulate = Color("f0e6d2")
		label.outline_size = 6
		label.outline_modulate = Color("111820")
		stage.add_child(label)
	await _frames(3)
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1280, 720) or not _is_nonblank(image):
		failures += 1
	else:
		image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("MAT-003 CAPTURE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _is_nonblank(image: Image) -> bool:
	var changed := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var pixel := image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b > 0.12:
				changed += 1
				if changed >= 24:
					return true
	return false
