extends SceneTree

const Cemetery = preload("res://scripts/zones/cemetery_section.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.current_zone_id = "greyfen"
	game.zone_root = Node3D.new()
	game.add_child(game.zone_root)
	var context := ZoneBuildContext.new(game, "greyfen")
	var builder := Cemetery.new()
	var origin := Vector3(14, 0, 8.6)
	builder.build_stage(context, origin, "approach", true)
	var section: Node = game.zone_root.find_child("GreyfenCemeterySection", true, false)
	var passed := section != null and not bool(section.get_meta("cemetery_build_complete", false))
	builder.build(context, origin, true)
	passed = passed and bool(section.get_meta("presentation_compact", false))
	builder.build(context, origin, false)
	passed = passed and bool(section.get_meta("cemetery_build_complete", false))
	passed = passed and not bool(section.get_meta("presentation_compact", true))
	for stage in Cemetery.BUILD_STAGES:
		passed = passed and bool(section.get_meta("built_" + stage, false))
	var operations := context.operation_count
	var children: int = game.zone_root.get_child_count()
	builder.build(context, origin, false)
	passed = passed and context.operation_count == operations and game.zone_root.get_child_count() == children
	game._make_greyfen_first_impression_dressing("ruts")
	var impression: Node = game.zone_root.find_child("GreyfenFirstImpressionDressing", true, false)
	passed = passed and not bool(impression.get_meta("first_impression_complete", false))
	game._make_greyfen_first_impression_dressing()
	passed = passed and bool(impression.get_meta("first_impression_complete", false))
	children = game.zone_root.get_child_count()
	game._make_greyfen_first_impression_dressing()
	passed = passed and game.zone_root.get_child_count() == children
	game.prepare_resource_shutdown()
	for frame in 20:
		await process_frame
	game.queue_free()
	for frame in 8:
		await process_frame
	print("CEMETERY STAGES: %s - partial, compact upgrade, full and idempotent construction" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
