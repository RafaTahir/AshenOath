extends SceneTree

## Evaluate the compiled grip through the unmodified runtime owners. The paired
## stock actor removes its own supply metadata and follows the same full route.
const Spawn = preload("res://scripts/asset_spawn_helper.gd")
const Presentation = preload("res://scripts/character_presentation.gd")
const Modifier = preload("res://scripts/character_life_modifier.gd")
const Life = preload("res://scripts/greyfen_life_controller.gd")
const Cast = preload("res://scripts/story_cast_profile.gd")
const Builder = preload("res://scripts/zone_construction_host.gd")
const Spatial = preload("res://scripts/zone_spatial_service.gd")
const SOURCE := "res://assets_external/design_pack_v1/humans/C11_Nessa.glb"
const CATALOG := "res://data/prepared_actors.json"
const LIBRARY := "res://assets_external/characters_prepared/animations/life_C11.res"
const SCOPE := "greyfen:saga_nessa:baker_day:4:work_to_errand"
const STEP := 1.0 / 120.0
const SPEED := 0.62
const MAX_FRAMES := 4200

class FixtureHost extends Node:
	var CharacterAnimationDriver: Script = preload("res://scripts/character_animation_driver.gd")
	var zone_root: Node3D
	var scene_rng: RandomNumberGenerator
	var player: Node3D
	var quests: Node
	var day_night: Node
	var audio: Node
	var spatial: Node

	func validate_walkable_position(point: Vector3) -> Vector3:
		return spatial.validate_position(point)

var sandbox: Node
var failures: Array[String] = []
var trace: Array[Dictionary] = []
var compiled_placement: Dictionary = {}
var metrics := {
	"outbound_hidden_ramp": 0, "outbound_visible": 0, "carry_between_thresholds": 0,
	"errand_standing": 0, "return_stock": 0, "work_resumed": 0,
	"peak_speed_mps": 0.0, "braking": false, "max_anchor_error_m": 0.0, "max_wrist_solve_error_m": 0.0,
	"max_outbound_wrist_delta_m": 0.0, "max_standing_wrist_delta_m": 0.0
}
var previous_speed := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 or arguments[0] != "--out" or not arguments[1].is_absolute_path():
		printerr("C11 compiled carry route requires --out followed by an absolute receipt path")
		quit(1)
		return
	sandbox = Node.new()
	root.add_child(sandbox)
	var profile: Dictionary = Cast.routine("saga_nessa", "greyfen", null, null, "dusk", 1100.0)
	var path: Array = profile.get("path", [])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var prepared := str(catalog.get("saga_nessa|" + SOURCE, {}).get("path", ""))
	if not _is_original_profile(profile, path):
		failures.append("The original authored Nessa work-to-errand schedule is unavailable")
		_finish(arguments[1], path)
		return
	var actor := _create_actor(profile, path, prepared, false)
	var stock := _create_actor(profile, path, prepared, true)
	if actor.is_empty() or stock.is_empty():
		_finish(arguments[1], path)
		return
	for warmup: int in 3:
		await process_frame
	for frame: int in MAX_FRAMES:
		await process_frame
		if not _step(actor) or not _step(stock) or not _compare(frame, actor, stock):
			break
		if int(metrics.work_resumed) > 0:
			break
	for key: String in ["outbound_hidden_ramp", "outbound_visible", "carry_between_thresholds", "errand_standing", "return_stock", "work_resumed"]:
		if int(metrics[key]) == 0:
			failures.append("The route did not exercise " + key)
	if not bool(metrics.braking) or absf(float(metrics.peak_speed_mps) - SPEED) > 0.001:
		failures.append("The complete natural route did not reach and brake from 0.62 m/s")
	if minf(float(metrics.max_outbound_wrist_delta_m), float(metrics.max_standing_wrist_delta_m)) <= 0.001:
		failures.append("The compiled standing and moving goals did not affect the actual right wrist")
	_finish(arguments[1], path)

func _is_original_profile(profile: Dictionary, path: Array) -> bool:
	if path.size() != 2 or not bool(profile.get("scheduled", false)) or not bool(profile.get("carry_in_transit", false)) \
			or str(profile.get("intent_key", "")) != "baker_day:4" or str(profile.get("intent", "")) != "carry" \
			or str(profile.get("activity", "")) != "carry" or str(profile.get("prop", "")) != "supply" \
			or profile.get("activities", []) != ["carry", "carry"]:
		return false
	var authored: Dictionary = Cast.life_data()["zones"]["greyfen"]["saga_nessa"]
	for index: int in 2:
		var raw: Array = authored[["work", "errand"][index]]
		if path[index] != Vector3(float(raw[0]), float(raw[1]), float(raw[2])):
			return false
	return true

