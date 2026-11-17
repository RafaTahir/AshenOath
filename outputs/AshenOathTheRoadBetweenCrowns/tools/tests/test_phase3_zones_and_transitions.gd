extends SceneTree
## Real construction helpers and lifetime integration, not a campaign/art acceptance run.
const Scope = preload("res://scripts/core/zone_instance_scope.gd")
const Context = preload("res://scripts/zone_build_context.gd")
const Transition = preload("res://scripts/models/world_transition_model.gd")
const Router = preload("res://scripts/zone_composition_router.gd")
const Surface = preload("res://scripts/spatial_surface_contract.gd")
const Bridge = preload("res://scripts/bridge_surface_contract.gd")
const Facade = preload("res://scripts/zone_construction_host.gd")
const Opening = preload("res://scripts/systems/opening_startup_service.gd")
const Lifecycle = preload("res://scripts/systems/zone_lifecycle_service.gd")
const Seamless = preload("res://scripts/seamless_world_service.gd")

class Presentation extends RefCounted:
	static func apply(_area: Node3D, _id: String) -> bool:
		return false

class Story extends RefCounted:
	var flags: Dictionary = {}
	func get_flag(key: String, fallback: Variant = null) -> Variant:
		return flags.get(key, fallback)
	func set_flag(key: String, value: Variant) -> void:
		flags[key] = value

class Settings extends RefCounted:
	var settings: Dictionary = {"quality_preset": "balanced", "potato_mode": false}

class Materials extends RefCounted:
	func get_material(_id: String, _quality: String, color: Color, _wetness: float, _triplanar: bool) -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		return material
	func make_tiled_box(size: Vector3, origin: Vector3) -> ArrayMesh:
		return preload("res://scripts/world_material_library.gd").make_tiled_box(size, origin)
	func make_forest_berm(size: Vector3, origin: Vector3) -> ArrayMesh:
		return preload("res://scripts/world_material_library.gd").make_forest_berm(size, origin)

class World extends Node3D:
	var owner_host: Node3D
	func _zone_runtime_fields() -> Scope:
		return Scope.for_root(owner_host.zone_root)
	func _make_role_visual(_role: String, _category: String, _scale: Vector3) -> Node3D:
		return null

class Assets extends RefCounted:
	var zone: String = ""
	func set_zone_scope(value: String) -> void:
		zone = value

