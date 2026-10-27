extends RefCounted

## Resolves intent only. GreyfenLifeController retains travel, reservations and
## interruptions; the existing saved day/night clock remains the sole clock.
const WORK_PROPS := {"forge":"hammer", "repair":"hammer", "read":"book", "check_rope":"rope", "bake":"bread", "care":"cloth", "sort_herbs":"bowl", "sort_seeds":"bowl", "tend":"bowl", "check_supplies":"supply", "sort_supplies":"supply"}

static func resolve(data: Dictionary, id: String, definition: Dictionary, profile: Dictionary, minutes: float) -> Dictionary:
	var schedule := str(definition.get("schedule", data.get("schedules_by_actor", {}).get(id, "villager_day")))
	var windows: Array = data.get("routines", {}).get(schedule, [])
	if windows.is_empty():
		return profile
	var now := fposmod(minutes, 1440.0)
	var slot := -1
	for index in windows.size():
		var window: Dictionary = windows[index]
		var start := float(window.start)
		var end := float(window.end)
		var inside := (start <= now and now < end) if start < end else (now >= start or now < end)
		if inside:
			slot = index
			break
	if slot < 0:
		return profile
	var intent: Dictionary = windows[slot]
	var result := profile.duplicate(true)
	var action := str(intent.action)
	if action == "work":
		action = str(profile.activity)
	var targets: Array = intent.get("targets", ["work"])
	var path: Array[Vector3] = []
	for target: String in targets:
		var point: Array = definition.get(target, definition.work)
		path.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
	var activities: Array[String] = []
	for point in path:
		activities.append(action)
	result.merge({"path":path, "activities":activities, "activity":action,
		"scheduled":true, "intent":str(intent.action), "intent_key":schedule + ":" + str(slot),
		"sleeping":bool(intent.get("sleeping", false)), "hold_activity":path.size() == 1,
		"prop":str(intent.get("prop", WORK_PROPS.get(action, ""))),
		"carry_in_transit":action == "carry", "activity_seconds":float(intent.get("dwell", 6.0))}, true)
	result.revision = str([profile.get("revision", ""), result.intent_key])
	return result

static func for_existing_route(data: Dictionary, id: String, profile: Dictionary, route: Array, minutes: float) -> Dictionary:
	if route.is_empty():
		return profile
	var work: Vector3 = route.back()
	var rest: Vector3 = route.front()
	var definition := {"work":[work.x,work.y,work.z], "errand":[rest.x,rest.y,rest.z], "rest":[rest.x,rest.y,rest.z]}
	return resolve(data, id, definition, profile, minutes)
