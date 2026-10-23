extends Control

var hud: CanvasLayer
var state: Dictionary = {}
var point := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	var owner: Node = hud._game_owner if is_instance_valid(hud) else null
	var player: Node3D = owner.get("player") if is_instance_valid(owner) else null
	visible = is_instance_valid(player) and not get_tree().paused and not hud._gameplay_surface_blocked() and player.is_bow_pose_active() and player.bow_aiming
	if not visible: return
	state = player.bow_aim_solution
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var target: Vector3 = state.get("point", camera.global_position - camera.global_basis.z * 10.0)
	visible = not camera.is_position_behind(target)
	point = camera.unproject_position(target) if bool(state.get("blocked", false)) or bool(state.get("obstructed", false)) else get_viewport_rect().size * 0.5
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var draw: float = float(state.get("draw", 0.0))
	var blocked: bool = bool(state.get("blocked", false))
	var empty: bool = not bool(state.get("ammo", false))
	var colour := Color(0.95, 0.89, 0.73, 0.95)
	if empty or blocked: colour = Color(1.0, 0.40, 0.27)
	elif draw >= 0.99: colour = Color(1.0, 0.78, 0.36)
	var radius := lerpf(14.0, 5.0, draw)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(point + direction * radius, point + direction * (radius + 4.0), colour, 1.5, true)
	draw_circle(point, 1.3, colour)
	if draw > 0.0: draw_arc(point, 22.0, -PI * 0.5, -PI * 0.5 + TAU * draw, 40, colour, 1.5, true)
	if empty or blocked:
		draw_line(point + Vector2(-4, -4), point + Vector2(4, 4), colour, 1.5, true)
		draw_line(point + Vector2(-4, 4), point + Vector2(4, -4), colour, 1.5, true)
