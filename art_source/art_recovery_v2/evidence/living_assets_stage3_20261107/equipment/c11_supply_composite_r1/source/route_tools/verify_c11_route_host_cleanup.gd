extends SceneTree

const Route = preload("export_c11_supply_scheduler_route_trial.gd")
const Life = preload("res://scripts/greyfen_life_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Route.RouteHost.new()
	root.add_child(host)
	host.player = Node3D.new()
	host.add_child(host.player)
	var life := Life.new()
	host.add_child(life)
	life.set_process(false)
	life.set_physics_process(false)
	life.host = host
	life.player = host.player
	host.free()
	print("C11 ROUTE HOST CLEANUP: PASS")
	quit(0)
