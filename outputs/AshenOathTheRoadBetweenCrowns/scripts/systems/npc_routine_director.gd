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

static func weather_routine(profile: Dictionary, entry: Dictionary, host, weather: String) -> Dictionary:
	profile = shared_work_routine(profile, entry, host)
	if weather != "rain" or bool(profile.get("sleeping",false)): return profile
	var shelter: Variant = entry.get("rain_shelter")
	if shelter == null:
		entry["rain_shelter"] = false
		var points: Array = profile.get("path",[]).duplicate()
		points.append_array(entry.get("base_path",[]))
		for raw in points:
			var point: Vector3 = raw
			var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.8,point+Vector3.UP*5.5,1)
			var hit: Dictionary = host.zone_root.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				entry.rain_shelter = point
				break
		shelter = entry.rain_shelter
	if not shelter is Vector3: return profile
	var result := profile.duplicate(true)
	var activity := "read" if str(profile.get("activity","")) == "read" else "check_supplies"
	result.merge({"path":[shelter],"activities":[activity],"activity":activity,"prop":WORK_PROPS.get(activity,""),"scheduled":true,"hold_activity":true,"revision":str(profile.get("revision",""))+":rain","line":"We'll keep the work dry until this passes."},true)
	result.erase("workstation")
	return result

static func shared_work_routine(profile: Dictionary, entry: Dictionary, host) -> Dictionary:
	if bool(profile.get("sleeping",false)): return profile
	var minutes: float = host.day_night.get_time()
	if minutes < 960.0 or minutes >= 1080.0: return profile
	var scenes = preload("res://scripts/story_world_scenes.gd")
	var cast = load("res://scripts/story_cast_profile.gd")
	var heard: Dictionary = host.story_state.get_flag("world_scenes_heard",{})
	for scene: Dictionary in scenes.data().get("scenes",[]):
		if str(scene.id) not in ["everyday_gre_pair","everyday_wyc_pair","everyday_dep_pair","everyday_roa_pair","everyday_var_pair_after","everyday_har_pair"]: continue
		if not bool(heard.get(str(scene.id),false)) or not scenes.eligible(scene,host): continue
		var actor_id := ""
		for id: String in scene.actors:
			if cast.same_person(id,str(entry.id)): actor_id=id
		if actor_id=="": continue
		var complete := true
		for id: String in scene.actors:
			if not is_instance_valid(cast.registered_actor(host.zone_root,id)): complete=false
		if not complete: continue
		var result := profile.duplicate(true)
		var path: Array = entry.get("base_path",profile.get("path",[]))
		var raw: Array = scene.get("stage",{}).get(actor_id,[])
		if not raw.is_empty(): path=[Vector3(raw[0],raw[1],raw[2])]
		if path.is_empty(): return profile
		var activity := str(scene.get("action","check_supplies"))
		result.merge({"path":[path.back()],"activities":[activity],"activity":activity,"prop":WORK_PROPS.get(activity,""),"scheduled":true,"hold_activity":true,"revision":str(profile.get("revision",""))+":"+str(scene.id)},true)
		result.erase("workstation")
		return result
	return profile
