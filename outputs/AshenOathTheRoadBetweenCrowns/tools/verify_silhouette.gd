extends SceneTree

## User-run, isolated graphical silhouette check. Never starts a journey or
## reads/writes a save. Fixed perspective, scale and camera: no auto-crop cheat.
const Helper = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const RoleSpec = preload("res://scripts/character_role_spec.gd")
const ROLES := {
	"blacksmith":"blacksmith_tor",
	"ranger":"road_ranger_human",
	"cleric":"sister_anwen_human",
	"guard":"castle_guard_human",
}
const VIEWS := {"front":0.0, "three_quarter":45.0, "side":90.0, "back":180.0}
const FRAME := Vector2i(1280, 720)
const DISTANCE_M := 20.0
const MIN_DIFFERENCE := 0.12
var output := "D:/Temp/AshenOath/silhouette"
var failures: Array[String] = []
var masks: Dictionary = {}
var report := {"scope":"alpha-shape discrimination, not subjective art or animation acceptance", "distance_m":DISTANCE_M, "resolution":[1280,720], "fov":55.0, "minimum_xor_over_union":MIN_DIFFERENCE, "roles":{}, "comparisons":[]}
var helper: Node
var viewport: SubViewport

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
	if DisplayServer.get_name() == "headless":
		push_error("Use a graphical Compatibility renderer; a headless mask cannot prove appearance.")
		quit(1)
		return
	call_deferred("_capture")
	create_timer(180.0).timeout.connect(func(): push_error("Silhouette capture timed out"); quit(1))

func _capture() -> void:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create silhouette output: " + output)
		quit(1)
		return
	helper = Helper.new()
	root.add_child(helper)
	viewport = SubViewport.new()
	viewport.size = FRAME
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 55.0
	viewport.add_child(camera)
	camera.position = Vector3(0, 1.05, -DISTANCE_M)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.make_current()
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	for family: String in ROLES:
		var role := str(ROLES[family])
		var body: Node3D = helper.spawn_visual_role(role, "characters", role)
		if body == null:
			_fail("Missing required role: " + role)
			continue
		viewport.add_child(body)
		Presentation.apply_npc(body, role, false)
		# Compare an identical sampled idle time, not random animation phases.
		for raw in body.find_children("*", "AnimationPlayer", true, false):
			var player := raw as AnimationPlayer
			var selected := ""
			for clip: String in player.get_animation_list():
				if clip.to_lower().get_slice("/", clip.get_slice_count("/") - 1) == "idle":
					selected = clip
					break
			if selected != "":
				player.play(selected)
				player.advance(0.0)
				player.pause()
			else:
				_fail("Missing comparable idle pose: " + role)
		for raw in body.find_children("*", "MeshInstance3D", true, false):
			var mesh := raw as MeshInstance3D
			if str(mesh.name).to_lower().contains("shadow"):
				mesh.visible = false
				continue
			mesh.material_override = black
		var contract: Dictionary = body.get_meta("character_silhouette", {})
		if str(contract.get("archetype", "")) != family:
			_fail("Role used wrong silhouette: " + role)
		var required: Array = {"blacksmith":["apron_bib","apron_skirt","smith_tool"], "guard":["helmet","pauldron_left","pauldron_right"]}.get(family, [])
		for layer: String in required:
			if layer not in contract.get("layers_attached", []):
				_fail("Missing required shape: %s / %s" % [family,layer])
		report.roles[family] = {"role":role, "contract":contract, "captures":{}}
		masks[family] = {}
		for view: String in VIEWS:
			# The visual's source-facing correction remains intact.
			body.rotation_degrees.y = RoleSpec.facing_degrees(role) + float(VIEWS[view])
			await process_frame
			await RenderingServer.frame_post_draw
			var source := viewport.get_texture().get_image()
			if source == null:
				_fail("Renderer returned no mask image: %s / %s" % [family, view])
				source = Image.create(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
			source.convert(Image.FORMAT_RGBA8)
			var input := source.get_data()
			var data := PackedByteArray()
			data.resize(FRAME.x * FRAME.y * 4)
			var pixels := 0
			for index in range(3, input.size(), 4):
				if input[index] >= 128:
					data[index] = 255
					pixels += 1
			var mask := Image.create_from_data(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8, data)
			if pixels < 150:
				_fail("Blank/culled silhouette: %s / %s (%d pixels)" % [family,view,pixels])
			if _touches_edge(mask):
				_fail("Clipped silhouette: %s / %s" % [family,view])
			var path := output.path_join(family + "_" + view + "_20m.png")
			if mask.save_png(path) != OK:
				_fail("Cannot save mask: " + path)
			masks[family][view] = mask
			report.roles[family].captures[view] = {"path":path,"sha256":FileAccess.get_sha256(path),"opaque_pixels":pixels}
		body.free()
	var names := masks.keys()
	for a in names.size():
		for b in range(a+1,names.size()):
			var differentiated := 0
			var distinct_axes := 0
			var thresholds := {"shoulder_width":0.08,"head_scale":0.08,"torso_length":0.08,"hunch":6.0}
			for axis: String in thresholds:
				if absf(float(report.roles[names[a]].contract[axis]) - float(report.roles[names[b]].contract[axis])) + 0.00001 >= float(thresholds[axis]):
					distinct_axes += 1
			if distinct_axes < 2:
				_fail("Roles differ on fewer than two proportion axes: %s / %s" % [names[a],names[b]])
			var measurements := {}
			for view: String in VIEWS:
				var difference := _difference(masks[names[a]][view], masks[names[b]][view])
				measurements[view] = difference
				if difference >= MIN_DIFFERENCE:
					differentiated += 1
			if differentiated < 2:
				_fail("Roles differ in fewer than two views: %s / %s" % [names[a],names[b]])
			report.comparisons.append({"a":names[a],"b":names[b],"xor_over_union":measurements,"differentiated_views":differentiated,"distinct_proportion_axes":distinct_axes})
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file == null:
		_fail("Cannot save silhouette report")
	else:
		file.store_string(JSON.stringify(report,"\t") + "\n")
		file.close()
	helper.clear_runtime_caches()
	viewport.free()
	helper.free()
	print("SILHOUETTE: %s; %s" % ["PASS" if failures.is_empty() else "FAIL",output])
	quit(0 if failures.is_empty() else 1)

func _difference(a: Image, b: Image) -> float:
	var union := 0
	var different := 0
	var left_data := a.get_data()
	var right_data := b.get_data()
	for index in range(3, left_data.size(), 4):
		var left := left_data[index] >= 128
		var right := right_data[index] >= 128
		if left or right:
			union += 1
		if left != right:
			different += 1
	return float(different) / maxf(union,1)

func _touches_edge(mask: Image) -> bool:
	for x in FRAME.x:
		if mask.get_pixel(x,0).a > 0.5 or mask.get_pixel(x,FRAME.y-1).a > 0.5:
			return true
	for y in FRAME.y:
		if mask.get_pixel(0,y).a > 0.5 or mask.get_pixel(FRAME.x-1,y).a > 0.5:
			return true
	return false

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
