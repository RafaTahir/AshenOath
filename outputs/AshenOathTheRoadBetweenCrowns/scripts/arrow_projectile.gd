extends Node3D

const SPEED := 48.0
var direction := Vector3.FORWARD
var remaining := 0.0
var shot: Dictionary = {}
var enemies: Array = []
var combat: WeakRef
var completed: Callable
var excluded: Array[RID] = []
var finished := false

func _physics_process(delta: float) -> void:
	if finished: return
	var origin := global_position
	var endpoint := origin + direction * minf(SPEED * delta, remaining)
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
	query.exclude = excluded
	query.collide_with_areas = false
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty(): endpoint = wall.position
	var result := {"hit": false, "point": endpoint, "endpoint": endpoint, "enemy": null}
	var resolver: Node = combat.get_ref() if combat != null else null
	if is_instance_valid(resolver):
		var segment := shot.duplicate()
		segment.merge({"origin":origin,"endpoint":endpoint,"direction":direction,"report_miss":false}, true)
		var candidates: Array = []
		for ref: WeakRef in enemies:
			var actor: Node = ref.get_ref()
			if is_instance_valid(actor): candidates.append(actor)
		result = resolver.resolve_arrow_shot(candidates, segment)
		if not bool(result.get("hit", false)) and not wall.is_empty():
			result = resolver.environment_contact(wall)
			result["direction"] = direction
	global_position = result.get("point", endpoint) if bool(result.get("hit", false)) else endpoint
	remaining -= origin.distance_to(endpoint)
	if bool(result.get("hit", false)) or not wall.is_empty() or remaining <= 0.001:
		finished = true
		set_physics_process(false)
		if completed.is_valid(): completed.call(result)
		queue_free()