func _create_actor(profile: Dictionary, path: Array, prepared: String, stock: bool) -> Dictionary:
	var host := FixtureHost.new()
	sandbox.add_child(host)
	host.zone_root = Node3D.new()
	host.add_child(host.zone_root)
	host.spatial = Spatial.new()
	host.zone_root.add_child(host.spatial)
	host.player = Node3D.new()
	host.zone_root.add_child(host.player)
	var start: Vector3 = path[0]
	var destination: Vector3 = path[1]
	var heading := (destination - start).normalized()
	host.player.global_position = start.lerp(destination, 0.5) + heading.cross(Vector3.UP) * 5.0

	var builder := Builder.new()
	host.add_child(builder)
	builder.coordinator = host
	builder.context = ZoneBuildContext.new(host, "greyfen")
	var helper := Spawn.new()
	host.add_child(helper)
	var visual: Node3D = helper.spawn_visual_role("saga_nessa", "characters")
	if visual == null or prepared.is_empty() or visual.scene_file_path != prepared \
			or str(visual.get_meta("runtime_asset_path", "")) != SOURCE or bool(visual.get_meta("runtime_fallback_used", true)):
		if visual != null:
			visual.free()
		failures.append("The exact prepared C11 actor is unavailable")
		return {}
	var placement := Node3D.new()
	host.zone_root.add_child(placement)
	placement.global_position = start
	placement.add_child(visual)
	visual.set_meta("cast_viewer", host.player)
	Presentation.apply_npc(visual, "saga_nessa", false)
	if not builder._configure_npc_animation(visual, "saga_nessa"):
		failures.append("The real C11 animation driver failed to bind")
		return {}
	var driver: Node = visual.get_node("CharacterAnimationDriver")
	driver.set_external_tick(true)
	driver.reset_for_journey_restore()
	var skeleton: Skeleton3D = driver.skeleton
	var modifier: Modifier = driver.life_modifier
	if modifier == null or str(modifier.get_script().resource_path) != "res://scripts/character_life_modifier.gd" \
			or str(driver.life_library_path) != LIBRARY or skeleton.find_bone("hand_r") < 0:
		failures.append("The actual animation library, right hand or runtime modifier is unavailable")
		return {}
	for item: SkeletonModifier3D in visual.find_children("*", "SkeletonModifier3D", true, false):
		item.active = false

	var grips: Dictionary = driver.character_root.get_meta("activity_prop_grips", {})
	var grip: Dictionary = grips.get("supply", {})
	var goals: Dictionary = grip.get("wrist_goals", {})
	var standing: Vector2 = goals.get("standing", Vector2.INF)
	var moving: Vector2 = goals.get("moving", Vector2.INF)
	if not bool(grip.get("verified", false)) or str(grip.get("bone", "")) != "hand_r" \
			or str(grip.get("moving_route", "")) != SCOPE or goals.size() != 2 or not standing.is_finite() or not moving.is_finite() \
			or not standing.is_equal_approx(Vector2(0.075, 0.120)) or not moving.is_equal_approx(Vector2(0.087, 0.120)) \
			or not Presentation.grip_record_error(skeleton, grip).is_empty():
		failures.append("The bound compiled library did not carry the verified C11 scoped grip")
		return {}
	if stock:
		var stock_grips := grips.duplicate(true)
		stock_grips.erase("supply")
		driver.character_root.set_meta("activity_prop_grips", stock_grips)
	else:
		var orientation: Basis = grip.basis
		compiled_placement = {
			"bone": str(grip.bone), "source_sha256": str(grip.source_sha256),
			"palm": _vector(grip.palm), "anchor": _vector(grip.anchor),
			"basis_columns": [_vector(orientation.x), _vector(orientation.y), _vector(orientation.z)]
		}

	# Only the paired random clock is fixed. The actual animation, solver and
	# scheduler advance naturally, including both work dwells and every step.
	modifier.idle_rng.seed = 11001101
	modifier.next_shift = modifier.elapsed + modifier.idle_rng.randf_range(6.0, 10.0)
	var life := Life.new()
	host.add_child(life)
	life.set_process(false)
	life.set_physics_process(false)
	life.host = host
	life.player = host.player
	life.spatial_service = host.spatial
	life.rng.seed = 44017
	var entry: Dictionary = life._make_entry("saga_nessa", placement, path.duplicate(), SPEED, driver, true)
	entry.regional = true
	entry.routine_zone = "greyfen"
	entry.profile = profile.duplicate(true)
	entry.target = 0
	entry.pause = 0.0
	life._face(placement, start - heading, TAU, true)
	return {"life": life, "entry": entry, "driver": driver, "modifier": modifier, "skeleton": skeleton, "grip": grip}

