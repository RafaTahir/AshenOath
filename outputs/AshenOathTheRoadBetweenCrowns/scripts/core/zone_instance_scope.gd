class_name ZoneInstanceScope
extends RefCounted
## A root-owned lifetime, never a fallback to the active coordinator's fields.
const Rng = preload("res://scripts/core/seeded_rng.gd")
const SpatialIndex = preload("res://scripts/actor_spatial_index.gd")

class Anchor extends Node:
	var scope: ZoneInstanceScope
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and scope != null:
			scope.release()

var zone_id: String = ""
var generation: int = 0
var cancelled: bool = false
var zone_root: Node3D
var active_enemies: Array[Node] = []
var interaction_candidates: Array[Area3D] = []
var interaction_areas: Array[Area3D] = []
var interaction_area_cache: Array[Area3D] = []
var interaction_area_cache_ready: bool = false
var interaction_focus_dirty: bool = true
var encounter_spatial_index: SpatialIndex = SpatialIndex.new()
var spatial_service: Node
var runtime_light_count: int = 0
var tree_batch_data: Array[Dictionary] = []
var deadfall_batch_data: Array[Transform3D] = []
var prop_batch_data: Dictionary[String, Dictionary] = {}
var visual_box_batch_data: Array[Dictionary] = []
var terrain_patch_batch_data: Array[Dictionary] = []
var house_batch_data: Dictionary[String, Dictionary] = {}
var house_module_batch_data: Dictionary[String, Dictionary] = {}
var environment_batches_flushed: bool = false
var world_props: Node
var world_vfx: Node
var rng: Rng = Rng.new(78233)
var builder_reference: WeakRef
var stream_environment_units: Array[Callable] = []
var stream_environment_cursor: int = 0
var prepared_story_flags: Dictionary = {}
var road_entrances: Dictionary = {}
var road_materials: Dictionary = {}
var opening_presentation_ready: bool = false
var preparing: bool = false
var _released: bool = false

static func for_root(root: Node3D, id: String = "") -> ZoneInstanceScope:
	if not is_instance_valid(root):
		return null
	var anchor: Anchor = root.get_node_or_null("_ZoneInstanceScope") as Anchor
	if anchor == null:
		anchor = Anchor.new()
		anchor.name = "_ZoneInstanceScope"
		anchor.scope = load("res://scripts/core/zone_instance_scope.gd").new()
		anchor.scope.zone_root = root
		anchor.scope.zone_id = id if not id.is_empty() else str(root.name)
		root.add_child(anchor, false, Node.INTERNAL_MODE_BACK)
	return anchor.scope

func supports_opening_spatial(service: Node) -> bool:
	return opening_presentation_ready and spatial_service == service

func is_current(epoch: int) -> bool:
	return not cancelled and not _released and generation == epoch and is_instance_valid(zone_root)

func cancel() -> void:
	if not cancelled:
		cancelled = true
		generation += 1

func unregister_actor(actor: Node) -> void:
	if is_instance_valid(actor):
		encounter_spatial_index.remove(actor.get_instance_id())
		active_enemies.erase(actor)
		if actor is Area3D:
			interaction_candidates.erase(actor)
			interaction_areas.erase(actor)
			interaction_area_cache.erase(actor)

func quiesce() -> void:
	cancel()
	for actor: Node in active_enemies:
		if is_instance_valid(actor):
			actor.set_physics_process(false)
			actor.set_process(false)
	for area: Area3D in interaction_areas:
		if is_instance_valid(area):
			area.set_process(false)
	active_enemies.clear()
	interaction_candidates.clear()
	interaction_areas.clear()
	interaction_area_cache.clear()
	interaction_area_cache_ready = false
	encounter_spatial_index = SpatialIndex.new()

func release() -> void:
	if _released:
		return
	quiesce()
	_released = true
	var builder: Node = builder_reference.get_ref() as Node if builder_reference != null else null
	builder_reference = null
	if is_instance_valid(builder) and not builder.is_queued_for_deletion():
		builder.queue_free()
	stream_environment_units.clear()
	road_entrances.clear()
	road_materials.clear()
	tree_batch_data.clear()
	deadfall_batch_data.clear()
	prop_batch_data.clear()
	visual_box_batch_data.clear()
	terrain_patch_batch_data.clear()
	house_batch_data.clear()
	house_module_batch_data.clear()
	prepared_story_flags.clear()
	world_props = null
	world_vfx = null
	spatial_service = null
	zone_root = null