class Host extends "res://scripts/systems/game_bindings.gd":
	func setup() -> void:
		_state = State.new(self)
		_host = self
		_state.story_state = Story.new()
		_state.settings = Settings.new()
		_state.world_materials = Materials.new()
		_state.asset_helper = Assets.new()
		_state.scene_rng = RandomNumberGenerator.new()
		_state.scene_rng.seed = 41021
		_state.shared_box_mesh = BoxMesh.new()
		add_child(_state.zone_residency)
		_state.zone_residency.configure(validate_render)
		var world: World = World.new()
		world.owner_host = self
		add_child(world)
		_systems = {"world": world}
		_state.zone_root = Node3D.new()
		_state.zone_root.name = "source"
		add_child(_state.zone_root)
	func _zone_runtime_fields() -> InstanceScope:
		return Scope.for_root(zone_root)
	func _gameplay_script(_key: String) -> Script:
		return Presentation
	func _connect_interactable(area: Variant, _owner_root: Node3D = null, owner_cache: Array = []) -> void:
		owner_cache.append(area)
	func _remove_interaction_candidate(area: Node) -> void:
		Scope.for_root(zone_root).unregister_actor(area)
	func _begin_zone_world_reads(_zone: String, _reset: bool = true) -> void:
		pass
	func _end_zone_world_reads() -> void:
		pass
	func _journey_load_pending() -> bool:
		return false
	func validate_render(branch: Node) -> Dictionary:
		var errors: Array[String] = []
		for mesh: MeshInstance3D in branch.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				errors.append("missing mesh")
			elif mesh.material_override == null and mesh.mesh.surface_get_material(0) == null:
				errors.append("missing material")
		return {"ok": errors.is_empty(), "errors": errors}

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _fsm() -> void:
	var abandoned: Transition = Transition.new()
	var abandoned_epoch: int = abandoned.prepare_opening()
	_check(abandoned.enter_menu() and not abandoned.pack_mounted("abandoned", abandoned_epoch), "return to menu invalidates opening callbacks")
	var model: Transition = Transition.new()
	_check(not model.autosave_allowed(), "BOOT must gate autosaves")
	_check(model.enter_menu(), "BOOT enters menu")
	var opening: int = model.prepare_opening()
	_check(model.state == Transition.State.PREPARING_OPENING, "opening preparation state")
	_check(model.pack_mounted("opening", opening), "current opening mount")
	_check(model.mark_prepared("greyfen", opening), "opening resources prepared")
	_check(not model.autosave_allowed() and model.active_zone_id.is_empty(), "preparation never starts a journey")
	var restore: int = model.request_travel("vargan_approach", true)
	_check(restore > opening and not model.accepts(opening), "selected Continue interrupts opening epoch")
	_check(not model.pack_mounted("stale_opening", opening), "stale opening mount rejected")
	_check(not model.commit("greyfen", opening, true, true), "stale opening cannot publish")
	_check(not model.commit("vargan_approach", restore, false, true), "unsupported ground cannot publish")
	_check(not model.commit("vargan_approach", restore, true, false), "incomplete world cannot publish")
	_check(model.commit("vargan_approach", restore, true, true), "supported selected destination publishes")
	_check(model.autosave_allowed(), "ACTIVE permits autosave")
	var adjacent: int = model.prepare_adjacent("wychwood")
	_check(not model.autosave_allowed(), "adjacent preparation gates autosave")
	_check(model.cancel(adjacent), "mid-preload cancel restores source")
	_check(model.active_zone_id == "vargan_approach" and model.autosave_allowed(), "cancel preserves active zone")
	_check(not model.pack_mounted("wychwood", adjacent), "cancelled preload callback rejected")
	var portal: int = model.request_travel("wychwood")
	_check(model.request_travel("wychwood") == portal, "double same portal coalesces")
	_check(model.request_travel("greyfen") == -1, "competing portal cannot replace commit")
	_check(not model.autosave_allowed(), "COMMITTING gates autosave")
	_check(model.fail(portal, "missing pack"), "failed download recovers")
	_check(model.failure == "missing pack" and model.active_zone_id == "vargan_approach", "failure retains source and actionable detail")
	_check(not model.commit("wychwood", portal, true, true), "failed epoch cannot publish late")
	adjacent = model.prepare_adjacent("greyfen")
	_check(model.mark_prepared("greyfen", adjacent) and model.autosave_allowed(), "completed neighbor preparation restores ACTIVE")
	_check(model.active_zone_id == "vargan_approach", "neighbor preparation cannot activate")
	var closing: int = model.teardown()
	_check(closing > adjacent and not model.autosave_allowed(), "teardown advances epoch and gates autosaves")
	_check(model.request_travel("greyfen", true) == -1 and not model.cancel(closing), "teardown is terminal")
	_check(not model.pack_mounted("late", closing) and not model.commit("greyfen", closing, true, true), "no publication during teardown")
	_check(not model.mounted_packs.has("stale_opening") and not model.mounted_packs.has("late"), "stale mounts do not alter ledger")

func _surface_contract(context: Context) -> bool:
	var zone: String = context.zone_id
	var bounds: Vector2 = Surface.zone_half_extents("greyfen" if zone == "cemetery" else zone)
	if zone in ["greyfen", "wychwood"]:
		context.make_split_ground(bounds.x * 2, bounds.y * 2, Surface.river_center(zone), 3.4, Color(0.16, 0.18, 0.13), Bridge.DECK_WIDTH, Bridge.bridge_length(3.4), Bridge.APPROACH_LENGTH)
	else:
		context.make_ground(Vector3(0, -0.08, 0), Vector3(bounds.x * 2, 0.16, bounds.y * 2), Color(0.16, 0.18, 0.13))
	context.make_play_area_bounds(bounds.x * 2, bounds.y * 2, Color(0.09, 0.12, 0.08))
	context.make_zone_gate("Return", Vector3(0, 0, 12), "greyfen" if zone != "greyfen" else "wychwood", Vector3(0, 1, 9))
	context.make_named_interactable("phase3_evidence", "inspect", "Inspect", Vector3(3, 0, 9), Color(0.3, 0.4, 0.2))
	return true