func _step(actor: Dictionary) -> bool:
	var driver: Node = actor.driver
	var modifier: Modifier = actor.modifier
	var delta := modifier.get_process_delta_time()
	if absf(delta - STEP) > 0.000001:
		failures.append("Expected the engine's fixed 120 Hz process delta")
		return false
	actor.life._update_actor(actor.entry, delta)
	var placement: Node3D = actor.entry.node
	var transform_before := placement.global_transform
	actor.skeleton.reset_bone_poses()
	driver.advance_external(delta)
	modifier._process_modification()
	if placement.global_transform != transform_before:
		failures.append("The animation or grip modified the scheduler-owned root")
		return false
	return true

func _compare(frame: int, actor: Dictionary, stock: Dictionary) -> bool:
	var entry: Dictionary = actor.entry
	var control: Dictionary = stock.entry
	var placement: Node3D = entry.node
	var control_placement: Node3D = control.node
	var driver: Node = actor.driver
	var modifier: Node = actor.modifier
	var control_modifier: Node = stock.modifier
	var speed: float = driver.current_speed_mps
	var position := placement.global_position
	var expected_arrival: int = int(entry.get("arrived_target", -1))
	for key: String in ["target", "arrived_target", "route_index", "route", "motion_speed", "travel_direction", "pause", "activity_cycles", "activity_active"]:
		if entry.get(key) != control.get(key):
			return _reject(frame, "The grip changed the paired scheduler field " + key)
	if placement.global_transform != control_placement.global_transform or speed != float(stock.driver.current_speed_mps):
		return _reject(frame, "The grip changed the paired root trajectory or achieved speed")
	if not position.is_finite() or not is_finite(speed) or speed > SPEED + 0.001:
		return _reject(frame, "The route produced invalid or accelerated root movement")
	if bool(entry.activity_active) and (expected_arrival < 0 or position.distance_to(entry.path[expected_arrival]) > 0.081):
		return _reject(frame, "The work or errand arrival missed its authored anchor")

	var carried: bool = str(modifier.carried_activity) == "carry" and str(modifier.activity).is_empty()
	var outbound: bool = carried and expected_arrival == 0 and int(entry.target) == 1
	var returning: bool = carried and expected_arrival == 1 and int(entry.target) == 0
	var scope: String = driver.carried_activity_scope
	var mode: String = driver.activity_grip_pose_mode("carry", "supply", SCOPE)
	var tool: BoneAttachment3D = modifier.tool
	var control_tool: BoneAttachment3D = control_modifier.tool
	var visible := is_instance_valid(tool) and tool.is_visible_in_tree()
	var measured := is_instance_valid(tool) and tool.has_meta("measured_grip")
	var weight: float = modifier.pose_weight
	var settled := is_equal_approx(weight, 1.0)
	trace.append({
		"frame": frame, "position": _vector(position), "yaw": placement.rotation.y, "speed_mps": speed,
		"target": int(entry.target), "arrived_target": expected_arrival, "activity": str(modifier.activity),
		"scope": scope, "mode": mode, "carried": carried, "measured": measured, "visible": visible, "pose_weight": weight
	})
	if not scope.is_empty() and (scope != SCOPE or not outbound or speed <= 0.05):
		return _reject(frame, "The scoped grip escaped the qualified outbound leg")
	if outbound and speed > 0.05:
		if scope != SCOPE:
			return _reject(frame, "The qualified outbound carry did not receive its scoped grip token")
		if speed <= 0.08:
			metrics.carry_between_thresholds += 1
		if not settled:
			metrics.outbound_hidden_ramp += 1
			if visible:
				return _reject(frame, "The outbound supply was visible before the owning pose settled")
		if visible:
			if not measured or mode != "moving":
				return _reject(frame, "The outbound supply did not use the compiled moving grip")
			metrics.outbound_visible += 1
			metrics.max_outbound_wrist_delta_m = maxf(float(metrics.max_outbound_wrist_delta_m), _wrist(actor).distance_to(_wrist(stock)))
		if float(metrics.peak_speed_mps) >= SPEED - 0.001 and speed < previous_speed - 0.001:
			metrics.braking = true
		metrics.peak_speed_mps = maxf(float(metrics.peak_speed_mps), speed)
	if returning:
		if not scope.is_empty() or not mode.is_empty() or measured:
			return _reject(frame, "The unscoped return did not fall back to the stock socket")
		if visible:
			if not is_instance_valid(control_tool) or not control_tool.is_visible_in_tree() or control_tool.has_meta("measured_grip"):
				return _reject(frame, "The stock comparison did not render its ordinary supply socket")
			tool.on_skeleton_update()
			control_tool.on_skeleton_update()
			if not tool.transform.is_equal_approx(control_tool.transform) or _wrist(actor).distance_to(_wrist(stock)) > 0.00001:
				return _reject(frame, "The unscoped return differed from the stock grip and wrist")
			metrics.return_stock += 1
	if visible and (str(tool.bone_name) != "hand_r" or str(modifier.tool_kind) != "supply"):
		return _reject(frame, "A visible supply lost the actual right-hand socket")
	if measured and visible:
		if not settled or tool.get_meta("measured_grip") != actor.grip:
			return _reject(frame, "The fitted socket exposed a partial pose or the wrong compiled record")
		var solved_goal: Vector3 = modifier.solved_wrist_goal
		var wrist_error := _wrist(actor).distance_to(solved_goal)
		if not solved_goal.is_finite() or not is_finite(wrist_error) or wrist_error > 0.001:
			return _reject(frame, "The exposed grip did not reach the actual solver endpoint")
		metrics.max_wrist_solve_error_m = maxf(float(metrics.max_wrist_solve_error_m), wrist_error)
		var error := _anchor_error(actor, tool)
		if not is_finite(error) or error > 0.001:
			return _reject(frame, "The actual fitted prop missed its measured palm anchor")
		metrics.max_anchor_error_m = maxf(float(metrics.max_anchor_error_m), error)
	if bool(entry.activity_active) and measured and visible:
		if not is_zero_approx(speed) or not scope.is_empty() or mode != "standing":
			return _reject(frame, "The arrived activity did not resume with the compiled standing grip")
		metrics.max_standing_wrist_delta_m = maxf(float(metrics.max_standing_wrist_delta_m), _wrist(actor).distance_to(_wrist(stock)))
		if expected_arrival == 1:
			metrics.errand_standing += 1
		elif int(entry.activity_cycles) >= 3:
			metrics.work_resumed += 1
	previous_speed = speed
	return true

