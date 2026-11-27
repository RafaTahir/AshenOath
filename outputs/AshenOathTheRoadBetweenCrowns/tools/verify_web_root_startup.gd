extends SceneTree

## Load the real entry point with only the exported Web root mounted.
func _initialize() -> void:
	var entry := load("res://scripts/game.gd") as Script
	if entry == null or not entry.can_instantiate():
		push_error("Web root cannot compile game.gd before supplemental packs mount")
		quit(1)
		return
	print("WEB ROOT STARTUP SCRIPT: PASS")
	quit()