func _construction() -> void:
	var before_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host: Host = Host.new()
	root.add_child(host)
	host.setup()
	var source: Scope = Scope.for_root(host.zone_root)
	var source_rng: int = source.rng.get_state()
	var saves: Node = preload("res://scripts/save_manager.gd").new()
	_check(saves._save_is_gated(host), "save adapter gates BOOT")
	var epoch: int = host.world_transition.request_travel("source")
	_check(saves._save_is_gated(host), "save adapter gates COMMITTING")
	host.world_transition.commit("source", epoch, true, true)
	_check(not saves._save_is_gated(host), "save adapter permits supported ACTIVE")
	epoch = host.world_transition.prepare_adjacent("wychwood")
	_check(not saves._save_is_gated(host) and not saves.autosave(host) and not saves.checkpoint(host), "preloading permits a source manual save but gates automatic writes")
	host.world_transition.cancel(epoch)
	saves.free()
	for id: String in ["greyfen", "wychwood", "cemetery", "vargan_approach"]:
		var destination: Node3D = Node3D.new()
		destination.name = id
		host.add_child(destination)
		var context: Context = Context.new(host, id)
		context.own(destination, null)
		context.generation = 12
		var facade: Node3D = context.construction_host()
		_check(facade is Facade and context.scope is Scope, id + ": typed facade and scope")
		_check(context.run_step(_surface_contract), id + ": construction step completes")
		var result: Dictionary = context.validate()
		_check(bool(result.ok), id + ": ground/bounds/gate contract " + str(result.errors))
		_check(context.cursor == 1 and context.step_result().next_step == 1, id + ": resumable cursor")
		_check(context.scope.interaction_areas.size() == 2 and context.scope.interaction_area_cache.size() == 2, id + ": root-local registrations")
		_check(source.interaction_areas.is_empty() and source.runtime_light_count == 0 and source.rng.get_state() == source_rng, id + ": active world is untouched")
		_check(bool(host.validate_render(destination).ok), id + ": complete non-null materials")
		context.set_story_flag("phase3_local", id)
		_check(not host.story_state.flags.has("phase3_local") and context.scope.prepared_story_flags.phase3_local == id, id + ": preparation cannot change live story")
		var actor: Node3D = Node3D.new()
		destination.add_child(actor)
		context.scope.active_enemies.append(actor)
		context.scope.encounter_spatial_index.update(actor)
		context.scope.unregister_actor(actor)
		_check(context.scope.active_enemies.is_empty() and context.scope.encounter_spatial_index.nearby(actor.global_position, 1).is_empty(), id + ": unregister before free")
		actor.queue_free()
		var original_children: int = destination.get_child_count()
		context.cancel()
		context.set_story_flag("late_cancelled_write", true)
		facade._connect_interactable(source.zone_root)
		_check(not host.story_state.flags.has("late_cancelled_write") and source.interaction_area_cache.is_empty(), id + ": stale story/registration cannot fall back")
		facade._make_ground(Vector3.ZERO, Vector3.ONE, Color.WHITE)
		facade._make_pillar(Vector3.ZERO)
		_check(destination.get_child_count() == original_children and host.zone_root == source.zone_root, id + ": stale facade cannot build or fall back")
		_check(not context.run_step(_surface_contract) and context.step_result().state == "cancelled", id + ": cancelled step rejected")
		host.zone_residency._retire_zone_root(destination)
		_check(context.scope.interaction_areas.is_empty() and context.scope.interaction_area_cache.is_empty(), id + ": retirement clears registrations before free")
		var retirement_frames: int = 0
		while host.zone_residency.pending_zone_retirements > 0 and retirement_frames < 512:
			await process_frame
			retirement_frames += 1
		await process_frame
		_check(not is_instance_valid(destination) and not is_instance_valid(facade), id + ": root and facade released")
		_check(host.zone_residency.pending_zone_retirements == 0 and host.zone_residency.retired_zone_roots.is_empty(), id + ": no retirement owner remains")
		context = null
	host.zone_residency.release_shared_anchors()
	host.zone_residency.release_material_anchors()
	host.world_transition.teardown()
	_check(host.zone_residency._activate_cached_zone("greyfen") == null, "residency rejects activation after teardown")
	host.queue_free()
	await process_frame
	await process_frame
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == before_orphans, "construction leaves no orphan nodes")

func _registered_and_source_contracts() -> void:
	var released: Array[String] = ["greyfen", "wychwood", "ruins", "cemetery", "deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach", "vargan_court", "record_hall", "undercroft", "assembly", "hart_glade", "lantern_reach", "hearthward"]
	for id: String in released:
		_check(Router.supports(id) if id != "cemetery" else FileAccess.file_exists("res://scripts/zones/cemetery_section.gd"), id + ": retained composition owner")
	var paths: Array[String] = ["res://scripts/zone_construction_host.gd", "res://scripts/zone_build_context.gd"]
	for name: String in ["terrain_and_water_builder", "architecture_batch_builder", "foliage_and_prop_builder", "zone_actor_spawner", "interaction_station_builder", "settlement_detail_builder"]:
		paths.append("res://scripts/builders/" + name + ".gd")
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		_check(not text.contains("func _get(") and not text.contains("func _set("), path + ": no dynamic proxy")
		_check(not text.contains("zone_construction_fields") and not text.contains("owned_fields"), path + ": no field bag")
	_check(Opening != null and Lifecycle != null and Seamless != null, "all lifecycle adapters compile")

func _run() -> void:
	_fsm()
	_registered_and_source_contracts()
	await _construction()
	print("PHASE 3 ZONES AND TRANSITIONS: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