func _wrist(actor: Dictionary) -> Vector3:
	var skeleton: Skeleton3D = actor.skeleton
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))).origin

func _anchor_error(actor: Dictionary, tool: BoneAttachment3D) -> float:
	var grip: Node3D = tool.get_child(0) as Node3D if tool.get_child_count() == 1 else null
	if grip == null or grip.get_child_count() != 1 or not grip.get_child(0) is MeshInstance3D:
		return INF
	var mesh := grip.get_child(0) as MeshInstance3D
	tool.on_skeleton_update()
	var skeleton: Skeleton3D = actor.skeleton
	var record: Dictionary = actor.grip
	var palm: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(tool.bone_idx) * record.palm
	var anchor: Vector3 = mesh.global_transform * record.anchor
	return palm.distance_to(anchor)

func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _reject(frame: int, failure: String) -> bool:
	failures.append("Frame %d. %s" % [frame, failure])
	return false

func _finish(output: String, path: Array) -> void:
	var anchors: Array = []
	for point: Vector3 in path:
		anchors.append(_vector(point))
	var result := {
		"passed": failures.is_empty(), "runtime_fixture_only": true, "visual_accepted": false,
		"scope": SCOPE, "runtime_library_sha256": FileAccess.get_sha256(LIBRARY),
		"compiled_placement": compiled_placement, "anchors": anchors,
		"metrics": metrics, "trace": trace, "failures": failures
	}
	sandbox.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("C11 compiled carry route could not save its receipt")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	for failure: String in failures:
		printerr("C11 COMPILED CARRY ROUTE: " + failure)
	print("C11 COMPILED CARRY ROUTE: %s frames=%d" % ["PASS" if failures.is_empty() else "FAIL", trace.size()])
	quit(0 if failures.is_empty() else 1)

