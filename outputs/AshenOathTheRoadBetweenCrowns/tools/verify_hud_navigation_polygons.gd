extends SceneTree
## Uses the real dial/circle and actual CanvasItem drawing. The narrow slivers
## below are clipping output with >=3 points but no valid triangle indices.
const Dial = preload("res://scripts/hud_navigation_dial.gd")
class Errors extends Logger:
	var messages: Array[String] = []
	func _log_error(_function: String,file: String,line: int,code: String,rationale: String,
			_editor_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type!=Logger.ERROR_TYPE_WARNING: messages.append("%s:%d %s %s"%[file,line,code,rationale])
var errors := Errors.new()
var output := ""

func _initialize() -> void:
	OS.add_logger(errors)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("_run")

func _rect(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(left,top),Vector2(right,top),Vector2(right,bottom),Vector2(left,bottom)])

func _run() -> void:
	var dial := Dial.new()
	dial.size = Vector2(170,170)
	root.add_child(dial)
	var center := Vector2(85,85)
	var radius := 73.0
	var factor := radius/22.0
	var circle: PackedVector2Array = dial._circle_polygon(center,radius)
	var terrain: Array[Dictionary] = [{"kind":"ground","points":_rect(-30,-30,30,30)}]
	var degenerate: Array[Dictionary] = []
	for epsilon: float in [0.00001,0.00003,0.00005,0.0001,0.0003,0.001,0.003]:
		var points := _rect(22.0-epsilon/factor,-30,24,30)
		terrain.append({"kind":"obstacle","points":points})
		var projected := PackedVector2Array()
		for point: Vector2 in points: projected.append(center+point*factor)
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(projected,circle):
			if clipped.size()>=3 and Geometry2D.triangulate_polygon(clipped).is_empty():
				var recorded: Array = []
				for point: Vector2 in clipped: recorded.append([point.x,point.y])
				degenerate.append({"epsilon":epsilon,"points":recorded})
	var normal_valid := not Geometry2D.triangulate_polygon(circle).is_empty()
	var collinear_has_indices := not Geometry2D.triangulate_polygon(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(2,0)])).is_empty()
	var draw_count := [0]
	dial._background.draw.connect(func() -> void: draw_count[0]+=1)
	dial.set_snapshot({"player_xz":Vector2.ZERO,"radius_m":22.0,"terrain":terrain,"markers":[],"player_forward":Vector2.UP})
	for index in 3:
		dial._background.queue_redraw()
		await process_frame
	var iterations := 2000
	var began := Time.get_ticks_usec()
	for index in iterations: Geometry2D.triangulate_polygon(circle)
	var added_check_usec := float(Time.get_ticks_usec()-began)/iterations
	dial.queue_free()
	await process_frame
	var passed: bool = normal_valid and not degenerate.is_empty() and int(draw_count[0])>0 and errors.messages.is_empty()
	var report := {"kind":"hud_navigation_polygon_regression","passed":passed,"normal_circle_valid":normal_valid,
		"collinear_helper_returns_indices":collinear_has_indices,"actual_degenerate_clipped_polygons":degenerate,"actual_background_draws":draw_count[0],
		"engine_errors":errors.messages,"extra_triangulation_usec_per64vertex_polygon":added_check_usec,
		"cost_scope":"Headless math micro-observation only; extra test runs only in the existing invalidated background-polygon loop; not a frame-time benchmark."}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report))
	quit(0 if passed else 1)
