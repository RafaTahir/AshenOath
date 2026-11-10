extends SceneTree

## Compare station-free supply aliases through the same actor and routine owners.
## The candidate bias applies only in this disposable authoring fixture.
const Spawn = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Builder = preload("res://scripts/zone_construction_host.gd")
const Trial = preload("c11_supply_forward_trial_modifier.gd")
const SOURCE := "res://assets_external/design_pack_v1/humans/C11_Nessa.glb"
const CATALOG := "res://data/prepared_actors.json"
const HZ := 120.0

class FixtureHost extends Node:
	var CharacterAnimationDriver: Script = preload("res://scripts/character_animation_driver.gd")
	var zone_root: Node3D
	var scene_rng: RandomNumberGenerator

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var prepared := str(catalog.get("saga_nessa|" + SOURCE, {}).get("path", ""))
	var host := FixtureHost.new()
	root.add_child(host)
	host.zone_root = Node3D.new()
	host.add_child(host.zone_root)
	var builder := Builder.new()
	host.add_child(builder)
	builder.coordinator = host
	builder.context = ZoneBuildContext.new(host, "greyfen")
	var helper := Spawn.new()
	host.add_child(helper)
	var life := Life.new()
	host.add_child(life)
	life.set_process(false)
	life.set_physics_process(false)
	var variants: Array[Dictionary] = []
	for kind: String in ["carry", "check_supplies", "sort_supplies"]:
		for style: String in ["supply", ""]:
			var entry := _make_entry(builder, helper, life, prepared, kind, style)
			if entry.is_empty():
				_finish(host, 0)
				return
			variants.append(entry)
	var baseline: Node = variants[0].driver
	var source_player: AnimationPlayer = baseline.animation_player
	var idle_seconds: float = source_player.get_animation(baseline.get_clip_for_state("idle")).length
	var frames := ceili(idle_seconds * HZ) + 1
	if frames != 301:
		failures.append("Actual runtime Idle cycle differs from the retained carrier")
		_finish(host, 0)
		return
	var previous_time := 0.0
	for index: int in frames:
		var at := minf(float(index) / HZ, idle_seconds)
		for entry: Dictionary in variants:
			if not _sample(entry, at, at - previous_time):
				_finish(host, index)
				return
		var reference_skeleton: Skeleton3D = baseline.skeleton
		for entry: Dictionary in variants.slice(1):
			var compared_driver: Node = entry.driver
			var compared: Skeleton3D = compared_driver.skeleton
			for bone: int in reference_skeleton.get_bone_count():
				if reference_skeleton.get_bone_pose(bone) != compared.get_bone_pose(bone):
					failures.append("%s/%s differs from Carry at frame %d bone %s" % [entry.profile.activity, entry.profile.prop, index, reference_skeleton.get_bone_name(bone)])
					_finish(host, index)
					return
		previous_time = at
	_finish(host, frames)

func _make_entry(builder: Node, helper: Node, life: Node, prepared: String, kind: String, style: String) -> Dictionary:
	var actor: Node3D = helper.spawn_visual_role("saga_nessa", "characters")
	if actor == null or prepared.is_empty() or actor.scene_file_path != prepared or str(actor.get_meta("runtime_asset_path", "")) != SOURCE or bool(actor.get_meta("runtime_fallback_used", true)):
		if actor != null: actor.free()
		failures.append("Exact prepared Nessa actor is unavailable")
		return {}
	builder.zone_root.add_child(actor)
	Presentation.apply_npc(actor, "saga_nessa", false)
	if not builder._configure_npc_animation(actor, "saga_nessa"):
		failures.append("Runtime Nessa driver could not bind")
		return {}
	var driver: Node = actor.get_node("CharacterAnimationDriver")
	driver.set_external_tick(true)
	var skeleton: Skeleton3D = driver.skeleton
	var original: Node = driver.life_modifier
	if not is_instance_valid(original) or str(original.get_script().resource_path) != "res://scripts/character_life_modifier.gd":
		failures.append("The retained life modifier is missing")
		return {}
	driver.life_modifier = null
	original.free()
	var trial := Trial.new()
	trial.name = "CharacterLifePose"
	skeleton.add_child(trial)
	trial.configure(driver.character_root, driver)
	driver.life_modifier = trial
	for modifier: SkeletonModifier3D in actor.find_children("*", "SkeletonModifier3D", true, false):
		modifier.active = false
	driver.reset_for_journey_restore()
	var entry: Dictionary = life._make_entry("saga_nessa", actor, [Vector3.ZERO], 0.62, driver, true)
	entry.profile = {"activity":kind, "prop":style, "workstation":{}}
	life._set_activity_pose(entry, true)
	for tick: int in 60: driver.advance_external(1.0 / HZ)
	var graph: RefCounted = driver.animation_graph
	if not driver.activity_prop_pose_ready() or driver.life_clip != StringName() or str(graph.playback.get_current_node()) != "locomotion" or not str(graph.playback.get_fading_from_node()).is_empty():
		failures.append("Supply alias did not settle into the expected station-free Idle graph: " + kind)
		return {}
	graph.playback.start("locomotion", true)
	graph.gait_phase = 0.0
	trial.pose_weight = 1.0
	trial.ambient_weight = 1.0
	return entry

func _sample(entry: Dictionary, at: float, delta: float) -> bool:
	var driver: Node = entry.driver
	var skeleton: Skeleton3D = driver.skeleton
	var modifier: Node = driver.life_modifier
	var previous_applications: int = int(modifier.trial_applications)
	skeleton.reset_bone_poses()
	driver.advance_external(delta)
	modifier.elapsed = at - minf(float(modifier.get_process_delta_time()), 0.05)
	modifier._process_modification()
	var tool: BoneAttachment3D = modifier.tool
	if absf(float(modifier.elapsed) - at) > 0.000001 or int(modifier.trial_applications) != previous_applications + 1 or not modifier.trial_failures.is_empty():
		failures.append("Owning-arm trial did not preserve the native clock and rig")
		return false
	if not is_instance_valid(tool) or not tool.is_visible_in_tree() or str(tool.bone_name) != "hand_r" or str(modifier.tool_kind) != "supply":
		failures.append("Alias failed to render the actual supply in the owning hand")
		return false
	return true

func _finish(host: Node, frames: int) -> void:
	host.free()
	for failure: String in failures: printerr("C11 SUPPLY ALIAS: " + failure)
	print("C11 SUPPLY ALIAS: %s samples=%d variants=6" % ["PASS" if failures.is_empty() else "FAIL", frames])
	quit(0 if failures.is_empty() else 1)
